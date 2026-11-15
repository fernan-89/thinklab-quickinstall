# Generates ventoy\ventoy.json: TreeView menu in three folders, ThinkLab theme, aliases, class icons, auto-install templates, PE injection.
# Never set VTOY_MENU_TIMEOUT to 0: Ventoy then boots the first image immediately (that once hid the Windows entries).
param([string]$SitePath, [string]$Out = (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path 'build\USB'))
. "$PSScriptRoot\QI.Common.ps1"
$ErrorActionPreference = 'Stop'
$site = Get-Site $SitePath; $cat = Get-Catalog
$wk = @(Get-WindowsKits $site $cat); $lk = @(Get-LinuxKits $site $cat)
$f = $cat.folders
$alias = @(); $auto = @(); $cls = @(); $inject = @()
$dirs = [ordered]@{
  "/ISO/$($f.windows)"  = 'Windows - instalacao completa (kits por maquina)'
  "/ISO/$($f.linux)"    = 'Linux - instalacao (Ubuntu, AlmaLinux, openSUSE)'
  "/ISO/$($f.recovery)" = 'Recovery - Windows Live e resgate (Hiren''s PE, SystemRescue, GParted, Clonezilla, MemTest86+)'
}
foreach ($d in $dirs.Keys) { $alias += [ordered]@{ dir = $d; alias = $dirs[$d] } }

function Who($labels) { $l = @($labels | Select-Object -Unique); if ($l.Count -eq 0) { 'BASE' } elseif ($l.Count -eq 1) { "somente $($l[0])" } else { $l -join ' / ' } }

foreach ($w in $cat.windows) {
  $p = "/ISO/$($f.windows)/$($w.iso)"
  $mine = @($wk | Where-Object { -not $_.Base -and $_.Os -eq $w.os -and $_.Lang -eq $w.lang })
  $tail = if ($w.office) { "Office $($w.office)" } else { 'Servidor' }
  $alias += [ordered]@{ image = $p; alias = "$($w.label) | $(Who ($mine | ForEach-Object MachineLabel)) | $tail" }
  $same = @($wk | Where-Object { $_.Os -eq $w.os -and $_.Lang -eq $w.lang })
  $tpl = @($same | Where-Object { $_.Base }) + @($same | Where-Object { -not $_.Base })   # BASE first, then machines in site order (Sort-Object is not stable)
  $auto += [ordered]@{ image = $p; template = @($tpl | ForEach-Object { "/Unattend/$($_.File)" }) }
}
foreach ($l in $cat.linux) {
  $p = "/ISO/$($f.linux)/$($l.iso)"
  $mine = @($lk | Where-Object { -not $_.Base -and $_.Distro -eq $l.id } | ForEach-Object { $site.machines | Where-Object code -eq $_.Machine | ForEach-Object label })
  $who = if (Get-Prop $l 'allMachines') { 'todas' } else { Who $mine }
  $suffix = Get-Prop $l 'aliasSuffix'
  $alias += [ordered]@{ image = $p; alias = ("$($l.label) | $who" + $(if ($suffix) { " | $suffix" } else { '' })) }
  $files = @($lk | Where-Object { $_.Distro -eq $l.id } | Sort-Object File | ForEach-Object File)
  if ($files.Count) { $auto += [ordered]@{ image = $p; template = @($files | ForEach-Object { "/Unattend/$_" }) } }
}
foreach ($r in $cat.recovery) {
  $p = "/ISO/$($f.recovery)/$($r.iso)"
  $alias += [ordered]@{ image = $p; alias = $r.label }
  if (Get-Prop $r 'inject') { $inject += [ordered]@{ image = $p; archive = '/ventoy/inject/ThinkLab-PE-Extras.zip' } }
}
$seen = @{}
foreach ($e in @($cat.windows) + @($cat.linux) + @($cat.recovery)) {
  $key = ($e.iso -split '_x64')[0] -replace '_Multi.*', ''
  if (-not $seen.ContainsKey($key)) { $seen[$key] = 1; $cls += [ordered]@{ key = $key; class = $e.class } }
}
$cfg = [ordered]@{
  control = @(
    [ordered]@{ VTOY_DEFAULT_SEARCH_ROOT = '/ISO' }, [ordered]@{ VTOY_DEFAULT_MENU_MODE = '1' }, [ordered]@{ VTOY_TREE_VIEW_MENU_STYLE = '1' },
    [ordered]@{ VTOY_FILT_DOT_UNDERSCORE_FILE = '1' }, [ordered]@{ VTOY_SORT_CASE_SENSITIVE = '0' } )
  theme = [ordered]@{ file = '/ventoy/theme/thinklab/theme.txt'; gfxmode = '1920x1080'; display_mode = 'GUI' }
  menu_alias = $alias; menu_class = $cls; auto_install = $auto; injection = $inject
}
# Ventoy's JSON parser does not decode \u escapes (PowerShell writes ' as ')
$json = ($cfg | ConvertTo-Json -Depth 8).Replace(([string][char]92 + 'u0027'), [string][char]39)
Write-Utf8 (Join-Path $Out 'ventoy\ventoy.json') $json
$missing = $auto.template | ForEach-Object { $_ } | Where-Object { -not (Test-Path (Join-Path $Out $_.TrimStart('/'))) }
"New-VentoyConfig: $($alias.Count) aliases, $($cls.Count) classes, $($auto.Count) auto_install, $(@($auto.template | ForEach-Object { $_ }).Count) templates; missing template files: $(@($missing).Count)"
$missing
