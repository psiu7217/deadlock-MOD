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

Party / “With Party” work remains experimental and must not be treated as stable without a fresh runtime test.

## Source-of-truth warning

GitHub `main` still contains the original 28 September source snapshot plus documentation updates. The latest runtime-tested post-update working tree was developed locally afterward and has not yet been fully synchronized to GitHub.

Therefore:

- do not assume current `main` build scripts exactly reproduce the latest working VPK;
- do not restore the old standalone `src/soundevents/*` / `src/resourcemanifests/*` architecture into new work just because those files still exist on `main`;
- before making further source changes, sync the current local working tree first and audit the resulting Git diff.

Known post-update local work included current-stock resource patching/build logic and later UI/sound compatibility work that is not represented by the single original source commit.

## Runtime safety

Assume Deadlock is closed unless explicitly stated otherwise.

If Deadlock is running:

- never replace the installed VPK;
- never kill/restart/stop the game;
- source edits, staging and static validation are allowed.

## Build/install principles

- Build against current installed Deadlock resources rather than permanently committing decompiled Valve resources.
- Keep generated Valve-derived files under ignored build/generated-style paths.
- Keep VPKs, compiler output, backups and staged generated resources out of Git.
- Validate source, compiled resources, VPK contents and hashes before install.
- Close Deadlock before replacing the installed VPK.

Useful checks from the current repository snapshot:

```powershell
python .\tools\validate_schedule.py
.\tools\inspect_tree.ps1
```

## Installation / addon mounting

The VPK normally lives under:

```text
<Deadlock>\game\citadel\addons\pak99_dir.vpk
```

The game must actually mount `citadel/addons`. Deadlock updates / Steam Verify can restore `gameinfo.gi` and remove custom addon search paths. Never replace the whole current `gameinfo.gi` with an old copy.

For sharing with another player, prefer a current Deadlock mod manager / loader rather than asking them to hand-edit `gameinfo.gi`.

## Ownership notes

Some HUD wrapper and timer patterns were adapted from Predi-i/Deadlock-UI-Mods under Apache-2.0. See `THIRD_PARTY_NOTICES.md` and `LICENSES/Apache-2.0.txt`.

The Rune WAV is the user's custom asset. Do not commit Valve binaries, CSDK binaries, full copied/decompiled game resources, or generated compiled stock resources.
