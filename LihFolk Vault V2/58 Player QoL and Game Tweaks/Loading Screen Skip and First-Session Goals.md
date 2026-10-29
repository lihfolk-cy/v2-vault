---
tags: [qol, loading-screen, replicatedfirst, preload, fast-join, first-session, goals, onboarding, type/guide, area/ui, area/design, level/intermediate, api/ReplicatedFirst, api/ContentProvider]
---
# Loading Screen Skip and First-Session Goals

<!-- tldr:start -->
> [!tldr] TL;DR
> - Long loading for no visible reason: Preloading the whole game -> Preload only first-screen assets
> - Player stuck behind loading screen: Waits on a signal that never fires -> Hard timeout
> - Skip reveals broken state: Systems assume data loaded -> Handle late data with placeholders
> - Custom loading screen removes the default and closes on a ready signal or timeout.
> - Skip appears after a few seconds; returning players skip on ready.
> - Preload limited to first-screen assets.
>
> Cost: TL;DR ~160 tok · whole note ~1.9k tok. Read more: ## 2. A loading screen with an honest skip · ## 3. First-session goals · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The first 60 seconds decide whether a new player stays. Two QoL levers sit right there: a loading screen that gets out of the way, and a clear goal for the first session so the player knows what to do once it does. This note covers custom loading screens with a skip, what to preload (and what not to), and how to present first-session goals. The deeper engineering of fast joins is in [[Case Study - Fast Join and Deferred Loading]] and [[Streaming Joins - Frozen Players and Loading Screen Teardown]]; onboarding design in [[First-Time User Experience and Onboarding]].

Sources: **Roblox docs** for `ReplicatedFirst:RemoveDefaultLoadingScreen` (https://create.roblox.com/docs/reference/engine/classes/ReplicatedFirst), `ContentProvider:PreloadAsync` (https://create.roblox.com/docs/reference/engine/classes/ContentProvider) and `game:IsLoaded` (https://create.roblox.com/docs/reference/engine/classes/DataModel). Timings are **Rule of thumb**.

## 1. What a loading screen is for

A custom loading screen should hide a broken-looking world, not add waiting. Its job: cover the moment when the map is half streamed and the HUD is not built, then leave as soon as the player can act. Every second beyond that costs players (**Rule of thumb**; measure your own drop-off with funnel analytics, [[Onboarding Funnel]]).

## 2. A loading screen with an honest skip

```lua
--!strict
-- ReplicatedFirst/LoadingScreen (LocalScript)
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local gui = script:WaitForChild("LoadingGui"):Clone() :: ScreenGui
gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local skip = gui:FindFirstChild("Skip", true) :: TextButton
skip.Visible = false

local finished = false
local function close()
	if finished then return end
	finished = true
	gui:Destroy()
end

skip.Activated:Connect(close)

task.delay(3, function() -- offer skip after a short moment
	if not finished then skip.Visible = true end
end)

if not game:IsLoaded() then game.Loaded:Wait() end

-- Preload only what the first screen needs: HUD icons and the first area's key sounds.
local critical = ReplicatedFirst:FindFirstChild("PreloadList")
if critical then
	pcall(ContentProvider.PreloadAsync, ContentProvider, critical:GetChildren())
end

-- Wait for the game's own ready signal (character spawned, settings applied, HUD built).
local ready = player:GetAttribute("ClientReady") == true
local start = os.clock()
while not ready and not finished and os.clock() - start < 20 do
	task.wait(0.2)
	ready = player:GetAttribute("ClientReady") == true
end
close()
```

`ClientReady` is set by your client bootstrap after it has built the HUD and applied settings. The 20 s cap means a stuck dependency never traps a player behind the loading screen forever.

What skip means: "show me the world now, even if parts are still loading". It is safe because the game must already handle late-streamed content. If skipping would break something (player spawns before data loads and sees zero coins), fix the dependency instead of hiding the skip: show a small "Loading data…" badge on the currency until data arrives.

Gotchas:
- **Do not preload everything.** `PreloadAsync` on the whole `Workspace` blocks on assets the player will not see for minutes. Preload the HUD and first-area sounds; let the rest stream.
- **Do not fake progress bars.** A bar stuck at 99% is worse than a spinner. If you show progress, base it on real counts (preload callback, or steps of your own bootstrap).
- **Returning players**: on the second join, skip immediately once ready; no logo animation.
- **Teleports**: `TeleportService:SetTeleportGui` shows a screen during place teleports; keep it visually consistent with the loading screen ([[Teleporting and Multi-Place Games]]).
- **Studio**: `RemoveDefaultLoadingScreen` behaviour in Studio play differs from live joins; test in a live server.

## 3. First-session goals

Players who know what they are trying to do in the first session stay longer (**Rule of thumb**, widely reported in Roblox postmortems). Give the first session three to five visible goals that walk through the core loop:

| Good first goal | Why |
|---|---|
| "Catch your first fish" | Teaches the core verb within a minute |
| "Sell for 100 coins" | Introduces the economy loop |
| "Buy a better rod" | First upgrade, first feeling of progress |
| "Reach the second island" | Shows the world is bigger |
| "Invite or play with a friend" (optional) | Social hook, never required |

Presentation:
- A small **goal tracker** in a corner (compact on phones), with progress counts.
- **Each completion gives a small reward and moment** ([[Reward Moments and Celebrations]]).
- **Server-tracked**: goals complete from server events, like quests ([[Quests and Objectives]]).
- **Dismissible** for experienced players, re-openable from the menu.
- **Ends with a hook into the long-term loop**: the last goal points at the daily or long-term goal system.

## 4. Do not stack modals on arrival

The worst first ten seconds: loading screen, then daily reward popup, then "Like the game!" popup, then update log, then a shop offer. Queue arrival modals and show **at most one** in the first minute; new players see none until their first goal is done (**Rule of thumb**). Use the critical notification channel only for real problems ([[Notification Queues and Limits]]).

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Long loading for no visible reason | Preloading the whole game | Preload only first-screen assets |
| Player stuck behind loading screen | Waits on a signal that never fires | Hard timeout |
| Skip reveals broken state | Systems assume data loaded | Handle late data with placeholders |
| Bar stuck at 99% | Fake progress | Real counts or spinner |
| New players bounce on arrival | Popup stack | One modal max in the first minute |
| No idea what to do | No first goals | 3-5 tracked first-session goals |

## Checklist

- [ ] Custom loading screen removes the default and closes on a ready signal or timeout.
- [ ] Skip appears after a few seconds; returning players skip on ready.
- [ ] Preload limited to first-screen assets.
- [ ] 3-5 server-tracked first-session goals with rewards.
- [ ] Arrival modals queued; none for new players before the first goal.

## See also

- [[Case Study - Fast Join and Deferred Loading]]
- [[Streaming Joins - Frozen Players and Loading Screen Teardown]]
- [[First-Time User Experience and Onboarding]]
- [[Onboarding and FTUE - Tutorials That Keep Players]]
- [[Core Loops and Session Design]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Skippable Tutorials and Replayable Tips]] · [[Retention and Return Hooks]] · Instance Streaming
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[QoL Audit Checklist]] · [[Top 25 QoL Wins by Effort]] · [[Joining Friends Parties and Private Servers]] · [[UI Scale HUD Hide and Compact Mode]] · [[Accessibility Cross-Links for QoL Settings]] · [[Feedback - Autosave Indicator Ping Display and Error Toasts]] · [[Server Hop Rejoin and Server Lists with Ping]] · [[Confirmation and Undo Patterns for Destructive and Paid Actions]]
<!-- related:end -->
