# Writes SHA256SUMS.txt at the root of the stick ("<hash> *<relative path>"). Verify later with Scripts\Verify-Stick.ps1.
# Full hashing of ~100 GB takes a while; -Quick hashes only size + first/last 4 MiB of files bigger than 64 MiB.
param([Parameter(Mandatory)][string]$Stick, [switch]$Quick)
$ErrorActionPreference = 'Stop'
$Stick = $Stick.TrimEnd('\'); if ($Stick.Length -eq 1) { $Stick += ':' }
if ((Get-Volume -DriveLetter $Stick.Substring(0, 1)).FileSystemLabel -ne 'Ventoy') { throw 'not a Ventoy stick' }
$files = Get-ChildItem "$Stick\" -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\System Volume Information\\' -and $_.Name -ne 'SHA256SUMS.txt' } | Sort-Object FullName
$total = ($files | Measure-Object Length -Sum).Sum; $done = 0; $lines = New-Object Collections.Generic.List[string]; $t0 = Get-Date
function QuickHash($f) {
  $fs = [IO.File]::OpenRead($f.FullName); try {
    $sha = [Security.Cryptography.SHA256]::Create(); $buf = New-Object byte[] (4MB)
    [void]$sha.TransformBlock([BitConverter]::GetBytes([int64]$f.Length), 0, 8, $null, 0)
    $n = $fs.Read($buf, 0, $buf.Length); [void]$sha.TransformBlock($buf, 0, $n, $null, 0)
    [void]$fs.Seek([math]::Max(0, $f.Length - 4MB), 'Begin'); $n = $fs.Read($buf, 0, $buf.Length); [void]$sha.TransformFinalBlock($buf, 0, $n)
    ([BitConverter]::ToString($sha.Hash) -replace '-', '').ToLower()
  } finally { $fs.Dispose() }
}
foreach ($f in $files) {
  $h = if ($Quick -and $f.Length -gt 64MB) { 'q:' + (QuickHash $f) } else { (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower() }
  $lines.Add("$h *$($f.FullName.Substring($Stick.Length + 1).Replace('\', '/'))")
  $done += $f.Length
  if ($lines.Count % 25 -eq 0) { Write-Host ('{0:N1} / {1:N1} GiB  ({2:N0} min)' -f ($done / 1GB), ($total / 1GB), ((Get-Date) - $t0).TotalMinutes) }
}
[IO.File]::WriteAllLines("$Stick\SHA256SUMS.txt", $lines, (New-Object Text.UTF8Encoding($false)))
"SHA256SUMS.txt: $($lines.Count) files, $([math]::Round($total/1GB,1)) GiB, mode $(if ($Quick) { 'quick' } else { 'full' })"
