# Forever SnackTrack: Agent Guide

## Purpose And Client

Forever SnackTrack reminds players to use the best kill-XP food in their bags when their active XP buff is missing or weaker. This repository contains two independent implementations: a standalone addon and a ForeverAuras import.

- Target WoW Forever, interface `16001`, not arbitrary Retail or Classic versions. Retail-style API names do not guarantee identical client behavior.
- Product name: **Forever SnackTrack**. Addon folder/TOC basename: `ForeverSnackTrack`. Repository: `dkruenbo/ForeverSnackTrack`.
- Keep Lua compatible with the game client. Local Lua compilation is not proof of client compatibility; avoid newer Lua syntax and dependencies that require installation in WoW.
- This root `AGENTS.md` provides project-wide guidance for both implementations.

## Ownership And Layout

- Root: shared [README](README.md), [license](LICENSE), repository settings, and this guide.
- `addon/`: runtime Lua, TOC, ZIP, addon documentation, and regression tests.
- `weakaura/`: the single current import, its changelog, and its regression tests.
- Implementation-specific instructions are in [addon/README.md](addon/README.md) and [weakaura/README.md](weakaura/README.md).
- Addon fixes belong in [addon/docs/Changelog.md](addon/docs/Changelog.md); do not mention WeakAura changes there.
- WeakAura fixes belong in [weakaura/WA-changelog.md](weakaura/WA-changelog.md). Editing addon Lua does not update the encoded import, or vice versa.
- In each changelog's current Unreleased section and future patch entries, group notes under `### Player-facing` followed by `### Technical`. Describe user-visible effects first, keep implementation detail concise, and omit either heading when it has no entries. Leave historical release sections unchanged unless asked.
- Do not create multiple competing import strings or leave old release archives around without a reason.

## Addon Architecture

The TOC loads `Locale.lua`, `ScreenAlert.lua`, `Core.lua`, then `Options.lua`. Modules share the private namespace supplied through `local addonName, ns = ...`.

- [Core.lua](addon/Core.lua): settings initialization, tooltip matching/caches, scans, reminder state, event handling, and `/fst debug` diagnostics.
- [ScreenAlert.lua](addon/ScreenAlert.lua): alert frame, appearance, dragging, preview, timeout, snooze/dismiss buttons.
- [Options.lua](addon/Options.lua): settings panel and `/snacktrack` / `/fst` commands. Closing options checks reminders again.
- [Locale.lua](addon/Locale.lua): interface strings and tooltip-matching terms. English fallback exists; other locales need real-client verification.
- Follow the existing tab-indented Lua style. Avoid broad refactors while fixing a narrow behavior.

## Detection Invariants

- Read the percentage from tooltip wording about increased experience from kills. **5% is an example, not a constant.** Current supported bonuses are positive integers.
- Bag candidates must be consumable food/drink: class ID `0`, subclass ID `5`, using `C_Item.GetItemInfoInstant` or the global fallback. Verify classifications against Forever before broadening or narrowing the filter.
- Do not identify food using tooltip text alone; equipment and other XP items can contain similar wording.
- An active bonus equal to or stronger than the best available food suppresses the food reminder.
- Restock reminders are optional and must be suppressed while any qualifying XP buff is active, even after the last food is consumed.
- Keep unknown data distinct from a definitive negative. Missing APIs/classification, empty tooltips, loading placeholders, and title-only tooltips can be unresolved.
- Recognize the client's `RETRIEVING_ITEM_INFO` value rather than hard-coding an English loading message.
- Never turn unresolved data into "no food" merely because a retry count elapsed. Bound retry work without inventing a negative result.
- Do not cache incomplete tooltips as definitive negatives. Bag/item-data events retry food checks; `UNIT_AURA` invalidates cached buff values.
- The addon currently refreshes tooltip caches every 60 seconds. Do not remove that safeguard without a tested replacement for context-dependent values and partial loading.
- Do not take the first percentage blindly. Test mixed health/XP percentages and decimal suffixes; `2.5%` must not become `5%`.
- Addon and WeakAura matching algorithms are not identical. A parser test passing for one does not validate the other.

## Reminder And Position Invariants

- Defaults: chat and screen enabled, repeat every minute, unlimited real alert, restock reminders off, **Remind while resting off**. New installations do not open options or require setup.
- Suppress real reminders during combat and, by default, while `IsResting()` is true. Check again on combat/resting transitions.
- While dead, hide the on-screen reminder without suppressing chat; check again on `PLAYER_ALIVE` or `PLAYER_UNGHOST` in both implementations.
- Chat delivery is rate-limited; screen visibility is separate state. Restoring a hidden eligible alert must not resend chat or reset its repeat timer.
- Repeat disabled means no extra chat for the same condition merely because combat or resting ended.
- Restoring an alert must respect snooze, dismissal, current condition, enabled channels, and finite expiry. Do not re-show an expired finite alert on every scan.
- A real alert duration of `0` means unlimited. An unlimited-duration preview is still timed.
- Do not overwrite a positioning preview with a real alert during ordinary scans. Closing preview should restore an eligible real alert.
- Snooze pauses both channels; dismissal applies to the current reminder condition until it changes or resolves.
- Save addon offsets in UIParent coordinates. Convert using `frame:GetEffectiveScale() / UIParent:GetEffectiveScale()` when anchoring and dragging; re-anchor after scale changes.

## Saved Preferences And Renaming

- Current global: `ForeverSnackTrackDB`. `ForeverExpFoodDB` is intentional legacy compatibility, not a stale identifier to delete.
- Existing new settings take precedence over legacy settings; defaults fill missing/invalid fields without resetting valid user preferences.
- WoW saved-variable loading depends on the addon filename. A rename cannot automatically discover an unloaded old saved-variable file.
- Keep the documented one-time transfer in [addon/README.md](addon/README.md) and prevent users from running both old and new addon folders together.

## WeakAura Import Rules

- [weakaura/weak-aura-string.txt](weakaura/weak-aura-string.txt) is the canonical artifact. It uses `!WA:1!`, AceSerializer-3.0, raw DEFLATE, and the printable alphabet `abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789()`.
- Parse and regenerate the encoded structure; never search-and-replace arbitrary compressed characters. Round-trip the generated string and compile/test the decoded Lua.
- AceSerializer `^S` is a string marker: `^SkillTerms` encodes `killTerms`, **not** `SkillTerms`. Do not infer keys by eyeballing marker boundaries.
- Preserve the existing UID, author metadata (`_lektor`), custom-option keys, configuration, and import envelope unless a change explicitly requires migration.
- Custom triggers must exit on `OPTIONS` before sending chat or scanning. Slider editing previously caused chat spam.
- `FRAME_UPDATE` is dispatched every frame by ForeverAuras. Full scans are throttled to once per second; bag/aura events bypass that throttle. Suppression checks must remain ahead of it.
- Frame-throttled returns must still respect alert expiry and avoid reviving alerts after unresolved data or resolved conditions.
- Do not force `ClearAllPoints`/`SetPoint` from custom text. That overwrites positions restored by ForeverAuras after reload.
- There are no snooze/dismiss controls in the current import. Do not describe addon-only buttons as WeakAura features.

## Validation

Run from the repository root:

```sh
lua addon/tests/addon.lua
sh weakaura/tests/run-weak-aura.sh
git diff --check
```

The WeakAura runner needs Python 3 and Lua; it decodes the checked-in import and runs its Lua tests without changing the import. Addon tests use mocked WoW APIs and also run from inside `addon/` with `lua tests/addon.lua`.

Required regression scenarios: preview open/close and screen toggles with repeats on/off; combat/resting/death transitions without unintended chat changes; snooze/dismiss across transitions; finite expiry; dragging at 75%, 100%, and 150% then changing scale; title-only and multi-line partial tooltips followed by loaded XP descriptions; short complete food/buff descriptions; preservation of known XP-food actions when another item is unresolved; negative food-cache invalidation through `GET_ITEM_INFO_RECEIVED`; cached buff invalidation on `UNIT_AURA`; coalesced aura bursts followed by a later event; a sufficient XP buff alongside an unresolved aura; active buff after consuming the last food; non-food XP items; mixed percentages; and WeakAura throttling/saved positioning.

Passing mocks does not certify Forever API availability, food classifications, localized tooltip wording, frame layout, or import/update behavior. Report in-game validation separately. Use `/fst debug` with real food/buff tooltips when investigating detection failures.

## Release And Collaboration

- [addon/ForeverSnackTrack.toc](addon/ForeverSnackTrack.toc) is the version source; currently `1.0.4`. Keep the release version and addon changelog consistent. Keep unreleased changes marked unreleased until actually released.
- After runtime/TOC changes, rebuild the addon ZIP and name it `ForeverSnackTrack-<version>.zip` using the TOC version; update documented download links to match. Archive entries must be `ForeverSnackTrack/` plus the TOC and four runtime Lua files, not an `addon/` folder.
- Exclude `.DS_Store`, `__MACOSX`, tests, planning docs, WeakAura files, and repository settings. Verify archive integrity and byte-for-byte source parity.
- Prefer explicit archive file lists over recursively zipping the workspace. Source files are authoritative; do not edit only the ZIP.
- Preserve existing user edits and keep addon/WeakAura changes scoped. Do not commit, push, tag, rename repositories, or publish releases unless requested.
- All requested commits and pushes must use a feature branch and a pull request targeting `main`. Never commit or push directly to `main`, bypass its protection, or merge a pull request without an explicit request.
- After confirming a branch has merged into `main` on GitHub, switch to local `main`, fast-forward it, and delete the merged local branch. Preserve uncommitted work, and never delete a branch that has not been confirmed merged.
- Public descriptions should be short, plain, and factual, without sales fluff or claims of unverified client support. See [addon/docs/CURSEFORGE-DESCRIPTION.md](addon/docs/CURSEFORGE-DESCRIPTION.md).