# Builds the ThinkLab boot-menu themes for Ventoy: thinklab-dark and thinklab-light (switch at boot with F5 > Theme Select).
#   <Out>\thinklab-dark\{theme.txt, background.png, slices, icons}   <Out>\thinklab-light\...   <Out>\fonts\*.pf2
# Colours come from config\design.json (interface "menu"); fonts from assets\fonts (OFL), converted here to GRUB PF2 so the
# menu itself is set in IBM Plex Mono. ASCII only (accents through U()); run with Windows PowerShell.
param([string]$Out = (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path 'build\USB\ventoy\theme'))
. "$PSScriptRoot\QI.Common.ps1"
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$FontDir = Join-Path $script:RepoRoot 'assets\fonts'
function U($s) { [regex]::Unescape($s) }
function C($hex, $a = 255) { $h = $hex.TrimStart('#'); [Drawing.Color]::FromArgb($a, [Convert]::ToInt32($h.Substring(0,2),16), [Convert]::ToInt32($h.Substring(2,2),16), [Convert]::ToInt32($h.Substring(4,2),16)) }

# ---- fonts (private collection: nothing is installed on the build machine) ----
$pfc = New-Object Drawing.Text.PrivateFontCollection
Get-ChildItem $FontDir -Filter *.ttf | ForEach-Object { $pfc.AddFontFile($_.FullName) }
function Fam($pattern) { $f = $pfc.Families | Where-Object { $_.Name -like $pattern } | Select-Object -First 1; if (-not $f) { $f = New-Object Drawing.FontFamily 'Segoe UI' }; $f }
function Fnt($pattern, [single]$px, [switch]$Bold) {
  $fam = Fam $pattern; $st = if ($Bold -and $fam.IsStyleAvailable('Bold')) { 'Bold' } elseif ($fam.IsStyleAvailable('Regular')) { 'Regular' } else { 'Bold' }
  New-Object Drawing.Font $fam, $px, ([Drawing.FontStyle]$st), ([Drawing.GraphicsUnit]::Pixel)
}

# ---- GRUB PF2 font writer (1 bit per pixel) ----
function BE16([int]$v) { $b = [BitConverter]::GetBytes([int16]$v); [Array]::Reverse($b); , $b }
function BE32([uint32]$v) { $b = [BitConverter]::GetBytes($v); [Array]::Reverse($b); , $b }
function New-Pf2([Drawing.Font]$font, [string]$name, [string]$family, [string]$weight, [string]$path) {
  $px = [int][Math]::Round($font.Size); $fam = $font.FontFamily; $st = $font.Style
  $asc = [int][Math]::Round($fam.GetCellAscent($st) * $font.Size / $fam.GetEmHeight($st)); $dsc = [int][Math]::Round($fam.GetCellDescent($st) * $font.Size / $fam.GetEmHeight($st))
  $cw = $px * 3; $ch = $px * 3
  $bmp = New-Object Drawing.Bitmap $cw, $ch, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [Drawing.Graphics]::FromImage($bmp); $g.TextRenderingHint = 'SingleBitPerPixelGridFit'
  $sf = [Drawing.StringFormat]::GenericTypographic.Clone(); $sf.FormatFlags = $sf.FormatFlags -bor [Drawing.StringFormatFlags]::MeasureTrailingSpaces
  $codes = @(32..126) + @(160..255) + @(0x2013, 0x2014, 0x2022, 0x2026, 0x2190, 0x2191, 0x2192, 0x2193, 0x2500, 0x2502) | Sort-Object -Unique   # GRUB wants ascending code points
  $glyphs = New-Object Collections.Generic.List[object]; $maxw = 0
  $rect = New-Object Drawing.Rectangle 0, 0, $cw, $ch; $buf = New-Object byte[] ($cw * $ch * 4)
  foreach ($cp in $codes) {
    $s = [string][char]$cp
    $adv = [int][Math]::Round($g.MeasureString($s, $font, (New-Object Drawing.PointF 0, 0), $sf).Width)
    $g.Clear([Drawing.Color]::Black); $g.DrawString($s, $font, [Drawing.Brushes]::White, [single]$px, [single]0, $sf)     # drawn at x = px so negative bearings fit
    $bd = $bmp.LockBits($rect, 'ReadOnly', 'Format32bppArgb'); [Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $buf, 0, $buf.Length); $bmp.UnlockBits($bd)
    $x0 = $cw; $x1 = -1; $y0 = $ch; $y1 = -1
    for ($y = 0; $y -lt $ch; $y++) { $row = $y * $cw * 4; for ($x = 0; $x -lt $cw; $x++) { if ($buf[$row + $x * 4 + 1] -gt 127) { if ($x -lt $x0) { $x0 = $x }; if ($x -gt $x1) { $x1 = $x }; if ($y -lt $y0) { $y0 = $y }; if ($y -gt $y1) { $y1 = $y } } } }
    if ($x1 -lt 0) { $glyphs.Add(@{ cp = $cp; w = 0; h = 0; xo = 0; yo = 0; adv = $adv; bits = (New-Object byte[] 0) }); continue }
    $w = $x1 - $x0 + 1; $h = $y1 - $y0 + 1; $bits = New-Object byte[] ([int][Math]::Ceiling($w * $h / 8.0)); $n = 0
    for ($y = $y0; $y -le $y1; $y++) { $row = $y * $cw * 4; for ($x = $x0; $x -le $x1; $x++) { if ($buf[$row + $x * 4 + 1] -gt 127) { $bits[[int][Math]::Floor($n / 8)] = $bits[[int][Math]::Floor($n / 8)] -bor (0x80 -shr ($n % 8)) }; $n++ } }
    if ($w -gt $maxw) { $maxw = $w }
    $glyphs.Add(@{ cp = $cp; w = $w; h = $h; xo = ($x0 - $px); yo = ($asc - ($y1 + 1)); adv = $adv; bits = $bits })
  }
  $g.Dispose(); $bmp.Dispose()
  $ms = New-Object IO.MemoryStream
  function Sec($ms, [string]$id, [byte[]]$data) { $ms.Write([Text.Encoding]::ASCII.GetBytes($id), 0, 4); $l = BE32 ([uint32]$data.Length); $ms.Write($l, 0, 4); $ms.Write($data, 0, $data.Length) }
  function Str([string]$t) { , ([Text.Encoding]::ASCII.GetBytes($t) + [byte]0) }
  Sec $ms 'FILE' ([Text.Encoding]::ASCII.GetBytes('PFF2'))
  Sec $ms 'NAME' (Str $name); Sec $ms 'FAMI' (Str $family); Sec $ms 'WEIG' (Str $weight); Sec $ms 'SLAN' (Str 'normal')
  Sec $ms 'PTSZ' (BE16 $px); Sec $ms 'MAXW' (BE16 $maxw); Sec $ms 'MAXH' (BE16 ($asc + $dsc)); Sec $ms 'ASCE' (BE16 $asc); Sec $ms 'DESC' (BE16 $dsc)
  $off = [int]$ms.Length + 8 + 9 * $glyphs.Count + 8          # CHIX header + entries + DATA header
  $chix = New-Object IO.MemoryStream
  foreach ($gl in $glyphs) { $b = BE32 ([uint32]$gl.cp); $chix.Write($b, 0, 4); $chix.WriteByte(0); $b = BE32 ([uint32]$off); $chix.Write($b, 0, 4); $off += 10 + $gl.bits.Length }
  Sec $ms 'CHIX' ($chix.ToArray())
  $ms.Write([Text.Encoding]::ASCII.GetBytes('DATA'), 0, 4); $ms.Write([byte[]](0xFF, 0xFF, 0xFF, 0xFF), 0, 4)
  foreach ($gl in $glyphs) { foreach ($v in $gl.w, $gl.h, $gl.xo, $gl.yo, $gl.adv) { $b = BE16 $v; $ms.Write($b, 0, 2) }; if ($gl.bits.Length) { $ms.Write($gl.bits, 0, $gl.bits.Length) } }
  [IO.File]::WriteAllBytes($path, $ms.ToArray())
}
New-Item -ItemType Directory -Force "$Out\fonts" | Out-Null
$Pf2 = @(
  @{ file = 'plex-mono-18.pf2';  name = 'IBM Plex Mono Regular 18';  weight = 'normal'; font = (Fnt 'IBM Plex Mono' 18) },
  @{ file = 'plex-mono-b18.pf2'; name = 'IBM Plex Mono SemiBold 18'; weight = 'bold';   font = (Fnt 'IBM Plex Mono SemiBold' 18) },
  @{ file = 'plex-mono-14.pf2';  name = 'IBM Plex Mono Regular 14';  weight = 'normal'; font = (Fnt 'IBM Plex Mono' 14) })
foreach ($f in $Pf2) { New-Pf2 $f.font $f.name 'IBM Plex Mono' $f.weight (Join-Path "$Out\fonts" $f.file) }

# ---- drawing helpers ----
function Solid($path, $w, $h, $color, $alpha = 255) {
  $b = New-Object Drawing.Bitmap $w, $h, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [Drawing.Graphics]::FromImage($b); $g.Clear((C $color $alpha)); $g.Dispose(); $b.Save($path, [Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
}
function RoundRect($g, $brush, $x, $y, $w, $h, $r) {
  $p = New-Object Drawing.Drawing2D.GraphicsPath
  $p.AddArc($x, $y, $r*2, $r*2, 180, 90); $p.AddArc($x+$w-$r*2, $y, $r*2, $r*2, 270, 90)
  $p.AddArc($x+$w-$r*2, $y+$h-$r*2, $r*2, $r*2, 0, 90); $p.AddArc($x, $y+$h-$r*2, $r*2, $r*2, 90, 90); $p.CloseFigure()
  $g.FillPath($brush, $p); $p.Dispose()
}
function Txt($g, $text, $font, $color, $x, $y, [single]$track = 0) {
  $br = New-Object Drawing.SolidBrush $color; $sf = [Drawing.StringFormat]::GenericTypographic.Clone(); $sf.FormatFlags = $sf.FormatFlags -bor [Drawing.StringFormatFlags]::MeasureTrailingSpaces
  if ($track -le 0) { $g.DrawString($text, $font, $br, [single]$x, [single]$y, $sf); $w = $g.MeasureString($text, $font, (New-Object Drawing.PointF 0, 0), $sf).Width }
  else { $cx = [single]$x; foreach ($chr in $text.ToCharArray()) { $g.DrawString([string]$chr, $font, $br, $cx, [single]$y, $sf); $cx += $g.MeasureString([string]$chr, $font, (New-Object Drawing.PointF 0, 0), $sf).Width + $track }; $w = $cx - $x }
  $br.Dispose(); $w
}
function IsoPt($ox, $oy, $x, $y, $z) { New-Object Drawing.PointF ([single]($ox + ($x - $y) * 0.866)), ([single]($oy + ($x + $y) * 0.5 - $z)) }
function IsoCube($g, $ox, $oy, $x, $y, $z, $w, $d, $h, $top, $left, $right, $edge) {
  $faces = @(
    @{ c = $left;  p = @((IsoPt $ox $oy $x ($y+$d) ($z+$h)), (IsoPt $ox $oy ($x+$w) ($y+$d) ($z+$h)), (IsoPt $ox $oy ($x+$w) ($y+$d) $z), (IsoPt $ox $oy $x ($y+$d) $z)) },
    @{ c = $right; p = @((IsoPt $ox $oy ($x+$w) $y ($z+$h)), (IsoPt $ox $oy ($x+$w) ($y+$d) ($z+$h)), (IsoPt $ox $oy ($x+$w) ($y+$d) $z), (IsoPt $ox $oy ($x+$w) $y $z)) },
    @{ c = $top;   p = @((IsoPt $ox $oy $x $y ($z+$h)), (IsoPt $ox $oy ($x+$w) $y ($z+$h)), (IsoPt $ox $oy ($x+$w) ($y+$d) ($z+$h)), (IsoPt $ox $oy $x ($y+$d) ($z+$h))) })
  $pen = New-Object Drawing.Pen $edge, 1.6; $pen.LineJoin = 'Round'
  foreach ($f in $faces) { $br = New-Object Drawing.SolidBrush $f.c; $g.FillPolygon($br, [Drawing.PointF[]]$f.p); $g.DrawPolygon($pen, [Drawing.PointF[]]$f.p); $br.Dispose() }
  $pen.Dispose()
}
function Darken([Drawing.Color]$c, [double]$k) { [Drawing.Color]::FromArgb(255, [int]($c.R * $k), [int]($c.G * $k), [int]($c.B * $k)) }

$icons = [ordered]@{
  win10 = @('10', '#0B64DD'); win11 = @('11', '#0B64DD'); winsrv = @('SV', '#101C3F'); winlite = @('LT', '#3B7DD8')
  ubuntu = @('U', '#E95420'); alma = @('A', '#16B79A'); rhel = @('RH', '#E2231A'); centos = @('C', '#7A3FA0'); suse = @('S', '#5FA31C')
  vtoydir = @('>', '#E95420'); vtoyiso = @('i', '#6B6B6B'); vtoyret = @('<', '#6B6B6B')
  pe = @('PE', '#16B79A'); rescue = @('R', '#C47F00'); memtest = @('M', '#F04E98'); tools = @('T', '#6B6B6B')
}

foreach ($scheme in 'dark', 'light') {
  $p = Get-Palette 'menu' $scheme; $dir = Join-Path $Out "thinklab-$scheme"; New-Item -ItemType Directory -Force "$dir\icons" | Out-Null
  $bg = C $p.background; $surf = C $p.surface; $high = C $p.surfaceHigh; $line = C $p.outline; $ink = C $p.onSurface; $mut = C $p.onSurfaceVariant
  $pri = C $p.primary; $brand = C $p.'seed-brand'; $nub = C $p.nub
  $W = 1920; $H = 1080
  $bmp = New-Object Drawing.Bitmap $W, $H, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.Clear($bg)

  # granular halftone: dense at the top right and bottom left, fading toward the middle
  $dot = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb($(if ($scheme -eq 'dark') { 30 } else { 34 }), $ink))
  for ($y = 10; $y -lt $H; $y += 20) { for ($x = 10; $x -lt $W; $x += 20) {
      $a = [Math]::Max(0, 1 - [Math]::Sqrt(($W - $x) * ($W - $x) + $y * $y) / 900.0); $b = [Math]::Max(0, 1 - [Math]::Sqrt($x * $x + ($H - $y) * ($H - $y)) / 760.0)
      $r = 2.6 * [Math]::Max($a, $b); if ($r -gt 0.35) { $g.FillEllipse($dot, [single]($x - $r), [single]($y - $r), [single](2 * $r), [single](2 * $r)) } } }
  $dot.Dispose()

  # top bar
  $pen = New-Object Drawing.Pen $line, 1
  $g.DrawLine($pen, 0, 64, $W, 64)
  $mono13 = Fnt 'IBM Plex Mono SemiBold' 13; $mono15 = Fnt 'IBM Plex Mono' 15; $mono15b = Fnt 'IBM Plex Mono SemiBold' 15
  $g.DrawRectangle($pen, 64, 20, 86, 26); [void](Txt $g 'THINK' $mono13 $ink 76 25 4.2)
  [void](Txt $g 'ThinkLab Quick Install' $mono15 $ink 172 23)
  $wv = Txt $g 'PT / EN' $mono15b $pri 1560 23; [void](Txt $g (U '\u00b7 F5 tema / theme') $mono15 $mut (1560 + $wv + 10) 23)

  # brand block (left column)
  $bb = New-Object Drawing.SolidBrush $brand; RoundRect $g $bb 64 128 76 76 9; $bb.Dispose()
  $ring = New-Object Drawing.Pen ([Drawing.Color]::White), 8; $g.DrawEllipse($ring, 83, 147, 38, 38); $ring.Dispose()
  $g.FillEllipse([Drawing.Brushes]::White, 96, 160, 12, 12)
  $nb = New-Object Drawing.SolidBrush $nub; $g.FillEllipse((New-Object Drawing.SolidBrush $bg), 127, 191, 22, 22); $g.FillEllipse($nb, 130, 194, 16, 16)
  [void](Txt $g 'ThinkLab' (Fnt 'Barlow Condensed SemiBold' 132) $ink 60 206)
  [void](Txt $g 'QUICK INSTALL' (Fnt 'IBM Plex Mono SemiBold' 22) $pri 66 356 5)
  $sans = Fnt 'IBM Plex Sans' 21
  [void](Txt $g (U 'Kit de instala\u00e7\u00e3o e recupera\u00e7\u00e3o') $sans $mut 66 404)
  [void](Txt $g 'Install and recovery kit' $sans $mut 66 432)

  # numbered sections (01/ 02/ 03/)
  $num = Fnt 'IBM Plex Mono SemiBold' 20; $sec = Fnt 'IBM Plex Sans SemiBold' 24; $small = Fnt 'IBM Plex Mono' 14
  $rows = @(@('01/', 'Windows', '10 / 11 / LTSC / IoT / Server'), @('02/', 'Linux', 'Ubuntu / AlmaLinux / RHEL / CentOS / openSUSE'), @('03/', 'Recovery', 'WinPE / SystemRescue / GParted / Clonezilla / MemTest'))
  $yy = 506
  foreach ($r in $rows) {
    $g.DrawLine($pen, 64, $yy - 14, 560, $yy - 14)
    [void](Txt $g $r[0] $num $pri 66 $yy); [void](Txt $g $r[1] $sec $ink 122 ($yy - 4)); [void](Txt $g $r[2] $small $mut 122 ($yy + 30)); $yy += 84
  }
  $g.DrawLine($pen, 64, $yy - 14, 560, $yy - 14)

  # isometric motif (bottom left): the kit as a stack
  $edge = if ($scheme -eq 'dark') { C '#C9D3EA' } else { C '#1B2A4A' }; $face = if ($scheme -eq 'dark') { C '#2A2F3C' } else { C '#FFFFFF' }
  $f2 = if ($scheme -eq 'dark') { C '#20242F' } else { C '#EEF1F6' }; $f3 = if ($scheme -eq 'dark') { C '#171A23' } else { C '#DFE4EC' }
  $ox = 232; $oy = 905
  IsoCube $g $ox $oy 0 0 0 150 150 16 $face $f2 $f3 $edge
  IsoCube $g $ox $oy 0 0 26 150 150 16 $face (C '#16B79A') (C '#0B5F51') $edge
  IsoCube $g $ox $oy 0 0 52 150 150 16 $face $f2 $f3 $edge
  IsoCube $g $ox $oy 0 0 78 150 150 16 $face $brand (Darken $brand 0.52) $edge
  IsoCube $g $ox $oy 215 (-35) 0 76 76 76 $face (C '#0B64DD') (C '#06377D') $edge

  # menu panel + header + crosshair corners
  $px0 = 620; $py0 = 110; $px1 = 1856; $py1 = 862
  $sb = New-Object Drawing.SolidBrush $surf; $g.FillRectangle($sb, $px0, $py0, $px1 - $px0, $py1 - $py0); $sb.Dispose()
  $hb = New-Object Drawing.SolidBrush $high; $g.FillRectangle($hb, $px0, $py0, $px1 - $px0, 44); $hb.Dispose()
  $g.DrawRectangle($pen, $px0, $py0, $px1 - $px0, $py1 - $py0); $g.DrawLine($pen, $px0, $py0 + 44, $px1, $py0 + 44)
  $nbm = New-Object Drawing.SolidBrush $nub; $g.FillEllipse($nbm, $px0 + 18, $py0 + 16, 12, 12)
  [void](Txt $g 'MENU DE BOOT / BOOT MENU' $mono13 $ink ($px0 + 42) ($py0 + 14) 2.2)
  [void](Txt $g (U '\u2191 \u2193  ENTER   ESC') $mono13 $mut ($px1 - 196) ($py0 + 14) 1.2)
  $cp = New-Object Drawing.Pen $mut, 1
  foreach ($c in @(@($px0, $py0), @($px1, $py0), @($px0, $py1), @($px1, $py1))) { $g.DrawLine($cp, $c[0] - 7, $c[1], $c[0] + 7, $c[1]); $g.DrawLine($cp, $c[0], $c[1] - 7, $c[0], $c[1] + 7) }
  # tip strip under the panel
  [void](Txt $g 'i' $mono15b $pri ($px0 + 4) 884); $g.DrawLine($pen, $px0, 916, $px1, 916)
  [void](Txt $g (U 'disco sempre manual \u00b7 the disk is always chosen by you') $small $mut ($px1 - 482) 1040)
  $pen.Dispose(); $cp.Dispose(); $nbm.Dispose(); $nb.Dispose()
  $g.Dispose(); $bmp.Save("$dir\background.png", [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()

  # slices: the panel is part of the background, so the menu box itself stays invisible
  Solid "$dir\select_c.png" 8 8 $p.surfaceHigh 255
  Solid "$dir\select_w.png" 4 8 $p.primary 255
  Solid "$dir\slider_c.png" 8 8 $p.onSurfaceVariant 255; Solid "$dir\slider_n.png" 8 2 $p.onSurfaceVariant 255; Solid "$dir\slider_s.png" 8 2 $p.onSurfaceVariant 255
  foreach ($n in 'n','s') { Solid "$dir\terminal_box_$n.png" 8 1 $p.outline 255 }; foreach ($n in 'e','w') { Solid "$dir\terminal_box_$n.png" 1 8 $p.outline 255 }
  foreach ($n in 'nw','ne','sw','se') { Solid "$dir\terminal_box_$n.png" 1 1 $p.outline 255 }
  Solid "$dir\terminal_box_c.png" 8 8 $p.background 245

  # class icons: flat 28x28 tiles, mono caption
  $ff = Fnt 'IBM Plex Mono SemiBold' 12
  foreach ($k in $icons.Keys) {
    $b = New-Object Drawing.Bitmap 28, 28, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gi = [Drawing.Graphics]::FromImage($b); $gi.SmoothingMode = 'AntiAlias'; $gi.TextRenderingHint = 'AntiAliasGridFit'; $gi.Clear([Drawing.Color]::Transparent)
    $br = New-Object Drawing.SolidBrush (C $icons[$k][1]); RoundRect $gi $br 1 1 26 26 4; $br.Dispose()
    $sf = New-Object Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
    $gi.DrawString($icons[$k][0], $ff, [Drawing.Brushes]::White, (New-Object Drawing.RectangleF 0, 1, 28, 28), $sf)
    $gi.Dispose(); $b.Save("$dir\icons\$k.png", [Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
  }

  $sel = if ($scheme -eq 'dark') { '#FFFFFF' } else { '#000000' }
@"
desktop-image: "background.png"
title-text: " "
title-color: "$($p.onSurface)"
message-color: "$($p.onSurface)"
message-font: "IBM Plex Mono Regular 14"
terminal-font: "IBM Plex Mono Regular 14"
terminal-box: "terminal_box_*.png"

+ boot_menu {
  left = 33%
  width = 63%
  top = 15%
  height = 64%

  item_font = "IBM Plex Mono Regular 18"
  selected_item_font = "IBM Plex Mono SemiBold 18"
  item_color = "$($p.onSurface)"
  item_height = 36
  item_spacing = 2
  item_padding = 10
  item_icon_space = 14

  selected_item_color = "$sel"
  selected_item_pixmap_style = "select_*.png"

  icon_width = 28
  icon_height = 28

  scrollbar = true
  scrollbar_width = 8
  scrollbar_thumb = "slider_*.png"
}

+ progress_bar {
  id = "__timeout__"
  text = "@TIMEOUT_NOTIFICATION_SHORT@"
  font = "IBM Plex Mono Regular 14"
  left = 33%
  width = 63%
  top = 86%
  height = 20
  text_color = "$($p.primary)"
  bar_style = "*"
  highlight_style = "*"
}

+ hbox { left = 33%  top = 89%  width = 62%  height = 22  + label { text = "@VTOY_HOTKEY_TIP@"   font = "IBM Plex Mono Regular 14" color = "$($p.onSurfaceVariant)" align = "left" } }
+ hbox { left = 33%  top = 92%  width = 14%  height = 22  + label { text = "@VTOY_ISO_RAW@"      font = "IBM Plex Mono Regular 14" color = "$($p.primary)" align = "left" } }
+ hbox { left = 47%  top = 92%  width = 14%  height = 22  + label { text = "@VTOY_MEM_DISK@"     font = "IBM Plex Mono Regular 14" color = "$($p.primary)" align = "left" } }
+ hbox { left = 61%  top = 92%  width = 14%  height = 22  + label { text = "@VTOY_GRUB2_MODE@"   font = "IBM Plex Mono Regular 14" color = "$($p.primary)" align = "left" } }
+ hbox { left = 75%  top = 92%  width = 14%  height = 22  + label { text = "@VTOY_WIMBOOT_MODE@" font = "IBM Plex Mono Regular 14" color = "$($p.primary)" align = "left" } }
+ hbox { left = 86%  top = 7%  width = 12%  height = 22  + label { text = "@VTOY_ISO_UEFI_DRV@" font = "IBM Plex Mono Regular 14" color = "$($p.primary)" align = "left" } }
"@ | Set-Content "$dir\theme.txt" -Encoding ASCII
}
"themes written to $Out (thinklab-dark, thinklab-light, fonts: $(($Pf2 | ForEach-Object { $_.file }) -join ', '))"
