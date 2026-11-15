# Generates the AlmaLinux kickstarts and Ubuntu autoinstall files into <Out>\Unattend.
# Disk, user/password and (for Ubuntu) keyboard/network stay INTERACTIVE on purpose: nothing is wiped unasked.
param([string]$SitePath, [string]$Out = (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path 'build\USB'))
. "$PSScriptRoot\QI.Common.ps1"
$ErrorActionPreference = 'Stop'
$site = Get-Site $SitePath; $cat = Get-Catalog
$dir = Join-Path $Out 'Unattend'; New-Item -ItemType Directory -Force $dir | Out-Null
$tz = 'America/Sao_Paulo'
$n = 0
foreach ($k in Get-LinuxKits $site $cat) {
  $l = $script:Loc[$k.Lang]
  if ($k.Distro -eq 'alma') {
    $env = if ($k.Kind -eq 'desktop') { '@^workstation-product-environment' } else { '@^server-product-environment' }
    $role = if ($k.Kind -eq 'desktop') { 'Workstation' } else { 'Server' }
    $net = if ($k.Host) { "network --bootproto=dhcp --hostname=$($k.Host) --activate" } else { 'network --bootproto=dhcp --activate' }
    $hdr = if ($k.Host) { $k.Host } else { 'BASE' }
    $text = @"
# $hdr | AlmaLinux 10.2 $role | $($k.Machine) | $($l.Tag)
# Disk (installation destination), root/user and anything not listed here are asked by the installer.
eula --agreed
lang $($l.LinuxLang)
keyboard --vckeymap=$($l.Kbd) --xlayouts='$($l.Kbd)'
timezone $tz --utc
$net
firstboot --enable

%packages
$env
git
curl
vim-enhanced
htop
%end
"@
  }
  else {   # ubuntu autoinstall
    $late = if ($k.Host) { "  late-commands:`n    - echo '$($k.Host)' > /target/etc/hostname`n" } else { '' }
    $text = @"
#cloud-config
# $(if ($k.Host) { $k.Host } else { 'BASE' }) | Ubuntu Server 26.04.1 LTS | $($k.Machine) | English
# Interactive on purpose: identity (user/password), storage (which disk is wiped), network, keyboard.
autoinstall:
  version: 1
  refresh-installer:
    update: no
  locale: en_US.UTF-8
  timezone: $tz
  interactive-sections:
    - keyboard
    - network
    - storage
    - identity
  ssh:
    install-server: true
    allow-pw: true
  packages:
    - curl
    - git
    - htop
    - vim
    - net-tools
  updates: security
$late
"@
  }
  [IO.File]::WriteAllText((Join-Path $dir $k.File), (($text.TrimEnd() + "`n") -replace "`r`n", "`n"), (New-Object Text.UTF8Encoding($false)))
  $n++
}
"New-LinuxTemplates: $n Linux templates -> $dir"
