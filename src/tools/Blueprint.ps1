# Isometric line-art "exploded view" wallpapers of a machine (own artwork; no vendor logos, no copied manual images).
# Library: New-Blueprint -Machine <site machine> -Scheme dark|light -Style Line|XRay|Sunset -Out <png> [-Type .. -Label .. -Width 3840 -Height 2160]
#   machine.blueprint selects the drawing: tower | laptop | tiny | tiny-fanless   (config\site.json, per machine)
# Colours come from config\design.json (interface "desktop"). ASCII only.
Add-Type -AssemblyName System.Drawing

class BP {
  [Drawing.Graphics]$G; [Drawing.Pen]$Pen; [Drawing.Pen]$Thin; [Drawing.Brush]$Bg; [Drawing.Brush]$Nub
  [double]$S; [double]$Cx; [double]$Cy
  [double]$Lw = 1; [Drawing.Pen]$Dash; [Drawing.Font]$Font; [Drawing.Brush]$Ink
  BP([Drawing.Graphics]$g, [Drawing.Color]$line, [Drawing.Color]$bg, [Drawing.Color]$nub, [double]$s, [double]$cx, [double]$cy, [double]$lw) {
    $this.G = $g; $this.S = $s; $this.Cx = $cx; $this.Cy = $cy
    $this.Pen = New-Object Drawing.Pen $line, ([single](2.6 * $lw)); $this.Pen.LineJoin = 'Round'
    $this.Thin = New-Object Drawing.Pen ([Drawing.Color]::FromArgb([Math]::Min(150, [int]$line.A), $line)), ([single](1.5 * $lw)); $this.Thin.LineJoin = 'Round'
    $this.Bg = New-Object Drawing.SolidBrush $bg; $this.Nub = New-Object Drawing.SolidBrush $nub
    $this.Lw = $lw; $this.Dash = New-Object Drawing.Pen ([Drawing.Color]::FromArgb([Math]::Min(170, [int]$line.A), $line)), ([single](1.5 * $lw)); $this.Dash.DashStyle = 'Dash'
  }
  [Drawing.PointF] P([double]$x, [double]$y, [double]$z) { return (New-Object Drawing.PointF ([float]($this.Cx + ($x - $y) * 0.866 * $this.S)), ([float]($this.Cy + ($x + $y) * 0.5 * $this.S - $z * $this.S))) }
  Poly([double[][]]$pts, [bool]$fill, [bool]$thin) {
    $arr = New-Object 'Drawing.PointF[]' $pts.Count
    for ($i = 0; $i -lt $pts.Count; $i++) { $arr[$i] = $this.P($pts[$i][0], $pts[$i][1], $pts[$i][2]) }
    if ($fill) { $this.G.FillPolygon($this.Bg, $arr) }
    $this.G.DrawPolygon($(if ($thin) { $this.Thin } else { $this.Pen }), $arr)
  }
  # solid (hidden-line) box: three visible faces
  Box([double]$x, [double]$y, [double]$z, [double]$w, [double]$d, [double]$h, [bool]$thin) {
    $this.Poly(@(@($x, ($y + $d), $z), @(($x + $w), ($y + $d), $z), @(($x + $w), ($y + $d), ($z + $h)), @($x, ($y + $d), ($z + $h))), $true, $thin)
    $this.Poly(@(@(($x + $w), $y, $z), @(($x + $w), ($y + $d), $z), @(($x + $w), ($y + $d), ($z + $h)), @(($x + $w), $y, ($z + $h))), $true, $thin)
    $this.Poly(@(@($x, $y, ($z + $h)), @(($x + $w), $y, ($z + $h)), @(($x + $w), ($y + $d), ($z + $h)), @($x, ($y + $d), ($z + $h))), $true, $thin)
  }
  # open (wire) box: all edges, no fill
  Wire([double]$x, [double]$y, [double]$z, [double]$w, [double]$d, [double]$h) {
    foreach ($zz in $z, ($z + $h)) { $this.Poly(@(@($x, $y, $zz), @(($x + $w), $y, $zz), @(($x + $w), ($y + $d), $zz), @($x, ($y + $d), $zz)), $false, $false) }
    foreach ($c in @(@($x, $y), @(($x + $w), $y), @(($x + $w), ($y + $d)), @($x, ($y + $d)))) { $this.Line(@($c[0], $c[1], $z), @($c[0], $c[1], ($z + $h)), $false) }
  }
  Line([double[]]$a, [double[]]$b, [bool]$thin) { $this.G.DrawLine($(if ($thin) { $this.Thin } else { $this.Pen }), $this.P($a[0], $a[1], $a[2]), $this.P($b[0], $b[1], $b[2])) }
  # circle lying on the horizontal plane at height z
  Circle([double]$cx, [double]$cy, [double]$z, [double]$r, [bool]$fill, [bool]$thin) {
    $c = $this.P($cx, $cy, $z); $rx = 1.2247 * $r * $this.S; $ry = 0.7071 * $r * $this.S
    if ($fill) { $this.G.FillEllipse($this.Bg, [float]($c.X - $rx), [float]($c.Y - $ry), [float](2 * $rx), [float](2 * $ry)) }
    $this.G.DrawEllipse($(if ($thin) { $this.Thin } else { $this.Pen }), [float]($c.X - $rx), [float]($c.Y - $ry), [float](2 * $rx), [float](2 * $ry))
  }
  NubDot([double]$cx, [double]$cy, [double]$z, [double]$r) {
    $c = $this.P($cx, $cy, $z); $rx = 1.2247 * $r * $this.S; $ry = 0.7071 * $r * $this.S
    $this.G.FillEllipse($this.Nub, [float]($c.X - $rx), [float]($c.Y - $ry), [float](2 * $rx), [float](2 * $ry))
  }
  # polyline through 3D points (cables)
  Cable([double[][]]$pts) {
    $arr = New-Object 'Drawing.PointF[]' $pts.Count
    for ($i = 0; $i -lt $pts.Count; $i++) { $arr[$i] = $this.P($pts[$i][0], $pts[$i][1], $pts[$i][2]) }
    $this.G.DrawCurve($this.Thin, $arr, 0.5)
  }

  # ---- parts -------------------------------------------------------------------------------------------------------
  Fan([double]$x, [double]$y, [double]$z, [double]$s) {
    $this.Box($x, $y, $z, $s, $s, 7, $false); $m = $s / 2; $r = $s * 0.42
    $this.Circle($x + $m, $y + $m, $z + 7, $r, $true, $false); $this.Circle($x + $m, $y + $m, $z + 7, $r * 0.28, $true, $true)
    for ($a = 0; $a -lt 7; $a++) { $t = $a * 2 * [Math]::PI / 7; $this.Line(@(($x + $m + [Math]::Cos($t) * $r * 0.28), ($y + $m + [Math]::Sin($t) * $r * 0.28), ($z + 7)), @(($x + $m + [Math]::Cos($t + 0.5) * $r * 0.95), ($y + $m + [Math]::Sin($t + 0.5) * $r * 0.95), ($z + 7)), $true) }
  }
  Heatsink([double]$x, [double]$y, [double]$z, [double]$w, [double]$d, [double]$h, [int]$fins) {
    $this.Box($x, $y, $z, $w, $d, 5, $false)
    for ($i = 0; $i -lt $fins; $i++) { $this.Box($x + 4 + $i * (($w - 8) / $fins), $y + 2, $z + 5, 2.2, $d - 4, $h, $true) }
  }
  Dimm([double]$x, [double]$y, [double]$z, [double]$l) {
    $this.Box($x, $y, $z, 2.2, $l, 26, $false)
    for ($i = 0; $i -lt 4; $i++) { $this.Box($x + 2.2, $y + 8 + $i * ($l - 14) / 4, $z + 8, 1.2, ($l - 20) / 5, 12, $true) }
  }
  Board([double]$x, [double]$y, [double]$z, [double]$w, [double]$d, [int]$dimms, [bool]$socket) {
    $this.Box($x, $y, $z, $w, $d, 3, $false)
    if ($socket) { $this.Box($x + $w * 0.42, $y + $d * 0.22, $z + 3, 34, 34, 4, $false); $this.Box($x + $w * 0.42 + 6, $y + $d * 0.22 + 6, $z + 7, 22, 22, 1.5, $true) }
    for ($i = 0; $i -lt $dimms; $i++) { $this.Box($x + $w * 0.14 + $i * 8, $y + $d * 0.1, $z + 3, 4, 74, 6, $true) }
    for ($i = 0; $i -lt 3; $i++) { $this.Box($x + 10, $y + $d * 0.5 + $i * 18, $z + 3, 90, 7, 5, $true) }
    for ($i = 0; $i -lt 6; $i++) { $this.Circle($x + $w * 0.8 + ($i % 3) * 9, $y + $d * 0.3 + [Math]::Floor($i / 3) * 9, $z + 3, 3, $false, $true) }
    $this.Box($x + $w - 26, $y + $d - 34, $z + 3, 20, 28, 12, $true)
  }
  M2([double]$x, [double]$y, [double]$z) { $this.Box($x, $y, $z, 16, 66, 2, $false); $this.Box($x + 2, $y + 6, $z + 2, 12, 12, 1.5, $true); $this.Box($x + 2, $y + 24, $z + 2, 12, 16, 1.5, $true) }
  Ssd([double]$x, [double]$y, [double]$z) { $this.Box($x, $y, $z, 54, 80, 7, $false); $this.Box($x + 8, $y + 12, $z + 7, 38, 42, 0.8, $true); $this.Box($x + 20, $y + 80, $z + 1, 14, 8, 4, $true) }
  Gpu([double]$x, [double]$y, [double]$z, [double]$l) {
    $this.Box($x, $y, $z, $l, 66, 5, $false); $this.Box($x + 6, $y + 4, $z + 5, $l - 14, 58, 20, $false)
    $this.Circle($x + $l * 0.3, $y + 33, $z + 25, 18, $true, $false); $this.Circle($x + $l * 0.68, $y + 33, $z + 25, 18, $true, $false)
    $this.Box($x - 3, $y, $z, 3, 70, 36, $false)
  }
  Psu([double]$x, [double]$y, [double]$z) { $this.Box($x, $y, $z, 150, 140, 86, $false); $this.Circle($x + 75, $y + 70, $z + 86, 34, $true, $false); $this.Circle($x + 75, $y + 70, $z + 86, 8, $false, $true); $this.Cable(@(@(($x + 150), ($y + 20), ($z + 30)), @(($x + 190), ($y + 36), ($z + 10)), @(($x + 214), ($y + 90), ($z + 40)))) }
  Battery([double]$x, [double]$y, [double]$z, [double]$w, [double]$d) { $this.Box($x, $y, $z, $w, $d, 8, $false); for ($i = 1; $i -lt 3; $i++) { $this.Line(@(($x + $i * $w / 3), $y, ($z + 8)), @(($x + $i * $w / 3), ($y + $d), ($z + 8)), $true) } ; $this.Box($x + $w - 14, $y + $d, $z + 1, 12, 4, 4, $true) }
  Lcd([double]$x, [double]$y, [double]$z, [double]$w, [double]$d) {
    $this.Box($x, $y, $z, $w, $d, 5, $false); $i = 12
    $this.Poly(@(@(($x + $i), ($y + $i), ($z + 5)), @(($x + $w - $i), ($y + $i), ($z + 5)), @(($x + $w - $i), ($y + $d - $i), ($z + 5)), @(($x + $i), ($y + $d - $i), ($z + 5))), $false, $true)
    $this.Circle($x + $w / 2, $y + 6, $z + 5, 2.2, $false, $true)
  }
  Keyboard([double]$x, [double]$y, [double]$z, [double]$w, [double]$d, [int]$rows, [int]$cols, [bool]$nub) {
    $this.Box($x, $y, $z, $w, $d, 5, $false)
    $kw = ($w - 16) / $cols; $kd = ($d * 0.62 - 6) / $rows
    for ($r = 0; $r -lt $rows; $r++) { for ($c = 0; $c -lt $cols; $c++) { $this.Box($x + 8 + $c * $kw + 1.2, $y + 8 + $r * $kd + 1.2, $z + 5, $kw - 2.4, $kd - 2.4, 1.6, $true) } }
    if ($nub) { $this.NubDot($x + $w / 2, $y + 8 + $kd * 2.2, $z + 6.6, 3.6) }
    $this.Box($x + $w * 0.36, $y + $d * 0.74, $z + 5, $w * 0.28, $d * 0.16, 1.2, $true)
  }
  Wlan([double]$x, [double]$y, [double]$z) { $this.Box($x, $y, $z, 22, 30, 2, $false); $this.Box($x + 4, $y + 6, $z + 2, 8, 8, 1.2, $true); $this.Cable(@(@(($x + 4), $y, ($z + 2)), @(($x - 10), ($y - 30), ($z + 4)), @(($x - 30), ($y - 70), ($z + 3)))); $this.Cable(@(@(($x + 18), $y, ($z + 2)), @(($x + 24), ($y - 34), ($z + 4)), @(($x + 40), ($y - 76), ($z + 3)))) }
  Speaker([double]$x, [double]$y, [double]$z) { $this.Box($x, $y, $z, 14, 46, 9, $false); for ($i = 0; $i -lt 4; $i++) { $this.Line(@(($x + 2), ($y + 6 + $i * 9), ($z + 9)), @(($x + 12), ($y + 6 + $i * 9), ($z + 9)), $true) } }
  Adapter([double]$x, [double]$y, [double]$z) { $this.Box($x, $y, $z, 60, 130, 24, $false); $this.Cable(@(@(($x + 30), ($y + 130), ($z + 12)), @(($x + 70), ($y + 170), ($z + 4)), @(($x + 120), ($y + 160), ($z + 2)))); $this.Cable(@(@(($x + 30), $y, ($z + 12)), @(($x - 20), ($y - 30), ($z + 4)), @(($x - 60), ($y - 20), ($z + 2)))) }

  # ---- diagram primitives (system / architecture drawings) ----------------------------------------------------------
  Tag([double]$x, [double]$y, [double]$z, [string]$text) {              # red dot + leader + mono caption (skipped on glow passes)
    if ($null -eq $this.Font) { return }
    $p = $this.P($x, $y, $z); $r = 5 * $this.Lw; $len = 54 * $this.Lw
    $this.G.DrawLine($this.Thin, $p.X, $p.Y, [single]($p.X + $len), $p.Y)
    $this.G.FillEllipse($this.Nub, [single]($p.X - $r), [single]($p.Y - $r), [single](2 * $r), [single](2 * $r))
    $this.G.DrawString($text, $this.Font, $this.Ink, [single]($p.X + $len + 8 * $this.Lw), [single]($p.Y - $this.Font.Size * 0.62))
  }
  Cyl([double]$cx, [double]$cy, [double]$z, [double]$r, [double]$h) {     # upright cylinder (storage, repositories)
    $c0 = $this.P($cx, $cy, $z); $c1 = $this.P($cx, $cy, $z + $h); $rx = 1.2247 * $r * $this.S; $ry = 0.7071 * $r * $this.S
    $this.G.FillEllipse($this.Bg, [single]($c0.X - $rx), [single]($c0.Y - $ry), [single](2 * $rx), [single](2 * $ry)); $this.G.DrawEllipse($this.Pen, [single]($c0.X - $rx), [single]($c0.Y - $ry), [single](2 * $rx), [single](2 * $ry))
    $this.G.FillRectangle($this.Bg, [single]($c1.X - $rx), $c1.Y, [single](2 * $rx), [single]($c0.Y - $c1.Y))
    $this.G.DrawLine($this.Pen, [single]($c1.X - $rx), $c1.Y, [single]($c0.X - $rx), $c0.Y); $this.G.DrawLine($this.Pen, [single]($c1.X + $rx), $c1.Y, [single]($c0.X + $rx), $c0.Y)
    $this.G.FillEllipse($this.Bg, [single]($c1.X - $rx), [single]($c1.Y - $ry), [single](2 * $rx), [single](2 * $ry)); $this.G.DrawEllipse($this.Pen, [single]($c1.X - $rx), [single]($c1.Y - $ry), [single](2 * $rx), [single](2 * $ry))
  }
  Dashed([double]$x, [double]$y, [double]$z, [double]$w, [double]$d) {    # dashed rectangle on the horizontal plane
    $arr = [Drawing.PointF[]]@($this.P($x, $y, $z), $this.P($x + $w, $y, $z), $this.P($x + $w, $y + $d, $z), $this.P($x, $y + $d, $z))
    $this.G.DrawPolygon($this.Dash, $arr)
  }
  Link([double[]]$a, [double[]]$b) { $this.G.DrawLine($this.Dash, $this.P($a[0], $a[1], $a[2]), $this.P($b[0], $b[1], $b[2])) }
  Rack([double]$x, [double]$y, [double]$z, [double]$h) {                   # server: tall box with drive-bay lines on the front
    $this.Box($x, $y, $z, 84, 110, $h, $false)
    for ($i = 1; $i -lt [int]($h / 26); $i++) { $this.Line(@($x, ($y + 110), ($z + $i * 26)), @(($x + 84), ($y + 110), ($z + $i * 26)), $true) }
    $this.Circle($x + 42, $y + 55, $z + $h, 14, $false, $true)
  }
  Pc([double]$x, [double]$y, [double]$z) {                                 # client: screen on a small stand
    $this.Box($x + 20, $y + 14, $z, 40, 30, 4, $true); $this.Box($x + 36, $y + 26, $z + 4, 8, 6, 22, $true); $this.Box($x, $y + 26, $z + 26, 80, 6, 56, $false)
  }
  Cloud([double]$x, [double]$y, [double]$z) { $this.Circle($x + 70, $y + 60, $z, 50, $true, $false); $this.Circle($x + 128, $y + 84, $z, 42, $true, $false); $this.Circle($x + 86, $y + 118, $z, 46, $true, $false); $this.Circle($x + 96, $y + 86, $z, 38, $true, $true) }
  Panel([double]$x, [double]$y, [double]$z) {                              # monitoring panel with a chart line
    $this.Box($x, $y, $z, 170, 8, 112, $false); $yy = $y + 8; $pts = @(14, 30, 22, 58, 40, 76, 52, 92)
    for ($i = 0; $i -lt 7; $i++) { $this.Line(@(($x + 12 + $i * 21), $yy, ($z + $pts[$i])), @(($x + 12 + ($i + 1) * 21), $yy, ($z + $pts[$i + 1])), $false) }
    for ($i = 1; $i -lt 4; $i++) { $this.Line(@(($x + 10), $yy, ($z + $i * 26)), @(($x + 160), $yy, ($z + $i * 26)), $true) }
  }
}

# fonts for the title block (bundled OFL fonts; nothing is installed)
$script:BpFonts = New-Object Drawing.Text.PrivateFontCollection
Get-ChildItem (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path 'assets\fonts') -Filter *.ttf | ForEach-Object { $script:BpFonts.AddFontFile($_.FullName) }
function BpFont([string]$pattern, [single]$px) {
  $fam = $script:BpFonts.Families | Where-Object { $_.Name -like $pattern } | Select-Object -First 1
  if (-not $fam) { $fam = New-Object Drawing.FontFamily 'Segoe UI' }
  $st = if ($fam.IsStyleAvailable('Regular')) { 'Regular' } else { 'Bold' }
  New-Object Drawing.Font $fam, $px, ([Drawing.FontStyle]$st), ([Drawing.GraphicsUnit]::Pixel)
}

# Styles: Line (matte background + halftone, dark or light scheme), XRay (glowing lines on navy), Sunset (black + stripe band).
# -Type overrides machine.blueprint (tower | laptop | tiny | tiny-fanless); -Label overrides the caption (default: the machine name).
function New-Blueprint {
  param($Machine, [string]$Scheme = 'dark', [ValidateSet('Line', 'XRay', 'Sunset')][string]$Style = 'Line', [string]$Type = '', [string]$Label = '', [string]$Out, [int]$Width = 3840, [int]$Height = 2160)
  $pal = Get-Palette 'desktop' $Scheme
  $col = { param($h, $a = 255) $x = $h.TrimStart('#'); [Drawing.Color]::FromArgb($a, [Convert]::ToInt32($x.Substring(0, 2), 16), [Convert]::ToInt32($x.Substring(2, 2), 16), [Convert]::ToInt32($x.Substring(4, 2), 16)) }
  $k = $Width / 3840.0
  $bgC = & $col $pal.background; $lineC = & $col $pal.onSurface; $nubC = & $col $pal.nub; $brandC = & $col $pal.'seed-brand'; $mutedC = & $col $pal.onSurfaceVariant; $fillC = $bgC
  if ($Style -eq 'XRay') { $bgC = & $col '#061321'; $lineC = & $col '#CFF6FF'; $mutedC = & $col '#7FB8D6'; $fillC = & $col '#071726' 205; $nubC = & $col '#FF5A4E' }
  if ($Style -eq 'Sunset') { $bgC = & $col '#0B0B0C'; $lineC = & $col '#F5F5F5'; $mutedC = & $col '#A8A8A8'; $fillC = $bgC }
  $bmp = New-Object Drawing.Bitmap $Width, $Height, ([Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.Clear($bgC)
  switch ($Style) {
    'XRay' { $gb = New-Object Drawing.Drawing2D.LinearGradientBrush ((New-Object Drawing.Rectangle 0, 0, $Width, $Height), (& $col '#04101C'), (& $col '#0B2036'), 90.0); $g.FillRectangle($gb, 0, 0, $Width, $Height); $gb.Dispose() }
    'Sunset' { $y = 1380 * $k
      foreach ($c in '#FEC514', '#FF8A2B', '#E95420', '#F04E98', '#7A3FA0') { $sb = New-Object Drawing.SolidBrush (& $col $c); $x1 = (1560 * $k) - ($y - 1380 * $k)
        $g.FillPolygon($sb, [Drawing.PointF[]]@((New-Object Drawing.PointF 0, ([single]$y)), (New-Object Drawing.PointF ([single]$x1), ([single]$y)), (New-Object Drawing.PointF ([single]($x1 - 66 * $k)), ([single]($y + 66 * $k))), (New-Object Drawing.PointF 0, ([single]($y + 66 * $k))))); $sb.Dispose(); $y += 66 * $k } }
    default { $dotB = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(26, $lineC))                       # halftone, fading toward the lower left
      for ($yy = 12; $yy -lt $Height; $yy += [int](28 * $k + 0.5)) { for ($xx = 12; $xx -lt $Width; $xx += [int](28 * $k + 0.5)) { $f = [Math]::Max(0, ($xx / $Width) * 0.8 + (1 - $yy / $Height) * 0.5 - 0.35); $r = (1.0 + 2.2 * [Math]::Min(1, $f)) * $k; $g.FillEllipse($dotB, [single]($xx - $r), [single]($yy - $r), [single](2 * $r), [single](2 * $r)) } }
      $dotB.Dispose() }
  }
  $type = if ($Type) { $Type } elseif ($Machine.PSObject.Properties.Name -contains 'blueprint' -and $Machine.blueprint) { $Machine.blueprint } else { 'tower' }
  $script:BpNoFan = $type -like '*fanless*'; if ($type -like 'tiny*') { $type = 'tiny' }
  $GRID = 275.0; $n = 4; $s = ($Height / 1350.0) * 0.98
  $ox = $Width * 0.62; $oy = ($Height * 0.50 - ($n - 1) * $GRID * 0.5 * $s)
  $passes = @()
  if ($Style -eq 'XRay') { $passes += , ([BP]::new($g, (& $col '#2FD2FF' 24), [Drawing.Color]::Transparent, [Drawing.Color]::Transparent, $s, $ox, $oy, 5.0 * $k)); $passes += , ([BP]::new($g, (& $col '#2FD2FF' 46), [Drawing.Color]::Transparent, [Drawing.Color]::Transparent, $s, $ox, $oy, 2.6 * $k)) }
  $passes += , ([BP]::new($g, $lineC, $fillC, $nubC, $s, $ox, $oy, $k))
  $passes[-1].Font = BpFont 'IBM Plex Mono SemiBold' (30 * $k); $passes[-1].Ink = New-Object Drawing.SolidBrush $mutedC
  $parts = switch ($type) {
    'tower' { @(
      @{ gx = 0; gy = 0; z = 60;  a = { param($b, $x, $y, $z) $b.Fan($x, $y, $z, 80) } },
      @{ gx = 1; gy = 0; z = 0;   a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 190, 260, 5, $false); for ($i = 1; $i -lt 6; $i++) { $b.Line(@(($x + 20), ($y + 40 * $i), ($z + 5)), @(($x + 170), ($y + 40 * $i), ($z + 5)), $true) } } },
      @{ gx = 2; gy = 0; z = 40;  a = { param($b, $x, $y, $z) $b.Psu($x, $y, $z) } },
      @{ gx = 3; gy = 0; z = 90;  a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 40, 200, 110, $false); for ($i = 0; $i -lt 8; $i++) { $b.Line(@(($x + 40), ($y + 20 + $i * 20), ($z + 20)), @(($x + 40), ($y + 20 + $i * 20), ($z + 90)), $true) } } },
      @{ gx = 0; gy = 1; z = 20;  a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 170, 130, 42, $false); $b.Box($x + 20, $y + 130, $z + 8, 130, 4, 26, $true) } },
      @{ gx = 1; gy = 1; z = 70;  a = { param($b, $x, $y, $z) $b.Board($x, $y, $z, 210, 300, 4, $true) } },
      @{ gx = 2; gy = 1; z = 140; a = { param($b, $x, $y, $z) $b.Gpu($x, $y, $z, 230) } },
      @{ gx = 3; gy = 1; z = 30;  a = { param($b, $x, $y, $z) $b.Ssd($x, $y, $z); $b.M2($x + 90, $y + 20, $z + 40) } },
      @{ gx = 0; gy = 2; z = 0;   a = { param($b, $x, $y, $z) $b.Keyboard($x, $y, $z, 300, 120, 5, 14, $false); $b.Cable(@(@($x, ($y + 20), ($z + 4)), @(($x - 40), ($y + 90), ($z + 2)), @(($x - 90), ($y + 80), $z))) } },
      @{ gx = 1; gy = 2; z = 150; a = { param($b, $x, $y, $z) $b.Heatsink($x, $y, $z, 80, 80, 36, 12); $b.Fan($x, $y, ($z + 70), 80) } },
      @{ gx = 2; gy = 2; z = 60;  a = { param($b, $x, $y, $z) for ($i = 0; $i -lt 4; $i++) { $b.Dimm(($x + $i * 22), $y, ($z + $i * 4), 76) } } },
      @{ gx = 3; gy = 2; z = 10;  a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 100, 146, 26, $false); $b.Box($x + 15, $y + 20, $z + 26, 70, 100, 1, $true) } },
      @{ gx = 1; gy = 3; z = 30;  a = { param($b, $x, $y, $z) $b.Adapter($x, $y, $z) } },
      @{ gx = 2; gy = 3; z = 0;   a = { param($b, $x, $y, $z) $b.Wlan($x, ($y + 50), $z); $b.Speaker(($x + 70), ($y + 40), $z) } }) }
    'laptop' { @(
      @{ gx = 0; gy = 0; z = 200; a = { param($b, $x, $y, $z) $b.Lcd($x, $y, $z, 250, 170) } },
      @{ gx = 1; gy = 0; z = 120; a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 250, 170, 4, $false); $b.Box($x + 80, $y + 50, $z + 4, 90, 70, 1.5, $true) } },
      @{ gx = 2; gy = 0; z = 40;  a = { param($b, $x, $y, $z) $b.Adapter($x, $y, $z) } },
      @{ gx = 3; gy = 0; z = 60;  a = { param($b, $x, $y, $z) $b.Speaker($x, $y, $z); $b.Speaker(($x + 60), $y, $z) } },
      @{ gx = 0; gy = 1; z = 90;  a = { param($b, $x, $y, $z) $b.Keyboard($x, $y, $z, 280, 190, 6, 15, $true) } },
      @{ gx = 1; gy = 1; z = 60;  a = { param($b, $x, $y, $z) $b.Board($x, $y, $z, 200, 150, 0, $false); $b.Box($x + 60, $y + 40, $z + 3, 36, 36, 3, $true) } },
      @{ gx = 2; gy = 1; z = 150; a = { param($b, $x, $y, $z) $b.Fan($x, $y, $z, 50); $b.Fan(($x + 70), $y, $z, 50); $b.Heatsink($x, ($y + 70), $z, 120, 40, 10, 10) } },
      @{ gx = 3; gy = 1; z = 20;  a = { param($b, $x, $y, $z) $b.Battery($x, $y, $z, 200, 90) } },
      @{ gx = 0; gy = 2; z = 10;  a = { param($b, $x, $y, $z) $b.M2($x, $y, $z); $b.M2(($x + 30), $y, ($z + 20)) } },
      @{ gx = 1; gy = 2; z = 80;  a = { param($b, $x, $y, $z) $b.Dimm($x, $y, $z, 60); $b.Dimm(($x + 20), $y, ($z + 14), 60) } },
      @{ gx = 2; gy = 2; z = 0;   a = { param($b, $x, $y, $z) $b.Wlan($x, ($y + 50), $z) } },
      @{ gx = 3; gy = 2; z = 0;   a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 250, 170, 3, $false); for ($i = 1; $i -lt 6; $i++) { $b.Line(@(($x + 15), ($y + 25 * $i), ($z + 3)), @(($x + 235), ($y + 25 * $i), ($z + 3)), $true) } } }) }
    'sys-client' { @(
      @{ gx = -1; gy = -1; z = 0; a = { param($b, $x, $y, $z) $b.Link(@(170, 760, 60), @(330, 600, 60)); $b.Link(@(60, 1010, 0), @(1040, 1010, 0)); $b.Dashed(300, 300, -8, 400, 400) } },
      @{ gx = 1.2; gy = 1.2; z = 0;   a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 340, 340, 18, $false); $b.Tag($x + 340, $y + 170, $z + 9, 'HARDWARE') } },
      @{ gx = 1.2; gy = 1.2; z = 72;  a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 340, 340, 18, $false); for ($i = 1; $i -lt 6; $i++) { $b.Line(@(($x + $i * 56), ($y + 20), ($z + 18)), @(($x + $i * 56), ($y + 320), ($z + 18)), $true) }; $b.Tag($x + 340, $y + 170, $z + 9, 'KERNEL') } },
      @{ gx = 1.2; gy = 1.2; z = 144; a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 340, 340, 18, $false); foreach ($c in @(@(40, 40), @(190, 60), @(70, 200), @(220, 210))) { $b.Box($x + $c[0], $y + $c[1], $z + 18, 80, 80, 6, $true) }; $b.Tag($x + 340, $y + 170, $z + 9, 'DRIVERS') } },
      @{ gx = 1.2; gy = 1.2; z = 216; a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 340, 340, 18, $false); foreach ($c in @(@(90, 90), @(250, 110), @(150, 250))) { $b.Circle($x + $c[0], $y + $c[1], $z + 18, 34, $false, $true); $b.Circle($x + $c[0], $y + $c[1], $z + 18, 10, $false, $false) }; $b.Tag($x + 340, $y + 170, $z + 9, 'SERVICES') } },
      @{ gx = 1.2; gy = 1.2; z = 288; a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 340, 340, 18, $false); for ($r = 0; $r -lt 3; $r++) { for ($c = 0; $c -lt 3; $c++) { $b.Box($x + 30 + $c * 100, $y + 30 + $r * 100, $z + 18, 80, 80, (12 + 10 * (($r + $c) % 3)), $false) } }; $b.Tag($x + 340, $y + 170, $z + 9, 'APPS') } },
      @{ gx = 3.1; gy = 0.3; z = 60;  a = { param($b, $x, $y, $z) for ($i = 0; $i -lt 3; $i++) { $b.Box($x + $i * 34, $y + $i * 26, $z, 96, 6, 128, $false); for ($k = 1; $k -lt 5; $k++) { $b.Line(@(($x + $i * 34 + 14), ($y + $i * 26 + 6), ($z + $k * 24)), @(($x + $i * 34 + 82), ($y + $i * 26 + 6), ($z + $k * 24)), $true) } }; $b.Tag($x + 164, $y + 58, $z + 64, 'OFFICE') } },
      @{ gx = 0.2; gy = 2.6; z = 0;   a = { param($b, $x, $y, $z) $b.Cyl($x + 60, $y + 60, $z, 34, 78); $b.Circle($x + 60, $y + 60, $z + 118, 26, $true, $false); $b.Tag($x + 96, $y + 60, $z + 40, 'USER') } },
      @{ gx = 0.2; gy = 3.6; z = 0;   a = { param($b, $x, $y, $z) for ($i = 0; $i -lt 6; $i++) { $b.Circle($x + 20 + $i * 180, $y + 22, $z, 10, $true, $false); $b.Box($x - 6 + $i * 180, $y - 4, $z + 30 + ($i % 2) * 44, 52, 52, (14 + $i * 7), $false) }; $b.NubDot($x + 20 + 5 * 180, $y + 22, $z, 7); $b.Tag($x + 60 + 5 * 180, $y + 22, $z, 'VERSIONS') } }) }
    'sys-server' { @(
      @{ gx = -1; gy = -1; z = 0; a = { param($b, $x, $y, $z) $b.Link(@(100, -100, 0), @(100, 100, 0)); $b.Link(@(100, 100, 0), @(400, 100, 0)); $b.Link(@(400, 100, 0), @(700, 100, 0)); $b.Link(@(700, 160, 0), @(700, 420, 0)); $b.Link(@(700, 420, 0), @(260, 420, 0)); $b.Link(@(700, 420, 0), @(960, 420, 0)); $b.Link(@(260, 520, 0), @(260, 860, 0)); $b.Link(@(260, 860, 0), @(820, 860, 0)); $b.Dashed(60, 330, -8, 520, 250) } },
      @{ gx = 0.0; gy = -0.75; z = 0; a = { param($b, $x, $y, $z) $b.Cloud($x, $y, $z); $b.Tag($x + 170, $y + 90, $z, 'INTERNET') } },
      @{ gx = 1.25; gy = 0.1; z = 0;  a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 150, 34, 116, $false); for ($k = 1; $k -lt 4; $k++) { $b.Line(@($x, ($y + 34), ($z + $k * 29)), @(($x + 150), ($y + 34), ($z + $k * 29)), $true) }; for ($k = 0; $k -lt 4; $k++) { for ($c = 0; $c -lt 3; $c++) { $xx = $x + 25 + $c * 50 + ($k % 2) * 25; if ($xx -lt $x + 150) { $b.Line(@($xx, ($y + 34), ($z + $k * 29)), @($xx, ($y + 34), ($z + ($k + 1) * 29)), $true) } } }; $b.Tag($x + 150, $y + 17, $z + 58, 'FIREWALL') } },
      @{ gx = 2.2; gy = 0.1; z = 0;   a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 250, 130, 28, $false); for ($i = 0; $i -lt 9; $i++) { $b.Box($x + 14 + $i * 25, $y + 130, $z + 8, 15, 1, 11, $true) }; $b.Tag($x + 250, $y + 65, $z + 14, 'SWITCH') } },
      @{ gx = 0.35; gy = 1.3; z = 0;  a = { param($b, $x, $y, $z) $b.Rack($x, $y, $z, 236); $b.Rack($x + 110, $y, $z, 236); $b.Rack($x + 220, $y, $z, 236); $b.Tag($x + 304, $y + 55, $z + 150, 'SERVERS') } },
      @{ gx = 2.1; gy = 1.25; z = 0;  a = { param($b, $x, $y, $z) $b.Cyl($x + 50, $y + 60, $z, 46, 34); $b.Cyl($x + 50, $y + 60, $z + 44, 46, 34); $b.Cyl($x + 50, $y + 60, $z + 88, 46, 34); $b.Cyl($x + 170, $y + 60, $z, 46, 34); $b.Cyl($x + 170, $y + 60, $z + 44, 46, 34); $b.Tag($x + 226, $y + 60, $z + 60, 'STORAGE') } },
      @{ gx = 3.2; gy = 1.2; z = 30;  a = { param($b, $x, $y, $z) $b.Panel($x, $y, $z); $b.Tag($x + 170, $y + 4, $z + 56, 'NETDATA') } },
      @{ gx = 0.5; gy = 2.9; z = 0;   a = { param($b, $x, $y, $z) for ($i = 0; $i -lt 5; $i++) { $b.Pc($x + $i * 130, $y, $z) }; $b.Tag($x + 600, $y + 30, $z + 50, 'CLIENTS') } }) }
    'sys-linux' { @(
      @{ gx = -1; gy = -1; z = 0; a = { param($b, $x, $y, $z) $b.Link(@(150, 250, 0), @(300, 400, 0)); $b.Link(@(730, 480, 60), @(900, 300, 60)); $b.Link(@(190, 900, 0), @(320, 720, 0)); $b.Dashed(250, 250, 196, 480, 480) } },
      @{ gx = 0.1; gy = 0.3; z = 0;   a = { param($b, $x, $y, $z) $b.Circle($x + 80, $y + 80, $z, 74, $true, $false); $b.Circle($x + 80, $y + 80, $z, 26, $true, $false); for ($a = 0; $a -lt 8; $a++) { $t = $a * [Math]::PI / 4; $b.Line(@(($x + 80 + [Math]::Cos($t) * 26), ($y + 80 + [Math]::Sin($t) * 26), $z), @(($x + 80 + [Math]::Cos($t) * 74), ($y + 80 + [Math]::Sin($t) * 74), $z), $true) }; $b.Tag($x + 150, $y + 80, $z, 'SYSTEMD') } },
      @{ gx = 1.0; gy = 1.0; z = 0;   a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 440, 440, 18, $false); for ($i = 1; $i -lt 8; $i++) { $b.Line(@(($x + $i * 55), ($y + 20), ($z + 18)), @(($x + $i * 55), ($y + 420), ($z + 18)), $true) }; $b.Tag($x + 440, $y + 220, $z + 9, 'KERNEL') } },
      @{ gx = 1.0; gy = 1.0; z = 80;  a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 440, 440, 14, $false); $b.Tag($x + 440, $y + 220, $z + 7, 'RUNTIME') } },
      @{ gx = 1.0; gy = 1.0; z = 94;  a = { param($b, $x, $y, $z) for ($r = 0; $r -lt 2; $r++) { for ($c = 0; $c -lt 3; $c++) { $b.Box($x + 40 + $c * 130, $y + 70 + $r * 180, $z, 96, 96, 96, $false); $b.Box($x + 58 + $c * 130, $y + 88 + $r * 180, $z + 96, 60, 60, 4, $true) } }; $b.Tag($x + 396, $y + 300, $z + 48, 'CONTAINERS') } },
      @{ gx = 3.2; gy = 0.2; z = 60;  a = { param($b, $x, $y, $z) $n = 0; foreach ($t in 'SSH', 'NETWORK', 'STORAGE', 'NETDATA') { $b.Box($x, $y + $n * 150, $z, 110, 110, 40, $false); $b.Circle($x + 55, $y + $n * 150 + 55, $z + 40, 24, $false, $true); $b.Tag($x + 110, $y + $n * 150 + 55, $z + 20, $t); $n++ } } },
      @{ gx = 0.2; gy = 3.0; z = 0;   a = { param($b, $x, $y, $z) $b.Cyl($x + 60, $y + 60, $z, 54, 40); $b.Cyl($x + 60, $y + 60, $z + 52, 54, 40); $b.Cyl($x + 60, $y + 60, $z + 104, 54, 40); $b.Tag($x + 124, $y + 60, $z + 70, 'PACKAGES') } }) }
    default { @(
      @{ gx = 0; gy = 0; z = 140; a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 170, 180, 8, $false); for ($i = 1; $i -lt 8; $i++) { $b.Line(@(($x + 20 * $i), ($y + 20), ($z + 8)), @(($x + 20 * $i), ($y + 80), ($z + 8)), $true) } } },
      @{ gx = 1; gy = 0; z = 60;  a = { param($b, $x, $y, $z) $b.Adapter($x, $y, $z) } },
      @{ gx = 2; gy = 0; z = 100; a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 60, 140, 5, $false) } },
      @{ gx = 0; gy = 1; z = 80;  a = { param($b, $x, $y, $z) $b.Board($x, $y, $z, 170, 180, 2, $true) } },
      @{ gx = 1; gy = 1; z = 150; a = { param($b, $x, $y, $z) if ($script:BpNoFan) { $b.Heatsink($x, $y, $z, 150, 110, 46, 18) } else { $b.Heatsink($x, $y, $z, 70, 70, 24, 10); $b.Fan($x, $y, ($z + 52), 70) } } },
      @{ gx = 2; gy = 1; z = 30;  a = { param($b, $x, $y, $z) $b.Ssd($x, $y, $z) } },
      @{ gx = 0; gy = 2; z = 20;  a = { param($b, $x, $y, $z) $b.Dimm($x, $y, $z, 60); $b.Dimm(($x + 22), $y, ($z + 8), 60) } },
      @{ gx = 1; gy = 2; z = 0;   a = { param($b, $x, $y, $z) $b.M2($x, $y, $z); $b.Wlan(($x + 50), ($y + 40), $z) } },
      @{ gx = 2; gy = 2; z = 0;   a = { param($b, $x, $y, $z) $b.Box($x, $y, $z, 170, 190, 6, $false) } }) }
  }
  foreach ($bp in $passes) { foreach ($p in ($parts | Sort-Object { $_.gx + $_.gy }, { $_.z })) { & $p.a $bp ($p.gx * $GRID) ($p.gy * $GRID) $p.z } }
  # title block (bottom left): ThinkLab + red dot + caption; brand tab at the right edge
  $cap = if ($Label) { $Label } else { ($Machine.fullName -replace '\s*\(.*\)$', '') }
  $sf = [Drawing.StringFormat]::GenericTypographic.Clone(); $sf.FormatFlags = $sf.FormatFlags -bor [Drawing.StringFormatFlags]::MeasureTrailingSpaces
  $f1 = BpFont 'Barlow Condensed SemiBold' (118 * $k); $f2 = BpFont 'IBM Plex Mono' (46 * $k); $inkB = New-Object Drawing.SolidBrush $lineC; $mutB = New-Object Drawing.SolidBrush $mutedC
  $g.DrawString('ThinkLab', $f1, $inkB, [single](150 * $k), [single]($Height - 266 * $k), $sf)
  $wf = $g.MeasureString('ThinkLab', $f1, (New-Object Drawing.PointF 0, 0), $sf).Width
  $nb = New-Object Drawing.SolidBrush $nubC; $g.FillEllipse($nb, [single](150 * $k + $wf + 10 * $k), [single]($Height - 176 * $k), [single](24 * $k), [single](24 * $k))
  $g.DrawString($cap.ToUpper(), $f2, $mutB, [single](150 * $k + $wf + 62 * $k), [single]($Height - 198 * $k), $sf)
  $tab = New-Object Drawing.SolidBrush $brandC; $g.FillRectangle($tab, [single]($Width - 100 * $k), [single]($Height - 580 * $k), [single](100 * $k), [single](360 * $k))
  $st = New-Object Drawing.StringFormat; $st.Alignment = 'Center'; $st.LineAlignment = 'Center'
  $g.TranslateTransform([single]($Width - 50 * $k), [single]($Height - 400 * $k)); $g.RotateTransform(-90)
  $g.DrawString('ThinkLab', (BpFont 'Barlow Condensed SemiBold' (64 * $k)), [Drawing.Brushes]::White, 0, 0, $st); $g.ResetTransform()
  $g.Dispose(); New-Item -ItemType Directory -Force (Split-Path $Out -Parent) | Out-Null
  $bmp.Save($Out, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}
