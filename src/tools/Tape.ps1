# "Tape" wallpapers: flat retro graphics (stripe bands, diagonal blocks) in the ThinkLab palette - own artwork, no vendor marks.
# Library: New-TapeWallpaper -Machine <site machine> -Style Sunset|SunsetLight|Diagonal|Teal -Out <png> [-Width 3840 -Height 2160]
# Fonts come from assets\fonts (OFL). ASCII only.
Add-Type -AssemblyName System.Drawing
$script:TapeFonts = New-Object Drawing.Text.PrivateFontCollection
Get-ChildItem (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path 'assets\fonts') -Filter *.ttf | ForEach-Object { $script:TapeFonts.AddFontFile($_.FullName) }
function TapeFont([string]$pattern, [single]$px) {
  $fam = $script:TapeFonts.Families | Where-Object { $_.Name -like $pattern } | Select-Object -First 1
  if (-not $fam) { $fam = New-Object Drawing.FontFamily 'Segoe UI' }
  $st = if ($fam.IsStyleAvailable('Regular')) { 'Regular' } else { 'Bold' }
  New-Object Drawing.Font $fam, $px, ([Drawing.FontStyle]$st), ([Drawing.GraphicsUnit]::Pixel)
}
function TapeColor([string]$hex, [int]$a = 255) { $h = $hex.TrimStart('#'); [Drawing.Color]::FromArgb($a, [Convert]::ToInt32($h.Substring(0,2),16), [Convert]::ToInt32($h.Substring(2,2),16), [Convert]::ToInt32($h.Substring(4,2),16)) }
function TapeText($g, [string]$text, $font, $color, [single]$x, [single]$y, [single]$track = 0) {
  $br = New-Object Drawing.SolidBrush $color; $sf = [Drawing.StringFormat]::GenericTypographic.Clone(); $sf.FormatFlags = $sf.FormatFlags -bor [Drawing.StringFormatFlags]::MeasureTrailingSpaces
  $cx = $x
  if ($track -le 0) { $g.DrawString($text, $font, $br, $x, $y, $sf); $cx = $x + $g.MeasureString($text, $font, (New-Object Drawing.PointF 0, 0), $sf).Width }
  else { foreach ($ch in $text.ToCharArray()) { $g.DrawString([string]$ch, $font, $br, $cx, $y, $sf); $cx += $g.MeasureString([string]$ch, $font, (New-Object Drawing.PointF 0, 0), $sf).Width + $track } }
  $br.Dispose(); $cx
}

function TapeFit($g, [string]$text, [string]$pattern, [single]$px, [single]$max) {     # largest font (<= px) whose text fits in max pixels
  $sf = [Drawing.StringFormat]::GenericTypographic
  do { $f = TapeFont $pattern $px; $w = $g.MeasureString($text, $f, (New-Object Drawing.PointF 0, 0), $sf).Width; $px = $px * 0.94 } while ($w -gt $max -and $px -gt 12)
  $f
}

function New-TapeWallpaper {
  param($Machine, [ValidateSet('Sunset', 'SunsetLight', 'Diagonal', 'Teal')][string]$Style = 'Sunset', [string]$Out, [int]$Width = 3840, [int]$Height = 2160)
  $k = $Width / 3840.0; $light = $Style -eq 'SunsetLight'
  $bg = if ($light) { '#F2F0EA' } elseif ($Style -eq 'Teal') { '#141416' } else { '#0B0B0C' }
  $ink = if ($light) { TapeColor '#141414' } else { TapeColor '#F5F5F5' }; $mut = if ($light) { TapeColor '#5F5F5F' } else { TapeColor '#A8A8A8' }
  $brand = '#E95420'; $nub = '#E2231A'
  $bmp = New-Object Drawing.Bitmap $Width, $Height, ([Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.Clear((TapeColor $bg))
  $label = $Machine.label.ToUpper(); $full = $Machine.fullName
  $fBrand = TapeFont 'Barlow Condensed SemiBold' (150 * $k); $fModel = TapeFont 'Barlow Condensed Light' (300 * $k); $fSmall = TapeFont 'IBM Plex Sans' (54 * $k)
  $fMono = TapeFont 'IBM Plex Mono' (34 * $k); $fMonoB = TapeFont 'IBM Plex Mono SemiBold' (30 * $k)

  switch -Wildcard ($Style) {
    'Sunset*' {
      $cols = '#FEC514', '#FF8A2B', $brand, '#F04E98', '#7A3FA0'; $y = 900 * $k
      foreach ($c in $cols) { $b = New-Object Drawing.SolidBrush (TapeColor $c); $g.FillRectangle($b, 0, [single]$y, $Width, [single](66 * $k)); $b.Dispose(); $y += 66 * $k }
      [void](TapeText $g 'ThinkLab' $fBrand $ink (150 * $k) (120 * $k))
      [void](TapeText $g $label $fModel $ink (146 * $k) (560 * $k))
      $nb = New-Object Drawing.SolidBrush (TapeColor $nub)                                   # dot matrix, top right (fades out)
      for ($r = 0; $r -lt 6; $r++) { for ($c = 0; $c -lt 6; $c++) { if (($r + (5 - $c)) -le 6) { $g.FillEllipse($nb, [single]($Width - (150 + $c * 34) * $k), [single]((130 + $r * 34) * $k), [single](18 * $k), [single](18 * $k)) } } }
      $nb.Dispose()
    }
    'Diagonal' {
      $b = New-Object Drawing.SolidBrush (TapeColor $brand)
      $g.FillPolygon($b, [Drawing.PointF[]]@((New-Object Drawing.PointF 0, 0), (New-Object Drawing.PointF ([single](1900 * $k)), 0), (New-Object Drawing.PointF ([single](560 * $k)), ([single](1340 * $k))), (New-Object Drawing.PointF 0, ([single](1340 * $k))))); $b.Dispose()
      $pen = New-Object Drawing.Pen (TapeColor $brand), ([single](5 * $k))
      for ($i = 1; $i -le 6; $i++) { $o = (70 + $i * 74) * $k; $g.DrawLine($pen, [single](1900 * $k + $o), 0, [single](560 * $k + $o - 820 * $k), [single](2160 * $k)) }
      $pen.Dispose()
      [void](TapeText $g 'ThinkLab' $fBrand ([Drawing.Color]::White) (150 * $k) (120 * $k))
      $g.TranslateTransform([single](760 * $k), [single](1060 * $k)); $g.RotateTransform(-45)
      $fd = TapeFit $g $label 'Barlow Condensed Light' (300 * $k) (760 * $k)
      [void](TapeText $g $label $fd ([Drawing.Color]::White) 0 (-$fd.Size - 10 * $k)); $g.ResetTransform()
    }
    'Teal' {
      $teal = New-Object Drawing.SolidBrush (TapeColor '#16B79A'); $h = 84 * $k; $gap = 30 * $k; $yTop = 760 * $k; $drop = 150 * $k; $xs = 1560 * $k
      foreach ($n in 0, 1) {
        $y0 = $yTop + $n * ($h + $gap)
        $g.FillPolygon($teal, [Drawing.PointF[]]@((New-Object Drawing.PointF ([single]$Width), ([single]$y0)), (New-Object Drawing.PointF ([single]($xs + $drop)), ([single]$y0)), (New-Object Drawing.PointF ([single]$xs), ([single]($y0 + $drop))),
            (New-Object Drawing.PointF 0, ([single]($y0 + $drop))), (New-Object Drawing.PointF 0, ([single]($y0 + $drop + $h))), (New-Object Drawing.PointF ([single]($xs + $h * 0.42)), ([single]($y0 + $drop + $h))),
            (New-Object Drawing.PointF ([single]($xs + $drop + $h * 0.42)), ([single]($y0 + $h))), (New-Object Drawing.PointF ([single]$Width), ([single]($y0 + $h)))))
      }
      $teal.Dispose()
      $card = New-Object Drawing.Rectangle ([int](1020 * $k)), ([int](560 * $k)), ([int](560 * $k)), ([int](760 * $k))
      $g.FillRectangle((New-Object Drawing.SolidBrush (TapeColor $bg)), $card); $pen = New-Object Drawing.Pen $ink, ([single](5 * $k)); $g.DrawRectangle($pen, $card)
      [void](TapeText $g 'ThinkLab' (TapeFont 'Barlow Condensed SemiBold' (96 * $k)) $ink (1060 * $k) (590 * $k))
      [void](TapeText $g $label (TapeFit $g $label 'Barlow Condensed Light' (150 * $k) (480 * $k)) $ink (1056 * $k) (700 * $k))
      $thin = New-Object Drawing.Pen $mut, ([single](2 * $k)); foreach ($i in 0..3) { $yy = (1120 + $i * 44) * $k; $g.DrawLine($thin, [single](1060 * $k), [single]$yy, [single](1540 * $k), [single]$yy) }
      $pen.Dispose(); $thin.Dispose()
    }
  }
  # footer: THINK tag + machine line
  $pen = New-Object Drawing.Pen $(if ($Style -eq 'Diagonal') { TapeColor '#F5F5F5' } else { $ink }), ([single](3 * $k))
  $g.DrawRectangle($pen, [single](150 * $k), [single](1950 * $k), [single](200 * $k), [single](62 * $k)); $pen.Dispose()
  [void](TapeText $g 'THINK' $fMonoB $ink (174 * $k) (1964 * $k) (11 * $k))
  [void](TapeText $g $full $fMono $mut (384 * $k) (1962 * $k))
  $g.Dispose(); New-Item -ItemType Directory -Force (Split-Path $Out -Parent) | Out-Null
  $bmp.Save($Out, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}
