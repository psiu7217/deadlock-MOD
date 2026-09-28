# Deadlock Personal Toolkit

Deadlock Personal Toolkit (DLTK) is a client-side Source 2 / Panorama toolkit for Deadlock. It adds a modular in-game settings panel for personal HUD utilities.

## Features

- Rune / Bridge Buff warning before the expected spawn cycle.
- Configurable warning lead time.
- Custom warning sound support (development/debug state; see Current status).
- Party lane preference helper for “With Party”. Live automation is not yet fully verified.
- Modular in-game settings UI for DLTK features.

## Current status

The known-good Deadlock UI sound plays through the Panorama sound path. The custom event DLTK.Rune.Warning currently does **not** produce audible sound at runtime, although its WAV, soundevent, and addon manifest compile and are packaged. Custom sound registration/playback is being debugged.

The Party helper can detect and attempt to set the native lane preference, but live confirmation that it reliably keeps “With Party” selected is still pending. Do not treat it as fully verified.

The default Rune schedule is a first spawn at 05:00, then every five minutes, with a 30-second warning lead. Settings currently reset when the Panorama context is reloaded.

## Installation

This repository contains source code only. Debug and generated VPK files are not stored in Git. Stable VPK builds may be attached to GitHub Releases after the runtime issues are resolved.

Build a VPK with the local Deadlock CSDK, then install the release package as:

    <Deadlock install directory>\game\citadel\addons\pak99_dir.vpk

Close Deadlock before replacing the installed VPK and keep a backup of the existing file. The helper in tools/install_built_vpk.ps1 checks whether the game is running, backs up the current slot, and verifies the copied file hash.

    powershell -ExecutionPolicy Bypass -File .\tools\install_built_vpk.ps1 `
      -GameRoot "<Deadlock install directory>" `
      -BuiltVpk ".\dist\pak99_dir.vpk"

## Development

Requirements:

- Windows and a compatible Deadlock installation.
- Source 2 / Deadlock Reduced CSDK 12 with ResourceCompiler and CSDKCfgVPK.
- PowerShell and Python 3 for the included build and validation scripts.

Run the engine-independent Rune schedule check and source tree check from the repository root:

    python .\tools\validate_schedule.py
    .\tools\inspect_tree.ps1

Build a VPK without installing it (replace both placeholder paths first):

    powershell -ExecutionPolicy Bypass -File .\tools\build_vpk.ps1 `
      -CsdkRoot "<path to Reduced CSDK 12>" `
      -GameRoot "<Deadlock install directory>" `
      -OutputVpk ".\dist\pak99_dir.vpk"

Build output, staged resources, backups, compiled Source 2 resources, and VPK packages are local artifacts and are excluded from Git. Keep CSDK and game files outside this repository.

To replace the bundled custom WAV for a local build, use tools/set_custom_sound.ps1 with a PCM WAV input. The canonical project asset is src/sounds/dltk/rune_warning.wav.

## Repository layout

- src/panorama — HUD wrapper, styles, scripts, feature modules, and settings UI.
- src/sounds — the user-created Rune warning WAV.
- src/soundevents and src/resourcemanifests — Source 2 source resources.
- tools — build, installation, sound import, and validation scripts.
- config — default settings reference.
- CODEX_HANDOFF.md — current technical state and development notes.
- THIRD_PARTY_NOTICES.md — attribution and license notes for adapted/reference material.

## Licensing and affiliation

No project-wide license has been selected. Apache-2.0 applies to the identified adapted portions described in THIRD_PARTY_NOTICES.md; the full license text is included under LICENSES/.

This project is unofficial and is not affiliated with or endorsed by Valve. Deadlock, Source 2, Panorama, and related game names and marks belong to their respective owners.
