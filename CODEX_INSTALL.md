# Codex install guide

This file is the installation runbook for a local Codex agent installing Deadlock Personal Toolkit (DLTK) on another Windows PC.

Repository:

```text
https://github.com/psiu7217/deadlock-MOD
```

## One-line user request

The intended installation request is only:

```text
Install this Deadlock mod for me:
https://github.com/psiu7217/deadlock-MOD
```

That single request authorizes the normal installation steps in this runbook. **Do not ask the user for additional confirmation for the documented download, backup, five-line mount patch, VPK copy, or verification steps.**

If all checks pass, finish with a concise message equivalent to:

> DLTK v1.0.0 installed and verified. You can launch Deadlock now.

Do not launch Deadlock yourself.

## Stable release to install

Use the verified prebuilt release. Do **not** rebuild it for a normal installation.

- Release: `https://github.com/psiu7217/deadlock-MOD/releases/tag/v1.0.0`
- Asset: `https://github.com/psiu7217/deadlock-MOD/releases/download/v1.0.0/DLTK_Runes_v1.0.0.vpk`
- Filename: `DLTK_Runes_v1.0.0.vpk`
- Expected SHA-256: `9990F935E835E5D72762C7E5D2168DABC720C0710FE0859E95F589393477825D`
- Expected size: `157789` bytes
- Source commit: `b635a59a757715e45fa6fc779fbf65b011f23c0a`

This exact VPK was runtime-tested successfully and the installation procedure below was also successfully tested on a second Windows PC.

## Hard stop conditions

Stop instead of improvising only if:

1. Deadlock is running. Never kill/restart it; tell the user to close it and then continue/rerun.
2. The release asset hash or size does not match the values above.
3. `gameinfo.gi` has a materially different `SearchPaths` structure and the verified minimal patch cannot be applied unambiguously.
4. A mod manager is actively managing a different addon layout and direct edits would conflict with it.
5. The target `pak99_dir.vpk` is occupied by an unrelated mod and replacing it would disable that mod.
6. Required filesystem permissions are unavailable.

Do not ask for confirmation merely because a backup or the verified five-line patch is required.

---

# Installation procedure

## 1. Locate Deadlock

Find the actual Steam library instead of assuming `C:\Steam`.

Locate:

```text
<DeadlockRoot>\game\citadel\gameinfo.gi
```

and the addon directory:

```text
<DeadlockRoot>\game\citadel\addons\
```

Detect whether Deadlock is running before changing files.

If it is running, stop without changing anything and tell the user to close the game. Never terminate it automatically.

## 2. Download and verify the stable VPK

Download exactly:

```text
https://github.com/psiu7217/deadlock-MOD/releases/download/v1.0.0/DLTK_Runes_v1.0.0.vpk
```

Do not disable TLS/certificate verification. If one local download method has a certificate/trust problem, use another normal trusted path such as the browser/web download rather than bypassing certificate checks.

Verify before installation:

```text
Size:    157789 bytes
SHA-256: 9990F935E835E5D72762C7E5D2168DABC720C0710FE0859E95F589393477825D
```

If either value differs, do not install.

## 3. Inspect current addon mounting

Read the **current local** `gameinfo.gi`. Never replace it with a repository copy, old backup from another PC, or a hard-coded full template.

Preserve all current-build content, including when present:

- `Game_UILanguage` / `Game_Language`
- `Game_LowViolence`
- `UserSettingsPathID`
- `LegacyUserSettingsPathID`
- comments
- encoding and line endings
- any unrelated current-build settings

If `citadel/addons` is already mounted correctly with explicit `Mod`/`Write` roots, do not duplicate the entries.

### Verified manual mount patch

For the compatible stock layout where `SearchPaths` already contains the existing entries:

```text
Game    citadel
Game    core
```

apply **exactly five added lines**, preserving the existing two `Game` entries and all other content:

```diff
+ Game    citadel/addons
+ Mod     citadel
+ Write   citadel
  Game    citadel
+ Mod     core
+ Write   core
  Game    core
```

Spacing/tabs may follow the file's existing style. Semantically the resulting order must be:

```text
Game    citadel/addons
Mod     citadel
Write   citadel
Game    citadel
Mod     core
Write   core
Game    core
```

This ordering matches the current Deadlock Mod Manager mount logic used as compatibility evidence and has been successfully tested with DLTK on two PCs.

**Do not use the old one-line-only patch:**

```text
Game citadel/addons
```

by itself. A previous test of that simplified patch caused Deadlock to fail with `Unable to read default keybinding configuration (user_keys_default)`.

## 4. Back up and patch `gameinfo.gi` safely

Before modifying the live file, create a timestamped copy, for example:

```text
gameinfo.gi.codex-backup-YYYYMMDD-HHMMSS
```

Record its SHA-256.

Use a simple, robust file-update flow:

1. Copy the original to the timestamped backup.
2. Prepare the modified content in a temporary file next to `gameinfo.gi`.
3. Preserve the source file's encoding and CRLF/LF style.
4. Validate the temporary file before replacing the live file.
5. Confirm the intended diff is only the verified five added mount lines when starting from the compatible stock layout.
6. Replace/move the validated temp file over the live file.
7. Re-read the live file and validate it again.

Do **not** use a fragile `File.Replace(...)` backup overload if the runtime/platform rejects it. The explicit backup copy already provides recovery protection.

Validation after the edit must confirm:

- braces / `SearchPaths` structure are intact;
- `citadel/addons` appears exactly once for this layout;
- `Mod citadel`, `Write citadel`, `Mod core`, `Write core` are present in the verified order;
- original language/low-violence/settings-path entries are unchanged;
- no unrelated lines were removed or rewritten.

If the current file does not have compatible anchors or would require broader reconstruction, stop rather than guessing.

## 5. Install the VPK

Target path for this standalone installation:

```text
<DeadlockRoot>\game\citadel\addons\pak99_dir.vpk
```

Create `addons` if it does not exist.

If `pak99_dir.vpk` does not exist, install normally.

If it already exists:

- if it is clearly a previous DLTK installation, back it up with a timestamp and replace it;
- if it is an unrelated mod, stop instead of silently disabling that mod.

Copy the verified release VPK into the target path. Use a temp file + rename/move on the same filesystem when practical.

After installation verify the installed file again:

```text
Size:    157789 bytes
SHA-256: 9990F935E835E5D72762C7E5D2168DABC720C0710FE0859E95F589393477825D
```

## 6. Final audit

Do not launch Deadlock automatically.

Verify:

- Deadlock was closed during all mutations;
- installed VPK hash and size match the stable release;
- `gameinfo.gi` passed structural checks;
- if patched from the compatible stock layout, the final comparison shows exactly the documented five added mount lines;
- the timestamped `gameinfo.gi` backup still exists and hashes correctly;
- no unrelated mod or game file was changed.

A successful final response should be short, for example:

```text
DLTK v1.0.0 installed successfully.
VPK hash verified.
Deadlock addon mount configured and validated.
Backup of gameinfo.gi created.

You can launch Deadlock now.
```

Optionally include the installed path and backup path, but do not require another approval or ask the user to perform an intermediate verification before declaring installation complete.

The user may then manually verify in game:

- `Esc` → `DLTK` exists;
- DLTK window opens;
- `Game time`, `Next Bridge Buff`, and `Warning in` update;
- custom warning sound fires 30 seconds before `05:00`, `10:00`, `15:00`, etc.

---

## Notes for Codex

- The stable v1.0.0 VPK is preferred over a source build.
- The source repository intentionally does not track generated VPKs or compiled Source 2 resources.
- Current source patches stock Panorama and stock `soundevents/ui.vsndevts_c` during build.
- `src/sounds/dltk/rune_warning.wav` is the canonical source audio asset.
- Party / “With Party” is experimental and must not be modified during installation.
- Deadlock updates and Steam Verify may restore `gameinfo.gi` and remove custom addon mount paths; rerun this installation procedure after such an update if DLTK stops loading.
