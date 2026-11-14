# Prioritized Ideas

## 1.0.10 - Estimate and Selection Polish

- Format estimated durations compactly, omitting zero units (for example, `15m`, `1h 15m`, or `2h`).
- Keep serving count and estimated time primary, with Gourmand rank or fallback details secondary and consistent across the popup, icon tooltip, and options.
- Show a compact comparison of the active buff with the carried food's 5% bonus, including remaining buff time when known. Reuse values from existing reminder scans; add no ticker, per-frame scan, or hover-triggered inventory scan.
- Persist the selected food per character only if retaining a stat-bonus preference proves useful; if unavailable, fall back to a recognized food from the normal cached bag scan.

## 1.0.11 - Low-Stock Reminder

- Extend the existing optional restock reminder with a per-character low-stock threshold measured in qualifying servings; default it to disabled so current behavior is unchanged.
- Notify when known stock falls to or below the threshold, avoid repeating for the same low-stock state, and re-arm after stock rises above it.
- Suppress the reminder while any qualifying XP buff is active. Reuse existing bag/item-data scans and caches; keep unresolved food data distinct from a confirmed low count and add no polling.

## 1.0.12 - Cozy Sleeping Bag Buff Tracking

- Add opt-in, disabled-by-default tracking for the Cozy Sleeping Bag's Well Rested buff, separate from food-coverage logic. Whenever the buff is below 3/3 and the bag's 1-hour cooldown is ready, remind the player to build or restore all 3 stacks; at 3/3, remind 10 minutes before the 2-hour buff expires only if the bag is ready. Follow XP-food reminder visibility rules: hide during combat, flight, and death, then restore when eligible.
- Use the selected popup or icon mode for the sleeping-bag reminder. Show the stack timeline as its own compact horizontal HUD, like a flight-time bar, not embedded in the reminder: mark the three stack milestones and show current progress and a countdown to the next stack. Start the own-bag session from the verified unroll cast and nearby resting transition; for party bags, use stack growth or `/fst bag` before the first aura stack appears. End the session on movement so resting in cities/inns alone does not display the HUD. On starting or resuming rest, read current aura stacks and estimate time to 3/3: 0/3 takes 3 minutes, 1/3 takes 2, 2/3 takes 1, and refreshing at 3/3 takes 1 minute. Suppress the timeline during combat, flight, and death as well.
- Verify `IsResting()` and stack timing while using a party member's bag, and confirm timeline placement/visibility in Forever.

## 1.0.13 - Sleeping Bag Logout Reminder

- During the 20-second logout countdown outside a resting area, show a choice popup when the Cozy Sleeping Bag is ready: **Use Bag & Stay** cancels logout and uses the bag; **Log Out Anyway** leaves the countdown untouched. Do not block or delay logout while waiting for a choice.
- Listen for `PLAYER_CAMPING` to catch the start of the 20-second countdown, and use `IsResting()` to skip the prompt in inns and cities. Verify that both behave as expected on Forever, along with supported logout-cancel/item-use actions and bag cooldown/readiness APIs.

## 1.0.14 - Optional Camping Nudge

- Add a separate per-character, disabled-by-default **Camping nudge** option. Enable its control only when **Track Cozy Sleeping Bag Well-Rested buff** is enabled; append “While you're at it, you might want to set up camp?” to the 10-minute Well-Rested expiry warning during play. Camping provides another 2-hour buff, so this is an in-play refresh suggestion, not a logout reminder or separate alert.
- Show a clear disclaimer beside the option: this is only a reminder and does not detect or track the camping buff or check camping availability.
