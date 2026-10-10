# ForeverExpFood

A lightweight World of Warcraft Forever addon that helps you maintain the kill-experience bonus from qualifying food. It reads the percentage from the tooltip; 5% is the current example, not a hard-coded limit.

## Features

- Scans carried bags for food whose tooltip grants additional experience from kills and extracts its percentage.
- Compares food bonuses with the active `Well Fed` XP buff; an equal or stronger buff suppresses reminders.
- Sends configurable chat and screen reminders when the active buff is weaker than the best food bonus.
- Optionally reminds you when no qualifying food is in your bags.
- Provides a movable screen alert with custom text, duration, size, and color.
- Uses a 1-minute repeat interval and unlimited screen-alert duration by default on new installations.
- Starts with default preferences without opening options; closing options checks reminders again.
- Supports snoozing reminders or dismissing the current reminder condition.
- Suppresses reminders during combat and checks again when combat ends.
- Suppresses reminders in resting areas by default; enable **Remind while resting** to override. Checks again immediately when leaving a resting area.
- Includes localized interface text and tooltip matching for standard WoW locales.

## Install

1. Download `ForeverExpFood.zip` from the repository and extract its `ForeverExpFood` folder into `World of Warcraft\_retail_\Interface\AddOns\`.
2. Enable **ForeverExpFood** in the AddOns list and log in.
3. Reminders work immediately with default preferences. To customize them, open the in-game options with `/foreverexpfood` or `/fef`. New installations repeat reminders every minute and keep screen alerts visible until snoozed, dismissed, suppressed by combat or resting, or no longer needed. Choose a finite alert duration in the options if preferred.
4. Run `/fef debug` to print recognized XP food, active XP buffs, and relevant tooltip candidates to chat.

The addon targets interface `16001`. The game client must provide the Retail APIs used by the addon.

## Troubleshooting

If XP food is in your bags but no reminder appears, open `/fef` and check that at least one alert is enabled. Reminders are suppressed during combat, in resting areas by default, while snoozed, or after dismissing the current reminder condition.

The [WeakAura import](weak-aura-string.txt) also has a **Remind while resting** toggle in Custom Options, disabled by default. Re-import it to receive this option.

Run `/fef debug` out of combat to inspect reminder settings, recognized food and buffs, and unavailable tooltip data. If your food is not recognized, include the debug output, food name, full tooltip text, and game language in a bug report.

## License

MIT. See [LICENSE](LICENSE).
