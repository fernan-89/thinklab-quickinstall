# Generates ventoy\ventoy.json: TreeView menu in three numbered folders, ThinkLab themes (dark + light, F5 > Theme Select),
# PF2 fonts, bilingual aliases laid out as columns (the menu font is monospaced), a bilingual tip per entry, class icons,
# auto-install templates and PE injection.
# Never set VTOY_MENU_TIMEOUT to 0: Ventoy then boots the first image immediately (that once hid the Windows entries).
param([string]$SitePath, [string]$Out = (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path 'build\USB'))
. "$PSScriptRoot\QI.Common.ps1"
$ErrorActionPreference = 'Stop'
function U($s) { [regex]::Unescape($s) }
$site = Get-Site $SitePath; $cat = Get-Catalog
$wk = @(Get-WindowsKits $site $cat); $lk = @(Get-LinuxKits $site $cat)
$f = $cat.folders
$alias = @(); $auto = @(); $cls = @(); $inject = @(); $tips = @()
$DOT = U ' \u00b7 '
function Row([string]$name, [string]$lang, [string]$who, [string]$tail) { ('{0}  {1}  {2}  {3}' -f $name.PadRight(37).Substring(0, 37), $lang.PadRight(6), $who.PadRight(29), $tail).TrimEnd() }
function Who($labels) { $l = @($labels | Select-Object -Unique); if ($l.Count -eq 0) { 'BASE' } else { 'BASE' + $DOT + ($l -join $DOT) } }
function Tip($t) { U $t }   # one short bilingual line (it must fit a 1024-pixel-wide screen too)

$dirs = @(
  @{ d = "/ISO/$($f.windows)";  a = (U '01/  Windows   instala\u00e7\u00e3o completa / full install');           t = (Tip 'sistema > kit da m\u00e1quina ou BASE  |  system > machine kit or BASE') },
  @{ d = "/ISO/$($f.linux)";    a = (U '02/  Linux     instala\u00e7\u00e3o / install');                         t = (Tip 'workstation PT/EN \u00b7 server EN + Netdata') },
  @{ d = "/ISO/$($f.recovery)"; a = (U '03/  Recovery  recupera\u00e7\u00e3o e diagn\u00f3stico / rescue and diagnostics'); t = (Tip 'roda do pen-drive, n\u00e3o instala  |  runs from the stick, installs nothing') })
foreach ($d in $dirs) { $alias += [ordered]@{ dir = $d.d; alias = $d.a }; $tips += [ordered]@{ dir = $d.d; tip = $d.t } }

foreach ($w in $cat.windows) {
  $p = "/ISO/$($f.windows)/$($w.iso)"
  $mine = @($wk | Where-Object { -not $_.Base -and $_.Os -eq $w.os -and $_.Lang -eq $w.lang })
  $name = (($w.label -split ' - ')[0]) -replace '\(leve\)', '(lite)'
  $tag = $script:Loc[$w.lang].Tag
  $tail = if ($w.office) { "Office $($w.office)" } else { 'Std / Datacenter' }
  $alias += [ordered]@{ image = $p; alias = (Row $name $tag (Who ($mine | ForEach-Object MachineLabel)) $tail) }
  $tips += [ordered]@{ image = $p; tip = $(if ($w.office) { Tip "kits + BASE \u00b7 Office $($w.office) offline \u00b7 disco manual / manual disk" } else { Tip 'Standard / Datacenter \u00b7 Desktop Experience \u00b7 Netdata \u00b7 disco manual / manual disk' }) }
  $same = @($wk | Where-Object { $_.Os -eq $w.os -and $_.Lang -eq $w.lang })
  $tpl = @($same | Where-Object { $_.Base }) + @($same | Where-Object { -not $_.Base })   # BASE first, then machines in site order (Sort-Object is not stable)
  $auto += [ordered]@{ image = $p; template = @($tpl | ForEach-Object { "/Unattend/$($_.File)" }) }
}
foreach ($l in $cat.linux) {
  $p = "/ISO/$($f.linux)/$($l.iso)"
  $mine = @($lk | Where-Object { -not $_.Base -and $_.Distro -eq $l.id } | ForEach-Object { $site.machines | Where-Object code -eq $_.Machine | ForEach-Object label })
  $name = (($l.label -split ' - ')[0]) -replace '\s*\([^)]*\)', ''
  switch ($l.templates) {
    'kickstart'   { $lang = 'PT/EN'; $who = Who $mine; $tail = 'Desktop / Server' + $(if (Get-Prop $l 'repoUrl') { ' (net)' } else { '' })
                    $tip = Tip 'kickstart \u00b7 workstation PT/EN \u00b7 server EN + Netdata \u00b7 disco manual / manual disk' }
    'autoinstall' { $lang = 'EN'; $who = Who $mine; $tail = 'Server'
                    $tip = Tip 'autoinstall \u00b7 server EN + Netdata \u00b7 disco manual / manual disk' }
    default       { $lang = '--'; $who = 'todas / all'; $tail = 'Agama'
                    $tip = Tip 'Agama \u00b7 instalador interativo / interactive installer' }
  }
  $alias += [ordered]@{ image = $p; alias = (Row $name $lang $who $tail) }; $tips += [ordered]@{ image = $p; tip = $tip }
  $files = @($lk | Where-Object { $_.Distro -eq $l.id } | Sort-Object File | ForEach-Object File)
  if ($files.Count) { $auto += [ordered]@{ image = $p; template = @($files | ForEach-Object { "/Unattend/$_" }) } }
}
$recTip = @{
  pe      = (Tip 'Windows Live (WinPE) \u00b7 boot, senhas / passwords, dados / data, clone')
  rescue  = (Tip 'Linux live \u00b7 parti\u00e7\u00f5es / partitions, arquivos / files, rede / network')
  tools   = (Tip 'disco e imagem / disk and imaging \u00b7 siga a tela / follow the screen')
  memtest = (Tip 'teste de RAM / RAM test \u00b7 v\u00e1rias passagens / several passes')
}
$recKind = @{ pe = 'Windows Live'; rescue = 'Linux live'; tools = 'Live tool'; memtest = 'RAM test' }
foreach ($r in $cat.recovery) {
  $p = "/ISO/$($f.recovery)/$($r.iso)"; $k = if ($recTip.ContainsKey($r.class)) { $r.class } else { 'tools' }
  $alias += [ordered]@{ image = $p; alias = (Row (($r.label -split ' - ')[0]) '--' $recKind[$k] $(if (Get-Prop $r 'inject') { '+ ThinkLab PE Extras' } else { '' })) }
  $tips += [ordered]@{ image = $p; tip = $recTip[$k] }
  if (Get-Prop $r 'inject') { $inject += [ordered]@{ image = $p; archive = '/ventoy/inject/ThinkLab-PE-Extras.zip' } }
}
$seen = @{}
foreach ($e in @($cat.windows) + @($cat.linux) + @($cat.recovery)) {
  $key = ($e.iso -split '_x64')[0] -replace '_Multi.*', ''
  if (-not $seen.ContainsKey($key)) { $seen[$key] = 1; $cls += [ordered]@{ key = $key; class = $e.class } }
}
$fonts = @(Get-ChildItem (Join-Path $Out 'ventoy\theme\fonts') -Filter *.pf2 -ErrorAction SilentlyContinue | ForEach-Object { "/ventoy/theme/fonts/$($_.Name)" })
$cfg = [ordered]@{
  control = @(
    [ordered]@{ VTOY_DEFAULT_SEARCH_ROOT = '/ISO' }, [ordered]@{ VTOY_DEFAULT_MENU_MODE = '1' }, [ordered]@{ VTOY_TREE_VIEW_MENU_STYLE = '1' },
    [ordered]@{ VTOY_FILT_DOT_UNDERSCORE_FILE = '1' }, [ordered]@{ VTOY_SORT_CASE_SENSITIVE = '0' } )
  theme = [ordered]@{ file = @('/ventoy/theme/thinklab-dark/theme.txt', '/ventoy/theme/thinklab-light/theme.txt'); default_file = 1
    fonts = $fonts; gfxmode = '1920x1080'; display_mode = 'GUI'; ventoy_left = '34%'; ventoy_top = '96%'; ventoy_color = '#8A8A8A' }
  menu_alias = $alias; menu_tip = [ordered]@{ left = '34%'; top = '82%'; color = '#8A8A8A'; tips = $tips }
  menu_class = $cls; auto_install = $auto; injection = $inject
}
# Ventoy's JSON parser does not decode \u escapes: write real UTF-8 characters (PowerShell 5.1 escapes ' < > & and non-ASCII)
$json = [regex]::Replace(($cfg | ConvertTo-Json -Depth 8), '\\u([0-9a-fA-F]{4})', { param($m) [string][char][Convert]::ToInt32($m.Groups[1].Value, 16) })
Write-Utf8 (Join-Path $Out 'ventoy\ventoy.json') $json
$missing = $auto.template | ForEach-Object { $_ } | Where-Object { -not (Test-Path (Join-Path $Out $_.TrimStart('/'))) }
"New-VentoyConfig: $($alias.Count) aliases, $($tips.Count) tips, $($cls.Count) classes, $($auto.Count) auto_install, $(@($auto.template | ForEach-Object { $_ }).Count) templates; missing template files: $(@($missing).Count)"
$missing
