# Writes build\diag-<name>-<light|dark>.html so a diagram can be checked in a browser (both themes).
param([string]$Name = 'overview', [string]$Lang = 'en', [string]$Out = (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path 'build'))
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\QI.Common.ps1"; $SITE = Get-Site; $CAT = Get-Catalog
. "$PSScriptRoot\Diagrams.ps1"
New-Item -ItemType Directory -Force $Out | Out-Null
foreach ($m in 'light', 'dark') {
  $bg = if ($m -eq 'light') { '#ffffff' } else { '#111111' }
  $html = "<!doctype html><html data-theme=""$m""><meta charset=""utf-8""><style>body{margin:0;padding:12px;background:$bg}$($script:DiagramCss)</style><body>$(Get-Diagram $Name $Lang)</body></html>"
  [IO.File]::WriteAllText((Join-Path $Out "diag-$Name-$m.html"), $html, (New-Object Text.UTF8Encoding($false)))
}
"preview: $Out\diag-$Name-light.html / -dark.html"
