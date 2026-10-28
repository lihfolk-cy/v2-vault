---
tags: [field-notes, audio, sound, sound-design, combat, asset-audit, marketplace]
---
# Sound Design Pitfalls - Reused Ids Onsets and Layered Loops

<!-- tldr:start -->
> [!tldr] TL;DR
> - A "chime" sounds like a weapon: Id reused by name, never checked -> Audit ids with `GetProductInfoAsync`, use role keys
> - Swings feel like clicks after a batch: Trim removed the swell -> Trim before the -40 dB crossing, listen to each
> - Swing disconnected from animation: Fade-in too short, peak not on contact frame -> 30 to 60 ms swell, align peak to contact
> - Every sound id in the place counted and its real asset name checked.
> - Code asks for roles, not raw ids.
> - Trimmed sounds keep their swell; each trimmed swing auditioned.
>
> Cost: TL;DR ~180 tok · whole note ~1.7k tok. Read more: ## 1. Audit reused ids by what they are, not what they are called · ## 2. Onset trimming that removes the attack · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most combat audio problems in a large Roblox game are not about choosing good sounds. They are about bookkeeping: an id reused in places nobody remembers, an automated trim that cut the part of the sound that mattered, two copies of a swing playing on top of each other, and a loop that cannot be partly turned down. This note collects five such pitfalls from a shipped action game and the fixes. Fundamentals are in [[Sound Design for Games]] and [[Combat Sound Design and Feedback]]; the import side in [[Audio Pipeline]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## 1. Audit reused ids by what they are, not what they are called

**Measured.** An id named "chime" in config was used for UI confirmations, pickups and level-ups: 95 places in total. It was in fact a lightsaber-style deflect sound. Everyone who added a new use had copied the name from an existing use. Nobody had listened to it in isolation in months, because in context it "sort of worked".

Names drift because the name lives in your code, not on the asset. The asset's real name and creator live on the platform. Check them:

```lua
-- Command bar: count every audio id in the place and look up its real asset name.
local MarketplaceService = game:GetService("MarketplaceService")
local counts: { [number]: number } = {}

local function note(idString: string)
	local id = tonumber(string.match(idString, "%d+"))
	if id then
		counts[id] = (counts[id] or 0) + 1
	end
end

local roots = { workspace, game.ReplicatedStorage, game.ServerStorage, game.StarterGui,
	game.StarterPlayer, game.SoundService, game.ServerScriptService, game.ReplicatedFirst }
for _, root in roots do
	for _, d in root:GetDescendants() do
		if d:IsA("Sound") and d.SoundId ~= "" then
			note(d.SoundId)
		elseif d:IsA("LuaSourceContainer") then
			for id in string.gmatch(d.Source, "rbxassetid://(%d+)") do
				note(id)
			end
		end
	end
	task.wait()
end

for id, n in counts do
	local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, id, Enum.InfoType.Asset)
	print(n, id, if ok then info.Name else "lookup failed")
	task.wait(0.2) -- stay polite with the web API
end
```

`GetProductInfoAsync` is the current name of the product-info call; `GetProductInfo` is deprecated (Roblox docs, see [[Pricing and Store Design]]). Sort the output by count. The top twenty ids are your game's sound identity; listen to each one alone. The pattern is anchored on a literal prefix, so it is cheap even on large scripts (see [[Studio Automation Without Freezing Studio]] for patterns that are not).

**Rule of thumb:** give each sound a role key (`UI.Confirm`, `Combat.Deflect`) in one sound table, and have code ask for the role. Then one sound used in 95 places is one line to change, and a mismatch between role and asset is visible on review.

## 2. Onset trimming that removes the attack

Trimming leading silence makes sounds respond faster, and automated trimming by an amplitude threshold is a common batch step. The trap: many whooshes and swells *begin* below the threshold. The trimmer cuts the rising swell and leaves only the peak.

**Measured.** After a batch trim, swing sounds started at full loudness. They felt like clicks, not swings. Re-trimming from the untouched source files, keeping the quiet rise, brought the motion back.

**Rule of thumb:** trim to a few milliseconds *before* the first sample above about -40 dB, never to the first sample above a loud threshold, and listen to every trimmed swing. Inside Roblox, `Sound.PlaybackRegion` with `PlaybackRegionsEnabled` lets you offset the start without re-uploading (Roblox docs), which is handy for testing a trim before baking it.

## 3. Fade-ins that are too short

A swing has three parts: wind-up, the fast middle, and the tail. A fade-in under about 10 ms on a whoosh removes the wind-up perception and the swing reads as "instant", disconnected from an animation that clearly takes 0.2 s to come around. Let the swell take 30 to 60 ms (rule of thumb), and align the *loudest* point with the animation's contact frame, not the sound's start with the animation's start ([[Feedback Timing - Sound Visual and Haptic Sync]]).

## 4. Overlaps you did not mean

Fast attack chains replay the same swing sound before the previous one has ended, and two identical waveforms slightly offset produce a hollow, phasey doubling. Rules that worked:

- **One voice per sound key per source.** Starting a new swing on a weapon stops or quickly fades the previous swing on that weapon.
- **A global cap per key** (for example four concurrent copies of a hit) for crowds.
- **Small random pitch variation** (plus or minus 3 to 5%) so repeats are not identical.

## 5. Layer loops so you can drop one layer

**Measured.** Weapons had a looping hum while drawn. The high "swing whine" part was the piece that needed to go in some mixes while the low body stayed. Because each hum was a single mixed file, the only option was to turn the whole thing down.

Build per-weapon loops from layers (body, low, and a separate high "swing whine" layer) as separate `Sound` objects routed to separate `SoundGroup`s. Then a settings toggle or a mix rule can drop or duck only the whine. Optional layers are the reason [[ipairs Stops at the First nil - Cleanup Tables That Leak]] exists: stop them with a cleanup list that cannot skip.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| A "chime" sounds like a weapon | Id reused by name, never checked | Audit ids with `GetProductInfoAsync`, use role keys |
| Swings feel like clicks after a batch | Trim removed the swell | Trim before the -40 dB crossing, listen to each |
| Swing disconnected from animation | Fade-in too short, peak not on contact frame | 30 to 60 ms swell, align peak to contact |
| Hollow doubled sound in fast combos | Same sound overlapping itself | One voice per key per source, pitch variance |
| Players mute weapon audio entirely | Whine baked into a single loop | Separate high layer in its own `SoundGroup` |

## Checklist

- [ ] Every sound id in the place counted and its real asset name checked.
- [ ] Code asks for roles, not raw ids.
- [ ] Trimmed sounds keep their swell; each trimmed swing auditioned.
- [ ] Swing peaks aligned with contact frames.
- [ ] Per-source voice limit and global per-key cap in place.
- [ ] Weapon loops split into layers with separate groups.

## Connected notes
<!-- auto-links:start -->
[[Sound Design for Games]] · [[Combat Sound Design and Feedback]] · [[Audio Pipeline]] · [[Spatial Audio and Mixing]] · [[Feedback Timing - Sound Visual and Haptic Sync]] · [[Field Notes Start Here]]
<!-- auto-links:end -->
