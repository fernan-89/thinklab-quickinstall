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
