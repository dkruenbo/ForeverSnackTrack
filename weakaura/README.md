# Forever SnackTrack WeakAura

Scans your bags for XP food and reminds you when its kill-XP buff is missing or weaker than the food you have. Made for ForeverAuras on WoW Forever, interface `16001`.

## Import

1. Open [weak-aura-string.txt](weak-aura-string.txt) and select the complete `!WA:1!` string.
2. Paste it into the ForeverAuras import dialog and review the custom Lua before importing.
3. Adjust reminders in Custom Options and position the text using ForeverAuras' own controls.

The published version is also available on [Wago](https://wago.io/GqIa5R4w7). The repository may contain unreleased changes not yet published there.

Re-import the latest string to apply updates. Its UID is preserved for update matching. Avoid running it alongside the [standalone addon](../addon/README.md), or you may receive duplicate reminders.

## Behavior And Options

- Chat and screen reminders, with a one-minute repeat interval and unlimited alert duration by default.
- Optional restock reminders, suppressed while an XP buff is active.
- Suppresses reminders at level 60, the level cap.
- No reminders during combat; **Remind while resting** is off by default.
- Custom reminder text, duration, size, color, and tooltip-matching keywords.
- Frame-triggered scans are limited to once per second; bag and aura events scan immediately.
- Saved positioning is managed by ForeverAuras, not forced by custom text.

The import does not include the addon's snooze/dismiss buttons. Tooltip matching defaults to English keywords; other languages require suitable Custom Options and real-client verification. Supported XP percentages are positive integers, not decimals.

## Tests

Run `sh weakaura/tests/run-weak-aura.sh` from the repository root, or `sh tests/run-weak-aura.sh` from this folder. Python 3 and Lua are required.

The runner decodes the checked-in string and tests its Lua without modifying the import. Client compatibility and actual import/update behavior still need in-game testing.

## Changelog And License

See [WA-changelog.md](WA-changelog.md) for WeakAura changes and [LICENSE](../LICENSE) for the shared MIT license.