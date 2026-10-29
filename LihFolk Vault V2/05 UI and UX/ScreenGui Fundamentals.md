---
tags: [ui, screengui, playergui, zindex, displayorder, fundamentals, type/guide, area/ui, level/beginner, api/ZIndex, api/DisplayOrder, api/CanvasGroup]
---
# ScreenGui Fundamentals

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Screens organised into folders in `StarterGui`, which silently re-enables reset on spawn.
> - Avoid: Using `ZIndex` to put one screen above another.
> - Avoid: A modal backdrop made of a plain `Frame`: clicks pass straight through to the world.
> - Every persistent screen: `ResetOnSpawn = false`, direct child of `StarterGui`.
> - A written `DisplayOrder` band plan; tutorial layers on top.
> - New screens use `ZIndexBehavior.Sibling`.
>
> Cost: TL;DR ~150 tok · whole note ~5.5k tok. Read more: ## 6. The GuiObject basics you will use every day · ## 10. A minimal, robust screen controller · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Every piece of 2D interface a player sees on their screen lives inside a `ScreenGui`. This note explains how that container actually behaves at runtime: where it comes from, when it is destroyed and re-created, how several of them stack, how draw order works inside one, and how input passes through it. Most "my UI disappeared", "my button is behind the frame" and "my menu reset when I died" bugs come from misunderstanding one of these rules, not from layout maths.

Sources used below:
- **Docs**: the official Roblox engine reference and the "On-screen UI containers" guide (checked October 2026).
- **Reference project**: one production game (a sword/RNG combat game) whose UI went through a full phone rebuild, a 10/10 positioning audit and a font sweep. Its numbers are labelled as measured or chosen there.
- **Rule of thumb**: experience, not a hard limit.

Layout maths (Scale, Offset, constraints) is in [[Layout - Scale Offset and Constraints]]. Notches and the top bar are in [[Safe Areas and Insets]].

---

## 1. Where a ScreenGui lives

A `ScreenGui` only renders when it is a descendant of a player's `PlayerGui` (Docs). There are three ways to get one there:

1. **Put it in `StarterGui`.** When the player's character first spawns, the engine clones every `ScreenGui` in `StarterGui` into their `PlayerGui`. This is the normal path for Studio-authored UI.
2. **Clone it from a script.** A LocalScript clones a template from `ReplicatedStorage` into `PlayerGui`. Useful for screens that only some players ever need.
3. **Build it in code.** `Instance.new("ScreenGui")`, parented to `PlayerGui` by a LocalScript.

Two details catch people:

- **Cloning waits for the character.** Docs: the clone happens when the player joins and "their character first spawns". If `Players.CharacterAutoLoads` is false, nothing in `StarterGui` is cloned until `Player:LoadCharacterAsync()` runs. A main menu shown before spawning therefore cannot live in `StarterGui`; put it in `ReplicatedFirst` and build it from there (the reference project's main menu is a `ReplicatedFirst` LocalScript for exactly this reason).
- **The server cannot see a player's UI changes.** UI is client-side. The server can parent a `ScreenGui` into a `PlayerGui` (it replicates to that client), but everything after that, including button clicks, happens on the client. Do not put game logic that matters in UI scripts; see [[Client-Server Model]] and [[Server Authority and Validation]].

### Accessing UI from code

```lua
--!strict
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

-- WaitForChild, never FindFirstChild, for StarterGui clones: on a slow join
-- the clone may arrive after your LocalScript starts.
local hud = playerGui:WaitForChild("HUD") :: ScreenGui
local shop = playerGui:WaitForChild("Shop") :: ScreenGui
```

Scripts placed inside a `ScreenGui` in `StarterGui` are cloned with it and start running in the clone. That is convenient for tiny widgets, but a game with more than three or four screens is easier to maintain with controller ModuleScripts in `StarterPlayerScripts` that find their screens by name (see [[Project Structure and Bootstrapping]]).

---

## 2. ResetOnSpawn: the death trap

`ResetOnSpawn` decides whether the clone is destroyed and re-cloned every time the character respawns (Docs):

| Condition | Resets on respawn |
|---|---|
| `ResetOnSpawn = true` (the default) | Yes |
| The `ScreenGui` is an **indirect** descendant of `StarterGui` (inside a Folder) | Yes, whatever the property says |
| `ResetOnSpawn = false` **and** a direct child of `StarterGui` | No |

**What you see when it bites.** A player dies and their open shop closes, their scroll position is lost, a tween half-way through snaps, any connections your controller made to buttons inside the old copy now point at destroyed instances, and clicks do nothing. Or worse: the controller re-runs and you have two sets of connections.

**Rule of thumb.** Set `ResetOnSpawn = false` on every persistent screen (HUD, menus, settings) and keep them as direct children of `StarterGui`. Keep `true` only for UI that is genuinely tied to one life (a death-cam overlay, a per-life ability bar whose contents depend on the character). The folder rule is the one that surprises teams: organising `StarterGui` into folders silently turns reset back on.

If a controller does need to survive resets, look the screen up again on `CharacterAdded` instead of caching the instance forever:

```lua
--!strict
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function bindHud(hud: ScreenGui)
	-- connect buttons for this copy only; the copy owns its connections,
	-- so destroying it on respawn cleans them up
end

local function onCharacter()
	local hud = player:WaitForChild("PlayerGui"):WaitForChild("HUD") :: ScreenGui
	bindHud(hud)
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter()
end
```

---

## 3. Enabled, Visible and the cost of hidden UI

Two switches hide UI and they are not the same:

| Switch | Applies to | Effect |
|---|---|---|
| `ScreenGui.Enabled = false` | the whole container | Docs: contents "will not render, process user input, or update in response to changes" |
| `GuiObject.Visible = false` | one object and its descendants | Not rendered and not hit-tested; the object still exists in layouts' child lists (a `UIListLayout` skips invisible children) |

Use `Enabled` for whole screens you open and close (one screen per menu), and `Visible` for parts inside a screen. Toggling `Enabled` is cheap and avoids layout work for everything inside.

### The ScreenGui render cache

Docs: "the appearance of a `ScreenGui` is cached" until a descendant is added or removed, a descendant property changes, or a property of the `ScreenGui` itself changes. Then it is recomputed on the next rendered frame.

This has a practical consequence the docs do not spell out: **one animated object invalidates its whole ScreenGui every frame.** A HUD that holds 300 static objects and one spinning sunburst re-composes the whole HUD every frame while the sunburst turns. Two fixes:

- Put constantly animated decoration in its own small `ScreenGui` (or under a `CanvasGroup`, see [[UI Layout Objects - Lists Grids and Pages]] and [[UI Design Systems]]).
- Pause decorative animation when the screen is closed. The reference project's rule after a performance pass: any per-frame UI loop runs only while its screen is visible, and idle UI has zero `RenderStepped` connections (see [[UI and GUI Animation]]).

---

## 4. Stacking many ScreenGuis: DisplayOrder

`DisplayOrder` is an integer; higher draws on top of lower (Docs). It only orders whole `ScreenGui`s against each other. `ZIndex` never crosses `ScreenGui` boundaries: a `ZIndex = 10000` frame in a `DisplayOrder = 0` gui still draws under everything in a `DisplayOrder = 1` gui.

Write your bands down once and never improvise. The reference project grew past 40 screens and ended up with a band plan like this (anonymised but numerically real):

| Band | [[DisplayOrder]] | Contents |
|---|---|---|
| World overlays | 0 to 5 | damage numbers converted to 2D, crosshair |
| HUD | 5 to 20 | rail, bottom bar, currency, quest dock, goal card (8) |
| Panels | 20 to 100 | shop, backpack, settings (one open at a time) |
| Popups and toasts | 100 to 199 | reward banners, "Quest complete!" |
| Always-on primary button | 200 | the auto-roll toggle that must sit above panels |
| Tutorial | 201 to 205 | reward burst 201, spotlight 204, pointing hand 205 |
| Loading / main menu | 1000+ | covers everything |

**Production lesson (reference project).** A first-roll reward burst sat at `DisplayOrder` 175 and was drawn under the always-on AUTO button at 200, so the tutorial's celebratory effect appeared to hang out of the bottom of the screen behind a button. The fix was 175 to 201. The general lesson: anything a tutorial points at, highlights or celebrates must sit in a band above everything it can overlap, and the tutorial hand must be the top-most of all (205 there).

**Do not use DisplayOrder for modality.** A higher `DisplayOrder` draws on top, but clicks still reach buttons underneath wherever the top screen has no input-sinking object. Modality needs an input blocker (section 7).

---

## 5. Draw order inside one ScreenGui: ZIndexBehavior

`LayerCollector.ZIndexBehavior` (on `ScreenGui`, `BillboardGui`, `SurfaceGui`) chooses how `ZIndex` is interpreted (Docs):

| Mode | Rule |
|---|---|
| `Sibling` (default) | Children always draw above their parent. `ZIndex` only orders siblings under the same parent. |
| `Global` | All descendants sort by `ZIndex` first, hierarchy only breaks ties. A child with a lower `ZIndex` than its parent draws **under** it. |

`Sibling` is what you want for new work: the hierarchy is the draw order, so moving a card moves its whole stack. `Global` exists for old UI. It is still common in games that started years ago, and it produces the classic bug "my new label is invisible": it is under its own background because its `ZIndex` is 1 and the background's is 3.

Two rules that matter in mixed codebases:

- **CanvasGroup only flattens under `Sibling`.** Docs: "Descendants of `CanvasGroup` will be rendered as a flattened texture only when the ancestor `LayerCollector` has its `ZIndexBehavior` set to `Enum.ZIndexBehavior.Sibling`." A `CanvasGroup` in a `Global` gui does not give you group fades.
- **Do not switch an old gui's mode in place.** Flipping a large `Global` gui to `Sibling` reorders hundreds of objects at once. Do it per screen with screenshots before and after, or leave it and add new screens as `Sibling` guis.

**Reference project.** Its large legacy container (all the "MainUI" panels) stayed `Global`; headers are drawn at panel `ZIndex + 3` by convention so they always sit over the panel body. New screens were built `Sibling`. That split is fine as long as every builder knows which mode a gui is in. Put it in the gui's name or an attribute if you have many.

### UIStroke has its own ZIndex

`UIStroke.ZIndex` orders sibling strokes on the same object (Docs). Several strokes with the same `ZIndex` have an **undefined** order. If a design uses two outlines (dark outer, light inner), give them different `ZIndex` values or one will randomly win on some devices.

---

## 6. The GuiObject basics you will use every day

| Property | What it really does | Trap |
|---|---|---|
| `Size`, `Position` (`UDim2`) | Scale (fraction of parent) plus Offset (pixels) per axis | Offset pixels are not physical: phones render fewer, bigger pixels. See [[Layout - Scale Offset and Constraints]] |
| `AnchorPoint` | Which point of the object `Position` refers to, 0 to 1 per axis | Also the origin for `UIScale` pops and `AutomaticSize` growth. Centre-anchor anything that pops |
| `ClipsDescendants` | Clips children to the **rectangle** | Ignores `UICorner`; see below |
| `Rotation` | Degrees | Old rule: a rotated ancestor disables clipping unless `StarterGui.ClipsDescendantsSupportsRotation` is enabled (Docs) |
| `Active` | Boolean input sink | Superseded for most uses by `InputSink` |
| `InputSink` | `None`, `Activate`, `All` | Buttons default to `Activate`; frames default to `None` (Docs) |
| `Interactable` | false = button cannot be pressed, `GuiState` stays `NonInteractable` | Use for disabled buttons instead of disconnecting handlers |
| `LayoutOrder` | Sort key for list/grid layouts | Only used when the layout's `SortOrder` is `LayoutOrder` |
| `Selectable` | Gamepad selection candidate | See [[Gamepad and Console UX]] |

### The "pocket" bug: ClipsDescendants and UICorner

Docs state that clipping by rounded corners is not supported: `ClipsDescendants` cuts on the rectangle. A rounded card with a full-width coloured child (a header strip, a progress fill, a gradient) paints that child into the card's corners, producing small square "pockets" of colour outside the rounding.

The reference project's UI audit tool flags this as `pocket` and it was the single most common defect across 84 screen-views. Fixes, in order of preference:

1. Give the child its own `UICorner` with the same radius (for a header strip, only the top corners: `UICorner` now has per-corner `TopLeftRadius`, `TopRightRadius`, `BottomRightRadius`, `BottomLeftRadius` (Docs)).
2. Inset the child by the corner radius.
3. Wrap the content in a `CanvasGroup` with the `UICorner`: Docs say `UICorner` and `UIGradient` under a `CanvasGroup` "apply to the whole group", so children are clipped to the rounded shape. This costs texture memory (see section 8).

### Disabled buttons the right way

```lua
--!strict
local function setButtonEnabled(button: GuiButton, enabled: boolean)
	button.Interactable = enabled           -- engine blocks presses and hover states
	button.AutoButtonColor = enabled        -- no engine tint on a dead button
	-- visual: desaturate rather than hide, so the layout does not jump
	button.BackgroundTransparency = if enabled then 0 else 0.35
	button:SetAttribute("Disabled", not enabled) -- lets a style rule or audit find it
end
```

---

## 7. Input through UI

When a player clicks or taps, the engine hit-tests UI from the top-most visible object down. Three things decide whether the input stops at your UI or continues into the 3D world (where it would fire `ClickDetector`s, swing a tool, or rotate the camera):

1. **`GuiButton`s sink their activation input by default** (`InputSink.Activate`, Docs). Mouse movement still passes through.
2. **Frames do not sink by default** (`InputSink.None`). A modal backdrop made of a plain `Frame` does not block clicks to the world or to buttons beneath it.
3. **`InputSink.All`** sinks everything over the object. This is the modal blocker.

```lua
--!strict
-- A full-screen dimmer that makes a panel modal.
local function makeModalBlocker(parent: ScreenGui): Frame
	local blocker = Instance.new("Frame")
	blocker.Name = "ModalBlocker"
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.BackgroundColor3 = Color3.new(0, 0, 0)
	blocker.BackgroundTransparency = 0.45
	blocker.InputSink = Enum.InputSink.All -- nothing behind receives input
	blocker.ZIndex = 0                    -- under the panel in a Sibling gui
	blocker.Parent = parent
	return blocker
end
```

Note that `GuiObject.InputBegan`, `InputChanged` and `InputEnded` fire whatever `InputSink` says (Docs), so you can still detect "tap outside the panel to close" on the blocker itself.

For `UserInputService` the signal is the `gameProcessedEvent` argument: it is true when the UI (or a focused `TextBox`) consumed the input. Every world-action handler must check it, or typing "w" in a chat box makes the character walk. See [[Input - UserInputService and ContextActionService]].

---

## 8. Hiding Roblox's own UI

`StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.X, false)` hides default elements: `PlayerList`, `Health`, `Backpack`, `Chat`, `EmotesMenu`, `SelfView`, and more (Docs). Call it from a LocalScript. Hide only what you replace: players expect chat and the player list, and the reference project ended up putting "Player List" back as a setting (default off) after hiding it outright confused players looking for friends.

The top bar itself (the Roblox menu button, chat, and so on) cannot be removed. Design around it with `ScreenInsets` and `GuiService.TopbarInset` ([[Safe Areas and Insets]]).

---

## 9. Studio-authored versus code-built UI

There are three workable strategies:

| Strategy | Good for | Fails when |
|---|---|---|
| Authored in Studio, scripts only wire behaviour | Art-heavy menus, designers editing directly | Many near-identical items; layout differs per device |
| Built entirely in code | Lists, generated cards, anything data-driven; declarative frameworks ([[Declarative UI - React-Lua and Fusion]]) | Artists need to tweak pixels and cannot |
| Templates authored in Studio, cloned and filled by code | Most games | Templates drift from what code expects |

The failure that cost the reference project the most time was a fourth, accidental strategy: **saved copy plus runtime rebuild.** A screen was authored in Studio, then a module started rebuilding parts of it at runtime (a newer card layout). The saved `StarterGui` copy stayed at the old version. The game looked right in play, but every Edit-mode audit read the stale saved copy, and the phone-layout "desktop round trip" check reported 137 differing properties until someone re-baked the saved copy with the new builder. Their rule afterwards: **if code rebuilds a screen, re-run the builder on the saved copy whenever the builder changes**, so Edit and Play show the same thing.

Related lessons from the same project:

- **Mark every mass edit reversibly.** Before a sweep changed a property on hundreds of objects, it wrote the old value into an attribute (`PreStd_Font`, `PreStd_Color`, and so on). When the user later asked for the stroke part of a font sweep to be undone, 252 stroke colours and 38 thicknesses were restored exactly from those attributes. Without them the revert would have been guesswork.
- **Keep names stable.** Tutorial pointers, tap pads and controller lookups found buttons by name (`BackpackButton`, `ShopButton`). Redesigns that renamed instances silently broke the tutorial hand. Prefer tagging (`CollectionService`) or a dedicated attribute such as `TutHook = "hud_roll"` for anything another system needs to find; see [[CollectionService Patterns]].

---

## 10. A minimal, robust screen controller

```lua
--!strict
-- StarterPlayerScripts/ScreenController (ModuleScript required by a client bootstrap)
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local ScreenController = {}

local OPEN_INFO = TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local current: ScreenGui? = nil

local function popScale(gui: ScreenGui): UIScale?
	local root = gui:FindFirstChild("Root")
	if not root then
		return nil
	end
	local scale = root:FindFirstChild("OpenScale")
	if scale and scale:IsA("UIScale") then
		return scale
	end
	local s = Instance.new("UIScale")
	s.Name = "OpenScale"
	s.Parent = root
	return s
end

function ScreenController.open(name: string)
	local gui = playerGui:FindFirstChild(name)
	if not (gui and gui:IsA("ScreenGui")) then
		warn("ScreenController: no ScreenGui named", name)
		return
	end
	if current and current ~= gui then
		ScreenController.close()
	end
	current = gui
	gui.Enabled = true
	local s = popScale(gui)
	if s then
		if GuiService.ReducedMotionEnabled then
			s.Scale = 1 -- no motion for players who asked for none
		else
			s.Scale = 0.92
			TweenService:Create(s, OPEN_INFO, { Scale = 1 }):Play()
		end
	end
end

function ScreenController.close()
	local gui = current
	if not gui then
		return
	end
	current = nil
	local s = popScale(gui)
	if s and not GuiService.ReducedMotionEnabled then
		local t = TweenService:Create(s, CLOSE_INFO, { Scale = 0.9 })
		t.Completed:Once(function()
			-- only disable if nothing reopened it meanwhile
			if current ~= gui then
				gui.Enabled = false
			end
		end)
		t:Play()
	else
		gui.Enabled = false
	end
end

return ScreenController
```

The numbers (0.92 to 1 in 0.14 s with `Back` out, close in 0.12 s) are the reference project's "snappy presenter" values after players called the earlier 0.3 s opens sluggish. One open panel at a time is a deliberate rule: stacked panels on phones cover the whole screen and players lose track of how to get back.

---

## Common mistakes

- Screens organised into folders in `StarterGui`, which silently re-enables reset on spawn.
- Using `ZIndex` to put one screen above another. Only `DisplayOrder` crosses `ScreenGui`s.
- A modal backdrop made of a plain `Frame`: clicks pass straight through to the world.
- Rounded cards with rectangular children: square "pockets" in the corners.
- Animated decoration in the same `ScreenGui` as hundreds of static HUD objects.
- Caching a screen instance in a controller and never re-finding it after a reset.
- Testing only in Studio's default window size. See [[Responsive UI for Phone Tablet Console and PC]].

## Checklist

- [ ] Every persistent screen: `ResetOnSpawn = false`, direct child of `StarterGui`.
- [ ] A written `DisplayOrder` band plan; tutorial layers on top.
- [ ] New screens use `ZIndexBehavior.Sibling`.
- [ ] Modals use an `InputSink.All` blocker.
- [ ] Disabled buttons use `Interactable = false`.
- [ ] No per-frame loop runs for a closed screen.
- [ ] Every mass edit stores old values in attributes.
- [ ] Other systems find UI by tag or attribute, not by a name a redesign may change.

See also: [[Layout - Scale Offset and Constraints]], [[Safe Areas and Insets]], [[HUD Design]], [[UI Design Systems]], [[UI and GUI Animation]], [[Input - UserInputService and ContextActionService]], [[Memory Budgets and Leaks]], [[Events Signals and Connections]].

## Connected notes
<!-- auto-links:start -->
[[Debugging UI Layout and Input]] · Links - Containers · UI Asset Pipeline · Cookbook - UI · Skill - Roblox UI Builder · Safe Area
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[UI Asset Pipeline]] · [[Cookbook - UI]] · [[Minimap and World Map UI - Projection, Rotation and Fog of War]] · [[UI Motion Language and Timing]] · [[Drag-and-Drop Inventories and Sliders with UIDragDetector]] · [[World-Space UI - BillboardGui and SurfaceGui]] · [[Menu Archetypes - Shop Settings Codes Rewards]] · [[Text Fonts and Rich Text]] · [[Virtualized Lists and Large Inventories]] · [[Accessibility]]
<!-- related:end -->
