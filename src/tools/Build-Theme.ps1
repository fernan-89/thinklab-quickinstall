# Builds the ThinkLab Ventoy theme (Canonical/Vanilla dark look, same tokens as the ThinkLab web app).
# Output: <Out>\theme.txt + PNG slices + icons\*.png   (ASCII only; run with Windows PowerShell)
param([string]$Out = (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path 'build\USB\ventoy\theme\thinklab'))
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force "$Out\icons" | Out-Null

function C($hex, $a = 255) { $h = $hex.TrimStart('#'); [Drawing.Color]::FromArgb($a, [Convert]::ToInt32($h.Substring(0,2),16), [Convert]::ToInt32($h.Substring(2,2),16), [Convert]::ToInt32($h.Substring(4,2),16)) }
$BG = '#111111'; $NAV = '#000000'; $BAND = '#1e1e1e'; $SURF = '#1d1d1d'; $BORDER = '#3a3a3a'; $BRAND = '#e95420'; $TEXT = '#f3f3f3'; $MUTED = '#a8a8a8'; $LINK = '#5aa7ff'

function Solid($path, $w, $h, $color, $alpha = 255) {
  $b = New-Object Drawing.Bitmap $w, $h, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [Drawing.Graphics]::FromImage($b); $g.Clear((C $color $alpha)); $g.Dispose()
  $b.Save($path, [Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
}
function RoundRect($g, $brush, $x, $y, $w, $h, $r) {
  $p = New-Object Drawing.Drawing2D.GraphicsPath
  $p.AddArc($x, $y, $r*2, $r*2, 180, 90); $p.AddArc($x+$w-$r*2, $y, $r*2, $r*2, 270, 90)
  $p.AddArc($x+$w-$r*2, $y+$h-$r*2, $r*2, $r*2, 0, 90); $p.AddArc($x, $y+$h-$r*2, $r*2, $r*2, 90, 90); $p.CloseFigure()
  $g.FillPath($brush, $p); $p.Dispose()
}
function Mark($g, $x, $y, $size) {          # orange square with a white ring + dot (brand mark)
  $br = New-Object Drawing.SolidBrush (C $BRAND); RoundRect $g $br $x $y $size $size ([int]($size/8)); $br.Dispose()
  $pen = New-Object Drawing.Pen ([Drawing.Color]::White), ([single]($size/9)); $d = $size * 0.52; $o = ($size - $d) / 2
  $g.DrawEllipse($pen, [single]($x+$o), [single]($y+$o), [single]$d, [single]$d); $pen.Dispose()
  $wb = New-Object Drawing.SolidBrush ([Drawing.Color]::White); $r = $size * 0.11; $g.FillEllipse($wb, [single]($x+$size/2-$r), [single]($y+$size/2-$r), [single]($r*2), [single]($r*2)); $wb.Dispose()
}

# ---- background 1920x1080 ----
$W = 1920; $H = 1080
$bmp = New-Object Drawing.Bitmap $W, $H, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear((C $BG))
$g.FillRectangle((New-Object Drawing.SolidBrush (C $NAV)), 0, 0, $W, 46)
$g.FillRectangle((New-Object Drawing.SolidBrush (C $BAND)), 0, 46, $W, 150)
$g.FillRectangle((New-Object Drawing.SolidBrush (C $BRAND)), 0, 196, $W, 3)
$f1 = New-Object Drawing.Font 'Segoe UI', 15; $f2 = New-Object Drawing.Font 'Segoe UI Light', 58; $f3 = New-Object Drawing.Font 'Segoe UI', 20
$tb = New-Object Drawing.SolidBrush (C $TEXT); $mb = New-Object Drawing.SolidBrush (C $MUTED)
$g.DrawString('ThinkLab Quick Install', $f1, $tb, 120, 11)
$g.DrawString('Windows 10 / 11  |  Server  |  Linux  |  Recovery', $f1, $mb, 1000, 11)
Mark $g 120 70 100
$g.DrawString('ThinkLab', $f2, $tb, 244, 52)
$g.DrawString(('Kit de instala' + [char]0xE7 + [char]0xE3 + 'o e recupera' + [char]0xE7 + [char]0xE3 + 'o  /  Install and recovery kit'), $f3, $mb, 252, 146)
$g.Dispose(); $bmp.Save("$Out\background.png", [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()

# ---- 9-slice pixmaps ----
Solid "$Out\menu_c.png" 8 8 $SURF 235
foreach ($n in 'n','s') { Solid "$Out\menu_$n.png" 8 1 $BORDER 255; Solid "$Out\terminal_box_$n.png" 8 1 $BORDER 255 }
foreach ($n in 'e','w') { Solid "$Out\menu_$n.png" 1 8 $BORDER 255; Solid "$Out\terminal_box_$n.png" 1 8 $BORDER 255 }
foreach ($n in 'nw','ne','sw','se') { Solid "$Out\menu_$n.png" 1 1 $BORDER 255; Solid "$Out\terminal_box_$n.png" 1 1 $BORDER 255 }
Solid "$Out\terminal_box_c.png" 8 8 $BG 235
Solid "$Out\select_c.png" 8 8 '#2f2f2f' 255
Solid "$Out\select_w.png" 3 8 $BRAND 255
Solid "$Out\slider_c.png" 8 8 '#6b6b6b' 255; Solid "$Out\slider_n.png" 8 2 '#6b6b6b' 255; Solid "$Out\slider_s.png" 8 2 '#6b6b6b' 255

# ---- class icons (28x28 rounded tiles) ----
$icons = [ordered]@{
  win10 = @('10', '#0066cc'); win11 = @('11', '#0e5fbf'); winsrv = @('S', '#1b3a6b'); winlite = @('L', '#3b7dd8')
  ubuntu = @('U', '#e95420'); alma = @('A', '#0f6d9c'); suse = @('S', '#5fa31c')
  vtoydir = @('>', '#e95420'); vtoyiso = @('i', '#6b6b6b'); vtoyret = @('<', '#6b6b6b')
  pe = @('PE', '#1a9a2e'); rescue = @('R', '#c47f00'); memtest = @('M', '#a3121f'); tools = @('T', '#6b6b6b')
}
$ff = New-Object Drawing.Font 'Segoe UI Semibold', 11
foreach ($k in $icons.Keys) {
  $b = New-Object Drawing.Bitmap 28, 28, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $gi = [Drawing.Graphics]::FromImage($b); $gi.SmoothingMode = 'AntiAlias'; $gi.TextRenderingHint = 'AntiAliasGridFit'; $gi.Clear([Drawing.Color]::Transparent)
  $br = New-Object Drawing.SolidBrush (C $icons[$k][1]); RoundRect $gi $br 1 1 26 26 5; $br.Dispose()
  $sf = New-Object Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
  $gi.DrawString($icons[$k][0], $ff, [Drawing.Brushes]::White, (New-Object Drawing.RectangleF 0, 0, 28, 28), $sf)
  $gi.Dispose(); $b.Save("$Out\icons\$k.png", [Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
}

# ---- theme.txt ----
@"
desktop-image: "background.png"
title-text: " "
title-color: "$TEXT"
message-color: "$TEXT"

terminal-box: "terminal_box_*.png"

+ boot_menu {
  left = 12%
  width = 76%
  top = 24%
  height = 58%

  menu_pixmap_style = "menu_*.png"

  item_color = "$TEXT"
  item_height = 34
  item_spacing = 2
  item_padding = 8
  item_icon_space = 12

  selected_item_color = "#ffffff"
  selected_item_pixmap_style = "select_*.png"

  icon_width = 28
  icon_height = 28

  scrollbar = true
  scrollbar_width = 10
  scrollbar_thumb = "slider_*.png"
}

+ progress_bar {
  id = "__timeout__"
  text = "@TIMEOUT_NOTIFICATION_SHORT@"
  left = 20%
  width = 60%
  top = 88%
  text_color = "$BRAND"
  bar_style = "*"
  highlight_style = "*"
}

+ hbox { left = 12%  top = 95%-50  width = 15%  height = 25  + label { text = "@VTOY_ISO_RAW@"  color = "$BRAND" align = "left" } }
+ hbox { left = 12%  top = 95%-25  width = 15%  height = 25  + label { text = "@VTOY_MEM_DISK@" color = "$BRAND" align = "left" } }
+ hbox { left = 30%  top = 95%-50  width = 15%  height = 25  + label { text = "@VTOY_GRUB2_MODE@"  color = "$BRAND" align = "left" } }
+ hbox { left = 30%  top = 95%-25  width = 15%  height = 25  + label { text = "@VTOY_WIMBOOT_MODE@" color = "$BRAND" align = "left" } }
+ hbox { left = 30%  top = 95%     width = 60%  height = 25  + label { text = "@VTOY_HOTKEY_TIP@"  color = "$LINK"  align = "left" } }
+ hbox { left = 90%  top = 55      width = 10%  height = 25  + label { text = "@VTOY_ISO_UEFI_DRV@" color = "$BRAND" align = "left" } }
"@ | Set-Content "$Out\theme.txt" -Encoding ASCII
"theme written to $Out"
