# One "paper" (manual + descriptor) per installation enabled on the stick, plus the general paper of the stick.
# Library for Build-Docs.ps1 (dot-sourced): needs $SITE, $CAT, $SW, Enc/Dec/Table (Build-Docs) and Diagrams.ps1. ASCII only (HTML entities).
#   Get-PaperIndex          -> @{ Id; Group = 'win'|'linux'|'rec'|'general'; Title = @{pt;en}; Kind; Ref }
#   Get-PaperBody $p $lang  -> HTML body (inside <main>)

$script:OsName = @{ W10 = 'WINDOWS 10'; W11 = 'WINDOWS 11'; L21 = 'WINDOWS 10 LTSC'; I10 = 'WINDOWS 10 IOT'; L24 = 'WINDOWS 11 LTSC'; S19 = 'SERVER 2019' }

function Get-PaperIndex {
  $idx = @()
  $idx += @{ Id = 'papel-geral'; Group = 'general'; Kind = 'general'; Ref = $null; Title = @{ pt = 'Paper geral do pen-drive'; en = 'Stick overview paper' } }
  foreach ($w in $CAT.windows) {
    $t = $w.label
    $idx += @{ Id = ('inst-{0}-{1}' -f $w.os.ToLower(), $w.lang.ToLower()); Group = 'win'; Kind = 'windows'; Ref = $w; Title = @{ pt = (Enc $t); en = (Enc $t) } }
  }
  foreach ($l in $CAT.linux) {
    $idx += @{ Id = "inst-$($l.id)"; Group = 'linux'; Kind = 'linux'; Ref = $l; Title = @{ pt = (Enc ($l.label -replace ' - Desktop e Server', '' -replace ' - ENGLISH', '')); en = (Enc ($l.label -replace ' - Desktop e Server', '' -replace ' - ENGLISH', '')) } }
  }
  foreach ($r in $CAT.recovery) {
    $nm = ($r.label -split ' - ')[0]
    $idx += @{ Id = ('rec-' + (($r.iso -split '_')[0] -replace '[^A-Za-z0-9]', '').ToLower()); Group = 'rec'; Kind = 'recovery'; Ref = $r; Title = @{ pt = (Enc $nm); en = (Enc $nm) } }
  }
  $idx
}

function Sw-Name($id) { $i = $SW.items | Where-Object { $_.id -eq $id } | Select-Object -First 1; if ($i) { $i.name } else { $id } }
function LiList($items) { '<ul>' + (($items | ForEach-Object { "<li>$_</li>" }) -join '') + '</ul>' }
function Steps($items) { '<ol class="steps">' + (($items | ForEach-Object { "<li>$_</li>" }) -join '') + '</ol>' }
function Fig($name, $lang) { "<figure class=""fig"">$(Get-Diagram $name $lang)</figure>" }
function CodeBox($file, $lines) {
  $h = ''
  foreach ($ln in $lines) {
    $e = Enc $ln
    $e = [regex]::Replace($e, '(&quot;[^&]*?&quot;)(\s*:)', '<span class="k">$1</span>$2')
    $e = [regex]::Replace($e, ':\s*(&quot;[^&]*?&quot;)', ': <span class="s">$1</span>')
    $e = [regex]::Replace($e, '\b(true|false|null|\d+)\b(?![^<]*>)', '<span class="n">$1</span>')
    $h += "<li>$e</li>"
  }
  "<div class=""code""><div class=""fn"">File: <b>$(Enc $file)</b></div><ol>$h</ol></div>"
}
function H2($t) { "<h2>$t</h2>" }

# ---------------------------------------------------------------- Windows ISO paper
function Paper-Windows($w, $lang) {
  $kits = @(Get-WindowsKits $SITE $CAT | Where-Object { $_.Iso -eq $w.iso })
  $isServer = $w.os -eq 'S19'; $osn = $script:OsName[$w.os]
  $mk = @($kits | Where-Object { -not $_.Base }); $base = @($kits | Where-Object { $_.Base })
  $imgs = (@($kits | ForEach-Object { $_.Image }) | Select-Object -Unique)
  $profiles = (@($mk | ForEach-Object { $_.Profile }) | Select-Object -Unique)
  $office = $w.office; $prods = if ($office) { @($CAT.office.$office) } else { @() }
  $slabs = @(@{ k = 'plain'; t = (T2 $lang 'INVENT&Aacute;RIO' 'INVENTORY'); s = 'inventory.json' }, @{ k = 'teal'; t = 'BRANDING'; s = 'OEM - WALLPAPERS' })
  if ($isServer) { $slabs += @{ k = 'pink'; t = 'NETDATA'; s = (T2 $lang 'MONITORAMENTO' 'MONITORING') } } else { $slabs += @{ k = 'plain'; t = (T2 $lang 'PROGRAMAS' 'SOFTWARE'); s = (T2 $lang 'POR PERFIL' 'PER PROFILE') } }
  $slabs += @{ k = 'yellow'; t = 'DRIVERS'; s = 'PNPUTIL' }
  $slabs += @{ k = 'brand'; t = (T2 $lang 'ARQUIVO DE RESPOSTA' 'ANSWER FILE'); s = 'unattend.xml' }
  $cfg = @{
    left = @{ k = 'blue'; t = (T2 $lang 'IMAGEM DO WINDOWS' 'WINDOWS IMAGE'); s = ($imgs[0] -replace 'Windows ', '').ToUpper() }
    topA = @{ k = 'brand'; t = $osn; s = $w.lang + ' - ' + $w.os }
    plane = @{ t = 'SITE.JSON'; s = (T2 $lang 'UM KIT POR M&Aacute;QUINA' 'ONE KIT PER MACHINE') }
    slabs = $slabs
  }
  if ($office) { $cfg.topB = @{ k = 'pink'; t = "OFFICE $office"; s = 'PROPLUS - VISIO - PROJECT' } }
  $html = '<p class="lead">' + (T2 $lang ("Instala&ccedil;&atilde;o autom&aacute;tica do $(Enc $osn) com idioma e teclado j&aacute; definidos; s&oacute; o disco &eacute; escolhido por voc&ecirc;.") ("Automated install of $(Enc $osn) with language and keyboard already set; only the disk is chosen by you.")) + '</p>'
  $html += Fig 'overview' $lang | Out-Null
  $html = '<p class="lead">' + (T2 $lang ("Instala&ccedil;&atilde;o autom&aacute;tica do $(Enc $osn) com idioma e teclado j&aacute; definidos; s&oacute; o disco &eacute; escolhido por voc&ecirc;.") ("Automated install of $(Enc $osn) with language and keyboard already set; only the disk is chosen by you.")) + '</p>'
  $html += "<figure class=""fig"">$(Diagram-Stack $lang $cfg (T2 $lang 'Vis&atilde;o explodida desta instala&ccedil;&atilde;o' 'Exploded view of this install'))</figure>"
  # 01 summary
  $html += H2 (T2 $lang 'Resumo' 'Summary')
  $rows = @(
    @((T2 $lang 'Arquivo ISO' 'ISO file'), "<code>$(Enc $w.iso)</code>"),
    @((T2 $lang 'Idioma' 'Language'), (Enc $w.lang)),
    @((T2 $lang 'Imagem(ns) instalada(s)' 'Installed image(s)'), (($imgs | ForEach-Object { "<code>$(Enc $_)</code>" }) -join '<br>')),
    @((T2 $lang 'Chave' 'Key'), (T2 $lang 'Chave gen&eacute;rica de instala&ccedil;&atilde;o (n&atilde;o ativa o sistema).' 'Generic install key (does not activate the system).')),
    @((T2 $lang 'Disco' 'Disk'), (T2 $lang 'Escolha manual, sempre; nada &eacute; apagado sem voc&ecirc; pedir.' 'Always manual; nothing is wiped unasked.')),
    @((T2 $lang 'Kits' 'Kits'), "$($kits.Count) ($($base.Count) BASE + $($mk.Count) $(T2 $lang 'por m&aacute;quina' 'per machine'))"))
  $html += Table @((T2 $lang 'Item' 'Item'), (T2 $lang 'Valor' 'Value')) $rows
  # 02 kits
  $html += H2 (T2 $lang 'Kits dispon&iacute;veis' 'Available kits')
  $krows = @()
  foreach ($k in $kits) { $krows += , @("<code>$(Enc $k.File)</code>", (Enc $(if ($k.Base) { 'BASE' } else { $k.MachineLabel })), (Enc $(if ($k.Name -eq '*') { (T2 $lang '(autom&aacute;tico)' '(automatic)') } else { $k.Name })), (Enc ($k.Image -replace 'Windows ', '')), (Enc $k.Profile)) }
  $html += Table @((T2 $lang 'Modelo no menu' 'Menu template'), (T2 $lang 'M&aacute;quina' 'Machine'), (T2 $lang 'Nome do computador' 'Computer name'), (T2 $lang 'Edi&ccedil;&atilde;o' 'Edition'), (T2 $lang 'Perfil' 'Profile')) $krows
  $html += '<p>' + (T2 $lang 'O kit <b>BASE</b> instala s&oacute; o sistema' + $(if ($office) { ' e o Office correspondente' } else { '' }) + ' (e o Netdata no servidor), sem drivers nem nome fixo; os kits por m&aacute;quina acrescentam nome, drivers, programas e identidade ThinkLab.' ('The <b>BASE</b> kit installs only the system' + $(if ($office) { ' and its matching Office' } else { '' }) + ' (and Netdata on the server), with no drivers or fixed name; the per-machine kits add name, drivers, programs and ThinkLab identity.')) + '</p>'
  # 03 what gets installed
  $html += H2 (T2 $lang 'O que &eacute; instalado' 'What gets installed')
  $li = @()
  $drv = (@($mk | ForEach-Object { $_.Drivers } | ForEach-Object { ($_ -replace '^pack:', '') -split '\\' | Select-Object -Last 1 }) | Select-Object -Unique)
  if ($drv) { $li += '<b>Drivers:</b> ' + (($drv | ForEach-Object { "<code>$(Enc $_)</code>" }) -join ', ') }
  if ($office) { $li += "<b>Office $office</b> (" + (T2 $lang 'no idioma do kit, instala&ccedil;&atilde;o offline' 'in the kit language, offline install') + '): ' + (($prods | ForEach-Object { Enc ($_ -replace "Retail|$office", '') }) -join ', ') }
  foreach ($pf in $profiles) {
    $names = @($SW.profiles.$pf.software | ForEach-Object { Sw-Name $_ })
    $ex = @($mk | Where-Object { $_.Profile -eq $pf } | ForEach-Object { $_.ExtraSoftware } | Where-Object { $_ } | Select-Object -Unique | ForEach-Object { Sw-Name $_ })
    $who = (@($mk | Where-Object { $_.Profile -eq $pf } | ForEach-Object { $_.MachineLabel }) | Select-Object -Unique) -join ', '
    $all = @($names + $ex | Select-Object -Unique)
    if ($all.Count) { $li += "<b>$(T2 $lang 'Perfil' 'Profile') $(Enc $pf)</b> ($(Enc $who)): " + (($all | ForEach-Object { Enc $_ }) -join ', ') }
  }
  $li += '<b>Branding:</b> ' + (T2 $lang 'fabricante &quot;ThinkLab&quot; e modelo + nome do computador nas Propriedades do Sistema, logo e pap&eacute;is de parede.' 'manufacturer &quot;ThinkLab&quot; and model + computer name in System Properties, logo and wallpapers.')
  $li += '<b>' + (T2 $lang 'Invent&aacute;rio' 'Inventory') + ':</b> <code>C:\QuickInstall\inventory.json</code> + ' + (T2 $lang 'log do primeiro logon.' 'first-logon log.')
  $html += LiList $li
  # 04 steps
  $html += H2 (T2 $lang 'Passo a passo' 'Step by step')
  $html += Steps @(
    (T2 $lang 'D&ecirc; boot pelo pen-drive e abra <b>Windows</b> no menu.' 'Boot from the stick and open <b>Windows</b> in the menu.'),
    (T2 $lang "Escolha esta ISO e, no modelo, o kit da m&aacute;quina (ou <code>BASE_...</code>)." "Choose this ISO and, in the template list, the machine kit (or <code>BASE_...</code>)."),
    (T2 $lang 'Na tela de disco, selecione o <b>disco de destino</b> (nunca as parti&ccedil;&otilde;es Ventoy/VTOYEFI) e avance.' 'On the disk screen select the <b>target disk</b> (never the Ventoy/VTOYEFI partitions) and continue.'),
    (T2 $lang 'Aguarde: o Windows reinicia sozinho, entra com o usu&aacute;rio inicial e roda o primeiro logon (drivers, Office, programas).' 'Wait: Windows restarts by itself, signs in with the initial user and runs first logon (drivers, Office, programs).'),
    (T2 $lang 'Ao terminar, reinicie. A senha inicial deve ser trocada no pr&oacute;ximo logon.' 'When it finishes, restart. The initial password must be changed at the next sign-in.'))
  # 05 after
  $html += H2 (T2 $lang 'Depois da instala&ccedil;&atilde;o' 'After the install')
  $html += LiList @(
    (T2 $lang 'Ative o Windows e o Office com as suas chaves ou conta; o kit n&atilde;o ativa nada.' 'Activate Windows and Office with your keys or account; the kit activates nothing.'),
    (T2 $lang 'Conferir <code>C:\QuickInstall\FirstLogon-*.log</code> (deve terminar em <code>Done</code>).' 'Check <code>C:\QuickInstall\FirstLogon-*.log</code> (it should end with <code>Done</code>).'),
    $(if ($isServer) { T2 $lang 'O Netdata responde em <code>http://localhost:19999</code>.' 'Netdata answers at <code>http://localhost:19999</code>.' } else { T2 $lang 'Programas que dependem de conta (Kaspersky, Office) pedem o seu login uma vez.' 'Account-based programs (Kaspersky, Office) ask for your sign-in once.' }))
  $html
}

# ---------------------------------------------------------------- Linux distro paper
function Paper-Linux($l, $lang) {
  $lk = @(Get-LinuxKits $SITE $CAT | Where-Object { $_.Distro -eq $l.id })
  $srv = @($lk | Where-Object { $_.Kind -eq 'server' }).Count -gt 0
  $name = Enc (($l.label -split ' - ')[0])
  $slabs = @()
  if ($srv) { $slabs += @{ k = 'pink'; t = 'NETDATA'; s = (T2 $lang 'SERVIDOR - PRIMEIRO BOOT' 'SERVER - FIRST BOOT') } }
  $slabs += @{ k = 'plain'; t = (T2 $lang 'PACOTES' 'PACKAGES'); s = 'git - curl - vim - htop' }
  if ($l.templates -ne 'none') { $slabs += @{ k = 'brand'; t = (T2 $lang 'ARQUIVO DE RESPOSTA' 'ANSWER FILE'); s = $(if ($l.templates -eq 'kickstart') { 'kickstart' } else { 'autoinstall' }) } } else { $slabs += @{ k = 'brand'; t = (T2 $lang 'INSTALADOR' 'INSTALLER'); s = 'AGAMA' } }
  $cfg = @{ left = @{ k = 'blue'; t = 'ISO'; s = ($l.iso -replace '_Multi\.iso$', '').ToUpper() }; topA = @{ k = 'brand'; t = $name.ToUpper(); s = (T2 $lang 'LINUX LIVRE' 'FREE LINUX') }; slabs = $slabs }
  if ($srv) { $cfg.plane = @{ t = 'SITE.JSON'; s = (T2 $lang 'UM KIT POR M&Aacute;QUINA' 'ONE KIT PER MACHINE') } }
  $html = '<p class="lead">' + (T2 $lang ("${name}: " + $(if ($l.templates -eq 'none') { 'instalador interativo (Agama); n&atilde;o h&aacute; arquivo de resposta.' } else { 'instala&ccedil;&atilde;o guiada por arquivo de resposta; disco, usu&aacute;rio e senha ficam interativos.' })) ("${name}: " + $(if ($l.templates -eq 'none') { 'interactive installer (Agama); there is no answer file.' } else { 'answer-file guided install; disk, user and password stay interactive.' }))) + '</p>'
  $html += "<figure class=""fig"">$(Diagram-Stack $lang $cfg (T2 $lang 'Vis&atilde;o explodida desta instala&ccedil;&atilde;o' 'Exploded view of this install'))</figure>"
  $html += H2 (T2 $lang 'Resumo' 'Summary')
  $rows = @(@((T2 $lang 'Arquivo ISO' 'ISO file'), "<code>$(Enc $l.iso)</code>"), @((T2 $lang 'Disco, usu&aacute;rio e senha' 'Disk, user and password'), (T2 $lang 'Interativos (nada &eacute; apagado sem voc&ecirc; pedir).' 'Interactive (nothing is wiped unasked).')))
  if ($l.id -in 'alma', 'rhel', 'centos') { $rows += , @((T2 $lang 'Idiomas' 'Languages'), (T2 $lang 'Workstation em ingl&ecirc;s ou portugu&ecirc;s; servidor somente em ingl&ecirc;s.' 'Workstation in English or Portuguese; server English only.')) }
  if ($l.id -eq 'ubuntu') { $rows += , @((T2 $lang 'Idiomas' 'Languages'), (T2 $lang 'Somente ingl&ecirc;s (servidor).' 'English only (server).')) }
  if ($l.id -eq 'alma') { $rows += , @((T2 $lang 'Requisito' 'Requirement') , (T2 $lang 'CPU com AVX2 (x86-64-v3).' 'CPU with AVX2 (x86-64-v3).')) }
  if ($l.id -eq 'rhel') { $rows += , @((T2 $lang 'Download' 'Download'), (T2 $lang 'O Red Hat exige login: baixe o DVD (assinatura Developer gratuita) e renomeie para o nome do cat&aacute;logo.' 'Red Hat requires a login: download the DVD (free Developer subscription) and rename it to the catalog name.')) }
  if ($l.id -eq 'centos') { $rows += , @((T2 $lang 'Instala&ccedil;&atilde;o' 'Install'), (T2 $lang 'ISO de boot; os pacotes v&ecirc;m pela internet do espelho oficial.' 'Boot ISO; packages come over the internet from the official mirror.')) }
  if ($srv) { $rows += , @('Netdata', (T2 $lang 'Servidores instalam o Netdata no primeiro boot (precisa de internet).' 'Servers install Netdata at first boot (needs internet).')) }
  $html += Table @((T2 $lang 'Item' 'Item'), (T2 $lang 'Valor' 'Value')) $rows
  if ($lk.Count) {
    $html += H2 (T2 $lang 'Kits dispon&iacute;veis' 'Available kits')
    $krows = @($lk | Sort-Object File | ForEach-Object { , @("<code>$(Enc $_.File)</code>", (Enc $_.Machine), (Enc $(if ($_.Kind -eq 'server') { 'Server' } else { 'Workstation' })), (Enc $_.Lang), (Enc $(if ($_.Host) { $_.Host } else { (T2 $lang '(autom&aacute;tico)' '(automatic)') }))) })
    $html += Table @((T2 $lang 'Modelo no menu' 'Menu template'), (T2 $lang 'M&aacute;quina' 'Machine'), (T2 $lang 'Tipo' 'Type'), (T2 $lang 'Idioma' 'Language'), 'Hostname') $krows
  }
  $html += H2 (T2 $lang 'Passo a passo' 'Step by step')
  $html += Steps @(
    (T2 $lang 'D&ecirc; boot pelo pen-drive e abra <b>Linux</b> no menu.' 'Boot from the stick and open <b>Linux</b> in the menu.'),
    (T2 $lang ('Escolha esta ISO' + $(if ($l.templates -ne 'none') { ' e o modelo da m&aacute;quina (ou <code>BASE_...</code>)' } else { '' }) + '.') ('Choose this ISO' + $(if ($l.templates -ne 'none') { ' and the machine template (or <code>BASE_...</code>)' } else { '' }) + '.')),
    (T2 $lang 'Complete o que o instalador perguntar: disco, usu&aacute;rio, senha e rede.' 'Complete what the installer asks: disk, user, password and network.'),
    $(if ($srv) { T2 $lang 'No primeiro boot o Netdata &eacute; instalado sozinho; acompanhe com <code>journalctl -u netdata-firstboot</code>.' 'At first boot Netdata installs by itself; follow it with <code>journalctl -u netdata-firstboot</code>.' } else { T2 $lang 'Reinicie e remova o pen-drive.' 'Restart and remove the stick.' }))
  $html
}

# ---------------------------------------------------------------- Recovery tool paper
$script:RecInfo = @{
  pe      = @{ pt = 'Ambiente Windows Live (WinPE) com ferramentas de recupera&ccedil;&atilde;o, estilo Hiren''s BootCD; recebe as ferramentas ThinkLab injetadas (PE Extras).'; en = 'Windows Live (WinPE) with recovery tools, Hiren''s BootCD style; the ThinkLab PE Extras are injected.'; use = @('pt|Corrigir boot, redefinir senhas locais, copiar dados e clonar discos no Windows.', 'en|Fix boot, reset local passwords, copy data and clone disks from Windows.') }
  rescue  = @{ pt = 'Linux de resgate (SystemRescue) para discos, dados e rede.'; en = 'Rescue Linux (SystemRescue) for disks, data and network.'; use = @('pt|Particionar, reparar sistemas de arquivos, montar volumes e copiar dados.', 'en|Partition, repair file systems, mount volumes and copy data.') }
  tools   = @{ pt = 'Ferramenta de disco ou de c&oacute;pia (GParted, Clonezilla, MemTest86+).'; en = 'Disk or imaging tool (GParted, Clonezilla, MemTest86+).'; use = @('pt|Siga a tela do pr&oacute;prio programa.', 'en|Follow the tool''s own screens.') }
  memtest = @{ pt = 'Teste de mem&oacute;ria RAM.'; en = 'RAM test.'; use = @('pt|Deixe rodar v&aacute;rias passagens; qualquer erro indica m&oacute;dulo com defeito.', 'en|Let it run several passes; any error means a faulty module.') }
}
function Paper-Recovery($r, $lang) {
  $info = $script:RecInfo[$r.class]; if (-not $info) { $info = $script:RecInfo['tools'] }
  $nm = ($r.label -split ' - ')[0]
  $cfg = @{ left = @{ k = 'blue'; t = 'ISO'; s = ($r.iso -replace '_Multi\.iso$', '').ToUpper() }; topA = @{ k = 'teal'; t = $nm.ToUpper(); s = (T2 $lang 'RECUPERA&Ccedil;&Atilde;O' 'RECOVERY') }
    slabs = @(@{ k = 'plain'; t = (T2 $lang 'FERRAMENTAS' 'TOOLS'); s = (T2 $lang 'DISCO - DADOS - REDE' 'DISK - DATA - NETWORK') }, @{ k = 'teal'; t = (T2 $lang 'BOOT' 'BOOT'); s = 'VENTOY' }) }
  if ($r.inject) { $cfg.slabs = @(@{ k = 'pink'; t = 'PE EXTRAS'; s = 'THINKLAB TOOLS' }) + $cfg.slabs }
  $html = '<p class="lead">' + (T2 $lang $info.pt $info.en) + '</p>'
  $html += "<figure class=""fig"">$(Diagram-Stack $lang $cfg (T2 $lang 'Vis&atilde;o explodida desta ferramenta' 'Exploded view of this tool'))</figure>"
  $html += H2 (T2 $lang 'Resumo' 'Summary')
  $html += Table @((T2 $lang 'Item' 'Item'), (T2 $lang 'Valor' 'Value')) @(@((T2 $lang 'Arquivo ISO' 'ISO file'), "<code>$(Enc $r.iso)</code>"), @((T2 $lang 'Instala&ccedil;&atilde;o' 'Install'), (T2 $lang 'N&atilde;o instala nada: roda direto do pen-drive.' 'Installs nothing: runs straight from the stick.')))
  $html += H2 (T2 $lang 'Quando usar' 'When to use it')
  $u = @($info.use | Where-Object { $_ -like "$lang|*" } | ForEach-Object { $_.Substring(3) })
  $html += LiList $u
  $html += H2 (T2 $lang 'Passo a passo' 'Step by step')
  $html += Steps @((T2 $lang 'D&ecirc; boot pelo pen-drive e abra <b>Recovery</b> no menu.' 'Boot from the stick and open <b>Recovery</b> in the menu.'), (T2 $lang 'Escolha esta ferramenta e siga a tela.' 'Choose this tool and follow the screen.'), (T2 $lang 'Ao terminar, remova o pen-drive e reinicie.' 'When done, remove the stick and restart.'))
  $html
}

# ---------------------------------------------------------------- general paper
function Paper-General($lang) {
  $wk = @(Get-WindowsKits $SITE $CAT); $lk = @(Get-LinuxKits $SITE $CAT)
  $html = '<p class="lead">' + (T2 $lang 'Uma p&aacute;gina com o pen-drive inteiro: o que ele instala, para quem, e como as pe&ccedil;as se conectam &agrave; plataforma ThinkLab.' 'One page for the whole stick: what it installs, for whom, and how the pieces connect to the ThinkLab platform.') + '</p>'
  $html += Fig 'overview' $lang
  $html += H2 (T2 $lang 'Em n&uacute;meros' 'In numbers')
  $html += Table @((T2 $lang 'Item' 'Item'), (T2 $lang 'Quantidade' 'Count')) @(
    @((T2 $lang 'M&aacute;quinas atendidas' 'Machines served'), "$(@($SITE.machines).Count)"),
    @((T2 $lang 'Sistemas Windows (ISOs)' 'Windows systems (ISOs)'), "$(@($CAT.windows).Count)"),
    @((T2 $lang 'Distribui&ccedil;&otilde;es Linux' 'Linux distributions'), "$(@($CAT.linux).Count)"),
    @((T2 $lang 'Ferramentas de recupera&ccedil;&atilde;o' 'Recovery tools'), "$(@($CAT.recovery).Count)"),
    @((T2 $lang 'Kits Windows (arquivos de resposta)' 'Windows kits (answer files)'), "$($wk.Count)"),
    @((T2 $lang 'Kits Linux (kickstart / autoinstall)' 'Linux kits (kickstart / autoinstall)'), "$($lk.Count)"),
    @((T2 $lang 'Programas no cat&aacute;logo' 'Programs in the catalog'), "$(@($SW.items).Count)"))
  $html += H2 (T2 $lang 'M&aacute;quinas por sistemas' 'Machines by systems')
  $html += Fig 'matrix' $lang
  $html += H2 (T2 $lang 'Integra&ccedil;&atilde;o com o ThinkLab' 'ThinkLab integration')
  $html += Fig 'platform' $lang
  $html += H2 (T2 $lang 'Regras do kit' 'Kit rules')
  $html += LiList @(
    (T2 $lang '<b>Disco sempre manual:</b> nada &eacute; apagado sem voc&ecirc; pedir.' '<b>Disk always manual:</b> nothing is wiped unasked.'),
    (T2 $lang '<b>Servidores somente em ingl&ecirc;s;</b> workstations em ingl&ecirc;s ou portugu&ecirc;s.' '<b>Servers English only;</b> workstations in English or Portuguese.'),
    (T2 $lang '<b>Windows Server:</b> sempre Standard ou Datacenter (Desktop Experience), com Netdata.' '<b>Windows Server:</b> always Standard or Datacenter (Desktop Experience), with Netdata.'),
    (T2 $lang '<b>Senha inicial</b> trocada no primeiro acesso; chaves de instala&ccedil;&atilde;o s&atilde;o gen&eacute;ricas.' '<b>Initial password</b> changed at first sign-in; install keys are generic.'),
    (T2 $lang '<b>Integridade:</b> <code>SHA256SUMS.txt</code> na raiz e <code>Verify-Stick.ps1</code> para conferir.' '<b>Integrity:</b> <code>SHA256SUMS.txt</code> at the root and <code>Verify-Stick.ps1</code> to check it.'))
  $html += '<p class="printnote">' + (T2 $lang 'Dica: imprima ou salve em PDF; o layout &eacute; otimizado para papel (tema claro).' 'Tip: print or save as PDF; the layout is optimised for paper (light theme).') + '</p>'
  $html
}

function Get-PaperBody($p, [string]$lang) {
  switch ($p.Kind) {
    'general' { "<h1>$(T2 $lang 'Paper geral do pen-drive' 'Stick overview paper')</h1>" + (Paper-General $lang) }
    'windows' { "<h1>$($p.Title[$lang])</h1>" + (Paper-Windows $p.Ref $lang) }
    'linux' { "<h1>$($p.Title[$lang])</h1>" + (Paper-Linux $p.Ref $lang) }
    'recovery' { "<h1>$($p.Title[$lang])</h1>" + (Paper-Recovery $p.Ref $lang) }
  }
}
