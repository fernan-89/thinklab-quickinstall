# Security and privacy

## What must never be committed

| Item | Where it lives instead |
|---|---|
| Your machines, models, types, serial numbers, host names, user names | `config/site.json` (git-ignored) |
| Initial password | `site.json` (`initialPassword`) - only a bootstrap, the kit **forces a change at the next logon** |
| Product keys (Windows, Office) | your password manager; Office *Retail* activates with your own key/account |
| ISOs, installers, driver packs, Office payload | the *library* (git-ignored) and the stick |
| Real e-mail addresses, local user paths, private IPs | rejected by `tests/Test-Repo.ps1` |

`config/privacy-terms.local.txt` (git-ignored, one term per line) lets you add your own identifiers; the repo check and the **pre-commit hook**
fail if any appears in a tracked or staged file.

## Threat model of the stick

* The answer files contain the **initial** local-admin password in clear text (Windows unattend requires it). Treat the stick like a key:
  keep it physically safe, and never publish a built `Unattend\` folder.
* The generic Windows keys in `config/catalog.json` are Microsoft's published *install* keys; they do not license anything.
* Everything downloaded by `Get-RescueIsos.ps1` is checked against the checksum published by its project before it is renamed into place;
  the Office Deployment Tool is checked for a valid Microsoft Authenticode signature.
* `Verify-Stick.ps1` + `SHA256SUMS.txt` detect a corrupted or altered stick. The manifest itself is not signed: keep a copy off the stick.
* The Ventoy Secure Boot flow needs the user to enroll Ventoy's key once per machine (MOK). That is a deliberate, visible step.

## Reporting

Open a GitHub issue without including any private data (names, serials, keys).
