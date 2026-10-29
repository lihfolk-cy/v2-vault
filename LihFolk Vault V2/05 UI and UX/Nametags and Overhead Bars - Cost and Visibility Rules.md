---
tags: [ui, nametags, overhead, health-bars, billboardgui, visibility, teams, performance, type/guide, area/ui, level/intermediate, api/BillboardGui, api/Humanoid]
---
# Nametags and Overhead Bars - Cost and Visibility Rules

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Custom tags without disabling built-in -> `DisplayDistanceType = None`
> - Avoid: Server-created tags -> Client tag manager
> - Avoid: Enemy tags with `AlwaysOnTop` -> LOS check or no enemy tags
> - Built-in displays disabled where custom tags exist (players and NPCs).
> - Visibility table per relationship; enemies never through walls.
> - Client tag manager with tiers, declutter and slow refresh.
>
> Cost: TL;DR ~140 tok · whole note ~2.2k tok. Read more: ## 2. Visibility rules · ## 3. A client tag manager · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[World-Space UI - BillboardGui and SurfaceGui]] covers how a `BillboardGui` sizes, scales and culls, and shows a nameplate and health bar pattern. This note is the policy layer above it: who should see whose tag (team, enemy, party, stealth), how to switch off and replace the Humanoid's built-in name and health display, a client-side tag manager that declutters crowds and degrades with distance, and the update rules that keep 50 tags cheap.

Source labels: **Roblox docs**, **Rule of thumb**.

---

## 1. The built-in Humanoid display

Every Humanoid can draw its own name and health above the head. Properties (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/Humanoid):

| Property | Effect |
|---|---|
| `DisplayDistanceType` | `Viewer`, `Subject` or `None`; who decides the visible distance |
| `NameDisplayDistance`, `HealthDisplayDistance` | Distances in studs |
| `HealthDisplayType` | `DisplayWhenDamaged`, `AlwaysOn`, `AlwaysOff` |
| `NameOcclusion` | Whether names are hidden behind walls, for enemies, or never |
| `DisplayName` | Text shown; defaults to the player's display name |

If you draw your own tags, set `DisplayDistanceType = None` on every character (in a `CharacterAdded` handler on the server, or in `StarterCharacter`), or players see two names. NPCs with Humanoids show their model name by default: set it on NPC templates too.

The built-in display is cheap and respects `NameOcclusion`. For simple games it is enough; custom tags earn their cost when you need team colours, levels, titles, icons, voice indicators or custom health bars.

## 2. Visibility rules

Decide per relationship, then encode in one function on the client:

| Viewer sees... | Name | Health bar | Through walls | Distance |
|---|---|---|---|---|
| Self | No (`PlayerToHideFrom`) | Own health in HUD | n/a | n/a |
| Party / squad | Yes | Yes | Yes (`AlwaysOnTop`) | Far (200+) |
| Teammate | Yes | When damaged | Yes, faded | Medium (120) |
| Neutral player | Yes | No | No | Short (60 to 80) |
| Enemy | Optional | When damaged and in line of sight | **No** | Short |
| Hidden / stealthed enemy | No | No | No | n/a |

**Rule of thumb.** Enemy tags through walls are a wallhack you shipped yourself. Enemies get tags only with `AlwaysOnTop = false` and a line-of-sight check, or no tags at all in competitive modes.

Because visibility differs per viewer, **create tags on the client**. Server-created billboards replicate to everyone with the same properties, and you cannot make them depend on the viewer except through `PlayerToHideFrom` (one player) ([[World-Space UI - BillboardGui and SurfaceGui]] section 6).

Data comes from the server via replicated attributes on the player or character: `Team` (or `Player.Team`), `Level`, `Title`, `PartyId`, `Stealthed`. Never derive hidden information on the client from data it should not have: if stealth matters, the server must not replicate the stealthed character's position at all, or tag hiding is cosmetic.

## 3. A client tag manager

One module owns all tags:
- Creates a tag on `CharacterAdded` for every player (and tagged NPCs), destroys it on removal.
- Every 0.2 to 0.5 s (not every frame) recomputes each tag's **visibility tier** from relationship and distance: `Full` (name, title, bar), `NameOnly`, `Hidden`.
- **Declutter**: in crowds, show at most N full tags (for example 12 to 20) for the nearest or most relevant players; the rest drop to `NameOnly` or `Hidden`. Party members and players the viewer is targeting are always included.
- **Line of sight** for enemy tags: one raycast per enemy tag per refresh, from camera to head, at the slow refresh rate.

```lua
--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

type Tier = "Full" | "NameOnly" | "Hidden"
type Tag = { gui: BillboardGui, bar: Frame, player: Player, tier: Tier }

local tags: { [Player]: Tag } = {}
local MAX_FULL = 16
local local_ = Players.LocalPlayer

local function relationship(p: Player): "Party" | "Team" | "Enemy" | "Neutral"
	if p:GetAttribute("PartyId") ~= nil and p:GetAttribute("PartyId") == local_:GetAttribute("PartyId") then return "Party" end
	if p.Team and p.Team == local_.Team then return "Team" end
	if p.Team and local_.Team and p.Team ~= local_.Team then return "Enemy" end
	return "Neutral"
end

local MAX_DIST = { Party = 300, Team = 120, Neutral = 70, Enemy = 50 }

local function refresh()
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local candidates = {}
	for p, tag in tags do
		local head = p.Character and p.Character:FindFirstChild("Head") :: BasePart?
		if head then
			local rel = relationship(p)
			local d = (head.Position - cam.CFrame.Position).Magnitude
			if d <= MAX_DIST[rel] and not p.Character:GetAttribute("Stealthed") then
				table.insert(candidates, { tag = tag, d = if rel == "Party" then 0 else d })
			else
				tag.tier = "Hidden"
			end
		end
	end
	table.sort(candidates, function(a, b) return a.d < b.d end)
	for i, c in candidates do
		c.tag.tier = if i <= MAX_FULL then "Full" else "NameOnly"
	end
	for _, tag in tags do
		tag.gui.Enabled = tag.tier ~= "Hidden"
		tag.bar.Visible = tag.tier == "Full"
	end
end

task.spawn(function()
	while true do
		refresh()
		task.wait(0.3)
	end
end)
```

## 4. Cost rules

- **Update on change, not per frame.** Health bars listen to `Humanoid.HealthChanged` and tween only when health changes. Levels and titles change on attribute signals.
- **Fewer elements per tag.** Each `TextLabel`, `UIStroke`, `UIGradient` and image is rendered per tag. A name with a stroke, a bar with a fill, and one icon is plenty. Text strokes on many tags are a known cost ([[UIStroke on Text - Glyph Counters and the Stroke Ratio]]).
- **Offset size with `MaxDistance`** for readable, cullable tags; set `MaxDistance` to the tier's distance so the engine also culls.
- **`LightInfluence = 0`** so tags stay readable in dark areas.
- **No per-tag loops.** One refresh loop for all tags, as above; no `while true` inside each tag.
- Measure with 50 dummy characters in a test place on a low-end phone ([[MicroProfiler Guide]]).

## 5. Content and privacy

- Show `DisplayName`, optionally with `@Name` in profile surfaces only. Usernames over every head in a kids' game help harassment more than identification.
- Titles and clan tags that players choose are user-generated text and must be filtered through `TextService` before display to others ([[Text Chat Customization with TextChatService]]).
- Voice chat indicators (speaking icon) help social games; show them only for players within voice range.
- Accessibility: support a "larger nametags" option with `UIScale` on the tag, and enough contrast for colour-blind team colours (icon or shape plus colour) ([[Readable Text and UI Scale]]).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Custom tags without disabling built-in | Two names per player | `DisplayDistanceType = None` |
| Server-created tags | Same visibility for everyone; enemy tags through walls | Client tag manager |
| Enemy tags with `AlwaysOnTop` | Free wallhack | LOS check or no enemy tags |
| Per-frame updates per tag | CPU cost in busy servers | Event-driven bars, one slow refresh loop |
| No declutter | Wall of names in hubs | Max full tags, tiers |
| Unfiltered custom titles | Moderation risk | Filter before showing |

## Checklist
- [ ] Built-in displays disabled where custom tags exist (players and NPCs).
- [ ] Visibility table per relationship; enemies never through walls.
- [ ] Client tag manager with tiers, declutter and slow refresh.
- [ ] Bars update on health change only; minimal elements per tag.
- [ ] Display names by default; custom titles filtered; size option.

## See also
[[World-Space UI - BillboardGui and SurfaceGui]] · [[HUD Design]] · [[Characters and Humanoids]] · [[Interest Management and Per-Player Replication]] · [[Accessibility]] · [[Spawning Teams and Rounds]]

## Connected notes
<!-- auto-links:start -->
[[Readable Text and UI Scale]] · Downed, Revive and Bleed-Out States · Social Design and Multiplayer Play
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Off-Screen Objective Markers and Waypoint Arrows]] · [[Text Fonts and Rich Text]] · [[UI Design Systems]] · [[Layout - Scale Offset and Constraints]] · [[Minimap and World Map UI - Projection, Rotation and Fog of War]] · [[ScreenGui Fundamentals]] · [[Safe Areas and Insets]] · [[Tutorial Step Design Patterns - Teach by Doing]]
<!-- related:end -->
