# Instructions for Codex agents

Deadlock Personal Toolkit (DLTK) is a client-side Source 2 / Panorama mod.

## Installation tasks

If the user asks to install this mod, for example:

> Install this Deadlock mod for me: https://github.com/psiu7217/deadlock-MOD

use `CODEX_INSTALL.md` and the repository's one-shot installer:

```text
tools/install_release.ps1
```

For a normal install, do **not** manually reproduce the installer logic. Do not clone/build the source, scan the VPK, research Deadlock Mod Manager, inspect broad game directories, or invent PowerShell/CMD commands for editing `gameinfo.gi`.

The intended flow is:

1. Download `tools/install_release.ps1` from this repository.
2. Run it with Windows PowerShell.
3. On success, report: **DLTK installed; you can launch Deadlock now.**

The installer already finds Steam/Deadlock, checks whether the game is running, downloads and hashes the stable VPK, backs up and patches the addon mount when required, installs `pak99_dir.vpk`, and verifies the installed hash.

If the installer stops because Deadlock is running, ask the user to close it and rerun the same script. For other installer errors, report the exact error instead of improvising a different install path unless the user explicitly requests debugging.

Never kill or launch Deadlock automatically.

## Development tasks

For source/build/development work, read `README.md` and `CODEX_HANDOFF.md`. Keep generated Valve resources, compiled Source 2 resources, VPKs, build output, backups, and local CSDK/game files out of Git as defined by `.gitignore`.
