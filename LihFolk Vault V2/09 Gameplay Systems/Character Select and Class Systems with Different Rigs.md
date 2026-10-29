---
tags: [gameplay, characters, classes, character-select, rigs, morphs, humanoiddescription, data, type/guide, area/gameplay, level/advanced, api/Players, api/Humanoid, server-authority]
---
# Character Select and Class Systems with Different Rigs

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Class chosen on the client and applied there -> Server applies; client only requests
> - Avoid: `ApplyDescription` without pcall -> pcall, fallback look
> - Avoid: Rig missing Animate or Animator -> Complete template, copy character scripts
> - Class definitions as data; class id as server-set attributes.
> - Look applied by the right method per class, with pcall and fallbacks.
> - Custom rigs complete; character scripts present; ownership and camera correct.
>
> Cost: TL;DR ~160 tok · whole note ~2.4k tok. Read more: ## 2. Three ways to apply a look · ## 3. Swapping to a custom rig · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A class system (knight, mage, ranger) or a character roster (pick a hero) changes three things at once: **stats and abilities** (data), **appearance** (avatar or a custom rig) and sometimes **skeleton** (R15 avatar vs a custom creature). Each has a different Roblox mechanism and different traps. [[Custom Characters and StarterCharacter]] covers a single custom rig for everyone; this note covers choosing per player at runtime: the class data model, the three ways to apply a look, swapping rigs safely, respawn flow, and saving the choice.

Source labels: **Roblox docs**, **Rule of thumb**, **Unverified** where marked.

---

## 1. Class data is the source of truth

```lua
--!strict
export type ClassDef = {
	id: string,
	displayName: string,
	rig: "Avatar" | "Custom",
	customRig: string?,             -- name of a model in ServerStorage.Rigs
	outfit: { [string]: any }?,     -- HumanoidDescription fields for Avatar classes
	stats: { maxHealth: number, walkSpeed: number, jump: number },
	abilities: { string },
	animationSet: string,           -- id of an animation set for the Animate script
	footstepSet: string,
	unlock: { kind: "Free" | "Level" | "Gamepass" | "Currency", value: number? },
}
```

Everything downstream (combat, UI, sounds, hitboxes) reads the class id from one place, an attribute set by the server: `character:SetAttribute("Class", "Ranger")` and `player:SetAttribute("Class", "Ranger")`. Abilities, animations and footsteps look up the definition ([[Ability Kits Architecture]], [[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]]).

## 2. Three ways to apply a look

| Method | How | Keeps the player's avatar? | Use for |
|---|---|---|---|
| **Outfit over avatar** | `Humanoid:ApplyDescription(desc)` on the server, modifying only some fields (clothing, accessories, colours, body scale) | Partially | Classes that are "you, in knight gear" |
| **Full HumanoidDescription** | `player:LoadCharacterWithHumanoidDescription(desc)` | No | Fixed hero looks on standard R15 |
| **Custom rig** | Clone a rig model and assign it as `player.Character` | No | Creatures, non-humanoid skeletons, stylised heroes |

References (**Roblox docs**): https://create.roblox.com/docs/reference/engine/classes/Humanoid#ApplyDescription, https://create.roblox.com/docs/reference/engine/classes/Player#LoadCharacterWithHumanoidDescription, https://create.roblox.com/docs/characters/appearance.

**Rule of thumb.** Prefer outfit-over-avatar when you can: players like seeing their own avatar, and you keep the default rig's animation and accessory behaviour. Fixed hero looks are better for competitive games where silhouettes must be readable.

`ApplyDescription` is a yielding server call that can fail (asset loading); wrap it in `pcall`, and apply only to a fully loaded character (after `CharacterAppearanceLoaded` if you mix with the player's own avatar).

## 3. Swapping to a custom rig

```lua
--!strict
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

Players.CharacterAutoLoads = false -- we spawn characters ourselves

local function spawnAs(player: Player, def: { id: string, customRig: string?, stats: { maxHealth: number, walkSpeed: number } }, at: CFrame)
	local template = def.customRig and ServerStorage.Rigs:FindFirstChild(def.customRig)
	if not (template and template:IsA("Model")) then
		player:LoadCharacter() -- fall back to the avatar
		return
	end
	local rig = template:Clone()
	rig.Name = player.Name
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not (hum and root and root:IsA("BasePart")) then
		rig:Destroy()
		player:LoadCharacter()
		return
	end
	hum.MaxHealth = def.stats.maxHealth
	hum.Health = def.stats.maxHealth
	hum.WalkSpeed = def.stats.walkSpeed
	rig.PrimaryPart = root
	-- Character scripts you rely on (Animate, health, your client controllers)
	for _, s in StarterPlayer.StarterCharacterScripts:GetChildren() do
		if not rig:FindFirstChild(s.Name) then
			s:Clone().Parent = rig
		end
	end
	rig:SetAttribute("Class", def.id)
	rig:PivotTo(at)
	local old = player.Character
	player.Character = rig
	rig.Parent = workspace
	if old and old ~= rig then old:Destroy() end
end
```

Gotchas:
- **Rig must be complete**: `Humanoid`, `HumanoidRootPart`, joints, an `Animator` inside the Humanoid (one is created when animations first load on the server, but create it in the template to be safe), and an `Animate` script whose animation ids match the skeleton ([[The Default Animate Script]], [[Rigs and Joints]]).
- **Character scripts**: with manual assignment, do not assume Roblox copies `StarterCharacterScripts` into your rig the way `LoadCharacter` does (**Unverified** across all cases; copying them yourself as above is safe either way, skipping names already present).
- **Ownership** of the new character goes to the player once it is their `Character` and unanchored; nothing in the template should be anchored ([[Network Ownership]]).
- **Camera** follows the new Humanoid through the default camera's `CameraSubject` update on character change; custom cameras must listen to `CharacterAdded` ([[Camera Systems]]).
- **Animations** are skeleton-specific. R15 animations do not play correctly on a quadruped. Keep animation sets per skeleton family ([[Retargeting Animations Between Rigs]]).
- **Hitboxes** change with rigs; competitive games normalise with uniform hitbox parts per class so a small creature is not unhittable ([[Hitboxes and Hit Detection]]).

## 4. The select flow

1. Player joins; data loads ([[Session Locking and Profile Libraries]]). Until loaded, show the select screen with a loading state; spawn nothing.
2. Client shows classes with unlock state from server-sent data. Previews use a `ViewportFrame` with a local clone of the rig or a `HumanoidDescription` applied to a local dummy ([[UI Layout Objects - Lists Grids and Pages]]).
3. Client sends `SelectClass(id)`. Server validates: id exists, unlocked (level, owns gamepass via `MarketplaceService:UserOwnsGamePassAsync` cached, currency purchase already recorded), allowed in the current mode (team limits, "max 2 healers"), not on cooldown.
4. Server spawns via the chosen method, sets attributes, grants the ability kit.
5. Death and respawn: since `CharacterAutoLoads = false`, a server respawn loop (on `Humanoid.Died` plus `Players.RespawnTime` or your own delay) calls the same `spawnAs` with the saved class.

Changing class mid-match: only at spawn points or between rounds; changing on the spot is a common exploit (switch to a healer to heal, switch back).

## 5. Saving the choice

- Save `lastClass` and per-class progress (`classes[id] = { level, xp, loadout }`) in the profile, not a single global loadout ([[Data Schema Design and Migrations]]).
- Validate on load: a saved class that no longer exists or is no longer owned falls back to a default; never trust saved ids blindly.
- When you add classes, existing players get them in their unlocked set through a migration or a computed default, not a manual grant.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Class chosen on the client and applied there | Others see the wrong look; exploits | Server applies; client only requests |
| `ApplyDescription` without pcall | Spawn fails silently on asset errors | pcall, fallback look |
| Rig missing Animate or Animator | T-pose for other players | Complete template, copy character scripts |
| R15 animations on custom skeletons | Broken poses | Animation sets per skeleton |
| Class swap anywhere | Heal-and-swap exploits | Swap at spawn or between rounds |
| Global loadout | Switching classes wipes setups | Per-class progress and loadouts |

## Checklist
- [ ] Class definitions as data; class id as server-set attributes.
- [ ] Look applied by the right method per class, with pcall and fallbacks.
- [ ] Custom rigs complete; character scripts present; ownership and camera correct.
- [ ] Selection validated on the server (unlock, mode rules, cooldown).
- [ ] Respawn loop uses the saved class; mid-match swaps restricted.
- [ ] Per-class progress saved; invalid saved classes fall back.

## See also
[[Custom Characters and StarterCharacter]] · [[Characters and Humanoids]] · [[Ability Kits Architecture]] · [[Retargeting Animations Between Rigs]] · [[R15 Rig Anatomy and Attachments]] · [[Spawn Points Safe Zones and Respawn Flow]]

## Connected notes
<!-- auto-links:start -->
[[Character and Creature Pipeline]] · Modeling Characters for R15 and Custom Rigs · Genre Playbook - Battlegrounds and Arena Fighters · Saved Inventory End to End
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[HumanoidDescription and Outfit Systems]] · [[Downed, Revive and Bleed-Out States]] · [[Kill Credit, Assists, Kill Feed and Death Recaps]] · [[Tools and Inventory Systems]] · [[Combat Systems Architecture]] · [[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]] · [[Spawning Teams and Rounds]] · [[Grabs, Carries and Throws - Moving Players Safely]]
<!-- related:end -->
