---
tags: [marketing, icon, store-page, composition, contrast, silhouette, readability, art-direction, testing, type/guide, area/growth, area/marketing]
---
# Game Icon Design - Readable at Small Sizes

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: A scene instead of a subject. Unreadable at 64 px.
> - Avoid: Low value contrast between subject and background.
> - Avoid: Text-heavy icons with update tags.
> - One big subject, readable expression, simple background.
> - Passes the greyscale test.
> - Hue distinct from the genre crowd; consistent brand colours.
>
> Cost: TL;DR ~120 tok · whole note ~1.9k tok. Read more: ## Composition rules (rule of thumb) · ## Test at real sizes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The icon is the one image that follows your game everywhere: search results, the Continue row, friends' activity, favourites, the mobile home sort. It is shown far smaller than the 512 x 512 you upload, often next to dozens of other bright squares. This note is about the craft of composing an icon that survives that: one subject, one read, strong value contrast, and a test procedure at real sizes. Specs and upload rules are in [[Thumbnails Icons and Store Page]]; patterns from top games are in [[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]].

Source labels: **Roblox docs**, **Rule of thumb** (LihFolk practice), **Unverified**.

## The job of an icon

An icon has about one glance to answer: "what kind of game is this and is it for me?". It does that with three things, in order:

1. **Silhouette**: a recognisable shape (a character, a creature, a single object).
2. **Value contrast**: subject clearly lighter or darker than the background.
3. **Colour identity**: a hue pair that becomes your brand and stays consistent across updates.

Text is fourth, and often absent. A short wordmark can help brand recall, but at small sizes most words become noise.

## Composition rules (rule of thumb)

- **One subject, big.** The subject should fill roughly 60 to 80 % of the frame. Two characters is the maximum; three becomes a crowd.
- **Face or focal point in the upper-middle.** Eyes and expressions read even when tiny; a character looking slightly toward the viewer outperforms a profile.
- **Expression carries genre.** Shock or fear (horror, chase), joy and excitement (simulator, pet), determination (combat), mischief (troll, obby).
- **Simple background.** A radial gradient or flat colour field, with a glow or rim light separating the subject. Busy scenes belong in thumbnails, not icons.
- **Crop for tension.** Let the subject break the frame edge slightly; it reads as bigger and closer.
- **Keep away from the corners.** Some surfaces round or mask icon corners; anything important in a corner can be clipped (Unverified for every surface; designing for it is cheap).
- **Avoid thin lines and small details.** Hair strands, weapon engravings and small UI elements vanish below about 100 px.

## Contrast and colour

- **Squint test / greyscale test.** Convert to greyscale. If the subject does not separate from the background, the icon fails for colour-blind players and in small sizes for everyone ([[Accessibility Contrast]], [[Thumbnail Contrast]]).
- **Pick a hue that differs from your genre's crowd.** If every simulator in the chart is yellow and green, a purple and orange icon stands out in a row. Check your competitors' icons side by side ([[Competitor Analysis Method]]).
- **Saturated subject, less saturated background** is a reliable default.
- **Rim light** on the subject in a complementary colour separates it from any background.

## Text and wordmarks

- If you use text, use one to two short words, heavy weight, with an outline or drop shadow.
- A custom letterform (a logo with one distinctive glyph) builds recognition over time; generic fonts do not.
- Do not put "UPDATE", "x2" or "FREE" on the icon. It cheapens the brand, goes stale and duplicates what the title already does.
- Localise text for your top regions, or keep the icon text-free so one image works everywhere ([[Localization]]).

## Test at real sizes

Never judge an icon at full resolution. A Studio test harness takes two minutes to build and catches most problems:

```lua
--!strict
-- Command bar or a test LocalScript: shows candidate icons at several sizes in a grid.
-- Upload candidates privately first; replace the content ids with your own.
local Players = game:GetService("Players")
local gui = Instance.new("ScreenGui")
gui.Name = "IconSizeTest"
gui.IgnoreGuiInset = true
local candidates = { "rbxassetid://YOUR_ICON_A", "rbxassetid://YOUR_ICON_B" }
local sizes = { 150, 100, 64, 48 }
for row, image in candidates do
	for col, px in sizes do
		local img = Instance.new("ImageLabel")
		img.Image = image
		img.Size = UDim2.fromOffset(px, px)
		img.Position = UDim2.fromOffset(20 + (col - 1) * 170, 20 + (row - 1) * 170)
		img.BackgroundTransparency = 1
		img.Parent = gui
	end
end
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
```

Then:

1. View on a real phone, not just the desktop emulator; pixel density changes perception.
2. Put the candidates in a mock row next to screenshots of the current top games in your genre at the same size.
3. Ask someone who has not seen the game: "What do you think this game is about?" If they cannot answer in two seconds, iterate.
4. Check against both light and dark app themes.

## Iterating live

- Roblox's thumbnail personalisation tests multiple **thumbnails** per user group (Roblox docs, thumbnails page). Icon testing is a different matter: treat any icon change as an experiment, change one thing at a time, and watch qualified play-through rate and impressions over comparable periods (weekday to weekday).
- Event recolours (a seasonal hat, a palette swap) can refresh an icon without losing recognition; keep the silhouette and wordmark stable.
- Keep a dated archive of every icon version with the metric window it ran in.

## Honesty

The icon must represent the game. A character or creature that does not appear in the game, or a render far beyond in-game fidelity, is misleading and hurts first-session retention when players notice ([[Thumbnails Icons and Store Page]]). AI-assisted icon art is subject to the same rules and to the notes in [[Roblox Policies on AI-Generated Content]].

## Common mistakes

- **A scene instead of a subject.** Unreadable at 64 px.
- **Low value contrast** between subject and background.
- **Text-heavy icons** with update tags.
- **Judging at 512 px on a big monitor.**
- **Changing silhouette, colour and wordmark at once** so returning players no longer recognise the game.
- **Icons that promise content the game does not have.**

## Checklist

- [ ] One big subject, readable expression, simple background.
- [ ] Passes the greyscale test.
- [ ] Hue distinct from the genre crowd; consistent brand colours.
- [ ] Nothing critical in corners; no thin details.
- [ ] Tested at 150, 100, 64 and 48 px on a phone, next to competitors.
- [ ] A stranger can name the genre in two seconds.
- [ ] Version archive with metric windows.

## See also

- [[Thumbnails Icons and Store Page]]
- [[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]]
- [[Icon and Thumbnail Rendering Pipeline]]
- [[AI Image Generation for Icons Thumbnails and Concepts]]
- [[Shape Language and Silhouette Testing]]

## Connected notes

[[Game Trailers and Clean Footage - Capture, Freecam and Editing]] · [[Competitor Analysis Method]] · [[A-B Testing and Experiments on Roblox]] · [[Marketing and Growth Start Here]]

<!-- related:start -->
## Related
[[Thumbnail Composition for High CTR - Focal Point, Contrast and Readability]] · [[Click-Through Rate]] · [[Thumbnail Specs, Rules and Upload - Sizes, Count and Policy]] · [[Thumbnail Review Checklist and Scoring Rubric]] · [[Making Thumbnails in Studio and Blender - Capture, Lighting and Posing]] · [[Experience Description and Search Keywords]]
<!-- related:end -->
