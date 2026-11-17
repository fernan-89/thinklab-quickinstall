# Wallpapers for a smartphone (portrait) in the ThinkLab line: isometric exploded view (own artwork, no vendor logos or
# manual images) in four looks - Dark, Light, XRay, Sunset - plus the four "tape" looks (Sunset, SunsetLight, Diagonal, Teal).
#   .\Build-PhoneWallpapers.ps1 -Out <folder> [-Label THINKPHONE] [-FullName "Phone model line"] [-Sizes 1080x2400,1440x3200]
# Reuses the BP class (Blueprint.ps1) and the tape helpers (Tape.ps1). ASCII only.
param(
  [string]$Out = (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path 'build\Phone'),
  [string]$Label = 'THINKPHONE',
  [string]$FullName = 'Smartphone (Android)',
  [string[]]$Sizes = @('1080x2400', '1440x3200')
)
. "$PSScriptRoot\QI.Common.ps1"
Add-Type -AssemblyName System.Drawing
. "$PSScriptRoot\Blueprint.ps1"
. "$PSScriptRoot\Tape.ps1"
$ErrorActionPreference = 'Stop'

function PhHex($h, $a = 255) { $x = $h.TrimStart('#'); [Drawing.Color]::FromArgb($a, [Convert]::ToInt32($x.Substring(0, 2), 16), [Convert]::ToInt32($x.Substring(2, 2), 16), [Convert]::ToInt32($x.Substring(4, 2), 16)) }

# the exploded phone: five layers on one vertical axis (back cover, battery + coil, board + cameras, display, glass) and a side key
function Draw-Phone($b, [bool]$labels) {
  $W = 150; $D = 320
  $zc = 0; $zb = 150; $zp = 300; $zd = 450; $zg = 600
  # dashed guides between the layers (three visible corners)
  foreach ($c in @(@($W, $D), @($W, 0), @(0, $D))) { foreach ($z in @(@(5, $zb), @(($zb + 7), $zp), @(($zp + 4), $zd), @(($zd + 6), $zg))) { $b.Link(@($c[0], $c[1], $z[0]), @($c[0], $c[1], $z[1])) } }
  # 1 back cover: slab, camera island with three lenses and a flash, wireless-charging ring
  $b.Box(0, 0, $zc, $W, $D, 5, $false)
  $b.Box(14, 14, ($zc + 5), 66, 66, 3, $false)
  foreach ($c in @(@(32, 32), @(62, 32), @(47, 60))) { $b.Circle($c[0], $c[1], ($zc + 8), 11, $true, $false); $b.Circle($c[0], $c[1], ($zc + 8), 4.5, $false, $true) }
  $b.Circle(66, 62, ($zc + 8), 3, $false, $true)
  $b.Circle(75, 215, ($zc + 5), 46, $false, $true); $b.Circle(75, 215, ($zc + 5), 30, $false, $true); $b.Circle(75, 215, ($zc + 5), 14, $false, $true)
  # 2 battery with cell lines and a flex connector
  $b.Box(14, 130, $zb, 122, 160, 7, $false)
  foreach ($i in 1, 2) { $b.Line(@((14 + $i * 122 / 3), 130, ($zb + 7)), @((14 + $i * 122 / 3), 290, ($zb + 7)), $true) }
  $b.Box(56, 112, ($zb + 1), 38, 18, 2, $true)
  # 3 mid frame (wire), board with SoC and chips, two camera modules
  $b.Wire(0, 0, $zp, $W, $D, 4)
  $b.Poly(@(@(8, 8, ($zp + 4)), @(($W - 8), 8, ($zp + 4)), @(($W - 8), ($D - 8), ($zp + 4)), @(8, ($D - 8), ($zp + 4))), $false, $true)
  $b.Box(10, 100, ($zp + 1), 130, 120, 3, $false)
  $b.Box(46, 128, ($zp + 4), 40, 40, 5, $false); $b.Box(54, 136, ($zp + 9), 24, 24, 1.5, $true)
  $b.Box(100, 130, ($zp + 4), 28, 18, 4, $true); $b.Box(100, 160, ($zp + 4), 28, 28, 4, $true); $b.Box(16, 190, ($zp + 4), 60, 14, 3, $true)
  $b.Cyl(34, 40, ($zp + 1), 17, 18); $b.Cyl(76, 40, ($zp + 1), 12, 14)
  $b.Cable(@(@(34, 62, ($zp + 4)), @(40, 92, ($zp + 7)), @(60, 124, ($zp + 5))))
  # 4 display panel: punch-hole camera, active area
  $b.Box(0, 0, $zd, $W, $D, 6, $false)
  $b.Poly(@(@(8, 14, ($zd + 6)), @(($W - 8), 14, ($zd + 6)), @(($W - 8), ($D - 10), ($zd + 6)), @(8, ($D - 10), ($zd + 6))), $false, $true)
  $b.Circle(75, 12, ($zd + 6), 3.4, $false, $true)
  $b.Box(54, $D, ($zd + 1), 42, 26, 1.5, $true)
  # 5 cover glass: thin plate, earpiece slot
  $b.Box(0, 0, $zg, $W, $D, 2, $false)
  $b.Line(@(54, 6, ($zg + 2)), @(96, 6, ($zg + 2)), $true)
  # side keys: volume rocker and the red key
  $b.Box(168, 70, ($zp + 10), 8, 50, 12, $false); $b.Box(168, 140, ($zp + 10), 8, 30, 12, $false); $b.NubDot(172, 155, ($zp + 22.5), 3.4)
  $b.Link(@(150, 95, ($zp + 16)), @(168, 95, ($zp + 16))); $b.Link(@(150, 155, ($zp + 16)), @(168, 155, ($zp + 16)))
  if ($labels) {
    $b.Tag($W, 0, ($zg + 2), 'GLASS'); $b.Tag($W, 0, ($zd + 6), 'DISPLAY'); $b.Tag($W, 0, ($zp + 4), 'BOARD + CAMERAS')
    $b.Tag($W, 0, ($zb + 7), 'BATTERY + COIL'); $b.Tag($W, 0, ($zc + 5), 'BACK COVER'); $b.Tag(176, 155, ($zp + 22), 'RED KEY')
  }
}

function New-PhoneBlueprint([string]$Scheme, [string]$Style, [string]$Out, [int]$Width, [int]$Height) {
  $pal = Get-Palette 'desktop' $Scheme
  $k = $Width / 1080.0
  $bgC = PhHex $pal.background; $lineC = PhHex $pal.onSurface; $nubC = PhHex $pal.nub; $brandC = PhHex $pal.'seed-brand'; $mutedC = PhHex $pal.onSurfaceVariant; $fillC = $bgC
  if ($Style -eq 'XRay') { $bgC = PhHex '#061321'; $lineC = PhHex '#CFF6FF'; $mutedC = PhHex '#7FB8D6'; $fillC = PhHex '#071726' 205; $nubC = PhHex '#FF5A4E' }
  if ($Style -eq 'Sunset') { $bgC = PhHex '#0B0B0C'; $lineC = PhHex '#F5F5F5'; $mutedC = PhHex '#A8A8A8'; $fillC = $bgC }
  $bmp = New-Object Drawing.Bitmap $Width, $Height, ([Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.Clear($bgC)
  switch ($Style) {
    'XRay' { $gb = New-Object Drawing.Drawing2D.LinearGradientBrush ((New-Object Drawing.Rectangle 0, 0, $Width, $Height), (PhHex '#04101C'), (PhHex '#0B2036'), 90.0); $g.FillRectangle($gb, 0, 0, $Width, $Height); $gb.Dispose() }
    'Sunset' { $y = 1800 * $k
      foreach ($c in '#FEC514', '#FF8A2B', '#E95420', '#F04E98', '#7A3FA0') { $sb = New-Object Drawing.SolidBrush (PhHex $c); $x1 = (720 * $k) - ($y - 1800 * $k)
        $g.FillPolygon($sb, [Drawing.PointF[]]@((New-Object Drawing.PointF 0, ([single]$y)), (New-Object Drawing.PointF ([single]$x1), ([single]$y)), (New-Object Drawing.PointF ([single]($x1 - 54 * $k)), ([single]($y + 54 * $k))), (New-Object Drawing.PointF 0, ([single]($y + 54 * $k))))); $sb.Dispose(); $y += 54 * $k } }
    default { $dotB = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(26, $lineC)); $step = [int](22 * $k + 0.5)       # halftone, fading toward the lower left
      for ($yy = 10; $yy -lt $Height; $yy += $step) { for ($xx = 10; $xx -lt $Width; $xx += $step) { $f = [Math]::Max(0, ($xx / $Width) * 0.8 + (1 - $yy / $Height) * 0.5 - 0.35); $r = (0.9 + 1.9 * [Math]::Min(1, $f)) * $k; $g.FillEllipse($dotB, [single]($xx - $r), [single]($yy - $r), [single](2 * $r), [single](2 * $r)) } }
      $dotB.Dispose() }
  }
  $s = 1.55 * $k; $ox = $Width * 0.45; $ym = $Height * 0.50; $oy = $ym + 186.5 * $s
  $lw = 0.95 * $k
  $passes = @()
  if ($Style -eq 'XRay') { $passes += , ([BP]::new($g, (PhHex '#2FD2FF' 24), [Drawing.Color]::Transparent, [Drawing.Color]::Transparent, $s, $ox, $oy, 5.0 * $lw)); $passes += , ([BP]::new($g, (PhHex '#2FD2FF' 46), [Drawing.Color]::Transparent, [Drawing.Color]::Transparent, $s, $ox, $oy, 2.6 * $lw)) }
  $passes += , ([BP]::new($g, $lineC, $fillC, $nubC, $s, $ox, $oy, $lw))
  $last = $passes[-1]; $last.Font = BpFont 'IBM Plex Mono SemiBold' (27 * $k); $last.Ink = New-Object Drawing.SolidBrush $mutedC
  foreach ($bp in $passes) { Draw-Phone $bp ($bp -eq $last) }
  # title block (bottom left) and brand tab (right edge), as in the landscape set
  $sf = [Drawing.StringFormat]::GenericTypographic.Clone(); $sf.FormatFlags = $sf.FormatFlags -bor [Drawing.StringFormatFlags]::MeasureTrailingSpaces
  $f1 = BpFont 'Barlow Condensed SemiBold' (104 * $k); $f2 = BpFont 'IBM Plex Mono' (34 * $k); $inkB = New-Object Drawing.SolidBrush $lineC; $mutB = New-Object Drawing.SolidBrush $mutedC
  $x0 = 70 * $k; $yb = $Height - 330 * $k
  $g.DrawString('ThinkLab', $f1, $inkB, [single]$x0, [single]$yb, $sf)
  $wf = $g.MeasureString('ThinkLab', $f1, (New-Object Drawing.PointF 0, 0), $sf).Width
  $nb = New-Object Drawing.SolidBrush $nubC; $g.FillEllipse($nb, [single]($x0 + $wf + 8 * $k), [single]($yb + 76 * $k), [single](20 * $k), [single](20 * $k))
  $g.DrawString($Label.ToUpper(), $f2, $mutB, [single]($x0 + $wf + 46 * $k), [single]($yb + 66 * $k), $sf)
  $tab = New-Object Drawing.SolidBrush $brandC; $g.FillRectangle($tab, [single]($Width - 60 * $k), [single]($Height - 640 * $k), [single](60 * $k), [single](300 * $k))
  $st = New-Object Drawing.StringFormat; $st.Alignment = 'Center'; $st.LineAlignment = 'Center'
  $g.TranslateTransform([single]($Width - 30 * $k), [single]($Height - 490 * $k)); $g.RotateTransform(-90)
  $g.DrawString('ThinkLab', (BpFont 'Barlow Condensed SemiBold' (44 * $k)), [Drawing.Brushes]::White, 0, 0, $st); $g.ResetTransform()
  $g.Dispose(); New-Item -ItemType Directory -Force (Split-Path $Out -Parent) | Out-Null
  $bmp.Save($Out, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}

# portrait "tape" looks: stripe bands, a diagonal block, teal chevrons (same palette and fonts as Tape.ps1)
function New-PhoneTape([string]$Style, [string]$Out, [int]$Width, [int]$Height) {
  $k = $Width / 1080.0; $light = $Style -eq 'SunsetLight'
  $bg = if ($light) { '#F2F0EA' } elseif ($Style -eq 'Teal') { '#141416' } else { '#0B0B0C' }
  $ink = if ($light) { TapeColor '#141414' } else { TapeColor '#F5F5F5' }; $mut = if ($light) { TapeColor '#5F5F5F' } else { TapeColor '#A8A8A8' }
  $brand = '#E95420'; $nub = '#E2231A'
  $bmp = New-Object Drawing.Bitmap $Width, $Height, ([Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.Clear((TapeColor $bg))
  $lab = $Label.ToUpper()
  $fBrand = TapeFont 'Barlow Condensed SemiBold' (104 * $k); $fMono = TapeFont 'IBM Plex Mono' (28 * $k); $fMonoB = TapeFont 'IBM Plex Mono SemiBold' (26 * $k)
  switch -Wildcard ($Style) {
    'Sunset*' {
      $y = 1560 * $k
      foreach ($c in '#FEC514', '#FF8A2B', $brand, '#F04E98', '#7A3FA0') { $b = New-Object Drawing.SolidBrush (TapeColor $c); $g.FillRectangle($b, 0, [single]$y, $Width, [single](54 * $k)); $b.Dispose(); $y += 54 * $k }
      [void](TapeText $g 'ThinkLab' $fBrand $ink (70 * $k) (1100 * $k))
      [void](TapeText $g $lab (TapeFit $g $lab 'Barlow Condensed Light' (260 * $k) (940 * $k)) $ink (66 * $k) (1210 * $k))
      $nb = New-Object Drawing.SolidBrush (TapeColor $nub)
      for ($r = 0; $r -lt 6; $r++) { for ($c = 0; $c -lt 6; $c++) { if (($r + (5 - $c)) -le 6) { $g.FillEllipse($nb, [single]($Width - (90 + $c * 30) * $k), [single]((1000 + $r * 30 - 600) * $k + 600 * $k), [single](16 * $k), [single](16 * $k)) } } }
      $nb.Dispose()
    }
    'Diagonal' {
      $b = New-Object Drawing.SolidBrush (TapeColor $brand)
      $g.FillPolygon($b, [Drawing.PointF[]]@((New-Object Drawing.PointF 0, ([single](1180 * $k))), (New-Object Drawing.PointF ([single]$Width), ([single](780 * $k))), (New-Object Drawing.PointF ([single]$Width), ([single](1420 * $k))), (New-Object Drawing.PointF 0, ([single](1820 * $k))))); $b.Dispose()
      $pen = New-Object Drawing.Pen (TapeColor $brand), ([single](4 * $k))
      for ($i = 1; $i -le 5; $i++) { $o = (50 + $i * 52) * $k; $g.DrawLine($pen, 0, [single](1820 * $k + $o), [single]$Width, [single](1420 * $k + $o)) }
      $pen.Dispose()
      [void](TapeText $g 'ThinkLab' $fBrand $ink (70 * $k) (640 * $k))
      $g.TranslateTransform([single](60 * $k), [single](1500 * $k)); $g.RotateTransform(-21.8)
      $fd = TapeFit $g $lab 'Barlow Condensed Light' (230 * $k) (900 * $k)
      [void](TapeText $g $lab $fd ([Drawing.Color]::White) 0 (-$fd.Size - 10 * $k)); $g.ResetTransform()
    }
    'Teal' {
      $teal = New-Object Drawing.SolidBrush (TapeColor '#16B79A'); $h = 60 * $k; $gap = 22 * $k; $yTop = 1500 * $k; $drop = 110 * $k; $xs = 430 * $k
      foreach ($n in 0, 1) {
        $y0 = $yTop + $n * ($h + $gap)
        $g.FillPolygon($teal, [Drawing.PointF[]]@((New-Object Drawing.PointF ([single]$Width), ([single]$y0)), (New-Object Drawing.PointF ([single]($xs + $drop)), ([single]$y0)), (New-Object Drawing.PointF ([single]$xs), ([single]($y0 + $drop))),
            (New-Object Drawing.PointF 0, ([single]($y0 + $drop))), (New-Object Drawing.PointF 0, ([single]($y0 + $drop + $h))), (New-Object Drawing.PointF ([single]($xs + $h * 0.42)), ([single]($y0 + $drop + $h))),
            (New-Object Drawing.PointF ([single]($xs + $drop + $h * 0.42)), ([single]($y0 + $h))), (New-Object Drawing.PointF ([single]$Width), ([single]($y0 + $h)))))
      }
      $teal.Dispose()
      $card = New-Object Drawing.Rectangle ([int](70 * $k)), ([int](860 * $k)), ([int](560 * $k)), ([int](460 * $k))
      $g.FillRectangle((New-Object Drawing.SolidBrush (TapeColor $bg)), $card); $pen = New-Object Drawing.Pen $ink, ([single](4 * $k)); $g.DrawRectangle($pen, $card)
      [void](TapeText $g 'ThinkLab' (TapeFont 'Barlow Condensed SemiBold' (76 * $k)) $ink (104 * $k) (890 * $k))
      [void](TapeText $g $lab (TapeFit $g $lab 'Barlow Condensed Light' (120 * $k) (480 * $k)) $ink (100 * $k) (1000 * $k))
      $thin = New-Object Drawing.Pen $mut, ([single](2 * $k)); foreach ($i in 0..3) { $yy = (1160 + $i * 36) * $k; $g.DrawLine($thin, [single](104 * $k), [single]$yy, [single](596 * $k), [single]$yy) }
      $pen.Dispose(); $thin.Dispose()
    }
  }
  $pen = New-Object Drawing.Pen $(if ($Style -eq 'Diagonal') { TapeColor '#F5F5F5' } else { $ink }), ([single](3 * $k))
  $g.DrawRectangle($pen, [single](70 * $k), [single](2060 * $k), [single](170 * $k), [single](52 * $k)); $pen.Dispose()
  [void](TapeText $g 'THINK' $fMonoB $ink (90 * $k) (2072 * $k) (9 * $k))
  [void](TapeText $g $FullName $fMono $mut (262 * $k) (2070 * $k))
  $g.Dispose(); New-Item -ItemType Directory -Force (Split-Path $Out -Parent) | Out-Null
  $bmp.Save($Out, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}

$tag = ($Label -replace '[^A-Za-z0-9]', ''); $n = 0
foreach ($sz in $Sizes) {
  $w, $h = [int[]]($sz -split 'x'); $suffix = if ($w -eq 1080) { '' } else { "-$sz" }
  foreach ($bs in @(@('Exploded-Dark', 'dark', 'Line'), @('Exploded-Light', 'light', 'Line'), @('Exploded-XRay', 'dark', 'XRay'), @('Exploded-Sunset', 'dark', 'Sunset'))) {
    New-PhoneBlueprint $bs[1] $bs[2] (Join-Path $Out "ThinkLab-$tag-$($bs[0])$suffix.png") $w $h; $n++
  }
  foreach ($st in 'Sunset', 'SunsetLight', 'Diagonal', 'Teal') { New-PhoneTape $st (Join-Path $Out "ThinkLab-$tag-Tape-$st$suffix.png") $w $h; $n++ }
}
"Build-PhoneWallpapers: $n wallpapers -> $Out"
