# Builds the bilingual (pt/en) offline documentation site for the ThinkLab Quick Install stick.
# Content lives in src\docs-src\<page>.html (one file per page, two <section lang="pt|en"> blocks); this script wraps it with the
# ThinkLab / Canonical-Vanilla dark layout, builds navigation + a client-side search index and tables generated from the site config.
# ASCII only (entities for accents). Output: <Out>\index.html, <Out>\pt\*.html, <Out>\en\*.html, <Out>\assets\*
param(
  [string]$SitePath,
  [string]$Src = (Join-Path (Resolve-Path "$PSScriptRoot\..").Path 'docs-src'),
  [string]$Out = (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path 'build\USB\Docs'),
  [string]$Stage = (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path 'build\USB'),
  [string]$StickRoot = ''
)
. "$PSScriptRoot\QI.Common.ps1"$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web
$SITE = Get-Site $SitePath; $CAT = Get-Catalog; $SW = Get-Software
function Dec($s) { [System.Net.WebUtility]::HtmlDecode($s) }
function Enc($s) { [System.Net.WebUtility]::HtmlEncode([string]$s) }

# ------------------------------------------------------------------ navigation model
$Nav = @(
  @{ Group = @{ pt = 'In&iacute;cio'; en = 'Start' }; Items = @(
      @{ Id = 'index';      T = @{ pt = 'Vis&atilde;o geral'; en = 'Overview' } },
      @{ Id = 'instalar';   T = @{ pt = 'Passo a passo'; en = 'Step by step' } } ) },
  @{ Group = @{ pt = 'Instala&ccedil;&atilde;o'; en = 'Installation' }; Items = @(
      @{ Id = 'menu';       T = @{ pt = 'Menu de boot'; en = 'Boot menu' } },
      @{ Id = 'maquinas';   T = @{ pt = 'M&aacute;quinas e kits'; en = 'Machines and kits' } },
      @{ Id = 'software';   T = @{ pt = 'Software e Office'; en = 'Software and Office' } },
      @{ Id = 'drivers';    T = @{ pt = 'Drivers'; en = 'Drivers' } },
      @{ Id = 'linux';      T = @{ pt = 'Linux'; en = 'Linux' } } ) },
  @{ Group = @{ pt = 'Recupera&ccedil;&atilde;o'; en = 'Recovery' }; Items = @(
      @{ Id = 'recuperacao'; T = @{ pt = 'Windows Live e resgate'; en = 'Windows Live and rescue' } } ) },
  @{ Group = @{ pt = 'Refer&ecirc;ncia'; en = 'Reference' }; Items = @(
      @{ Id = 'licencas';   T = @{ pt = 'Licen&ccedil;as e ativa&ccedil;&atilde;o'; en = 'Licensing and activation' } },
      @{ Id = 'solucao';    T = @{ pt = 'Solu&ccedil;&atilde;o de problemas'; en = 'Troubleshooting' } },
      @{ Id = 'arquivos';   T = @{ pt = 'Arquivos do pen-drive'; en = 'Files on the stick' } },
      @{ Id = 'manutencao'; T = @{ pt = 'Manuten&ccedil;&atilde;o'; en = 'Maintenance' } } ) }
)
$Flat = @(); foreach ($g in $Nav) { foreach ($i in $g.Items) { $Flat += $i } }
$UI = @{
  pt = @{ lang = 'pt-BR'; search = 'Pesquisar na documenta&ccedil;&atilde;o'; prev = 'Anterior'; next = 'Pr&oacute;ximo'; other = 'English'; otherLang = 'en'; updated = 'Esta p&aacute;gina foi gerada em'; sub = 'Kit de instala&ccedil;&atilde;o e recupera&ccedil;&atilde;o'; top = @('Instalar', 'Recuperar', 'Refer&ecirc;ncia'); noresult = 'Nenhum resultado' }
  en = @{ lang = 'en'; search = 'Search the documentation'; prev = 'Previous'; next = 'Next'; other = 'Portugu&ecirc;s'; otherLang = 'pt'; updated = 'This page was generated on'; sub = 'Install and recovery kit'; top = @('Install', 'Recover', 'Reference'); noresult = 'No results' }
}

# ------------------------------------------------------------------ generated tables
function Table($head, $rows) {
  $h = ($head | ForEach-Object { "<th>$_</th>" }) -join ''
  $b = ($rows | ForEach-Object { '<tr>' + (($_ | ForEach-Object { "<td>$_</td>" }) -join '') + '</tr>' }) -join "`n"
  "<div class=""tablewrap""><table><thead><tr>$h</tr></thead><tbody>`n$b`n</tbody></table></div>"
}
$cfg = Get-Content "$Stage\ventoy\ventoy.json" -Raw | ConvertFrom-Json
$aliasByImg = @{}; foreach ($a in $cfg.menu_alias) { if ($a.image) { $aliasByImg[$a.image] = $a.alias } }
$tplByImg = @{}; foreach ($a in $cfg.auto_install) { $tplByImg[$a.image] = @($a.template) }

function Cards($lang) {
  $h = ''
  foreach ($m in $SITE.machines) {
    $p = $SITE.site.prefix
    $h += "<div class=""card""><h3>$(Enc $m.fullName)</h3><p>$(Enc $m.specs). $(if ($lang -eq 'pt') { 'Perfil' } else { 'Profile' }) <b>$(Enc $m.role)</b> ($(Enc $m.profile)).</p></div>"
  }
  $h += "<div class=""card""><h3>BASE ($(if ($lang -eq 'pt') { 'qualquer m&aacute;quina' } else { 'any machine' }))</h3><p>$(if ($lang -eq 'pt') { 'S&oacute; o sistema e o Office correspondente, sem drivers nem programas e com nome de computador autom&aacute;tico.' } else { 'Only the system and its matching Office, no drivers or programs, with an automatic computer name.' })</p></div>"
  "<div class=""cards"">$h</div>"
}
function DriversTable($lang) {
  $rows = @()
  foreach ($m in $SITE.machines) {
    if (-not $m.drivers) { continue }
    foreach ($os in $m.drivers.PSObject.Properties.Name) {
      $list = @($m.drivers.$os | ForEach-Object { '<code>' + (Enc ($_ -replace '^pack:', '')) + '</code>' + $(if ($_ -like 'pack:*') { ' <span class="badge">pack</span>' } else { '' }) })
      $rows += , @((Enc $m.label), (Enc $os), ($list -join '<br>'))
    }
  }
  $head = if ($lang -eq 'pt') { @('M&aacute;quina', 'Sistema', 'Pastas no pen-drive') } else { @('Machine', 'System', 'Folders on the stick') }
  Table $head $rows
}
function SoftwareTable($lang) {
  $rows = @(); $mach = @($SITE.machines)
  foreach ($it in $SW.items) {
    $cells = @(); foreach ($m in $mach) { $pf = $SW.profiles.($m.profile); $cells += $(if ($pf -and ($pf.software -contains $it.id)) { $(if ($lang -eq 'pt') { 'sim' } else { 'yes' }) } else { '&ndash;' }) }
    if ($it.id -eq 'toolbox') { continue }
    $rows += , @((Enc $it.name)) + $cells
  }
  $head = @($(if ($lang -eq 'pt') { 'Programa' } else { 'Program' })) + @($mach | ForEach-Object { Enc $_.label })
  Table $head $rows
}
function LinuxTable($lang) {
  $rows = @()
  foreach ($l in $CAT.linux) {
    $who = @($SITE.machines | Where-Object { $_.linux -and ($_.linux.PSObject.Properties.Name -contains $l.id) } | ForEach-Object { $_.label })
    $m = if ($l.PSObject.Properties.Name -contains 'allMachines') { $(if ($lang -eq 'pt') { 'todas' } else { 'all' }) } else { (($who + 'BASE') -join ', ') }
    $how = switch ($l.templates) { 'kickstart' { 'Kickstart' } 'autoinstall' { 'Autoinstall' } default { $(if ($lang -eq 'pt') { 'Instalador Agama (interativo)' } else { 'Agama installer (interactive)' }) } }
    $rows += , @((Enc ($l.label -replace ' \(.*', '')), "<code>$(Enc $l.iso)</code>", (Enc $m), (Enc $how))
  }
  $head = if ($lang -eq 'pt') { @('Distribui&ccedil;&atilde;o', 'Imagem', 'M&aacute;quinas', 'Como instala') } else { @('Distribution', 'Image', 'Machines', 'How it installs') }
  Table $head $rows
}
function MachineList { (($SITE.machines | ForEach-Object { Enc $_.fullName }) -join ', ') }
function NamePattern { $p = $SITE.site.prefix; "$p-&lt;model&gt;-&lt;system&gt;&lt;language&gt;-&lt;role&gt;" }
function ExampleName { $k = (Get-WindowsKits $SITE $CAT | Where-Object { $_.Name -ne '*' } | Select-Object -First 1); if ($k) { $k.Name } else { 'LAB-XXX-W10E-F' } }
function MenuTable($lang) {
  $rows = @()
  foreach ($img in ($aliasByImg.Keys | Sort-Object { ($_ -split '/')[-3 .. -1] -join '/' })) {
    $leaf = $img.Split('/')[-1]
    $folder = ($img -split '/')[2]
    $n = @($tplByImg[$img]).Count
    $tx = if ($n) { "$n" } else { '&ndash;' }
    $rows += , @((Enc $folder), (Enc $aliasByImg[$img]), "<code>$(Enc $leaf)</code>", $tx)
  }
  $head = if ($lang -eq 'pt') { @('Pasta', 'Entrada do menu', 'Arquivo', 'Modelos autom&aacute;ticos') } else { @('Folder', 'Menu entry', 'File', 'Auto-install templates') }
  Table $head $rows
}
function KitsTable($lang) {
  $rows = @()
  foreach ($f in Get-ChildItem "$Stage\Unattend" -Filter *.xml | Sort-Object Name) {
    $x = [xml](Get-Content $f.FullName -Raw)
    $ns = New-Object Xml.XmlNamespaceManager $x.NameTable; $ns.AddNamespace('u', 'urn:schemas-microsoft-com:unattend'); $ns.AddNamespace('wcm', 'http://schemas.microsoft.com/WMIConfig/2002/State')
    $name = $x.SelectSingleNode('//u:ComputerName', $ns).InnerText; if ($name -eq '*') { $name = if ($lang -eq 'pt') { '(autom&aacute;tico)' } else { '(automatic)' } }
    $img = $x.SelectSingleNode('//u:MetaData/u:Value', $ns).InnerText
    $loc = $x.SelectSingleNode('//u:SetupUILanguage/u:UILanguage', $ns).InnerText
    $parts = $f.BaseName -split '_'
    $rows += , @("<b>$name</b>", (Enc $parts[0]), (Enc $img), (Enc $loc), (Enc ($parts[3 .. ($parts.Count - 1)] -join ' ')))
  }
  foreach ($f in Get-ChildItem "$Stage\Unattend" -Filter *.ks | Sort-Object Name) {
    $t = Get-Content $f.FullName -Raw
    $hn = [regex]::Match($t, '--hostname=(\S+)').Groups[1].Value; if (-not $hn) { $hn = if ($lang -eq 'pt') { '(autom&aacute;tico)' } else { '(automatic)' } }; $lg = [regex]::Match($t, '(?m)^lang\s+(\S+)').Groups[1].Value
    $parts = $f.BaseName -split '_'
    $rows += , @("<b>$hn</b>", (Enc $parts[0]), (Enc ('AlmaLinux 10.2 ' + $parts[2].Split('-')[-1])), (Enc $lg), 'kickstart')
  }
  foreach ($f in Get-ChildItem "$Stage\Unattend" -Filter *.yaml | Sort-Object Name) {
    $t = Get-Content $f.FullName -Raw; $hn = [regex]::Match($t, "echo '([^']+)'").Groups[1].Value; if (-not $hn) { $hn = if ($lang -eq 'pt') { '(autom&aacute;tico)' } else { '(automatic)' } }
    $rows += , @("<b>$hn</b>", (Enc ($f.BaseName -split '_')[0]), 'Ubuntu Server 26.04.1 LTS', 'en_US.UTF-8', 'autoinstall')
  }
  $head = if ($lang -eq 'pt') { @('Nome do computador', 'M&aacute;quina', 'Sistema / edi&ccedil;&atilde;o', 'Idioma', 'Perfil') } else { @('Computer name', 'Machine', 'System / edition', 'Language', 'Profile') }
  Table $head $rows
}
function FilesTable($lang) {
  $rows = @(); $roots = @('ISO', 'Office', 'Software', 'Drivers')
  if ($StickRoot -and (Test-Path $StickRoot)) {
    foreach ($r in $roots) {
      $dir = Join-Path $StickRoot $r
      if (-not (Test-Path $dir)) { continue }
      if ($r -eq 'Drivers') {
        foreach ($d in Get-ChildItem $dir -Directory -Recurse -Depth 1 | Where-Object { $_.FullName.Substring($dir.Length + 1).Split('\').Count -eq 2 }) {
          $m = Get-ChildItem $d.FullName -Recurse -File | Measure-Object Length -Sum
          $rows += , @('Drivers', "<code>$(Enc $d.FullName.Substring($StickRoot.Length))</code>", ('{0:N0}' -f $m.Count) + ' files', ('{0:N2}' -f ($m.Sum / 1GB)))
        }
      } else {
        foreach ($f in Get-ChildItem $dir -Recurse -File | Where-Object { $_.Extension -notin '.md', '.xml' -and $_.FullName -notmatch 'TP-Link|Wacom' } | Sort-Object FullName) {
          $rows += , @($r, "<code>$(Enc $f.FullName.Substring($StickRoot.Length))</code>", (Enc $f.Extension.TrimStart('.').ToUpper()), ('{0:N2}' -f ($f.Length / 1GB)))
        }
      }
    }
  }
  if (-not $rows) { foreach ($e in @($CAT.windows) + @($CAT.linux) + @($CAT.recovery)) { $rows += , @('ISO', "<code>$(Enc $e.iso)</code>", 'ISO', '') } }
  $head = if ($lang -eq 'pt') { @('Se&ccedil;&atilde;o', 'Caminho', 'Tipo', 'GiB') } else { @('Section', 'Path', 'Type', 'GiB') }
  Table $head $rows
}

# ------------------------------------------------------------------ assets
New-Item -ItemType Directory -Force "$Out\assets", "$Out\pt", "$Out\en" | Out-Null
@'
:root{--nav:#000;--band:#1e1e1e;--bg:#111;--surface:#1d1d1d;--field:#2b2b2b;--text:#f3f3f3;--muted:#a8a8a8;--border:#3a3a3a;--link:#5aa7ff;--brand:#e95420;--ok:#4fd067;--warn:#f0b24a;--bad:#ffb4b4;--tint:#16202d}
:root[data-theme=light]{--nav:#111;--band:#262626;--bg:#f3f3f3;--surface:#fff;--field:#e9e9e9;--text:#111;--muted:#666;--border:#d0d0d0;--link:#0066cc;--ok:#0e8420;--warn:#8a5300;--bad:#a3121f;--tint:#eaf2fb}
*{box-sizing:border-box}html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--text);font:16px/1.55 'Ubuntu Sans',Ubuntu,system-ui,-apple-system,'Segoe UI',Roboto,sans-serif}
a{color:var(--link);text-decoration:none}a:hover{text-decoration:underline}
code,.mono{font:0.86em ui-monospace,SFMono-Regular,Consolas,Menlo,monospace;background:var(--field);padding:.05em .35em;border-radius:3px}
.global{background:var(--nav);color:#fff;font-size:.8rem}.global .in{max-width:1320px;margin:0 auto;display:flex;gap:1.6rem;align-items:center;min-height:46px;padding:0 24px}
.global .sp{flex:1}.global button{background:none;border:1px solid #555;color:#c7c7c7;padding:2px 10px;cursor:pointer;font:inherit}.global a{color:#c7c7c7}.global a:hover{color:#fff}
.band{background:var(--band);border-bottom:3px solid var(--brand)}.band .in{max-width:1320px;margin:0 auto;display:flex;align-items:center;gap:2rem;padding:12px 24px;flex-wrap:wrap}
.brand{display:flex;align-items:center;gap:.7rem;color:#fff;font-size:1.5rem;font-weight:300}.brand:hover{text-decoration:none}
.mark{width:34px;height:34px;background:var(--brand);border-radius:4px;display:inline-grid;place-items:center}.mark i{display:block;width:16px;height:16px;border:3px solid #fff;border-radius:50%;position:relative}.mark i:after{content:"";position:absolute;inset:3px;background:#fff;border-radius:50%}
.band nav{display:flex;gap:1.4rem;flex-wrap:wrap}.band nav a{color:#fff;padding:.3rem 0;border-bottom:3px solid transparent}.band nav a:hover,.band nav a.on{border-color:#fff;text-decoration:none}
.search{max-width:1320px;margin:20px auto 0;padding:0 24px;position:relative}.search input{width:100%;background:var(--field);color:var(--text);border:0;border-bottom:1px solid var(--muted);padding:12px 44px 12px 14px;font:inherit}
.search input:focus{outline:2px solid var(--link);outline-offset:0}.results{position:absolute;left:24px;right:24px;top:100%;background:var(--surface);border:1px solid var(--border);z-index:5;display:none;max-height:60vh;overflow:auto}
.results a{display:block;padding:10px 14px;border-bottom:1px solid var(--border);color:var(--text)}.results a:hover{background:var(--field);text-decoration:none}.results small{display:block;color:var(--muted)}
.wrap{max-width:1320px;margin:0 auto;padding:24px;display:grid;grid-template-columns:260px minmax(0,1fr);gap:48px}
.side{font-size:.92rem}.side h4{margin:1.4rem 0 .4rem;font-weight:600;font-size:.95rem}.side h4:first-child{margin-top:0}
.side a{display:block;padding:.5rem .6rem;border-top:1px solid var(--border);color:var(--link)}.side a.on{background:var(--field);border-left:3px solid var(--brand);padding-left:.6rem;color:var(--text);font-weight:500}
main{min-width:0;max-width:980px}main h1{font-size:2.6rem;font-weight:300;line-height:1.15;margin:.2rem 0 1rem}main h2{font-size:1.5rem;font-weight:400;margin:2.2rem 0 .6rem}main h3{font-size:1.1rem;font-weight:500;margin:1.6rem 0 .4rem}
main p,main li{max-width:78ch}main .lead{font-size:1.25rem;font-weight:500;margin:0 0 1.4rem}
.tablewrap{overflow-x:auto;margin:1rem 0;border:1px solid var(--border)}table{border-collapse:collapse;width:100%;font-size:.9rem;background:var(--surface)}th,td{padding:8px 12px;text-align:left;border-bottom:1px solid var(--border);vertical-align:top}th{background:var(--field);font-weight:600;white-space:nowrap}
.note{border:1px solid var(--border);border-left:4px solid var(--link);background:var(--tint);padding:12px 16px;margin:1.2rem 0}.note.warn{border-left-color:var(--warn)}.note.bad{border-left-color:var(--bad)}.note.ok{border-left-color:var(--ok)}.note b:first-child{display:block;margin-bottom:.2rem}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:16px;margin:1.2rem 0}.card{background:var(--surface);border:1px solid var(--border);padding:16px;border-top:3px solid var(--brand)}.card h3{margin:.2rem 0 .4rem}.card p{margin:0;color:var(--muted);font-size:.92rem}
.steps{counter-reset:s;list-style:none;padding:0}.steps li{counter-increment:s;position:relative;padding:0 0 1rem 3rem}.steps li:before{content:counter(s);position:absolute;left:0;top:-2px;width:2rem;height:2rem;background:var(--brand);color:#fff;border-radius:50%;display:grid;place-items:center;font-weight:600}
.pager{display:flex;justify-content:space-between;border-top:1px solid var(--border);margin-top:3rem;padding-top:1rem}.pager small{display:block;color:var(--muted)}.pager a{font-size:1.1rem}
.foot{border:1px solid var(--border);border-left:4px solid var(--link);padding:12px 16px;margin:2rem 0;color:var(--muted);font-size:.92rem}
.badge{display:inline-block;padding:.05em .5em;border-radius:3px;font-size:.78rem;background:var(--field);margin-right:.3rem}.badge.ok{color:var(--ok)}.badge.warn{color:var(--warn)}.badge.bad{color:var(--bad)}
@media (max-width:860px){.wrap{grid-template-columns:1fr;gap:16px}.side{display:none}main h1{font-size:2rem}}
'@ | Set-Content "$Out\assets\style.css" -Encoding UTF8
@'
(function(){
  try{var th=localStorage.getItem('tl-theme');if(th)document.documentElement.setAttribute('data-theme',th)}catch(e){}
  var tb=document.getElementById('th');if(tb)tb.addEventListener('click',function(){var d=document.documentElement,n=d.getAttribute('data-theme')==='light'?'dark':'light';d.setAttribute('data-theme',n);try{localStorage.setItem('tl-theme',n)}catch(e){}});
  var lang=document.documentElement.getAttribute('data-l');var box=document.getElementById('q'),res=document.getElementById('res');
  if(!box||!window.SEARCH)return;
  box.addEventListener('input',function(){
    var q=box.value.trim().toLowerCase();if(q.length<2){res.style.display='none';return}
    var out=[];window.SEARCH[lang].forEach(function(p){var i=p.x.indexOf(q);if(i>=0||p.t.toLowerCase().indexOf(q)>=0){var s=p.x.substr(Math.max(0,i-40),120);out.push('<a href="'+p.u+'">'+p.t+'<small>'+(i>=0?'...'+s.replace(/</g,'&lt;')+'...':'')+'</small></a>')}});
    res.innerHTML=out.length?out.join(''):'<a>'+box.getAttribute('data-none')+'</a>';res.style.display='block'});
  document.addEventListener('click',function(e){if(!res.contains(e.target)&&e.target!==box)res.style.display='none'});
})();
'@ | Set-Content "$Out\assets\app.js" -Encoding UTF8

# ------------------------------------------------------------------ pages
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
$search = @{ pt = @(); en = @() }
for ($k = 0; $k -lt $Flat.Count; $k++) {
  $pg = $Flat[$k]; $srcFile = Join-Path $Src "$($pg.Id).html"
  if (-not (Test-Path $srcFile)) { Write-Warning "missing source: $srcFile"; continue }
  $raw = [IO.File]::ReadAllText($srcFile, [Text.Encoding]::UTF8)
  foreach ($lang in 'pt', 'en') {
    $m = [regex]::Match($raw, "(?s)<section lang=""$lang"">(.*?)</section>")
    if (-not $m.Success) { Write-Warning "no $lang section in $($pg.Id)"; continue }
    $body = $m.Groups[1].Value.Replace('{{MENU_TABLE}}', (MenuTable $lang)).Replace('{{KITS_TABLE}}', (KitsTable $lang)).Replace('{{FILES_TABLE}}', (FilesTable $lang)).Replace('{{MACHINE_CARDS}}', (Cards $lang)).Replace('{{DRIVERS_TABLE}}', (DriversTable $lang)).Replace('{{SOFTWARE_TABLE}}', (SoftwareTable $lang)).Replace('{{LINUX_TABLE}}', (LinuxTable $lang)).Replace('{{MACHINE_LIST}}', (MachineList)).Replace('{{NAME_PATTERN}}', (NamePattern)).Replace('{{EXAMPLE_NAME}}', (ExampleName)).Replace('{{ADMIN_USER}}', (Enc $SITE.site.adminUser)).Replace('{{DATE}}', $stamp)
    $u = $UI[$lang]
    $navHtml = ''
    foreach ($g in $Nav) {
      $navHtml += "<h4>$($g.Group[$lang])</h4>"
      foreach ($i in $g.Items) { $on = if ($i.Id -eq $pg.Id) { ' class="on"' } else { '' }; $navHtml += "<a href=""$($i.Id).html""$on>$($i.T[$lang])</a>" }
    }
    $prev = if ($k -gt 0) { "<a href=""$($Flat[$k-1].Id).html""><small>$($u.prev)</small>&lsaquo; $($Flat[$k-1].T[$lang])</a>" } else { '<span></span>' }
    $next = if ($k -lt $Flat.Count - 1) { "<a href=""$($Flat[$k+1].Id).html"" style=""text-align:right""><small>$($u.next)</small>$($Flat[$k+1].T[$lang]) &rsaquo;</a>" } else { '<span></span>' }
    $title = Dec $pg.T[$lang]
    $page = @"
<!doctype html>
<html lang="$($u.lang)" data-l="$lang"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$title - ThinkLab Quick Install</title><link rel="stylesheet" href="../assets/style.css"><script>try{var t=localStorage.getItem('tl-theme');if(t)document.documentElement.setAttribute('data-theme',t)}catch(e){}</script></head><body>
<div class="global"><div class="in"><span>ThinkLab Quick Install</span><span class="sp"></span><a href="menu.html">$($u.top[0])</a><a href="recuperacao.html">$($u.top[1])</a><a href="licencas.html">$($u.top[2])</a><a href="../$($u.otherLang)/$($pg.Id).html">$($u.other)</a><button id="th" type="button" title="Dark / Light">&#9680;</button></div></div>
<div class="band"><div class="in"><a class="brand" href="index.html"><span class="mark"><i></i></span>ThinkLab</a><nav><a href="index.html">$(if($lang -eq 'pt'){'In&iacute;cio'}else{'Start'})</a><a href="instalar.html">$(if($lang -eq 'pt'){'Passo a passo'}else{'Step by step'})</a><a href="maquinas.html">$(if($lang -eq 'pt'){'M&aacute;quinas'}else{'Machines'})</a><a href="recuperacao.html">$(if($lang -eq 'pt'){'Recupera&ccedil;&atilde;o'}else{'Recovery'})</a><a href="arquivos.html">$(if($lang -eq 'pt'){'Arquivos'}else{'Files'})</a></nav></div></div>
<div class="search"><input id="q" type="search" placeholder="$($u.search)" data-none="$($u.noresult)" autocomplete="off"><div id="res" class="results"></div></div>
<div class="wrap"><aside class="side">$navHtml</aside><main>
$body
<div class="pager">$prev$next</div>
<div class="foot">$($u.updated) $stamp.</div>
</main></div>
<script src="../assets/search-index.js"></script><script src="../assets/app.js"></script></body></html>
"@
    [IO.File]::WriteAllText("$Out\$lang\$($pg.Id).html", $page, (New-Object Text.UTF8Encoding($false)))
    $txt = ([regex]::Replace($body, '<[^>]+>', ' ') -replace '\s+', ' ').ToLower()
    $search[$lang] += [pscustomobject]@{ u = "$($pg.Id).html"; t = $title; x = (Dec $txt) }
  }
}
$js = 'window.SEARCH=' + ($search | ConvertTo-Json -Depth 5 -Compress) + ';'
[IO.File]::WriteAllText("$Out\assets\search-index.js", $js, (New-Object Text.UTF8Encoding($false)))

# language chooser
@'
<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>ThinkLab Quick Install</title>
<link rel="stylesheet" href="assets/style.css"></head><body>
<div class="band"><div class="in"><span class="brand"><span class="mark"><i></i></span>ThinkLab</span></div></div>
<div class="wrap" style="grid-template-columns:1fr"><main><h1>ThinkLab Quick Install</h1><p class="lead">Kit de instala&ccedil;&atilde;o e recupera&ccedil;&atilde;o &nbsp;/&nbsp; Install and recovery kit</p>
<div class="cards"><a class="card" href="pt/index.html"><h3>Portugu&ecirc;s (Brasil)</h3><p>Documenta&ccedil;&atilde;o completa do pen-drive.</p></a><a class="card" href="en/index.html"><h3>English</h3><p>Full documentation of the stick.</p></a></div></main></div>
<script>try{var l=(navigator.language||'').toLowerCase().indexOf('pt')===0?'pt':'en';document.querySelector('a[href^="'+l+'/"]').style.borderTopColor='#4fd067'}catch(e){}</script></body></html>
'@ | Set-Content "$Out\index.html" -Encoding UTF8
"built $($Flat.Count * 2) pages -> $Out"
