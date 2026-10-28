---
tags: [ui, billboardgui, surfacegui, world-space, nameplates, damage-numbers, performance]
---
# World-Space UI - BillboardGui and SurfaceGui

Some UI belongs in the world rather than on the screen: names over heads, enemy health bars, damage numbers, shop signs, interactive screens on a wall, a leaderboard on a pillar. Roblox offers two containers for this. A `BillboardGui` always faces the camera and follows a part or attachment. A `SurfaceGui` is painted onto a face of a part. Both use ordinary `GuiObject`s inside, so everything you know about layout applies, but their sizing, lighting, input and performance rules are different and are the source of most "my nameplate is giant", "my sign is blurry" and "the server lags with 200 enemies" problems.

Sources: **Docs** (BillboardGui, SurfaceGui, SurfaceGuiBase, LayerCollector; "In-experience UI containers"; October 2026), the **reference project** (one production game), and **rule of thumb**.

---

## 1. BillboardGui

### Placement

| Property | Meaning (Docs) |
|---|---|
| `Adornee` | The part or attachment it follows. If unset, its parent (if a part or attachment) |
| `StudsOffset` | Offset in studs relative to the **camera** orientation (so "up" is screen-up) |
| `StudsOffsetWorldSpace` | Offset in studs relative to world axes |
| `ExtentsOffset`, `ExtentsOffsetWorldSpace` | Offsets in units of half the adornee's size: `(0, 1, 0)` is "on top of the part" whatever its size |
| `SizeOffset` | A 2D anchor in size-relative units |

Prefer `ExtentsOffsetWorldSpace = Vector3.new(0, 1, 0)` plus a small `StudsOffsetWorldSpace` over a hard-coded Y offset: it adapts to big and small enemies. The reference project's VFX and UI anchoring rule was the same: derive positions from bounding boxes or named attachments, never fixed Y offsets that break on small or flying rigs. Using a named attachment (`NameplateAttachment` above the head) as the `Adornee` is the most robust.

### The Size rule that confuses everyone

`BillboardGui.Size` is a `UDim2`, but its two parts mean different things:

- **Scale is studs.** `UDim2.fromScale(4, 1)` is 4 studs wide and 1 stud tall in the world: it gets smaller on screen as the camera moves away, like a real sign.
- **Offset is pixels.** `UDim2.fromOffset(200, 50)` is 200 x 50 screen pixels at any distance: always the same on-screen size.

| Use | Size choice |
|---|---|
| Nameplates readable at range | Offset (constant on-screen size), with `MaxDistance` |
| Health bars that should feel attached to the body | Scale (shrink with distance) |
| Damage numbers | Offset for readability, or Scale for a "physical" feel at close range |
| Signs in the world | Scale, or better a `SurfaceGui` |

Mixed sizes (Scale X, Offset Y) work but are rarely what you want.

Inside the billboard, children use normal Scale/Offset relative to the billboard's canvas. With a Scale-sized billboard, use Scale (and `TextScaled` with a `UITextSizeConstraint`) inside, because the canvas pixel size changes with distance. Docs note `TextScaled` "is useful for rendering text elements within BillboardGuis".

### Distance behaviour

- `MaxDistance`: beyond this the billboard stops rendering. Default `0` or `inf` means no limit (Docs). Always set it. Docs recommend a value high enough that the UI is already small when it disappears, to hide the pop.
- `DistanceLowerLimit` and `DistanceUpperLimit`: distances at which scaling stops growing or shrinking. `DistanceStep` quantises `CurrentDistance` changes (Docs). `CurrentDistance` is readable.
- `AlwaysOnTop`: draw over 3D geometry (visible through walls). Use for important markers; not for every enemy, or walls stop meaning anything.
- `LightInfluence` (0 = unlit, uses `Brightness`) and `Brightness`: UI that should glow in a dark cave needs `LightInfluence = 0`.
- `PlayerToHideFrom`: hides it from one player, typically the owner's own nameplate.
- `ClipsDescendants`: whether content outside the canvas draws.

### Input

`BillboardGui.Active` controls whether descendants receive input (Docs). Clickable billboards work, but small moving click targets in 3D are frustrating; prefer a `ProximityPrompt` for interaction and use the billboard for display.

---

## 2. SurfaceGui

| Property | Meaning (Docs) |
|---|---|
| `Adornee`, `Face` | Which part and which `NormalId` face |
| `SizingMode` | `PixelsPerStud` (default): canvas size = face size in studs times `PixelsPerStud`. `FixedSize`: canvas is `CanvasSize` |
| `PixelsPerStud` | Pixel density in `PixelsPerStud` mode |
| `CanvasSize` | Virtual pixels in `FixedSize` mode, so a 1920 x 1080 design can be reused on a wall |
| `AlwaysOnTop`, `LightInfluence`, `Brightness`, `MaxDistance`, `ClipsDescendants` | As billboards |
| `ZOffset` | Layering of several SurfaceGuis on the same face |
| `ToolPunchThroughDistance` | Within this distance, left clicks act on the gui instead of the held tool |
| `Active` | Sinks input (default true) |

### Resolution trade-off

Docs: higher `PixelsPerStud` lets content render at higher definition, but a large pixel density on a big part creates a large canvas. Rules of thumb:

| Viewing distance | PixelsPerStud |
|---|---|
| Up close (an arcade screen, a terminal) | 50 to 100 |
| Across a room (a shop sign) | 20 to 50 |
| Far away (a billboard on a building) | 5 to 20 |

A 40 x 20 stud wall at 100 pixels per stud is a 4000 x 2000 canvas; that is texture memory spent on something players see from 50 studs away. `FixedSize` mode with a sensible `CanvasSize` makes the cost explicit.

### Interactive SurfaceGuis

A `SurfaceGui` in `Workspace` that contains buttons receives input from players. Two common requirements:

- **Per-player content** (a terminal showing your own stats): keep the `SurfaceGui` in `PlayerGui` (or created by a LocalScript there) and set its `Adornee` to the part. Each player sees and interacts with their own copy, and the server never sees it.
- **Shared content** (a global leaderboard): one `SurfaceGui` in the world, updated by the server or by each client from replicated data.

---

## 3. Patterns

### Enemy health bar with a trailing "damage ghost"

A bar that drops instantly while a pale "ghost" fill lingers and then slides down reads as satisfying damage. The reference project's version: hold the ghost 0.35 s, slide it over 0.45 s, plus a white flash on the fill on each hit, all client-side.

```lua
--!strict
local TweenService = game:GetService("TweenService")

export type HpBar = { set: (fraction: number) -> (), destroy: () -> () }

local SLIDE = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function makeHpBar(adornee: Attachment | BasePart, parent: Instance): HpBar
	local gui = Instance.new("BillboardGui")
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(4, 0.45)        -- studs: feels attached to the body
	gui.StudsOffsetWorldSpace = Vector3.new(0, 0.8, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false

	local track = Instance.new("Frame")
	track.Size = UDim2.fromScale(1, 1)
	track.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	track.Parent = gui

	local ghost = Instance.new("Frame")
	ghost.Size = UDim2.fromScale(1, 1)
	ghost.BackgroundColor3 = Color3.fromRGB(255, 235, 200)
	ghost.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 50, 60)
	fill.Parent = track

	gui.Parent = parent

	local current = 1
	local pending: thread? = nil
	local function set(fraction: number)
		fraction = math.clamp(fraction, 0, 1)
		if fraction >= current then
			fill.Size = UDim2.fromScale(fraction, 1)
			ghost.Size = fill.Size
			current = fraction
			return
		end
		current = fraction
		fill.Size = UDim2.fromScale(fraction, 1) -- the real value drops instantly
		if pending then
			task.cancel(pending)
		end
		pending = task.delay(0.35, function()      -- hold, then slide the ghost
			pending = nil
			TweenService:Create(ghost, SLIDE, { Size = UDim2.fromScale(current, 1) }):Play()
		end)
	end

	return {
		set = set,
		destroy = function()
			if pending then
				task.cancel(pending)
			end
			gui:Destroy()
		end,
	}
end
```

### Damage numbers: billboard or screen?

Two approaches:

1. **Billboards at the hit position** (pooled `BillboardGui`s with Offset size, tweened upward via `StudsOffsetWorldSpace` and faded). Natural depth; cost grows with live count.
2. **Screen-space numbers**: project the hit point with `Camera:WorldToViewportPoint` once, then animate an ordinary `TextLabel` in a screen gui. Cheaper, easier to style and merge, and does not jitter with the target. Common Roblox UI playbooks recommend the same approach for "coin flies from enemy to your counter" effects.

Either way: pool (the reference project caps live numbers at 12), merge same-kind numbers within about 0.55 s, and skip numbers for enemies off-screen.

### Nameplates

- Offset-sized, `MaxDistance` around 60 to 150 studs depending on the game, `PlayerToHideFrom` set to the owner.
- Show the minimum: name and one social signal. The reference project adds the held weapon's name as a title line under the player's name as a deliberate social flex.
- Use a premium style for important NPCs and stations (the reference project tags station titles and gives them one consistent font and treatment). A duplicate title billboard that someone added on top of a station (a blue pill reading "SHOP", `AlwaysOnTop`, used by no script) covered the real, consistently styled title; the fix was deleting it. Keep one owner per world label.

---

## 4. Performance

World UI is rendered per object and updated per frame for position. Rules that held up:

- **Count them.** Hundreds of always-on billboards are a measurable cost, especially on phones. Budget them like particles: for example at most a few dozen live enemy bars on screen.
- **Set `MaxDistance` on everything.** The default renders at any distance.
- **Hide when irrelevant.** Health bars only while the enemy is damaged or targeted; nameplates hidden in combat-heavy scenes if needed.
- **Avoid per-frame property writes.** Update bars on health change, not every frame. Do not rotate or recolour billboard contents in a `RenderStepped` loop for every enemy.
- **`AlwaysOnTop` sparingly.** It also changes sorting, and too many on-top labels clutter the scene.
- **Streaming.** With instance streaming, a billboard parented to a part that streams out disappears with it; client-created billboards must handle their adornee being removed ([[Instance Streaming]]).
- **SurfaceGui canvas size** is texture memory: compute `face size x PixelsPerStud` before shipping.

A testing gotcha from the reference project: its automated screen capture did not draw `AlwaysOnTop` billboards (health bars), so screenshots taken by tools looked as if the bars were missing. Verify world UI in a live play test, not only in captured images.

---

## 5. ViewportFrame: 3D inside 2D

The reverse direction, showing 3D models inside screen UI (shop previews, backpack item cards, character portraits), uses a `ViewportFrame` with its own `CurrentCamera`, `Ambient`, `LightColor` and `LightDirection` (Docs). Rules:

- Frame the subject from its bounding box (`Model:GetBoundingBox()`), not hard-coded distances.
- Animated rigs need a `WorldModel` inside the `ViewportFrame`, which costs more.
- Many live viewports (20 inventory slots, each spinning) are expensive; prefer one shared preview stage and static icons in the grid, or spin only the selected item.
- The reference project's backpack hero stage and its exclusive shop card used a single viewport each, animated by one loop that runs only while the screen is visible.

---

## 6. Who creates world UI: server or client?

| Created by | Pros | Cons |
|---|---|---|
| Server (billboard parented to the NPC's model) | Simple; every player sees it; streams with the model | Every property change replicates to every client; per-player variation impossible |
| Client (LocalScript creates billboards for visible NPCs) | Per-player content (your damage, your target); no replication cost for animation; can cull by distance | Must handle models streaming in and out and being destroyed |

Rule of thumb: the server owns **data** (health as an attribute on the model, the NPC's name and level), clients own **presentation** (the billboard, its animation, its colour). A health bar animated on the server sends a property update to every player for every frame of animation; the same bar created by each client from the replicated `Health` attribute costs no network at all. The reference project follows this split: enemy levels and ranks are attributes set by the spawner, and the bar title (including a rich text tag for the rank) is built on the client.

```lua
--!strict
-- Client: attach a nameplate to every model tagged "Enemy", driven by attributes.
local CollectionService = game:GetService("CollectionService")

local plates: { [Model]: BillboardGui } = {}

local function attach(model: Instance)
	if not model:IsA("Model") or plates[model] then
		return
	end
	local head = model:FindFirstChild("Head") or model.PrimaryPart
	if not head then
		return
	end
	local plate = Instance.new("BillboardGui")
	plate.Size = UDim2.fromOffset(160, 36)
	plate.ExtentsOffsetWorldSpace = Vector3.new(0, 1, 0)
	plate.StudsOffsetWorldSpace = Vector3.new(0, 1, 0)
	plate.MaxDistance = 90
	plate.Adornee = head :: BasePart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.RichText = true
	label.TextScaled = true
	label.AutoLocalize = false
	label.Parent = plate
	local function refresh()
		local level = model:GetAttribute("Level") or 1
		label.Text = string.format("<b>Lv %d</b> %s", level, model.Name)
	end
	model:GetAttributeChangedSignal("Level"):Connect(refresh)
	refresh()
	plate.Parent = model
	plates[model] = plate
end

local function detach(model: Instance)
	local plate = plates[model :: Model]
	if plate then
		plate:Destroy()
		plates[model :: Model] = nil
	end
end

for _, m in CollectionService:GetTagged("Enemy") do
	attach(m)
end
CollectionService:GetInstanceAddedSignal("Enemy"):Connect(attach)
CollectionService:GetInstanceRemovedSignal("Enemy"):Connect(detach) -- also fires when streamed out
```

Note that the model name is inserted into rich text without escaping here because it is developer-controlled; anything a player can name must be escaped ([[Text Fonts and Rich Text]]).

---

## Common mistakes

- Billboard sized in Scale when you wanted constant on-screen size (or the reverse).
- No `MaxDistance`: hundreds of labels rendering across the map.
- Hard-coded Y offsets that float above small enemies and sink into big ones.
- `AlwaysOnTop` on every label.
- Per-frame updates of every enemy's bar.
- SurfaceGuis with huge pixel densities on big parts.
- Two labels owned by different systems on the same object.
- Trusting tool screenshots for `AlwaysOnTop` UI.

## Checklist

- [ ] Size choice (studs or pixels) deliberate per element.
- [ ] Every billboard and surface gui has `MaxDistance`.
- [ ] Anchored to attachments or extents, not fixed offsets.
- [ ] Bars and numbers pooled, updated on change, capped.
- [ ] `PixelsPerStud` chosen from viewing distance; canvas size computed.
- [ ] Per-player interactive screens live in `PlayerGui` with an `Adornee`.
- [ ] Verified in a live play test on a phone.

See also: [[ScreenGui Fundamentals]], [[Text Fonts and Rich Text]], [[Game Feel and Juice]], [[Hitboxes and Hit Detection]], [[Rendering Performance]], [[Instance Streaming]], [[Highlights and Selection Effects]].

## Connected notes
<!-- auto-links:start -->
[[Links - Containers]] · [[Readable Text and UI Scale]] · [[Debugging UI Layout and Input]] · [[Layout - Scale Offset and Constraints]] · [[Links - UI elements]] · [[Accessibility Contrast]]
<!-- auto-links:end -->
