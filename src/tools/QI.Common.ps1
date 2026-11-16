# Shared helpers for the ThinkLab Quick Install build tools (dot-source this file). Windows PowerShell 5.1 compatible, ASCII only.
$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json }
function Write-Utf8([string]$Path, [string]$Text) {
  New-Item -ItemType Directory -Force (Split-Path $Path -Parent) | Out-Null
  [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}

# site.json (private, git-ignored) wins over site.example.json
function Get-Site([string]$Path) {
  if (-not $Path) { $Path = Join-Path $script:RepoRoot 'config\site.json'; if (-not (Test-Path $Path)) { $Path = Join-Path $script:RepoRoot 'config\site.example.json' } }
  $s = Read-Json $Path; $s | Add-Member -NotePropertyName _path -NotePropertyValue $Path -Force; $s
}
function Get-Catalog  { Read-Json (Join-Path $script:RepoRoot 'config\catalog.json') }
function Get-Software { Read-Json (Join-Path $script:RepoRoot 'config\software.json') }

$script:Loc = @{
  EN = @{ Tag = 'EN-US'; Ui = 'en-US'; Input = '0409:00000409'; Letter = 'e'; Kbd = 'us';       LinuxLang = 'en_US.UTF-8' }
  PT = @{ Tag = 'PT-BR'; Ui = 'pt-BR'; Input = '0416:00010416'; Letter = 'p'; Kbd = 'br-abnt2'; LinuxLang = 'pt_BR.UTF-8' }
}

function Get-Prop($o, [string]$n) { if ($o -and $o.PSObject.Properties.Name -contains $n) { $o.$n } else { $null } }

# Every Windows kit described by the site (per machine) + one generic BASE kit per catalog ISO.
function Get-WindowsKits($Site, $Catalog) {
  $kits = @()
  foreach ($m in $Site.machines) {
    foreach ($wk in @($m.windows)) {
      foreach ($lang in @($wk.langs)) {
        $cat = $Catalog.windows | Where-Object { $_.os -eq $wk.os -and $_.lang -eq $lang } | Select-Object -First 1
        if (-not $cat) { Write-Warning "no catalog ISO for $($wk.os)/$lang (machine $($m.code))"; continue }
        $edKey = if ($wk.edition -and $cat.editions.PSObject.Properties.Name -contains $wk.edition) { $wk.edition } else { 'Default' }
        $ed = $cat.editions.$edKey
        $profile = (Get-Prop $wk 'profile'); if (-not $profile) { $profile = $m.profile }
        $pfile = (Get-Prop $wk 'profileFile'); if (-not $pfile) { $pfile = $m.profileFile }
        $role = (Get-Prop $wk 'role'); if (-not $role) { $role = $m.role }
        $loc = $script:Loc[$lang]
        $name = ('{0}-{1}-{2}{3}-{4}' -f $Site.site.prefix, $m.nameCode, $wk.os, $loc.Letter.ToUpper(), $role).ToUpper()
        $file = '{0}_{1}_{2}' -f $m.code, $loc.Tag, $cat.fileLabel
        if (Get-Prop $ed 'fileLabel') { $file += '-' + $ed.fileLabel }
        if ($cat.office) { $file += "_Office$($cat.office)" }
        $file += "_$pfile.xml"
        $drv = @(); if ($m.drivers -and ($m.drivers.PSObject.Properties.Name -contains $wk.os)) { $drv = @($m.drivers.($wk.os)) }
        $kits += [pscustomobject]@{ File = $file; Name = $name; Machine = $m.code; MachineLabel = $m.label; Os = $wk.os; Lang = $lang; Iso = $cat.iso; Image = $ed.image; KeyId = $ed.key
          Key = $Catalog.genericKeys.($ed.key); Profile = $profile; Drivers = $drv; Office = $cat.office; Base = $false; FullName = $m.fullName; Wallpapers = @(Get-Prop $m 'wallpapers'); ExtraSoftware = @(Get-Prop $wk 'extraSoftware') }
      }
    }
  }
  foreach ($cat in $Catalog.windows) {
    $baseEds = @(Get-Prop $cat 'baseEditions'); if (-not $baseEds -or -not $baseEds[0]) { $baseEds = @(if ($cat.editions.PSObject.Properties.Name -contains 'Pro') { 'Pro' } else { 'Default' }) }
    foreach ($edKey in $baseEds) {
      $ed = $cat.editions.$edKey
      $loc = $script:Loc[$cat.lang]
      $file = 'BASE_{0}_{1}' -f $loc.Tag, $cat.fileLabel
      if (Get-Prop $ed 'fileLabel') { $file += '-' + $ed.fileLabel }
      if ($cat.office) { $file += "_Office$($cat.office)" }
      $file += '_Base.xml'
      $profile = if ($cat.office) { 'Base' } else { 'Server' }
      $kits += [pscustomobject]@{ File = $file; Name = '*'; Machine = 'BASE'; MachineLabel = 'BASE'; Os = $cat.os; Lang = $cat.lang; Iso = $cat.iso; Image = $ed.image; KeyId = $ed.key
        Key = $Catalog.genericKeys.($ed.key); Profile = $profile; Drivers = @(); Office = $cat.office; Base = $true; FullName = ''; Wallpapers = @(); ExtraSoftware = @() }
    }
  }
  $kits
}

# Linux templates described by the site (+ BASE). Kind: kickstart (alma) / autoinstall (ubuntu).
function Get-LinuxKits($Site, $Catalog) {
  $out = @()
  $prefix = $Site.site.prefix.ToLower()
  foreach ($lx in $Catalog.linux) {
    if ($lx.templates -eq 'none') { continue }
    $entries = @()
    foreach ($m in $Site.machines) {
      $cfg = Get-Prop (Get-Prop $m 'linux') $lx.id
      if ($cfg) { $entries += [pscustomobject]@{ Code = $m.code; NameCode = $m.nameCode.ToLower(); Label = $m.label; Cfg = $cfg; Base = $false } }
    }
    $baseCfg = if ($lx.templates -eq 'kickstart') { [pscustomobject]@{ desktop = @('EN', 'PT'); server = @('EN') } } else { [pscustomobject]@{ server = @('EN') } }
    $entries += [pscustomobject]@{ Code = 'BASE'; NameCode = 'base'; Label = 'BASE'; Cfg = $baseCfg; Base = $true }
    foreach ($e in $entries) {
      foreach ($kind in 'desktop', 'server') {
        foreach ($lang in @(Get-Prop $e.Cfg $kind)) {
          if (-not $lang) { continue }
          if ($kind -eq 'server' -and $lang -ne 'EN') { Write-Warning "server kits are English only - ignoring $lang ($($e.Code))"; continue }   # policy: servers EN, workstations EN or PT
          $loc = $script:Loc[$lang]; $k = if ($kind -eq 'desktop') { 'd' } else { 's' }
          $host_ = if ($e.Base) { '' } else { '{0}-{1}-{2}{3}-{4}' -f $prefix, $e.NameCode, $lx.hostCode, $loc.Letter, $k }
          if ($lx.templates -eq 'kickstart') { $role = if ($kind -eq 'desktop') { 'Workstation' } else { 'Server' }; $file = '{0}_{1}_{2}-{3}.ks' -f $e.Code, $loc.Tag, $lx.tag, $role }
          else { $file = '{0}_{1}_{2}_Servidor.yaml' -f $e.Code, $loc.Tag, $lx.tag }
          $out += [pscustomobject]@{ File = $file; Distro = $lx.id; Iso = $lx.iso; Kind = $kind; Lang = $lang; Host = $host_; Machine = $e.Code; Tag = $lx.tag; Base = $e.Base; RepoUrl = (Get-Prop $lx 'repoUrl') }
        }
      }
    }
  }
  $out
}

# ---- design tokens (config\design.json): Material Design roles, solid colours, dark + light per interface ----
function Get-Design { Read-Json (Join-Path $script:RepoRoot 'config\design.json') }
# Merged palette for one interface and scheme (dark|light) as an ordered hashtable role -> #RRGGBB
function Get-Palette([string]$Interface, [string]$Scheme) {
  $d = Get-Design; $out = [ordered]@{}
  foreach ($pr in $d.base.$Scheme.PSObject.Properties) { $out[$pr.Name] = $pr.Value }
  $iface = $d.interfaces.$Interface
  if ($iface -and $iface.$Scheme) { foreach ($pr in $iface.$Scheme.PSObject.Properties) { $out[$pr.Name] = $pr.Value } }
  foreach ($pr in $d.seed.PSObject.Properties) { if (-not $out.Contains("seed-$($pr.Name)")) { $out["seed-$($pr.Name)"] = $pr.Value } }
  $out
}
