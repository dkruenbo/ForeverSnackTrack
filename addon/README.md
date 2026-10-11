# Forever SnackTrack

A lightweight World of Warcraft Forever addon that helps you maintain the kill-experience bonus from qualifying food. It reads the percentage from the tooltip; 5% is the current example, not a hard-coded limit.

## Features

- Scans carried bags for items classified as food and drink whose tooltip grants additional experience from kills and extracts its percentage.
- Compares food bonuses with the active `Well Fed` XP buff; an equal or stronger buff suppresses reminders.
- Sends configurable chat and screen reminders when the active buff is weaker than the best food bonus.
- Optionally reminds you when no qualifying food is in your bags.
- Provides a movable screen alert with custom text, duration, size, and color.
- Uses a 1-minute repeat interval and unlimited screen-alert duration by default on new installations.
- Starts with default preferences without opening options; closing options checks reminders again.
- Supports snoozing reminders or dismissing the current reminder condition.
- Suppresses reminders during combat and checks again when combat ends.
- Suppresses reminders in resting areas by default; enable **Remind while resting** to override. Checks again immediately when leaving a resting area.
- Restores eligible screen alerts without sending extra chat messages; finite alerts keep their original expiry.
- Includes localized interface text and tooltip matching for standard WoW locales.

## Install

1. Download [ForeverSnackTrack.zip](ForeverSnackTrack.zip) and extract its `ForeverSnackTrack` folder into `World of Warcraft\_retail_\Interface\AddOns\`.
2. Enable **Forever SnackTrack** in the AddOns list and log in.
3. Reminders work immediately with default preferences. To customize them, open the in-game options with `/snacktrack` or `/fst`. New installations repeat reminders every minute and keep screen alerts visible until snoozed, dismissed, suppressed by combat or resting, or no longer needed. Choose a finite alert duration in the options if preferred.
4. Run `/fst debug` to print recognized XP food, active XP buffs, and relevant tooltip candidates to chat.

The addon targets interface `16001`. The game client must provide the Retail APIs used by the addon, including item classification through `C_Item.GetItemInfoInstant` or `GetItemInfoInstant`. Missing classification or loading tooltip data is treated as unresolved rather than as proof that no XP food exists.

## Upgrading From ForeverExpFood

Exit the game before upgrading. To keep existing preferences, copy `ForeverExpFood.lua` to `ForeverSnackTrack.lua` in each account's `WTF/Account/<account>/SavedVariables/` folder. The renamed addon imports the old settings when no new settings exist. Keep a backup of the original file.

Remove the old `Interface/AddOns/ForeverExpFood` folder after installing `ForeverSnackTrack` so both versions do not run together. The new options commands are `/snacktrack` and `/fst`.

## Troubleshooting

If XP food is in your bags but no reminder appears, open `/fst` and check that at least one alert is enabled. Reminders are suppressed during combat, in resting areas by default, while snoozed, or after dismissing the current reminder condition.

Prefer a WeakAura? See the [WeakAura README](../weakaura/README.md) for its import and options.

Run `/fst debug` out of combat to inspect reminder settings, recognized food and buffs, and unavailable tooltip data. If your food is not recognized, include the debug output, food name, full tooltip text, and game language in a bug report.

## License

MIT. See [LICENSE](../LICENSE).

## Tests

Run `lua addon/tests/addon.lua` from the repository root for mocked reminder-state, tooltip, item-classification, and scaled-position regression checks. Client API behavior and localized tooltips still require in-game testing.

From inside `addon/`, run `lua tests/addon.lua` instead.

## Documentation

- [Changelog](docs/Changelog.md)
- [CurseForge description](docs/CURSEFORGE-DESCRIPTION.md)
- [Specification](docs/spec.md)
- [Implementation plan](implementation-plan.md)
- [Roadmap](docs/ROADMAP.md)
