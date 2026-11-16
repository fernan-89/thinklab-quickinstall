# Repo checks (run before every commit; also wired as a git pre-commit hook in .githooks/):
#   1. every PowerShell file parses
#   2. the example site builds a complete kit (answer files well-formed, every template referenced by ventoy.json exists, names <= 15 chars)
#   3. PRIVACY: no personal / machine identifiers in any tracked or staged file (patterns: built-in generic ones + config\privacy-terms.local.txt)
param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing   # Blueprint.ps1 declares a class with System.Drawing members: load it before parsing
$repo = (Resolve-Path "$PSScriptRoot\..").Path; Set-Location $repo
$fail = 0
function Fail($m) { Write-Host "FAIL  $m" -ForegroundColor Red; $script:fail++ }
function Pass($m) { Write-Host "ok    $m" -ForegroundColor Green }

# 1 --- syntax
foreach ($f in Get-ChildItem "$repo\src", "$repo\tests" -Recurse -Filter *.ps1) {
  $e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$e)
  if ($e.Count) { Fail "syntax: $($f.Name): $($e[0].Message)" }
}
if (-not $fail) { Pass 'all PowerShell files parse' }

# 2 --- example build
if (-not $SkipBuild) {
  $out = Join-Path $env:TEMP 'qi-test-build'; Remove-Item $out -Recurse -Force -ErrorAction SilentlyContinue
  try {
    & "$repo\src\tools\New-Kit.ps1" -SitePath "$repo\config\site.example.json" -Out $out | Out-Null
    $xml = Get-ChildItem "$out\Unattend" -Filter *.xml
    foreach ($x in $xml) { try { [xml](Get-Content $x.FullName -Raw) | Out-Null } catch { Fail "XML not well-formed: $($x.Name)" } }
    $j = Get-Content "$out\ventoy\ventoy.json" -Raw | ConvertFrom-Json
    $miss = @($j.auto_install.template | ForEach-Object { $_ } | Where-Object { -not (Test-Path (Join-Path $out $_.TrimStart('/'))) })
    if ($miss.Count) { Fail "ventoy.json references missing templates: $($miss -join ', ')" } else { Pass "ventoy.json: $(@($j.auto_install.template | ForEach-Object { $_ }).Count) templates, none missing" }
    if ((Get-Content "$out\ventoy\ventoy.json" -Raw) -match 'VTOY_MENU_TIMEOUT"\s*:\s*"0"') { Fail 'VTOY_MENU_TIMEOUT=0 boots the first image immediately' }
    $names = $xml | ForEach-Object { [regex]::Match((Get-Content $_.FullName -Raw), '<ComputerName>([^<]+)</ComputerName>').Groups[1].Value }
    if ($names | Where-Object { $_ -ne '*' -and $_.Length -gt 15 }) { Fail 'computer name longer than 15 characters' } else { Pass "$($xml.Count) answer files, computer names <= 15" }
    if (-not (Test-Path "$out\Scripts\FirstLogon.ps1") -or -not (Test-Path "$out\Scripts\kit.json")) { Fail 'Scripts incomplete' } else { Pass 'Scripts\FirstLogon.ps1 + kit.json present' }
    if ((Get-ChildItem "$out\Docs" -Recurse -Filter *.html).Count -lt 20) { Fail 'docs incomplete' } else { Pass 'bilingual docs built' }
  } catch { Fail "example build: $($_.Exception.Message)" }
}

# 3 --- privacy
$generic = @('[A-Za-z0-9._%+-]+@(?!users\.noreply\.github\.com)[A-Za-z0-9.-]+\.[A-Za-z]{2,}', 'C:\\Users\\[A-Za-z0-9._-]+', '\b(?:10|192\.168|172\.(?:1[6-9]|2\d|3[01]))\.\d{1,3}\.\d{1,3}(?:\.\d{1,3})?\b')
$local = @(); $lp = Join-Path $repo 'config\privacy-terms.local.txt'
if (Test-Path $lp) { $local = Get-Content $lp | Where-Object { $_.Trim() -and -not $_.StartsWith('#') } }
$files = @(git ls-files) + @(git diff --cached --name-only) | Sort-Object -Unique | Where-Object { $_ -and (Test-Path $_) }
$hits = @()
foreach ($f in $files) {
  if ($f -match '\.(png|zip|ico|ttf|otf|pf2)$') { continue }   # binary files (bundled OFL fonts, images)
  $lines = Get-Content $f -ErrorAction SilentlyContinue; $n = 0
  foreach ($l in $lines) {
    $n++
    foreach ($p in $generic) { if ($l -match $p) { $hits += "$f`:$n  (pattern) $($Matches[0])" } }
    foreach ($t in $local) { if ($l -like "*$t*") { $hits += "$f`:$n  (private term) $t" } }
  }
}
if ($hits.Count) { $hits | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }; Fail "privacy: $($hits.Count) possible identifiers in tracked files" } else { Pass "privacy: no identifiers in $($files.Count) tracked files$(if (-not $local) { ' (only generic patterns - add config\privacy-terms.local.txt)' })" }
if ((git ls-files 'config/site.json' 'build' 'library') ) { Fail 'private/binary paths are tracked (config/site.json, build/, library/)' }
if ($fail) { Write-Host "`n$fail check(s) failed" -ForegroundColor Red; exit 1 } else { Write-Host "`nall checks passed" -ForegroundColor Green }
