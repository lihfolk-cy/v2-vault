---
tags: [modeling, ugc, marketplace, accessories, layered-clothing, avatar]
---
# UGC Avatar Items and Accessories

UGC (user-generated content) avatar items are 3D accessories, layered clothing, bodies, heads and emotes that creators sell on the Roblox Marketplace. Making one is a modelling and texturing job with an unusually strict technical spec, an automated validator, human moderation, real Robux fees and a revenue share. This note collects the requirements, specs, fees and publishing flow, all checked against the Creator Hub and Roblox announcements **as of October 2026**. Marketplace rules change several times a year; before you spend Robux, re-read the linked official pages.

Animation-side behaviour of garments (skinning, cages under motion) is in [[Layered Clothing Cages and Animation]]; in-game armour that is not a Marketplace item is in [[Accessories and Armor That Follow Animation]].

## 1. Who can sell (as of October 2026)

From the Marketplace policy and the publishing guide:

| Action | Requirements |
|---|---|
| **Upload** an avatar item | Government ID verification (or a linked parent account that is ID-verified), and the upload fee |
| **Publish** (put on sale) | ID verification (or linked verified parent), **2-step verification**, a **Roblox Plus or Premium 1000/2200** membership, and the publishing advance for the item type |
| **Keep items on sale** | The individual creator or the group owner keeps Roblox Plus or Premium 1000/2200 |
| Groups | The group must meet the Creator and Group requirements; the creator chosen at upload (user or group) controls pricing and sale |

A July 2026 announcement unified the 2D (classic clothing) and 3D publishing requirements, effective 14 July 2026, with non-compliant accounts' items taken off sale from 1 August 2026. It also moved 2D items to the same 30 percent creator share as 3D. 3D requirements and advances were described as unchanged.

## 2. Fees, advances and revenue share (as of October 2026)

### Upload fee

| Item | Upload fee (docs) |
|---|---|
| Standard submission | **80 Robux** |
| Items using an emissive mask | **500 Robux** |

Upload fees are generally **not refunded** if moderation rejects the item. Every update to a published item costs the upload fee again.

Note: the July 2026 announcement's main text still quoted 200 Robux per upload; its own 13 July update and the current fees page both say 80. Trust the fees page.

### Publishing advance (refundable through rebates)

Non-limited items (docs, selection):

| Asset type | Non-limited | Paid limited |
|---|---|---|
| Hat, Face | 1,500 | 13,000 |
| Hair | 1,000 | 6,000 |
| Neck, Shoulder, Front, Back, Waist | 1,000 | 15,000 |
| Jacket, T-Shirt, Shirt, Sweater, Pants, Dress/Skirt, Shorts, Shoes (3D) | 600 | 5,000 |
| Body | 2,500 | 20,000 |
| Head | 1,500 | 10,000 |
| Emotes | 1,500 | 10,000 |
| Classic t-shirt, shirt, pants (2D) | 10 | n/a |

Emissive items have higher non-limited advances (for example 7,500 for hats and face accessories, 5,000 for back, front, neck, shoulder, waist and hair, 3,000 for layered clothing). Free Limiteds pay a **per-unit fee** instead of an advance (market-based; the docs' example is 100 Robux per unit).

How the advance comes back: rebates are taken from the platform's 30 percent commission on your sales until the advance is repaid (the docs' example: a 1,000 Robux advance is fully rebated after 9 sales at 400 Robux). Taking an item off sale and back on does not charge the advance again.

### Revenue share

| Sale | Creator share (docs) |
|---|---|
| Marketplace purchase at the price floor | 30% |
| Marketplace purchase above the floor | Rises progressively: 1.3x floor 37%, 1.5x 41%, 2x 50%, 2.5x 57%, 3x 62%, 3.5x 65%, 4x 67%, 5x 69%, 6x and above 70% |
| In-experience purchase | 30% creator, 40% to the experience owner |
| Limited primary sale | 30% creator, 40% seller/affiliate, 30% Roblox |
| Limited resale | Original creator gets 10% |

Earnings sit in a **30-day escrow** from the sale date. Price floors per item type are shown in the Creator Dashboard rather than the docs; check there before pricing.

The 40 percent in-experience share is why many games sell UGC in their own shops: a game owner earns more on an item sold in their experience than the creator does (see [[Monetization Overview]] and [[Pricing and Store Design]]).

### Publishing limits

| Item | Daily limit (docs) |
|---|---|
| Free Limiteds | 50 per day enabled for sale |
| Paid Limiteds | No limit |
| Bodies and heads | No limit |

Only the first time an asset goes on sale counts. Paid Limiteds have a maximum quantity of 3,000. Limited purchase rate limits also apply to buyers (9 successful purchases per minute per user, maximum 3 per user per item, 60 seconds in the experience for in-game Limited purchases).

## 3. Item types and the two technical families

| Family | What it is | Examples |
|---|---|---|
| **Rigid accessory** | One mesh attached to one attachment point; moves rigidly with one body part | Hats, hair, face items, back items (wings, swords), shoulder pets, waist items |
| **Layered accessory (layered clothing)** | One mesh skinned to the R15 armature, with inner and outer cages, that wraps onto any body and over other layers | Shirts, jackets, sweaters, pants, shorts, dresses, shoes, some hair |
| Bodies and heads | Full avatar bodies, dynamic heads with FACS | Out of scope here; see [[Facial Animation and Dynamic Heads]] |

### Rigid accessory specs (docs)

| Item | Value |
|---|---|
| Meshes | One |
| Triangles | **4,000 maximum** |
| Topology | Watertight, no holes or backfaces; quads preferred, no 5+ sided faces |
| Size | Within the bounding box for its type and body scale, centred on its attachment |
| Textures | Up to **2048 x 2048** for Marketplace; larger is downscaled |
| Attachments | At least one, named for the accessory type (see below) |
| Body scale | `AvatarPartScaleType` StringValue: `Classic`, `ProportionsNormal` or `ProportionsSlender` (the Accessory Fitting Tool adds it) |
| Validation | Material `Plastic`, Transparency 0, VertexColor (1, 1, 1), no extra objects such as Scripts or extra Parts |

Bounding boxes in studs, width x height x depth (docs, selection):

| Type | Normal | Slender | Classic |
|---|---|---|---|
| Hat | 1.87 x 2.5 x 1.87 | 1.78 x 2.5 x 1.78 | 3 x 4 x 3 |
| Hair | 1.87 x 3.12 x 2.18 | 1.78 x 3.12 x 2.08 | 3 x 5 x 3.5 |
| Face | 1.87 x 1.25 x 1.25 | 1.78 x 1.25 x 1.18 | 3 x 2 x 2 |
| Neck | 2.95 x 3.68 x 2.16 | 2.59 x 3.39 x 1.92 | 3 x 3 x 2 |
| Front | 2.95 x 3.68 x 3.24 | 2.59 x 3.39 x 2.88 | 3 x 3 x 3 |
| Back | 9.86 x 8.59 x 4.87 | 8.64 x 7.91 x 4.32 | 10 x 7 x 4.5 |
| Waist | 3.94 x 4.29 x 7.57 | 3.76 x 3.29 x 6.73 | 4 x 3.5 x 7 |

Some boxes are off-centre (hair extends further down and behind than up and in front; back items extend further behind). Read the spec page for the exact offsets before you sculpt long hair or big wings. The Importer's Rig Scale choices map to these: Rthro = Normal, Rthro Narrow = Slender, Default = Classic.

Attachment names by type (docs): Hat `HatAttachment`; Hair `HairAttachment`; Back `BodyBackAttachment`; Front `BodyFrontAttachment`; Neck `NeckAttachment`; Waist `WaistFrontAttachment`, `WaistCenterAttachment` or `WaistBackAttachment`; Shoulder `RightShoulderAttachment`, `RightCollarAttachment`, `NeckAttachment`, `LeftCollarAttachment` or `LeftShoulderAttachment` (shoulder attachments move with the arm, collar attachments do not); Face `FaceFrontAttachment` or `FaceCenterAttachment`.

### Layered accessory specs (docs)

| Item | Value |
|---|---|
| Meshes | One render mesh, plus cages |
| Triangles | **4,000 maximum** |
| Size | Clothing within 8 x 8 x 8 studs centred on the attachment; eyebrows and eyelashes 1.5 x 0.5 x 0.5 |
| Cages | `<Name>_InnerCage` and `<Name>_OuterCage`. Outer starts identical to inner and is the only one you adjust. **Never delete cage vertices or change cage UVs** |
| Skinning | Weighted to an R15 armature, at most 4 influences per vertex, or generated by automatic skinning transfer |
| Textures | Up to 2048 x 2048 for Marketplace |
| Attachments | Tops `BodyFrontAttachment`; bottoms `WaistCenterAttachment`; others as rigid |
| Importer | Mesh objects with an `_Att` suffix are read as attachment points when importing caged meshes |
| Eyebrows and eyelashes | Cannot be uploaded alone; bundled with a body or makeup |
| Shoes | Two accessories `LeftShoeAccessory` and `RightShoeAccessory`, grouped as a Model before upload |
| Validation | Plastic, Transparency 0, VertexColor (1, 1, 1), no extra objects; invalid cages fail validation |

Start from Roblox's official cage templates and mannequins (Creator Hub avatar resources). Cages match by vertex index and UV, which is why the vertex and UV rules are absolute ([[Layered Clothing Cages and Animation]]).

## 4. Making a rigid accessory, end to end

1. **Concept against the box.** Block out inside the bounding box on a mannequin of each body scale you will support. Most failed uploads are "outside bounds", and Normal and Slender boxes are much smaller than Classic.
2. **Model** to 4,000 triangles or fewer, watertight, no internal faces. A hat that "only" has an open bottom fails the watertight rule; close it ([[Modeling Fundamentals for Games]], [[Low-Poly and Stylized Modeling]]).
3. **Unwrap** with one UV set in 0 to 1 ([[UV Unwrapping]]).
4. **Texture** with a SurfaceAppearance set or a single colour texture, at most 2048 ([[Texturing and PBR Baking]], [[Substance Painter and Texturing Tools]]). Emissive costs more to upload and publish, and EmissiveStrength must be within 0 to 40.
5. **Export** (FBX with Roblox's recommended settings, or glTF), import in Studio with the 3D Importer ([[Exporting and Validating Models for Roblox]]).
6. **Accessory Fitting Tool** (Avatar tab): converts the mesh into an `Accessory` with a `Handle`, the right attachment and the `AvatarPartScaleType` value, and lets you preview it on bodies of different types and sizes.
7. **Test** on several bodies: classic blocky, Rthro, slender, a large and a small scale, with animations (walk, jump, emotes). Watch for intersecting the head, floating above it (policy: hats and hair must sit on the visible head surface; floating attachments violate Marketplace policy), and covering the face.
8. **Upload**: right-click the Accessory > Save to Roblox > Submit As "Avatar Asset", pick the asset type. Validation runs when you pick the type.
9. **Fix validation errors** (usually back in Blender), then fill in title and description, pick the creator (you or a group) and submit, which charges the upload fee and sends the item to moderation.
10. **Publish** from the Creator Hub (Creations > Avatar Items > the item): choose Non-Limited or Limited, price ("amount above price floor", optional minimum price, regional pricing on by default), sale location (Marketplace and all experiences, or by place via API), then Publish Item (charges the advance). You can schedule sales up to 30 days ahead.

## 5. Layered clothing specifics

- **Weight to R15 or use automatic skinning transfer.** Authored weights give control (stiff collars, hems); automatic transfer is faster and handles skirts well. See the weighting guidance in [[Layered Clothing Cages and Animation]] and [[Weight Painting and Skinning for Roblox]].
- **Only move cage vertices.** Shrink-wrap the inner cage to the body template; inflate the outer cage to cover your garment's outer surface so the next layer fits over it.
- **Thickness and stacking.** A puffy jacket with an outer cage hugging the body makes anything worn over it clip; an outer cage far too large makes the next layer float.
- **Avatar Setup and fitting tools** in Studio preview garments on bodies and test with animations. Tool names and menus change; use the current Avatar tab.
- **Test extremes**: arms overhead, crouch, sitting, strides, big emotes; layered garments stretch and clip in exactly those poses.

## 6. Validation and moderation failures

| Failure | Typical cause | Fix |
|---|---|---|
| Mesh exceeds triangle limit | Over 4,000 triangles | Decimate or retopologise ([[Retopology and Decimation]]) |
| Outside bounding box | Too big for Normal or Slender scale, or attachment wrong | Rescale for each body scale; check off-centre bounds |
| Not watertight | Open edges, backfaces, internal faces | Fill holes, delete internals (Blender: Select All by Trait > Non Manifold) |
| Texture too large | 4096 export | 2048 or less |
| Wrong material / transparency / vertex colour | Handle not Plastic, Transparency not 0, VertexColor not 1,1,1 | Reset properties |
| Extra objects | Scripts, extra Parts, leftover attachments, welds | Remove; keep Accessory > Handle > Attachment(s), SurfaceAppearance, WrapLayer as needed |
| Cage errors | Deleted cage vertices, changed cage UVs, missing outer cage | Restart from template cages |
| Asset ids not owned | Textures or meshes uploaded by another account or group, or pending moderation | Upload under the same creator; wait for moderation |
| Text filter | Name or description | Rename |
| Moderation rejection | Policy (see below) | Read the policy before modelling |

Policy points that affect modelling (docs): no political, religious, gory, violent, drug-related, sexual, wedding or dating themes; no Roblox branding or Roblox-created assets; not overly similar to existing items (including re-publishing your own as Limited); minimal text; nothing that hides most of an avatar, hides game UI, makes avatars disappear, or relies on glitches; attachments on the visible head surface; care around mouth and waist; categorise correctly (complete hairstyles are Hair, facial hair is Face). You need rights to everything you upload, including permission for any IP.

## 7. Updating published items

Use "Update an existing asset" with the asset id. The id, sales history and owners are kept; each update costs the upload fee and goes through moderation. Updates are for fixes; substantial design changes are not allowed. Plan for this by testing thoroughly before the first upload.

## 8. UGC in your own game

If you also run a game:

- **Sell in-experience** with `MarketplaceService:PromptPurchase` for avatar items; the experience owner earns 40 percent (docs). See [[Monetization Overview]].
- **Gameplay gear is not UGC.** Weapons, armour and tools that only exist in your game do not need the Marketplace spec, fees or moderation; they are ordinary game assets. The reference project's armour was in-game only: welded MeshParts scaled per body part, no cages, up to about 3,300 triangles per piece. It hid hats and hair under helmets by setting their transparency. None of that would pass UGC validation, and none of it needed to.
- **Respect players' avatars.** Design game gear to sit over layered clothing (rigid welded plates) rather than replacing it ([[Accessories and Armor That Follow Animation]]).

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Modelling to the Classic box only | Fails Normal/Slender bounds | Check all three scales from blockout |
| Open-bottom hats, single-sided capes | Not watertight | Close and give thickness |
| 4K textures | Validation failure | 2048 max |
| Emissive added late | Higher upload fee and advance; strength limit | Decide early |
| Deleting cage vertices to "clean up" | Broken fitting, failed validation | Never edit cage topology or UVs |
| Uploading textures from a personal account for a group item | Ids not owned | Same creator for every asset |
| Treating updates as redesigns | Moderation rejection | New item instead |
| Assuming fees from an old tutorial | Wrong budget | Check the fees page the day you publish |

## Checklist

- [ ] Account: ID verification, 2-step verification, Plus or Premium 1000/2200 (as of October 2026).
- [ ] Budget: upload fee (80, or 500 emissive) plus the publishing advance for the type.
- [ ] Triangles at most 4,000; one mesh; watertight.
- [ ] Inside the bounding box for every body scale; attachment named for the type.
- [ ] Textures at most 2048; SurfaceAppearance correct; emissive 0 to 40.
- [ ] Plastic, Transparency 0, VertexColor 1,1,1, no extra objects.
- [ ] Layered: cages from templates, only positions edited, 4 influences, R15 armature or auto skinning.
- [ ] Tested on several bodies, scales and animations.
- [ ] Policy and IP reviewed before modelling, not after.

## See also

[[Layered Clothing Cages and Animation]] · [[Accessories and Armor That Follow Animation]] · [[R15 Rig Anatomy and Attachments]] · [[Weight Painting and Skinning for Roblox]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Exporting and Validating Models for Roblox]] · [[Texturing and PBR Baking]] · [[Substance Painter and Texturing Tools]] · [[3D Importer Settings Reference]] · [[Monetization Overview]] · [[Roblox Policies Ratings and Compliance]] · [[Roblox Policies on AI-Generated Content]]

## Connected notes
<!-- auto-links:start -->
[[Layered Clothing Creation Workflow]] · [[Bundles Animation Packs and Emotes for Sale]] · [[UGC Pricing Limiteds and Marketplace Rules]] · [[Avatars and UGC Start Here]] · [[Links - Avatars and UGC]] · [[HumanoidDescription and Outfit Systems]]
<!-- auto-links:end -->
