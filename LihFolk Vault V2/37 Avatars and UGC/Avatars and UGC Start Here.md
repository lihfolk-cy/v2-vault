---
cssclasses: [vault-hub]
tags: [avatars, ugc, hub, start-here, marketplace, humanoiddescription, type/hub, area/avatars, level/beginner, api/ApplyDescriptionAsync, api/AvatarEditorService]
---
# Avatars and UGC Start Here

This section goes deeper on avatars from two sides: the **game developer** who has to handle every body, outfit and emote players bring in (and may want to sell items in their shop), and the **UGC creator** who makes and prices items for the Marketplace. It builds on [[UGC Avatar Items and Accessories]], the broader note that lists the specs, fees, advances and revenue shares. Read that first if you have not; the notes here assume its numbers and do not repeat them.

Everything time-sensitive is marked **as of October 2026**. Roblox renamed many yielding methods with an `Async` suffix during 2026 (for example `ApplyDescriptionAsync`, `GetProductInfoAsync`, `PlayerOwnsAssetAsync`); older tutorials use the deprecated names.

## The notes

| Note | Read it when |
|---|---|
| [[AvatarEditorService and In-Game Avatar Editors]] | You are building a catalog, try-on or "save outfit" feature: permissions, server-validated try-on, saving unowned items, rentals, performance |
| [[HumanoidDescription and Outfit Systems]] | You change how characters look in code: diff versus reset applies, uniforms over player avatars, saving outfits as data, NPC crowds |
| [[Layered Clothing Creation Workflow]] | You are making a layered garment: Blender setup, outer cage editing, skinning routes, the WrapLayer debug modes, garment-specific fixes |
| [[UGC Pricing Limiteds and Marketplace Rules]] | You are pricing or publishing: floor-relative prices, the revenue-share curve worked out, advance break-even, irreversible Limited switches, in-game sales |
| [[Bundles Animation Packs and Emotes for Sale]] | You are making bodies, emotes or animation packs, or integrating emotes in a game: validator rules, the 8-slot wheel, pilot-only packs |
| [[Avatar Body Types and Scale in Gameplay]] | Avatar variety affects your gameplay: Avatar Settings, collision modes, measuring characters, fair hitboxes, level and camera design |

## Suggested paths

**Game developer adding avatar features:** HumanoidDescription and Outfit Systems, then [[AvatarEditorService]] and In-Game Avatar Editors, then Avatar Body Types and Scale in Gameplay. Finish with the in-game sales section of UGC Pricing Limiteds and Marketplace Rules.

**Competitive or obby game:** Avatar Body Types and Scale in Gameplay first. It decides whether you need any of the rest.

**UGC creator:** [[UGC Avatar Items and Accessories]], then Layered Clothing Creation Workflow, then UGC Pricing Limiteds and Marketplace Rules, then Bundles Animation Packs and Emotes for Sale.

## Five things that surprise people

1. **Saving an avatar does not give players items they do not own.** An editor that lets players try on catalog items needs a buy step before the save prompt.
2. **`ApplyDescriptionAsync` diffs against a cache.** If any other script changed the character, use `ApplyDescriptionResetAsync`.
3. **The outer cage is for the next layer.** A garment can look perfect alone and ripple everything worn over it.
4. **Doubling a price from the floor to 2x more than triples creator Robux per sale.** The floor tier pays 30 percent, 2x pays 50.
5. **Turning on resale for a Limited is permanent** and disables restocking for good.

## Related notes elsewhere in the vault

- Animation side: [[Layered Clothing Cages and Animation]], [[Emotes and Social Animation]], [[Scale and Animation]], [[Facial Animation and Dynamic Heads]], [[The Default Animate Script]], [[Accessories and Armor That Follow Animation]], [[R15 Rig Anatomy and Attachments]]
- Characters: [[Characters and Humanoids]], [[Custom Characters and StarterCharacter]], [[Cookbook - Players and Characters]]
- Modelling: [[Weight Painting and Skinning for Roblox]], [[Exporting and Validating Models for Roblox]], [[Modeling Characters for R15 and Custom Rigs]]
- Money and policy: [[Monetization Overview]], [[Pricing and Store Design]], [[Paid Random Items and Odds Disclosure in Practice]], [[Roblox Policies Ratings and Compliance]]
- Gameplay: [[Hitboxes and Hit Detection]], [[Camera Systems]], [[Obby and Platforming Level Design]]

## Open questions for this section

Not confirmed as of October 2026, and flagged in the notes: whether `ApplyDescriptionAsync` is still server-only for player characters; AvatarEditorService rate limits and the outfit cap; the platform body-scale ranges; the root-motion thresholds of the emote validator; the current status of animation-pack selling (reported as pilot-only); the current rules for free UGC Limited rewards in experiences.

## Connected notes
<!-- auto-links:start -->
[[Official Docs - Asset Creation]] · Commerce and Physical Goods · Official Docs - Characters and Animation · 3D Importer Settings Reference · Skinning Weights
<!-- auto-links:end -->
