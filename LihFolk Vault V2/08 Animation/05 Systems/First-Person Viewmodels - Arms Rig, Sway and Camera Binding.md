---
tags: [animation, first-person, viewmodel, fps, sway, bob, camera, weapons, type/guide, area/animation, level/advanced, api/Camera, api/AnimationController, api/RunService]
---
# First-Person Viewmodels - Arms Rig, Sway and Camera Binding

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Queryable viewmodel parts -> `CanQuery`, `CanCollide`, `CanTouch` off
> - Avoid: Bound before the camera -> Bind after camera priority
> - Avoid: Mouse-delta sway only -> Sway from camera rotation change
> - Local-only viewmodel under the camera; all parts non-colliding, non-queryable, shadowless.
> - Bound after camera priority; destroyed on every exit path.
> - Sway works for mouse, touch and gamepad; bob scales with speed; reduced-motion respected.
>
> Cost: TL;DR ~160 tok · whole note ~2.6k tok. Read more: ## 2. Binding to the camera every frame · ## 3. Clipping into walls · ## Common mistakes · ## Checklist
<!-- tldr:end -->

In first person, the character's real arms are the wrong thing to show: they are animated for third-person readability, they clip through the camera, and the default camera hides the local character anyway. Shooters and first-person melee games render a separate **viewmodel**: a local-only arms-and-weapon rig bound to the camera every frame, with its own animations, sway, bob and aim-down-sights offset. Other players never see it; they see the third-person character, driven by replicated aim. This note covers the rig, the per-frame binding, sway and bob, clipping strategies, ADS alignment and third-person sync.

Source labels: **Roblox docs**, **Rule of thumb**.

---

## 1. The rig

- A `Model` with a root part (`Root`, anchored, invisible), two arms (meshes or simplified limbs), and the weapon, connected by `Motor6D`s. The weapon attaches to a hand or to the root via a grip joint ([[Custom Rigs - Weapons and Props]], [[Held Weapons on Motor6D - Locking the Grip During Attacks]]).
- Animate with an `AnimationController` + `Animator` (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/AnimationController). Animations play on the client only, which is what you want. Author viewmodel clips separately from third-person clips; they share timing (fire, reload markers) but not poses.
- Every part: `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, `CastShadow = false`, `Massless = true`. A queryable viewmodel blocks your own weapon raycasts (fired from the camera) and can trigger touch events.
- Parent it under `Workspace.CurrentCamera`. It is created by a `LocalScript`, so it is local regardless, but under the camera it is easy to find and clean up, and it never ends up inside a character model that other systems iterate.
- Sleeves: tint arms from the character's shirt colour or skin tone (read `BodyColors` or `HumanoidDescription`) so the arms match the avatar.

## 2. Binding to the camera every frame

Bind **after** the camera has been finalised, so recoil and shake layers are included:

```lua
--!strict
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local camera = Workspace.CurrentCamera
local viewmodel = script:WaitForChild("Viewmodel"):Clone() :: Model
local root = viewmodel:WaitForChild("Root") :: BasePart
viewmodel.Parent = camera

local BASE_OFFSET = CFrame.new(0.35, -0.55, -1.1)
local swayRot = Vector2.zero
local bobTime = 0
local adsAlpha = 0
local aiming = false
local aimOffset = CFrame.identity -- computed from the sight attachment, see section 4

local function damp(k: number, dt: number): number
	return 1 - math.exp(-k * math.min(dt, 0.1))
end

RunService:BindToRenderStep("Viewmodel", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
	local reduced = GuiService.ReducedMotionEnabled
	-- Sway: lag behind mouse movement, spring back
	local delta = UserInputService:GetMouseDelta()
	local target = Vector2.new(-delta.X, -delta.Y) * 0.003
	swayRot = swayRot:Lerp(target, damp(12, dt))

	-- Bob from the character's horizontal speed
	local char = game:GetService("Players").LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local speed = if hrp then (hrp.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude else 0
	bobTime += dt * math.clamp(speed / 16, 0, 1.5) * 9
	local bobAmp = if reduced then 0 else math.clamp(speed / 16, 0, 1) * (1 - adsAlpha * 0.8)
	local bob = CFrame.new(math.sin(bobTime) * 0.03 * bobAmp, math.abs(math.cos(bobTime)) * -0.04 * bobAmp, 0)

	adsAlpha += ((if aiming then 1 else 0) - adsAlpha) * damp(14, dt)
	local offset = BASE_OFFSET:Lerp(aimOffset, adsAlpha)
	local swayScale = if reduced then 0.3 else 1 - adsAlpha * 0.7
	local sway = CFrame.Angles(swayRot.Y * swayScale, swayRot.X * swayScale, swayRot.X * 0.5 * swayScale)

	root.CFrame = camera.CFrame * offset * sway * bob
end)
```

Notes:
- `GetMouseDelta` only reports movement while the mouse is locked (first person locks it). On touch and gamepad, derive sway from the change in camera orientation between frames instead, which works for all inputs.
- Use `Root.CFrame` on an anchored root; animations on the `Animator` still move the Motor6D children. For many parts, a single anchored root plus joints is cheaper than CFraming each part.
- Unbind and destroy on death, unequip, leaving first person and character removal.

## 3. Clipping into walls

Roblox has no "render this model on top" flag for 3D parts, so the viewmodel can pass through walls when the player stands close to them. Strategies, best first (**Rule of thumb**):

1. **Keep it small and close.** Scale the whole viewmodel down (for example 0.5x) and move it proportionally closer to the camera. It looks identical from the eye but sticks out half as far. `Model:ScaleTo` scales rigs including joints (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/Model#ScaleTo).
2. **Wall push.** Raycast or spherecast forward from the camera the length of the weapon. If something is closer, lerp the viewmodel back and rotate the weapon upward or sideways ("gun lowered" pose). Players read this as the character reacting to the wall.
3. **Near clip awareness.** The camera's near plane is fixed; parts closer than it are cut. Keep the viewmodel's nearest geometry beyond it.
4. **ViewportFrame rendering.** Render the viewmodel in a full-screen `ViewportFrame` with its own camera; it can never clip. Costs: no world lighting or shadows (only the ViewportFrame's ambient and light direction), no particles in the same way, extra render cost, and post-processing differences. Generally only worth it for stylised games.

## 4. Aim down sights

Put an `Attachment` named `Sight` on the weapon at the rear sight / optic centre, pointing forward. The ADS offset is the transform that puts that attachment on the camera's centre line:

```lua
--!strict
local function computeAimOffset(root: BasePart, sight: Attachment, eyeDistance: number): CFrame
	local sightInRoot = root.CFrame:ToObjectSpace(sight.WorldCFrame)
	return CFrame.new(0, 0, -eyeDistance) * sightInRoot:Inverse()
end
```

Compute it once per weapon (in the rest pose), not every frame. ADS also lowers camera FOV through the single FOV owner ([[Camera Systems]]), reduces sway and bob, and reduces spread ([[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]]). Field of view changes distort the viewmodel; tune `BASE_OFFSET` at your default FOV and test at the extremes of any FOV slider.

## 5. The local character in first person

- The default camera hides the local character's parts in first person by setting `LocalTransparencyModifier` (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/BasePart#LocalTransparencyModifier). If you want visible legs ("true first person"), you must override it every frame after the camera module runs, and hide head and accessories yourself.
- Tools equipped on the character still exist in third person for other players. Hide the third-person tool locally in first person, or the player sees two guns when looking down.
- Lock first person with `Player.CameraMode = LockFirstPerson` or a camera zoom of 0.5 (**Roblox docs**: https://create.roblox.com/docs/reference/engine/enums/CameraMode).

## 6. Third-person sync

Other players see the character, not the viewmodel. Make it match:
- Replicate **aim pitch** (and yaw if the body does not turn) from the client at 10 to 20 Hz on an `UnreliableRemoteEvent`; the server validates range and relays (or sets an attribute); other clients rotate the waist and neck joints toward it ([[Look-At Aim and Head Tracking]]).
- Third-person **fire, reload and equip animations** are triggered from server-confirmed actions or relayed events, with the same markers as the viewmodel clips so sounds line up ([[Weapon and Combat Animation]]).
- The muzzle flash others see comes from the third-person weapon's muzzle attachment; the shooter sees it at the viewmodel's muzzle.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Queryable viewmodel parts | Own shots hit your gun | `CanQuery`, `CanCollide`, `CanTouch` off |
| Bound before the camera | Viewmodel lags a frame, jitter | Bind after camera priority |
| Mouse-delta sway only | No sway on touch and gamepad | Sway from camera rotation change |
| Full-size viewmodel | Clips into every wall | Scale down and move closer; wall push |
| ADS offset by hand per weapon | Sights misaligned | Compute from a `Sight` attachment |
| Third-person tool visible in first person | Two guns | Hide locally |
| No aim replication | Others see players shooting the floor | Replicated pitch drives waist and neck |

## Checklist
- [ ] Local-only viewmodel under the camera; all parts non-colliding, non-queryable, shadowless.
- [ ] Bound after camera priority; destroyed on every exit path.
- [ ] Sway works for mouse, touch and gamepad; bob scales with speed; reduced-motion respected.
- [ ] Clipping handled by scale and wall push.
- [ ] ADS from a sight attachment; FOV through the single owner.
- [ ] Aim pitch replicated; third-person animations match markers.

## See also
[[Weapon and Combat Animation]] · [[Procedural Weapon Motion]] · [[Camera Systems]] · [[Genre Playbook - Shooters FPS and TPS]] · [[Custom Rigs - Weapons and Props]] · [[Springs Damping and Smoothing]]

## Connected notes
<!-- auto-links:start -->
[[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]] · [[Equip Draw and Flourish Systems]] · [[Camera Shake and Camera FX]] · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Teardown - Phantom Forces]] · [[Accessories and Armor That Follow Animation]] · [[Procedural Animation]] · [[Rigs and Joints]] · [[Cameras and Cutscenes]] · [[Mounts and Rideable Creatures]] · [[Snippets - Procedural Motion]] · [[Motor6D Math and CFrame Composition]] · [[Snippets - Camera Shake and FX]]
<!-- related:end -->
