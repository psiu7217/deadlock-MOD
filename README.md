# Deadlock Personal Toolkit

Deadlock Personal Toolkit (DLTK) is a client-side Source 2 / Panorama toolkit for Deadlock.

## Current runtime status

As of 30 September 2026, the Rune / Bridge Buff reminder is runtime-verified in the current Deadlock build used for testing:

- the DLTK UI loads in game;
- the Rune timer follows the in-game match clock;
- the custom warning sound is audible;
- automatic warnings fire on schedule.

The current default schedule is:

- first Bridge Buff spawn: `05:00`;
- then every 5 minutes;
- warning: 30 seconds before spawn (`04:30`, `09:30`, `14:30`, ...).

The build injects `DLTK.Rune.Warning` into a generated copy of the current game's stock `soundevents/ui.vsndevts_c`, preserving original events. The current source uses event volume `22.0`; the sound is audible in game.

The current source dynamically adds a DLTK launcher to the native Escape menu. Verify its appearance in game after confirming that the current game configuration mounts `citadel/addons`.

The Party / “With Party” helper is experimental and should not be treated as part of the stable Rune feature.

## Installation

### Recommended for another player

Use a current Deadlock mod loader / Deadlock Mod Manager to mount the mod VPK. This is the safest option for sharing because Deadlock updates can replace `gameinfo.gi` and remove custom addon search paths.

The built mod VPK belongs under the Deadlock addon path, typically:

```text
<Deadlock install directory>\game\citadel\addons\pak99_dir.vpk
```

The exact VPK slot/name may be changed by a mod manager when it orders installed mods. That is normal.

### Manual installation

Manual installation also works when the game is already configured to mount `citadel/addons` with the correct search-path priority.

1. Close Deadlock completely.
2. Back up the current mod VPK if one already exists.
3. Copy the built VPK to:

   ```text
   <Deadlock install directory>\game\citadel\addons\pak99_dir.vpk
   ```

4. Make sure the current Deadlock configuration actually mounts `citadel/addons` before launching the game.
5. Launch Deadlock normally and verify the DLTK entry / Rune UI.

Do **not** blindly replace `gameinfo.gi` with an old copy. Deadlock updates change that file. Steam Verify may also restore it to the vanilla version and remove addon search paths. If manual search-path setup is required, modify the current game version only and keep a backup.

## Sharing a built mod

For a friend, the simplest package is:

```text
DLTK_Runes.zip
└── pak99_dir.vpk
```

A compiled VPK is enough for the player; the CSDK and source tree are only required to build or modify the mod.

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

The build uses the current installed Deadlock resources and a compatible Source 2 / Deadlock ResourceCompiler and VPK packer. Build output, generated Valve-derived resources, extracted stock resources, compiled files, backups, and VPK packages must stay outside tracked source and are ignored by Git. The packer is considered complete only after output stabilization and validation.

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
- `THIRD_PARTY_NOTICES.md` and `LICENSES/` — attribution/license material.

## Licensing and affiliation

No project-wide license has been selected. Apache-2.0 applies to the identified adapted portions described in `THIRD_PARTY_NOTICES.md`; the full license text is included under `LICENSES/`.

This project is unofficial and is not affiliated with or endorsed by Valve. Deadlock, Source 2, Panorama, and related game names and marks belong to their respective owners.
