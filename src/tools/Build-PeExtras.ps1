# Builds ventoy\inject\ThinkLab-PE-Extras.zip: files that Ventoy's injection plugin unpacks at X:\ inside Hiren's BootCD PE.
# Result inside the PE:  X:\ThinkLab\*.cmd  +  desktop shortcuts.  ASCII only. Windows PowerShell 5.1.
param(
  [string]$Stage = (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path 'build\USB'),
  [string[]]$DesktopDirs = @('Users\Public\Desktop'),     # where the shortcuts are unpacked (relative to X:\)
  [string]$Prefix = ''
)
$ErrorActionPreference = 'Stop'
$work = Join-Path $env:TEMP 'tl-pe-extras'; Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$work\ThinkLab" | Out-Null

# ---- shared helper: find the Ventoy data volume ----
@'
@echo off
rem sets STICK to the drive letter of the volume labelled Ventoy
set STICK=
for %%d in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
  if exist %%d:\ventoy\ventoy.json if exist %%d:\Drivers set STICK=%%d:
)
if "%STICK%"=="" (echo ThinkLab stick not found. & pause & exit /b 1)
'@ | Set-Content "$work\ThinkLab\_stick.cmd" -Encoding ASCII

# ---- 1) offline docs ----
@'
@echo off
call "%~dp0_stick.cmd" || exit /b 1
if exist "%STICK%\Docs\index.html" (start "" "%STICK%\Docs\index.html") else echo Docs folder not found on %STICK%
'@ | Set-Content "$work\ThinkLab\ThinkLab-Docs.cmd" -Encoding ASCII

# ---- 2) load drivers from the stick into this PE session ----
@'
@echo off
setlocal enabledelayedexpansion
call "%~dp0_stick.cmd" || exit /b 1
echo ThinkLab - load drivers from %STICK%\Drivers into this Windows Live session
echo.
set i=0
for /d %%m in ("%STICK%\Drivers\*") do (
  set /a i+=1
  set "m!i!=%%m"
  echo   !i!^) %%~nxm
)
echo.
set /p pick=Number of the machine (empty = cancel):
if "%pick%"=="" exit /b
call set "dir=%%m%pick%%%"
if not defined dir (echo invalid choice & pause & exit /b 1)
echo Loading all .inf under !dir! ... this can take a few minutes.
pnputil /add-driver "!dir!\*.inf" /subdirs /install
echo.
echo Done. Use Device Manager / PENetwork to check network and disks.
pause
'@ | Set-Content "$work\ThinkLab\Load-StickDrivers.cmd" -Encoding ASCII

# ---- 3) export the drivers of an OFFLINE Windows to the stick (backup before a reinstall) ----
@'
@echo off
setlocal enabledelayedexpansion
call "%~dp0_stick.cmd" || exit /b 1
echo ThinkLab - export drivers of an installed (offline) Windows to the stick
echo.
echo Windows installations found:
for %%d in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
  if exist %%d:\Windows\System32\config\SYSTEM echo   %%d:
)
echo.
set /p win=Drive letter of the Windows to read (empty = cancel):
if "%win%"=="" exit /b
set "out=%STICK%\Drivers\_Exported\%COMPUTERNAME%-%DATE:~-4%%DATE:~3,2%%DATE:~0,2%"
mkdir "%out%" 2>nul
dism /Image:%win%:\ /Export-Driver /Destination:"%out%"
echo.
echo Exported to %out%
pause
'@ | Set-Content "$work\ThinkLab\Export-WindowsDrivers.cmd" -Encoding ASCII

# ---- 4) copy the installer logs of a finished install to the stick ----
@'
@echo off
call "%~dp0_stick.cmd" || exit /b 1
set /p win=Drive letter of the installed Windows (empty = cancel):
if "%win%"=="" exit /b
mkdir "%STICK%\Logs" 2>nul
xcopy "%win%:\QuickInstall\*" "%STICK%\Logs\%COMPUTERNAME%\" /E /I /Y
pause
'@ | Set-Content "$work\ThinkLab\Collect-InstallLogs.cmd" -Encoding ASCII

@'
ThinkLab tools inside Hiren's BootCD PE
---------------------------------------
ThinkLab-Docs.cmd          offline documentation of the stick (pt/en)
Load-StickDrivers.cmd      load the stick's driver pack of a machine into this PE session (network, storage...)
Export-WindowsDrivers.cmd  export the drivers of an installed Windows to Drivers\_Exported on the stick
Collect-InstallLogs.cmd    copy C:\QuickInstall logs of an installed Windows to Logs\ on the stick
'@ | Set-Content "$work\ThinkLab\README.txt" -Encoding ASCII

# ---- desktop shortcuts ----
$sh = New-Object -ComObject WScript.Shell
foreach ($dd in $DesktopDirs) {
  $dir = Join-Path $work $dd; New-Item -ItemType Directory -Force $dir | Out-Null
  foreach ($t in @(@('ThinkLab Docs', 'ThinkLab-Docs.cmd'), @('ThinkLab - Load stick drivers', 'Load-StickDrivers.cmd'), @('ThinkLab - Export Windows drivers', 'Export-WindowsDrivers.cmd'), @('ThinkLab - Collect install logs', 'Collect-InstallLogs.cmd'))) {
    $l = $sh.CreateShortcut((Join-Path $dir ("$Prefix$($t[0]).lnk")))
    $l.TargetPath = "X:\ThinkLab\$($t[1])"; $l.WorkingDirectory = 'X:\ThinkLab'; $l.IconLocation = 'X:\Windows\System32\shell32.dll,21'; $l.Save()
  }
}
$zip = "$Stage\ventoy\inject\ThinkLab-PE-Extras.zip"
New-Item -ItemType Directory -Force (Split-Path $zip) | Out-Null; Remove-Item $zip -Force -ErrorAction SilentlyContinue
Compress-Archive -Path "$work\*" -DestinationPath $zip -CompressionLevel Optimal
"built $zip ($([math]::Round((Get-Item $zip).Length/1KB)) KB)"
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::OpenRead($zip).Entries | ForEach-Object { '  ' + $_.FullName }
