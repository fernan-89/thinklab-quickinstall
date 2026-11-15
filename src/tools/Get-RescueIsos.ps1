# Downloads the rescue / live ISOs from their official project sources and verifies the published checksums.
# Output: <Library>\iso\Rescue\<Name>\<final name>.iso  (final name = Product_Detail_Arch_Version_Language)
param([string]$Library = (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path 'library'), [string]$Log = "$env:TEMP\rescue-dl.log")
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; $ProgressPreference = 'SilentlyContinue'
$h = @{ 'User-Agent' = 'Mozilla/5.0' }
function L($m) { "$(Get-Date -Format 'HH:mm:ss')  $m" | Out-File $Log -Append -Encoding utf8 }
function Txt($url) { [Text.Encoding]::UTF8.GetString((Invoke-WebRequest $url -UseBasicParsing -Headers $h).RawContentStream.ToArray()) }
function Fetch($url, $dir, $tmpName, $final, $algo, $expected) {
  New-Item -ItemType Directory -Force $dir | Out-Null
  $dst = Join-Path $dir $final
  if (Test-Path $dst) { L "skip (exists) $final"; return }
  $tmp = Join-Path $dir $tmpName
  L "download $final ..."
  Invoke-WebRequest $url -OutFile $tmp -UseBasicParsing -Headers $h -TimeoutSec 7200
  $got = (Get-FileHash $tmp -Algorithm $algo).Hash.ToLower()
  if ($got -eq $expected.ToLower()) { Rename-Item $tmp $final; L "OK $algo $final" } else { L "CHECKSUM MISMATCH $final (expected $expected got $got) - left as $tmpName" }
}
try {
  # Hiren's BootCD PE (official site; SHA-256 printed on the download page)
  $t = (Invoke-WebRequest 'https://www.hirensbootcd.org/download/' -UseBasicParsing -Headers $h).Content -replace '<[^>]+>', ' '
  $hb = [regex]::Match($t, 'ISO\s+SHA-256\s+([0-9a-fA-F]{64})').Groups[1].Value
  if (-not $hb) { throw "Hiren's SHA-256 not found on the page" }
  Fetch 'https://www.hirensbootcd.org/files/HBCD_PE_x64.iso' "$Library\iso\Rescue\HirensBootCD-PE" 'HBCD_PE_x64.iso' 'HirensBootCD-PE_x64_20240305_Multi.iso' 'SHA256' $hb

  # SystemRescue (project site .sha256 file)
  $sr = ([regex]::Match((Txt 'https://www.system-rescue.org/releases/13.03/systemrescue-13.03-amd64.iso.sha256'), '([0-9a-f]{64})')).Groups[1].Value
  Fetch 'https://fastly-cdn.system-rescue.org/releases/13.03/systemrescue-13.03-amd64.iso' "$Library\iso\Rescue\SystemRescue" 'systemrescue-13.03-amd64.iso' 'SystemRescue_x64_13.03_Multi.iso' 'SHA256' $sr

  # GParted Live + Clonezilla Live (official downloads are hosted on NCHC; SHA256SUMS next to the ISO)
  foreach ($p in @(
    @{ B = 'https://free.nchc.org.tw/gparted-live/stable'; F = 'gparted-live-1.8.1-3-amd64.iso'; D = 'GParted-Live'; N = 'GParted-Live_x64_1.8.1-3_Multi.iso' },
    @{ B = 'https://free.nchc.org.tw/clonezilla-live/stable'; F = 'clonezilla-live-3.3.3-37-amd64.iso'; D = 'Clonezilla-Live'; N = 'Clonezilla-Live_x64_3.3.3-37_Multi.iso' })) {
    $sums = Txt "$($p.B)/SHA256SUMS"
    $e = ([regex]::Match($sums, "([0-9a-f]{64})\s+\*?$([regex]::Escape($p.F))")).Groups[1].Value
    if (-not $e) { throw "no checksum for $($p.F)" }
    Fetch "$($p.B)/$($p.F)" "$Library\iso\Rescue\$($p.D)" $p.F $p.N 'SHA256' $e
  }

  # MemTest86+ (ISO is inside a zip; sha256sum.txt on the project site)
  $mt = ([regex]::Match((Txt 'https://memtest.org/download/v9.00/sha256sum.txt'), '([0-9a-f]{64})\s+\S*mt86plus_9\.00_x86_64\.iso\.zip')).Groups[1].Value
  $md = "$Library\iso\Rescue\MemTest86Plus"; $mf = 'MemTest86Plus_x64_9.00_Multi.iso'
  if (-not (Test-Path "$md\$mf")) {
    New-Item -ItemType Directory -Force $md | Out-Null
    $zip = "$md\mt86plus_9.00_x86_64.iso.zip"
    Invoke-WebRequest 'https://memtest.org/download/v9.00/mt86plus_9.00_x86_64.iso.zip' -OutFile $zip -UseBasicParsing -Headers $h
    if ((Get-FileHash $zip -Algorithm SHA256).Hash.ToLower() -ne $mt) { throw 'MemTest86+ zip checksum mismatch' }
    Expand-Archive $zip "$md\x" -Force
    Move-Item (Get-ChildItem "$md\x" -Filter *.iso -Recurse | Select-Object -First 1).FullName "$md\$mf"
    Remove-Item "$md\x" -Recurse -Force; Remove-Item $zip -Force; L "OK SHA256 $mf"
  }
  L 'ALL DONE'
} catch { L "FAILED: $($_.Exception.Message)" }
