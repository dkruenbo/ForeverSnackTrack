# WeakAura Changelog

## Unreleased

- Suppress reminders at level 60, the level cap; no separate XP-lock detection is added.

## 2026-10-11

- Limit frame-triggered scans to once per second; bag and aura events still scan immediately.
- Suppress restock reminders while an XP buff is active.
- Associate percentages with experience and kill wording instead of taking the first percentage on a line. Ignore decimal fractions rather than misreading them as whole percentages; supported bonuses remain integers.
- Treat empty, loading, and title-only tooltip data as unresolved rather than proof that XP food or its buff is missing.
- Restrict bag detection to food-and-drink items; unresolved item classification does not trigger restock reminders.
- Preserve the saved alert position when the region is recreated or the UI is reloaded by removing forced re-anchoring from custom text.
- Preserve chat timing across combat and resting transitions, while keeping unlimited alerts visible on return and retaining finite alert expiry.
- Keep the existing UID, configuration, custom options, and author metadata.

## Initial Release

- Scan bags for XP food and show reminders when its buff is missing or weaker.
- Provide configurable chat and screen reminders, with optional restock reminders.
- Default to a one-minute repeat interval and unlimited screen-alert duration.
- Suppress reminders during combat and, by default, in resting areas.