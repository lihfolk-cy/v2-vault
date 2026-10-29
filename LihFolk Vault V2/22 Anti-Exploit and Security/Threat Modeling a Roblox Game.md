---
tags: [security, threat-model, anti-cheat, design, combat, rng, economy, type/guide, area/security, level/intermediate, api/DataStore, area/gameplay]
---
# Threat Modeling a Roblox Game

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Ranking by how loudly players complain -> Rank by impact, reach, ease and stealth
> - Avoid: Modeling only remotes -> Include Touched, prompts, owned physics, saves, third-party...
> - Avoid: Ignoring "server to future server" -> Validate on load; invariant checks
> - Assets listed with where their truth lives and who may change them.
> - Trust boundaries drawn, including saves, HTTP, receipts, admin and third-party assets.
> - Each boundary walked with STRIDE plus races and physics claims.
>
> Cost: TL;DR ~170 tok · whole note ~4.4k tok. Read more: ## Step 5: record it so it stays alive · ## Worked example: a combat RNG game · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Threat modeling is the habit of asking "what could go wrong, and how much would it hurt" before writing a system, then spending your defensive effort where the answer is worst. Most small Roblox teams skip it and end up fixing exploits in the order players report them, which is the order of visibility, not the order of damage. A dupe that quietly inflates the economy for three weeks costs more than a flyhacker everyone can see.

This note gives a lightweight process sized for a solo developer or a small team: list your assets, draw your trust boundaries, enumerate threats per boundary, rank them, and record the result in a form that stays useful as the game grows. It finishes with a full worked example for a combat and RNG game (rolling for weapons, fighting enemies, luck boosts, paid products, a trade feature).

The questions the Roblox docs recommend asking of every feature (worst case for any argument value, maximum rate, griefing potential, resource cost, minimum exposed state) are listed in [[Exploits and Anti-Cheat]]. This note is the process that turns those questions into a ranked plan.

## Why bother on Roblox specifically

Three things make threat modeling unusually valuable here:

1. **Everything client-facing is public** ([[How Exploits Work - The Client Boundary]]). Attackers can read your remote names and argument shapes in minutes. Security through obscurity does not exist, so you must know which remotes are dangerous.
2. **Economic damage is persistent.** A combat exploit ruins a match; a dupe is saved to DataStores and spreads through trades. Rollbacks are painful and imperfect ([[Data Loss Prevention and Recovery]]).
3. **Teams are small and time is short.** You cannot harden everything. A ranked list tells you which three things to do this week.

## Step 1: list the assets

An asset is anything an attacker wants, or anything whose loss hurts you or your players. Write them down in four groups:

| Group | Examples | Typical damage if compromised |
|---|---|---|
| **Player value** | Currency, items, rare drops, levels, cosmetic unlocks, leaderboard positions | Inflation, trade market collapse, players quit when rares become common |
| **Paid value** | Developer products, game pass perks, subscriptions, premium currency | Lost revenue, refund disputes, policy exposure |
| **Experience quality** | Fair matches, server stability, other players' fun | Griefing, server crashes, bad reviews, retention drops |
| **Secrets and reputation** | Unreleased content, internal tools, admin lists, player data | Leaks, impersonation, privacy issues |

For each asset note where its truth lives (profile data, server memory, MemoryStore, replicated attribute) and who is allowed to change it.

## Step 2: draw the trust boundaries

A trust boundary is any point where data from a less trusted source enters a more trusted one. In a Roblox game the important ones are:

```
 [Player client]  --remotes, prompts, Touched, owned physics-->  [Game server]
 [Game server]    --DataStore / MemoryStore / Messaging------->  [Other servers, future sessions]
 [Game server]    --HttpService------------------------------->  [Your external services]
 [Roblox backend] --ProcessReceipt / ownership checks-------->  [Game server]
 [Admin client]   --admin remotes---------------------------->  [Game server]
 [Toolbox / packages] --inserted scripts------------------->  [Your place]
```

Every arrow is a place where you validate. Two arrows are often forgotten:

- **Server to future server.** Data saved by one server is trusted by the next. If a server saves a corrupted value (a `NaN` balance, a duplicated item), every future session inherits it. Validate on load as well as on write.
- **Third-party assets.** A free model with a hidden script runs with full server authority inside your place. See [[Creator Store and Toolbox Safety]].

## Step 3: enumerate threats per boundary

For each boundary, walk the assets that cross it and ask a structured set of questions. A short adaptation of the classic STRIDE list works well:

| Letter | Question for a Roblox feature | Example |
|---|---|---|
| **S**poofing | Can someone act as another player or as an admin? | An admin remote that checks a client-sent flag |
| **T**ampering | Can someone change a value they should not? | A sell remote with an unchecked quantity |
| **R**epudiation | Could we prove what happened afterwards? | No log of trades, so a "I was scammed" report cannot be checked |
| **I**nformation disclosure | Can someone learn what they should not? | Drop odds or unreleased items in ReplicatedStorage |
| **D**enial of service | Can someone make the server or others suffer? | A remote that triggers a DataStore write per call |
| **E**levation | Can someone get a capability they did not earn? | Using an ultimate move from a weapon they do not hold |

Add two Roblox-specific prompts that STRIDE misses:

- **Races and repeats:** what happens if this request arrives twice in the same frame, or again after a server crash, or from two servers at once?
- **Physics claims:** does this feature trust anything the owning client simulates (position, Touched, velocity)?

Write each threat as one sentence in attacker terms: "A player sends quantity NaN to SellItem and their balance becomes NaN and saves."

## Step 4: rank the risks

You need a ranking that is fast, consistent, and honest about uncertainty. Score each threat 1 to 3 on four axes (rule of thumb; the exact scale matters less than applying it consistently):

| Axis | 1 | 2 | 3 |
|---|---|---|---|
| **Impact** | Cosmetic or one session | Unfair advantage, contained | Persistent economy damage, revenue loss, server crash, data loss |
| **Reach** | Only the attacker | Players in the same server | Whole player base (via trades, leaderboards, saves) |
| **Ease** | Needs precise timing and knowledge | Needs a modified client and some reading | Needs only fast clicking or two accounts |
| **Stealth** | Obvious to everyone | Visible in logs if you look | Invisible until the damage shows up |

**Risk = Impact x Reach x (Ease + Stealth).** Range 2 to 54. Sort descending. The multiplication makes "persistent and widespread" dominate, which is what you want: a stealthy dupe (3 x 3 x (2 + 3) = 45) outranks a visible flyhack (1 x 2 x (2 + 1) = 6) even though players complain about the flyhack more.

Then add one column: **Design fix available?** Many top threats disappear entirely with a design change (the server computes damage; rewards require server-witnessed kills), which is cheaper and stronger than any detection. Prefer those first. See the design table in [[Exploits and Anti-Cheat]].

### When not to rank

If a threat is trivially fixable (add a type check, move a module to ServerStorage), fix it during the session instead of scoring it. Ranking is for the things that cost real time.

## Step 5: record it so it stays alive

A threat model that lives in one person's head expires the day the code changes. Keep a short living document per system, and keep a machine-readable **remote manifest** in the codebase so every remote declares its risk properties next to its handler. The manifest pays for itself during reviews and lets you build tests from it ([[Testing Your Own Remotes - Fuzzing and Abuse Tests]]).

```lua
--!strict
-- ServerScriptService/Net/RemoteManifest.luau
-- One entry per client-to-server remote. Reviewed whenever a remote is added or changed.

export type Tier = "critical" | "high" | "normal" | "cosmetic"

export type Entry = {
	direction: "toServer" | "toClient" | "both",
	tier: Tier,                -- from the threat model ranking
	touches: { string },       -- assets: "currency", "inventory", "combat", "trade", ...
	ratePerSec: number,        -- sustained legitimate maximum, with margin
	burst: number,
	idempotent: boolean,       -- safe to receive twice?
	notes: string?,
}

local Manifest: { [string]: Entry } = {
	RollWeapon   = { direction = "toServer", tier = "critical", touches = { "currency", "inventory" }, ratePerSec = 4, burst = 6, idempotent = false },
	SellItem     = { direction = "toServer", tier = "critical", touches = { "currency", "inventory" }, ratePerSec = 5, burst = 10, idempotent = false },
	TradeOffer   = { direction = "toServer", tier = "critical", touches = { "trade", "inventory" }, ratePerSec = 2, burst = 4, idempotent = true },
	CastAbility  = { direction = "toServer", tier = "high", touches = { "combat" }, ratePerSec = 8, burst = 12, idempotent = false },
	SwingHit     = { direction = "toServer", tier = "high", touches = { "combat", "currency" }, ratePerSec = 10, burst = 15, idempotent = false },
	SetSetting   = { direction = "toServer", tier = "normal", touches = { "profile" }, ratePerSec = 2, burst = 10, idempotent = true },
	EmotePlay    = { direction = "toServer", tier = "cosmetic", touches = {}, ratePerSec = 1, burst = 3, idempotent = true },
	Notify       = { direction = "toClient", tier = "normal", touches = {}, ratePerSec = 0, burst = 0, idempotent = true },
}

return Manifest
```

A bootstrap script can then assert at startup that every RemoteEvent in your remotes folder has a manifest entry, connect a wrong-direction detector to every `toClient` remote (see [[Exploits and Anti-Cheat]]), and build each remote's rate limiter from the manifest values. A new remote without an entry fails the startup check in Studio, which forces the threat question at the moment it is cheapest to answer.

```lua
--!strict
-- Startup check: every remote must be declared. Fails loudly in Studio, warns in live servers.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Manifest = require(script.Parent.RemoteManifest)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local missing = {}
for _, r in remotes:GetDescendants() do
	if (r:IsA("RemoteEvent") or r:IsA("RemoteFunction") or r:IsA("UnreliableRemoteEvent"))
		and Manifest[r.Name] == nil then
		table.insert(missing, r:GetFullName())
	end
end
if #missing > 0 then
	local msg = "Remotes without a threat manifest entry: " .. table.concat(missing, ", ")
	if RunService:IsStudio() then
		error(msg)
	else
		warn(msg)
	end
end
```

([[Honeypots|Honeypot]] remotes are deliberately absent from client code but should still be in the manifest, marked as honeypots, so the check passes and reviewers know what they are.)

## Worked example: a combat RNG game

The game: players roll for weapons with an in-game currency, rarer weapons drop with lower odds, luck boosts (bought with Robux or earned) improve odds for a time, players fight enemies in zones for currency and drops, weapons have abilities with cooldowns, and players can trade weapons. Profiles are session-locked ([[Session Locking and Profile Libraries]]).

### Assets

| Asset | Truth lives in | Who may change it |
|---|---|---|
| Currency balance | Profile (server) | Server reward and spend functions |
| Weapon inventory, with unique ids | Profile | Roll, trade, sell, fuse functions |
| Luck boost expiry | Profile (server timestamp) | Receipt handler, reward function |
| Drop tables and odds | ServerStorage module (display copy replicated) | Developers only |
| Enemy health and kill credit | Server memory | Server combat code |
| Leaderboard (total rolls, rarest weapon) | OrderedDataStore | Server, from profile |
| Trade sessions | Server memory, both profiles | Trade service |
| Admin tools | ServerStorage, cloned to allowlisted admins | Admin allowlist |

### Threats found and scored

| # | Threat (attacker terms) | Imp | Rch | Ease | Stl | Risk | Design fix? |
|---|---|---|---|---|---|---|---|
| 1 | Two players race a trade against a sell or a server crash and both end up with the same weapon | 3 | 3 | 1 | 3 | 36 | Escrow and unique ids |
| 2 | Player fires RollWeapon many times in one frame; balance checked once, rolls granted many times | 3 | 3 | 2 | 2 | 36 | Deduct before roll, no yield |
| 3 | Player sends a negative or NaN quantity to SellItem | 3 | 3 | 2 | 2 | 36 | Validation |
| 4 | Client sends "luck multiplier" in the roll request | 3 | 3 | 3 | 2 | 45 | Server reads luck from profile |
| 5 | Player fires a fake "purchase complete" remote | 3 | 3 | 3 | 1 | 36 | ProcessReceipt only |
| 6 | Client sends SwingHit for enemies across the map, farming currency | 2 | 2 | 3 | 2 | 20 | Server reach and timing checks |
| 7 | Player casts abilities of a weapon they do not hold, or ignores cooldowns | 2 | 2 | 2 | 2 | 16 | Server loadout and cooldowns |
| 8 | Flyhack to reach a high-tier zone without unlocking it | 2 | 1 | 3 | 1 | 8 | Server zone gating |
| 9 | Auto-clicker farming overnight | 1 | 3 | 3 | 2 | 15 | Design: diminishing returns; accept |
| 10 | Datamining odds from ReplicatedStorage | 1 | 3 | 3 | 3 | 18 | Publish odds anyway (policy requires disclosure for paid random items) |
| 11 | Spamming trade requests to annoy others | 1 | 2 | 3 | 1 | 8 | Rate limit, decline-all setting |
| 12 | Remote spam that triggers DataStore writes | 2 | 2 | 3 | 2 | 20 | No per-request saves; coalesce |
| 13 | Corrupted value saved by a bug, inherited by every future session | 3 | 3 | 1 | 3 | 36 | Validate on load and write |

Two results are worth noticing:

- **Threat 4 tops the list** even though it is "just" a missing server lookup, because it is easy, persistent and affects the whole economy through trades. That is exactly the kind of thing visible-complaint ordering would never surface.
- **Threat 10 is resolved by policy, not code.** Paid random items require odds disclosure under Roblox policy (see [[Paid Random Items and Odds Disclosure in Practice]] and [[Roblox Policies Ratings and Compliance]]), so the "leak" is not one. Recording that decision stops someone wasting a week on obfuscation later.

### Resulting plan

1. **This week:** threats 4, 2, 3, 5 (all design or validation fixes, each under an hour): server-side luck, deduct-before-roll in one synchronous block, `Guard` validation on SellItem, delete any purchase remote. See [[Economy Exploits - Dupes Races and Purchase Abuse]].
2. **Next:** threats 1 and 13: trade escrow with unique weapon ids and an invariant check on load.
3. **Then:** threats 6, 7, 12: hit validation ([[Detecting Combat Exploits - Reach Rate and Aim]]), loadout-checked casts, save coalescing.
4. **Accepted risks, with monitoring:** 8 (zone gating already makes it worthless, add a log), 9 (design), 11 (rate limit only).

### What the model changed in practice

Teams that do this exercise usually find that the most dangerous remotes are the boring economy ones, not combat. The ranking also tells you where logging matters most: put audit logs on threats with high stealth (1, 2, 13), because those are the ones you will otherwise discover only through their consequences.

## Keeping the model current

- **On every new remote:** add a manifest entry (enforced by the startup check).
- **On every new asset type** (a new currency, a new tradeable): re-run step 3 for the trade, sell and save boundaries.
- **On every exploit report:** add the threat to the table with its real scores, even after fixing it, and ask which neighbouring features share the pattern.
- **Quarterly** (or before a big update): re-score the top ten. Ease changes as public tools change; reach changes when you add trading or leaderboards.

## Common mistakes

| Mistake | Fix |
|---|---|
| Ranking by how loudly players complain | Rank by impact, reach, ease and stealth |
| Modeling only remotes | Include Touched, prompts, owned physics, saves, third-party assets, admin tools |
| Ignoring "server to future server" | Validate on load; invariant checks |
| Detection before design | Ask "can this be made impossible?" first |
| A one-off document | Manifest in code, enforced at startup |
| Treating every threat as must-fix | Explicitly accept low risks and record why |

## Checklist

- [ ] Assets listed with where their truth lives and who may change them.
- [ ] Trust boundaries drawn, including saves, HTTP, receipts, admin and third-party assets.
- [ ] Each boundary walked with STRIDE plus races and physics claims.
- [ ] Threats scored and sorted; design fixes preferred.
- [ ] Remote manifest exists and is enforced at startup.
- [ ] Accepted risks are written down with a monitoring plan.
- [ ] High-stealth threats have audit logging.
- [ ] Model reviewed on new remotes, new assets and every exploit report.

## See also
[[Anti-Exploit Start Here]] · [[How Exploits Work - The Client Boundary]] · [[Exploits and Anti-Cheat]] · [[Server Authority and Validation]] · [[Rate Limiting and Abuse Prevention]] · [[Remote Abuse Patterns and Rate Limiting in Practice]] · [[Economy Exploits - Dupes Races and Purchase Abuse]] · [[Trading Systems Without Duplication]] · [[Genre Playbook - RNG and Collection Games]] · [[RNG Drops and Luck Systems]]

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox Anti-Exploit Review]] · Server Authority · Client-Server Model · Pity Timer · Economy Resets and Seasonal Wipes · Official Docs - Security and Moderation
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Admin Commands Done Safely - Permissions and Audit Logs]] · [[False Positives Lag and Fair Enforcement]] · [[Autoclicker and Macro Detection for Combat Remotes]] · [[Logging Bans and Appeals]] · [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] · [[Creator Account Security and Takeover Recovery]]
<!-- related:end -->
