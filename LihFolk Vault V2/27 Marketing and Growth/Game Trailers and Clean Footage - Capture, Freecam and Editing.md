---
tags: [marketing, trailer, video, freecam, capture, video-thumbnails, editing, store-page, type/guide, area/growth, area/marketing, level/intermediate]
---
# Game Trailers and Clean Footage - Capture, Freecam and Editing

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Spoken narration or lyrics in the video thumbnail.
> - Avoid: Studio-only lighting or post-processing the live game does not have.
> - Avoid: Logo first. Wastes the hook.
> - Edit permission confirmed for whoever films in live servers.
> - Shots captured with freecam (low stiffness), Player Lock, nameplates hidden.
> - Hook in the first 3 s; core verb by 10 s.
>
> Cost: TL;DR ~130 tok · whole note ~1.9k tok. Read more: ## The built-in free camera (Roblox docs) · ## Video thumbnails on the experience page (Roblox docs) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A landscape trailer serves two places: the experience page's **video thumbnail** (Roblox-hosted, strict rules) and off-platform channels (a YouTube trailer, a devlog, a press kit). This note covers the built-in free camera and its 2026 configuration menu, the video thumbnail rules, a gameplay-first trailer structure, and an edit workflow. Vertical short-form clips have their own note, [[Short-Form Video Marketing]], which also covers a UI-hide script and a capture place; this note does not repeat those.

Source labels: **Roblox docs** (create.roblox.com, read 28 October 2026), **Rule of thumb**.

## The built-in free camera (Roblox docs)

Freecam is available in Studio playtests and **in the live client for the experience owner or anyone with edit permission**. That last part matters: you can film real servers with real lighting and network behaviour, not just Studio.

- Toggle: **Left Shift + P** (keyboard only). On-screen UI hides automatically.
- Move: WASD; up and down: E and Q; look: hold right mouse; field of view: scroll wheel; roll: Z and C (double-tap to reset); hold Shift for slow, precise movement. Gamepad works once freecam is active.
- **Configuration menu** (Up arrow or D-pad Up): speed and *stiffness* (how much easing) for movement, rotation, roll and FOV; toggles for ScreenGuis and the leaderboard; **Player Lock**, which makes the camera follow a chosen player in the server; and **custom post-processing** (depth of field, bloom, blur, colour correction, sun rays, colour grading) that replaces your game's own while filming.
- The configuration menu and custom post-processing require `Workspace.PlayerScriptsUseInputActionSystem` to be Enabled.
- Separate GUI shortcuts, holding Ctrl (Cmd on macOS) + Left Shift: **G** core UI, **C** your ScreenGuis, **B** BillboardGuis, **N** player nameplates.

Practical use:

- Low stiffness plus slow movement gives smooth dolly moves without a cutscene system.
- Player Lock on a teammate's character gives clean third-person tracking shots of real gameplay.
- Hide nameplates (N) when filming other people, or film with team accounts in a private server.
- Keep freecam post-processing subtle when footage is for a video thumbnail; see the rules below.

For scripted, repeatable shots (a flythrough you re-record after every art pass), a cutscene path is still better; see [[Cameras and Cutscenes]].

## Video thumbnails on the experience page (Roblox docs)

- Free, limited to **3 uploads per month**; rejected uploads still count.
- Once approved, the video shows first on the experience details page and can appear on Home.
- Not supported on Xbox, PlayStation or VR (static thumbnails show there).
- Content rules: authentic in-game footage only; no gameplay, UI or interactions that are not in the game; reflects the game's core themes; **no real-life footage, no spoken audio** (no voice-over, narration or voice chat), no music with lyrics; Roblox catalog music is allowed; text overlays sparing and descriptive; no ads, promotions or subjective claims ("best game ever").
- Graphics must match what players see. Minor brightness, contrast or small effects are allowed; "artificially enhancing graphics beyond what a player will experience" is not. Free camera work is explicitly allowed if it shows real gameplay.

The docs page does not list resolution or length limits as of this reading; check the upload dialog for current constraints.

Because uploads are limited, cut the thumbnail video last, from footage already used and validated elsewhere.

## Trailer structure (rule of thumb)

Viewers decide in seconds. Lead with play, not logos.

| Time | Beat | Content |
|---|---|---|
| 0 to 3 s | Hook | The most exciting real moment: the boss hit, the rare roll, the escape |
| 3 to 10 s | What you do | The core verb, shown from the player's camera with real UI if it helps reading |
| 10 to 25 s | Why it is fun | 3 to 5 short shots of variety: progression, friends, new zone |
| 25 to 35 s | Freshness | The current update's headline content |
| End | Title card | Game name and "Play on Roblox"; for off-platform versions, a QR or link in the description, not in the game |

For a video thumbnail, drop the call to action and promotional text; describe gameplay only. Keep it short; the docs give no target length, and a tight 20 to 30 s loop is a safe default.

## Capture settings

- Record at the highest resolution your display supports, 60 fps, with graphics quality at maximum **and** a second pass at a mid setting to check honesty: the trailer should not look like a different game from what a phone player sees.
- Use a recorder with a constant frame rate; variable frame rate footage causes audio drift in editors.
- Capture game audio and music on separate tracks if your recorder allows, so you can duck music under impacts.
- Turn off developer-only debug UI and test badges; check the CoreGui is hidden (Ctrl+Shift+G) for clean frames.

## Editing workflow

1. Log every usable shot with a one-line label while recording (saves hours).
2. Assemble to music first; cut on beats; impacts land on downbeats.
3. Prefer cuts under 2 s in the hook section, longer shots for beauty moments.
4. Colour: only global, mild correction for the video thumbnail; off-platform you have more freedom but should stay recognisably the same game.
5. Export a master, then derive: 16:9 store video, 16:9 YouTube trailer with title card, 9:16 crops for shorts.

Music: Roblox's library audio is licensed for use on Roblox; whether a track can be used in an off-platform video depends on its licence. Use music you own or have explicitly licensed for external video.

## Common mistakes

- **Spoken narration or lyrics in the video thumbnail.** Rejected, and it uses one of three monthly uploads.
- **Studio-only lighting or post-processing** the live game does not have.
- **Logo first.** Wastes the hook.
- **Other players' names visible.** Hide nameplates or use team accounts.
- **Cutting the store video first.** Validate shots in off-platform edits, then spend an upload.
- **Assuming freecam's configuration menu works without the input action system setting.**

## Checklist

- [ ] Edit permission confirmed for whoever films in live servers.
- [ ] Shots captured with freecam (low stiffness), Player Lock, nameplates hidden.
- [ ] Hook in the first 3 s; core verb by 10 s.
- [ ] Store video: authentic footage, no voice, no lyrics, no claims, minimal text.
- [ ] Honesty pass at mid graphics settings.
- [ ] Master exported; 16:9 and 9:16 derivatives cut.

## See also

- [[Short-Form Video Marketing]]
- [[Thumbnails Icons and Store Page]]
- [[Cameras and Cutscenes]]
- [[Atmosphere Sky Clouds and Post-Processing]]
- [[Working with Content Creators]]

## Connected notes

[[Game Icon Design - Readable at Small Sizes]] · [[Launch Strategy - The First Two Weeks]] · [[Marketing and Growth Start Here]]

Sources: https://create.roblox.com/docs/workspace/camera/free-camera ; https://create.roblox.com/docs/production/publishing/thumbnails (both read 28 October 2026).

<!-- related:start -->
## Related
[[Experience Description and Search Keywords]] · [[Marketing to Kids and Teens - Age Rules and Paid-Promo Disclosure]] · [[Update Cadence and Hype Cycles]] · [[Sponsored Ads and Campaign Math]] · [[Rescuing a Weak Launch - Empty Servers, Low CCU and Relaunch Tactics]] · [[Competitor Analysis Method]] · [[A-B Testing and Experiments on Roblox]] · [[Roblox Communities as Your On-Platform Hub]]
<!-- related:end -->
