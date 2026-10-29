---
tags: [animation, mocap, mixamo, licensing, legal, retargeting, type/guide, area/animation, area/business, level/intermediate]
---
# Free Mocap and Mixamo Licensing for Roblox

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Downloading a "free CMU FBX pack" with a non-commercial licence and shipping it in a paid game.
> - Avoid: Publishing Mixamo or CMU animations as free models or Creator Store packages.
> - Avoid: Selling raw mocap as emote items without checking the licence.
> - Licence read at the source (Adobe, CMU, vendor), snapshot saved.
> - Converted packs checked for their own licence; prefer converting originals yourself.
> - Use is inside your game, not redistribution of the data.
>
> Cost: TL;DR ~160 tok · whole note ~2.0k tok. Read more: ## 1. Mixamo (Adobe) · ## 4. Mapping the terms onto Roblox uses · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Free motion data is the fastest way to get believable locomotion, emotes and NPC idles into a Roblox game: Adobe's Mixamo, the CMU Graphics Lab Motion Capture Database, and many smaller libraries. Each has terms, and the terms all draw the same line in different places: **using** the motion inside your game is usually fine; **redistributing** the raw data (selling it, uploading it as a free model pack, publishing it as standalone items) usually is not. Roblox adds a twist, because uploading an animation to Roblox and putting it on the Creator Store can look a lot like redistribution.

This note covers what the main sources allow, how that maps onto Roblox uses, and a short pointer to the retarget workflow. Not legal advice; terms below were checked October 2026 and change. Labels as marked.

---

## 1. Mixamo (Adobe)

What Adobe's Mixamo FAQ says (as posted by Adobe on its community forum, [Mixamo FAQ: licensing, royalties, ownership](https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400); the helpx page refused automated access when checked):

- Characters and animations are **royalty free** for personal, commercial and non-profit projects, including games.
- There are no limits on paid or unpaid project types **as long as the distribution rules are followed**.
- The thing you may not do is **distribute the raw character and animation files**, for example in packs sold or given away on 3D stock or asset store sites. Team members on a project may share the files internally.
- You need an Adobe account to download. Reports in 2026 describe Mixamo as online but in maintenance mode (**Unverified**: third-party guide).

The FAQ text Adobe staff posted dates from 2022 and calls the service a technical preview; read the current Adobe terms before a commercial launch.

## 2. CMU Graphics Lab Motion Capture Database

The CMU notice (as reproduced by mirrors of the dataset) says the data is free for research and that you **may include it in commercially sold products but may not resell the data directly, even in converted form**. Source: [mocap.cs.cmu.edu](http://mocap.cs.cmu.edu/); quoted on the [4TU FBX conversion page](https://data.4tu.nl/datasets/0448aab2-3332-449f-a8e2-d208cb58c7df).

Two traps:

- **Conversions carry their own licence.** The 4TU FBX conversion record lists CC BY-NC 4.0, which forbids commercial use, even though CMU's original notice allows commercial products. If you download a converted pack, you are bound by the converter's licence too. Safer: convert the original BVH or ASF/AMC data yourself.
- Aggregator sites describe the data as "no restrictions". They are wrong about the resale rule. Rely on CMU's notice.

## 3. Other sources

Many other free mocap libraries exist (vendor freebies, marketplace samples, academic datasets). Patterns to check in each licence (**Rule of thumb**):

| Clause | Watch for |
|---|---|
| Non-commercial / research only | Common for academic datasets; not usable in a game with paid items |
| Attribution required | Add a credits entry |
| No redistribution / no "UGC platforms" | Some forbid putting data in user-generated content platforms; Roblox is one ([[Animation Capture and Mocap]] notes this) |
| Seat or project limits | Paid packs often licence per project or per seat |

Roblox's own **Animation Capture** (from video, in Studio) produces your own animation data; see [[Animation Capture and Mocap]] and [[AI Animation and Motion from Video]] for its quality and limits.

---

## 4. Mapping the terms onto Roblox uses

| Roblox use | Mixamo | CMU original | Reasoning |
|---|---|---|---|
| Retarget to R15, upload as an animation, play it in **your** game | Generally allowed | Allowed | The motion is part of the project; players cannot download the raw file (**Rule of thumb**) |
| Same, in a game with paid items | Allowed (royalty free, commercial) | Allowed ("commercially sold products") | |
| Sell an emote or animation pack as Marketplace items | Risky | Risky: close to reselling the data | Selling the motion itself, not a game that uses it |
| Publish a **free model or Creator Store package** of the animations | Not allowed: raw-file distribution | Not allowed: redistribution | Others can take the data out |
| Upload the Mixamo **character mesh** as a UGC avatar item | Avoid | n/a | Close to distributing the raw character |
| Share the `.fbx` with your team | Allowed (team sharing) | Allowed | Keep it in a private repo or drive |

The middle rows are judgement calls. **Unverified:** neither Adobe nor CMU has published Roblox-specific guidance that we found. When money depends on it, ask the licensor or a lawyer, or make your own motion.

Uploaded animations belong to the uploader (user or group); upload to the group that owns the game ([[Publishing Animations]]). That does not change the licence of the source data.

---

## 5. Retarget workflow pointers

Free mocap is never on a Roblox rig. The workflow is in other notes:

1. Import the FBX or BVH into Blender; clean up root motion and scale ([[Animation Data from Blender to Roblox]]).
2. Retarget to R15 with an explicit bone name map, not substring guessing ([[Retargeting Animations Between Rigs]], which includes a Mixamo-style skeleton map).
3. Drop limb translations from mocap; keep rotations only, or shoulders and elbows stretch ([[Retargeting Animations Between Rigs]], common pitfalls).
4. Fix foot sliding and loop seams; reduce keys.
5. Upload under the owning group; set priority and looping ([[Publishing Animations]]).
6. Score against the LihFolk animation rubric (`skills/quality-score/rubrics/animation.md`, minimum 8.5) before shipping.

---

## 6. Keep records

For each animation from external data: source (Mixamo clip name, CMU subject and trial number), licence snapshot or URL, date, who downloaded it, and the Roblox asset id. Add it to the asset manifest described in [[Disaster Recovery for a Roblox Game - Places, Code, Assets, Data and Accounts]] and the licence log in [[Legal Basics - IP Licenses and Assets]].

---

## Common mistakes

- Downloading a "free CMU FBX pack" with a non-commercial licence and shipping it in a paid game.
- Publishing Mixamo or CMU animations as free models or Creator Store packages.
- Selling raw mocap as emote items without checking the licence.
- Trusting aggregator summaries over the licensor's text.
- No record of where each animation came from.
- Shipping raw mocap without retarget clean-up (stretched limbs, sliding feet).

## Checklist

- [ ] Licence read at the source (Adobe, CMU, vendor), snapshot saved.
- [ ] Converted packs checked for their own licence; prefer converting originals yourself.
- [ ] Use is inside your game, not redistribution of the data.
- [ ] Uploaded under the owning group.
- [ ] Retargeted with an explicit map; limb translations removed.
- [ ] Provenance recorded in the manifest; attribution added where required.

## See also

- [[Animation Capture and Mocap]], [[Retargeting Animations Between Rigs]], [[Publishing Animations]]
- [[Legal Basics - IP Licenses and Assets]], [[Open-Source Licenses for Roblox Libraries - Quick Reference]]
- [[Who Owns AI-Generated Code and Assets]]

## Connected notes

[[Moon Animator and Third-Party Tools]] · [[Animation Data from Blender to Roblox]] · [[AI Animation and Motion from Video]] · Creator Store and Toolbox Safety

<!-- related:start -->
## Related
[[Animation Editor Advanced]] · [[Animation Editor Workflow]] · [[Animation Asset Permissions and Groups]] · [[Blender Armature and Bone Roll Conventions]] · [[Animation Review Checklist]] · [[Rigging in Blender]] · [[Locomotion and Melee Reference Numbers]] · [[Blade Grip and Wrist Limits]]
<!-- related:end -->
