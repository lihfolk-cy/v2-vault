---
tags: [gameplay, characters, humanoid, spawning, health, states, type/guide, area/gameplay, level/intermediate, api/Humanoid, api/ForceField, api/HipHeight]
---
# Characters and Humanoids

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: `SetStateEnabled` on the server for a player -> Run it on the client
> - Avoid: Long `MoveTo` -> Re-issue or use waypoints
> - Avoid: Setting Health for damage -> `TakeDamage` or check shields yourself
> - One damage function; Health written only by the server.
> - Movement-state edits happen on the owning machine.
> - Character scale decided before ranges are tuned.
>
> Cost: TL;DR ~130 tok · whole note ~4.4k tok. Read more: ## 2. Movement properties and their defaults · ## 6. Keeping players in the world (production guards) · ## 9. Common mistakes · ## Checklist
<!-- tldr:end -->

The `Humanoid` is the most used and least understood object in Roblox. It is a movement controller, a state machine, a health container, an appearance applier and a network-ownership anchor in one. Most "my character does something weird" bugs come from not knowing which of those jobs is running, on which machine. This note covers the character model, the Humanoid's properties and states, health and death, spawning and respawning, scaling, and the production failure modes (wall-jump exploits, players stuck in geometry, falling through the world).

Animation-side detail lives in the Animation section: [[Humanoid States and Animation]], [[The Default Animate Script]], [[R15 Rig Anatomy and Attachments]], [[Custom Characters and StarterCharacter]].

Source labels: **Docs** (checked October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. What a character is

A player character is a `Model` with:

| Piece | Job |
|---|---|
| `HumanoidRootPart` | Invisible root of the assembly; the Humanoid's `RootPart`; network ownership follows it |
| Body parts (R15: 15 MeshParts; R6: 6 Parts) | Visuals and collision |
| `Motor6D` joints (or `AnimationConstraint`s) | Joints the Animator drives |
| `Humanoid` | Movement, states, health, appearance |
| `Animator` (child of Humanoid) | Plays animation tracks |
| Accessories, clothing, `BodyColors`, scale `NumberValue`s | Appearance from the player's `HumanoidDescription` |
| `Animate` LocalScript, `Health` Script | Default locomotion animation and regeneration |

The character is one rigid assembly rooted at `HumanoidRootPart` (see [[Physics Assemblies and Constraints]]) and it is **owned by its player's client**. That single fact explains most of this note: the client simulates the body, so the client decides where it is, and anything the server does to its physics arrives late or is overwritten.

**Measured.** In Edit mode, `Players:CreateHumanoidModelFromDescriptionAsync` produced rigs with `AnimationConstraint` joints and no Motor6Ds in the reference project. Code that walks a character's joints should accept both kinds.

---

## 2. Movement properties and their defaults

| Property | Default (Docs) | Notes |
|---|---|---|
| `WalkSpeed` | 16 studs/s | From `StarterPlayer.CharacterWalkSpeed` |
| `JumpPower` | 50 | Used when `UseJumpPower` is true; range 0 to 1000 |
| `JumpHeight` | 7.2 studs | Used when `UseJumpPower` is false |
| `UseJumpPower` | from `StarterPlayer.CharacterUseJumpPower` (default true) | Pick one model and stick to it |
| `MaxSlopeAngle` | 89 degrees | Range 0 to 89 |
| `HipHeight` | rig dependent | R15: height = `0.5 * RootPart.Size.Y + HipHeight` |
| `AutoRotate` | | True turns the character to face its movement |

Rules of thumb:
- **Change speeds on the server or the client, not both.** WalkSpeed replicates server to client, and the client's change is simulated locally (it owns the body). A server sprint system that sets WalkSpeed is honest but feels laggy; a client sprint system feels instant but is trivially exploitable. Production answer: the client sets WalkSpeed for feel, the server measures actual speed for anti-cheat ([[Exploits and Anti-Cheat]]).
- **[[HipHeight]] is not "leg length".** It is the distance the Humanoid holds the root above the floor. Scaling a custom rig without fixing HipHeight gives a character that sinks into or floats above the ground. The reference project stored the old value in an attribute (`PreProHipHeight`) before fixing 17 enemy templates: always keep the original when you change it in bulk.
- **Large characters.** The reference project scales player characters 1.6x (about 9 studs tall). Every range (melee reach, ability radius, prompt distance, camera offset, door heights) had to account for it. Decide character scale before tuning anything else; re-tuning ranges afterwards touches every system. See [[Scale and Animation]].

### Moving a Humanoid from code
- `Humanoid:Move(direction, relativeToCamera?)`: sets the desired direction. The default control scripts overwrite it every frame unless you bind after them or replace them (Docs). Server calls need network ownership.
- `Humanoid:MoveTo(position, part?)`: walk to a point. Times out after **8 seconds** and counts arrival within about 1 stud (Docs). `MoveToFinished(reached)` fires on arrival or timeout. A long path must be fed waypoint by waypoint ([[Pathfinding]]).
- `MoveDirection`: world-space unit (or zero) vector of the current input. Read it; it is the cleanest signal for "is the player trying to move".

The MoveTo timeout is the classic NPC bug: an NPC walking to a point more than 8 seconds away stops part way and the script thinks it arrived. Re-issue `MoveTo` on each `MoveToFinished` with `reached == false`, or move in shorter legs.

---

## 3. The state machine

`Humanoid:GetState()` returns a `HumanoidStateType`: `Running`, `RunningNoPhysics`, `Climbing`, `StrafingNoPhysics`, `Jumping`, `Freefall`, `Landed`, `Swimming`, `Seated`, `PlatformStanding`, `FallingDown`, `Ragdoll`, `GettingUp`, `Flying`, `Physics`, `Dead`, `None`.

| Method | Behaviour (Docs) |
|---|---|
| `SetStateEnabled(state, bool)` | A disabled state cannot be entered by `ChangeState` or internal code. **Not replicated** either way |
| `ChangeState(state)` | Works from a LocalScript if the client owns the character, from a server Script if the server does |
| `EvaluateStateMachine = false` | No forces, no floor sensing, no automatic transitions; state events, appearance and `Move` input still work |

Because `SetStateEnabled` does not replicate, disabling a state on the server for a player does nothing to the player's simulation. Disable states **on the owning client**. The common case: disable `FallingDown` and `Ragdoll` on players so a hard landing never trips them:

```lua
--!strict
-- StarterCharacterScripts LocalScript
local character = script.Parent :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
```

**Measured: the wall-jump exploit.** The reference project had a double jump and wall jump whose counters refilled "when grounded". Grounded was `FloorMaterial ~= Air`, and the Humanoid reports a floor material when standing on steep geometry, so players refilled their jumps against walls and climbed anything. The fix:
- grounded = `FloorMaterial ~= Air` **and** a solid-floor check of five short downward rays where at least one hit has `Normal.Y >= 0.55`;
- while standing on a "wall floor", the native `Jumping` state is disabled on the client.

General lesson: `FloorMaterial` is "touching something", not "standing on flat ground". If a mechanic rewards being grounded, verify the ground with rays ([[Raycasts Shapecasts and Spatial Queries]]).

---

## 4. Health, damage and death

| Fact | Source |
|---|---|
| `Health` is clamped to 0..`MaxHealth`, held at 0 when dead | Docs |
| The default `Health` script regenerates 1% of MaxHealth per second for living player characters | Docs |
| `TakeDamage(n)` respects a `ForceField`; setting `Health` directly bypasses it | Docs |
| `SpawnLocation.Duration` default 10 s of [[ForceField]] on spawn | Docs |
| `BreakJointsOnDeath` default true; `RequiresNeck` default true | Docs |

Server rules for health (rule of thumb, and enforced in the reference project):
- **Only the server writes `Health`.** Health replicates from server to client. A client writing its own Health changes only its local copy.
- **Route all damage through one function.** Shields, damage reduction traits, i-frames, tutorial protection and kill credit all need to see every hit. The reference project's player damage path (`hurt` in its fighters module) checks dash i-frames first, then guard/parry, then multipliers, for every source (enemy swings, projectiles, lava, lingering fields). When it added boss dodging, it changed one function.
- **Remove `Health` regeneration if your game has its own.** Delete or replace the `Health` script by putting a script named `Health` in `StarterCharacterScripts`; otherwise you get double regeneration.
- **Death is a state, not an event you control.** `Humanoid.Died` fires once when Health reaches 0. With `BreakJointsOnDeath` true the joints break and the character falls apart; set it false for death animations or ragdolls ([[Procedural Death Knockdown and Hit Reactions]]).
- **Neck removal kills.** With `RequiresNeck` true, destroying the Neck joint kills the character. Custom rigs and accessory scripts that rebuild joints can kill players by accident.

### Separate "game health" from Humanoid health?
Many combat games keep their own health number (attribute) and drive `Humanoid.Health` from it or ignore it. Reasons: big numbers (millions of HP), percent-based damage, KO states that are not death, and PvP arenas with normalised damage.

**Measured.** The reference project keeps a separate fight health for its combat body (a KO, 4 s, then recovery) and falls back to `Humanoid.Health/MaxHealth` for the HUD only where no fight health exists (the hub). Its PvP arena normalises damage to a percentage of the victim's fight health so any weapon is fair, with a 3 s KO, respawn in an alcove and a 2 s ForceField.

---

## 5. Spawning and respawning

| Setting | Default | Notes |
|---|---|---|
| `Players.CharacterAutoLoads` | true | False = you call `LoadCharacterAsync` yourself |
| `Players.RespawnTime` | 5 s | Delay after death when auto-loading |
| `Player:LoadCharacterAsync()` | | Current docs mark `LoadCharacter()` superseded by it. It replaces the old character and clears the player's Backpack and PlayerGui (Docs) |

Order of events on spawn:
1. `Player.CharacterAdded(character)`: the model exists, parented to Workspace. Appearance may still be loading.
2. `Player.CharacterAppearanceLoaded(character)`: accessories and clothing are in.
3. Scripts in `StarterCharacterScripts` run inside the new character.

Common bugs:
- **Missing the first character.** `PlayerAdded` connects `CharacterAdded` after the first character has spawned in fast Studio tests. Always handle `player.Character` immediately as well as connecting.
- **Holding references to old characters.** Every respawn is a new model. Connections to the old Humanoid leak unless you disconnect them or let them die with the model (Destroy disconnects). Keep per-character state in a table keyed by the character and clear it on `AncestryChanged`/`Destroying`.
- **Spawn invulnerability is not universal.** The ForceField only protects against damage that uses `TakeDamage` or checks for ForceFields (Docs). If your damage code sets Health or uses its own health, check for the spawn shield yourself.

Spawn placement, teams and rounds: [[Spawning Teams and Rounds]].

---

## 6. Keeping players in the world (production guards)

Two guards from the reference project are worth copying because their failure modes are universal.

### Unstuck guard (client)
Abilities that teleport or dash could leave a character inside walls. A LocalScript checks every frame whether a small core box inside the root (0.45 x 0.7 x 0.45 of the root's size) overlaps solid static world geometry: anchored, colliding parts that are not inside a Humanoid or AnimationController model or a Tool, plus terrain (voxel occupancy above 0.85, not water). It remembers the last clear CFrame; two stuck frames in a row put the player back there with rotation kept and velocity cleared. It skips while the root is anchored or a cutscene lock is set.

```lua
--!strict
-- Simplified unstuck guard (LocalScript in StarterCharacterScripts).
local RunService = game:GetService("RunService")

local character = script.Parent :: Model
local root = character:WaitForChild("HumanoidRootPart") :: BasePart

local params = OverlapParams.new()
params.ExcludeInstances = { character }
params.RespectCanCollide = true -- only parts that actually collide

local lastClear = root.CFrame
local stuckFrames = 0

local function isSolidWorld(p: BasePart): boolean
	if not p.Anchored or not p.CanCollide then return false end
	local model = p:FindFirstAncestorOfClass("Model")
	if model and (model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")) then
		return false
	end
	return p:FindFirstAncestorOfClass("Tool") == nil
end

RunService.PostSimulation:Connect(function()
	if root.Anchored or character:GetAttribute("CutsceneLock") then
		stuckFrames = 0
		return
	end
	local core = root.Size * Vector3.new(0.45, 0.7, 0.45)
	local stuck = false
	for _, p in workspace:GetPartBoundsInBox(root.CFrame, core, params) do
		if isSolidWorld(p) then
			stuck = true
			break
		end
	end
	if stuck then
		stuckFrames += 1
		if stuckFrames >= 2 then
			root.CFrame = lastClear
			root.AssemblyLinearVelocity = Vector3.zero
			stuckFrames = 0
		end
	else
		stuckFrames = 0
		lastClear = root.CFrame
	end
end)
```

`GetPartBoundsInBox` uses bounding boxes, so a large rotated mesh can report a false overlap; the real guard used exact tests for meshes. Terrain needs a separate check (`Terrain:ReadVoxels` around the root). Use `GetPartsInPart` if false positives appear ([[Raycasts Shapecasts and Spatial Queries]]).

### Fall guard (server)
A server script records each player's last grounded position every 0.25 s. Falling more than 55 studs below it (only in the hub, where no legit drops exist) or below y -60 anywhere returns them there, 4 studs up, velocity cleared, with a 1.5 s ForceField. A sideways move of more than 400 studs between samples counts as a teleport and resets the safe spot.

Lesson from narrowing it: a global "fell 55 studs" rule broke legitimate drops, boss knock-ups and void teleports in the combat realm. **Fall rules must be per area.** And invisible edge walls must exist only on the outer edge: an early version that walled every inner gap stopped players jumping across their own hub.

---

## 7. NPC Humanoids: when not to use one

A Humanoid on every NPC is convenient (Animator, health, MoveTo, nametag) and expensive: each runs floor sensing and state logic every frame on its owner. Options:

| NPC count | Approach |
|---|---|
| Up to a few dozen, need Humanoid features | Humanoid, server-owned, `SetNetworkOwner(nil)` |
| Dozens to hundreds | `AnimationController` + `Animator`, movement by movers or CFrame, own health attribute |
| Hundreds+, simple | Anchored roots moved by the server at low rate, smoothed on clients |

**Measured.** The reference project's enemies have a Humanoid-shaped rig (HumanoidRootPart + Animator) but movement by server-owned AlignPosition movers and their own health and poise numbers, with animation played by a custom player on clients. See [[NPC AI and Behaviour]] and [[Enemy and NPC Animation]].

---

## 8. Attributes as step-aside flags

Many systems want to control the same character: locomotion, combat, abilities, cutscenes, freezes. The reference project uses character attributes as flags that other systems read before acting: `GuardingLocal`, `FlourishLocal`, `KitControl`, `CutsceneLock`, `FrozenUntil`/`FreezeImmuneUntil` (an ice ball freezes for 1.2 s with 2 s of immunity after), `PlayDeath`. Each controller checks them and listens for changes. This is cheaper and safer than controllers calling each other. See [[Instances Attributes and Tags]].

Rule of thumb: name local-only flags with a `Local` suffix and never let the server trust them.

---

## 9. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| `SetStateEnabled` on the server for a player | No effect | Run it on the client |
| Long `MoveTo` | NPC stops after 8 s | Re-issue or use waypoints |
| Setting Health for damage | Spawn ForceField ignored | `TakeDamage` or check shields yourself |
| Duplicate regeneration | Players heal too fast | Replace the `Health` script |
| `FloorMaterial` as "grounded" | Wall climbing exploits | Verify with rays and normals |
| Scaling a rig without HipHeight | Floating or sinking | Recompute HipHeight |
| Global fall guard | Legit drops rubber-band | Per-area rules |
| Handling only `CharacterAdded` | First spawn missed in Studio | Also handle `player.Character` |

## Checklist
- [ ] One damage function; Health written only by the server.
- [ ] Movement-state edits happen on the owning machine.
- [ ] Character scale decided before ranges are tuned.
- [ ] Unstuck and fall guards with per-area rules.
- [ ] NPC count drives the choice of Humanoid vs AnimationController.

## See also
[[Custom Character Controllers]] · [[Mover Constraints and Physics Controllers]] · [[Spawning Teams and Rounds]] · [[Camera Systems]] · [[Humanoid States and Animation]] · [[Custom Characters and StarterCharacter]] · [[Exploits and Anti-Cheat]] · [[Network Ownership]]

## Connected notes
<!-- auto-links:start -->
[[Spawn Points Safe Zones and Respawn Flow]] · Cookbook - Players and Characters · Ragdolls and Physics-Based Animation · Official Docs - Characters and Animation · Snippets - Ragdoll · Debugging Physics and Network Ownership
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Humanoid - Engine Reference Card]] · [[Cookbook - Players and Characters]] · [[Ragdolls and Physics-Based Animation]] · [[Snippets - Ragdoll]] · [[Character Select and Class Systems with Different Rigs]] · [[Pathfinding Edge Cases and Fallbacks]]
<!-- related:end -->
