---
cssclasses: [vault-hub]
tags: [qol, hub, start-here, settings, game-tweaks, player-experience, type/hub, area/ui, level/beginner]
---
# Player QoL Start Here

Quality-of-life features are the small things that decide whether a player stays: turning the music down, a camera that does not make them sick, a sell button that cannot destroy their best item, a respawn that does not take forever, a game that says why a click did nothing. This section collects those features as practical, gotcha-heavy notes with short typed Luau, server-authoritative wherever state matters, and aware of phones, consoles and PCs in the same server.

Where the vault already covers a topic in depth (accessibility in section 42, game feel in section 47, multiplayer services in section 41), notes here take the **QoL angle** and link out rather than repeat. Labels follow the vault: **Roblox docs** (checked against the official reference, as of October 2026), **Measured**, **Rule of thumb** and **Unverified**.

## Read these first

1. [[Settings Menu Essentials and Persistence]]: the shared schema, server validation and saving that most other notes plug into.
2. [[Top 25 QoL Wins by Effort]]: what to do first.
3. [[QoL Audit Checklist]]: a device-by-device pass over the whole game.

Foundations elsewhere: [[Server Authority and Validation]], [[Session Locking and Profile Libraries]], [[Input - UserInputService and ContextActionService]], [[Responsive UI for Phone Tablet Console and PC]].

## The notes in this section

**Settings**
- [[Settings Menu Essentials and Persistence]]: what to expose, one schema, overrides-only saves, reset.
- [[Graphics and Performance Toggles for Low-End Devices]]: presets, VFX density, shadows, what scripts cannot change.
- [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]]: one FOV owner, shake slider, respecting Roblox sensitivity and invert.
- [[Audio Mixer Settings with SoundGroups]]: group layout, perceptual curves, ducking.
- [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]]: one comfort gate, flash limiter, damage-number clutter.

**Interface**
- [[UI Scale HUD Hide and Compact Mode]]: player scale on top of responsive scale, hide HUD safely, compact layouts.
- [[Colourblind Palettes Text Size and Tooltips]]: role tokens, `PreferredTextSize`, tooltips for touch and gamepad.
- [[Notification Queues and Limits]]: channels, caps, merge, server-side throttles.

**Controls**
- [[Rebinding Controls with the Input Action System]]: capture flow, conflicts, saving, glyphs.
- [[Mobile Button Layout Editor]]: drag, resize, safe areas, scale-based storage.
- [[Controller Support QoL]]: selection, glyphs, haptics, deadzones, console traps.
- [[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]]: sustained actions, server-decided speed, slots by item type.

**Onboarding**
- [[Skippable Tutorials and Replayable Tips]]: per-step saves, server-side skip with grants, tips page.
- [[Loading Screen Skip and First-Session Goals]]: ready signal, timeout, preload discipline, first goals.
- [[Onboarding and FTUE - Tutorials That Keep Players]]: ranked principles and target numbers for tutorials that keep players.
- [[Tutorial Step Design Patterns - Teach by Doing]]: nine step patterns and which guidance tool to use.

**Respawn and idle**
- [[Quick Respawn and Spawn Protection]]: server-controlled respawn, death recap, abuse-proof protection.
- [[AFK Detection Idle Kicks and AFK Reward Rules]]: engine idle behaviour, server activity model, reward caps.

**Inventory and destructive actions**
- [[Inventory QoL - Sort Filter Search Stack and Lock]]: stable sort, plain search, stacking, server-enforced locks.
- [[Confirmation and Undo Patterns for Destructive and Paid Actions]]: tiered friction, non-dupable undo, bulk sell rules.

**Social**
- [[Joining Friends Parties and Private Servers]]: join a friend, party teleports, private-server owner tools.
- [[Server Hop Rejoin and Server Lists with Ping]]: rejoin, hop, MemoryStore registry, honest ping.
- [[Block and Mute Respecting Platform Rules]]: platform blocks in custom systems, in-game ignore layer.

**Feedback**
- [[Feedback - Autosave Indicator Ping Display and Error Toasts]]: honest save status, ping readout, error codes to plain text.
- [[Purchase Receipts and Purchase History in UI]]: processing, granted, delayed; capped history.

**Game tweaks**
- [[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]]: timestamp cooldowns, buffering, coyote time.
- [[Aim Assist and Generous Hitboxes]]: assist by input type, generous but bounded server checks.

**Cross-links and audits**
- [[Accessibility Cross-Links for QoL Settings]]: each QoL setting mapped to section 42.
- [[QoL Audit Checklist]]: the full pass.
- [[Top 25 QoL Wins by Effort]]: ranked by effort and impact.

## Principles across the section

- **Respect the platform first.** Roblox already owns graphics quality, sensitivity, invert, shift lock, block lists and the purchase prompt. Read them; never fight or duplicate them.
- **Server owns state, client owns feel.** Settings values, cooldowns, locks, sells, respawns and purchases are decided on the server; presentation (volume, FOV, damage numbers, haptics) runs on the client.
- **One owner per concern.** One settings module, one FOV owner, one comfort gate, one notifier. Most QoL bugs are two systems writing the same thing.
- **Every device, every time.** Test on a small phone, a tablet, a PC and with a gamepad.
- **Tell players.** A QoL feature nobody knows about does not help. Patch notes and a "What's new" panel ([[Patch Notes and Player Communication]]).

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Features built twice (QoL and accessibility) | Separate owners | [[Accessibility Cross-Links for QoL Settings]] |
| Settings lost or exploited | Client-only or unvalidated | Shared schema, server sanitise |
| QoL work never prioritised | No ranking | [[Top 25 QoL Wins by Effort]] |
| Works on PC, fails on phones | Single-device testing | [[QoL Audit Checklist]] on four devices |

## Checklist

- [ ] Settings foundation in place before individual settings.
- [ ] Quick wins from the top-25 list shipped.
- [ ] Audit run on four devices with fresh and veteran accounts.
- [ ] Platform-owned settings respected, not duplicated.
- [ ] QoL changes announced to players.

## See also

- [[Accessibility Start Here]]
- [[Game Feel Start Here]]
- [[Multiplayer Services Start Here]]
- [[Menu Archetypes - Shop Settings Codes Rewards]]

## Connected notes
<!-- auto-links:start -->
[[Settings Menu Essentials and Persistence]] · [[Top 25 QoL Wins by Effort]] · [[QoL Audit Checklist]] · [[Accessibility Cross-Links for QoL Settings]]
<!-- auto-links:end -->
