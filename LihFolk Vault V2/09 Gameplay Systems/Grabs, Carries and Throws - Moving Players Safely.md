---
tags: [gameplay, combat, grabs, carry, throw, network-ownership, physics, anti-abuse, type/guide, area/gameplay, level/advanced, api/WeldConstraint, api/BasePart, server-authority]
---
# Grabs, Carries and Throws - Moving Players Safely

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Weld without ownership change -> Root priority plus `SetNetworkOwner(grabber)`
> - Avoid: Victim still controlling movement -> PlatformStand, input off, massless
> - Avoid: Release misses an exit path -> Single guarded release on every path
> - Server validates range, states, zones, immunity and team rules before grabbing.
> - Victim neutralised, massless, non-colliding with the grabber; grabber is assembly root and owner.
> - Release restores everything, returns ownership, runs once, with a max duration.
>
> Cost: TL;DR ~170 tok · whole note ~2.5k tok. Read more: ## 3. Doing the rigid weld correctly (server) · ## 4. Releasing and throwing · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Grabbing another player (a wrestler's throw, carrying a downed teammate, a monster dragging a victim, a "carry" emote) is one of the most bug-prone features on Roblox because it attaches two **client-owned** physics assemblies together. Done naively it flings both players, lets the grabbed player teleport the grabber, desyncs positions between clients, or becomes a griefing tool. This note covers the attachment options, network ownership during and after the grab, escape mechanics, throws, and the abuse rules. Ownership background is in [[Network Ownership]]; constraint behaviour in [[Physics Assemblies and Constraints]].

Source labels: **Roblox docs**, **Rule of thumb**.

---

## 1. Why it is hard

- Each player's client simulates its own character (**Roblox docs**: https://create.roblox.com/docs/physics/network-ownership). When two characters are joined by a rigid joint they become **one assembly**, and an assembly has **one** network owner. One of the two players is suddenly simulating the other's body.
- If the grabbed player's client still thinks it controls its character, it fights the joint: jitter, rubber-banding, or sudden flings.
- The owner of the merged assembly can move both bodies anywhere. If that is the victim, the victim can drag the grabber through walls.

## 2. Three attachment approaches

| Approach | How | Pros | Cons |
|---|---|---|---|
| **Rigid weld to grabber** | Server creates a `WeldConstraint` (or `RigidConstraint`) from victim root to grabber's hand/torso attachment | Exact, looks right | Assemblies merge; must control ownership and victim state |
| **Constraint follow** | Victim stays separate; `AlignPosition` + `AlignOrientation` pull the victim toward a target attachment on the grabber | Assemblies stay separate; softer | Slight lag; victim's client must not resist |
| **Puppet** | Victim root anchored on the server and CFramed each step to the grab point; or the victim's character hidden and a visual copy attached | Fully server-controlled, immune to victim input | Anchored characters look stiff; puppet needs swap logic |

**Rule of thumb.** Rigid weld for short grabs (throws, suplexes, under 2 to 3 s), constraint follow or weld for carries, puppet for scripted cinematic grabs by NPCs.

## 3. Doing the rigid weld correctly (server)

1. **Validate**: grabber is alive, not stunned, in range (server distance check with a small tolerance), target is grabbable (not in a safe zone, not spawn-protected, not already grabbed, not immune, team rules) ([[Server Authority and Validation]]).
2. **Neutralise the victim**: set the victim Humanoid to a non-controlled state (`PlatformStand = true`, or change state to `Physics`), set `AutoRotate = false`, disable their movement input via a client message, and make victim parts `Massless = true` so the grabber's movement is not dragged down.
3. **Choose the assembly root**: set `RootPriority` higher on the grabber's root part than on the victim's (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/BasePart#RootPriority) so the merged assembly's root is the grabber.
4. **Weld** the victim root to an attachment point on the grabber.
5. **Ownership**: after welding, call `SetNetworkOwner(grabberPlayer)` on the grabber's root (the assembly root). The grabber now simulates both; the victim's client just renders.
6. **Collision**: put the victim's parts in a collision group that does not collide with the grabber, or both bodies push each other ([[Collision and Physics Geometry]]).

```lua
--!strict
local GRAB_RANGE = 7

local function setVictimParts(char: Model, grabbed: boolean)
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			d.Massless = grabbed
			d.CollisionGroup = if grabbed then "Grabbed" else "Default"
		end
	end
end

local function grab(grabber: Player, victim: Player): WeldConstraint?
	local gc, vc = grabber.Character, victim.Character
	local gHum = gc and gc:FindFirstChildOfClass("Humanoid")
	local vHum = vc and vc:FindFirstChildOfClass("Humanoid")
	local gRoot = gHum and gHum.RootPart
	local vRoot = vHum and vHum.RootPart
	if not (gc and vc and gHum and vHum and gRoot and vRoot) then return nil end
	if gHum.Health <= 0 or vHum.Health <= 0 then return nil end
	if (gRoot.Position - vRoot.Position).Magnitude > GRAB_RANGE then return nil end
	if vc:GetAttribute("Grabbed") or vc:GetAttribute("Immune") then return nil end

	vc:SetAttribute("Grabbed", grabber.UserId)
	vHum.PlatformStand = true
	vHum.AutoRotate = false
	setVictimParts(vc, true)
	gRoot.RootPriority = 10
	vRoot.RootPriority = 0

	vRoot.CFrame = gRoot.CFrame * CFrame.new(0, 0.5, -2.5)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = gRoot
	weld.Part1 = vRoot
	weld.Parent = gRoot
	gRoot:SetNetworkOwner(grabber)
	return weld
end
```

Create the `Grabbed` collision group at startup with `workspace:RegisterCollisionGroup` and set it not to collide with `Default` characters as needed with `workspace:CollisionGroupSetCollidable` (**Roblox docs**: collision groups live on WorldRoot since September 2026; the `PhysicsService` methods are deprecated, https://create.roblox.com/docs/reference/engine/classes/WorldRoot).

## 4. Releasing and throwing

Release must undo **everything**, on every exit path (normal end, escape, grabber death, victim death, either leaving, grabber stunned, timeout):

1. Destroy the weld.
2. Restore victim parts' `Massless` and collision group, `RootPriority`, `PlatformStand = false`, `AutoRotate = true`.
3. **Return ownership**: `vRoot:SetNetworkOwner(victim)` (and the grabber's own root to the grabber). If the victim left, nothing to do; if the grabber left, the victim must still be restored.
4. Clear the `Grabbed` attribute.
5. Tell the victim's client to re-enable input and to apply any **throw velocity**: the server computes direction and strength and sends it; the victim's client (now the owner again) sets `AssemblyLinearVelocity` after leaving `PlatformStand`, as with knockback ([[Combat Systems Architecture]] section 4).

Wrap release in a function guarded by a per-grab "released" flag so it runs exactly once even when several exit events fire together. A **max duration** (for example 8 s for carries, 2 s for throws) with automatic release is mandatory.

## 5. Escape mechanics

- The victim sends escape inputs (mash, or a directional QTE). The server counts them with a rate cap (for example at most 15 per second accepted) so autoclickers do not trivialise it ([[Autoclicker and Macro Detection for Combat Remotes]]).
- Escape progress decays when not mashing; the threshold scales with the grab type.
- Teammates can break a grab by damaging the grabber (stagger threshold) or with a dedicated action.
- Grab immunity after release (1 to 3 s) prevents chain grabs.

## 6. Abuse and griefing

- **Consent for non-combat carries**: carry emotes in social games require the carried player to accept a prompt. Never let one player pick up another without consent outside combat ([[Community Building]]).
- **Safe zones** block grabs entirely; carrying a player into a kill zone or off the map is the classic grief. Release automatically on entering hazard or out-of-bounds areas, and ignore credit for such kills ([[Kill Credit, Assists, Kill Feed and Death Recaps]]).
- **Velocity checks** on the grabber still apply; a grabber cannot move faster than normal movement allows. The anti-cheat must understand that the victim's position is now driven by the grabber ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]]).
- Vehicles: do not allow entering seats while grabbing or grabbed.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Weld without ownership change | Jitter, victim drags grabber | Root priority plus `SetNetworkOwner(grabber)` |
| Victim still controlling movement | Fling on weld | PlatformStand, input off, massless |
| Release misses an exit path | Victim stuck massless or non-owned | Single guarded release on every path |
| Throw applied by the server | Late or no throw | Victim client applies after ownership returns |
| Unlimited mash accepted | Autoclickers escape instantly | Rate-capped escape inputs |
| Carry without consent | Griefing reports | Prompt acceptance outside combat |

## Checklist
- [ ] Server validates range, states, zones, immunity and team rules before grabbing.
- [ ] Victim neutralised, massless, non-colliding with the grabber; grabber is assembly root and owner.
- [ ] Release restores everything, returns ownership, runs once, with a max duration.
- [ ] Throws computed on the server, applied by the victim's client.
- [ ] Escape inputs rate-capped; post-release immunity.
- [ ] Safe zones, hazards and consent rules prevent griefing.

## See also
[[Network Ownership]] · [[Physics Assemblies and Constraints]] · [[Mover Constraints and Physics Controllers]] · [[Ragdolls and Physics-Based Animation]] · [[Debugging Physics and Network Ownership]] · [[Combat Systems Architecture]]

## Connected notes
<!-- auto-links:start -->
[[Downed, Revive and Bleed-Out States]] · [[Squad AI - Attack Tokens, Flanking and Attacker Limits]] · [[Horror Monster Chase AI End to End]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Teardown - Fling Things and People]] · [[Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run]] · [[Characters and Humanoids]] · [[Hitboxes and Hit Detection]] · [[Explosions - Radius Damage, Falloff and Cover Checks]] · [[Status Effects Buffs and Stacking Rules]] · [[Custom Character Controllers]] · [[Police Chases and Wanted Levels]] · [[Damage Formula Pipeline - Armor, Resistances, Crits and Order of Operations]]
<!-- related:end -->
