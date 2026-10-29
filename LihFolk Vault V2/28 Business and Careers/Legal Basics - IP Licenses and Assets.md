---
tags: [business, legal, ip, copyright, licensing, creator-store, assets, minors, type/guide, area/business, level/beginner]
---
# Legal Basics - IP Licenses and Assets

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Treating anything public as free to use.
> - Avoid: Assuming Creator Store assets are always clean.
> - Avoid: Non-commercial licences in games with paid items.
> - All game assets uploaded to the owning group, with source files kept.
> - Licence log for every third-party asset and library.
> - No non-commercial, share-alike or unknown licences in core content.
>
> Cost: TL;DR ~130 tok · whole note ~4.3k tok. Read more: ## 3. Using other people's assets · ## 5. Other people's games, brands and characters · ## Common mistakes · ## Checklist
<!-- tldr:end -->

> **Not legal advice.** This note explains general concepts that help Roblox developers ask the right questions. It is not legal advice. Copyright, trademark, contract and consumer law differ by country, and the details matter. For a real dispute, a takedown, a brand deal or a large contract, talk to a qualified lawyer where you live. The binding platform rules are Roblox's Terms of Use, Community Standards, the Creator Store terms and the Developer Exchange Terms of Use; read the current versions. **Minors** usually need a parent or guardian for contracts, licences and any legal process.

Every Roblox game is built from pieces: your code, your art, assets from the Creator Store, fonts, music, libraries from the community, ideas from other games. Each piece has an owner and a set of rules for who may use it. This note covers the concepts (copyright, trademarks, licences), how Roblox's own systems (asset permissions, the Creator Store, Rights Manager, License Manager) fit around them, and practical rules for keeping a game clean.

---

## 1. Four concepts in plain terms

| Concept | Protects | Roblox example | Plain-terms rule |
|---|---|---|---|
| **Copyright** | A specific expression: code, art, models, music, text | A mesh someone modelled; a script someone wrote | In many countries it exists automatically when the work is made; you need permission (a licence) to copy it |
| **Trademark** | Names, logos, branding that identify a source | A game's name and logo; a famous brand | Do not use others' brands in a way that suggests a connection |
| **Licence** | Permission from an owner, with conditions | An open-source licence on a library; a Creator Store asset's permissions | Read the conditions; they are the deal |
| **Contract** | An agreement between parties | A commission agreement | Defines who owns what between you ([[Commissions Pricing and Contracts]]) |

Two points people often get wrong:

- **Ideas and mechanics are generally not protected by copyright; expression is.** "A simulator where you click to gain strength" is an idea. The exact UI art, the code, the models and the music of a specific game are expression. Copying the idea is common practice; copying the expression is not yours to do. (General principle; how close is too close is a legal question, and it varies.)
- **"Found it online" is not a licence.** Images from search results, music from videos, models ripped from other games: unless the owner gave permission, you do not have it.

---

## 2. Owning your own work

### Solo work

In general, what you create alone, you own. Roblox's Terms of Use govern how content you upload can be used on the platform (including licences you grant to Roblox to host and display it). Read the current terms rather than relying on summaries.

### Team and contract work

Without a written agreement, ownership of team work can be unclear and, in some countries, may stay with the person who made it even if someone else paid. That is why every contract should state ownership after payment ([[Commissions Pricing and Contracts]], [[Hiring Freelancers and Revenue Shares]]), and why studios should have a founders' agreement saying who owns the games and IP ([[Running a Small Studio as a Business]]).

### Uploaded assets are a separate question

On Roblox, the account or group that **uploaded** an asset controls its permissions. That is a platform control, not a legal ownership statement, but it decides what works in practice:

- A Restricted asset loads only in games and for creators the owner has given explicit permission (Roblox docs, Creator Store, as of October 2026).
- Assets set to **Open Use** can be used by anyone who has the asset id (Roblox docs).
- Animations uploaded to a person's account may not play in a group's game ([[Animation Asset Permissions and Groups]]).

Practical rule: upload everything your game needs to the **group** that owns the game, from source files you own or have a licence for. Keep the source files.

---

## 3. Using other people's assets

### The Creator Store

The Creator Store is where creators distribute models, plugins, meshes, images, audio and more. Roblox docs (as of October 2026) say:

- Free assets are meant for other creators to use in their own development.
- You may distribute models, plugins, meshes, decals and audio you uploaded.
- Composite assets may include others' **Open Use** dependencies, but you **cannot distribute assets with Restricted dependencies you did not upload**.
- You cannot sell an edited asset you bought from someone else if it contains Restricted assets you did not create (with an exception for audio and video also on the Creator Store).
- Asset privacy "is not a form of DRM": it controls loading, not legal rights.

Being on the Creator Store does not prove an asset is clean. Someone can upload a model they do not own. Free models are also a security risk (hidden scripts, backdoors): [[Creator Store and Toolbox Safety]].

### Outside sources

| Source | What to check |
|---|---|
| Free 3D model sites | The exact licence per model; commercial use allowed? attribution required? |
| Texture and HDRI libraries | Many are CC0 (public domain dedication, no conditions); confirm per asset ([[Links - Free and CC0 asset libraries]]) |
| Fonts | Roblox ships a set of fonts; outside fonts need a licence that allows the use |
| Music and sound effects | Licences differ a lot; "royalty free" means no per-play fee, not "free to use" |
| Code libraries | The licence file in the repository (section 4) |
| AI-generated assets | The tool's terms on ownership and commercial use, and Roblox's rules ([[Roblox Policies on AI-Generated Content]], [[AI 3D Model Generation Outside Roblox]]) |

### Common licence types (general meanings)

| Licence | In short | Watch out for |
|---|---|---|
| **CC0** | Owner waives rights as far as possible | Check the person actually owned it |
| **CC BY** | Use freely with attribution | Attribution must be given as required, for example in a credits screen |
| **CC BY-NC** | Non-commercial only | A game with paid items is likely commercial; avoid unless you are sure |
| **CC BY-SA** | Share-alike: derivatives under the same licence | Hard to satisfy inside a game; avoid for core assets |
| **Standard asset store licences** | Usually: use in your products, no redistribution of the raw asset | Uploading the raw asset as an Open Use Creator Store item may count as redistribution |

### Keep a licence log

For every third-party asset in your game:

```
Asset: Stone texture set
Source: <site>, downloaded 2026-03-12
Licence: CC0
Used in: Forest zone, cave zone
Uploaded as: group asset (id recorded in the asset sheet)
Attribution needed: no
```

This log is what lets you answer a takedown in minutes and what clients and partners ask for ([[Asset Pipelines]], [[Documentation and Knowledge Bases]]).

---

## 4. Code licences for Luau libraries

Community libraries (signal classes, profile managers, UI frameworks) are usually published under an open-source licence. General meanings:

| Licence | Typical conditions | For a Roblox game |
|---|---|---|
| **MIT, BSD** | Keep the copyright and licence notice | Keep the licence text in the module or a licences folder |
| **Apache 2.0** | Keep notices; patent terms; state changes | As MIT, plus notes on changes |
| **MPL 2.0** | Changes to the licensed files themselves must be shared under MPL | Fine if you keep the library separate and publish changes to its files if you distribute |
| **GPL family** | Derived works distributed must be under the GPL with source | How this applies to Roblox games is unclear and debated; many studios avoid GPL code in games. Ask a lawyer if it matters |
| **No licence** | All rights reserved by default | You do not have permission to use it, even if it is public |

Practical habits:

- Keep a `Licenses` folder or module header per third-party library ([[Module Scripts and Requiring]], [[External Tooling - Rojo Wally Selene StyLua]]).
- Package managers do not remove licence duties.
- Copying a snippet from a forum post: short, common patterns are generally fine in practice; large copied code is someone's work. When in doubt, write it yourself or ask.

---

## 5. Other people's games, brands and characters

- **Do not use other games' names, logos, characters or assets.** Even as a "tribute". Trademarks and copyright apply, and Roblox's rules prohibit infringing content ([[Roblox Policies Ratings and Compliance]]).
- **Real brands, films, anime, sports teams, music artists:** using them without a licence risks takedowns and account action. Search terms and thumbnails using brand names can also be misleading to players ([[Thumbnails Icons and Store Page]]).
- **Parody and fair use** (or "fair dealing" in some countries) exist in law, but their scope is narrow and differs by country. They are defences argued in disputes, not permissions you can rely on in advance.
- **"Inspired by"** is fine for ideas and genres. Copying the layout, art and UI of a specific game closely enough that players think it is the same is not "inspired".

### Licensing IP the official way: License Manager

Roblox's **License Manager** lets rights holders offer their IP to creators. Roblox docs and a 2025 Roblox announcement (as of October 2026) describe:

- rights holders register an IP family and must prove exclusive, worldwide rights including copyright or trademark registrations;
- they set licence terms, content standards, eligibility (for example maturity level and minimum daily active users) and a **revenue share**; the announcement said rates are typically between 10 and 25%, collected automatically;
- creators can browse a Licenses catalogue and request a licence; rights holders accept or reject;
- a licence's revenue share cannot be edited after the licence is created; licences go through moderation review.

For a creator, a licensed IP brings an audience and a cost: the revenue share comes off the top, and brand guidelines limit what you can change. Model the numbers like any revenue share ([[Hiring Freelancers and Revenue Shares]], [[Running a Small Studio as a Business]]).

---

## 6. When someone copies you

Copying is common on Roblox. Steps, in order:

1. **Record evidence**: links, screenshots, dates, your source files and version history showing you made it first ([[Version History and Backups]], [[Git and Source Control for Roblox]]).
2. **Decide if it matters.** Copied ideas are usually not actionable. Copied assets, code or branding may be.
3. **Use Roblox's tools.** Roblox docs (as of October 2026) say suspected rights violations can be submitted for removal through the **Rights Manager**. Follow the current process on the Creator Hub; claims are a legal statement, so be accurate.
4. **Do not retaliate.** Public call-outs, harassment, brigading or report-spamming break Community Standards and can get *your* account actioned.
5. **Ask a lawyer** for large-value cases or anything beyond the platform's tools.

### When someone claims you copied

- Do not ignore it. Check your licence log.
- If you used something without a valid licence, remove or replace it and update the game.
- If the claim is wrong, use the platform's counter or appeal process with your evidence.
- For anything serious, get legal advice before responding in public.

---

## 7. Selling assets and plugins

The Creator Store can sell models and plugins for **USD**. Roblox docs (as of October 2026):

| Rule | Detail |
|---|---|
| What can be sold | Models and plugins only; prices in USD only |
| Seller account | Through Stripe, which administers seller accounts |
| Verification | Government ID verified account; phone verification is not accepted |
| Age | 18 or older, or **13 to 17 with a parent or guardian's consent** |
| Location | A country Stripe supports |
| Proceeds | Seller keeps 100% of net proceeds, minus taxes and payment processing fees |
| Price ranges | Plugins 4.99 to 249.99 USD; models 2.99 to 49.99 USD |
| Payout timing | 30-day escrow, then monthly payouts |
| Groups | Group-owned assets cannot be sold |
| Refunds | Refunds and certain moderation reimbursements are deducted from the seller |

Business points:

- Because group-owned assets cannot be sold, a studio that wants to sell tools needs to decide whose account sells them and how that person shares proceeds with the studio. Write it down ([[Running a Small Studio as a Business]]).
- Selling an asset is a licence to buyers. Make sure everything inside it is yours or allowed to be redistributed (section 3).
- Plugins run with access to people's places. Write them safely, never include hidden network calls or data collection beyond what users expect ([[Plugins - Using and Writing]]).
- Sales income is taxable in most countries; keep records ([[DevEx and Cashing Out]] has the record habits).

---

## 8. Player content and privacy

Games that let players create (building, drawing, naming items, text) host user content. Points to cover:

- Filter text through Roblox's filtering as required ([[Roblox Policies Ratings and Compliance]]).
- Player creations might copy third-party IP; have a way to remove them.
- Player data must be handled under Roblox's rules and privacy laws, including deletion requests ([[Player Privacy and Data Deletion]]).
- Child safety comes first for any feature that shares player content with others.

---

## 9. Worked example: auditing a game before a brand or publisher deal

A studio is approached about a partnership. The partner asks: "Do you own or have rights to everything in the game?"

| Step | Action | Finding (example) |
|---|---|---|
| 1 | Export the asset list per group and per personal account | 40 animations uploaded to an ex-member's personal account |
| 2 | Check licence log against third-party content | Two music tracks with no record |
| 3 | Check code libraries' licence headers | One library with no licence |
| 4 | Check contracts with contractors for ownership clauses | Two early contractors had verbal agreements |
| 5 | Fix | Re-upload animations to the group from source files; replace the two tracks; replace the library or ask its author; get written confirmation of ownership from the early contractors (with their parent or guardian if minors at the time) |

After the fixes, the studio can answer "yes" with evidence. Each fix was easier than it would have been after a dispute.

---

## When not to worry (much)

- Solo games built entirely from your own work and Roblox's built-in content: keep source files and version history; that is most of it.
- Game jams: still avoid using others' assets without licences, because jam games often get published.

## Common mistakes

- Treating anything public as free to use.
- Assuming Creator Store assets are always clean.
- Non-commercial licences in games with paid items.
- No licence log.
- Code from repositories with no licence.
- Using brand names in titles, thumbnails or content.
- Assets uploaded to personal accounts of people who leave.
- Verbal ownership agreements.
- Retaliating against copiers instead of using official tools.
- Selling assets that contain other people's restricted content.
- Minors signing licences or deals without a parent or guardian.

## Checklist

- [ ] All game assets uploaded to the owning group, with source files kept.
- [ ] Licence log for every third-party asset and library.
- [ ] No non-commercial, share-alike or unknown licences in core content.
- [ ] Written ownership clauses with every contributor.
- [ ] No third-party brands, names or characters without a licence.
- [ ] Evidence (version history, source files) kept for your own work.
- [ ] Rights Manager process known; no public retaliation.
- [ ] Creator Store selling rules checked before selling; parent or guardian consent if 13 to 17.
- [ ] Legal advice for any deal, claim or large contract.

## See also

[[Business and Careers Start Here]], [[Commissions Pricing and Contracts]], [[Hiring Freelancers and Revenue Shares]], [[Running a Small Studio as a Business]], [[Creator Store and Toolbox Safety]], [[Animation Asset Permissions and Groups]], [[Packages and Asset Reuse]], [[Roblox Policies Ratings and Compliance]], [[Roblox Policies on AI-Generated Content]], [[Plugins - Using and Writing]], [[UGC Avatar Items and Accessories]], [[Links - Free and CC0 asset libraries]]

## Connected notes
<!-- auto-links:start -->
[[Publishing Selling and Updating Plugins]] · [[Building a Portfolio as a Roblox Developer]] · Working with Content Creators · Groups Roles and Permissions for Studios · LICENSE · Links - Free and CC0 asset libraries
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Open-Source Licenses for Roblox Libraries - Quick Reference]] · [[Who Owns AI-Generated Code and Assets]] · [[Music Licensing and Audio Upload Rules for 2026]] · [[Groups Roles and Permissions for Studios]] · [[Free Mocap and Mixamo Licensing for Roblox]] · [[Working with Contractors and Revenue Splits]]
<!-- related:end -->
