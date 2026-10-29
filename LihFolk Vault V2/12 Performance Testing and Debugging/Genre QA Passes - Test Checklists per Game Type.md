---
tags: [testing, qa, genres, checklist, release, type/checklist, area/testing, level/intermediate, area/performance, area/scripting]
---
# Genre QA Passes - Test Checklists per Game Type

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Running only the generic release checklist and calling the game tested.
> - Avoid: Testers who play normally. Nobody tried to break it, so nothing broke.
> - Avoid: Testing odds by eye with 20 hatches.
> - Generic release checklist done.
> - Genre pass for each genre the game mixes (a tycoon with pets runs both).
> - A named breaker ran it on a real server, with evidence per row.
>
> Cost: TL;DR ~140 tok · whole note ~2.1k tok. Read more: ## Obby and platformer pass · ## Simulator, eggs and RNG pass · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A generic release checklist ([[QA Checklists Before Release]]) catches generic bugs: unsaved data, broken receipts, UI that overflows on phones. The bugs that kill a specific game are genre bugs: the obby stage you can skip with a jump nobody tried, the egg whose odds the server never enforced, the tycoon that loses its plot on rejoin, the tower defense map that pays out to an AFK player all night. This note gives one focused pass per genre. Run the generic pass every release; run the genre pass whenever a core loop system changes.

Each item says what to try and what "pass" looks like. Labels: **Rule of thumb** unless stated. Roblox docs claims link the doc.

---

## How to run a genre pass

1. **Name a breaker.** One tester whose only job is to cheat, skip and break, not to enjoy the game. Rotate the role.
2. **Use real devices and a real server.** Most genre exploits are about latency or physics, so solo Test in Studio hides them. Use Server & Clients at minimum ([[Testing Modes - Play Run and Multi-Client]]) and a private live server for the final run.
3. **Record evidence.** Each tick has a clip, a log line or a number. "Looked fine" is not a pass.
4. **Give testers powers through gated commands** (teleport to stage, grant currency, set time), never through edits to live code. See [[Gated Tester Commands and Debug Panels]].
5. **Turn every failure into a regression check.** If a bug can be expressed as a pure function test (odds, prices, rewards), add it to the suite ([[Automated Testing with TestEZ and Jest-Lua]]).

---

## Obby and platformer pass

| Try | Pass |
|---|---|
| Skip stages with wall hops, corner clips, emote or tool stacking, shift-lock jumps, ragdoll launches | Checkpoint only counts if the previous stage was reached; skips are either fixed or accepted on purpose |
| Touch a later checkpoint directly (stand on a moving platform that passes it) | Server checks stage order, not just the touch |
| Respawn on a checkpoint that is mid-air or inside a moving kill brick | Spawn point is safe and static |
| Rejoin mid-run | Stage restores from data; no reset to stage 1, no jump to the end |
| Stage skip product bought twice quickly | Exactly one stage granted per purchase (receipt idempotency, see [[Purchase Data and Receipts]]) |
| Low frame rate (throttle a phone) | Jumps still possible at 30 FPS; no physics-dependent gaps that need 60 |
| Speed or fly exploits | Server movement checks or Server Authority ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]]) |

Genre reference: [[Genre Playbook - Obbies and Platformers]].

## Simulator, eggs and RNG pass

| Try | Pass |
|---|---|
| Hatch 10,000 times through a test command and compare frequencies to the displayed odds | Each rarity within sampling error of the table (a chi-square or just a 3-sigma check per rarity) |
| Fire the hatch remote faster than the animation | Server rate limit and currency check per request; client animation is cosmetic only |
| Hatch with exactly enough currency from two devices at once | Currency never goes negative; one hatch fails |
| Paid random item in a region where paid random items are restricted | `PolicyService` check blocks the purchase path ([[Paid Random Items and Odds Disclosure in Practice]]) |
| Displayed odds vs config | Odds UI reads the same table the server rolls from (single source) |
| Inventory at cap, then hatch | Clear failure, no silent loss of the pet or the currency |
| Rebirth during a hatch | Either the hatch completes before the reset or is refunded |

Genre references: [[Pet Hatching and Following End to End]], [[Simulator and RNG Genre Teardown]].

## Tycoon pass

| Try | Pass |
|---|---|
| Leave and rejoin; join a different server | Plot rebuilds from data; purchased buttons stay purchased; no double droppers |
| Two players claim the same plot in the same frame | One owner; the other gets a different plot |
| Owner leaves while another player stands in the plot | Plot clears cleanly; no orphaned droppers still paying someone |
| Collector touched by a non-owner | Cash goes to the owner or nobody, never to the toucher |
| Server shutdown during autosave | Last save is consistent ([[Saving Correctly - Autosave and BindToClose]]) |
| Buy a button with a slow connection, spam-click | One purchase, one deduction |
| Leave the tycoon running 2 hours | Part count and memory stable (droppers clean up their drops) |

Genre reference: [[Tycoon Plots and Droppers End to End]].

## Tower defense pass

| Try | Pass |
|---|---|
| AFK through a whole match | Rewards scale with contribution or are capped; idle kick or AFK detection behaves as designed |
| Place towers on the path, inside walls, on other towers, outside the map | Server rejects placement using its own geometry check |
| Sell a tower the frame it is upgraded | No refund larger than the paid amount |
| Wave timer while the server lags | Enemy spawns are server-timed; no stacking of two waves into one frame unless designed |
| A player leaves mid-match | Their towers either persist or are removed and refunded per design; enemies keep pathing |
| Lowest-end phone at wave 40 | Enemy count, projectiles and effects inside budget ([[Mobile and Low-End Optimization]]) |

Genre reference: [[Tower Defense Waves and Placement End to End]].

## Racing pass

| Try | Pass |
|---|---|
| Cut corners across grass, through walls, by respawning | Checkpoints must be crossed in order; a respawn does not advance laps |
| Drive backwards over the finish line and forwards again | Lap does not count |
| Client-reported lap time | Server times laps from checkpoint crossings it saw |
| Car flips, falls out of the world | Reset puts the car on the last valid checkpoint, facing forward |
| Speed exploit on a client-owned car | Server speed check on the vehicle assembly |

Genre reference: [[Racing Laps and Checkpoints End to End]].

## Combat and PvP pass

| Try | Pass |
|---|---|
| Hit from far beyond weapon range, through walls | Server range and line-of-sight check |
| Fire faster than the cooldown with an exploit tool | Server cooldown per player per weapon |
| Kill credit when two players hit in the same frame | Deterministic rule (last hit or most damage) |
| Damage after death or after leaving | Ignored |
| Spawn camping | Spawn protection and spawn choice behave as designed |

## Trading and economy pass (any genre with trading)

Run [[Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins]] in full. A trading game without that pass is not ready.

---

## Common mistakes

- Running only the generic release checklist and calling the game tested.
- Testers who play normally. Nobody tried to break it, so nothing broke.
- Testing odds by eye with 20 hatches.
- Solo Test only: no latency, no second player, no race conditions.
- Fixing a skip without adding a regression test or a checklist row.
- Odds UI and server odds reading different tables.

## Checklist

- [ ] Generic release checklist done.
- [ ] Genre pass for each genre the game mixes (a tycoon with pets runs both).
- [ ] A named breaker ran it on a real server, with evidence per row.
- [ ] Odds sampled at volume and within tolerance.
- [ ] Rejoin and server-hop tested for every persistent system.
- [ ] Each failure became a test or a permanent checklist row.

## See also

- [[QA Checklists Before Release]], [[Multi-Client and Device Playtesting Protocols]], [[Testing Strategies and Frameworks]]
- [[Economy Exploits - Dupes Races and Purchase Abuse]], [[Server Authority and Validation]]
- [[Gated Tester Commands and Debug Panels]], [[Load and Soak Testing Servers - Long Sessions and Many Clients]]

## Connected notes

[[Genre Playbook - Tycoons]] · Genre Playbook - Tower Defense · Genre Playbook - Racing and Driving · Testing Modes - Play Run and Multi-Client · [[Automated Testing with TestEZ and Jest-Lua]]

<!-- related:start -->
## Related
[[Multi-Client and Live Testing]] · [[Testing Time-Based Features with a Controllable Clock]] · [[Automated Luau Checks - LihFolk Hook and Audit]] · [[UI Automation with VirtualInput and StudioTestService]] · [[Save Migration Tests - Fixture Saves and Golden Files]] · [[StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs]] · [[In-Game Bug Report Button with Automatic Context]] · [[Hunting Memory Leaks Step by Step]]
<!-- related:end -->
