# Third-party notices

## Predi-i / Deadlock-UI-Mods

Repository: https://github.com/Predi-i/Deadlock-UI-Mods

The repository identifies its source as Apache License 2.0. A copy of the license text is included at LICENSES/Apache-2.0.txt.

DLTK adapts a limited amount of source structure from the upstream Bridge-Buff-Reminder mod:

- The small WindowRoot/CitadelHud wrapper pattern in src/panorama/layout/base_hud.xml.
- HUD panel traversal and ignored-mode checks in src/panorama/scripts/dltoolkit_core.js.
- The polling and one-shot alert pattern in src/panorama/scripts/modules/runes.js.

These files have been modified for DLTK's modular architecture, settings, current HUD clock shape, and configurable warning behavior. Their source headers identify the adaptation and modification date. No upstream sound file, compiled resource, or VPK is included.

## SteamTracking / GameTracking-Deadlock

Repository: https://github.com/SteamTracking/GameTracking-Deadlock

Used as a technical reference for current Deadlock Panorama layouts and sound-event identifiers. No source files or compiled resources from this repository are included.

## Valve / Deadlock assets

The project does not include a full Valve/Deadlock decompiled HUD resource, game binaries, or compiled game assets. The HUD source is a small addon wrapper with DLTK's own settings panel. The bundled Rune warning WAV is a user-created custom asset, not a Valve or third-party sound file.

Deadlock, Source 2, Panorama, and related names and assets belong to their respective owners. This unofficial project is not affiliated with or endorsed by Valve.

## Project-wide license

No project-wide license has been selected. The included Apache-2.0 text applies to the identified adapted portions above; it does not grant a blanket license to all original DLTK code or the user-created WAV.
