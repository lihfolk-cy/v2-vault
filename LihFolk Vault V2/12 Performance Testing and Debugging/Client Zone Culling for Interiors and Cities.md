---
tags: [performance, culling, rendering, interiors, cities, streaming, client, type/guide, area/performance, level/advanced, api/ModelStreamingMode, api/StreamingEnabled]
---
# Client Zone Culling for Interiors and Cities

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Culling before measuring -> Profile on target phone first
> - Avoid: Culling gameplay collision or prompts -> Cull decor only
> - Avoid: Restoring to the wrong parent -> Record original parent
> - Profiled worst spots with culling off; gain expected and measured.
> - Cullable groups are decor-only Models with recorded home parents.
> - Room/floor/cell resolver uses the camera; hysteresis on hide.
>
> Cost: TL;DR ~140 tok · whole note ~2.4k tok. Read more: ## 2. What "hiding" means and what it saves · ## 3. Rules: rooms, portals and districts · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Instance streaming removes what is **far away**. It does nothing for what is **near but invisible**: the fully furnished interiors of every shop on the street you are walking down, the floors above and below you in a tower, the district on the other side of a wall. The engine does frustum culling and some occlusion work for rendering, but those objects still cost memory, still exist in the scene graph, still run their scripts and animations, and still get considered every frame. Manual zone culling, where the client hides whole groups of content it knows cannot be seen, is how dense cities and multi-room buildings hold frame rate on phones. This note covers when it is worth it, the safe way to hide content, portal-based rules, and how to measure the win.

Source labels: **Roblox docs** (create.roblox.com, as of October 2026), **Rule of thumb**, **Unverified**. Code is strict Luau, **reviewed, not run**.

---

## 1. When to bother

Measure first ([[MicroProfiler Guide]], [[Rendering Performance]]). Manual culling pays off when:

- Draw calls or triangle counts are high while standing in places where most content is behind walls (inside a building, in a narrow street).
- Interiors are detailed (props, lights, `SurfaceGui`s, particles) and players spend most time outside them, or vice versa.
- Many local effects (animated signs, fans, flickering lights, ambient particles) run in rooms nobody is in.

It does not pay off for open landscapes (nothing is hidden), for small maps that already fit the budget, or when streaming radius is already small enough. Rule of thumb: if the scene is under budget on your lowest target phone with everything shown, do not add culling; it is a correctness risk.

## 2. What "hiding" means and what it saves

| Technique | Saves rendering | Saves memory | Stops scripts/effects | Risk |
|---|---|---|---|---|
| Set `Transparency = 1` on every part | Some | No | No | Restoring the original values; overwrites server changes |
| `LocalTransparencyModifier` | Some | No | No | Intended for characters/camera; behaviour on arbitrary parts is not something to rely on (Unverified) |
| Disable effects (`ParticleEmitter.Enabled`, `Light.Enabled`, stop tweens/animations) | Some | No | Yes | Must re-enable correctly |
| **Reparent the group out of Workspace on the client** | Yes, fully | Partly (render data released) | Physics and rendering stop; scripts inside still exist | Server changes still replicate to it; streaming interaction (section 4) |
| Rely on streaming (`ModelStreamingMode`, smaller radius) | Yes | Yes | Yes (instances gone) | Only by distance, not by visibility |

The practical pattern for interiors and districts is **reparenting a client-side container**: each cullable group is a `Model` or `Folder`; when hidden, the client moves it to a holding folder outside Workspace (for example under `ReplicatedStorage` locally, or `nil` with a kept reference). A client reparenting a replicated instance does not replicate back (Roblox docs, replication rules: client changes stay local), so other players are unaffected.

Rules for doing it safely:

- Only cull **decor and static geometry** that the client never needs for gameplay. Never cull collision the local character can touch, doors with server logic, `ProximityPrompt`s the player must reach, or anything your client code holds `FindFirstChild` references into without checking.
- Keep a reference to each group so you can put it back. If you parent to `nil`, hold the instance in a table; the server can still update it (property replication keeps working while it exists on the client).
- Put it back to its **original parent**, recorded at startup.
- Do not cull anything the server will `Destroy` mid-session without your module hearing about it; listen to `Destroying` and drop references.

## 3. Rules: rooms, portals and districts

Simple models work best:

- **Inside or outside.** Each building has an interior group. When the local player is outside, all interiors except ones with open, visible doorways are hidden. When inside, the exterior city (except what windows show) and other interiors are hidden. This alone is most of the win in roleplay towns.
- **Floors.** In towers, show only the current floor plus one above and below.
- **Districts with portals.** Divide the city into cells; for each cell, list the cells visible from it (hand-authored or baked by sampling raycasts). Show only the current cell's visibility list. This is classic potentially visible set culling and is worth it only for very dense cities.

Detect the current room or cell with the same point-in-volume resolver as zones ([[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]]), using the **camera** position for visibility (third-person cameras can be outside the room the character is in) and the character for gameplay.

```lua
--!strict
-- Client: show the groups visible from the camera's current cell.
type Group = { model: Instance, home: Instance, shown: boolean }

local groups: { [string]: Group } = {}
local visibleFrom: { [string]: { string } } = {} -- cellId -> group ids, authored data
local holding = Instance.new("Folder")
holding.Name = "CulledLocal" -- not in Workspace: nothing inside renders

local function setShown(group: Group, shown: boolean)
	if group.shown == shown then return end
	group.shown = shown
	group.model.Parent = if shown then group.home else holding
end

local function applyCell(cellId: string)
	local want: { [string]: boolean } = {}
	for _, id in visibleFrom[cellId] or {} do
		want[id] = true
	end
	for id, group in groups do
		setShown(group, want[id] == true)
	end
end
```

Apply changes **with hysteresis** and a short delay when hiding (show immediately, hide after 0.5 to 1 s), so walking back and forth through a doorway does not thrash parenting, which itself costs time.

## 4. Interaction with StreamingEnabled

Streaming and manual culling both move instances in and out on the client; mixing them carelessly produces groups that never come back or appear twice.

- Make each cullable group a `Model` with `ModelStreamingMode = Atomic` (Roblox docs) so it arrives as a unit; register it with your culling module when it streams in (`ChildAdded` on its container, or `CollectionService:GetInstanceAddedSignal` for a tag) and unregister on removal.
- Do not cull groups marked `Persistent` expecting memory savings; reparenting does not free their data.
- Rule of thumb: let streaming handle distance and let your culler handle "near but hidden". If a group is far enough to be streamed out, your culler should simply not know about it.

## 5. Measuring the win

1. Pick three worst-case spots (busy street, tower lobby, interior with windows).
2. Record frame time, draw calls and triangle counts in the MicroProfiler and the render stats overlay with culling off and on, on a low-end phone ([[Mobile and Low-End Optimization]]).
3. Record client memory in the Developer Console ([[Developer Console and Stats]]).
4. Walk a fixed route for 5 minutes and watch for hitches when groups switch; if switching causes spikes, split groups smaller or spread reparenting across frames.

Keep the numbers in the note for the map. Culling that saves 0.3 ms but causes a 20 ms hitch at every doorway is a regression.

---

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Culling before measuring | Complexity with no gain | Profile on target phone first |
| Culling gameplay collision or prompts | Players fall through floors, cannot open doors | Cull decor only |
| Restoring to the wrong parent | Content appears in the wrong place or not at all | Record original parent |
| Using character position for visibility | Interior pops in with a zoomed-out camera | Camera position for culling |
| No hysteresis | Hitches walking through doorways | Show fast, hide late |
| Mixing with streaming blindly | Groups lost or duplicated | Atomic models, register on stream in |
| Transparency toggling every part | Server changes overwritten, little saved | Reparent the group |

## Checklist

- [ ] Profiled worst spots with culling off; gain expected and measured.
- [ ] Cullable groups are decor-only Models with recorded home parents.
- [ ] Room/floor/cell resolver uses the camera; hysteresis on hide.
- [ ] Atomic streaming for groups; registration on stream in and out.
- [ ] No gameplay references into cullable content.
- [ ] Before/after frame time, draw calls and memory recorded on a phone.

## See also

[[Instance Streaming]] · [[Level of Detail and Model Streaming]] · [[Rendering Performance]] · [[MicroProfiler Guide]] · [[Mobile and Low-End Optimization]] · [[Art Budgets - Triangles Draw Calls Memory]] · [[Instanced Interiors - Pooled House and Room Copies for Many Players]] · [[Replication Rules]]

## Connected notes
<!-- auto-links:start -->
[[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]] · VFX Performance Budgets and Culling · Case Study - Cutting a Million Instances
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs]] · [[Weather Performance Budgets and Quality Tiers]] · [[Performance Fundamentals]] · [[Network Bandwidth Budgets and Measuring Them]] · [[Script Performance]] · [[Memory Budgets and Leaks]] · [[QA Checklists Before Release]] · [[Hunting Memory Leaks Step by Step]]
<!-- related:end -->
