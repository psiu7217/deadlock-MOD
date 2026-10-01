# Instructions for Codex agents

This repository contains Deadlock Personal Toolkit (DLTK), a client-side Source 2 / Panorama mod.

## Installation tasks

If the user asks you to install this mod on their PC, **read `CODEX_INSTALL.md` first and follow it as the installation runbook**.

The intended user request may be as short as:

> Install this Deadlock mod for me: https://github.com/psiu7217/deadlock-MOD

Treat that single request as authorization to complete the normal, documented installation end-to-end. Do not ask for conversational confirmation for routine steps that are explicitly covered by `CODEX_INSTALL.md`, including:

- locating Deadlock;
- downloading the verified stable release VPK;
- checking its size and SHA-256;
- creating timestamped backups;
- creating the `citadel/addons` directory if missing;
- applying the documented, verified five-line addon-mount patch when the current `gameinfo.gi` has the expected compatible structure;
- installing/replacing the target VPK;
- verifying the final hashes and config diff.

The desired successful final response is essentially: installation complete, checks passed, **you can launch Deadlock now**.

### Hard stop conditions

Stop instead of improvising only when one of these conditions is true:

- Deadlock is currently running. Never terminate it automatically; tell the user to close it and rerun/continue the task.
- The downloaded release asset fails the documented size or SHA-256 check.
- The current `gameinfo.gi` structure is materially different from the compatible structure documented in `CODEX_INSTALL.md`, so the verified minimal patch cannot be applied safely.
- A mod manager is actively managing a different addon layout and changing the file yourself would conflict with it.
- Required filesystem access is unavailable.

### Safety / compatibility rules

- Never terminate, restart, or launch Deadlock automatically.
- Never replace a VPK or edit `gameinfo.gi` while Deadlock is running.
- Back up every existing game file that will be changed.
- Never replace current `gameinfo.gi` wholesale with an older copy or template.
- Preserve current Deadlock build-specific entries, comments, encoding, and line endings.
- Do **not** use the previously failed one-line-only `Game citadel/addons` patch. The verified manual mount adds five lines and keeps explicit `Mod` / `Write` roots; see `CODEX_INSTALL.md`.
- Prefer the verified stable prebuilt release VPK. Do not rebuild it unless the runbook explicitly requires a fallback source build.
- Do not download arbitrary third-party build tools or binaries.
- Preserve unrelated mods.
- Do not modify Party / “With Party”; it is experimental and not part of installation acceptance.

## Development tasks

For source/build work, also read:

- `README.md`
- `CODEX_HANDOFF.md`

Keep generated Valve resources, compiled Source 2 resources, VPKs, build output, backups, and local CSDK/game files out of Git as defined by `.gitignore`.
