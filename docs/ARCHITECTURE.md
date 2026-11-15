# Architecture

## Layers

| Layer | Files | Purpose |
|---|---|---|
| **Definition** | `config/catalog.json`, `config/software.json`, `config/site.json` (private) / `site.example.json` | What exists (images, software, profiles) and what *this* site owns (machines, languages, drivers). |
| **Generators** | `src/tools/New-*.ps1`, `Build-Theme.ps1`, `Build-PeExtras.ps1`, `Build-Docs.ps1` | Turn the definition into files for the stick. Deterministic: same input, same output. |
| **Kit (runs on the target)** | `src/kit/FirstLogon.ps1`, `Verify-Stick.ps1` + generated `kit.json` | Post-install and integrity check, executed *from the stick*. |
| **Publishing** | `Publish-Stick.ps1`, `New-Manifest.ps1`, `Get-RescueIsos.ps1` | Put the build + big binaries on the stick; checksum everything. |
| **Testing** | `New-TestStick.ps1`, `vmtools.ps1`, `Test-StickImageInHyperV.ps1`, `tests/Test-Repo.ps1` | Hyper-V based end-to-end tests and repo checks. |

## Stick layout

```
ISO\1-Windows | 2-Linux | 3-Recovery   images (Ventoy TreeView menu, folders = menu groups)
Unattend\      Windows XML, AlmaLinux kickstart, Ubuntu autoinstall (selected from the Ventoy template list)
Scripts\       FirstLogon.ps1, kit.json, Verify-Stick.ps1
Office\        _ODT\setup.exe + pt-BR\Office-Retail-CurrentChannel_* (one bilingual payload for every Office year)
Software\      installers named Product_Detail_Arch_Version_Language.ext
Drivers\       one folder per machine (pnputil'ed at first logon; "pack:" entries are self-extracting vendor packs)
ventoy\        ventoy.json, theme\thinklab, inject\ThinkLab-PE-Extras.zip
Docs\          offline bilingual documentation   |   SHA256SUMS.txt   |   Inventory\<name>.json (written by installs)
```

## How a Windows install flows

1. Ventoy lists the ISO (alias from the catalog) and, because of `auto_install`, a **template list**: `BASE_*` first, then the machine kits.
2. The chosen XML sets language, edition (by image *name*, not index), generic key, computer name, time zone, a local admin and autologon once.
   Disk selection is left to the person.
3. At the first logon the XML runs a bootstrap that waits for the `Ventoy` volume and starts `FirstLogon.ps1 -Profile .. -Lang .. -OS .. -Drivers ..`.
4. `FirstLogon.ps1`: drivers -> Office (Office Deployment Tool, offline source) -> software from `kit.json` (installer from the stick, else winget)
   -> `inventory.json` -> forced password change. Every step is logged to `C:\QuickInstall` and failures never stop the next step.

## Design decisions

* **Data-driven, not hard-coded.** Adding a machine is editing `site.json`; adding software is editing `software.json`.
* **Names are the interface.** File names follow `Product_Detail_Arch_Version_Language.ext` and the generators locate things by exact name, so a wrong
  or missing file is a *visible* error, not a silent one.
* **One Office payload.** The ODT downloads the same Current-Channel payload for 2021 and 2024 retail product ids; the product ids picked at install time
  decide the suite (2021 = ProPlus + Visio + Project + Publisher, 2024 = without Publisher, which does not exist there).
* **Nothing destructive by default.** Disk choice is manual; Linux templates leave disk, user and network interactive; the publisher refuses any volume not
  labelled `Ventoy`.
* **Hostile-environment friendly.** No telemetry, no cloud calls from the kit except the optional `winget` fallbacks.

## Relation to the ThinkLab platform

The kit is standalone. `Inventory\<computer>.json` (name, manufacturer, model, serial, OS, build, profile, language, date) is shaped to be imported
into `it-asset-registry`; recovery tooling on the stick complements the platform's recovery / DR plans. No integration is assumed or required.
