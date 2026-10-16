# Changelog

## 1.0.4 - 2026-10-16

### Player-facing

- Hide the on-screen reminder while dead and restore it after resurrection without suppressing chat reminders.
- Keep the Eat action available for recognized XP food when another item's tooltip is unresolved.

### Technical

- Parse stats only for XP food, reuse available-food results, and coalesce aura-triggered scans while still invalidating buff caches.
- Cache negative food and buff results only when their item-use or spell descriptions confirm tooltip completeness; otherwise retry. Recognize Forever's literal `Use:` marker.
- Let a known sufficient XP buff resolve the comparison even if another aura tooltip is unresolved.
- Report unresolved buff tooltips in diagnostics, fall back to English for missing locale keys, and guard optional dropdown helpers.

## 1.0.3 - 2026-10-14

- Suppress reminders at level 60, the level cap; players with XP locked can disable the addon.
- Show recognized stat bonuses, such as attack power, spell damage, healing, armor, crit, movement speed, and professions, in the food dropdown.

## 1.0.2 - 2026-10-13

- Add a secure Eat action for the strongest available XP food, with a dropdown to select another qualifying food before clicking Eat.

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