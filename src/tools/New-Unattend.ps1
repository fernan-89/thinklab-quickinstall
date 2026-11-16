# Generates the Windows answer files (one per kit) into <Out>\Unattend. Disk selection stays manual on purpose.
param([string]$SitePath, [string]$Out = (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path 'build\USB'))
. "$PSScriptRoot\QI.Common.ps1"
$ErrorActionPreference = 'Stop'
$site = Get-Site $SitePath; $cat = Get-Catalog
$dir = Join-Path $Out 'Unattend'; New-Item -ItemType Directory -Force $dir | Out-Null
function X($s) { [Security.SecurityElement]::Escape([string]$s) }
$pw = $site.site.initialPassword; $tz = $site.site.timezone
$count = 0; $kitId = 0; $kits = @()
foreach ($k in Get-WindowsKits $site $cat) {
  if ($k.Name -ne '*' -and $k.Name.Length -gt 15) { throw "computer name too long (NetBIOS 15): $($k.Name)" }
  $l = $script:Loc[$k.Lang]
  $isServer = $k.Os -eq 'S19'
  $user = if ($isServer) { 'Administrator' } else { $site.site.adminUser }
  $kitId++
  $kits += [ordered]@{ id = $kitId; file = $k.File; profile = $k.Profile; lang = $k.Lang; os = $k.Os; adminUser = $user; computerName = $k.Name; machine = $k.Machine; drivers = @($k.Drivers); oemModel = $k.FullName; wallpapers = @($k.Wallpapers); extraSoftware = @($k.ExtraSoftware) }
  # FirstLogonCommands accept at most ~259 characters: keep the command tiny and put every parameter in Scripts\kits.json (looked up by -K <id>).
  # It scans the drive letters (retrying ~6 min) for Scripts\FirstLogon.ps1 on the stick.
  $cmd = "powershell.exe -NoP -EP Bypass -C `"1..120|%{foreach(`$l in 67..90){`$p=[char]`$l+':\Scripts\FirstLogon.ps1';if(Test-Path `$p){& `$p -K $kitId;exit}};sleep 3}`""
  # Windows Server keeps the virtual/USB disk OFFLINE and does not auto-mount volumes: a first command brings disks online and gives the Ventoy partition a drive letter.
  $pre = ''
  if ($isServer) {
    $pc = 'powershell.exe -NoP -EP Bypass -C "Get-Disk|?{$_.IsOffline}|Set-Disk -IsOffline $false;sleep 5;Get-Volume -FileSystemLabel Ventoy|Get-Partition|Add-PartitionAccessPath -AssignDriveLetter"'
    $pre = "<SynchronousCommand wcm:action=`"add`"><Order>1</Order><Description>Mount install stick</Description><CommandLine>$(X $pc)</CommandLine></SynchronousCommand>`n        "
  }
  if ($cmd.Length -gt 250) { throw "FirstLogon command too long ($($cmd.Length))" }
  $account = if ($isServer) { "<UserAccounts><AdministratorPassword><Value>$(X $pw)</Value><PlainText>true</PlainText></AdministratorPassword></UserAccounts>" }
  else { "<UserAccounts><LocalAccounts><LocalAccount wcm:action=`"add`"><Name>$user</Name><Group>Administrators</Group><DisplayName>$user</DisplayName><Password><Value>$(X $pw)</Value><PlainText>true</PlainText></Password></LocalAccount></LocalAccounts></UserAccounts>" }
  $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<!-- $($k.Name) | $($k.Image) | $($k.Lang) | disk selection is intentionally manual (safety) -->
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <SetupUILanguage><UILanguage>$($l.Ui)</UILanguage></SetupUILanguage>
      <InputLocale>$($l.Input)</InputLocale><SystemLocale>$($l.Ui)</SystemLocale><UILanguage>$($l.Ui)</UILanguage><UserLocale>$($l.Ui)</UserLocale>
    </component>
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ImageInstall><OSImage>
        <InstallFrom><MetaData wcm:action="add"><Key>/IMAGE/NAME</Key><Value>$(X $k.Image)</Value></MetaData></InstallFrom>
      </OSImage></ImageInstall>
      <UserData><AcceptEula>true</AcceptEula><ProductKey><Key>$($k.Key)</Key><WillShowUI>OnError</WillShowUI></ProductKey></UserData>
    </component>
  </settings>
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ComputerName>$($k.Name)</ComputerName><TimeZone>$tz</TimeZone>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>$($l.Input)</InputLocale><SystemLocale>$($l.Ui)</SystemLocale><UILanguage>$($l.Ui)</UILanguage><UserLocale>$($l.Ui)</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <OOBE><HideEULAPage>true</HideEULAPage><HideOnlineAccountScreens>true</HideOnlineAccountScreens><HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE><ProtectYourPC>3</ProtectYourPC><NetworkLocation>Work</NetworkLocation></OOBE>
      $account
      <AutoLogon><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>$user</Username><Password><Value>$(X $pw)</Value><PlainText>true</PlainText></Password></AutoLogon>
      <FirstLogonCommands>
        $pre<SynchronousCommand wcm:action="add"><Order>$(if ($isServer) { 2 } else { 1 })</Order><Description>Quick-install post setup</Description><CommandLine>$(X $cmd)</CommandLine></SynchronousCommand>
      </FirstLogonCommands>
    </component>
  </settings>
</unattend>
"@
  $path = Join-Path $dir $k.File
  [IO.File]::WriteAllText($path, $xml, (New-Object Text.UTF8Encoding($false)))
  [xml](Get-Content $path -Raw) | Out-Null          # well-formedness check
  $count++
}
Write-Utf8 (Join-Path $Out 'Scripts\kits.json') ($kits | ConvertTo-Json -Depth 5)
"New-Unattend: $count Windows answer files -> $dir (+ Scripts\kits.json)"
