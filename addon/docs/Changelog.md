# Changelog

## 1.0.1 - 2026-10-11

- Restore the current screen alert after re-enabling screen reminders or closing a preview, even when repeat reminders are disabled.
- Preserve finite alert expiry and avoid interrupting an active positioning preview.
- Restore alerts after combat or resting without sending extra chat reminders when repeats are disabled.
- Correct saved alert positions when dragging at a non-default scale, and keep the position stable when changing scale.
- Restrict bag detection to food and drink so equipment and other XP items do not trigger food reminders.
- Retry loading and title-only food and buff tooltips instead of caching them as definitive non-XP results.
- Refresh cached buff values when player auras change.
- Apply the same food classification and tooltip handling to diagnostic scans.
- Update the addon version to 1.0.1.

## 1.0.0 - Initial Release

- Scan bags for XP food and compare its bonus with the active buff.
- Provide configurable chat reminders and a movable screen alert.
- Support custom alert text, color, size, duration, and repeat interval.
- Allow snoozing or dismissing reminders, with optional restock reminders.
- Suppress reminders during combat and, by default, in resting areas.
- Include localized interface text and tooltip matching.