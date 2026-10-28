---
tags: [performance, rendering, draw-calls, lod, particles, highlights, shadows]
---
# Rendering Performance

Rendering is usually the largest slice of a client frame, and it is the slice you control least directly: you cannot write the renderer, you can only decide what you ask it to draw. This note covers what makes Roblox rendering expensive (draw calls, geometry complexity, overdraw, lights and shadows, effects, UI), how instancing works, the engine's level-of-detail options and when to switch them off, effect budgets with real production numbers, the Highlight limit, and gating ambient effects by distance and graphics quality.

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

Art-side budgets live in [[Art Budgets - Triangles Draw Calls Memory]]; this note is the runtime view.

---

## 1. What costs

| Cost | Driven by | Profiler signal |
|---|---|---|
| **Draw calls** | number of distinct things the CPU must submit | `Perform`, `Id_Opaque`/`Id_Transparent`; `Stats.SceneDrawcallCount` |
| **Geometry** | triangles in view, skinned meshes | `SceneTriangleCount`; GPU wait |
| **Preparation** | parts that changed this frame, moving Humanoids and skinned meshes | `updateInvalidParts`, `updateInvalidatedFastClusters`, `updateDynamicParts` |
| **Overdraw** | layered transparent surfaces, particles, beams | GPU wait (`Present/waitUntilCompleted`), red frame bars |
| **Lighting and shadows** | number and range of lights, shadow casters | `computeLightingPerform`, `LightGridCPU`, `ShadowMapSystem` |
| **UI** | many GUI objects, layout changes | `fillGuiVertices`, `UpdateUILayouts`; `UI2DDrawcallCount` |

The MicroProfiler bar colour tells you the side: blue (render thread CPU bound) or red (render thread and GPU wait over 2.5 ms, Docs). See [[MicroProfiler Guide]].

Docs pointers: check draw calls with "Render Stats, Timing" in Studio or Shift+F2 in the client.

---

## 2. Draw calls and instancing

Fewer draw calls generally mean less render time (Docs). The engine batches identical meshes into one draw call ("instancing") when (Docs):
- the MeshParts share the same mesh,
- their `SurfaceAppearance`s match, or, with no SurfaceAppearance, their `TextureContent` matches,
- with neither SurfaceAppearance nor TextureID, their materials match.

Ways to break instancing without noticing (Docs and rule of thumb):
- **Importing a whole scene** can give identical meshes different asset ids. Import one piece, duplicate it in Studio.
- Re-uploading the same mesh or texture creates a new id each time.
- Per-instance texture variants instead of colour tints.

Decals, textures and particles batch poorly (Docs). A wall of 200 decals is 200 problems.

### Part count still matters
Basic parts are batched well, but every part still costs memory, preparation when it changes, and physics if not anchored. A building of 4,000 small parts that never changes is usually fine for rendering and bad for memory and Studio; a single merged mesh is usually better for both (rule of thumb).

---

## 3. Geometry complexity and LOD

- Limit very complex meshes; avoid setting `MeshPart.RenderFidelity` to `Precise` on many meshes. Use `Automatic` or `Performance` so the engine can use lower-poly versions at distance (Docs).
- Skinned meshes without a Humanoid are grouped in spatial clusters that rebuild when they move; Docs suggest a Humanoid in the model can avoid that for meshes that actually move, but profile afterwards.

### `Model.LevelOfDetail` (Docs)
Applies only with instance streaming enabled.

| Value | Behaviour |
|---|---|
| `Automatic` | default; **currently equivalent to `Disabled`** |
| `StreamingMesh` | a coarse coloured "imposter" mesh of the whole model renders outside the streaming radius; no textures |
| `Disabled` | no lower-resolution stand-in |
| `SLIM` | a composite of the model's parts at progressively lower resolution by distance; much better quality than StreamingMesh |

Composite or imposter meshes do not support physics, collision or raycasting (Docs). Docs recommend streaming plus `SLIM` on world models, and `Workspace.EnableSLIMAvatars` for distant avatars.

**Measured, and a nuance.** The reference project set `LevelOfDetail` from `Automatic` to `Disabled` explicitly on **7,861 models** across its hub and realm maps, because coarse stand-ins appeared for distant geometry and looked wrong against the art style. Each root got an attribute recording the previous value so a script could revert. Per the current Docs, `Automatic` already behaves like `Disabled`, so on today's engine the change mostly **pins** the behaviour: if Roblox later changes what `Automatic` means, those models will not silently gain stand-ins. Pinning engine defaults you depend on is a reasonable habit; just record why. Whether SLIM would now look acceptable for that art style was not tested.

See [[Level of Detail and Model Streaming]].

---

## 4. Lights and shadows

Docs:
- Use `BasePart.CastShadow = false` on small or distant parts (may cause artefacts) and on moving objects when possible.
- Set `Light.Shadows = false` where shadows aren't needed.
- Limit light `Range` and `Angle`; use fewer lights; disable lights outside relevant areas.
- Shadows degrade with graphics quality and are **disabled below quality level 4**, so test shadow cost at high quality, and do not rely on shadows for gameplay readability.

**Measured.** The reference project thinned its many decorative lights for performance by **disabling** them and tagging them `ThinnedForPerf`, not deleting. That made the pass reversible with one tag query. Scenery parts across several map passes had `CastShadow` turned off as a default, with shadows kept on hero landmarks and walls where the shading read as form.

Lighting technology choice (Future vs ShadowMap vs Voxel) is the biggest single lighting cost decision; see [[Lighting Technologies and Settings]] and [[Light Sources and Shadows]].

---

## 5. Transparency and overdraw

Every partially transparent surface draws on top of what is behind it. Layers of glass, fog cards, glow shells, particles and beams stack up per pixel (Docs: remove unnecessary layers). Symptoms: GPU-bound (red bars), worst on phones and at high resolutions, worst when the camera is inside the effect (a big aura around your own character).

Rules of thumb:
- One soft glow layer, not three stacked.
- Prefer `Neon` material or emissive textures to stacked transparent shells.
- Big screen-filling particles cost more than many small ones.
- Avoid stacked white flares: in the reference project, a "no glare" rule for element effects capped emissive strength and graded bursts to the element colour, which helped both readability and overdraw.

---

## 6. Effects budgets

Docs: particles batch poorly, and **changing ParticleEmitter properties can have a large performance impact**. Set properties once; animate by emitting, not by retuning every frame.

A budget per effect, measured against a hard cap, with a low-quality variant, is the only thing that kept the reference project's effects under control:

| Effect | Cap | Measured actual | Low-quality mode |
|---|---|---|---|
| Sword swing | 140 beams, 30 emitters | 128, 28 | 44 beams, 10 emitters |
| Finisher swing | 210 beams, 44 emitters | | |
| Element VFX layer | 12 meshes, 20 emitters | | |
| Open portal | 6 emitters, 7 beams, 6 meshes, 2 lights, 5 sounds | | asleep beyond 300 studs; low graphics trims layers |
| Sealed portal | 1 emitter, 9 beams, 3 meshes | | |
| Forge celebration | about 3,200 particles over 2 s (caster); ultimate tier 5,600 | | onlookers get half |
| Per-cast readability | at most one ground decal effect at a time; few large non-floor pieces | | |
| Kill feedback | 3 full splats per second | | rest at reduced level |
| Loot icons on screen | 24 (was 60) | | |
| Damage numbers | 12, same-kind merge within 0.55 s | | |

How these were enforced:
- Each effect module counts what it spawns and refuses or degrades past the cap.
- A **verification pass** in Edit ran every style, tier and move and recorded the peak counts (the "measured" column).
- Onlookers see cheaper versions of other players' effects. Your own effects matter most to you.

Further reading: [[Particle Emitters In Depth]], [[Beams and Trails]], [[VFX Design Playbook]].

### Edit-mode caveat for effects
Studio only steps particles while it renders, rate-based emission (`Enabled` streams) does not run in Edit, and `:Emit()` bursts do (Measured). An Edit-mode capture of a short burst can show nothing. Count instances in Edit; judge visuals and frame cost in a play test.

---

## 7. Highlights

Highlights are popular for hit flashes, outlines and selection, and they have a global cap per client.

- **Docs now (as of October 2026):** "Studio only displays 255 simultaneous Highlight instances on the client"; extra ones are dropped silently. **Disabled Highlights still take a slot.** Docs also say this cap does not affect performance.
- **Older Docs, the Animation section of this vault, and the reference project** all used **31** as the cap. The reference project budgeted around it: an outline for every enemy was done with **one** Highlight whose `Adornee` is the folder containing all enemies (one slot instead of hundreds), hit flashes were a pool of 8, tier effects used at most 3.

Whatever the current number, the same practices apply: one Highlight per *group* where possible (a Highlight on a Model or Folder outlines all descendants), pools with caps, delete rather than disable Highlights you will not reuse, and decide priority (hit flash beats ambient outline). A disabled Highlight left on a model can also block another outline effect on that model (Measured). See [[Highlights and Selection Effects]].

The discrepancy is recorded for [[Open Questions - Whole Vault]].

---

## 8. Sleep ambient effects by distance and quality

Ambient world effects (portals, waterfalls, spinning landmarks, fountains) are the easiest place to lose GPU time, because they run whether or not anyone is looking.

```lua
--!strict
-- Client: wake/sleep ambient effect groups by camera distance, with hysteresis,
-- and trim layers on low graphics quality.
local RunService = game:GetService("RunService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

type Fx = {
	root: BasePart,
	wake: number, -- studs: wake inside this
	sleep: number, -- studs: sleep beyond this (larger than wake, so no flicker)
	awake: boolean,
	start: () -> (),
	stop: () -> (),
	setLow: (low: boolean) -> (),
}

local list: { Fx } = {}

local function qualityIsLow(): boolean
	-- SavedQualityLevel is Automatic or QualityLevel1..10 (client only).
	local q = UserGameSettings.SavedQualityLevel
	if q == Enum.SavedQualitySetting.Automatic then
		return false -- the engine scales itself; or use your own in-game preset
	end
	return q.Value <= 3
end

local function register(fx: Fx)
	fx.awake = false
	table.insert(list, fx)
end

local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < 0.5 then
		return -- distance checks twice a second are plenty
	end
	acc = 0
	local camPos = workspace.CurrentCamera.CFrame.Position
	local low = qualityIsLow()
	for _, fx in list do
		local d = (fx.root.Position - camPos).Magnitude
		if not fx.awake and d < fx.wake then
			fx.awake = true
			fx.setLow(low)
			fx.start()
		elseif fx.awake and d > fx.sleep then
			fx.awake = false
			fx.stop()
		end
	end
end)

return register
```

Measured ranges used in the reference project: portals asleep beyond 300 studs; hub showpiece effects sleeping at 520 to 650 studs depending on size; shopkeeper idles beyond 280; spinning gate frames animate within 900. Low graphics (quality 1 to 3) trimmed layers rather than disabling the effect outright, so the world still read correctly. A separate in-game graphics preset (Performance, Balanced, Quality) chosen at first launch drove both the engine level and the game's own effect tiers; see [[Mobile and Low-End Optimization]].

The wake/sleep pair with a gap (hysteresis) prevents an effect flickering on and off when the camera sits right at the boundary.

---

## 9. UI rendering

- Many visible GUI objects cost vertex filling every frame; hidden ones (`Visible = false` or ScreenGui disabled) do not draw.
- **Layout churn** (`UpdateUILayouts`) is the common UI cost: writing `Size`, `Position`, `Text` every frame, huge `UIListLayout`s re-flowing, `TextScaled` labels re-measuring. Write on change ([[Script Performance]]).
- `CanvasGroup` renders its children to a texture: great for fading a whole panel, but it costs texture memory and re-renders when children change.
- Large full-screen images at high resolution cost texture memory on phones.

See [[ScreenGui Fundamentals]] and [[HUD Design]].

---

## Common mistakes

- Judging render cost on a desktop GPU.
- Breaking instancing by importing whole scenes or re-uploading assets.
- Precise render fidelity everywhere.
- Lights with long range and shadows on, in every room.
- Retuning ParticleEmitter properties every frame.
- Unbounded effects (no cap, no low-quality path, no onlooker reduction).
- Ambient effects running at any distance.
- Using disabled Highlights as "off" and leaking slots.
- Testing shadows only at low quality (where they are off) or only at high (where they cost most).

## Checklist

- [ ] Draw calls and triangles checked in the busiest view on a mid phone.
- [ ] Repeated meshes share ids and appearance so they instance.
- [ ] `RenderFidelity` Automatic or Performance except where justified.
- [ ] `LevelOfDetail` chosen deliberately per model group (and recorded if pinned).
- [ ] Shadows off on small, distant and moving parts; lights limited in range and count.
- [ ] Every effect has a cap, a measured peak and a low-quality variant; onlookers get less.
- [ ] Highlights grouped and pooled; unused ones destroyed.
- [ ] Ambient effects sleep by distance with hysteresis and respect graphics quality.
- [ ] UI writes only on change; hidden UI is disabled, not transparent.

## See also

[[Art Budgets - Triangles Draw Calls Memory]] · [[Level of Detail and Model Streaming]] · [[Particle Emitters In Depth]] · [[Beams and Trails]] · [[Highlights and Selection Effects]] · [[Light Sources and Shadows]] · [[Lighting Technologies and Settings]] · [[Mobile and Low-End Optimization]] · [[MicroProfiler Guide]] · [[Animation LOD]]

## Connected notes
<!-- auto-links:start -->
[[VFX Performance Budgets and Culling]] · [[Draw Calls]] · [[Performance Fundamentals]] · [[Mesh Optimization for Mobile]] · [[Juice on a Budget - Mobile and Low-End]] · [[Resource Library - Visual Effects]]
<!-- auto-links:end -->
