---
tags: [ai, legal, copyright, ownership, licensing, business, ugc, type/guide, area/ai, area/business, level/intermediate, area/avatars]
---
# Who Owns AI-Generated Code and Assets

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Assuming a vendor's "you own the output" means copyright exists and is enforceable.
> - Avoid: Raw AI output as the mascot or logo you will need to defend.
> - Avoid: No record of which tool and plan made which asset.
> - Core identity assets human-authored or substantially human-edited.
> - Provenance recorded for every AI asset (tool, model, plan, date, human changes).
> - Terms snapshot saved for each tool used commercially.
>
> Cost: TL;DR ~150 tok · whole note ~2.2k tok. Read more: ## 1. Copyright law: the human authorship line · ## 3. What this means for a Roblox game · ## Common mistakes · ## Checklist
<!-- tldr:end -->

"I made it with AI, so it's mine" and "AI made it, so nobody owns it" are both wrong often enough to hurt. Ownership of AI output has three separate layers: **copyright law** (can anyone own it at all), **the tool's terms** (what the vendor grants or keeps), and **platform rules** (what Roblox requires when you upload or sell). This note covers the first two in depth and how they affect selling a game, selling UGC and making deals. [[Roblox Policies on AI-Generated Content]] covers Roblox's own rules and vendor plan patterns; [[Legal Basics - IP Licenses and Assets]] covers IP in general.

This is general information, not legal advice. Law differs by country and is moving. Labels as marked; dates matter here.

---

## 1. Copyright law: the human authorship line

**United States** (most relevant for Roblox, a US company, and the jurisdiction with the clearest recent guidance):

- The US Copyright Office's report *Copyright and Artificial Intelligence, Part 2: Copyrightability* (January 2025) concludes that copyright requires human authorship, that prompts alone generally do not give enough control to make the output the user's authored work, and that existing law handles AI cases without new legislation. Human contributions remain protectable: selecting and arranging AI material creatively, modifying it substantially, or using AI as a tool inside your own expressive work. Source: [copyright.gov/ai](https://www.copyright.gov/ai/).
- *Thaler v. Perlmutter*: courts upheld refusing registration for a work listed as created autonomously by an AI. The D.C. Circuit affirmed in 2025 (reported as 130 F.4th 1039), and the US Supreme Court declined review on 2 March 2026 (summary: [Mayer Brown, March 2026](https://www.mayerbrown.com/en/insights/publications/2026/03/supreme-court-denies-review-in-ai-authorship-case)).

What that means in practice (**Rule of thumb**, based on the above):

| You did | Likely status in the US |
|---|---|
| Typed a prompt, used the output as is | The raw output is probably not protected by copyright. Others copying that exact piece may be hard to stop |
| Generated, then substantially edited (repainted a texture, remodelled a mesh, rewrote code) | Your human edits are protectable; the untouched AI parts may not be |
| Used AI for small parts inside your own larger work (autocomplete in your code, a generated base you sculpted over) | The work as a whole is generally yours; disclose AI parts if you register copyright |
| Selected and arranged many AI pieces into a level, UI kit or game | The selection and arrangement can be protectable even if pieces are not |

**Other countries differ.** The UK has a provision for "computer-generated works" with no human author; other countries require human creativity like the US. **Unverified** for any specific country beyond the US sources above: check local law if you or your buyer are elsewhere.

---

## 2. Tool terms: what the vendor gives you

Separately from copyright, the vendor's terms decide what you are allowed to do with output and whether they claim anything.

- **Code assistants.** Anthropic's Commercial Terms say the customer owns outputs and Anthropic assigns to the customer whatever rights it has in them, subject to compliance with the terms ([anthropic.com/legal/commercial-terms](https://www.anthropic.com/legal/commercial-terms)). Consumer plans have separate Consumer Terms. Other vendors use similar but not identical language; read yours.
- **Image, 3D, audio and music generators** often tie commercial rights to the plan at generation time, and some free plans are non-commercial only ([[Roblox Policies on AI-Generated Content]], section 4).
- **Roblox's own generators** (Assistant, Cube mesh generation, texture and material generation): governed by Roblox's terms for creator tools. Check the current Roblox Terms of Use and the generative AI pages before assuming exclusivity.

An assignment of "whatever rights we have" cannot create copyright where the law gives none. You can be fully licensed to use an output and still be unable to stop others copying it.

---

## 3. What this means for a Roblox game

### Code

- AI-written Luau that you reviewed, restructured and integrated into your architecture is, as a whole, your work in practice. Pure unedited generations are weaker. For a game, this rarely matters: the protection that counts is that your server code is not visible to players at all.
- **Licence contamination is the real code risk.** Models can reproduce snippets of public code. If an output looks like a recognisable library, check its licence ([[Open-Source Licenses for Roblox Libraries - Quick Reference]]).

### Art, models, audio

- Assets are visible and copyable. If an asset is the identity of your game (mascot, logo, key art), make it **human-authored or heavily human-edited**, so you can enforce rights against clones ([[Legal Basics - IP Licenses and Assets]], section 6 on copying).
- Generic filler (rocks, crates, background textures) matters less.

### UGC items

- Selling avatar items made with AI: check the generator's commercial terms, Roblox UGC rules, and that the output does not resemble existing brands or characters. Takedowns hit the seller.

### Selling a game, a studio or a licence

Buyers, publishers and brand partners increasingly ask about AI use in due diligence. Being able to answer helps:

- **Provenance log** per asset: tool, model, plan, date, prompt, and what a human changed. [[Roblox Policies on AI-Generated Content]] recommends the same record.
- **Which core IP is human-authored.**
- **Terms snapshots** of each tool at the time you used it.

A game whose key art and characters are raw prompt output may be worth less in a deal, because the buyer cannot be sure they can stop copies.

---

## 4. Contracts with people who use AI

If you hire builders, scripters or artists:

- Your contract should assign their work to you and require them to **disclose AI use** and the tools and plans used.
- Require that AI output was generated on plans permitting commercial use and that they hold no third-party claims.
- For key assets, require human authorship, or at least substantial human editing, in writing.

See [[Running a Small Studio as a Business]] for contractor basics.

---

## 5. Using LihFolk's workflow to keep records

- The `quality-score` ledger (`.lihfolk/ledger.jsonl`) already records each generated asset's name, type and parameters. Add `tool`, `model` and `plan` fields to entries for AI-made assets so provenance lives next to quality data.
- Keep a `PROVENANCE.md` or CSV in the repo for assets made outside the pipeline.

---

## Common mistakes

- Assuming a vendor's "you own the output" means copyright exists and is enforceable.
- Raw AI output as the mascot or logo you will need to defend.
- No record of which tool and plan made which asset.
- Contractors using free-plan generators for paid work.
- Treating AI code as licence-clean without checking recognisable snippets.
- Applying US conclusions to other jurisdictions without checking.

## Checklist

- [ ] Core identity assets human-authored or substantially human-edited.
- [ ] Provenance recorded for every AI asset (tool, model, plan, date, human changes).
- [ ] Terms snapshot saved for each tool used commercially.
- [ ] Contractor agreements require AI disclosure and commercial-plan use.
- [ ] Recognisable code snippets checked for licences.
- [ ] Ready answer for "what in this game is AI-made?" in a deal.

## See also

- [[Roblox Policies on AI-Generated Content]], [[Legal Basics - IP Licenses and Assets]]
- [[Open-Source Licenses for Roblox Libraries - Quick Reference]], [[Free Mocap and Mixamo Licensing for Roblox]]
- [[AI in Roblox Development Overview]], [[Evaluating AI Tools - A Practical Rubric]]

## Connected notes

[[Running a Small Studio as a Business]] · [[AI Image Generation for Icons Thumbnails and Concepts]] · [[AI 3D Model Generation Outside Roblox]] · [[Local vs Cloud AI - Keeping Unreleased Game Code Private]]

<!-- related:start -->
## Related
[[AI Audio - Voice Music and SFX]] · [[Roblox Built-In AI Tools Timeline 2023-2026]] · [[Roblox Generative AI - Cube Mesh and Texture Generation]] · [[Roblox Studio Assistant]] · [[AI Material and Texture Generation]] · [[AI Asset Pipelines - Scoring, Reviewers and Spot Checks]] · [[In-Game AI - LLM NPCs and Text Generation]] · [[AI Agents and Autonomous Workflows]]
<!-- related:end -->
