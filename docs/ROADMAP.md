# Roadmap: finishing Quick Install

Where the project stands at 1.2.2 and what is left to call it done. "Done" means: a stick that installs every supported
system unattended, documented, tested, backed up, and visible in the ThinkLab platform.

## State at 1.2.2

| Area | State |
|---|---|
| Windows kits (10, 11, LTSC, IoT, Server 2019) in PT-BR / EN-US | built; W10, W11, Server tested in VMs |
| Linux kits (AlmaLinux, RHEL, CentOS Stream, Ubuntu Server, openSUSE) | built; Alma, Ubuntu, CentOS, openSUSE tested; RHEL needs your ISO |
| Recovery set (WinPE, SystemRescue, GParted, Clonezilla, MemTest86+) | all boot |
| Boot menu, themes, wallpapers (machines, systems, phone), papers | done |
| Repository | public, sanitised, privacy check in CI-style test |
| ThinkLab web module | catalog screen added (`/quick-install`) |

## Phase 1 - close the open items (small)

1. **Kaspersky Password Manager.** Silent mode is refused by the vendor installer. Options: install it by hand after first logon
   (current), or drive its wizard with UI automation inside `FirstLogon.ps1`. Decide; if automation, test it in a VM.
2. **RHEL.** Supply the Red Hat ISO and run the L5 row of `docs/TESTING.md`.
3. **Lite editions in the second language.** Optional by design; add the ISOs when you have them and run W4.
4. **AlmaLinux workstation PT** finished to first boot (it was verified to the install summary only).
5. **Boot menu at 1080p** on a real screen (only 1024x768 was seen in VMs).

## Phase 2 - real hardware (the part VMs cannot prove)

1. One full install per machine class from the real stick: drivers, naming, wallpapers, Office, profile software.
2. Check that the disk picker never preselects the stick on the real machines (the Linux kits hide it; Windows asks).
3. Record each result in the private status file; fix what differs from the VM runs.

## Phase 3 - release hygiene

1. Refresh the integrity manifest (`New-Manifest.ps1 -Update`) and the backup after every stick change.
2. Cut a release per change set: changelog, tag, `tests/Test-Repo.ps1` green.
3. Keep `src/quickinstall/kits.ts` in thinklab-web in step with `config/catalog.json` (a small script that regenerates it is the
   obvious next automation).

## Phase 4 - ThinkLab integration (later, optional)

1. Gate the screen behind a billing feature (`quickinstall`) once the plan catalog has one.
2. Let the platform hold the per-organisation kit choices (machine classes, language, profile) and build a stick definition from
   them, instead of editing `config/site.json` by hand.
3. Report installs back (name, date, kit version, result) to the asset registry so a freshly installed machine appears as a
   discovered asset with its kit as provenance.

## Definition of done

- Every row of `docs/TESTING.md` is green or explicitly marked optional/manual with the reason.
- Phase 2 passed on each machine class.
- The stick, its checksum manifest and the backup agree.
- The public repository and the ThinkLab screen describe the same catalog.
