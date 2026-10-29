---
tags: [qol, audit, checklist, qa, review, release, playtest, type/checklist, area/production, level/beginner]
---
# QoL Audit Checklist

<!-- tldr:start -->
> [!tldr] TL;DR
> - Audit passes, players still complain: Only tested on PC -> Four devices minimum
> - Onboarding fine in tests: Testers are veterans -> Fresh account every audit
> - Social bugs missed: Single account -> Second account for section 10
> - Four devices, fresh and veteran accounts, recorded.
> - Every section marked; fails ticketed with device and steps.
> - Fix order: progress/money, arrival, primary-platform controls, rest.
>
> Cost: TL;DR ~150 tok · whole note ~2.0k tok. Read more: ## 3. Settings · ## 4. Controls · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A pass you run before a launch, a big update, or when retention looks soft and nobody knows why. It is organised by what a player experiences, in the order they experience it, and every line links to the note with the fix. Run it on **four devices** (small phone, tablet, PC, console or a gamepad on PC) with a **fresh account** and a **veteran save**. Release QA in general is in [[QA Checklists Before Release]]; this is the QoL slice.

Sources: every item is backed by the linked note; the checklist itself is **Rule of thumb** distilled from shipped games and public guidelines (Game Accessibility Guidelines https://gameaccessibilityguidelines.com/, Xbox Accessibility Guidelines https://learn.microsoft.com/en-us/gaming/accessibility/guidelines).

## How to run it

1. Record the session on each device (screen + voice notes). Problems you notice once are easy to forget.
2. Mark each line **Pass**, **Fail** or **N/A**. A "Fail" gets a ticket with device and steps.
3. Time the first three checks with a stopwatch.
4. Repeat the social section with a second account.
5. Re-run failed lines after fixes; do not trust "fixed" without a repeat.

## 1. Arrival (first 60 seconds)

- [ ] Time from join to controllable character measured on a low-end phone. Loading screen closes on a ready signal, with a timeout. [[Loading Screen Skip and First-Session Goals]]
- [ ] Skip appears within a few seconds; returning accounts skip immediately.
- [ ] At most one modal in the first minute; none for new players before their first goal.
- [ ] Settings reachable from the first second, including during the tutorial. [[Accessibility Cross-Links for QoL Settings]]
- [ ] First-session goals visible and server-tracked.

## 2. Onboarding

- [ ] Tutorial skippable; skip grants everything completing would. [[Skippable Tutorials and Replayable Tips]]
- [ ] Controls not locked longer than needed; prompts show the right glyph for the device.
- [ ] Tips can be replayed from a menu; tip frequency setting exists.

## 3. Settings

- [ ] Audio: Master, Music, SFX, UI sliders; mute-music toggle; every sound routed through a group. [[Audio Mixer Settings with SoundGroups]]
- [ ] Graphics: Auto/Low/Medium/High; VFX density reduces real particle counts; gameplay telegraphs stay visible on Low. [[Graphics and Performance Toggles for Low-End Devices]]
- [ ] Camera: FOV slider holds through sprint and zoom; shake 0-100%; custom cameras respect Roblox sensitivity and invert. [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]]
- [ ] Comfort: flashes, damage numbers, hit-stop, reduced motion following the platform. [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]]
- [ ] Interface: UI scale, hide HUD with restore path, compact mode, palette, text size, tooltips. [[UI Scale HUD Hide and Compact Mode]], [[Colourblind Palettes Text Size and Tooltips]]
- [ ] Settings survive rejoin and a device switch (device-specific ones bucketed). [[Settings Menu Essentials and Persistence]]
- [ ] Per-section reset works; reset-all confirms.
- [ ] Settings menu works with gamepad, at max UI scale and at largest text.

## 4. Controls

- [ ] Rebinding on PC and controller; reserved keys rejected; conflicts swap; glyphs update everywhere. [[Rebinding Controls with the Input Action System]]
- [ ] Touch layout editor: drag, resize, save, reset, left-handed mirror; no overlap after device change. [[Mobile Button Layout Editor]]
- [ ] Every menu selects on open; B closes; vibration setting exists. [[Controller Support QoL]]
- [ ] Hold/Toggle for sustained actions; toggles clear on death and menus. [[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]]
- [ ] Auto-equip and quick slots work after respawn.

## 5. Moment-to-moment feel

- [ ] Cooldowns visible on buttons, predicted instantly, server-gated. [[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]]
- [ ] Early presses buffered; ledge jumps forgiving.
- [ ] Touch and controller players can hit targets; assist off for mouse; nothing through walls. [[Aim Assist and Generous Hitboxes]]
- [ ] Getting hit feels fair (incoming hurtboxes accurate).

## 6. Death and idle

- [ ] Respawn delay suits the genre; "respawn now" after a minimum; death recap. [[Quick Respawn and Spawn Protection]]
- [ ] Spawn protection visible, server-side, ends on attack.
- [ ] Idle warning before any game-side kick; private servers exempt; AFK rewards capped. [[AFK Detection Idle Kicks and AFK Reward Rules]]

## 7. Inventory and economy actions

- [ ] Sort, filter, plain-text search; scroll position kept. [[Inventory QoL - Sort Filter Search Stack and Lock]]
- [ ] Locks enforced on the server in sell, trade, fuse and delete.
- [ ] Bulk sell previews, excludes locked/equipped/rares, has an undo window that cannot dupe. [[Confirmation and Undo Patterns for Destructive and Paid Actions]]
- [ ] Irreversible actions need a deliberate gesture; no extra confirm before Roblox purchase prompts.

## 8. Purchases

- [ ] Processing → granted → delayed states; receipt shows what and where. [[Purchase Receipts and Purchase History in UI]]
- [ ] Purchase history with ids and a help path.
- [ ] Kill the server mid-purchase in a test place: the item still arrives on rejoin.

## 9. Feedback and errors

- [ ] Save indicator reflects server results; premium actions frozen on save failure. [[Feedback - Autosave Indicator Ping Display and Error Toasts]]
- [ ] Ping display available; server load visible.
- [ ] Every rejected action shows a plain reason and next step.
- [ ] Notification queue capped; critical messages sticky; no stale toasts. [[Notification Queues and Limits]]

## 10. Social

- [ ] Join a friend from in game; failures explained. [[Joining Friends Parties and Private Servers]]
- [ ] Parties teleport together and back.
- [ ] Rejoin same server and hop to a new one; data not locked on arrival. [[Server Hop Rejoin and Server Lists with Ping]]
- [ ] Blocked players cannot send trades, invites or duels in either direction; Roblox block prompt reachable. [[Block and Mute Respecting Platform Rules]]

## 11. Performance under real conditions

- [ ] Full server on a low-end phone: frame time acceptable with Low preset. [[Mobile and Low-End Optimization]]
- [ ] Busy fight: damage numbers capped and merged; VFX density respected.
- [ ] Ping 250 ms+ (use a throttled connection): actions still feel responsive with prediction.

## Scoring

Count fails per section. Fix in this order (**Rule of thumb**): anything that loses progress or money (sections 7-9) → arrival (1) → controls on the platform most of your players use (4) → the rest. The effort-ranked list in [[Top 25 QoL Wins by Effort]] helps pick quick wins.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Audit passes, players still complain | Only tested on PC | Four devices minimum |
| Onboarding fine in tests | Testers are veterans | Fresh account every audit |
| Social bugs missed | Single account | Second account for section 10 |
| "Fixed" items regress | No re-test | Re-run failed lines |

## Checklist

- [ ] Four devices, fresh and veteran accounts, recorded.
- [ ] Every section marked; fails ticketed with device and steps.
- [ ] Fix order: progress/money, arrival, primary-platform controls, rest.
- [ ] Re-run after fixes.

## See also

- [[QA Checklists Before Release]]
- [[Testing Strategies and Frameworks]]
- [[Top 25 QoL Wins by Effort]]
- [[Player QoL Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Top 25 QoL Wins by Effort]] · [[Accessibility Cross-Links for QoL Settings]] · [[QA Checklists Before Release]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Genre QA Passes - Test Checklists per Game Type]] · [[Console and VR Release Checklists]] · [[Multi-Client and Device Playtesting Protocols]] · [[Menu Archetypes - Shop Settings Codes Rewards]] · [[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]] · [[Shift-Lock Sprint and Gamepad B for Menus]]
<!-- related:end -->
