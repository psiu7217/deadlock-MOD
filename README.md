# Deadlock Personal Toolkit

Deadlock Personal Toolkit (DLTK) is a client-side Source 2 / Panorama toolkit for Deadlock.

## Current runtime status

As of 30 September / 1 October 2026, the Rune / Bridge Buff reminder is runtime-verified after the major Deadlock update:

- the DLTK UI loads in game;
- the Rune timer follows the in-game match clock;
- the custom warning sound is audible;
- automatic warnings fire on schedule.

The current default schedule is:

- first Bridge Buff spawn: `05:00`;
- then every 5 minutes;
- warning: 30 seconds before spawn (`04:30`, `09:30`, `14:30`, ...).

The build injects `DLTK.Rune.Warning` into a generated copy of the current game's stock `soundevents/ui.vsndevts_c`, preserving original events. The current source uses event volume `22.0`; the sound is audible in game.

The Party / “With Party” helper is experimental and should not be treated as part of the stable Rune feature.

## Stable release

The first stable release is [DLTK Runes v1.0.0](https://github.com/psiu7217/deadlock-MOD/releases/tag/v1.0.0). Use the prebuilt [DLTK_Runes_v1.0.0.vpk](https://github.com/psiu7217/deadlock-MOD/releases/download/v1.0.0/DLTK_Runes_v1.0.0.vpk) instead of rebuilding for a normal installation.

- SHA-256: `9990F935E835E5D72762C7E5D2168DABC720C0710FE0859E95F589393477825D`
- Size: `157789` bytes
- Source commit: [`b635a59a757715e45fa6fc779fbf65b011f23c0a`](https://github.com/psiu7217/deadlock-MOD/commit/b635a59a757715e45fa6fc779fbf65b011f23c0a)

This VPK passed manual runtime testing. The one-shot Codex installation flow, including the verified five-line addon-mount patch, was also successfully tested on a second Windows PC.

## Installation

### One-prompt install with Codex

If Codex is available on the target PC, give it only this task:

```text
Install this Deadlock mod for me:
https://github.com/psiu7217/deadlock-MOD
```

That is the intended complete installation prompt.

Repository-level instructions are in `AGENTS.md`, and the complete tested installation runbook is in `CODEX_INSTALL.md`.

For a compatible installation with Deadlock already closed, Codex should complete the normal install without asking for intermediate confirmations: locate Deadlock, download and verify the stable VPK, back up `gameinfo.gi`, apply the documented five-line addon-mount patch when needed, install the VPK, verify the final state, and finish with **“You can launch Deadlock now.”**

Codex must not terminate or launch Deadlock automatically. If the game is already running, the user must close it before file changes can proceed.

### Manual / mod-manager installation

A current Deadlock mod manager / loader may also manage addon mounting. For a standalone manual installation, the VPK normally belongs at:

```text
<Deadlock install directory>\game\citadel\addons\pak99_dir.vpk
```

The current game must mount `citadel/addons` correctly. Do not add only a lone `Game citadel/addons` line and do not replace the whole `gameinfo.gi` with an old template. The tested manual mount layout and backup procedure are documented in `CODEX_INSTALL.md`.

Deadlock updates and Steam Verify may restore `gameinfo.gi` and remove addon search paths. If DLTK stops loading after an update, rerun the installation procedure against the current game config.

## Development

The source project contains Panorama UI/scripts, Rune logic, the custom warning WAV, and build/validation tools.

Useful checks from the repository root:

```powershell
python .\tools\validate_schedule.py
.\tools\inspect_tree.ps1
```

Build a staged VPK without installing it (replace the placeholder paths):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build_vpk.ps1 `
  -CsdkRoot "<path to Reduced CSDK 12>" `
  -GameRoot "<Deadlock install directory>" `
  -OutputVpk ".\dist\pak99_dir.vpk"
```

The build uses the current installed Deadlock resources and a compatible Source 2 / Deadlock ResourceCompiler and VPK packer. Build output, generated Valve-derived resources, extracted stock resources, compiled files, backups, and VPK packages must stay outside tracked source and are ignored by Git.

Close Deadlock before installing or replacing a VPK. The installer refuses to replace it while the game is running, backs up the current slot, and verifies the installed hash:

```powershell
.\tools\install_built_vpk.ps1 -GameRoot "<Deadlock install directory>" -BuiltVpk ".\dist\pak99_dir.vpk"
```

## Repository layout

- `src/panorama` — HUD/UI layouts, styles, scripts and modules.
- `src/sounds/dltk/rune_warning.wav` — custom Rune warning audio source.
- `tools` — build, installation, sound import and validation scripts.
- `config` — defaults/reference configuration.
- `CODEX_HANDOFF.md` — development notes.
- `AGENTS.md` — repository instructions for Codex agents.
- `CODEX_INSTALL.md` — tested one-shot Codex installation runbook.
- `THIRD_PARTY_NOTICES.md` and `LICENSES/` — attribution/license material.

## Licensing and affiliation

No project-wide license has been selected. Apache-2.0 applies to the identified adapted portions described in `THIRD_PARTY_NOTICES.md`; the full license text is included under `LICENSES/`.

This project is unofficial and is not affiliated with or endorsed by Valve. Deadlock, Source 2, Panorama, and related game names and marks belong to their respective owners.
