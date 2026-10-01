# Instructions for Codex agents

This repository contains Deadlock Personal Toolkit (DLTK), a client-side Source 2 / Panorama mod.

## Installation tasks

If the user asks you to install this mod on their PC, **read `CODEX_INSTALL.md` first and follow it as the installation runbook**.

The intended user request may be as short as:

> Install this Deadlock mod for me: https://github.com/psiu7217/deadlock-MOD

Treat that as an installation task and use `CODEX_INSTALL.md` for the detailed procedure.

Key rules:

- Detect whether Deadlock is running before changing game files.
- Never terminate Deadlock automatically.
- Never replace a VPK or edit `gameinfo.gi` while the game is running.
- Back up existing game files before modification.
- Never replace current `gameinfo.gi` wholesale with an older copy.
- Prefer a current prebuilt release VPK when available; otherwise build only with a compatible local toolchain.
- Do not download arbitrary third-party binaries to satisfy missing build dependencies.
- Preserve other mods and current Deadlock build-specific configuration.
- Do not launch the game automatically after installation; report what was changed and let the user test manually.
- Party / “With Party” functionality is experimental and is not part of installation acceptance criteria.

## Development tasks

For source/build work, also read:

- `README.md`
- `CODEX_HANDOFF.md`

Keep generated Valve resources, compiled Source 2 resources, VPKs, build output, backups, and local CSDK/game files out of Git as defined by `.gitignore`.
