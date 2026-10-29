---
tags: [marketing, thumbnails, studio, blender, capture, freecam, lighting, posing, depth-of-field, colour-grading, production, type/guide, area/marketing, level/intermediate]
---
# Making Thumbnails in Studio and Blender - Capture, Lighting and Posing

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: screenshots of the live game with UI, chat and other players' names.
> - Avoid: default noon lighting. Symptom: flat, shadowless subject that merges with the background.
> - Avoid: default idle poses. Symptom: stiff characters with arms at their sides and no emotion.
> - PhotoStudio place with sets, rigs, lighting presets and safe-area overlay.
> - Key, rim and fill lights placed; background brighter or darker than the hero.
> - Depth of field focused on the hero's face.
>
> Cost: TL;DR ~160 tok · whole note ~3.6k tok. Read more: ## 4. Posing characters · ## 6. Rendering in Blender (optional) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

This note is the production side of thumbnails: setting up a reusable "photo studio" place, lighting a hero shot with the game's own lighting objects, freezing characters in strong poses, capturing clean high-resolution frames, optionally rendering in Blender, and finishing with grading and export, all while keeping the image truthful to what players will see. Trailer and video capture are covered in [[Game Trailers and Clean Footage - Capture, Freecam and Editing]]; automated item-icon renders in [[Icon and Thumbnail Rendering Pipeline]] and [[Dramatic Showcase Renders in Eevee]]; in-game player screenshots in [[Photo Mode and In-Game Screenshots with CaptureService]]; posing theory in [[Posing and Silhouettes]]; lighting mood in [[Lighting Mood and Time of Day]] and [[Atmosphere Sky Clouds and Post-Processing]]. What the image should contain is in [[Thumbnail Composition for High CTR - Focal Point, Contrast and Readability]]. Hub: [[Thumbnails and CTR Start Here]].

Labels: **Roblox docs**, **Rule of thumb**, **Unverified**.

---

## 1. The truth constraint first

Roblox asks for imagery that shows what players will find; video rules allow varied camera angles of real gameplay and minor post-processing (brightness, contrast, small effects) as long as the core visuals stay the same, and forbid visuals beyond what a player will actually see (**Roblox docs**, https://create.roblox.com/docs/production/promotion/thumbnails). Misleading metadata is against the Community Standards (https://about.roblox.com/community-standards).

Working rule for stills (Rule of thumb):

| Allowed and useful | Keep out |
|---|---|
| Hand-placed characters and props from the game | Characters, items or places not in the game |
| Camera angles players never get | A different art style (painted, realistic) for a stylised game |
| Lighting presets and effects the game uses somewhere | Lighting or materials the game cannot render |
| Frozen frames of real VFX and real UI | Fake UI, fake rarity banners, invented numbers |
| Gentle grading, vignette, depth of field | Heavy paint-overs that change shapes or add detail |

If a Blender render is used, it should look like a very good screenshot of the game, not like a film poster for a different game.

---

## 2. Build a photo studio place

Keep a copy of the game as a separate, private place named something like `PhotoStudio` (Rule of thumb):

- **Sets:** the 3 to 5 most photogenic locations, trimmed of clutter, with the camera-facing side polished.
- **Rigs:** posable copies of the player avatar (several outfits), each major creature, NPC and boss, with Animators ready.
- **Lighting presets:** a folder per mood (golden hour, night neon, horror, clean daylight), each holding `Atmosphere`, `Sky`, `ColorCorrectionEffect`, `BloomEffect`, `DepthOfFieldEffect` and `SunRaysEffect` instances plus a note of `ClockTime`. Swap a preset by moving its children into `Lighting`.
- **Guides:** a 16:9 safe-area overlay (a `ScreenGui` with outlined frames for the bottom 15 to 20 % and corners) you can toggle on while framing and off for capture.
- **Re-shoot list:** after each update, re-sync rigs and sets from the live game so thumbnails always show current content.

---

## 3. Lighting a hero shot in Studio

Start from the game's own lighting, then make the shot read (Rule of thumb values; tune by eye):

1. **Pick the time of day** that separates the subject: golden hour (`ClockTime` around 6.5 to 7.5 or 17 to 18) gives warm key light and long shadows; night gives neon and rim light opportunities.
2. **Key light:** the sun, positioned so the subject's face is lit three-quarters from the camera side.
3. **Rim light:** a `SpotLight` or `PointLight` behind and above the subject, in a colour complementary to the background (cyan rim on a warm scene, orange rim on a blue scene). Brightness high enough that the edge glows at 320 x 180.
4. **Fill:** a soft `PointLight` near the camera at low brightness, so faces are not black.
5. **Background:** a bright sky, a glowing sign or a lit window behind the subject separates silhouettes more cheaply than any light.
6. **Atmosphere:** a little haze (`Atmosphere.Density` modest) pushes the background back and adds depth.
7. **Effects:** `BloomEffect` for glow, `ColorCorrectionEffect` for a small contrast and saturation lift, `SunRaysEffect` sparingly.

Use only effects your game can also show somewhere; a bloom level far beyond the game's own setting drifts toward "visuals beyond what a player will see".

### Depth of field
`DepthOfFieldEffect` in `Lighting` blurs foreground and background around a focus distance. Properties: `FocusDistance`, `InFocusRadius`, `NearIntensity`, `FarIntensity`. For a hero shot (Rule of thumb): focus on the subject's face, `InFocusRadius` just covering the subject, `FarIntensity` around 0.3 to 0.6, `NearIntensity` low unless a foreground object frames the shot. Blur makes the background a colour field, which is exactly what tile-size readability wants.

---

## 4. Posing characters

### Fastest: freeze a real animation
Play an existing animation and stop it at its most dramatic frame. Run this in a **Run** or **Play** session in the photo studio place (animations do not advance in edit mode):

```lua
--!strict
-- Freeze a rig at a chosen time in an animation, for thumbnail capture.
-- Put in a Script in ServerScriptService of the PhotoStudio place. Set the names below.
local RIG_NAME = "HeroRig"
local ANIMATION_ID = "rbxassetid://0" -- your attack or reaction animation
local FREEZE_AT = 0.42 -- seconds into the animation

local rig = workspace:WaitForChild(RIG_NAME) :: Model
local humanoid = rig:FindFirstChildOfClass("Humanoid")
local controller = rig:FindFirstChildOfClass("AnimationController")
local parent: Instance = (humanoid or controller) :: Instance
local animator = parent:FindFirstChildOfClass("Animator") or Instance.new("Animator")
animator.Parent = parent

local animation = Instance.new("Animation")
animation.AnimationId = ANIMATION_ID
local track = animator:LoadAnimation(animation)
track:Play(0) -- no fade-in
track.TimePosition = FREEZE_AT
track:AdjustSpeed(0) -- hold the pose
```

Anchor the rig's root part if physics would let it fall. For several characters, run one track per rig with different freeze times.

### Custom poses
For a pose no animation has, open the Animation Editor on the rig, set a single keyframe, and freeze it the same way. Pose rules (Rule of thumb, see [[Posing and Silhouettes]]):
- **Clear silhouette:** limbs away from the body, weapon not overlapping the face.
- **Line of action:** one strong curve from foot to head, tilted toward the action.
- **Exaggerate for small sizes:** a pose that looks slightly too big at 1080 p looks right at 320 x 180.
- **Face:** use an expressive face or dynamic head that matches the emotion; open-mouth shock reads furthest.

### Groups
For social and party shots, vary heights and depths (one character forward, two behind), overlap shoulders slightly so the group reads as one shape, and point every face toward the focal point or the camera.

### VFX
Freeze effects at peak too: set `ParticleEmitter.TimeScale` to 0 after emitting, or call `Emit` and pause the session at the right moment. Show your real effects at their best frame rather than adding new ones.

---

## 5. Capturing the frame

- **Free camera:** press **Left Shift + P** during a solo playtest to toggle freecam for cinematic screenshots and video (**Roblox docs**, thumbnails page). See the trailer note for movement controls.
- **Scripted camera:** for exact, repeatable framing, set `workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable` and its `CFrame` and `FieldOfView` from a client script; save each shot's CFrame and FOV in a module so re-shoots after updates match ([[Cameras and Cutscenes]]).
- **Field of view:** 30 to 50 degrees for hero close-ups (flattering, compresses background), 60 to 80 for scale shots with a tiny avatar and a giant subject (Rule of thumb).
- **Hide UI:** disable your `ScreenGui`s and core GUI for capture, unless the real UI element is part of the promise (a rarity banner), in which case keep only that element.
- **Quality:** set Studio's rendering quality to its highest level in Studio settings, close other heavy apps, and wait a few seconds after moving the camera so streaming and level-of-detail catch up.
- **Resolution:** capture at least 1920 x 1080 of pure viewport. On a 4K display, maximise the viewport and capture larger, then downscale; supersampling smooths edges. Use an operating-system screenshot tool or a capture app that grabs only the viewport. Whether Studio's own screenshot button still exists and what resolution it saves at is **Unverified** in current Studio.
- **Aspect:** frame for 16:9 from the start; the platform stretches other ratios rather than cropping (**Roblox docs**).
- **Take variants while set up:** same scene, three camera distances, two emotions, with and without the secondary element. That is your next personalisation round ([[Thumbnail and Icon A-B Testing - Method, Sample Size and Reading Results]]).

---

## 6. Rendering in Blender (optional)

Use Blender when you need cleaner lighting control, true depth of field or a consistent render style across many images, and the game's look can be reproduced faithfully.

**Getting the scene out of Studio**
- Select the parts or models, right-click, **Export Selection**, which writes an `.obj` with materials (a long-standing Studio exporter; developers report issues with materials and with objects far from the origin, so export near the origin: https://devforum.roblox.com/t/export-selection-obj-exporter-has-floating-point-issues-when-exporting-objects-not-at-origin/3310060). A native glTF or FBX exporter in Studio is **Unverified** as of 2026-10-29.
- Export a posed avatar during a Play session after freezing the pose, so the pose comes with the mesh.
- Expect to rebuild materials: check colours against in-game screenshots, keep the game's material palette, and avoid adding detail (normal maps, realistic skin) the game does not have.

**Scene and camera**
- Match the Studio camera's FOV; the Blender camera's focal length for a given FOV depends on sensor width, so set the FOV directly in the camera's lens settings.
- Use the camera's depth of field (focus object on the hero's face, f-stop that softens the background as in Studio).
- Light with a three-point setup (key, rim, fill) as in section 3. Eevee is fast and matches game-like stylised looks; Cycles is slower and can drift toward realism.

**Colour management**
- Blender 4.x defaults to the **AgX** view transform, which desaturates bright colours compared with how Roblox shows them. For stylised games, compare against a Studio screenshot and pick the transform and look that matches; the showcase note covers this in detail ([[Dramatic Showcase Renders in Eevee]]).
- Render 3840 x 2160 and downscale to 1920 x 1080 for clean edges, or render 1920 x 1080 with sufficient samples.

---

## 7. Finishing: grading and export

**Grade** (in any image editor; Rule of thumb):
1. **Levels:** set black and white points so the image uses the full range; keep the hero above mid-grey.
2. **Local contrast:** brighten the hero's face and the secondary element slightly; darken the edges with a 10 to 20 % vignette.
3. **Saturation:** lift the hero, not the background.
4. **Sharpen** lightly after downscaling.
5. **Text and logo** last, on separate layers, inside the safe area.

**Check**
- Greyscale test, 320 x 180 and 160 x 90 previews, row test against competitors ([[Thumbnail Composition for High CTR - Focal Point, Contrast and Readability]]).
- Side-by-side with a raw in-game screenshot of the same place: would a player recognise the game?

**Export**
- 1920 x 1080, 16:9, sRGB.
- JPG at high quality (about 90) for 3D scenes, PNG for flat art; under 3 MB so it works in the personalisation flow (**Roblox docs** for size and resolution).
- Name files with date and idea: `2026-10-29_thief-vs-guardian_v2.jpg`. Keep the layered source and the camera CFrame used.
- Add alt text when you upload to the details page (**Roblox docs**).

AI-assisted retouching follows the same truth rule; see [[AI Image Generation for Icons Thumbnails and Concepts]] and [[Roblox Policies on AI-Generated Content]].

---

## Common mistakes

- Avoid: screenshots of the live game with UI, chat and other players' names. Symptom: cluttered, unreadable tiles and possible privacy issues.
- Avoid: default noon lighting. Symptom: flat, shadowless subject that merges with the background.
- Avoid: default idle poses. Symptom: stiff characters with arms at their sides and no emotion.
- Avoid: Blender materials that look more realistic than the game. Symptom: players feel misled; first-play bounce rises.
- Avoid: rebuilding every shot from scratch. Symptom: thumbnails go stale because re-shooting takes too long.
- Avoid: capturing at a non-16:9 window size. Symptom: stretched characters after upload.
- Avoid: grading the background as hard as the hero. Symptom: everything competes; nothing pops.

## Checklist

- [ ] PhotoStudio place with sets, rigs, lighting presets and safe-area overlay.
- [ ] Key, rim and fill lights placed; background brighter or darker than the hero.
- [ ] Depth of field focused on the hero's face.
- [ ] Pose frozen from a real animation or a single-key custom pose with a clear silhouette.
- [ ] Captured at 16:9, at least 1920 x 1080, UI hidden except real payoff elements.
- [ ] Camera CFrame and FOV saved for re-shoots.
- [ ] If rendered in Blender, side-by-side check against an in-game screenshot.
- [ ] Graded, tested at small sizes, exported under 3 MB with a dated filename.

<!-- related:start -->
## Related
[[Thumbnail Review Checklist and Scoring Rubric]] · [[Thumbnail Contrast]] · [[Thumbnail Specs, Rules and Upload - Sizes, Count and Policy]] · [[Game Icon Design - Readable at Small Sizes]] · [[Stylized Lighting Recipes]] · [[Thumbnail Genre Patterns - What Top Games Show]]
<!-- related:end -->
