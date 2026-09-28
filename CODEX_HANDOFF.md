# DLTK development handoff

## Project

Deadlock Personal Toolkit is a client-side Source 2 / Panorama project. Keep the code modular: the core reads HUD state, feature modules own behavior, and the settings script owns the in-game panel.

## Current source layout

- src/panorama/layout/base_hud.xml — minimal HUD wrapper and DLTK overlay.
- src/panorama/styles/dltoolkit.css — toolkit styling.
- src/panorama/scripts/dltoolkit_config.js — runtime defaults and sound API.
- src/panorama/scripts/dltoolkit_core.js — HUD clock discovery and module polling.
- src/panorama/scripts/modules/runes.js — Rune / Bridge Buff timing and warning behavior.
- src/panorama/scripts/modules/party.js — native lane preference helper.
- src/panorama/scripts/ui/settings.js — tabs, status display, and UI actions.
- src/sounds/dltk/rune_warning.wav — user-created custom audio source.
- src/soundevents and src/resourcemanifests — Source 2 sound registration source.

## Verified and open runtime status

- The known-good UI sound path has been confirmed to play in Deadlock.
- DLTK.Rune.Warning currently produces no audible sound at runtime. The WAV, soundevent, and addon manifest compile and are included in the debug build, but custom event registration/playback remains open.
- The Runes tab has temporary Test custom and Test known-good buttons. Each logs the event passed to PlaySoundEffect when pressed.
- Party lane preference logic can attempt to select “With Party”; reliable live confirmation is still pending.
- Settings are in-memory and reset when Panorama reloads.

Keep the custom sound issue visible in documentation until the event is audibly confirmed in-game. Do not describe Party automation as fully verified without a live test.

## Build and validation

The build uses a compatible Deadlock Reduced CSDK 12 ResourceCompiler and CSDKCfgVPK. See the parameterized example in README.md. The build script writes staging/compiler outputs outside the tracked source tree and packs only compiled resources. Generated VPKs, backups, and compiler output are intentionally ignored by Git.

Useful source checks:

    python .\tools\validate_schedule.py
    .\tools\inspect_tree.ps1

The installer refuses to run while Deadlock is active, backs up the existing VPK slot, and verifies the installed hash. Close Deadlock before running it.

## Ownership notes

Some HUD wrapper and timer patterns are adapted from Predi-i/Deadlock-UI-Mods under Apache-2.0. The affected files carry notices; see THIRD_PARTY_NOTICES.md and LICENSES/Apache-2.0.txt. The project does not include a full decompiled Valve HUD resource or compiled game files. The Rune WAV is the user's custom asset.
