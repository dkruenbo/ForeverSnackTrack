# Prioritized Ideas

## 1.0.15 - Snooze Duration Picker

- Choose a one-time snooze duration for either XP-food or Sleeping Bag reminders without changing the configured default duration.
- Keep the existing Snooze button immediate and apply its configured default; expose longer choices from a popup picker and the icon-mode right-click menu.

## 1.0.16 - Sleeping Bag Logout Reminder

- During the 20-second logout countdown outside a resting area, show a choice popup when the Cozy Sleeping Bag is ready: **Use Bag & Stay** cancels logout and uses the bag; **Log Out Anyway** leaves the countdown untouched. Do not block or delay logout while waiting for a choice.
- Listen for `PLAYER_CAMPING` to catch the start of the 20-second countdown, and use `IsResting()` to skip the prompt in inns and cities. Verify that both behave as expected on Forever, along with supported logout-cancel/item-use actions and bag cooldown/readiness APIs.

## 1.0.17 - Optional Camping Nudge

- Add a separate per-character, disabled-by-default **Camping nudge** option. Enable its control only when **Track Cozy Sleeping Bag Well-Rested buff** is enabled; append “While you're at it, you might want to set up camp?” to the 10-minute Well-Rested expiry warning during play. Camping provides another 2-hour buff, so this is an in-play refresh suggestion, not a logout reminder or separate alert.
- Show a clear disclaimer beside the option: this is only a reminder and does not detect or track the camping buff or check camping availability.
