---
tags: [publishing, release, audience, kids-and-select, server-management, live-ops]
---
# Publishing an Experience

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Launching for "everyone" and being surprised the game is 16+ only during evaluation.
> - Avoid: Letting an age check or 2SV lapse on the account that publishes.
> - Avoid: Restarting all servers on every small update (players hate it) or never restarting after a schema change (data loss).
> - Creator account age-checked; 2SV on; account older than 2 days
> - Content question answered or full questionnaire completed accurately
> - Audience decision made (16+ only, or all ages with fee/Plus and evaluation)
>
> Read more (13 KB note): ## 3. Release requirements (Docs, Oct 2026) · ## 4. Shipping updates · ## 6. Common mistakes · ## 7. Checklist
<!-- tldr:end -->

Publishing used to be "File, Publish, set to Public". Since mid 2026 it is a gated release: age checks for the creator, a content question or full questionnaire, separate audiences (Roblox 16+, Roblox Select for ages 9 to 15, Roblox Kids for ages 5 to 8) with their own requirements, and an engagement evaluation before a game reaches younger players. This note walks through the whole path from first publish to shipping updates without hurting live players. Verified against the Creator Hub "Publish games and places", "Kids and Select" and "Release game updates" pages plus the Kids and Select launch announcement **as of October 2026**. The thresholds moved several times during 2026; the docs and the announcement disagree on some of them, and both are given.

---

## 1. Concepts

- **Experience (game, universe).** The thing players see; has a UniverseId. Contains one or more **places**.
- **Start place.** Where players arrive. Other places are reached by teleport ([[Teleporting and Multi-Place Games]]).
- **Place size limit:** 100 MB per place (Docs). See [[Case Study - Instance Cleanup and Place Size]].
- **Access.** New games are visible only to you, users with edit access and group members with suitable roles (Docs).
- **Audiences (2026).** Roblox (age-checked 16+), Roblox Select (ages 9 to 15), Roblox Kids (ages 5 to 8). Which you reach depends on your rating and on meeting extra requirements.

---

## 2. First publish

1. Studio: File, Publish. Fill the Game details: icon, thumbnail, name, Genre (optional Subgenre), description. Save; Roblox creates the game with a UniverseId (Docs).
2. Optionally invite early testers.
3. Creator Hub, Publish settings, Manage Audience:
   - **Playtest tab:** who can play before release. Early testers (up to 10) are always included; playtesters can be enabled for users with Playtest access (Docs).
   - **Public tab:** the Friends setting. On means only friends and Playtest users; off means anyone, subject to age and geographic restrictions (Docs).
   - Advanced: you can exclude a public game from Recommended For You (Docs). Useful for a soft launch where you want to drive traffic yourself.
4. Answer the content question or the Maturity & Compliance Questionnaire ([[Roblox Policies Ratings and Compliance]]).
5. Configure monetization items, icon, thumbnails ([[Thumbnails Icons and Store Page]]), social links, and the experience's API access settings (Studio access to API services for DataStores in Studio; HTTP requests if needed).

Limit: up to **5 never-before-released games per day** per creator (Docs).

---

## 3. Release requirements (Docs, Oct 2026)

Requirements apply to first releases, **updates**, Publish As to another game, and target-audience changes.

### Base: Roblox (16+) and Trusted Friends
- Creator account in good standing, at least **2 days old**.
- Creator **age check** (facial age estimation or government ID).
- An answer to the **age-restricted content question**:
  - **No:** the game gets the **Content May Vary** label and releases to age-checked users 16+.
  - **Yes:** you must complete the full Maturity & Compliance Questionnaire.

### All ages: adds Roblox Select (9 to 15) and Roblox Kids (5 to 8)
- Age verification: facial age estimation if under 18, government ID if 18+.
- **2-Step Verification** on.
- **Either** two consecutive months of Roblox Plus or Premium **or** a per-game publishing fee.
- **Pass the Kids and Select evaluation.**
- A rating of **Minimal or Mild (Kids)** or **Minimal, Mild or Moderate 9+ (Select)**; the full questionnaire is required for Kids and Select (Docs).

### Fees and the evaluation: where sources disagree

| Item | Publish page (Docs) | Kids and Select page (Docs) | Launch announcement (DevForum, June to July 2026) |
|---|---|---|---|
| Publishing fee | 1,000 Robux per game, refundable if the game keeps 25 highly engaged players for 60 days without moderation | One-time refundable fee (amount not stated); refund 90 days after eligibility, or 90 days after payment if never eligible | 1,000 Robux, refundable, or 2 consecutive months of Plus/Premium |
| Expedited review | 50,000 Robux per game; up to 48 h review; refund request after 90 days in good standing with 25 highly engaged players | 50,000 Robux | 100,000 Robux; up to 48 h |
| Entry threshold | n/a | 250 unique plays from highly engaged, age-checked players within 60 days | 500 Highly Engaged Players to enter |
| Keep-eligibility threshold | 25 highly engaged players (60 days) | n/a | Lowered from 100 to 25 over the last 60 days (July 16, 2026) |

Fees are not refunded if the game is permanently moderated or taken down for Community Standards violations (Docs). For a minor violation found in expedited review you fix and resubmit, and the 48-hour clock restarts.

What to take from the table: the program is new and tuned frequently. **The Audience Reach dashboard in Creator Hub shows your live progress and the current threshold** (Docs); trust it over any written number, including these.

### How the evaluation works (Docs)
- **Trial phase:** the game is available only to age-checked users 16+.
- Engagement is analysed hourly using account age, play history and platform spend. A **highly engaged player** needs enough account tenure, playtime in your game and a minimum purchase anywhere on Roblox in the last 60 days (they do not need to spend in *your* game).
- A safety review checks moderation reports and gameplay for age suitability.
- Games that do not reach the threshold stay available to 16+ only. Losing eligibility does not forfeit the fee.
- If your Plus subscription later lapses, the game stays published for all ages; the requirement applies when you publish or update for all-ages audiences.

### Existing games (Announcement)
Existing games stayed live for all ages; the Plus-or-fee requirement applies when pushing a new update. Games published with a completed questionnaire before June 16, 2026 were made playable again for 16+, and a facial age check is still required to push updates.

### What this means in practice (rule of thumb)
- **Plan the gate into your launch.** A brand-new game is 16+ only until enough highly engaged, age-checked players play it. A game aimed at young players has a cold-start problem; small ad campaigns with the Engagement objective exist for this (Announcement), and so does expedited review for studios.
- **Your first wave of players matters twice:** for retention metrics and for eligibility. Launch when the first session is good, not when the backlog is empty.
- **Every update is a release** under these rules. If a team member's age check or 2SV lapses, they may not be able to publish. Check accounts before an update day.

---

## 4. Shipping updates

### What happens when you publish
Publishing a place does not change running servers. New servers start on the new version; existing servers keep the old one until they close (Docs, "Release game updates").

### Options (Docs)
- **Do nothing:** non-disruptive; old servers empty naturally. Players can be on different versions for a long time.
- **Restart servers:** Creator Hub, Configure, Server Management, select places, Restart Servers. The dialog lets you restart **only outdated servers** and set a **delay of 1 to 60 minutes** so players can leave on their own (bleed-off). Roblox then stops matchmaking into those servers and teleports players to updated servers; players can still reach old servers through invites or teleports.
- Docs: if your **player data format changes**, you should probably restart.

### Version skew: the real risk
Old and new servers run at the same time and share data stores, MemoryStores and messaging topics. The dangerous cases:

| Change | Risk with mixed versions | Mitigation |
|---|---|---|
| New save schema field | Old server loads new data and drops unknown fields on save | Old code must preserve unknown fields; or restart all servers |
| Renamed data store | Old servers write to the old store | Restart; never rename live stores casually |
| New developer product | Old server's `ProcessReceipt` does not know it, returns `NotProcessedYet` | Fine if handled as in [[Developer Products and ProcessReceipt]]; the receipt waits for a new server |
| Changed remote signatures | Only within a server, so no skew | n/a |
| Cross-server messages with new payload | Old servers misparse | Version your message payloads ([[Cross-Server Messaging]]) |
| Live config in a data store | Old servers read new config | Make config backward compatible ([[Global State and Live Config]]) |

Write save code so it never deletes fields it does not understand. That single rule makes "do nothing" safe for most updates. See [[Data Schema Design and Migrations]].

### A release routine (rule of thumb)
1. Freeze; test in a private copy with real-like data ([[QA Checklists Before Release]]).
2. Publish at your lowest-traffic hour for your main regions (check concurrent users in analytics).
3. Restart outdated servers with a 5 to 15 minute bleed-off, with an in-game "Update ready, rejoin for X" banner if you want to be friendlier than a teleport.
4. Watch the error report and economy dashboards for an hour ([[Crash and Error Telemetry]]).
5. Post the update note and event ([[Live Ops Events and Updates]]).
6. Keep the previous place version ready to restore from Version History ([[Release Process and Rollbacks]]).

### Reference project
The reference project shipped many changes as "Edit only, publish to ship" and carried player data store versions forward (v1 to v6) during development, with each bump intentionally wiping progress while keeping purchase receipts and settings. In a live game a wipe needs a migration and purchase re-grant plan instead. It also kept a "test profile key" attribute so QA accounts loaded a separate profile; one release left that attribute set in Studio, which would have pointed real sessions at test data if it had been read live. Clear test switches as part of the release checklist.

---

## 5. Private servers and paid access

- **Private servers** can be free or charge a monthly Robux fee (Docs). With Roblox Plus, subscribers get paid private servers free and you can earn up to 100 Robux per subscriber per month for owner playtime (Docs). See [[Subscriptions and Premium Payouts]].
- **Paid access** (Robux or local currency) charges to enter (Docs). It limits your audience and recommendations heavily; use it for finished, premium experiences, not for a free-to-play loop.
- A game that is private-server-heavy should still design for public servers: recommendations count co-play days, and paid private servers need something worth owning.

---

### Personal or group ownership
Decide before launch. Group ownership survives team changes, lets you assign roles (playtesters, event managers, revenue configuration) and is required for many team workflows. Moving a game between owners later means re-checking every asset permission (animations and audio in particular must be usable by the new owner; see [[Animation Asset Permissions and Groups]]) and every product. Rule of thumb: anything with more than one developer should be group-owned from day one.

---

## 6. Common mistakes
- Launching for "everyone" and being surprised the game is 16+ only during evaluation.
- Letting an age check or 2SV lapse on the account that publishes.
- Restarting all servers on every small update (players hate it) or never restarting after a schema change (data loss).
- Save code that drops unknown fields.
- Shipping with test switches set.
- Changing the start place with plain Publish instead of Publish As (overwrites the wrong place; Docs warn about this).

## 7. Checklist
- [ ] Creator account age-checked; 2SV on; account older than 2 days
- [ ] Content question answered or full questionnaire completed accurately
- [ ] Audience decision made (16+ only, or all ages with fee/Plus and evaluation)
- [ ] Icon, thumbnails, description, genre set
- [ ] Monetization items created; no id 0 visible
- [ ] Studio API access settings correct; test switches cleared
- [ ] Save code preserves unknown fields
- [ ] Restart plan for the update (outdated only, with bleed-off)
- [ ] Previous version known for rollback

## See also
[[Places Universes and Experience Settings]] · [[Version History and Backups]] · [[Release Process and Rollbacks]] · [[Roblox Policies Ratings and Compliance]] · [[Age Checks and Safety Features]] · [[Server Lifecycle and Shutdown]] · [[Thumbnails Icons and Store Page]] · [[Discovery and the Algorithm]]

## Connected notes
<!-- auto-links:start -->
[[Sponsored Ads and Campaign Math]] · [[Ads and Rewarded Video]] · [[Monetization Overview]] · [[Links - Settings and publishing]] · [[Server Shutdowns Soft Updates and Migration]] · [[Launch Strategy - The First Two Weeks]]
<!-- auto-links:end -->
