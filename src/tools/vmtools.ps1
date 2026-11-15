Add-Type -AssemblyName System.Drawing
$script:ns = 'root\virtualization\v2'
function Snap($vmName, $path, [int]$W = 640, [int]$H = 480) {
  $vsms = Get-CimInstance -Namespace $ns -ClassName Msvm_VirtualSystemManagementService
  $cs = Get-CimInstance -Namespace $ns -ClassName Msvm_ComputerSystem -Filter "ElementName='$vmName'"
  $sd = Get-CimAssociatedInstance -InputObject $cs -ResultClassName Msvm_VirtualSystemSettingData | Where-Object VirtualSystemType -eq 'Microsoft:Hyper-V:System:Realized' | Select-Object -First 1
  $r = Invoke-CimMethod -InputObject $vsms -MethodName GetVirtualSystemThumbnailImage -Arguments @{ TargetSystem = $sd; WidthPixels = [uint16]$W; HeightPixels = [uint16]$H }
  $b = [byte[]]$r.ImageData
  $bmp = New-Object Drawing.Bitmap $W, $H, ([Drawing.Imaging.PixelFormat]::Format16bppRgb565)
  $bd = $bmp.LockBits((New-Object Drawing.Rectangle 0, 0, $W, $H), 'WriteOnly', $bmp.PixelFormat)
  $n = [int][math]::Min([int64]$b.Length, [int64]($bd.Stride * $H))
  [Runtime.InteropServices.Marshal]::Copy($b, 0, $bd.Scan0, $n); $bmp.UnlockBits($bd)
  $bmp.Save($path, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose(); "saved $path"
}
function Key($vmName, [int[]]$codes) {   # Windows virtual-key codes: DOWN=0x28 UP=0x26 ENTER=0x0D ESC=0x1B F2=0x71 F3=0x72 PGDN=0x22
  $cs = Get-CimInstance -Namespace $ns -ClassName Msvm_ComputerSystem -Filter "ElementName='$vmName'"
  $kb = Get-CimAssociatedInstance -InputObject $cs -ResultClassName Msvm_Keyboard
  foreach ($c in $codes) { [void](Invoke-CimMethod -InputObject $kb -MethodName TypeKey -Arguments @{ keyCode = [uint32]$c }); Start-Sleep -Milliseconds 250 }
}

# Creates a Generation 2 test VM: differencing disk over the test stick (the base stays pristine), blank target disk, TPM on, Secure Boot off.
function New-TlVm([string]$Name, [string]$StickVhdx = 'C:\VMs\T1.vhdx', [int]$Cpus = 4, [int]$MemGB = 8, [int]$TargetGB = 80, [string]$Dir = 'C:\VMs') {
  if (Get-VM -Name $Name -ErrorAction SilentlyContinue) { Stop-VM $Name -TurnOff -Force -ErrorAction SilentlyContinue; Remove-VM $Name -Force }
  foreach ($f in "$Dir\$Name-stick-diff.vhdx", "$Dir\$Name-target.vhdx") { Remove-Item $f -Force -ErrorAction SilentlyContinue }
  New-VHD -Path "$Dir\$Name-stick-diff.vhdx" -ParentPath $StickVhdx -Differencing | Out-Null
  New-VHD -Path "$Dir\$Name-target.vhdx" -SizeBytes ($TargetGB * 1GB) -Dynamic | Out-Null
  $vm = New-VM -Name $Name -Generation 2 -MemoryStartupBytes ($MemGB * 1GB) -NoVHD -Path $Dir
  Set-VMProcessor $vm -Count $Cpus; Set-VMMemory $vm -DynamicMemoryEnabled $false
  Set-VM -Name $Name -AutomaticCheckpointsEnabled $false -CheckpointType Disabled
  $sw = Get-VMSwitch | Where-Object Name -eq 'Default Switch' | Select-Object -First 1; if ($sw) { Connect-VMNetworkAdapter -VMName $Name -SwitchName $sw.Name }
  Add-VMHardDiskDrive -VMName $Name -ControllerType SCSI -Path "$Dir\$Name-stick-diff.vhdx"
  Add-VMHardDiskDrive -VMName $Name -ControllerType SCSI -Path "$Dir\$Name-target.vhdx"
  Set-VMFirmware -VMName $Name -EnableSecureBoot Off
  Set-VMKeyProtector -VMName $Name -NewLocalKeyProtector; Enable-VMTPM -VMName $Name
  Set-VMFirmware -VMName $Name -FirstBootDevice (Get-VMHardDiskDrive -VMName $Name | Select-Object -First 1)
  Start-VM $Name
}
# Reads the guest's C: from the target disk after the VM is turned off (read-only mount) and prints/returns the paths asked for.
function Get-TlGuestFile([string]$Name, [string[]]$Globs, [string]$Dir = 'C:\VMs') {
  Stop-VM $Name -TurnOff -Force -ErrorAction SilentlyContinue; Start-Sleep 3
  $vhd = "$Dir\$Name-target.vhdx"; $d = Mount-VHD -Path $vhd -ReadOnly -Passthru | Get-Disk; Start-Sleep 3
  try {
    $vol = Get-Partition -DiskNumber $d.Number | Get-Volume | Where-Object { $_.DriveLetter -and $_.FileSystem -eq 'NTFS' } | Sort-Object Size -Descending | Select-Object -First 1
    foreach ($g in $Globs) { Get-ChildItem (Join-Path "$($vol.DriveLetter):\" $g) -ErrorAction SilentlyContinue }
  } finally { }
  $script:LastMounted = $vhd
}
function Close-TlGuest { if ($script:LastMounted) { Dismount-VHD $script:LastMounted -ErrorAction SilentlyContinue; $script:LastMounted = $null } }