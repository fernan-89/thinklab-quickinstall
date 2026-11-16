# Isometric "exploded view" diagrams for the documentation (inline SVG, themed by CSS variables, PT and EN labels).
# Dot-source this file; Get-Diagram <name> <pt|en> returns an <svg> string. ASCII only (HTML entities for accents).
#   Colours come from CSS variables so the same SVG works in the light and the dark theme (see $DiagramCss).

class IsoScene {
  [double]$MinX = 1e9; [double]$MaxX = -1e9; [double]$MinY = 1e9; [double]$MaxY = -1e9
  [System.Text.StringBuilder]$Body = (New-Object System.Text.StringBuilder)
  [System.Collections.ArrayList]$Items = (New-Object System.Collections.ArrayList)
  [double[]] P([double]$x, [double]$y, [double]$z) { return @((($x - $y) * 0.866), (($x + $y) * 0.5 - $z)) }
  [string] Fmt([double]$v) { return $v.ToString('0.#', [Globalization.CultureInfo]::InvariantCulture) }
  [string] Pt([double]$x, [double]$y, [double]$z) {
    $p = $this.P($x, $y, $z)
    if ($p[0] -lt $this.MinX) { $this.MinX = $p[0] }; if ($p[0] -gt $this.MaxX) { $this.MaxX = $p[0] }
    if ($p[1] -lt $this.MinY) { $this.MinY = $p[1] }; if ($p[1] -gt $this.MaxY) { $this.MaxY = $p[1] }
    return ('{0},{1}' -f $this.Fmt($p[0]), $this.Fmt($p[1]))
  }
  [string] Poly([double[][]]$pts, [string]$cls) {
    $s = ($pts | ForEach-Object { $this.Pt($_[0], $_[1], $_[2]) }) -join ' '
    return "<polygon class=""$cls"" points=""$s""/>"
  }
  # kind: plain | brand | blue | pink | teal | yellow | navy  (accent colours paint the two visible side faces; the top stays light, like the Elastic cubes)
  Cube([double]$x, [double]$y, [double]$z, [double]$w, [double]$d, [double]$h, [string]$kind) {
    $top = $this.Poly(@(@($x, $y, ($z + $h)), @(($x + $w), $y, ($z + $h)), @(($x + $w), ($y + $d), ($z + $h)), @($x, ($y + $d), ($z + $h))), "top")
    $left = $this.Poly(@(@($x, ($y + $d), ($z + $h)), @(($x + $w), ($y + $d), ($z + $h)), @(($x + $w), ($y + $d), $z), @($x, ($y + $d), $z)), "lf $kind")
    $right = $this.Poly(@(@(($x + $w), $y, ($z + $h)), @(($x + $w), ($y + $d), ($z + $h)), @(($x + $w), ($y + $d), $z), @(($x + $w), $y, $z)), "rt $kind")
    [void]$this.Body.Append("<g class=""cube"">$top$left$right</g>")
  }
  Plane([double]$x, [double]$y, [double]$z, [double]$w, [double]$d) {
    [void]$this.Body.Append($this.Poly(@(@($x, $y, $z), @(($x + $w), $y, $z), @(($x + $w), ($y + $d), $z), @($x, ($y + $d), $z)), "plane"))
  }
  Link([double[]]$a, [double[]]$b) {
    $p = $this.P($a[0], $a[1], $a[2]); $q = $this.P($b[0], $b[1], $b[2])
    [void]$this.Body.Append(('<line class="link" x1="{0}" y1="{1}" x2="{2}" y2="{3}"/>' -f $this.Fmt($p[0]), $this.Fmt($p[1]), $this.Fmt($q[0]), $this.Fmt($q[1])))
    [void]$this.Pt($a[0], $a[1], $a[2]); [void]$this.Pt($b[0], $b[1], $b[2])
  }
  # label with a leader line from a 3D anchor to the left (side=end) or right (side=start) margin of the drawing
  Label([double[]]$anchor, [string]$side, [string]$title, [string]$sub) { [void]$this.Items.Add(@{ a = $anchor; side = $side; t = $title; s = $sub; two = $false }) }
  Heading([double[]]$anchor, [string]$side, [string]$title, [string]$cap) { [void]$this.Items.Add(@{ a = $anchor; side = $side; t = $title; s = $cap; two = $true }) }
  [string] Svg([string]$aria) {
    $lab = New-Object System.Text.StringBuilder
    $maxChars = 0
    foreach ($it in $this.Items) {
      $n = $it.t.Length + $(if ($it.s) { $it.s.Length + 3 } else { 0 }); if ($it.two) { $n = [Math]::Max($it.t.Length, $it.s.Length) }
      if ($n -gt $maxChars) { $maxChars = $n }
    }
    $pad = 30; $textW = [Math]::Min(380, $maxChars * 9.4)
    $L = $this.MinX - $pad; $R = $this.MaxX + $pad
    foreach ($it in $this.Items) {
      $p = $this.P($it.a[0], $it.a[1], $it.a[2]); $ax = $p[0]; $ay = $p[1]
      if ($it.side -eq 'start') { $tx = $R; $end = $R - 8 } else { $tx = $L; $end = $L + 8 }
      [void]$lab.Append(('<line class="lead" x1="{0}" y1="{1}" x2="{2}" y2="{1}"/><circle class="dot" cx="{0}" cy="{1}" r="2.4"/>' -f $this.Fmt($ax), $this.Fmt($ay), $this.Fmt($end)))
      if ($it.two) {
        [void]$lab.Append("<text class=""lt"" x=""$($this.Fmt($tx))"" y=""$($this.Fmt($ay - 4))"" text-anchor=""$($it.side)"">$($it.t)</text><text class=""ls2"" x=""$($this.Fmt($tx))"" y=""$($this.Fmt($ay + 11))"" text-anchor=""$($it.side)"">$($it.s)</text>")
      } else {
        $t = "<text class=""lt"" x=""$($this.Fmt($tx))"" y=""$($this.Fmt($ay + 4))"" text-anchor=""$($it.side)"">$($it.t)"
        if ($it.s) { $t += "<tspan class=""ls""> - $($it.s)</tspan>" }
        [void]$lab.Append("$t</text>")
      }
    }
    $vx = $this.MinX - $pad - $textW; $vy = $this.MinY - 24; $vw = ($this.MaxX - $this.MinX) + 2 * ($pad + $textW); $vh = ($this.MaxY - $this.MinY) + 48
    return "<svg class=""iso"" viewBox=""$($this.Fmt($vx)) $($this.Fmt($vy)) $($this.Fmt($vw)) $($this.Fmt($vh))"" role=""img"" aria-label=""$aria"" xmlns=""http://www.w3.org/2000/svg""><g class=""shapes"">$($this.Body)</g><g class=""labels"">$lab</g></svg>"
  }
}

# CSS shared by every diagram (goes into assets\style.css). Light/dark follow the page theme.
function Get-DiagramVars([string]$scheme) {
  $p = Get-Palette 'diagram' $scheme
  "--d-face:$($p.surface);--d-face2:$($p.surfaceHigh);--d-face3:$($p.surfaceDim);--d-edge:$($p.outline);--d-ink:$($p.onSurface);--d-muted:$($p.onSurfaceVariant);--d-dot:$($p.outline);--d-brand:$($p.'seed-brand');--d-blue:$($p.'seed-blue');--d-pink:$($p.'seed-pink');--d-teal:$($p.'seed-teal');--d-yellow:$($p.'seed-yellow');--d-navy:$($p.'seed-navy');--d-nub:$($p.nub)"
}
$script:DiagramCss = (@'
svg.iso{width:100%;height:auto;display:block;margin:1.2rem 0;__LIGHT__}
:root:not([data-theme=light]) svg.iso{__DARK__}
svg.iso .cube polygon{stroke:var(--d-edge);stroke-width:1.1;stroke-linejoin:round}
svg.iso .top{fill:var(--d-face)}svg.iso .lf{fill:var(--d-face2)}svg.iso .rt{fill:var(--d-face3)}
svg.iso .lf.brand{fill:var(--d-brand)}svg.iso .rt.brand{fill:#7a2a12}
svg.iso .lf.blue{fill:var(--d-blue)}svg.iso .rt.blue{fill:#06377d}
svg.iso .lf.pink{fill:var(--d-pink)}svg.iso .rt.pink{fill:var(--d-navy)}
svg.iso .lf.teal{fill:var(--d-teal)}svg.iso .rt.teal{fill:#0b5f51}
svg.iso .lf.yellow{fill:var(--d-yellow)}svg.iso .rt.yellow{fill:#8a6a00}
svg.iso .lf.navy{fill:#26356b}svg.iso .rt.navy{fill:var(--d-navy)}
svg.iso .plane{fill:none;stroke:var(--d-edge);stroke-width:1;stroke-dasharray:4 4;opacity:.8}
svg.iso .link{stroke:var(--d-edge);stroke-width:1;stroke-dasharray:3 3;opacity:.7}
svg.iso .lead{stroke:var(--d-edge);stroke-width:1;opacity:.85}svg.iso .dot{fill:var(--d-nub)}
svg.iso text{font-family:'IBM Plex Mono',ui-monospace,SFMono-Regular,Consolas,Menlo,monospace;font-size:15px;letter-spacing:.04em;fill:var(--d-ink)}
svg.iso .lt{font-weight:700}svg.iso .ls{font-weight:400;fill:var(--d-muted)}svg.iso .ls2{font-size:13px;fill:var(--d-muted);font-weight:400}
'@).Replace('__LIGHT__', (Get-DiagramVars 'light')).Replace('__DARK__', (Get-DiagramVars 'dark'))

# Standalone SVG (README / GitHub <img>): embeds the CSS, light by default, dark through prefers-color-scheme.
function Get-DiagramStandalone([string]$name, [string]$lang) {
  $svg = Get-Diagram $name $lang
  $css = ($script:DiagramCss -split "`n" | Where-Object { $_ -notmatch '^:root' }) -join "`n"
  $dark = 'svg.iso{' + (Get-DiagramVars 'dark') + '}'
  $svg.Replace('<svg class="iso"', '<svg class="iso" width="1100"').Replace('<g class="shapes">', "<style>$css`n@media (prefers-color-scheme:dark){$dark}</style><g class=""shapes"">")
}

function T2($lang, $pt, $en) { if ($lang -eq 'pt') { $pt } else { $en } }

# ------------------------------------------------------------------ generic exploded stack (used by the overview, the platform view and every install paper)
#   $cfg: left = @{ k; t; s }            cube at the lower left (foundation)
#         topA / topB = @{ k; t; s }     cubes on top (topB optional)
#         plane = @{ t; s }              dashed plane between the top cubes and the stack (optional)
#         slabs = @( @{ k; t; s } ... )  bottom to top, labelled on the right
function Diagram-Stack($lang, $cfg, [string]$aria) {
  $sc = [IsoScene]::new()
  $n = @($cfg.slabs).Count; $step = 36; $x0 = 175; $y0 = 0
  $topZ = ($n - 1) * $step + 22                       # top of the highest slab
  $planeZ = $topZ + 31; $cubeZ = $planeZ + 30
  for ($i = 0; $i -lt $n; $i++) { $sc.Cube($x0, $y0, $i * $step, 150, 150, 22, $cfg.slabs[$i].k) }
  if ($cfg.left) { $sc.Cube(-40, 180, 0, 110, 110, 110, $cfg.left.k) }
  if ($cfg.plane) { $sc.Plane(-80, -80, $planeZ, 260, 260) }
  if ($cfg.topA) { $sc.Cube(-64, 64, $cubeZ, 100, 100, 100, $cfg.topA.k) }
  if ($cfg.topB) { $sc.Cube(64, -64, $cubeZ, 100, 100, 100, $cfg.topB.k) }
  if ($cfg.topA) { $sc.Link(@(-14, 114, $cubeZ), @(-14, 114, 112)) }
  if ($cfg.topB) { $sc.Link(@(114, 0, $cubeZ), @(165, 40, $topZ)) }
  if ($cfg.topA) { $sc.Heading(@(-64, 164, ($cubeZ + 50)), 'end', $cfg.topA.t, $cfg.topA.s) }
  if ($cfg.left) { $sc.Heading(@(-40, 290, 55), 'end', $cfg.left.t, $cfg.left.s) }
  if ($cfg.topB) { $sc.Heading(@(164, -14, ($cubeZ + 50)), 'start', $cfg.topB.t, $cfg.topB.s) }
  if ($cfg.plane) { $sc.Label(@(180, 0, $planeZ), 'start', $cfg.plane.t, $cfg.plane.s) }
  for ($i = 0; $i -lt $n; $i++) { $sc.Label(@(($x0 + 150), ($y0 + 75), ($i * $step + 11)), 'start', $cfg.slabs[$i].t, $cfg.slabs[$i].s) }
  $sc.Svg($aria)
}

function Diagram-Overview($lang) {
  Diagram-Stack $lang @{
    left = @{ k = 'blue'; t = (T2 $lang 'MENU VENTOY' 'VENTOY MENU'); s = (T2 $lang 'TEMA - ATALHOS - KITS' 'THEME - SHORTCUTS - KITS') }
    topA = @{ k = 'brand'; t = 'THINKLAB'; s = (T2 $lang 'PLATAFORMA SAAS' 'SAAS PLATFORM') }
    topB = @{ k = 'pink'; t = 'NETDATA'; s = (T2 $lang 'MONITORAMENTO' 'MONITORING') }
    plane = @{ t = 'SITE.JSON'; s = (T2 $lang 'SUAS M&Aacute;QUINAS' 'YOUR MACHINES') }
    slabs = @(
      @{ k = 'plain'; t = (T2 $lang 'MANIFESTO' 'MANIFEST'); s = 'SHA-256' },
      @{ k = 'plain'; t = (T2 $lang 'INVENT&Aacute;RIO' 'INVENTORY'); s = 'inventory.json' },
      @{ k = 'teal';  t = 'BRANDING'; s = 'OEM - WALLPAPERS' },
      @{ k = 'plain'; t = 'FIRSTLOGON'; s = 'DRIVERS - OFFICE - APPS' },
      @{ k = 'plain'; t = 'KITS'; s = 'UNATTEND - KICKSTART' })
  } (T2 $lang 'Vis&atilde;o explodida do ThinkLab Quick Install' 'Exploded view of ThinkLab Quick Install')
}

function Diagram-Platform($lang) {
  Diagram-Stack $lang @{
    left = @{ k = 'blue'; t = 'QUICK INSTALL'; s = (T2 $lang 'PEN-DRIVE DE PROVISIONAMENTO' 'PROVISIONING STICK') }
    topA = @{ k = 'brand'; t = 'THINKLAB'; s = (T2 $lang 'PLATAFORMA SAAS' 'SAAS PLATFORM') }
    plane = @{ t = 'PLATFORM-GATEWAY'; s = 'API' }
    slabs = @(
      @{ k = 'brand';  t = (T2 $lang 'MANUTEN&Ccedil;&Atilde;O' 'MAINTENANCE'); s = 'it-hardware-maintenance' },
      @{ k = 'navy';   t = (T2 $lang 'SA&Uacute;DE' 'HEALTH'); s = 'it-health-monitoring' },
      @{ k = 'pink';   t = 'PATCHES'; s = 'it-patch-registry' },
      @{ k = 'yellow'; t = (T2 $lang 'LICEN&Ccedil;AS' 'LICENSES'); s = 'it-license-registry' },
      @{ k = 'teal';   t = (T2 $lang 'DESCOBERTA' 'DISCOVERY'); s = 'it-discovery' },
      @{ k = 'blue';   t = (T2 $lang 'ATIVOS' 'ASSETS'); s = 'it-asset-registry' })
  } (T2 $lang 'O que o pen-drive entrega aos m&oacute;dulos do ThinkLab' 'What the stick hands to the ThinkLab modules')
}

# ------------------------------------------------------------------ diagram: machine x system matrix (generated from the real kits)
function Diagram-Matrix($lang) {
  $kits = @(Get-WindowsKits $SITE $CAT); $lin = @(Get-LinuxKits $SITE $CAT)
  $cols = @(
    @{ id = 'W10'; t = 'WINDOWS 10'; os = @('W10'); k = 'brand' },
    @{ id = 'W11'; t = 'WINDOWS 11'; os = @('W11'); k = 'brand' },
    @{ id = 'LT';  t = 'LTSC - IOT'; os = @('L21', 'I10', 'L24'); k = 'navy' },
    @{ id = 'S19'; t = 'SERVER 2019'; os = @('S19'); k = 'blue' },
    @{ id = 'LX';  t = 'LINUX'; os = @(); k = 'teal' })
  $rows = @(); foreach ($m in $SITE.machines) { $rows += @{ code = $m.code; t = $m.label.ToUpper(); sub = $m.fullName } }
  $rows += @{ code = 'BASE'; t = 'BASE'; sub = (T2 $lang 'QUALQUER M&Aacute;QUINA' 'ANY MACHINE') }
  $cell = 84; $sc = [IsoScene]::new()
  # rows (machines) run along x, columns (systems) along y; painted back to front (x+y ascending)
  $cells = @()
  for ($r = 0; $r -lt $rows.Count; $r++) {
    for ($c = 0; $c -lt $cols.Count; $c++) {
      $col = $cols[$c]; $row = $rows[$r]
      $n = if ($col.id -eq 'LX') { @($lin | Where-Object { $_.Machine -eq $row.code }).Count } else { @($kits | Where-Object { $_.Machine -eq $row.code -and $col.os -contains $_.Os }).Count }
      $cells += [pscustomobject]@{ r = $r; c = $c; n = $n; k = $col.k; d = $r + $c }
    }
  }
  foreach ($q in ($cells | Sort-Object d, r)) {
    $x = $q.r * $cell; $y = $q.c * $cell
    $sc.Plane($x + 4, $y + 4, 0, $cell - 8, $cell - 8)
    if ($q.n -gt 0) { $h = [Math]::Min(62, 12 + 5 * $q.n); $sc.Cube($x + 20, $y + 20, 0, $cell - 40, $cell - 40, $h, $q.k) }
  }
  for ($r = 0; $r -lt $rows.Count; $r++) { $sc.Heading(@(($r * $cell + $cell / 2), ($cols.Count * $cell - 4), 0), 'end', $rows[$r].t, $rows[$r].sub) }
  for ($c = 0; $c -lt $cols.Count; $c++) { $sc.Label(@(($rows.Count * $cell - 4), ($c * $cell + $cell / 2), 0), 'start', $cols[$c].t, '') }
  $sc.Svg((T2 $lang 'Matriz de kits: m&aacute;quinas por sistemas' 'Kit matrix: machines by systems'))
}

$script:DiagramNames = @('overview', 'matrix', 'platform')
function Get-Diagram([string]$name, [string]$lang) {
  switch ($name) {
    'overview' { Diagram-Overview $lang }
    'matrix' { Diagram-Matrix $lang }
    'platform' { Diagram-Platform $lang }
    default { throw "unknown diagram $name" }
  }
}
