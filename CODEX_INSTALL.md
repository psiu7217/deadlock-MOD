# Codex install guide

This file is intended for a local Codex agent installing Deadlock Personal Toolkit (DLTK) on another Windows PC.

Repository:

```text
https://github.com/psiu7217/deadlock-MOD
```

## Ready-to-use prompt for Codex

Copy this entire prompt into Codex:

```text
Install Deadlock Personal Toolkit (DLTK) from:

https://github.com/psiu7217/deadlock-MOD

on this Windows PC for my local Deadlock installation.

Work autonomously, but follow the repository documentation exactly.
Read these files first:

- README.md
- CODEX_HANDOFF.md
- CODEX_INSTALL.md

IMPORTANT SAFETY RULES

1. Detect whether Deadlock is currently running.
2. If Deadlock is running:
   - do NOT kill it;
   - do NOT restart it;
   - do NOT replace any VPK;
   - do NOT edit gameinfo.gi;
   - stop and ask me to close the game manually.
3. Never replace the whole current gameinfo.gi with an old copy.
4. Before changing any existing game file, create a timestamped backup.
5. Preserve current Deadlock build-specific entries and comments.
6. Do not install unrelated software or modify other mods.
7. Do not launch Deadlock automatically at the end. I will test it manually.

GOAL

Install the current stable Rune / Bridge Buff reminder build so that:

- DLTK appears in the Deadlock UI;
- Rune timing uses the in-game clock;
- the bundled warning sound works;
- automatic warnings fire 30 seconds before the 05:00, 10:00, 15:00, ... Bridge Buff cycle.

STEP 1 — LOCATE DEADLOCK

Find the actual Deadlock installation instead of assuming C:\Steam.

Check Steam library configuration / common install locations and identify:

<DeadlockRoot>\game\citadel\

Confirm the current game build and the current gameinfo.gi path.

STEP 2 — OBTAIN THE MOD

Prefer a prebuilt release VPK if the repository has a current GitHub Release containing the DLTK VPK.

If a compatible prebuilt VPK is available:
- download/use that VPK;
- do not rebuild unnecessarily.

If no prebuilt release exists:
- clone or update this repository locally;
- run repository validation;
- build from source ONLY if a compatible local Deadlock Reduced CSDK / ResourceCompiler / VPK packer is available;
- use tools/build_vpk.ps1 and the current installed Deadlock resources as documented;
- do not download random third-party binaries merely to make the build work.

If there is no prebuilt VPK and no compatible local build toolchain, stop and tell me exactly what is missing rather than improvising.

STEP 3 — VALIDATE BEFORE INSTALL

For a source build, run:

python .\tools\validate_schedule.py
.\tools\inspect_tree.ps1

Confirm the build output parses correctly and contains the expected DLTK Panorama resources, Rune logic, custom sound resource, and patched stock soundevent resource.

Record the SHA-256 of the VPK that will be installed.

STEP 4 — BACK UP EXISTING MOD SLOT

Target addon directory is normally:

<DeadlockRoot>\game\citadel\addons\

If a VPK already occupies the target slot, back it up with a timestamp before replacing it.

Do not delete an existing mod without preserving it.

STEP 5 — ENSURE ADDON MOUNTING

Check whether the CURRENT Deadlock configuration already mounts `citadel/addons`.

If a current Deadlock Mod Manager / compatible mod loader is already installed and managing addon search paths, prefer using its current mechanism rather than fighting it.

If manual mounting is required:
- inspect the CURRENT gameinfo.gi first;
- inspect current Deadlock Mod Manager source/documentation if needed to understand the current build's expected search-path behavior;
- make the smallest possible change to the CURRENT file;
- preserve current Game_UILanguage, Game_LowViolence, UserSettingsPathID, LegacyUserSettingsPathID, comments, and all other current-build settings;
- create a timestamped backup first;
- never paste an old full SearchPaths block from another Deadlock build;
- never replace the whole file.

After any manual edit, re-read and validate gameinfo.gi structurally before proceeding.

If the correct mount method is uncertain, stop and report the uncertainty instead of guessing.

STEP 6 — INSTALL VPK

Install the validated VPK under the active Deadlock addon path.

Use the repository installer when appropriate:

.\tools\install_built_vpk.ps1 -GameRoot "<DeadlockRoot>" -BuiltVpk "<path-to-built-vpk>"

The installer should refuse to replace the file while Deadlock is running, create a backup of the existing slot, and verify the copied hash.

If installing a prebuilt release VPK manually, provide the same protections yourself:
- game closed;
- backup existing slot;
- copy atomically where practical;
- verify installed SHA-256 equals source SHA-256.

STEP 7 — FINAL AUDIT

Do NOT launch Deadlock automatically.

Report:

1. Deadlock root detected
2. Current Deadlock build
3. Repository/release version or commit used
4. Whether a prebuilt VPK or local build was used
5. VPK SHA-256
6. Installed VPK path
7. Backup path of any replaced VPK
8. Whether `citadel/addons` was already mounted
9. Whether gameinfo.gi was changed
10. If changed: backup path and exact minimal diff
11. Validation results
12. Any conflicts with existing mods

Then give me these manual test steps:

- launch Deadlock normally;
- enter a match / hero testing environment;
- press Esc and confirm the DLTK entry appears;
- open DLTK and confirm Rune reminder is enabled;
- verify Game time / Next Bridge Buff / Warning in update;
- verify the custom sound fires on schedule.

Do not modify Party functionality or other experimental modules during installation.
Do not commit or push anything to the repository.
```

## Notes for Codex

- The source repository intentionally does not track generated VPKs or compiled Source 2 resources.
- Current source patches stock Panorama and stock `soundevents/ui.vsndevts_c` during build rather than storing full generated Valve resources.
- `src/sounds/dltk/rune_warning.wav` is the canonical source audio asset.
- Party / “With Party” functionality is experimental and is not part of the installation acceptance criteria.
- Deadlock updates and Steam Verify can restore `gameinfo.gi` and remove custom addon search paths, so always inspect the current build before changing mounting configuration.
