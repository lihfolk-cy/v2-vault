---
tags: [platform, camera, photo-mode, captureservice, screenshots, sharing, growth, type/guide, area/platform, level/intermediate, api/CaptureService, api/Camera]
---
# Photo Mode and In-Game Screenshots with CaptureService

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Capturing with the toolbar visible -> Hide UI, wait a frame, capture
> - Avoid: Unleashed free camera -> Radius clamp around the character
> - Avoid: Not restoring the camera -> Watchdog on every exit path
> - Capture hides HUD, chat bubbles and nametags; `CaptureBegan/Ended` also handled for menu captures.
> - Save and share only on explicit buttons; results handled gracefully.
> - Free camera leashed, collides, and restores on every exit path.
>
> Cost: TL;DR ~150 tok · whole note ~2.2k tok. Read more: ## 2. Flow that respects the player · ## 3. The photo-mode camera · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Screenshots are free marketing: every capture a player saves or shares is a thumbnail you did not have to make. Roblox exposes the platform's capture system to scripts through `CaptureService`, so an experience can take a screenshot from its own UI, offer to save it to the player's captures gallery, and prompt a share that carries launch data back into the game. Pair it with a photo-mode camera and you have a feature that players use for fun and that drives invites. This note covers the API surface, a safe photo-mode camera, and the traps (HUD in shots, streaming holes, abuse).

Source labels: **Roblox docs**, **Rule of thumb**, **Unverified**. API reference: https://create.roblox.com/docs/reference/engine/classes/CaptureService

---

## 1. API surface (client only)

| Member | Use |
|---|---|
| `CaptureService:CaptureScreenshot(onCaptureReady)` | Takes a screenshot; the callback receives a temporary content id you can show in an `ImageLabel` |
| `CaptureService:PromptSaveCapturesToGallery(captures, resultCallback)` | Asks the player to save one or more captures to their captures gallery; the callback reports per-capture results |
| `CaptureService:PromptShareCapture(capture, launchData, onAccepted, onDenied)` | Opens the share flow for a capture; `launchData` travels with the share so joiners can be routed |
| `CaptureBegan` / `CaptureEnded` | Fire around a capture, including ones the player starts from the Roblox menu, so you can hide and restore UI |
| `UserCaptureSaved` | Fires when the player saves a capture |

All of it is **Roblox docs** at the URL above. The service runs on the client; the server never sees the image. Exact callback argument shapes change occasionally, so read the reference page before wiring results into UI.

**Unverified:** video capture members have been discussed and may exist in newer releases; check the reference page rather than assuming.

## 2. Flow that respects the player

1. Player opens photo mode (button or key). Gameplay input is paused for them; the character is invulnerable or the mode is only allowed in safe zones (otherwise it becomes an exploit-free "AFK in combat" button that gets them killed and they blame you).
2. HUD hidden, photo-mode toolbar shown.
3. Player frames the shot with a free camera, FOV, roll, filters.
4. "Capture": hide the toolbar, wait one frame, `CaptureScreenshot`, restore toolbar, show a preview with the returned content id.
5. Preview offers **Save** (`PromptSaveCapturesToGallery`) and **Share** (`PromptShareCapture`). Never auto-prompt; a prompt the player did not ask for is a dismissal habit you are training.

```lua
--!strict
local CaptureService = game:GetService("CaptureService")
local RunService = game:GetService("RunService")

local function setHudVisible(visible: boolean) end -- your HUD controller

local function takePhoto(toolbar: ScreenGui, preview: ImageLabel)
	toolbar.Enabled = false
	RunService.RenderStepped:Wait() -- let the hidden UI leave the frame
	CaptureService:CaptureScreenshot(function(contentId: string)
		toolbar.Enabled = true
		preview.Image = contentId
		preview.Visible = true
		preview:SetAttribute("CaptureId", contentId)
	end)
end

local function save(preview: ImageLabel)
	local id = preview:GetAttribute("CaptureId")
	if typeof(id) ~= "string" then return end
	CaptureService:PromptSaveCapturesToGallery({ id }, function(results)
		-- results: which captures were saved; show a toast either way
	end)
end

local function share(preview: ImageLabel, zoneName: string)
	local id = preview:GetAttribute("CaptureId")
	if typeof(id) ~= "string" then return end
	CaptureService:PromptShareCapture(id, "photo:" .. zoneName, function() end, function() end)
end

-- Hide gameplay HUD for captures the player starts from the Roblox menu too
CaptureService.CaptureBegan:Connect(function() setHudVisible(false) end)
CaptureService.CaptureEnded:Connect(function() setHudVisible(true) end)
```

### Launch data
`launchData` is a short string you choose. When someone joins from the share, read it from the joining player's join data on the server (`Player:GetJoinData()`, **Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/Player#GetJoinData) and treat it as untrusted input: whitelist the values (`photo:<zoneId>`), never execute or teleport to arbitrary content from it. Use it to drop the newcomer near the photographed spot, and to attribute installs to photo sharing in analytics ([[Friend Invites Referrals and Experience Invites]]).

## 3. The photo-mode camera

- `Camera.CameraType = Scriptable`, driven at `Enum.RenderPriority.Camera.Value + 1`, with WASD/thumbstick move, mouse/drag look, a vertical control, roll (Q/E or a slider) and FOV slider (for example 20 to 100).
- **Leash.** Clamp the camera to a radius around the character (**Rule of thumb:** 30 to 60 studs). Beyond that, three things break: with `StreamingEnabled` the world is not streamed there and the photo shows holes ([[Instance Streaming]]); players use photo mode to scout enemy bases or puzzle answers; and the client renders far geometry the level was not dressed for.
- **Collision.** Spherecast from the last camera position to the new one and stop at hits, so the camera cannot go inside walls or under terrain ([[Camera Obstruction Handling - Occlusion Modes, Fades and Collision]]).
- **Freeze time optionally.** Pausing your own client animations and particles (`ParticleEmitter.TimeScale`, `AnimationTrack:AdjustSpeed(0)` on local tracks) gives action shots. Other players keep moving; that is fine.
- **Restore** camera type, subject, FOV, HUD, `MouseBehavior` and input on exit, death, respawn, teleport and character removal (same watchdog pattern as cutscenes, [[Cameras and Cutscenes]]).

## 4. Filters and composition helpers

Cheap, local, reversible:
- A photo-mode `ColorCorrectionEffect`, `BloomEffect` and `DepthOfFieldEffect` parented to `Lighting` *on the client only*, removed on exit. Depth of field focus distance from a raycast at screen centre gives a one-click "focus on subject" ([[Atmosphere Sky Clouds and Post-Processing]]).
- Rule-of-thirds grid overlay (hidden at capture).
- Character pose and emote picker: play local animations on the player's character; other clients will not see it, which is fine for a photo.
- Hide other players toggle: set their characters' `LocalTransparencyModifier` locally; restore on exit.

## 5. Safety and policy

- Captures can include other players' avatars and chat bubbles. Hide chat bubbles and nametags during captures by default.
- Do not reward saves or shares with currency (**Rule of thumb**, and incentivised sharing risks platform policy; see [[Policy and Age Rules 2026]]). Reward *using* photo mode (a badge for the first photo) if anything.
- `PromptShareCapture` availability depends on the player's account and settings; if the share callback reports denial, do not reprompt.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Capturing with the toolbar visible | Every photo shows your buttons | Hide UI, wait a frame, capture |
| Unleashed free camera | Streaming holes, scouting exploits | Radius clamp around the character |
| Not restoring the camera | Player stuck in Scriptable after death | Watchdog on every exit path |
| Auto-prompting save or share | Players dismiss by habit | Prompt only on button press |
| Trusting launch data | Join-time exploits | Whitelist and validate on the server |
| Photo mode allowed in combat | Deaths during photo mode | Safe zones or invulnerability with rules |

## Checklist
- [ ] Capture hides HUD, chat bubbles and nametags; `CaptureBegan/Ended` also handled for menu captures.
- [ ] Save and share only on explicit buttons; results handled gracefully.
- [ ] Free camera leashed, collides, and restores on every exit path.
- [ ] Launch data whitelisted; joiners routed and attributed.
- [ ] Filters are client-only and removed on exit.

## See also
[[Camera Systems]] · [[Cameras and Cutscenes]] · [[Friend Invites Referrals and Experience Invites]] · [[Atmosphere Sky Clouds and Post-Processing]] · [[Instance Streaming]] · [[Platform Features Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Engine and API Changes 2025-2026]] · [[Avatar Context Menus Profiles and Social Surfaces]] · [[Camera Obstruction Handling - Occlusion Modes, Fades and Collision]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Experience Notifications and Return Prompts]] · [[Console and VR Release Checklists]] · [[Roblox Changes 2025-2026]] · [[Server Authority and Input Migration 2026]] · [[Regional Compliance - Paid Random Items and Country Rules]] · [[Badges and Achievement Design]]
<!-- related:end -->
