---
tags: [worked-build, shooter, arena, hitscan, server-validation, respawn, scoreboard, remotes, anti-exploit, fast-ship, type/build, area/gameplay]
---
# Weekend Build - Arena Shooter with Server-Checked Hits

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Trusting `claimedHit` for damage. Exploiters send any instance.
> - Avoid: Server raycast from `HumanoidRootPart` while the client fires from the camera.
> - Avoid: No slack in rate limits. Honest players lose shots.
> - Damage, interval and range come from shared config; server enforces.
> - Server re-raycasts from a tolerance-checked origin; ignores claimed hit for damage.
> - Rate limit with jitter slack; unit-direction check.
>
> Cost: TL;DR ~150 tok · whole note ~2.6k tok. Read more: ## 4. Client: fire and predict · ## 5. Server: validate, then damage · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A free-for-all arena shooter you can build in a weekend: one hitscan blaster, server-validated hits, respawns with brief spawn protection, kill credit and a live scoreboard. It is deliberately small: no ranked mode, no attachments, no lag compensation history buffer (a capped tolerance instead). The point is a correct skeleton you can extend, built on the rules in [[Genre Playbook - Shooters FPS and TPS]].

Source labels: **Roblox docs**, **Rule of thumb**. Code is original, reviewed but not run as a whole; test each piece in a two-client Studio session ([[Testing Modes - Play Run and Multi-Client]]).

## 1. What you are building

- Players spawn with a blaster `Tool`. Click fires a ray from the camera; the client shows a tracer and impact immediately.
- The client sends `Fire(origin, direction, claimedHit)` to the server. The server checks fire rate, origin plausibility, re-raycasts and applies damage.
- Death: kill credited to the last validated attacker within a time window; respawn after 3 s with 2 s spawn protection.
- Scoreboard: kills and deaths via `leaderstats` (default player list) plus a top-3 HUD.
- Round: first to 20 kills or 8 minutes, then a 15 s intermission and reset.

Time budget (rule of thumb): Saturday for weapon, validation and respawn; Sunday for scoreboard, round loop, map and polish.

## 2. Layout

```
ReplicatedStorage/Shared/WeaponConfig      (ModuleScript)
ReplicatedStorage/Remotes/Fire             (RemoteEvent)
ReplicatedStorage/Remotes/HitConfirm       (RemoteEvent, server -> shooter)
ServerScriptService/CombatService          (Script)
ServerScriptService/RoundService           (Script)
StarterPack/Blaster                        (Tool with Handle)
StarterPack/Blaster/BlasterClient          (LocalScript)
```

## 3. Shared config

```lua
--!strict
return {
	Damage = { Head = 50, Body = 25 },
	FireInterval = 0.18,        -- seconds between shots
	Range = 300,                -- studs
	OriginTolerance = 12,       -- studs between claimed origin and server head position
	SpawnProtection = 2,        -- seconds
	RespawnDelay = 3,
	KillCreditWindow = 8,       -- seconds
	KillsToWin = 20,
	RoundLength = 8 * 60,
}
```

Shared so the client can show cooldowns and the server enforces the same numbers. The server never trusts a damage value from the client; it looks it up here.

## 4. Client: fire and predict

```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.WeaponConfig)
local FireRemote = ReplicatedStorage.Remotes.Fire :: RemoteEvent

local tool = script.Parent :: Tool
local player = Players.LocalPlayer
local lastShot = 0

tool.Activated:Connect(function()
	local now = os.clock()
	if now - lastShot < Config.FireInterval then return end
	lastShot = now
	local camera = workspace.CurrentCamera
	local mouse = player:GetMouse()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local result = workspace:Raycast(ray.Origin, ray.Direction * Config.Range, params)
	-- local tracer and impact here (see Impact Decals note)
	FireRemote:FireServer(ray.Origin, ray.Direction, result and result.Instance or nil)
end)
```

`GetMouse` is fine for a weekend build on desktop; for touch and gamepad, move to screen-centre aiming or the input action system ([[Server Authority and Input Migration 2026]]).

## 5. Server: validate, then damage

```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.WeaponConfig)
local FireRemote = ReplicatedStorage.Remotes.Fire :: RemoteEvent
local HitConfirm = ReplicatedStorage.Remotes.HitConfirm :: RemoteEvent

local lastFire: {[Player]: number} = {}
local lastAttacker: {[Humanoid]: {player: Player, t: number}} = {}

local function isProtected(character: Model): boolean
	local untilT = character:GetAttribute("ProtectedUntil")
	return typeof(untilT) == "number" and os.clock() < untilT
end

FireRemote.OnServerEvent:Connect(function(player, origin, direction, _claimed)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then return end
	if direction.Magnitude < 0.5 or direction.Magnitude > 1.5 then return end -- expect a unit vector
	local now = os.clock()
	if now - (lastFire[player] or 0) < Config.FireInterval * 0.8 then return end -- small jitter slack
	lastFire[player] = now

	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (head and humanoid) or humanoid.Health <= 0 then return end
	if (origin - head.Position).Magnitude > Config.OriginTolerance then return end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance }
	local result = workspace:Raycast(origin, direction.Unit * Config.Range, params)
	if not result then return end

	local victimModel = result.Instance:FindFirstAncestorOfClass("Model")
	local victimHum = victimModel and victimModel:FindFirstChildOfClass("Humanoid")
	if not (victimModel and victimHum) or victimHum.Health <= 0 or isProtected(victimModel) then return end

	local isHead = result.Instance.Name == "Head"
	victimHum:TakeDamage(if isHead then Config.Damage.Head else Config.Damage.Body)
	lastAttacker[victimHum] = { player = player, t = now }
	HitConfirm:FireClient(player, isHead)
end)

Players.PlayerRemoving:Connect(function(p) lastFire[p] = nil end)

return lastAttacker -- if moved to a ModuleScript, RoundService reads kill credit from here
```

Why this shape:

- **The server re-raycasts from the claimed origin**, bounded by distance to the server's view of the head. This stops "shoot from across the map" and wall-through claims, while tolerating normal latency. The claimed hit instance is ignored for damage; it is useful only for logging mismatches.
- **The re-raycast uses current server positions**, so fast-moving targets at high ping will sometimes miss on the server when the shooter saw a hit. That is the weekend trade-off. The next step is a short position history and capped rewind, described in the shooter playbook.
- **`TakeDamage` respects `ForceField`s**; if you prefer a visible spawn shield, a `ForceField` in the character is an alternative to the attribute (Roblox docs, `Humanoid:TakeDamage`).
- **Rate limit with slack.** Exactly-equal intervals reject honest players whose packets bunch up.

## 6. Respawn, credit and scoreboard

- On `Humanoid.Died`, look up `lastAttacker[humanoid]`; credit a kill if within `KillCreditWindow` and the attacker is not the victim. Increment `leaderstats.Kills` and the victim's `Deaths`.
- Disable auto-respawn (`Players.CharacterAutoLoads = false`), wait `RespawnDelay`, call `player:LoadCharacterAsync()` (the non-deprecated form in the 2026 API), choose the spawn farthest from living enemies, and set `ProtectedUntil = os.clock() + SpawnProtection` on the new character. Clear protection early if the player fires.
- Clean up `lastAttacker` entries when characters are removed so the table does not grow.

Spawn selection and protection details are covered in [[Spawn Points Safe Zones and Respawn Flow]].

## 7. Round loop

`RoundService` runs: intermission (15 s), round (until `KillsToWin` or `RoundLength`), announce winner, reset leaderstats, respawn all. Reuse the structure from [[Round-Based Minigame Loop End to End]]; an arena is a single "minigame" that never rotates.

## 8. Exploits it must resist

| Attack | Defence in this build |
|---|---|
| Rapid fire | Server interval check |
| Damage edit | Damage from config, not client |
| Shooting from elsewhere | Origin tolerance to server head position |
| Wall-through | Server re-raycast |
| Killing protected players | Attribute or ForceField check |
| Aimbot | Not solvable server-side in a weekend; log headshot ratio for review ([[Detecting Combat Exploits - Reach Rate and Aim]]) |

## Common mistakes

- **Trusting `claimedHit` for damage.** Exploiters send any instance.
- **Server raycast from `HumanoidRootPart`** while the client fires from the camera. Over-the-shoulder shots get blocked; use a head or camera-aligned origin and tolerance.
- **No slack in rate limits.** Honest players lose shots.
- **Forgetting R15 multi-part hits** in shotgun extensions: dedupe by model per shot.
- **Using deprecated `LoadCharacter`.** Use `LoadCharacterAsync`.
- **Leaderstats written from the client.** Server only.

## Checklist

- [ ] Damage, interval and range come from shared config; server enforces.
- [ ] Server re-raycasts from a tolerance-checked origin; ignores claimed hit for damage.
- [ ] Rate limit with jitter slack; unit-direction check.
- [ ] Kill credit window; leaderstats server-side; tables cleaned on removal.
- [ ] Respawn delay, farthest-spawn selection, spawn protection that ends on firing.
- [ ] Two-client test with simulated latency.

## See also

- [[Genre Playbook - Shooters FPS and TPS]]
- [[Raycasts Shapecasts and Spatial Queries]]
- [[Projectiles and Ballistics]]
- [[Spawn Points Safe Zones and Respawn Flow]]
- [[Arena Rounds with Teams and Spectating End to End]]
- [[Detecting Combat Exploits - Reach Rate and Aim]]

## Connected notes

[[Impact Decals and Material-Aware Hit Sparks]] · [[Round-Based Minigame Loop End to End]] · [[Global Leaderboards End to End]] · Server Authority and Validation · [[Worked Builds Start Here]]

<!-- related:start -->
## Related
[[Melee Combat System End to End]] · [[Weekend Build - Roleplay Town with Jobs and Paychecks]] · [[Weekend Build - Survival Gather, Craft and Place]] · [[Quest Chain System End to End]] · [[Daily Rewards System End to End]] · [[Rebirth and Prestige System End to End]] · [[Saved Inventory End to End]] · [[Codes Redemption System End to End]]
<!-- related:end -->
