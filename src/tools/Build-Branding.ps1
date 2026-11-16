# Generates the branding assets of the kit (own artwork, no vendor logos):
#   build\USB\Scripts\oem\ThinkLab-oem.bmp        120x120 logo shown in System Properties (OEM information)
#   build\USB\Wallpapers\<machine code>\*.png      ThinkLab wallpapers per machine (3840x2160): Dark, Orange and a "family" one
# Official vendor wallpapers (vendor logos and wallpapers) are NOT generated here: put them in <library>\wallpapers\<folder>\
# and list the folders per machine in config\site.json ("wallpapers"); Publish-Stick.ps1 copies them to the stick.   ASCII only.
param([string]$SitePath, [string]$Out = (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path 'build\USB'))
. "$PSScriptRoot\QI.Common.ps1"
Add-Type -AssemblyName System.Drawing
. "$PSScriptRoot\Blueprint.ps1"
. "$PSScriptRoot\Tape.ps1"
$ErrorActionPreference = 'Stop'
$site = Get-Site $SitePath
function C($hex, $a = 255) { $h = $hex.TrimStart('#'); [Drawing.Color]::FromArgb($a, [Convert]::ToInt32($h.Substring(0,2),16), [Convert]::ToInt32($h.Substring(2,2),16), [Convert]::ToInt32($h.Substring(4,2),16)) }
$BRAND = '#e95420'
function RoundRect($g, $brush, $x, $y, $w, $h, $r) {
  $p = New-Object Drawing.Drawing2D.GraphicsPath
  $p.AddArc($x, $y, $r*2, $r*2, 180, 90); $p.AddArc($x+$w-$r*2, $y, $r*2, $r*2, 270, 90)
  $p.AddArc($x+$w-$r*2, $y+$h-$r*2, $r*2, $r*2, 0, 90); $p.AddArc($x, $y+$h-$r*2, $r*2, $r*2, 90, 90); $p.CloseFigure()
  $g.FillPath($brush, $p); $p.Dispose()
}
function Mark($g, $x, $y, $size, $fill = $BRAND) {
  $br = New-Object Drawing.SolidBrush (C $fill); RoundRect $g $br $x $y $size $size ([int]($size/8)); $br.Dispose()
  $pen = New-Object Drawing.Pen ([Drawing.Color]::White), ([single]($size/9)); $d = $size * 0.52; $o = ($size - $d) / 2
  $g.DrawEllipse($pen, [single]($x+$o), [single]($y+$o), [single]$d, [single]$d); $pen.Dispose()
  $wb = New-Object Drawing.SolidBrush ([Drawing.Color]::White); $r = $size * 0.11; $g.FillEllipse($wb, [single]($x+$size/2-$r), [single]($y+$size/2-$r), [single]($r*2), [single]($r*2)); $wb.Dispose()
}

# ---- OEM logo: 120x120 24-bit BMP, white background (the System page is light) ----
$od = Join-Path $Out 'Scripts\oem'; New-Item -ItemType Directory -Force $od | Out-Null
$b = New-Object Drawing.Bitmap 120, 120, ([Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [Drawing.Graphics]::FromImage($b); $g.SmoothingMode = 'AntiAlias'; $g.Clear([Drawing.Color]::White)
Mark $g 10 10 100; $g.Dispose(); $b.Save("$od\ThinkLab-oem.bmp", [Drawing.Imaging.ImageFormat]::Bmp); $b.Dispose()

# ---- wallpapers ----
$W = 3840; $H = 2160
function NewCanvas { $bm = New-Object Drawing.Bitmap $W, $H, ([Drawing.Imaging.PixelFormat]::Format24bppRgb); $gg = [Drawing.Graphics]::FromImage($bm); $gg.SmoothingMode = 'AntiAlias'; $gg.TextRenderingHint = 'AntiAliasGridFit'; @($bm, $gg) }
function Save($bm, $path) { $bm.Save($path, [Drawing.Imaging.ImageFormat]::Png); $bm.Dispose() }
$fBig = New-Object Drawing.Font 'Segoe UI Light', 150; $fMid = New-Object Drawing.Font 'Segoe UI', 44; $fSmall = New-Object Drawing.Font 'Segoe UI', 30
$white = New-Object Drawing.SolidBrush ([Drawing.Color]::White); $muted = New-Object Drawing.SolidBrush (C '#a8a8a8'); $fade = New-Object Drawing.SolidBrush (C '#ffffff' 150)
$n = 0
foreach ($m in $site.machines) {
  $dir = Join-Path $Out "Wallpapers\$($m.code)"; New-Item -ItemType Directory -Force $dir | Out-Null
  $family = Get-Prop $m 'family'; $title = $m.label; $sub = $m.fullName

  # 1) Dark
  $bm, $gg = NewCanvas
  $gg.Clear((C '#111111'))
  $gg.FillRectangle((New-Object Drawing.SolidBrush (C '#1e1e1e')), 0, 1500, $W, 660)
  $gg.FillRectangle((New-Object Drawing.SolidBrush (C $BRAND)), 0, 1500, $W, 8)
  Mark $gg 320 1620 300
  $gg.DrawString('ThinkLab', $fBig, $white, 680, 1560); $gg.DrawString($title, $fMid, $muted, 700, 1840); $gg.DrawString($sub, $fSmall, $muted, 704, 1920)
  $gg.Dispose(); Save $bm (Join-Path $dir "ThinkLab-$($m.label -replace '[^A-Za-z0-9]','')-Dark.png"); $n++

  # 2) Orange
  $bm, $gg = NewCanvas
  $br = New-Object Drawing.Drawing2D.LinearGradientBrush ((New-Object Drawing.Rectangle 0, 0, $W, $H), (C '#e95420'), (C '#7a1f10'), 35.0)
  $gg.FillRectangle($br, 0, 0, $W, $H); $br.Dispose()
  Mark $gg 3300 120 260 '#111111'
  $gg.DrawString('ThinkLab', $fBig, $white, 300, 1560); $gg.DrawString("$title  |  $sub", $fMid, $fade, 310, 1840)
  $gg.Dispose(); Save $bm (Join-Path $dir "ThinkLab-$($m.label -replace '[^A-Za-z0-9]','')-Orange.png"); $n++

  # 3) Family (own typography; vendor logos are never drawn)
  if ($family) {
    $bm, $gg = NewCanvas
    $gg.Clear((C '#0b0b0b'))
    $dot = if ($family -match 'Pad') { '#e2231a' } elseif ($family -match 'Station') { '#1b6fd1' } else { '#7a7a7a' }
    $gg.FillEllipse((New-Object Drawing.SolidBrush (C $dot)), 3200, 1850, 90, 90)
    $gg.DrawString($family, $fBig, $white, 300, 820); $gg.DrawString($sub, $fMid, $muted, 310, 1110)
    $gg.DrawString('ThinkLab', $fSmall, $muted, 310, 1960); Mark $gg 3420 1830 130
    $gg.Dispose(); Save $bm (Join-Path $dir "ThinkLab-$($family -replace '[^A-Za-z0-9]','')-$($m.label -replace '[^A-Za-z0-9]','').png"); $n++
  }
}
# exploded-view wallpapers (own line art; see Blueprint.ps1): dark, light, X-ray and sunset - per machine and per system (BASE)
$bpStyles = @(@('Exploded-Dark', 'dark', 'Line'), @('Exploded-Light', 'light', 'Line'), @('Exploded-XRay', 'dark', 'XRay'), @('Exploded-Sunset', 'dark', 'Sunset'))
foreach ($m in $site.machines) {
  $dir = Join-Path $Out "Wallpapers\$($m.code)"; $lbl = $m.label -replace '[^A-Za-z0-9]', ''
  foreach ($bs in $bpStyles) { New-Blueprint -Machine $m -Scheme $bs[1] -Style $bs[2] -Out (Join-Path $dir "ThinkLab-$lbl-$($bs[0]).png"); $n++ }
}
$sysArt = [ordered]@{ W10 = @('Windows 10', 'laptop'); W11 = @('Windows 11', 'laptop'); L21 = @('Windows 10 LTSC 2021', 'tiny'); I10 = @('Windows 10 IoT', 'tiny-fanless'); L24 = @('Windows 11 LTSC 2024', 'tiny'); S19 = @('Windows Server 2019', 'tower') }
foreach ($lx in (Get-Catalog).linux) { $sysArt[$lx.id] = @((($lx.label -split ' - ')[0] -replace '\s*\([^)]*\)', ''), $(if ($lx.id -eq 'ubuntu') { 'tower' } else { 'laptop' })) }
$fakeM = [pscustomobject]@{ label = 'BASE'; fullName = 'BASE' }
foreach ($sys in $sysArt.Keys) {
  foreach ($bs in $bpStyles) { New-Blueprint -Machine $fakeM -Scheme $bs[1] -Style $bs[2] -Type $sysArt[$sys][1] -Label $sysArt[$sys][0] -Out (Join-Path $Out "Wallpapers\BASE\ThinkLab-$sys-$($bs[0]).png"); $n++ }
}
# retro "tape" wallpapers per machine (stripe bands and diagonal blocks in the ThinkLab palette; see Tape.ps1)
foreach ($m in $site.machines) {
  $dir = Join-Path $Out "Wallpapers\$($m.code)"; $lbl = $m.label -replace '[^A-Za-z0-9]', ''
  foreach ($st in 'Sunset', 'SunsetLight', 'Diagonal', 'Teal') { New-TapeWallpaper -Machine $m -Style $st -Out (Join-Path $dir "ThinkLab-$lbl-Tape-$st.png"); $n++ }
}
# the same tape set for the generic BASE kits: one per Windows system in the catalog (the label is the system)
$osLabel = @{ W10 = 'Windows 10'; W11 = 'Windows 11'; L21 = 'LTSC 2021'; I10 = 'IoT 10'; L24 = 'LTSC 2024'; S19 = 'Server 2019' }
$cat = Get-Catalog; $bdir = Join-Path $Out 'Wallpapers\BASE'
foreach ($os in @($cat.windows | ForEach-Object { $_.os } | Select-Object -Unique)) {
  $w = $cat.windows | Where-Object { $_.os -eq $os } | Select-Object -First 1
  $fake = [pscustomobject]@{ label = $(if ($osLabel.ContainsKey($os)) { $osLabel[$os] } else { $os }); fullName = (($w.label -split ' - ')[0]) }
  foreach ($st in 'Sunset', 'SunsetLight', 'Diagonal', 'Teal') { New-TapeWallpaper -Machine $fake -Style $st -Out (Join-Path $bdir "ThinkLab-$os-Tape-$st.png"); $n++ }
}
"Build-Branding: OEM logo + $n wallpapers -> $Out"
