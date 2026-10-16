Lightweight World of Warcraft Forever addon using the Retail API, targeting the new beta client.

The addon helps players maximize XP from kills by tracking food that grants an experience bonus. It reads the percentage from the localized tooltip; 5% is the current example, not a hard-coded limit. It compares the best bonus available in bags with the active XP food buff and reminds the player when the buff is weaker or missing.

## Features

- Scans the player's bags in the background once per minute.
- Suppresses reminders during combat, hides a visible alert when combat begins, and checks again when combat ends.
- Suppresses chat and screen reminders in resting areas by default, hides an existing alert on entry, and checks again on exit. An opt-in **Remind while resting** setting is available in the addon and WeakAura.
- Hides the on-screen reminder while the player is dead and checks again after resurrection; chat reminders remain unaffected.
- Detects qualifying food by its localized tooltip line describing increased experience from kills and extracts its integer percentage. Mithril Head Trout's current 5% effect is one example.
- Requires food-and-drink item classification; unavailable classification, loading placeholders, and title-only food tooltips remain unresolved.
- If a tooltip line has multiple percentages, selects the one most closely associated with its experience-increase wording.
- Detects the percentage from the matching "Well fed" XP buff; a buff equal to or stronger than the best food bonus suppresses the reminder.
- Starts reminders with default preferences without opening options or requiring setup; players can customize preferences in the in-game options panel, and closing it triggers a scan.
- Provides `/fst debug` to report recognized XP food, active XP buffs, and relevant tooltip candidate lines.
- Supports chat and screen alerts, each independently toggleable.
- Lets players customize whether and how often reminders repeat.
- Offers an opt-in reminder when no qualifying XP food is in the player's bags and the XP buff is inactive; this option is off by default.
- Lets players customize the screen alert text, display duration, text color, and size.
- Offers 1-20 second screen-alert durations and an Unlimited choice at the rightmost slider position; unlimited alerts have no timeout, while previews remain timed.
- Lets players preview and move the screen alert, with its position saved between sessions and a reset option.
- Stores alert offsets in UIParent coordinates so dragging and changing scale do not move the saved screen position.
- Tracks screen visibility separately from reminder delivery: eligible hidden alerts restore without resetting chat timing, active previews are preserved, and finite alerts retain their original expiry.
- Provides a snooze button on screen alerts; snooze duration is configurable (1, 5, 10, 15, 30, or 60 minutes) and defaults to 1 minute.
- Snoozing pauses both chat and screen reminders; alerts resume on the first scan after the selected duration if the condition remains.
- Provides a dismiss button that suppresses the current reminder condition until it changes or resolves, without muting later conditions.

## Usage

- Install the addon in the World of Warcraft Forever addons folder and enable it in-game.
- Use default reminder preferences or adjust them in the options panel with `/fst`.
- Optionally enable reminders to restock XP food when none is available in bags.
- Use the options panel to customize, preview, and reposition the screen alert.
- Run `/fst debug` to inspect food and buff detection during testing.
- Snooze a reminder temporarily or dismiss the current reminder condition from the screen alert.
- The addon automatically checks bags once per minute and reminds the player when qualifying food is available and the active XP buff is weaker than the best available food bonus.
