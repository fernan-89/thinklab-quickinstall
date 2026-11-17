# Testing

Everything is tested in Hyper-V virtual machines; the real stick is never booted for tests.

## Automated (no VM)

```powershell
powershell -ExecutionPolicy Bypass -File tests\Test-Repo.ps1
```

Checks that every script parses, builds the kit from `config\site.example.json`, validates the Ventoy config (all templates exist), the answer files (computer names <= 15 characters), the generated docs and scans tracked files for private identifiers (`config\privacy-terms.local.txt`). A pre-commit hook (`.githooks\pre-commit`) runs it.

## VM tests

1. `src\tools\New-TestStick.ps1` builds a small virtual Ventoy stick (VHDX) from a published stick, copying only the ISOs, drivers, software and Office payload you list.
2. `src\tools\vmtools.ps1` (`New-TlVm`) creates a Generation 2 VM (TPM on, Secure Boot off) with a differencing disk over that stick, so the base stays pristine, plus an empty target disk.
3. Drive the Ventoy menu and Windows Setup with `Key` (virtual-key presses) and watch with `Snap` (WMI screenshots). The disk step is manual by design: pick the empty disk.
4. After the VM is turned off, `Get-TlGuestFile` mounts the target disk read-only and returns `C:\QuickInstall\*` (log, `inventory.json`) so results can be checked without logging in.

## Checklist per kit

- Menu shows the kit; Setup selects the right edition and language; only the disk step asks for input.
- First logon starts by itself: `C:\QuickInstall\FirstLogon-<profile>-<os>-<lang>.log` exists and ends with `Done`.
- Drivers added, Office installed in the kit language only, profile software present, no leftover installer windows.
- Branding: System Properties shows manufacturer/model/logo, default wallpaper is set, wallpapers copied.
- `inventory.json` written and the first-logon password change is forced.
- Linux templates: boot to the installer prompts and confirm the template is applied.

## Known limits

- Retail Office and the Kaspersky products need your own licences/sign-in after install.
- Vendor installers (Kaspersky, Adobe) are not redistributed; put them in `Software\` (see `docs-src\software.html`).
- Windows Terminal comes from the local `.msixbundle` (falls back to winget); on a fresh Windows 10 without dependencies it can still fail and only warns.

## Test plan (matrix)

Run every row after a change that touches it; record the result (date, pass/fail, note) in your private notes, not here.

| ID | Area | What is installed / booted | Pass when |
|---|---|---|---|
| M1 | Boot menu | dark theme, light theme (F5 > Theme Select), tips | fonts load, rows and tip readable, both themes switch |
| W1 | Windows 10, machine kit, PT-BR | office-type profile + extra software | log ends with `Done`; drivers, Office in PT only, profile software, extra software, OEM info, tape wallpaper |
| W2 | Windows 11, BASE kit, EN-US | system + Office only | log ends with `Done`; no drivers/software; BASE wallpapers; automatic computer name |
| W3 | Windows 11, machine kit, EN-US | developer profile, driver pack | log ends with `Done`; pack extracted, dev tools present |
| W4 | Lite editions (LTSC / IoT), both languages | machine kit | Setup picks the image; log ends with `Done` |
| S1 | Windows Server, Standard | server profile | stick mounted by the first command; Netdata installed |
| S2 | Windows Server, Datacenter | server profile | same as S1, Datacenter edition |
| L1 | Ubuntu Server autoinstall | server | interactive sections asked; Netdata unit enabled and service up after first boot |
| L2 | AlmaLinux kickstart, server, EN | server | kickstart applied; Netdata up after first boot |
| L3 | AlmaLinux kickstart, workstation, PT-BR | desktop | language, keyboard and hostname applied |
| L4 | CentOS Stream (network install) | workstation | installer reaches the summary with the kickstart values |
| L5 | RHEL (ISO supplied by you) | workstation / server | same as L2 / L3 |
| L6 | openSUSE Leap | interactive | installer starts |
| R1-R5 | Recovery ISOs | WinPE, SystemRescue, GParted, Clonezilla, MemTest86+ | each boots to its desktop / menu; PE extras present in WinPE |
| P1 | Phone wallpapers | `Build-PhoneWallpapers.ps1` | 16 PNGs (8 looks x 2 sizes), labels readable |
| K1 | Linux templates (static) | `ksvalidator -v RHEL10` (pykickstart) on every `.ks`, `bash -n` on its `%pre`, YAML parse of every autoinstall file | no errors, LF line endings |
| I1 | Integrity | `New-Manifest.ps1` then `Verify-Stick.ps1` | no mismatch |
| D1 | Repository | `tests\Test-Repo.ps1` | all checks pass |
