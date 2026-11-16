# Builds everything that goes on the stick EXCEPT the big binaries (ISOs, Office, drivers, installers):
#   build\USB\{Unattend, Scripts, ventoy (json + theme + inject), Docs}
# Usage:  .\src\tools\New-Kit.ps1            (uses config\site.json, else config\site.example.json)
param([string]$SitePath, [string]$Out = (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path 'build\USB'), [switch]$SkipDocs, [string]$StickRoot = '')
. "$PSScriptRoot\QI.Common.ps1"
$ErrorActionPreference = 'Stop'
$site = Get-Site $SitePath
"Site definition: $($site._path)"
if (Test-Path "$Out\Unattend") { Remove-Item "$Out\Unattend" -Recurse -Force }     # no stale templates
New-Item -ItemType Directory -Force $Out | Out-Null

& "$PSScriptRoot\New-Unattend.ps1"       -SitePath $SitePath -Out $Out
& "$PSScriptRoot\New-LinuxTemplates.ps1" -SitePath $SitePath -Out $Out
& "$PSScriptRoot\Build-Theme.ps1"        -Out (Join-Path $Out 'ventoy\theme') | Select-Object -Last 1
& "$PSScriptRoot\Build-PeExtras.ps1"     -Stage $Out | Select-Object -First 1
& "$PSScriptRoot\Build-Branding.ps1"      -SitePath $SitePath -Out $Out
& "$PSScriptRoot\New-VentoyConfig.ps1"   -SitePath $SitePath -Out $Out

# Windows post-install + its data (software catalog, profiles, Office product ids)
$sd = Join-Path $Out 'Scripts'; New-Item -ItemType Directory -Force $sd | Out-Null
Copy-Item (Join-Path $script:RepoRoot 'src\kit\*.ps1') $sd -Force
$oem = if ($site.site.PSObject.Properties.Name -contains 'oem') { $site.site.oem } else { [pscustomobject]@{ manufacturer = 'ThinkLab' } }
$kit = [ordered]@{ software = (Get-Software); office = (Get-Catalog).office; oem = $oem }
Write-Utf8 (Join-Path $sd 'kit.json') ($kit | ConvertTo-Json -Depth 8)
"Scripts: $((Get-ChildItem $sd).Name -join ', ')"

if (-not $SkipDocs -and (Test-Path "$PSScriptRoot\Build-Docs.ps1")) { & "$PSScriptRoot\Build-Docs.ps1" -SitePath $SitePath -Out (Join-Path $Out 'Docs') -Stage $Out -StickRoot $StickRoot | Select-Object -Last 1 }
"New-Kit done -> $Out"
