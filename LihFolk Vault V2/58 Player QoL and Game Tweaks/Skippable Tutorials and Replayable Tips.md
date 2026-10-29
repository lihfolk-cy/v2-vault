---
tags: [qol, onboarding, tutorial, skip, tips, ftue, progressive-disclosure, persistence, type/guide, area/design, area/ui, level/intermediate, api/DataStoreService]
---
# Skippable Tutorials and Replayable Tips

<!-- tldr:start -->
> [!tldr] TL;DR
> - Skippers stuck without starter items: Skip only hides UI -> Server skip applies all step grants
> - Double starter rewards: Non-idempotent grants -> Grant keyed by source id
> - New tutorial step never shown to anyone: Single done flag -> Per-step completion
> - Tutorial modelled as saved steps.
> - Skip available (immediately for returning accounts), applied on the server with grants.
> - Grants idempotent; completion detected server-side.
>
> Cost: TL;DR ~150 tok · whole note ~1.9k tok. Read more: ## 2. Skip without losing rewards or breaking state · ## 4. Replayable tips · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A tutorial is QoL for new players and a tax on everyone else. Returning players on a new device, alt accounts, friends who already know the game, and players who skipped once and now regret it all need different things. This note covers making tutorials skippable without breaking progression, saving per-step completion, and replayable tips that teach on demand. The design of the first session itself is in [[First-Time User Experience and Onboarding]] and [[Onboarding Funnel]]; the loading screen and first-session goals are in [[Loading Screen Skip and First-Session Goals]].

Sources: **Roblox docs** for DataStores (https://create.roblox.com/docs/cloud-services/data-stores) and remotes. Design guidance is **Rule of thumb**; funnel numbers you should measure yourself with analytics ([[Onboarding Funnel]]).

## 1. Steps, not a single "tutorialDone" flag

Model the tutorial as named steps, each completed independently and saved on the server:

```lua
--!strict
-- ReplicatedStorage/Shared/TutorialSteps
return {
	{ id = "move", title = "Move around", grants = nil },
	{ id = "collect", title = "Collect 5 coins", grants = nil },
	{ id = "equip", title = "Equip your first tool", grants = "StarterSword" },
	{ id = "shop", title = "Visit the shop", grants = nil },
	{ id = "quest", title = "Accept a quest", grants = nil },
}
```

Benefits: you can insert a step later and only show it to players who lack it; analytics can see exactly where people stop; a skip can mark everything done in one write.

## 2. Skip without losing rewards or breaking state

The skip button must leave the player in the same state as completing the tutorial. If step 3 grants a starter sword, skipping must grant it too, or the player is stuck without a weapon. Do this on the server:

```lua
--!strict
-- ServerScriptService/TutorialService (excerpt)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Steps = require(ReplicatedStorage.Shared.TutorialSteps)
local PlayerData = require(script.Parent.PlayerData)
local Inventory = require(script.Parent.Inventory)

local remote = ReplicatedStorage.Remotes.TutorialSkip :: RemoteEvent

local function completeStep(player: Player, data: any, stepId: string)
	if data.tutorial[stepId] then return end
	data.tutorial[stepId] = true
	for _, step in Steps do
		if step.id == stepId and step.grants then
			Inventory.grant(player, step.grants, "tutorial") -- idempotent by source key
		end
	end
end

remote.OnServerEvent:Connect(function(player: Player)
	local data = PlayerData.get(player)
	if data == nil then return end
	for _, step in Steps do
		completeStep(player, data, step.id)
	end
	data.tutorialSkipped = true -- for analytics, and to offer tips later
end)
```

Make grants idempotent (keyed by `"tutorial:"..stepId`) so a skip after partial completion cannot grant twice. Completion of normal steps is detected by the server from game events (coins collected, tool equipped), never reported by the client as "I finished step X".

Where to show the skip (**Rule of thumb**):
- **Immediately** for accounts with prior progress on this game (new device, data present).
- **After the first step** for brand-new accounts, with a confirm: "Skip the tutorial? You can replay tips from Settings."
- **Never hide skip behind a timer**; that is the opposite of QoL.

## 3. Tutorial UX that respects players

- **Do not lock controls** longer than needed. Let players walk around during dialogue.
- **One instruction at a time**, with the target highlighted (arrow, outline, beam to the target).
- **Show the bound key or button** for the current device, read from the input binding, not hard-coded ([[Rebinding Controls with the Input Action System]]).
- **Progressive disclosure**: show only the HUD buttons the current step needs; reveal the rest as steps complete ([[Menu Archetypes - Shop Settings Codes Rewards]] section 9).
- **No forced reading**: dialogue advances on tap, and a "fast text" option shows lines instantly ([[Writing Dialogue for Roblox Players]]).

## 4. Replayable tips

Tips are short, contextual, one-time-by-default hints: "Tip: hold to charge", shown the first time the player meets the mechanic. Make them replayable:

- A **Tips / How to play** page in the menu listing every tip seen, grouped by topic, each with a short clip or image.
- **Reset tips** in settings re-arms all contextual tips.
- **Tip frequency** setting: All / Important only / Off.
- Store seen tips as a set of ids on the server profile. This list grows; cap it or store as a compact bitset if you have hundreds.

```lua
--!strict
-- Client: show a tip once, if the player allows tips.
local ClientSettings = require(script.Parent.ClientSettings)
local Notifier = require(script.Parent.Notifier)
local seenRemote = game:GetService("ReplicatedStorage").Remotes.TipSeen :: RemoteEvent

local seen: { [string]: boolean } = {} -- filled from the profile on join

local function tip(id: string, text: string, important: boolean)
	local mode = ClientSettings.get("tips") :: string -- "all" | "important" | "off"
	if seen[id] or mode == "off" or (mode == "important" and not important) then return end
	seen[id] = true
	seenRemote:FireServer(id)
	Notifier.push("personal", text, if important then 5 else 2, "tip:" .. id)
end
```

On the server, accept only known tip ids and ignore duplicates.

## 5. Returning players

Players who come back after weeks forget controls and systems added since. Show a short "What's new" panel (only entries newer than their last visit) and offer "Refresh basics" which re-arms core tips. See [[Patch Notes and Player Communication]].

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Skippers stuck without starter items | Skip only hides UI | Server skip applies all step grants |
| Double starter rewards | Non-idempotent grants | Grant keyed by source id |
| New tutorial step never shown to anyone | Single done flag | Per-step completion |
| Client can skip to rewards | Client reports completion | Server detects completion from events |
| Players who skipped are lost | No way back | Tips page and reset tips |
| Wrong key in tutorial text | Hard-coded "Press E" | Glyph from the binding |

## Checklist

- [ ] Tutorial modelled as saved steps.
- [ ] Skip available (immediately for returning accounts), applied on the server with grants.
- [ ] Grants idempotent; completion detected server-side.
- [ ] Controls never locked unnecessarily; prompts show device glyphs.
- [ ] Contextual tips, a tips page, reset and frequency settings.
- [ ] "What's new" for returning players.

## See also

- [[First-Time User Experience and Onboarding]]
- [[Difficulty Options and Cognitive Load]]
- [[Lore Delivery Without Walls of Text]]
- [[Quests and Objectives]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Loading Screen Skip and First-Session Goals]] · [[Notification Queues and Limits]] · [[Onboarding Funnel]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Onboarding and FTUE - Tutorials That Keep Players]] · [[Tutorial Step Design Patterns - Teach by Doing]] · [[QoL Audit Checklist]] · [[Top 25 QoL Wins by Effort]] · [[Accessibility Cross-Links for QoL Settings]] · [[Settings Menu Essentials and Persistence]]
<!-- related:end -->
