# Builds a small VIRTUAL Ventoy stick (VHDX) to test kits in Hyper-V without touching the real stick. Run in an ELEVATED PowerShell.
#   -VentoyDir  folder of an extracted Ventoy release (contains Ventoy2Disk.exe); download it from ventoy.net
#   -Source     a published stick (E:) or any folder with the same layout; only what you list is copied
#   -Iso        ISO file names to copy (looked up under <Source>\ISO\**)
# The VHDX is created, mounted, formatted by Ventoy2Disk (/NoUsbCheck is safe here: the target is a file-backed virtual disk), filled and dismounted.
param(
  [Parameter(Mandatory)][string]$VentoyDir,
  [Parameter(Mandatory)][string]$Source,
  [string[]]$Iso = @(),
  [string[]]$Folders = @('ventoy', 'Unattend', 'Scripts', 'Docs'),
  [string[]]$ExtraFolders = @(),            # e.g. Office, Software, Drivers\<machine>
  [int]$SizeGB = 32,
  [string]$Path = 'C:\VMs\TestStick.vhdx'
)
$ErrorActionPreference = 'Stop'
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (([Security.Principal.WindowsPrincipal]$id).IsInRole('Administrator') -or ((whoami /groups) -match 'High Mandatory Level'))) { throw 'Run elevated.' }
$Source = $Source.TrimEnd('\'); if ($Source.Length -eq 1) { $Source += ':' }
New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null
if (Test-Path $Path) { Dismount-VHD $Path -ErrorAction SilentlyContinue; Remove-Item $Path -Force }
New-VHD -Path $Path -SizeBytes ($SizeGB * 1GB) -Dynamic | Out-Null
$d = Mount-VHD -Path $Path -Passthru | Get-Disk
if ($d.BusType -ne 'File Backed Virtual') { Dismount-VHD $Path; throw 'unexpected disk type - refusing to format' }
Push-Location $VentoyDir
$p = Start-Process "$VentoyDir\Ventoy2Disk.exe" -ArgumentList 'VTOYCLI', '/I', "/PhyDrive:$($d.Number)", '/GPT', '/NoUsbCheck' -Wait -PassThru -WindowStyle Hidden
Pop-Location
if ($p.ExitCode -ne 0) { Dismount-VHD $Path; throw "Ventoy2Disk failed ($($p.ExitCode)); see $VentoyDir\cli_log.txt" }
Start-Sleep 3
$L = (Get-Partition -DiskNumber $d.Number | Get-Volume | Where-Object FileSystemLabel -eq 'Ventoy').DriveLetter
"test stick formatted: ${L}: ($SizeGB GB virtual)"
foreach ($f in $Folders + $ExtraFolders) { if (Test-Path "$Source\$f") { robocopy "$Source\$f" "${L}:\$f" /E /R:1 /W:1 /NFL /NDL /NJH /NP /NJS | Out-Null; "  copied $f" } else { Write-Warning "missing in source: $f" } }
foreach ($n in $Iso) {
  $f = Get-ChildItem "$Source\ISO" -Recurse -Filter $n -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $f) { Write-Warning "ISO not found: $n"; continue }
  $rel = $f.DirectoryName.Substring($Source.Length + 1); New-Item -ItemType Directory -Force "${L}:\$rel" | Out-Null
  Copy-Item $f.FullName "${L}:\$rel\" -Force; "  copied $rel\$n"
}
Dismount-VHD $Path
"ready: $Path   (attach to a Generation 2 VM, Secure Boot off, TPM on for Windows 11)"
