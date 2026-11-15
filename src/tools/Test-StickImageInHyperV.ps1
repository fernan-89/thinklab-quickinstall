<#
.SYNOPSIS
  Hyper-V cannot pass a removable USB flash drive through to a VM. This script makes a raw, byte-for-byte
  copy of the Ventoy stick into a fixed VHD and boots THAT in a Generation 1 (legacy BIOS) VM.
  Run in an ELEVATED PowerShell. Read-only on the stick (removable USB flash drives cannot be set offline, so it is read while mounted; do not write to E: meanwhile).
#>
param([string]$VmRoot = 'C:\VMs', [int]$MemoryGB = 8, [int]$Cpus = 4, [string]$Log = "$env:TEMP\stick-image.log")
$ErrorActionPreference = 'Stop'
function L($m) { "$(Get-Date -Format 'HH:mm:ss')  $m" | Tee-Object -FilePath $Log -Append | Write-Host }
"" | Set-Content $Log

$stick = Get-Disk | Where-Object { $_.BusType -eq 'USB' -and (Get-Partition -DiskNumber $_.Number -ErrorAction SilentlyContinue | Get-Volume -ErrorAction SilentlyContinue | Where-Object FileSystemLabel -in 'Ventoy','VTOYEFI') } | Select-Object -First 1
if (-not $stick) { throw 'Ventoy stick not found' }
if ($stick.Size -gt 200GB -or $stick.Size -lt 50GB) { throw 'unexpected disk size' }
L "stick = disk $($stick.Number) $($stick.FriendlyName) $($stick.Size) bytes"

New-Item -ItemType Directory -Force $VmRoot | Out-Null
$vhd = Join-Path $VmRoot 'VentoyStick.vhd'
$sizeMB = [int64][math]::Ceiling($stick.Size / 1MB) + 2
if (Test-Path $vhd) { Remove-Item $vhd -Force }
L "creating fixed VHD ($sizeMB MB) ..."
New-VHD -Path $vhd -Fixed -SizeBytes ($sizeMB * 1MB) | Out-Null

Add-Type -TypeDefinition @'
using System; using System.IO; using System.Runtime.InteropServices; using Microsoft.Win32.SafeHandles;
public static class RawDisk {
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr sec, uint disp, uint flags, IntPtr tmpl);
  public static FileStream OpenRead(string path) {
    var h = CreateFile(path, 0x80000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
    if (h.IsInvalid) throw new IOException("CreateFile failed: " + Marshal.GetLastWin32Error());
    return new FileStream(h, FileAccess.Read, 4 * 1024 * 1024, false);
  }
}
'@
try {
  $src = [RawDisk]::OpenRead("\\.\PhysicalDrive$($stick.Number)")
  $dst = [IO.File]::Open($vhd, 'Open', 'Write', 'None')
  $buf = New-Object byte[] (4MB); $total = [int64]$stick.Size; $done = [int64]0; $next = 0
  L 'copying raw disk -> VHD ...'
  while ($done -lt $total) {
    $want = [int][math]::Min([int64]$buf.Length, [int64]($total - $done))
    $want = [int]([math]::Ceiling($want / 512.0) * 512)               # sector (512 B) aligned; the disk size is not a multiple of 4096
    $n = $src.Read($buf, 0, $want)
    if ($n -le 0) { break }
    $w = [int][math]::Min([int64]$n, [int64]($total - $done))
    $dst.Write($buf, 0, $w); $done += $w
    if ($done -ge $next) { L ('{0:N1} / {1:N1} GiB' -f ($done / 1GB), ($total / 1GB)); $next = $done + 5GB }
  }
  $dst.Flush(); $dst.Dispose(); $src.Dispose()
  L "copy finished: $done bytes"
} finally { L 'raw read finished' }

$name = 'VentoyTest-BIOS'
if (Get-VM -Name $name -ErrorAction SilentlyContinue) { Stop-VM $name -TurnOff -Force -ErrorAction SilentlyContinue; Remove-VM $name -Force }
$vm = New-VM -Name $name -Generation 1 -MemoryStartupBytes ($MemoryGB * 1GB) -NoVHD -Path $VmRoot
Set-VMProcessor $vm -Count $Cpus; Set-VMMemory $vm -DynamicMemoryEnabled $false
$sw = Get-VMSwitch | Where-Object Name -eq 'Default Switch' | Select-Object -First 1
if ($sw) { Connect-VMNetworkAdapter -VMName $name -SwitchName $sw.Name }
$target = Join-Path $VmRoot "$name-target.vhdx"
if (-not (Test-Path $target)) { New-VHD -Path $target -SizeBytes 80GB -Dynamic | Out-Null }
Add-VMHardDiskDrive -VMName $name -ControllerType IDE -ControllerNumber 0 -ControllerLocation 0 -Path $vhd
Add-VMHardDiskDrive -VMName $name -ControllerType IDE -ControllerNumber 0 -ControllerLocation 1 -Path $target
Set-VMBios -VMName $name -StartupOrder @('IDE', 'CD', 'LegacyNetworkAdapter', 'Floppy')
Start-VM $name
L "VM $name started"
L 'DONE'
