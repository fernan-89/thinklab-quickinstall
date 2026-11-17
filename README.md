# thinklab-quickinstall

Field kit for the ThinkLab platform: **one Ventoy USB stick that installs, configures and rescues the machines of a lab**. It is an add-on
of the ThinkLab SaaS - it does not need the platform to run, but it produces what the platform's asset registry and recovery plans expect:
machines that are named, installed the same way every time, and described in a small `inventory.json`.

| What | How |
|---|---|
| **Windows 10 / 11 / LTSC / IoT / Server 2019** | One answer file per machine *and language* (EN-US / PT-BR for workstations; servers are English only): edition, generic install key, computer name, time zone and a user are set; **only the disk choice stays manual** (nothing is wiped unasked). |
| **Post-install** (`FirstLogon.ps1`) | Profile driven (`Full`, `DevBasic`, `Office`, `Base`, `Server`): drivers (`pnputil`), Office from an offline Click-to-Run source, software from the stick or `winget`, an `inventory.json`, and a **forced password change** at the next logon. |
| **BASE option** | Every Windows ISO also has a `BASE_*` template: only that Windows + its matching Office (Windows Server: the system + Netdata). Linux has `BASE_*` kickstarts / autoinstall too. |
| **Linux** | AlmaLinux 10 (kickstart: Workstation EN/PT, Server EN only), Ubuntu Server (autoinstall), openSUSE Leap (interactive Agama). |
| **Recovery / Live** | Hiren's BootCD PE (Windows Live) + ThinkLab tools injected into it, SystemRescue, GParted Live, Clonezilla Live, MemTest86+. |
| **Menu + docs** | Ventoy TreeView menu with a ThinkLab theme (Canonical/Vanilla dark, same tokens as `thinklab-web`) and an **offline bilingual documentation site** on the stick. |
| **Integrity** | `SHA256SUMS.txt` manifest + `Verify-Stick.ps1`; repo checks incl. a privacy scan. |

> The repository holds **no site data**. Your machines live in `config/site.json` (git-ignored); the repo ships `config/site.example.json`.
> No ISO, installer, key or password is ever committed.

## How it fits together

```
config/catalog.json      Windows / Linux / recovery images and Office products the kit knows (public data)
config/software.json     software catalog + profiles
config/site.example.json example of a site (machines, languages, drivers)         -> copy to config/site.json (private)
src/tools/New-Kit.ps1    builds build/USB: Unattend/, Scripts/, ventoy/ (menu, theme, PE tools), Docs/
src/tools/Publish-Stick.ps1  copies the build (and a "library" of big files) to the Ventoy stick
src/kit/FirstLogon.ps1   the post-install that runs from the stick
```

## Quick start

```powershell
# 1. describe your machines
Copy-Item config\site.example.json config\site.json     # edit it: prefix, user, machines, drivers

# 2. build everything that is not a big binary
.\src\tools\New-Kit.ps1

# 3. install Ventoy on the stick (ventoy.net) and label the data partition "Ventoy", then publish
.\src\tools\Publish-Stick.ps1 -Stick E: -Library D:\library

# 4. fetch the recovery ISOs (checksums are verified) and write the manifest
.\src\tools\Get-RescueIsos.ps1 -Library D:\library
.\src\tools\New-Manifest.ps1 -Stick E:
# after a later publish: re-hash the small files only and keep the recorded hashes of the big ones
.\src\tools\New-Manifest.ps1 -Stick E: -Update
```

`-Library` layout: `iso\**` (exact file names from `config/catalog.json`), `office\{_ODT\setup.exe, pt-BR\Office-Retail-CurrentChannel_*}`,
`software\**`, `drivers\<machine-folder>\**`. See `docs/ARCHITECTURE.md`.

## Test without touching a machine

Everything was validated in Hyper-V: `src/tools/New-TestStick.ps1` makes a small *virtual* Ventoy stick, `vmtools.ps1` creates VMs over it,
types into the Ventoy menu and takes screenshots through WMI, and the guest's logs are read from the VM's disk. See `docs/TESTING.md`.

```powershell
.\tests\Test-Repo.ps1      # syntax, example-site build, privacy scan (also a pre-commit hook: git config core.hooksPath .githooks)
```

## Safety notes

* **Disk selection is manual** in every Windows template, on purpose. The stick's own partitions show up in Setup: never pick them.
* The install keys in `config/catalog.json` are Microsoft's **published generic install keys**; they only skip the key page and do **not** activate.
* Office is the *Retail* edition: it activates with your own key or account. LTSC/IoT need their own licence.
* `VTOY_MENU_TIMEOUT` must never be `0` (Ventoy would boot the first image at once). `Test-Repo.ps1` checks it.
* See `docs/SECURITY.md` for the threat model and what must stay private.

## License

PolyForm Strict 1.0.0, like the other ThinkLab repositories - see `LICENSE`.
