# Verifies the stick against SHA256SUMS.txt (written by src\tools\New-Manifest.ps1). Run from the stick:  .\Scripts\Verify-Stick.ps1
param([string]$Root)
$ErrorActionPreference = 'Continue'
if (-not $Root) { $Root = (Get-Volume -FileSystemLabel 'Ventoy' -ErrorAction SilentlyContinue | Where-Object DriveLetter | Select-Object -First 1 | ForEach-Object { "$($_.DriveLetter):" }) }
if (-not $Root) { throw 'Ventoy stick not found' }
$sums = Join-Path $Root 'SHA256SUMS.txt'
if (-not (Test-Path $sums)) { throw "no SHA256SUMS.txt on $Root" }
function QuickHash($path, $len) {
  $fs = [IO.File]::OpenRead($path); try {
    $sha = [Security.Cryptography.SHA256]::Create(); $buf = New-Object byte[] (4MB)
    [void]$sha.TransformBlock([BitConverter]::GetBytes([int64]$len), 0, 8, $null, 0)
    $n = $fs.Read($buf, 0, $buf.Length); [void]$sha.TransformBlock($buf, 0, $n, $null, 0)
    [void]$fs.Seek([math]::Max(0, $len - 4MB), 'Begin'); $n = $fs.Read($buf, 0, $buf.Length); [void]$sha.TransformFinalBlock($buf, 0, $n)
    ([BitConverter]::ToString($sha.Hash) -replace '-', '').ToLower()
  } finally { $fs.Dispose() }
}
$bad = 0; $ok = 0; $missing = 0
foreach ($line in [IO.File]::ReadAllLines($sums)) {
  if ($line -notmatch '^(\S+) \*(.+)$') { continue }
  $want = $Matches[1]; $rel = $Matches[2]; $p = Join-Path $Root ($rel.Replace('/', '\'))
  if (-not (Test-Path -LiteralPath $p)) { Write-Host "MISSING  $rel" -ForegroundColor Red; $missing++; continue }
  $got = if ($want.StartsWith('q:')) { 'q:' + (QuickHash $p (Get-Item -LiteralPath $p).Length) } else { (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower() }
  if ($got -eq $want) { $ok++ } else { Write-Host "CORRUPT  $rel" -ForegroundColor Red; $bad++ }
}
Write-Host "verified: $ok ok, $bad corrupt, $missing missing" -ForegroundColor $(if ($bad -or $missing) { 'Red' } else { 'Green' })
exit $(if ($bad -or $missing) { 1 } else { 0 })
