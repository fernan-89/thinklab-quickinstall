# ThinkLab Quick Install - post-install, runs at the first logon from the Ventoy stick (Scripts\FirstLogon.ps1).
# Profile-driven (see config/software.json -> Scripts\kit.json). Everything is best-effort and logged: a failing step never stops the next one.
param(
  [int]$K = -1,                      # kit id: the answer file passes only this (its command line is limited to ~259 characters); the rest comes from kits.json
  [ValidateSet('Full', 'DevBasic', 'Office', 'Base', 'Server')][string]$Profile,
  [ValidateSet('EN', 'PT')][string]$Lang,
  [ValidateSet('W10', 'W11', 'S19', 'L21', 'I10', 'L24')][string]$OS,
  [string]$Drivers = '',
  [string]$AdminUser = 'admin'
)
$ErrorActionPreference = 'Continue'
if ($K -ge 0) {
  $kk = (Get-Content (Join-Path $PSScriptRoot 'kits.json') -Raw -Encoding UTF8 | ConvertFrom-Json) | Where-Object { $_.id -eq $K } | Select-Object -First 1
  if (-not $kk) { throw "kit id $K not found in kits.json" }
  $Profile = $kk.profile; $Lang = $kk.lang; $OS = $kk.os; $AdminUser = $kk.adminUser; $Drivers = (@($kk.drivers) -join ';')
}
if (-not $Profile -or -not $Lang -or -not $OS) { throw 'usage: FirstLogon.ps1 -K <kit id>   or   -Profile .. -Lang .. -OS ..' }
$LogDir = 'C:\QuickInstall'; New-Item -ItemType Directory -Force $LogDir | Out-Null
Start-Transcript -Path "$LogDir\FirstLogon-$Profile-$OS-$Lang.log" -Append | Out-Null
$LangTag = if ($Lang -eq 'PT') { 'pt-BR' } else { 'en-US' }
function Step($t) { Write-Host ("`n=== {0}  [{1}]" -f $t, (Get-Date -Format 'HH:mm:ss')) -ForegroundColor Cyan }

# ---- kit definition (software, profiles, Office products) ----
$kit = Get-Content (Join-Path $PSScriptRoot 'kit.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$prof = $kit.software.profiles.$Profile
if (-not $prof) { Write-Warning "unknown profile $Profile"; $prof = [pscustomobject]@{ office = $false; software = @() } }

# ---- locate the Ventoy data partition ----
$Root = $null
for ($i = 0; $i -lt 30 -and -not $Root; $i++) {
  $v = Get-Volume -FileSystemLabel 'Ventoy' -ErrorAction SilentlyContinue | Where-Object DriveLetter | Select-Object -First 1
  if ($v) { $Root = "$($v.DriveLetter):" } else { Start-Sleep 5 }
}
if (-not $Root) { Write-Warning 'Ventoy stick not found - only winget steps will run.' }
Write-Host "Stick root: $Root   profile=$Profile os=$OS lang=$Lang"

function Run($file, $arguments, [int]$timeoutMin = 20, [switch]$NoWait, [switch]$Kill) {
  if (-not (Test-Path -LiteralPath $file)) { Write-Warning "missing: $file"; return $false }
  Write-Host "run: $(Split-Path $file -Leaf) $arguments"
  try {
    $p = if ($arguments) { Start-Process -FilePath $file -ArgumentList $arguments -PassThru } else { Start-Process -FilePath $file -PassThru }
    if ($NoWait) { return $true }
    if (-not $p.WaitForExit($timeoutMin * 60000)) { Write-Warning "timeout, continuing: $file"; if ($Kill) { & taskkill.exe /PID $p.Id /T /F | Out-Null; Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -match 'Acrobat Reader' } | Stop-Process -Force -ErrorAction SilentlyContinue }; return $false }
    Write-Host "exit code: $($p.ExitCode)"; return ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010)
  } catch { Write-Warning $_.Exception.Message; return $false }
}
$HasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
function Winget($id, $locale, [int]$Minutes = 12) {
  if (-not $HasWinget) { Write-Warning "winget not available - pending: $id"; return $false }
  Write-Host "winget: $id"
  $a = @('install', '--id', $id, '-e', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'); if ($locale) { $a += @('--locale', $locale) }
  # run with a watchdog: some vendor installers (e.g. Adobe) finish but keep a "Done" window open and winget never returns
  try {
    $p = Start-Process winget -ArgumentList $a -PassThru -NoNewWindow
    if ($p.WaitForExit($Minutes * 60000)) { return ($p.ExitCode -eq 0) }
    Write-Warning "winget $id still running after $Minutes min - assuming the installer finished and closing it"
    & taskkill.exe /PID $p.Id /T /F | Out-Null
    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -match 'Acrobat Reader' } | Stop-Process -Force -ErrorAction SilentlyContinue
    return $true
  } catch { Write-Warning $_.Exception.Message; return $false }
}

# ---- 1. drivers (pnputil; 'pack:' entries are self-extracting vendor packs) ----
Step 'Drivers'
if ($OS -eq 'S19') { Install-WindowsFeature -Name Wireless-Networking -ErrorAction SilentlyContinue | Out-Null }
if ($Root -and $Drivers) {
  foreach ($d in ($Drivers -split ';' | Where-Object { $_ })) {
    if ($d.StartsWith('pack:')) {
      $exe = Join-Path $Root $d.Substring(5); $ex = Join-Path $LogDir ('pack-' + [IO.Path]::GetFileNameWithoutExtension($exe))
      if (Run $exe "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=`"$ex`"" 30) { if (Test-Path $ex) { Write-Host "pnputil: $ex"; pnputil.exe /add-driver "$ex\*.inf" /subdirs /install | Out-Null } }
    } else {
      $path = Join-Path $Root $d
      if (Test-Path $path) { Write-Host "pnputil: $d"; pnputil.exe /add-driver "$path\*.inf" /subdirs /install | Out-Null } else { Write-Warning "driver folder missing: $d" }
    }
  }
}

# ---- 2. Office (Office Deployment Tool + bilingual offline payload; the product IDs decide 2021 vs 2024) ----
if ($prof.office -and $OS -ne 'S19' -and $Root) {
  Step 'Office'
  $year = if ($OS -in 'W11', 'L24') { '2024' } else { '2021' }
  $odt = Join-Path $Root 'Office\_ODT\setup.exe'
  $bundle = Get-ChildItem (Join-Path $Root 'Office\pt-BR') -Directory -Filter 'Office-Retail-CurrentChannel_*' -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not (Test-Path $odt) -or -not $bundle) { Write-Warning 'Office payload or ODT missing on the stick (Office\_ODT\setup.exe, Office\pt-BR\Office-Retail-CurrentChannel_*)' }
  else {
    try {
      $langs = if ($Lang -eq 'PT') { '<Language ID="pt-br"/>' } else { '<Language ID="en-us"/>' }
      $prod = (@($kit.office.$year) | ForEach-Object { "<Product ID=`"$_`">$langs</Product>" }) -join ''
      $cfg = "<Configuration><Add SourcePath=`"$($bundle.FullName)`" OfficeClientEdition=`"64`">$prod</Add><Display Level=`"None`" AcceptEULA=`"TRUE`"/><Property Name=`"PinIconsToTaskbar`" Value=`"FALSE`"/></Configuration>"
      $cfgFile = "$LogDir\office-$year-$Lang.xml"; Set-Content $cfgFile $cfg -Encoding UTF8
      [void](Run $odt "/configure `"$cfgFile`"" 90)
    } catch { Write-Warning $_.Exception.Message }
  }
  Write-Host 'NOTE: Retail Office needs your product keys / Microsoft account to activate.'
}

# ---- 3. software (profile list) ----
$sw = if ($Root) { Join-Path $Root 'Software' } else { $null }
function Install-Item($it) {
  Write-Host "-- $($it.name)"
  if ($it.PSObject.Properties.Name -contains 'onlyWithoutWinget' -and $it.onlyWithoutWinget -and $HasWinget) { return }
  $wg = if ($it.PSObject.Properties.Name -contains 'winget') { $it.winget } else { $null }
  $loc = if ($it.PSObject.Properties.Name -contains 'wingetLocale' -and $Lang -eq 'PT') { $it.wingetLocale } else { $null }
  if ($wg -and $it.PSObject.Properties.Name -contains 'preferWingetFor' -and ($it.preferWingetFor -contains $Lang) -and $HasWinget) { if (Winget $wg $loc) { return } }
  $file = $null
  if ($sw -and $it.PSObject.Properties.Name -contains 'filter') {
    $pattern = $it.filter.Replace('{LANGTAG}', $LangTag)
    $file = Get-ChildItem -Path (Join-Path $sw $pattern) -ErrorAction SilentlyContinue | Select-Object -First 1
  }
  if (-not $file) { if ($wg) { [void](Winget $wg $loc) } else { Write-Warning "no installer for $($it.name)" }; return }
  $kind = if ($it.PSObject.Properties.Name -contains 'kind') { $it.kind } else { 'exe' }
  $min = if ($it.PSObject.Properties.Name -contains 'minutes') { [int]$it.minutes } else { 20 }
  $args_ = if ($it.PSObject.Properties.Name -contains 'args') { $it.args } else { '' }
  switch ($kind) {
    'msi' { [void](Run 'msiexec.exe' "/i `"$($file.FullName)`" /qn /norestart" 20) }
    'zip' {
      try {
        $dst = [Environment]::ExpandEnvironmentVariables($it.extractTo); New-Item -ItemType Directory -Force $dst | Out-Null
        Expand-Archive -LiteralPath $file.FullName -DestinationPath $dst -Force
        if ($it.PSObject.Properties.Name -contains 'addToPath' -and $it.addToPath) { $mp = [Environment]::GetEnvironmentVariable('Path', 'Machine'); if ($mp -notlike "*$dst*") { [Environment]::SetEnvironmentVariable('Path', "$mp;$dst", 'Machine') } }
        Write-Host "extracted to $dst"
      } catch { Write-Warning $_.Exception.Message; if ($wg) { [void](Winget $wg $null) } }
    }
    default { $nw = ($it.PSObject.Properties.Name -contains 'noWait' -and $it.noWait); $kl = ($it.PSObject.Properties.Name -contains 'killOnTimeout' -and $it.killOnTimeout); [void](Run $file.FullName $args_ $min -NoWait:$nw -Kill:$kl) }
  }
  if ($it.PSObject.Properties.Name -contains 'copyAfter') {
    $to = [Environment]::ExpandEnvironmentVariables($it.copyAfter.to); New-Item -ItemType Directory -Force $to | Out-Null
    Copy-Item (Join-Path $sw $it.copyAfter.from) $to -Force -ErrorAction SilentlyContinue
  }
}
if (@($prof.software).Count -gt 0 -or ($kk -and @($kk.extraSoftware).Count -gt 0)) {
  Step "Software ($Profile)"
  $ids = @($prof.software) + @(if ($kk) { $kk.extraSoftware }) | Where-Object { $_ } | Select-Object -Unique   # extraSoftware: per-kit additions from config\site.json
  foreach ($id in $ids) {
    $it = $kit.software.items | Where-Object { $_.id -eq $id } | Select-Object -First 1
    if ($it) { try { Install-Item $it } catch { Write-Warning $_.Exception.Message } } else { Write-Warning "unknown software id $id" }
  }
}

# ---- 3b. branding: OEM information (System Properties page) + wallpapers ----
# OEM info lives in HKLM\...\OEMInformation (Manufacturer, Model, Logo = 120x120 .bmp, Support*). We never touch the BIOS identity values.
Step 'Branding'
try {
  $oem = if ($kit.PSObject.Properties.Name -contains 'oem') { $kit.oem } else { $null }
  if ($oem -and $oem.manufacturer) {
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'; New-Item -Path $key -Force | Out-Null
    $logo = $null; if ($Root -and (Test-Path (Join-Path $Root 'Scripts\oem\ThinkLab-oem.bmp'))) { $logo = "$env:windir\System32\ThinkLab-oem.bmp"; Copy-Item (Join-Path $Root 'Scripts\oem\ThinkLab-oem.bmp') $logo -Force }
    $model = if ($kk -and $kk.oemModel) { "$($kk.oemModel) - $env:COMPUTERNAME" } else { $env:COMPUTERNAME }
    Set-ItemProperty $key Manufacturer $oem.manufacturer; Set-ItemProperty $key Model $model
    if ($logo) { Set-ItemProperty $key Logo $logo }
    foreach ($p in 'supportHours', 'supportPhone', 'supportURL') { if ($oem.PSObject.Properties.Name -contains $p -and $oem.$p) { Set-ItemProperty $key ($p.Substring(0, 1).ToUpper() + $p.Substring(1)) $oem.$p } }
    Write-Host "OEM information: $($oem.manufacturer) / $model"
  }
  $wall = if ($Root) { Join-Path $Root 'Wallpapers' } else { $null }
  if ($wall -and (Test-Path $wall) -and $kk -and $kk.machine -ne 'BASE') {
    $dest = "$env:windir\Web\Wallpaper\ThinkLab"
    foreach ($f in @($kk.machine) + @($kk.wallpapers)) {
      if ($f -and (Test-Path (Join-Path $wall $f))) { New-Item -ItemType Directory -Force "$dest\$f" | Out-Null; Copy-Item (Join-Path $wall "$f\*") "$dest\$f" -Recurse -Force; Write-Host "wallpapers: $f" }
    }
    $def = Get-ChildItem "$dest\$($kk.machine)" -Filter 'ThinkLab-*-Dark.png' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($def) {
      # default wallpaper for this user and for every new profile (Default user hive)
      Set-ItemProperty 'HKCU:\Control Panel\Desktop' Wallpaper $def.FullName; Set-ItemProperty 'HKCU:\Control Panel\Desktop' WallpaperStyle '10'; Set-ItemProperty 'HKCU:\Control Panel\Desktop' TileWallpaper '0'
      Add-Type -Namespace TL -Name Wp -MemberDefinition '[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int SystemParametersInfo(int a, int b, string c, int d);'
      [void][TL.Wp]::SystemParametersInfo(20, 0, $def.FullName, 3)
      reg load HKU\TLDefault "$env:SystemDrive\Users\Default\NTUSER.DAT" 2>$null | Out-Null
      if (Test-Path 'Registry::HKU\TLDefault') { reg add 'HKU\TLDefault\Control Panel\Desktop' /v Wallpaper /t REG_SZ /d $def.FullName /f | Out-Null; reg add 'HKU\TLDefault\Control Panel\Desktop' /v WallpaperStyle /t REG_SZ /d 10 /f | Out-Null; [gc]::Collect(); reg unload HKU\TLDefault 2>$null | Out-Null }
      # a slideshow theme over all of this machine's wallpapers (apply it from Settings > Personalization > Themes)
      $theme = "[Theme]`r`nDisplayName=ThinkLab`r`n[Control Panel\Desktop]`r`nWallpaper=$($def.FullName)`r`nTileWallpaper=0`r`nWallpaperStyle=10`r`n[Slideshow]`r`nInterval=1800000`r`nShuffle=1`r`nImagesRootPath=$dest`r`n"
      Set-Content "$env:windir\Resources\Themes\ThinkLab.theme" $theme -Encoding Unicode
      Write-Host "default wallpaper: $($def.Name)"
    }
  }
} catch { Write-Warning $_.Exception.Message }

# ---- 4. inventory (a small JSON per machine; handy to import into an asset registry) ----
Step 'Inventory'
try {
  $cs = Get-CimInstance Win32_ComputerSystem; $bios = Get-CimInstance Win32_BIOS; $osv = Get-CimInstance Win32_OperatingSystem
  $inv = [ordered]@{ computerName = $env:COMPUTERNAME; manufacturer = $cs.Manufacturer; model = $cs.Model; serial = $bios.SerialNumber; os = $osv.Caption; build = $osv.BuildNumber
    profile = $Profile; language = $Lang; installedAt = (Get-Date).ToString('s'); kit = 'thinklab-quickinstall' }
  $json = $inv | ConvertTo-Json
  Set-Content "$LogDir\inventory.json" $json -Encoding UTF8
  if ($Root) { $idir = Join-Path $Root 'Inventory'; New-Item -ItemType Directory -Force $idir | Out-Null; Set-Content (Join-Path $idir "$($env:COMPUTERNAME).json") $json -Encoding UTF8 }
  Write-Host "inventory written ($($env:COMPUTERNAME))"
} catch { Write-Warning $_.Exception.Message }

# ---- 5. force a password change at the next logon (the initial password is only a bootstrap) ----
Step 'Password policy'
try { net user $AdminUser /logonpasswordchg:yes | Out-Null; Write-Host "$AdminUser must change the password at the next logon" } catch { Write-Warning $_.Exception.Message }

Step 'Done'
Write-Host "Log: $LogDir. Reboot now (Docker/WSL, drivers, Office)." -ForegroundColor Green
Stop-Transcript | Out-Null
