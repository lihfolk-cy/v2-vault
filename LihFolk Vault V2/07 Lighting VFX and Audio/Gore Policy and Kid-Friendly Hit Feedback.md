---
tags: [vfx, gore, blood, maturity, content-maturity, policy, hit-feedback, combat, settings, compliance, type/guide, area/vfx, area/policy]
---
# Gore Policy and Kid-Friendly Hit Feedback

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Answering the questionnaire for the default setting instead of the maximum content the game can show.
> - Avoid: Persistent blood decals in a Minimal-label game.
> - Avoid: Red as the default hit colour. Easy to read as blood; pick a non-blood hit colour unless blood is intended.
> - Label target chosen before art; VFX style guide states "stylised" or "blood".
> - Questionnaire answered for the most extreme content reachable, including settings and modes.
> - Default hit feedback uses non-blood colours and no persistent marks (for Minimal or Mild targets).
>
> Cost: TL;DR ~180 tok · whole note ~2.1k tok. Read more: ## What the label rules say about blood and violence · ## Feedback that hits hard without blood · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Blood is one of the few visual choices that directly changes who can find and play your game. On Roblox, how much blood you show and how realistic it looks feeds the content maturity label, and the label gates audiences (including the Roblox Kids and Roblox Select audiences announced in 2026). This note maps the label rules to concrete VFX decisions and gives hit-feedback alternatives that feel just as punchy without moving you up a label.

Source labels: **Roblox docs** (create.roblox.com, "Content maturity labels", read October 2026), **Reported**, **Rule of thumb**. This is design guidance, not legal advice; your questionnaire answers are your responsibility.

## What the label rules say about blood and violence

From the content maturity page (Roblox docs, October 2026):

| Label | Violence | Blood |
|---|---|---|
| Minimal | occasional mild violence | light, unrealistic blood |
| Mild | mild violence, may be repeated | unrealistic blood, can be heavy |
| Moderate | moderate (non-graphic but realistic-looking) | light, realistic blood |
| Restricted | strong (graphic, realistic-looking) | heavy, realistic blood; Restricted is 18+ age-verified only |

Other points from the same page:

- Roblox does not allow realistic depictions of extreme gore at any label. Graphic examples such as dismemberment and visible organs push content to Restricted.
- Frequency is answered separately (occasional or repeated).
- Answer for the most extreme content anywhere in the game, not the average.
- A game with no maturity information is automatically restricted in playability for all players.
- Games targeting Roblox Kids and Select audiences, or regions with specific content policies, need the full questionnaire. See [[Policy and Age Rules 2026]] for the 2026 audience changes.

The practical line for most combat games: **stylised, unrealistic, light hit marks keep you at Minimal or Mild; anything that looks like real blood moves you to Moderate.**

## Translating the rules into VFX choices

"Unrealistic" vs "realistic" is not defined numerically by Roblox. Rule-of-thumb signals that read as unrealistic:

- Non-blood colours: white, yellow, the attacker's element colour, or the target's team colour.
- Stylised shapes: stars, shards, cartoon "pow" bursts, flat-shaded droplets that vanish in under half a second.
- No pooling, no persistent stains on characters or floors, no wound decals.

Signals that read as realistic (and push toward Moderate or above):

- Dark red, liquid-shaded particles with gravity and splatter.
- Blood decals that persist on floors, walls or avatars.
- Wound textures, severed parts, ragdolls with blood trails.

If you are unsure which side a look falls on, assume the higher label or tone it down. Mislabelling can lead to moderation of the game and account (Roblox docs).

## Feedback that hits hard without blood

Hit feel comes mostly from timing, sound and motion, not from red particles ([[Game Feel and Juice]]). A strong kid-friendly stack:

1. **Hit-stop**: 40 to 90 ms freeze on attacker and target ([[Hit-Stop and Screen Shake Tuning by Numbers]]).
2. **Target flash**: brief white or tinted flash on the target via a pooled `Highlight` (fill transparency tweened from about 0.3 to 1) or a material/colour swap. Mind the Highlight concurrency limit ([[Highlights and Selection Effects]]).
3. **Impact burst**: white-core star or shard burst at the contact point, biased along the attack direction. For slashes, keep the burst and the slash arc in front of the attacker (frontal arc); radial bursts are for explosions and ground slams.
4. **Knockback and stagger animation** on the target ([[Hit Reactions Stagger and Hit-Stop]]).
5. **Damage number** that pops and floats, crit in a different colour and size.
6. **Layered sound**: transient crack plus body thump ([[Combat Sound Design and Feedback]]).
7. **Camera**: tiny shake for the attacker on heavy hits only.

Shooter-specific: replace blood puffs with hit-marker crosshair ticks, a target outline flash and a distinct headshot sound.

## A blood setting, done properly

If your game is labelled for blood, a player setting that reduces it is good practice, but **the label must reflect the maximum the game can show**, so a toggle does not let you claim a lower label. A clean implementation:

```lua
--!strict
-- Shared config: the server decides the ceiling; the client may choose less.
local HitFXConfig = {}

-- Set from your published label decision. "Stylised" never shows red liquid.
HitFXConfig.MaxStyle = "Stylised" :: "Stylised" | "Blood"

-- Client preference, saved with player settings. Defaults to the safer option.
function HitFXConfig.effectiveStyle(preference: string?): string
	if HitFXConfig.MaxStyle == "Stylised" then
		return "Stylised"
	end
	return if preference == "Blood" then "Blood" else "Stylised"
end

return HitFXConfig
```

Default the preference to "Stylised" for everyone. The ceiling being server-defined means a later decision to drop to a lower label is one constant, and you can verify no blood assets are loaded when `MaxStyle` is "Stylised".

## Horror and gore-adjacent content

Horror games often hit the "fear" descriptors before blood ones. The content maturity page treats fear-based content separately and lists visible organs and blood vessels at the Moderate fear level (Roblox docs). Corpses, skeletons and jump scares need their own questionnaire answers even if no blood is shown. See [[Genre Playbook - Horror and Story]].

## Thumbnails and store page

Your icon, thumbnails and video thumbnails must match the game. Showing blood in a thumbnail for a game labelled without blood, or vice versa, is a mismatch moderators and players notice ([[Thumbnails Icons and Store Page]]).

## Common mistakes

- **Answering the questionnaire for the default setting** instead of the maximum content the game can show.
- **Persistent blood decals in a Minimal-label game.** Persistence and realism both push up.
- **Red as the default hit colour.** Easy to read as blood; pick a non-blood hit colour unless blood is intended.
- **Ragdoll plus red particles plus dismemberment** "for fun" in a battlegrounds game. Dismemberment is a Restricted-level example.
- **Thinking a toggle lowers the label.** It does not; the label covers what the game can show.
- **Highlight flashes that are never destroyed or reused,** exhausting the Highlight limit in big fights.

## Checklist

- [ ] Label target chosen before art; VFX style guide states "stylised" or "blood".
- [ ] Questionnaire answered for the most extreme content reachable, including settings and modes.
- [ ] Default hit feedback uses non-blood colours and no persistent marks (for Minimal or Mild targets).
- [ ] Hit-stop, flash, burst, stagger, number and sound carry the feel.
- [ ] Slash bursts stay in the attacker's frontal arc.
- [ ] Optional blood setting defaults to off and is capped by a server ceiling.
- [ ] Store art matches the in-game content level.

## See also

- [[Policy and Age Rules 2026]]
- [[Roblox Policies Ratings and Compliance]]
- [[Hit Reactions Stagger and Hit-Stop]]
- [[Game Feel and Juice]]
- [[Combat Sound Design and Feedback]]
- [[Genre Playbook - Horror and Story]]

## Connected notes

[[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]] · [[Impact Decals and Material-Aware Hit Sparks]] · [[Genre Playbook - Battlegrounds and Arena Fighters]] · Ethical Design and Player Trust

Source: https://create.roblox.com/docs/production/promotion/content-maturity (read 28 October 2026).

<!-- related:start -->
## Related
[[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[VFX Design Playbook]] · [[VFX Readability and Value - Lessons from Blind Reviews]] · [[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]] · [[Slash VFX Recipes - Crescent and Ring]] · [[VFX Previews in Blender for Roblox - Colour and Framing]] · [[Light Sources and Shadows]] · [[VFX Performance Budgets and Culling]]
<!-- related:end -->
