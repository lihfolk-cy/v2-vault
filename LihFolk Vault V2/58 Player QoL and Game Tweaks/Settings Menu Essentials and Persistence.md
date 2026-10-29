---
tags: [qol, settings, persistence, datastore, schema, defaults, reset, remotes, type/guide, area/ui, area/data, level/intermediate, api/DataStoreService, api/RemoteEvent]
---
# Settings Menu Essentials and Persistence

<!-- tldr:start -->
> [!tldr] TL;DR
> - Settings reset every join: Saved in a client-only table -> Store in the server profile
> - DataStore throttling warnings: One write per slider tick -> Profile autosave; client debounce
> - Exploiter sets FOV to 9e9 or NaN: No server validation -> Shared schema `sanitize` on the server
> - Audio, graphics, camera, comfort, interface and controls groups exist.
> - One shared schema with type, range, step and default.
> - Server sanitises every key and caps patch size and rate.
>
> Cost: TL;DR ~160 tok · whole note ~2.4k tok. Read more: ## 2. One schema, shared by client and server · ## 3. Save only what differs from the default · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Players who cannot turn the music down, stop the shaking or enlarge text simply leave. This note covers what to expose, per-player server storage, defaults you can change after launch, and reset. Screen layout is in [[Menu Archetypes - Shop Settings Codes Rewards]]; this is the data underneath.

Sources: **Roblox docs** for DataStore limits (https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits) and remotes (https://create.roblox.com/docs/reference/engine/classes/RemoteEvent). Everything else is **Rule of thumb** from shipped games.

## 1. What to expose

Minimum set (**Rule of thumb**), grouped the way players look for them:

| Group | Settings | Default |
|---|---|---|
| Audio | Master, Music, SFX, UI volume; mute music | 0.8 / 0.6 / 0.8 / 0.7 |
| Graphics | Detail preset (Auto, Low, Medium, High), VFX density, shadows | Auto |
| Camera | FOV, shake intensity, sensitivity multiplier (custom cameras only) | 70, 100%, 1.0 |
| Comfort | Screen flashes, damage numbers, hit-stop, reduced motion override | On, but respect `GuiService.ReducedMotionEnabled` |
| Interface | UI scale, HUD visibility, compact mode, colour palette, tooltips | 1.0, on, off, default, on |
| Controls | Sprint hold/toggle, auto-equip, rebinding, touch layout | Hold, on |

Do not re-expose what Roblox already owns: graphics quality slider, mouse sensitivity, camera invert, shift lock and master volume all live in the Roblox menu. Read them where useful (see [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]]), and never fight them.

## 2. One schema, shared by client and server

A schema module in `ReplicatedStorage` lists every key with its type, range and default. The client uses it to build sliders; the server uses it to reject junk. Adding a setting means adding one line.

```lua
--!strict
-- ReplicatedStorage/Shared/SettingsSchema
export type Spec = {
	kind: string, -- "number" | "bool" | "choice"
	default: any,
	min: number?, max: number?, step: number?,
	options: { string }?,
}

local Schema: { [string]: Spec } = {
	masterVolume = { kind = "number", default = 0.8, min = 0, max = 1, step = 0.05 },
	fov = { kind = "number", default = 70, min = 60, max = 100, step = 1 },
	flashes = { kind = "bool", default = true },
	graphics = { kind = "choice", default = "auto", options = { "auto", "low", "medium", "high" } },
	-- ...one line per setting; other notes in this section add their keys here
}

local M = { Schema = Schema }

function M.sanitize(key: string, value: any): any
	local spec = Schema[key]
	if spec == nil then return nil end
	if spec.kind == "number" then
		if typeof(value) ~= "number" or value ~= value then return nil end -- rejects NaN
		local step = spec.step or 1
		local v = math.clamp(value, spec.min :: number, spec.max :: number)
		return math.round(v / step) * step
	elseif spec.kind == "bool" then
		return if typeof(value) == "boolean" then value else nil
	end
	if typeof(value) ~= "string" then return nil end
	return if table.find(spec.options :: { string }, value) then value else nil
end

function M.defaults(): { [string]: any }
	local out = {}
	for key, spec in Schema do out[key] = spec.default end
	return out
end

return M
```

## 3. Save only what differs from the default

Store the player's overrides, not the full table. If you later decide the default music volume is too loud, everyone who never touched it gets the new default; everyone who chose a value keeps it. It also keeps the save small.

```lua
--!strict
-- ServerScriptService/SettingsService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Schema = require(ReplicatedStorage.Shared.SettingsSchema)
local PlayerData = require(script.Parent.PlayerData) -- your session-locked profile wrapper

local setRemote = ReplicatedStorage.Remotes.SetSettings :: RemoteEvent
local getRemote = ReplicatedStorage.Remotes.GetSettings :: RemoteFunction

local RateLimit = require(script.Parent.RateLimit) -- token bucket, see Rate Limiting and Abuse Prevention
local allow = RateLimit.new(40, 60) -- 40 patches per minute; the client batches anyway

setRemote.OnServerEvent:Connect(function(player: Player, patch: any)
	if typeof(patch) ~= "table" or not allow(player) then return end
	local data = PlayerData.get(player)
	if data == nil then return end
	local seen = 0
	for key, value in patch do
		seen += 1
		if seen > 32 then break end
		if typeof(key) ~= "string" then continue end
		local clean = Schema.sanitize(key, value)
		if clean == nil then continue end
		-- nil means "use the current default"
		data.settings[key] = if clean == Schema.Schema[key].default then nil else clean
	end
end)

getRemote.OnServerInvoke = function(player: Player)
	local data = PlayerData.waitFor(player, 15) -- returns nil on timeout
	return if data then data.settings else {}
end
```

Fetching with a `RemoteFunction` invoked by the client avoids the race where the server fires settings before the client's listener exists.

The settings ride on the profile's normal autosave. Never call `SetAsync` per slider move: DataStores allow roughly one write per key every 6 seconds (**Roblox docs**, limits page), and a slider fires dozens of changes a second. See [[Saving Correctly - Autosave and BindToClose]] and [[Session Locking and Profile Libraries]].

## 4. The client: apply instantly, send later

```lua
--!strict
-- StarterPlayerScripts/ClientSettings (ModuleScript)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Schema = require(ReplicatedStorage.Shared.SettingsSchema)
local setRemote = ReplicatedStorage.Remotes.SetSettings :: RemoteEvent
local getRemote = ReplicatedStorage.Remotes.GetSettings :: RemoteFunction

local values = Schema.defaults()
local pending: { [string]: any } = {}
local token = 0
local changed = Instance.new("BindableEvent")

local M = { Changed = changed.Event } -- fires (key, value)

function M.get(key: string): any return values[key] end

function M.flush()
	if next(pending) == nil then return end
	setRemote:FireServer(pending)
	pending = {}
end

function M.set(key: string, value: any)
	local clean = Schema.sanitize(key, value)
	if clean == nil or values[key] == clean then return end
	values[key] = clean
	pending[key] = clean
	changed:Fire(key, clean)
	token += 1
	local mine = token
	task.delay(1, function() if mine == token then M.flush() end end)
end

task.spawn(function()
	local ok, saved = pcall(getRemote.InvokeServer, getRemote)
	if not ok or typeof(saved) ~= "table" then return end
	for key, value in saved do
		local clean = Schema.sanitize(key, value)
		if clean ~= nil then values[key] = clean; changed:Fire(key, clean) end
	end
end)

return M
```

Every system (audio, camera, HUD) reads `get` once and listens to `Changed`. Call `flush()` when the menu closes so a quick leave does not lose the last change.

## 5. Reset that people trust

Reset is `ClientSettings.set(key, Schema.Schema[key].default)` for each key in a section. Offer **per-section reset** (a broken camera should not reset audio), mark the default on each slider, and **confirm "reset all"**.

## 6. Device-specific values

A graphics preset chosen on a phone is wrong on a PC. Store device-bound keys per platform bucket (`graphics_touch`, `graphics_desktop`, `graphics_console`, chosen from `UserInputService.PreferredInput`). **Rule of thumb**: audio, comfort and palette follow the account; graphics and touch layout follow the device.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Settings reset every join | Saved in a client-only table | Store in the server profile |
| DataStore throttling warnings | One write per slider tick | Profile autosave; client debounce |
| Exploiter sets FOV to 9e9 or NaN | No server validation | Shared schema `sanitize` on the server |
| New default never reaches anyone | Full table saved | Save only overrides |
| HUD flashes default size then jumps | Settings applied after UI shows | Fetch settings before revealing HUD |
| Phone gets the PC's High preset | Graphics stored per account | Per-device bucket |

## Checklist

- [ ] Audio, graphics, camera, comfort, interface and controls groups exist.
- [ ] One shared schema with type, range, step and default.
- [ ] Server sanitises every key and caps patch size and rate.
- [ ] Only overrides are saved; saving rides the profile autosave.
- [ ] Client applies instantly, batches sends, flushes on menu close.
- [ ] Per-section reset plus confirmed reset-all.
- [ ] Device-specific settings bucketed by platform.

## See also

- [[Menu Archetypes - Shop Settings Codes Rewards]]
- [[Server Authority and Validation]]
- [[DataStore Fundamentals]]
- [[Rate Limiting and Abuse Prevention]]
- [[Player QoL Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Graphics and Performance Toggles for Low-End Devices]] · [[Audio Mixer Settings with SoundGroups]] · [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]] · [[UI Scale HUD Hide and Compact Mode]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[QoL Audit Checklist]] · [[Top 25 QoL Wins by Effort]] · [[Accessibility Cross-Links for QoL Settings]] · [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]] · [[Mobile Button Layout Editor]] · [[Controller Support QoL]] · [[Skippable Tutorials and Replayable Tips]] · [[Rebinding Controls with the Input Action System]]
<!-- related:end -->
