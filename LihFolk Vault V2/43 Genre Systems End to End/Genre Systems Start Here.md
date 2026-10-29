---
cssclasses: [vault-hub]
tags: [index, start, genre-system, worked-build]
---
# Genre Systems Start Here

The genre playbooks in `10 Game Design and Genres` explain why a genre works and what it needs. The worked builds in [[Worked Builds Start Here]] build general systems (inventory, shop, codes, leaderboards) from an empty place. This section joins the two: each note takes one genre's core system and builds it end to end in strict Luau, with a folder layout, a server and client split, validated remotes, save hooks, the edge cases that break it in live servers, and a test checklist.

All code is marked "reviewed, not run": written against Roblox docs (as of October 2026) and checked by reading, not executed.

## The builds

| Note | Genre playbook | The hard part it solves |
|---|---|---|
| [[Tycoon Plots and Droppers End to End]] | [[Genre Playbook - Tycoons]] | Income without physics parts, plots rebuilt from ids, offline earnings, chain changes after launch |
| [[Tower Defense Waves and Placement End to End]] | [[Genre Playbook - Tower Defense]] | Hundreds of enemies as numbers, batched events, eight-step placement validation, balance arithmetic |
| [[Obby Checkpoints and Stage Saves End to End]] | [[Genre Playbook - Obbies and Platformers]] | Current versus furthest stage, presence and timing checks, skips, streaming-safe respawns and kill bricks |
| [[Arena Rounds with Teams and Spectating End to End]] | [[Genre Playbook - Party and Minigame Collections]], [[Genre Playbook - Battlegrounds and Arena Fighters]] | Several arenas per server, rating-balanced teams, late joins, spectating, stale timers |
| [[Horror Monster Chase AI End to End]] | [[Genre Playbook - Horror and Story]] | A fair five-state monster, server-side senses, hiding both ways, stuck recovery |
| [[Racing Laps and Checkpoints End to End]] | [[Genre Playbook - Racing and Driving]] | Swept gate crossings, interpolated lap times, anchored starts, clean-lap records |

The arena note replaces the proposed title "Round-Based Minigame Loop End to End", which already exists as [[Round-Based Minigame Loop End to End]]. Read that one for the single global round loop; the arena note is its multi-arena, team and spectating extension.

## The shared foundation

Every build here sits on the plumbing from [[Saved Inventory End to End]]: the `Net` remote helper, the token-bucket `RateLimiter`, the `DataTemplate` with migrations, the lease-locked `PlayerData` module and the `Main` bootstrap. Each note shows the fields it adds to `DataTemplate` and the service name to append to `Main`'s `ORDER` list. Build that note first.

## Rules every build follows

1. **The client asks with the smallest payload; the server decides.** A button id, an arena name, a tower type and position. Never a price, a score, a time or a result ([[Server Authority and Validation]]).
2. **Validate in a fixed order:** types, NaN and size, state, ownership, cost, geometry. Cheap checks first.
3. **Write into the profile at the moment of change.** Cash, stages and wins go straight into `profile.Data`, so autosave and the leave-save see them. Copying values back in your own `PlayerRemoving` handler races the profile module's save, because the engine does not promise which connection runs first. For leave-time writes (a partial match reward, a rage-quit penalty), add a synchronous `BeforeRelease` hook to `PlayerData` that runs before it serialises.
4. **Guard every delayed callback** with a round or state id. `task.delay` outlives the state that scheduled it.
5. **Visuals belong to clients.** Drops, enemies, jumpscares and markers are drawn locally from replicated attributes and server times ([[RemoteEvents RemoteFunctions and Unreliable Remotes]]).
6. **Respond to suspicious movement with a reset and a log, not a ban.** Physics glitches look like cheats ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]]).

## Before you ship any of them

- [ ] The note's own test checklist, including the failure cases
- [ ] Remotes fuzzed ([[Testing Your Own Remotes - Fuzzing and Abuse Tests]])
- [ ] Multi-client and latency tests ([[Multi-Client and Device Playtesting Protocols]])
- [ ] Release checklist ([[QA Checklists Before Release]])

## See also
- [[Worked Builds Start Here]], [[Core Loops and Session Design]], [[Balancing with Spreadsheets and Data]]
- [[Anti-Exploit Start Here]], [[Session Locking and Profile Libraries]], [[Physics and Vehicles Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Level Design Start Here]] · [[Skill - Roblox System Builder]] · [[Core Loop]] · [[Multiplayer Services Start Here]] · [[Obby and Platforming Level Design]] · [[Genre Playbook - Sports]]
<!-- auto-links:end -->
