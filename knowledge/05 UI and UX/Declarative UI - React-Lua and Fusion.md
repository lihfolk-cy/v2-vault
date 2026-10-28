---
tags: [ui, declarative, react-lua, fusion, vide, state, architecture]
---
# Declarative UI - React-Lua and Fusion

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Starting with Roact in new code.
> - Avoid: Mixing Fusion 0.2 and 0.3 examples.
> - Avoid: Animating via component state every frame.
> - Library and version pinned (Wally or packages folder).
> - Server-replicated data feeds one client store.
> - Each property has exactly one owner.
>
> Cost: TL;DR ~110 tok · whole note ~3.6k tok. Read more: ## 2. React-Lua · ## 3. Fusion 0.3 · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Imperative UI code says "when the gem count changes, find the label and set its text". Declarative UI code says "the label's text is the gem count", and a library keeps the instances in sync with your state. On Roblox the declarative options are community libraries, mainly **React-Lua** (a Luau port of React), **Fusion** (reactive state objects) and **Vide** (a smaller reactive library). This note explains how each works, when declarative UI is worth it and when it is not, how to combine it with Studio-authored art, and the performance traps.

Sources: the libraries' own repositories and documentation (versions checked October 2026), **rule of thumb**, and the **reference project** (one production game that stayed imperative, with lessons on where that hurt). Roact, the older Roblox library, is superseded by React-Lua and should not be used for new work.

**Versions as of October 2026** (from the projects' GitHub releases):

| Library | Latest release | Notes |
|---|---|---|
| React-Lua (`jsdotlua/react-lua`) | 17.2.1 (December 2024) | Follows React 17 semantics; distributed via Wally and npm-style packages |
| Fusion (`dphfox/Fusion`) | 0.3 (August 2024) | 0.3 introduced scopes; 0.2 code needs migration |
| Vide (`centau/vide`) | 0.4.1 (July 2026) | Small, fast, Solid-style reactivity |

Pin the version you use; APIs changed between Fusion 0.2 and 0.3 and examples online mix them.

---

## 1. The problem declarative UI solves

Imperative UI scales badly with the number of ways state can change. A backpack card depends on the item, whether it is equipped, whether it is selected, whether it is new, the player's currency (for the upgrade button), the device (phone layout), and filters. With imperative code each of those changes needs a handler that updates every affected object, and every handler must handle every other state. Bugs look like: the card shows "Equipped" after you unequipped from another screen; the upgrade button stays grey after you earned enough cash; filters show a stale count.

Declarative UI makes the output a **function of state**. When any input changes, the library recomputes what changed and updates only those properties. You stop writing "update" code.

The reference project is an instructive counter-example: an imperative UI of 90+ screens. It shipped and it looks good, but its notes are full of state bugs of exactly this class: "stale-false" pass ownership in two places, a badge that did not refresh, a "card X" that was not wired, a saved static copy that disagreed with the runtime build. None is hard; together they consumed many fix rounds.

---

## 2. React-Lua

React-Lua is a faithful port: components are functions returning elements, state lives in hooks, and a reconciler diffs element trees and applies changes to Roblox instances.

```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local e = React.createElement

local function CurrencyPill(props: { amount: number, color: Color3 })
	return e("TextLabel", {
		Size = UDim2.fromOffset(160, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = props.color,
		Text = tostring(props.amount),
		TextSize = 22,
		FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Bold),
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	})
end

local function Hud()
	local gems, setGems = React.useState(0)

	React.useEffect(function()
		local player = Players.LocalPlayer
		local function read()
			setGems(player:GetAttribute("Gems") or 0)
		end
		read()
		local conn = player:GetAttributeChangedSignal("Gems"):Connect(read)
		return function()
			conn:Disconnect() -- cleanup when the component unmounts
		end
	end, {})

	return e("ScreenGui", { ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, {
		Gems = e(CurrencyPill, { amount = gems, color = Color3.fromRGB(80, 140, 255) }),
		Claim = e("TextButton", {
			Position = UDim2.fromOffset(16, 64),
			Size = UDim2.fromOffset(120, 44),
			Text = "Claim",
			[React.Event.Activated] = function()
				-- send a request; state updates when the server changes the attribute
			end,
		}),
	})
end

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local root = ReactRoblox.createRoot(Instance.new("Folder"))
root:render(ReactRoblox.createPortal(e(Hud), playerGui))
```

Key ideas:

- `React.Event.Activated` and similar keys connect instance events; `React.Change.Property` listens to property changes.
- `useState`, `useEffect`, `useMemo`, `useRef`, `useContext` behave like React's.
- Global state is usually kept outside (a store such as a Rodux-style or signal-based module) and read through context or hooks.
- `createPortal` renders into an existing parent such as `PlayerGui`.

Strengths: huge conceptual ecosystem (React knowledge transfers), predictable data flow, component reuse. Weaknesses: verbose element syntax, reconciliation overhead, and React's model of re-running whole components makes per-frame animation through state a bad idea.

---

## 3. Fusion 0.3

Fusion is reactive: you create state objects and computed values, and instance properties bind directly to them. Only the properties that depend on a changed value update; there is no tree diff.

Fusion 0.3 introduced **scopes**: every object you create belongs to a scope, and cleaning the scope destroys everything in it.

```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local scope = Fusion.scoped(Fusion)

local gems = scope:Value(0)
local canAfford = scope:Computed(function(use)
	return use(gems) >= 100
end)

local player = Players.LocalPlayer
local function read()
	gems:set(player:GetAttribute("Gems") or 0)
end
read()
table.insert(scope, player:GetAttributeChangedSignal("Gems"):Connect(read)) -- cleaned with the scope

scope:New "ScreenGui" {
	Name = "FusionHud",
	ResetOnSpawn = false,
	Parent = player:WaitForChild("PlayerGui"),

	[Fusion.Children] = {
		scope:New "TextLabel" {
			Position = UDim2.fromOffset(16, 16),
			Size = UDim2.fromOffset(160, 40),
			Text = scope:Computed(function(use)
				return tostring(use(gems))
			end),
		},
		scope:New "TextButton" {
			Position = UDim2.fromOffset(16, 64),
			Size = UDim2.fromOffset(160, 44),
			Text = "Buy (100)",
			Interactable = canAfford,
			BackgroundColor3 = scope:Computed(function(use)
				return if use(canAfford) then Color3.fromRGB(105, 225, 0) else Color3.fromRGB(148, 160, 176)
			end),
			[Fusion.OnEvent "Activated"] = function()
				-- request purchase from the server
			end,
		},
	},
}

-- later, when this UI is no longer needed:
-- scope:doCleanup()
```

Fusion also ships animation primitives (`Tween` and `Spring` objects that follow a goal state), which fit UI motion naturally: bind `Size` to a spring of a computed target and hover effects become one line.

Strengths: fine-grained updates (cheap), concise, built-in springs and tweens. Weaknesses: smaller community than React, breaking changes between minor versions (0.2 to 0.3), and you must understand scopes or you leak.

### Vide

Vide is in the same family as Fusion (fine-grained reactive "sources" and "effects"), with a smaller API and a focus on performance. It is actively released (0.4.1 in July 2026). Choose it if you like Fusion's model and want something lighter; check its docs for the current API rather than translating Fusion code.

---

## 4. When declarative UI is worth it

| Situation | Recommendation |
|---|---|
| Inventory, trading, crafting, settings: many states, data-driven lists | Declarative pays off |
| Team of several UI programmers | Declarative (shared patterns, fewer cross-screen bugs) |
| A few static menus with art made by an artist in Studio | Imperative is fine |
| Heavy custom art (bevels, gloss, checker layers) built by designers | Hybrid: Studio templates for art, declarative for data |
| Per-frame visual effects (spinning sunbursts, shimmer) | Neither drives them through state; use tweens or one render loop |
| A short game jam | Whatever the team knows |

The cost of declarative UI is mostly learning and tooling, not runtime. The cost of imperative UI is state bugs that grow with every feature.

---

## 5. Hybrid: Studio art with declarative data

Artists want to tweak pixels in Studio; programmers want state-driven updates. A hybrid that works:

1. Artists build **templates** in Studio (a card, a row, a header) with named children.
2. Code clones a template and **binds** named children to state. In Fusion, `scope:Hydrate(instance) { Text = computed }` applies bindings to an existing instance. In React-Lua, wrap the template in a component that clones it in a ref and updates properties from props in an effect.
3. Lists are generated by the library (`ForValues` / `ForPairs` in Fusion, mapped children in React) so adding an item never needs manual layout code.

Keep a strict rule: **a property is owned by either the template or the binding, never both.** The reference project's worst UI bugs came from exactly this kind of double ownership (a runtime builder and a saved copy both defining a screen).

---

## 6. Performance traps

- **Animating through state.** Setting React state 60 times a second re-renders components 60 times a second. Animate with TweenService or springs on instances (Fusion's `Spring` is fine because it updates only the bound property).
- **Huge lists without virtualisation.** 600 declarative cards are still 600 sets of instances. Virtualise (see [[UI Layout Objects - Lists Grids and Pages]]).
- **Unstable keys.** In React, list children keyed by index re-create instances when the list reorders. Key by stable ids (item uid).
- **Leaks.** Every connection created inside a component or computed must be cleaned: `useEffect` cleanup functions in React, scopes in Fusion. Leaks show up as UI updates that keep firing after a screen closed. See [[Memory Budgets and Leaks]].
- **Computeds that do work.** A Fusion `Computed` that loops over the whole inventory runs whenever any dependency changes. Keep heavy derivations in a data layer and expose the results.

---

## 7. Architecture around the library

Whatever library you pick, the surrounding architecture is the same:

- **The server is the source of truth.** UI state mirrors replicated data (attributes, a replicated profile table, or remote updates), and UI actions send requests. Never let UI state be the authority for currency or items ([[Server Authority and Validation]]).
- **One client store** holding the replicated profile and session state; UI reads from it.
- **Screens as components** registered with a presenter that enforces one-open-at-a-time and the band plan of `DisplayOrder`s ([[ScreenGui Fundamentals]]).
- **Device and accessibility as state.** The device profile and settings like reduced motion are values components read, so a phone layout is just another branch of the render function ([[Responsive UI for Phone Tablet Console and PC]], [[Accessibility]]).

---

## 8. Migrating an imperative UI

Rewriting a shipped UI is rarely justified. Migrate where the state bugs are:

1. **Pick the worst screen.** The one with the most "stale state" bugs (usually inventory or trading) gets a declarative rewrite first. Leave simple, static menus imperative.
2. **Create the client store before any component.** Replicated profile data, session state (selected item, open tab), device profile and settings in one module with change signals. Imperative screens can read the same store, which already removes a class of bugs (two screens disagreeing).
3. **Mount the new screen in its own `ScreenGui`** with its own `DisplayOrder` in your band plan, so old and new code never fight over the same instances.
4. **Keep names and attributes other systems rely on.** Tutorials, tap pads and analytics in the reference project found buttons by name or by a `TutHook` attribute; a rewritten screen must keep those hooks or the tutorial breaks silently.
5. **Measure.** Compare open time and frame time of the old and new screen on a low-end phone before migrating the next one.

### Testing declarative UI

Because output is a function of state, components are easy to test in isolation: render with a fake store in Edit mode (off-screen, as the reference project did for its phone checks), assert on properties, and destroy. Snapshot-style checks (render, read every object's `AbsoluteSize` and `Text`, compare against a stored table) catch layout regressions across devices when combined with the viewport list in [[Responsive UI for Phone Tablet Console and PC]]. See [[Testing Strategies and Frameworks]].

---

## Common mistakes

- Starting with Roact in new code.
- Mixing Fusion 0.2 and 0.3 examples.
- Animating via component state every frame.
- Properties set both by a Studio template and by a binding.
- Lists keyed by index.
- Forgetting to clean scopes and effects.
- UI state treated as authoritative for currency or items.

## Checklist

- [ ] Library and version pinned (Wally or packages folder).
- [ ] Server-replicated data feeds one client store.
- [ ] Each property has exactly one owner.
- [ ] Animation through tweens or springs, not render-loop state.
- [ ] Long lists virtualised; keys stable.
- [ ] Every connection cleaned on unmount.

See also: [[Project Structure and Bootstrapping]], [[Frameworks - Knit Matter and Others]], [[External Tooling - Rojo Wally Selene StyLua]], [[Luau Type System and Strict Mode]], [[UI Design Systems]], [[UI and GUI Animation]].

## Connected notes
<!-- auto-links:start -->
[[Links - UI frameworks]] · [[Tween vs Spring]] · [[Cookbook - UI]] · [[Plugin UI with DockWidgets]] · [[Tools and Inventory Systems]] · [[Code Pipeline - Rojo Git and CI]]
<!-- auto-links:end -->
