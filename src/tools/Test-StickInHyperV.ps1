<#
.SYNOPSIS
  Boot the physical Ventoy stick inside a Hyper-V VM (disk pass-through). Run in an ELEVATED PowerShell.

.EXAMPLE
  .\Test-StickInHyperV.ps1 -Mode UEFI          # Generation 2 VM, Secure Boot off, TPM on (for Windows 11 kits)
  .\Test-StickInHyperV.ps1 -Mode BIOS          # Generation 1 VM (legacy BIOS boot)
  .\Test-StickInHyperV.ps1 -Cleanup            # remove the VM(s) and bring the stick back online on the host

.NOTES
  * Hyper-V cannot pass a USB port to a VM, so the whole physical disk is attached (host sets it OFFLINE meanwhile).
  * The installs go to a separate 80 GB virtual disk, never to the stick. Do not unplug the stick while the VM runs.
#>
param(
  [ValidateSet('UEFI','BIOS')][string]$Mode = 'UEFI',
  [switch]$Cleanup,
  [int]$MemoryGB = 8,
  [int]$Cpus = 4,
  [string]$VmRoot = 'C:\VMs'
)
$ErrorActionPreference = 'Stop'
$idn = [Security.Principal.WindowsIdentity]::GetCurrent()
$elevated = ([Security.Principal.WindowsPrincipal]$idn).IsInRole('Administrator') -or ($idn.Groups | Where-Object { $_.Value -eq 'S-1-16-12288' }) -or ((whoami /groups) -match 'High Mandatory Level')   # High integrity level
if (-not $elevated) { throw 'Run this in an elevated (Administrator) PowerShell.' }
if (-not (Get-Command New-VM -ErrorAction SilentlyContinue)) { throw 'Hyper-V is not enabled. Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All, then reboot.' }

# --- locate the stick: USB disk that has the Ventoy + VTOYEFI volumes ---
$stick = Get-Disk | Where-Object { $_.BusType -eq 'USB' -and (Get-Partition -DiskNumber $_.Number -ErrorAction SilentlyContinue | Get-Volume -ErrorAction SilentlyContinue | Where-Object FileSystemLabel -in 'Ventoy','VTOYEFI') } | Select-Object -First 1
$names = 'VentoyTest-UEFI', 'VentoyTest-BIOS'

if ($Cleanup) {
  foreach ($n in $names) { if (Get-VM -Name $n -ErrorAction SilentlyContinue) { Stop-VM $n -TurnOff -Force -ErrorAction SilentlyContinue; Remove-VM $n -Force; "removed VM $n" } }
  if ($stick) { Set-Disk -Number $stick.Number -IsOffline $false -ErrorAction SilentlyContinue; "disk $($stick.Number) back online on the host" }
  Get-ChildItem $VmRoot -Filter 'VentoyTest-*.vhdx' -ErrorAction SilentlyContinue | Remove-Item -Force
  return
}

if (-not $stick) { throw 'Ventoy stick not found (USB disk with Ventoy/VTOYEFI volumes). Plug it in (and if it is already OFFLINE, set it online once so it can be detected).' }
if ($stick.Size -gt 200GB -or $stick.Size -lt 50GB) { throw "Unexpected disk size ($([math]::Round($stick.Size/1GB)) GB) - refusing." }
"Stick = disk $($stick.Number): $($stick.FriendlyName), $([math]::Round($stick.Size/1GB)) GB"

$name = "VentoyTest-$Mode"
if (Get-VM -Name $name -ErrorAction SilentlyContinue) { throw "VM $name already exists. Run -Cleanup first." }
New-Item -ItemType Directory -Force $VmRoot | Out-Null
$gen = if ($Mode -eq 'UEFI') { 2 } else { 1 }
$vm = New-VM -Name $name -Generation $gen -MemoryStartupBytes ($MemoryGB * 1GB) -NoVHD -Path $VmRoot
Set-VMProcessor $vm -Count $Cpus
Set-VMMemory $vm -DynamicMemoryEnabled $false
$sw = Get-VMSwitch | Where-Object { $_.Name -eq 'Default Switch' } | Select-Object -First 1
if ($sw) { Connect-VMNetworkAdapter -VMName $name -SwitchName $sw.Name }

# install target: a separate virtual disk (never the stick)
$target = Join-Path $VmRoot "$name-target.vhdx"
New-VHD -Path $target -SizeBytes 80GB -Dynamic | Out-Null
$ctl = if ($gen -eq 2) { 'SCSI' } else { 'IDE' }
Add-VMHardDiskDrive -VMName $name -ControllerType $ctl -Path $target

# the stick: physical pass-through disk (host must set it offline first)
Set-Disk -Number $stick.Number -IsOffline $true
Add-VMHardDiskDrive -VMName $name -ControllerType $ctl -DiskNumber $stick.Number

if ($gen -eq 2) {
  Set-VMFirmware -VMName $name -EnableSecureBoot Off          # Ventoy asks for MOK enrollment with Secure Boot on
  Set-VMKeyProtector -VMName $name -NewLocalKeyProtector
  Enable-VMTPM -VMName $name                                  # needed by the Windows 11 kits
  $first = Get-VMHardDiskDrive -VMName $name | Where-Object DiskNumber -eq $stick.Number
  Set-VMFirmware -VMName $name -FirstBootDevice $first
} else {
  Set-VMBios -VMName $name -StartupOrder @('IDE','CD','LegacyNetworkAdapter','Floppy')
  # on Gen 1 the stick must be first on the IDE controller: 0:0 = stick, 0:1 = target
  Get-VMHardDiskDrive -VMName $name | Remove-VMHardDiskDrive
  Add-VMHardDiskDrive -VMName $name -ControllerType IDE -ControllerNumber 0 -ControllerLocation 0 -DiskNumber $stick.Number
  Add-VMHardDiskDrive -VMName $name -ControllerType IDE -ControllerNumber 0 -ControllerLocation 1 -Path $target
}
Start-VM $name
vmconnect.exe localhost $name
"VM $name started. When finished:  .\Test-StickInHyperV.ps1 -Cleanup"
