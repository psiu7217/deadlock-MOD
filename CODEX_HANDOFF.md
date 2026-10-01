# DLTK development handoff

## Project

Deadlock Personal Toolkit is a client-side Source 2 / Panorama project. Keep the code modular: the core reads HUD state, feature modules own behavior, and the settings script owns the in-game panel.

## Runtime-verified state

As of 30 September 2026, the Rune / Bridge Buff feature is confirmed working in game after the major Deadlock update:

- DLTK UI loads in game;
- Rune timing follows the in-game match clock;
- the custom Rune warning sound is audible;
- automatic warnings trigger on schedule.

Default schedule:

- first spawn: 05:00;
- repeat interval: 05:00;
- warning lead: 00:30.

The current soundevent volume is 22.0. The current source dynamically inserts the DLTK launcher under the native Escape menu's `#SubOptions`, immediately before `#quit`; its appearance should be rechecked after confirming addon mounting on the current game build.

Party / “With Party” work remains experimental and must not be treated as stable without a fresh runtime test. Settings are in-memory and reset when Panorama reloads.

## Current source layout

- `src/panorama/layout/base_hud.xml` — small DLTK bootstrap layout.
- `src/panorama/layout/dltk_window.xml` — settings window injected into the current stock HUD layout.
- `src/panorama/styles/dltoolkit.css` — toolkit styling.
- `src/panorama/scripts/dltoolkit_config.js` — runtime defaults and sound API.
- `src/panorama/scripts/dltoolkit_core.js` — HUD clock discovery, modules, and Escape-menu integration.
- `src/panorama/scripts/dltoolkit_bootstrap.js` and `escape_bootstrap.js` — bootstrap entry points.
- `src/panorama/scripts/modules/runes.js` — Rune / Bridge Buff timing and warning behavior.
- `src/panorama/scripts/modules/party.js` — experimental native lane preference helper.
- `src/panorama/scripts/ui/settings.js` — tabs, status display, and UI actions.
- `src/sounds/dltk/rune_warning.wav` — user's custom audio asset.
- `tools/patch_stock_panorama.ps1` — extracts and patches the current stock Panorama layouts during build.
- `tools/build_vpk.ps1` — compiles source and packages the generated resources.

## Current sound and Panorama build architecture

The sound build uses the current `pak01_dir.vpk` as its source. It extracts/decompiles the current `soundevents/ui.vsndevts_c`, preserves stock event definitions, injects `DLTK.Rune.Warning` into a generated copy, compiles it, and packages it with `sounds/dltk/rune_warning.vsnd_c`. Runtime does not depend on standalone addon soundevent or addon resource-manifest files; those obsolete sources have been removed.

The Panorama patcher works from current compiled stock resources rather than committing full copied Valve layouts. Generated KV3/XML, extracted Valve resources, compiler output, compiled resources, and VPKs stay in ignored build/output paths.

The packer may display a success dialog and remain alive. The build script waits for stable output, validates VPK parsing, `resourceinfo`, and required contents, then closes the GUI packer.

## Build and validation

Useful source checks:

```powershell
python .\tools\validate_schedule.py
.\tools\inspect_tree.ps1
```

Build with a compatible Deadlock Reduced CSDK 12 ResourceCompiler and CSDKCfgVPK. Pass explicit `CsdkRoot`, `GameRoot`, and `OutputVpk` arguments to `tools/build_vpk.ps1`. The installer refuses to run while Deadlock is active, backs up the existing VPK slot, and verifies the installed hash.

## Runtime safety

Assume Deadlock is closed unless explicitly stated otherwise.

If Deadlock is running:

- never replace the installed VPK;
- never kill, restart, or stop the game;
- source edits, staging, and static validation are allowed.

## Installation / addon mounting

The VPK normally lives under:

```text
<Deadlock>\game\citadel\addons\pak99_dir.vpk
```

The game must actually mount `citadel/addons`. Deadlock updates and Steam Verify can restore `gameinfo.gi` and remove custom addon search paths. Never replace the whole current `gameinfo.gi` with an old copy. For sharing, prefer a current Deadlock mod manager / loader rather than asking another player to hand-edit `gameinfo.gi`.

## Ownership notes

Some HUD wrapper and timer patterns were adapted from Predi-i/Deadlock-UI-Mods under Apache-2.0. See `THIRD_PARTY_NOTICES.md` and `LICENSES/Apache-2.0.txt`.

The Rune WAV is the user's custom asset. Do not commit Valve binaries, CSDK binaries, full copied/decompiled game resources, or generated compiled stock resources.
