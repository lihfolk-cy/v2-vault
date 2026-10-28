---
tags: [studio, plugins, creator-store, publishing, monetization, versioning]
---
# Publishing Selling and Updating Plugins

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Publishing each update as a new asset -> Publish over the same asset
> - Avoid: Selling from a group account -> Individual ownership
> - Avoid: Changing seller bank details just before a payout -> Change just after a payout
> - Account verified (age check or ID); quota planned.
> - For selling: Stripe seller account approved, 2-step verification on, individually owned asset.
> - Price within $4.99 to $249.99; store page with video, images in both themes, changelog.
>
> Cost: TL;DR ~160 tok · whole note ~4.7k tok. Read more: ## 2. Selling: who can, and how money moves · ## 4. Versioning: what "a version" means for a plugin · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

Shipping a plugin is the start of a maintenance relationship. Once other people install it, every update you publish lands in their Studio, in their places, often automatically, and anything your plugin ever wrote into their places (attributes, tags, helper folders, settings keys) becomes a format you must keep reading forever. If you sell it, you also take on payouts through a third party, refunds, chargebacks and moderation risk.

This note covers the publishing flow and its limits, the Creator Store seller rules and money flow as documented (as of October 2026), pricing and positioning, versioning and update strategy, backward compatibility with data in users' places, and support. Basic publishing steps are in [[Plugins - Using and Writing]]; seller eligibility in brief is in [[Creator Store and Toolbox Safety]]. This note goes into the consequences.

Labels: **Roblox docs (as of October 2026)**, **rule of thumb**, **unverified**. Prices, limits and payout rules change; check the Creator Store documentation before relying on any number here.

---

## 1. Publishing: the mechanics and the limits

The flow (Roblox docs): select the plugin script in the Explorer, **Plugins > Publish as Plugin**, optionally upload a 512 by 512 thumbnail, fill in name, description and creator (you or a group), submit. The plugin then appears in your Toolbox **Inventory** and **Creations** tabs. Publishing alone makes it available to you; **distributing** it on the Creator Store is a separate toggle on the asset's configure page in the Creator Hub (**Distribute on Creator Store**), where you also set a USD price if you are a seller.

Limits and requirements that shape your release plan (Roblox docs):

| Rule | Value |
|---|---|
| Account age to share on the Creator Store | At least 2 days |
| Verification to share | Age check or government ID; a phone number does **not** count |
| Plugins distributed per 30 days, verified account | 10 |
| Plugins distributed per 30 days, unverified account | 2 |
| Store page media | Up to one video and 5 images, if ID or phone verified |
| Demo | Optional **Try in Roblox** game |

The 30-day distribution limit counts distributing assets, which matters if you ship a family of small plugins: plan releases, and do not burn the quota on throwaway experiments. Whether publishing a new **version** of an already-distributed plugin counts against it is **unverified**; in practice updates are published as new versions of the same asset (section 5), not new assets.

The store also restricts some code practices in distributed assets (Roblox docs): obscuring engine features (custom VMs, `getfenv`, `setfenv`), requiring remote assets (`require(assetId)`, `loadstring`, `InsertService:LoadAsset`, `AssetService:LoadAssetAsync`, `ModuleScript.LinkedSource`), obfuscated code, and unnecessarily large scripts. Design your plugin so it never needs these. In particular, "load the latest code from my server at startup" is both a security problem ([[Plugin Security and Permissions]]) and a store violation.

## 2. Selling: who can, and how money moves

Selling is in USD, not Robux (Roblox docs, Creator Store FAQ: "the real-world pricing model does not support Robux").

**Seller account requirements** (Roblox docs):

- The sharing requirements above, plus a seller account set up through **Stripe**, one Stripe account per Roblox account.
- Age 18 or older, or 13 to 17 with a parent or guardian who reviews and agrees to the terms and whose details go on the Stripe form.
- Two-step verification on the Roblox account.
- Residence in a country Stripe supports for cross-border payouts; the docs name Brazil, China, India and Russia as not yet supported.
- Assets must be owned by an **individual** account. Group-owned plugins cannot be sold; the docs suggest re-uploading under individual ownership. Only individuals can buy, not groups.
- Review of the Stripe application can take up to 7 days. The country cannot be changed after approval. Editing seller information after approval returns you to **Pending** and freezes payouts until reviewed, so the docs advise changing bank details just after a payout.

**Prices and money flow** (Roblox docs):

| Item | Rule |
|---|---|
| Plugin price range | $4.99 minimum, $249.99 maximum |
| Revenue share | 100% of net proceeds: only taxes and payment processing fees are deducted |
| Escrow | Each sale is held 30 days, then added to your Stripe balance |
| Payout | Monthly, on the 1st, to the linked bank; no access outside the schedule |
| Minimum payout | Set by Stripe per country and currency |
| Currency | Converted when proceeds move to your balance, if your account is not in USD |
| Per customer cap | Transactions between one customer and one seller are capped per month (amount not published) |

So a sale on 3 March is released around 2 April and paid on 1 May. Plan cash flow on a two-month lag (rule of thumb from the documented rules).

**Reimbursements** (Roblox docs) are deducted from your account when a customer refunds or charges back, or when the asset is moderated after purchase and the decision is not successfully appealed **within 5 days**. Uploading a fixed version does not prevent those reimbursements. If an unusually high share of your sales comes from accounts with a history of chargebacks, the asset is taken off sale and payouts frozen. Practical consequences:

- A moderation hit on a popular paid plugin can claw back a month of sales. Keep your description, images and code squarely within the rules, and appeal fast if moderated in error.
- Do not run promotions that attract throwaway accounts (giveaways tied to purchases, "buy and get Robux" schemes).

**AI data sharing.** Free assets on the store are opted in to AI data sharing by default; paid assets are used only if you opt in. If you later opt out, the docs say the asset leaves the training dataset within 30 days and trained models are updated within 365 days. Decide deliberately, especially for paid plugins whose code is your product.

Taxes are your responsibility: Stripe collects a W-8 or W-9 form during onboarding, and the docs mention tax identification numbers where applicable. Talk to someone qualified in your country; see [[Running a Small Studio as a Business]] and [[Legal Basics - IP Licenses and Assets]].

## 3. Free, paid, or both

Rules of thumb, not policy:

| Model | Works when | Watch out for |
|---|---|---|
| Free | You want reach, reputation, a portfolio piece, or the plugin is small | Support load with no income; set boundaries in the description |
| Paid only | The plugin saves professionals hours per week and is clearly better than free options | Must justify $4.99 or more before anyone sees it work; store media and a demo matter |
| Free plus paid edition | A useful free core, with a pro edition for heavy users | Two codebases or a shared core; never cripple the free one into uselessness |
| Free plugin, open source, paid support or commissions | Your income is consulting or custom tools | Clear license; see [[Commissions Pricing and Contracts]] |

Pricing anchors from the documented range: $4.99 is the floor, so "impulse" pricing below that is not possible. Many developers price around the value of one to two hours of their customer's time, and raise prices with major versions rather than nickel-and-diming small features (rule of thumb).

A plugin's store page sells it. What converts (rule of thumb): a 20 to 40 second video of the actual workflow, a thumbnail that shows the result rather than a logo, a first description line stating the problem it solves, a short feature list, and a changelog showing it is maintained. Screenshots in both Studio themes reassure users the UI is not broken in theirs.

Paid plugins are still readable code once installed. Asset Privacy and store rules control loading and listing, not copying; the docs state that asset privacy "is not a form of Digital Rights Management". Your protection is updates, support and reputation, plus the [[Legal Basics - IP Licenses and Assets]] route (the Rights Manager) for blatant re-uploads.

## 4. Versioning: what "a version" means for a plugin

Every time you publish over the existing asset, users receive the new version. Studio tells users when installed plugins have updates, and has a per-plugin auto-update setting in its plugin management UI (the engine's `PluginManagementService` exposes auto-update and latest-version lookups to Studio's own UI; the docs mark it as not for creator use). The exact timing of when an update reaches an open Studio session is **unverified**; assume "next time Studio starts or the plugin reloads". `plugin.Unloading` fires when a plugin is "about to be updated" (Roblox docs), so your cleanup code runs before the swap.

Adopt semantic versioning in a `Version` module inside the plugin (rule of thumb):

- **Patch** (1.4.1): bug fixes, no format changes.
- **Minor** (1.5.0): new features; new data written alongside old; old data still read.
- **Major** (2.0.0): anything that changes what the plugin writes into places or settings, or removes features. Announce it before shipping.

Show the version in the widget's footer. When users report bugs, the first question is always which version they run.

### The "what changed" panel

Use the `lastSeenVersion` field from the settings pattern in [[Building a Studio Plugin End to End]]:

```lua
--!strict
-- On startup: if the plugin was updated since the user last saw it, show the changelog once.
local VERSION = require(script.Parent.Version) :: string
local CHANGES: { [string]: string } = {
	["1.5.0"] = "Replace tool keeps tags. New: distribute by gaps.",
	["1.4.1"] = "Fixed undo after cancelling a drag.",
}

local function parse(v: string): (number, number, number)
	local a, b, c = string.match(v, "^(%d+)%.(%d+)%.(%d+)$")
	return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

local function newer(a: string, b: string): boolean
	local a1, a2, a3 = parse(a)
	local b1, b2, b3 = parse(b)
	if a1 ~= b1 then
		return a1 > b1
	end
	if a2 ~= b2 then
		return a2 > b2
	end
	return a3 > b3
end

local function changesSince(lastSeen: string): { string }
	local out: { string } = {}
	for version, text in CHANGES do
		if newer(version, lastSeen) and not newer(version, VERSION) then
			table.insert(out, version .. ": " .. text)
		end
	end
	table.sort(out, function(x, y)
		return newer(string.match(x, "^[%d%.]+") or "0.0.0", string.match(y, "^[%d%.]+") or "0.0.0")
	end)
	return out
end

return changesSince
```

Show the result in a small, dismissible banner, then save `lastSeenVersion = VERSION`. Never pop a modal on startup; users open Studio to work.

### Checking for updates yourself

For locally installed builds (GitHub releases, Rojo builds) Studio cannot tell users an update exists. A light check: put the latest version string at the start of the published asset's description, and compare it with `MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Asset).Description` at startup, inside `pcall` (a DevForum-described technique used by long-running popular plugins). It needs no HTTP permission and no extra domain. Check at most once per session.

## 5. Backward compatibility: the data in users' places

This is the part that hurts most when ignored. Anything your plugin writes into a place outlives your plugin's version, and possibly your plugin:

| You write | It lives | Compatibility rule (rule of thumb) |
|---|---|---|
| Attributes (`MyTool_Version`, `Pre_Anchored`) | On user instances, saved, published, replicated | Prefix with your plugin name; never change meaning; read old names forever or migrate explicitly |
| Tags | On instances, saved | Same; tags are used by game code too, so never reuse common words |
| Helper folders or config ModuleScripts | In the place | Version field inside; tolerate missing or older content |
| Generated scripts | In the place, run in the live game | Treat as an API: changing them changes users' games |
| `SetSetting` keys | On the user's disk | Schema number, migration on read |

Concrete rules:

- **Prefix everything** with a short, unique plugin prefix. A tag named `Spawn` written by your plugin will collide with half the games on the platform.
- **Write a format version** wherever you store structured data: an attribute `MyTool_Format = 3` on your root folder, for example.
- **Read old formats, write the new one.** Migrate lazily when the user next edits that object, inside a recording, rather than rewriting a whole place on startup without asking.
- **Never auto-migrate on load.** A plugin that rewrites data in every place the user opens, right after an update, modifies places the user did not intend to touch, possibly shared ones, possibly packages. Ask first, per place.
- **Generated runtime code is a contract.** If your plugin inserts a runtime ModuleScript that the game requires, an update that changes its API breaks users' live games the next time they publish. Version the module's name or keep the API stable, and document changes prominently.
- **Provide an uninstall cleanup.** A "Remove all MyTool data from this place" button (inside a recording) is a mark of a plugin that respects its users.

## 6. Release process

A small process prevents most bad updates (rule of thumb):

1. **Bump the version** and add the changelog entry.
2. **Run the test place** with edge cases (from [[Building a Studio Plugin End to End]]), in both themes, with two windows open, and in a place containing data written by the **previous** version.
3. **Run the security scan** from [[Plugin Security and Permissions]] on your own build. It should find only the HTTP and source writes you expect.
4. **Install the build locally** and use it for a day of real work before publishing.
5. **Publish over the existing asset**, then update the store description's version line.
6. **Watch reports** for a few days before starting the next feature. A bad update reaches users quickly, and some of them have auto-update on.

Rolling back: there is no documented "revert to previous version" button for plugin assets (**unverified**; check the asset's version history in the Creator Hub). Keep every released build as a file (`MyTool-1.5.0.rbxm`) in your repository or releases, so rolling back means re-publishing the previous build with a bumped patch number. Never re-publish an older build with an older version number: your changelog logic and users' bug reports will both get confused.

With Rojo and CI, the build and the version bump can be scripted; publishing a plugin asset through Open Cloud is possible for some asset types, but whether plugins are supported for automated upload as of October 2026 is **unverified** ([[Asset Upload Automation with Open Cloud]]). Most authors still publish from Studio.

## 7. Support, documentation and reputation

- **Documentation**: a short README or a page reachable from the widget (a "Help" link that copies the URL, or `plugin:OpenWikiPage(url)`, which opens Studio's context help window per the docs). Cover setup, every button, keyboard shortcuts, what the plugin writes into places, and how to remove it.
- **Where to report bugs**: one channel, stated in the description and the widget (a DevForum thread, a GitHub issues page, or a Discord server, see [[Discord Servers for Roblox Games]]). Ask for version, Studio theme, and steps.
- **Response expectations**: say them. "I fix critical bugs within a week; feature requests are considered for the next minor version" prevents a lot of anger, especially for paid plugins.
- **Reviews**: ratings drive store ranking (the store sorts by relevance or rating, per the docs). The fastest route to good reviews is fixing the first-run experience: the panel opens, the empty state explains what to do, the first action works.
- **Portfolio**: a well-maintained plugin is strong evidence for hiring and commissions ([[Building a Portfolio as a Roblox Developer]]).

## 8. Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Publishing each update as a new asset | Users never get updates; reviews scatter; distribution quota burned | Publish over the same asset |
| Selling from a group account | Not allowed | Individual ownership |
| Changing seller bank details just before a payout | Payout frozen while Pending | Change just after a payout |
| Generic tag or attribute names | Collisions with users' game code | Unique prefix |
| Auto-migrating data on load | Unasked edits in every place opened | Lazy, per-place, user-confirmed migration |
| Changing generated runtime code silently | Users' live games break on next publish | Versioned, documented runtime API |
| Self-updating via remote code | Security risk and store restriction | Ship code in the plugin; publish versions |
| No version shown in the UI | Bug reports without context | Version in footer; changelog banner |
| Ignoring the 30-day escrow and monthly payout | Cash-flow surprises | Plan on a two-month lag |

## 9. Checklist

- [ ] Account verified (age check or ID); quota planned.
- [ ] For selling: Stripe seller account approved, 2-step verification on, individually owned asset.
- [ ] Price within $4.99 to $249.99; store page with video, images in both themes, changelog.
- [ ] No restricted practices in code (remote requires, `loadstring` of remote code, obfuscation).
- [ ] Semantic version in the plugin, shown in the UI; changelog banner on update.
- [ ] All place data prefixed and format-versioned; old formats still read.
- [ ] Release process: test place with previous-version data, both themes, two windows, self-scan, a day of real use.
- [ ] Every released build archived for rollback.
- [ ] Docs, bug channel and support expectations published.
- [ ] AI data sharing preference set deliberately.

## See also

- [[Plugin Development Start Here]], [[Plugin Security and Permissions]], [[Building a Studio Plugin End to End]]
- [[Plugins - Using and Writing]], [[Creator Store and Toolbox Safety]], [[Packages and Asset Reuse]]
- [[Running a Small Studio as a Business]], [[DevEx and Cashing Out]], [[Legal Basics - IP Licenses and Assets]], [[Building a Portfolio as a Roblox Developer]]

## Connected notes
<!-- auto-links:start -->
[[Business and Careers Start Here]] · [[Hiring Freelancers and Revenue Shares]] · [[Commerce and Physical Goods]] · [[Subscriptions and Premium Payouts]] · [[Links - Plugins and custom tools]] · [[Monetization Overview]]
<!-- auto-links:end -->
