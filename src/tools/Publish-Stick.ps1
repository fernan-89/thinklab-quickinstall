# Publishes the built kit (build\USB) and, optionally, the large binaries of a "library" folder to a Ventoy stick.
#   -Stick  E:            drive letter of the Ventoy data partition (the volume label must be "Ventoy")
#   -Library <folder>     optional; layout:  iso\**  (any sub-folders; ISOs are found by the exact names in config\catalog.json)
#                                            office\{_ODT\setup.exe, pt-BR\Office-Retail-CurrentChannel_*}
#                                            software\**   drivers\<machine-folder>\**
# Unattend\ and Docs\ are mirrored (stale files on the stick are removed); everything else is only added/updated.
param(
  [Parameter(Mandatory)][string]$Stick,
  [string]$Library,
  [string]$Build
)
. "$PSScriptRoot\QI.Common.ps1"
# default resolved here, not in param(): $PSScriptRoot is still empty while parameter defaults are evaluated
if (-not $Build) { $Build = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'build\USB' }
$ErrorActionPreference = 'Stop'
$Stick = $Stick.TrimEnd('\'); if ($Stick.Length -eq 1) { $Stick += ':' }
$v = Get-Volume -DriveLetter $Stick.Substring(0, 1) -ErrorAction Stop
if ($v.FileSystemLabel -ne 'Ventoy') { throw "$Stick is labelled '$($v.FileSystemLabel)', not 'Ventoy' - refusing to write." }
if (-not (Test-Path "$Build\ventoy\ventoy.json")) { throw "Nothing built yet: run src\tools\New-Kit.ps1 first ($Build)." }
$cat = Get-Catalog

function Sync($src, $dst, [switch]$Mirror, [string[]]$Files = @('*.*')) {
  if (-not (Test-Path $src)) { return }
  $a = @($src, $dst) + $Files + @('/E', '/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP'); if ($Mirror) { $a += '/PURGE' }
  robocopy @a | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE): $src -> $dst" }
  "  {0,-60} -> {1}" -f $src.Replace((Get-Location).Path + '\', ''), $dst
}
"Publishing to $Stick (label Ventoy)"
Sync "$Build\ventoy" "$Stick\ventoy"
Sync "$Build\Unattend" "$Stick\Unattend" -Mirror
Sync "$Build\Scripts" "$Stick\Scripts"
Sync "$Build\Docs" "$Stick\Docs" -Mirror
Sync "$Build\Wallpapers" "$Stick\Wallpapers"

if ($Library) {
  $lib = (Resolve-Path $Library).Path
  function CopyIso($name, $folder) {
    $f = Get-ChildItem "$lib\iso" -Recurse -Filter $name -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $f) { Write-Warning "ISO not in library: $name"; return }
    $d = "$Stick\ISO\$folder"; New-Item -ItemType Directory -Force $d | Out-Null
    if ((Test-Path "$d\$name") -and (Get-Item "$d\$name").Length -eq $f.Length) { "  (up to date) $name"; return }
    Write-Host "  copying $name ($([math]::Round($f.Length/1GB,2)) GiB) ..."; Copy-Item $f.FullName $d -Force
  }
  foreach ($w in $cat.windows) { CopyIso $w.iso $cat.folders.windows }
  foreach ($l in $cat.linux) { CopyIso $l.iso $cat.folders.linux }
  foreach ($r in $cat.recovery) { CopyIso $r.iso $cat.folders.recovery }
  Sync "$lib\office" "$Stick\Office"
  Sync "$lib\software" "$Stick\Software"
  if (Test-Path "$lib\wallpapers") { foreach ($d in Get-ChildItem "$lib\wallpapers" -Directory) { Sync $d.FullName "$Stick\Wallpapers\$($d.Name)" } }   # official vendor wallpapers (private)
  if (Test-Path "$lib\drivers") { foreach ($d in Get-ChildItem "$lib\drivers" -Directory) { Sync $d.FullName "$Stick\Drivers\$($d.Name)" } }
}
'Done. Next: src\tools\New-Manifest.ps1 -Stick ' + $Stick + '  (writes SHA256SUMS.txt) and Scripts\Verify-Stick.ps1 to check it later.'
