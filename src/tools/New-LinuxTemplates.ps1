# Generates the AlmaLinux kickstarts and Ubuntu autoinstall files into <Out>\Unattend.
# Disk, user/password and (for Ubuntu) keyboard/network stay INTERACTIVE on purpose: nothing is wiped unasked.
param([string]$SitePath, [string]$Out = (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path 'build\USB'))
. "$PSScriptRoot\QI.Common.ps1"
$ErrorActionPreference = 'Stop'
$site = Get-Site $SitePath; $cat = Get-Catalog
$dir = Join-Path $Out 'Unattend'; New-Item -ItemType Directory -Force $dir | Out-Null
$tz = 'America/Sao_Paulo'
$n = 0

# Netdata on every Linux SERVER kit: a one-shot unit runs the official kickstart once the network is up (retries), then disables itself.
$ndScript = @'
#!/bin/sh
# ThinkLab Quick Install: install Netdata (stable) with the official kickstart script, once.
for i in $(seq 1 30); do
  curl -fsSL --max-time 60 https://get.netdata.cloud/kickstart.sh -o /tmp/netdata-kickstart.sh && break
  sleep 20
done
[ -s /tmp/netdata-kickstart.sh ] && sh /tmp/netdata-kickstart.sh --non-interactive --stable-channel --disable-telemetry   && systemctl disable netdata-firstboot.service
'@
$ndUnit = @'
[Unit]
Description=Install Netdata (ThinkLab Quick Install)
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
TimeoutStartSec=3600
ExecStart=/usr/local/sbin/netdata-firstboot.sh
[Install]
WantedBy=multi-user.target
'@
function B64($t) { $x = ($t.TrimEnd() + "`n") -replace "`r`n", "`n"; [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($x)) }
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
$(if ($k.Kind -eq 'server') { "`n%post --log=/root/ks-post-netdata.log`ncat > /usr/local/sbin/netdata-firstboot.sh <<'EOS'`n$($ndScript.TrimEnd())`nEOS`nchmod 755 /usr/local/sbin/netdata-firstboot.sh`ncat > /etc/systemd/system/netdata-firstboot.service <<'EOS'`n$($ndUnit.TrimEnd())`nEOS`nsystemctl enable netdata-firstboot.service`n%end" })
"@
  }
  else {   # ubuntu autoinstall
    $lc = @(); if ($k.Host) { $lc += "    - echo '$($k.Host)' > /target/etc/hostname" }
    if ($k.Kind -eq 'server') {
      $lc += "    - echo $(B64 $ndScript) | base64 -d > /target/usr/local/sbin/netdata-firstboot.sh"
      $lc += "    - chmod 755 /target/usr/local/sbin/netdata-firstboot.sh"
      $lc += "    - echo $(B64 $ndUnit) | base64 -d > /target/etc/systemd/system/netdata-firstboot.service"
      $lc += "    - curtin in-target --target=/target -- systemctl enable netdata-firstboot.service"
    }
    $late = if ($lc.Count) { "  late-commands:`n" + ($lc -join "`n") + "`n" } else { '' }
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
