---
tags: [monetization, refunds, chargebacks, support, webhooks, purchases, live-ops, luau, type/guide, area/monetization, level/intermediate, api/ProcessReceipt]
---
# Refunds Chargebacks and Purchase Support

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: No purchase log -> Log every processed receipt with real Robux spent
> - Avoid: Using the webhook Robux amount as revenue lost -> Use the logged amount
> - Avoid: Webhook handler does the work before replying -> Verify, queue, reply, then process
> - Purchase log with purchase id, product key, real Robux spent, grant contents, time.
> - Boot assertion: every product has a supported grant.
> - Transaction Refunded (and Subscription Refunded if relevant) webhooks configured with a secret.
>
> Cost: TL;DR ~160 tok · whole note ~5.2k tok. Read more: ## 2. Receiving refund notifications · ## 5. Purchase support: the tickets you will get · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Every game that sells things eventually has to answer three kinds of message: "I paid and got nothing", "my child bought this without asking", and, from Roblox, "this transaction was refunded". This note covers what Roblox does on its side when a purchase is refunded, what it leaves to you, how to receive refund notifications reliably, how to claw back developer product grants without punishing the wrong person, and how to run purchase support with the tools and logs that make it answerable.

Prerequisites: [[Developer Products and ProcessReceipt]], [[Purchase Data and Receipts]], [[Open Cloud APIs]].

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**. Where the docs are silent, the note says so; Roblox's consumer refund policy and the exact effect of refunds on creator earnings are not documented in the creator docs this note could check (unverified).

---

## 1. What Roblox does and what it leaves to you

The key distinction is where the purchased thing lives.

| Purchase | Who holds ownership | On a refund through Roblox Customer Service |
|---|---|---|
| Game pass | Roblox | Ownership is revoked automatically (Roblox docs) |
| Avatar item | Roblox | Ownership is revoked automatically (Roblox docs) |
| Developer product | **Your save data** | Nothing happens in your game. You must remove the benefit yourself (Roblox docs) |
| Extra benefits you granted on a pass purchase (a one-time gem bonus with VIP, an item) | Your save data | Same: yours to remove (Roblox docs) |
| Private servers, paid access | Roblox | Covered by the Transaction Refunded notification; whether access is revoked automatically is not stated (unverified) |
| Experience subscriptions | Roblox | Separate "Subscription Refunded" notification |

Two practical consequences:

- **Pass revocation reaches a running server late.** If you cached `UserOwnsGamePassAsync` at join (as you should; [[Game Passes]]), a player whose pass was refunded keeps the perk until they rejoin. That is usually acceptable. What is not acceptable is a pass purchase that also wrote permanent rewards into the profile and never removes them.
- **Roblox keeps no per-user purchase history of developer products for you** (Roblox docs). If you did not log a purchase, you cannot later prove it, reverse it, or re-grant it.

---

## 2. Receiving refund notifications

Roblox can send webhook notifications to an HTTPS endpoint you configure on the Creator Dashboard. The refund-related events (Roblox docs, as of October 2026):

| Event | Covers |
|---|---|
| **Transaction Refunded** | Developer products, passes, private servers, paid access. Not subscriptions |
| **Subscription Refunded** | Experience subscriptions |
| **Commerce Product Order Refunded** | Commerce product orders (refunded or cancelled) |

The Transaction Refunded payload carries the buyer's user id, the product type and product id, a Robux amount, the universe and place of purchase, a transaction or receipt id, and the refund time. The docs describe the contents but this note could not confirm exact JSON key names: read them from a real test delivery and code against those. Two documented details matter:

- **The Robux amount is the product's original price, not what the buyer paid.** Under regional pricing, Plus discounts and price tests those differ. Your purchase log has the real amount (`CurrencySpent` in the receipt).
- **Delivery retries are limited.** If your endpoint fails, Roblox retries 5 times; if all fail, it stops and treats the URL as invalid until you update the configuration (Roblox docs). An outage on your side can silently switch refund notifications off. Monitor it.

### Verifying the signature

Notifications carry a `roblox-signature` header of the form `t=<timestamp>,v1=<signature>` when you configured a secret. Verify by computing HMAC-SHA256 over `<timestamp>.<raw request body>` with your secret, Base64-encoding it, and comparing to `v1`; reject old timestamps (the docs' sample uses 300 seconds) (Roblox docs, as of October 2026). This runs on your server, not in Luau. A minimal Node.js version:

```js
// Webhook receiver (Node.js). Verify BEFORE parsing or acting on the body.
const crypto = require("crypto");

function verifyRoblox(rawBody, header, secret, maxAgeSec = 300) {
  if (!header) return false;
  // Split on the FIRST "=" only: Base64 signatures can end in "=" padding.
  const parts = Object.fromEntries(header.split(",").map(p => {
    const i = p.indexOf("=");
    return [p.slice(0, i).trim(), p.slice(i + 1)];
  }));
  const t = Number(parts.t), sig = parts.v1;
  if (!t || !sig) return false;
  if (Math.abs(Date.now() / 1000 - t) > maxAgeSec) return false; // replay window
  const expected = crypto.createHmac("sha256", secret)
    .update(`${t}.${rawBody}`)
    .digest("base64");
  const a = Buffer.from(sig), b = Buffer.from(expected);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}
```

Rules that apply to the receiver (rule of thumb):

- **Use the raw body bytes.** Re-serialising parsed JSON changes whitespace and breaks the signature.
- **Respond quickly, process later.** Return 2xx once the event is verified and durably queued; do the work afterwards. A slow handler burns retries.
- **Idempotent by transaction id.** Retries and duplicates are possible; store processed ids.
- **Keep the secret out of the game.** It never belongs in a script or a data store the game reads ([[HttpService and External APIs]]).

### Getting the refund into the game

The game cannot receive webhooks. Bridge it with Open Cloud ([[Open Cloud APIs]]):

1. The receiver writes a small record into a data store such as `Clawbacks`, key `u_<buyerUserId>`, appending `{ id = transactionId, product = productId, t = refundTime }` (deduplicated by id). Writing per user keeps it cheap to read at join.
2. Optionally, it publishes a MessagingService message through Open Cloud so a server where the player is online can apply it immediately ([[Cross-Server Messaging]]).
3. Game servers read `Clawbacks/u_<userId>` at join, after the profile loads, and apply anything not yet applied.

The Open Cloud write shares your experience's data store budget and does not take the player's session lease. That is why the game, not the receiver, should modify the profile: the receiver only appends to a separate key that nothing else writes.

---

## 3. Matching a refund to what you granted

To reverse a grant you must know exactly what was granted. That is the job of the purchase log ([[Purchase Data and Receipts]]): one entry per processed receipt with `PurchaseId`, product key, Robux actually spent, what was granted (amounts and any item Uids), and time.

Whether the webhook's transaction id is the same value as the `PurchaseId` your `ProcessReceipt` handler saw is not stated in the docs (unverified). Code for both:

```lua
--!strict
-- Find the purchase log entry a refund refers to.
export type LogEntry = { Pid: string, Key: string, ProductId: number, Spent: number, T: number, Grant: { [string]: any }, Refunded: boolean? }

local function matchRefund(log: { LogEntry }, refundId: string, productId: number, refundTime: number): LogEntry?
	-- 1. Exact id match, if the ids are the same value.
	for _, e in log do
		if e.Pid == refundId then
			return e
		end
	end
	-- 2. Fallback: most recent unrefunded purchase of that product before the refund time.
	local best: LogEntry? = nil
	for _, e in log do
		if e.ProductId == productId and not e.Refunded and e.T <= refundTime then
			if best == nil or e.T > best.T then
				best = e
			end
		end
	end
	return best
end
```

Record which rule matched. If the fallback matches often, you will want a support review step for multi-purchase cases (a player who bought the same pack three times in an hour and had one refunded).

---

## 4. Clawback policy: decide before you code

A refund means the money is gone. What the game does next is a policy choice, and the worst options punish children for what a parent's bank did.

| Situation | Options | Rule of thumb |
|---|---|---|
| Granted currency still unspent | Remove it | Remove the refunded amount, floor at zero |
| Currency already spent | Negative balance (debt), remove what it bought, or write off | Debt that future income repays; never delete items bought partly with free currency |
| Granted item still owned | Remove it | Remove if untraded; if traded, see below |
| Granted item traded to someone else | Remove from the receiver, or write off | Write off; the receiver traded in good faith. Mark the item untradeable at the giver side if it comes back |
| Consumable already used (a boost, a revive) | Nothing to remove | Write off |
| One-time pack flag | Clear it | Clearing lets them buy again; fine |
| Repeated refunds by one account | Restrict | Stop prompting products for that account after N refunds (rule of thumb: 2 to 3), with a support path to lift it |

The arithmetic for currency with debt:

```lua
--!strict
-- Apply a currency clawback; returns how much became debt.
local function clawCurrency(profile: any, field: "Gems" | "Cash", amount: number): number
	local bal: number = profile[field] or 0
	local take = math.min(bal, amount)
	profile[field] = bal - take
	local owed = amount - take
	if owed > 0 then
		profile.Debt = profile.Debt or {}
		profile.Debt[field] = (profile.Debt[field] or 0) + owed
	end
	return owed
end
```

Then every grant of that currency first pays down `Debt`. Show it plainly ("12 gems owed after a refunded purchase") so the player understands; silent debt reads as a bug and generates tickets.

**Apply on load, in the session-locked path.** The clawback is a profile write like any other: apply it after the profile loads and migrates, record the refund id in a bounded `RefundsApplied` list in the profile (so a reread of the `Clawbacks` key does not apply it twice), mark the log entry `Refunded = true`, and let the normal save persist it.

```lua
--!strict
local DataStoreService = game:GetService("DataStoreService")
local Clawbacks = DataStoreService:GetDataStore("Clawbacks_v1")

local function applyClawbacks(userId: number, profile: any)
	local ok, rec = pcall(Clawbacks.GetAsync, Clawbacks, `u_{userId}`)
	if not ok or type(rec) ~= "table" then
		return -- read failed or nothing pending; try again next join
	end
	profile.RefundsApplied = profile.RefundsApplied or {}
	local applied: { [string]: boolean } = {}
	for _, id in profile.RefundsApplied do
		applied[id] = true
	end
	for _, r in rec do
		if type(r) ~= "table" or type(r.id) ~= "string" or applied[r.id] then
			continue
		end
		local entry = matchRefund(profile.PurchaseLog or {}, r.id, tonumber(r.product) or 0, tonumber(r.t) or os.time())
		if entry and not entry.Refunded then
			Clawback.apply(profile, entry) -- policy from the table above, per product key
			entry.Refunded = true
		end
		table.insert(profile.RefundsApplied, r.id)
		applied[r.id] = true
		while #profile.RefundsApplied > 200 do
			table.remove(profile.RefundsApplied, 1)
		end
	end
end
```

Leave the `Clawbacks` key alone in the game; an offline job prunes old records. That keeps a single writer for the key (the receiver), so no write races.

**When not to claw back at all.** Small games with few refunds and only consumable products can log refunds and do nothing in-game; the effort and the risk of bugs outweigh the money. Clawback matters when refunds are being used as an exploit ("buy currency, spend it, refund") or for permanent, tradeable items.

---

## 5. Purchase support: the tickets you will get

Support load is predictable. Rule of thumb ranking by volume in a simulator or RNG game:

| Ticket | Likely causes | How to check |
|---|---|---|
| "I paid and got nothing" | Receipt stuck as `NotProcessedYet` (player left before grant, save failed); grant code missing for a product; gift recipient left; display lag only; bought the wrong product or in another game | Purchase log by user id; receipt handler errors; profile contents |
| "My purchase disappeared" | Data loss; a reset; a migration took it; trade or scam; duplicate clean-up | Profile version history, `MigrationLog`, trade history |
| "My child bought this" | Unauthorised purchase | Point to Roblox Support; you cannot refund Robux |
| "Refund me" for dissatisfaction | Misleading description, expectations | Check the description against code values |
| "The boost did nothing" | Cap reached, wrong scope ("this server"), expired on leave | Effective luck or multiplier logs |

**Measured in the reference project:** the most expensive class of bug was a product that charged but granted nothing because its grant type was missing from the server's list of supported grants; a later audit found a second one. A boot-time assertion that every configured product has a supported grant prevents the whole class ([[Developer Products and ProcessReceipt]]). Its gift system also needed explicit handling for "recipient left before the grant", with a buyer-facing message that the gift was waiting ([[Purchase Data and Receipts]]).

### What you can and cannot do

- **You cannot refund Robux.** There is no developer API to return Robux to a player for a developer product (none found as of October 2026). Refund requests go to Roblox Support. Say so clearly and kindly.
- **You can compensate in game.** Re-grant a missing purchase, or give an equivalent. Do it through a tool, never by hand-editing data.
- **You cannot see Roblox's side.** Players can see their own transaction history on their account. Ask for the date, time and product name they see there, never for passwords, screenshots of payment methods, or personal details.

### The support tool

A server-side admin command or panel, restricted by user id or group rank checked **on the server** ([[Server Authority and Validation]]):

- **Lookup**: purchase log, recent receipts, refunds applied, debt, migration log, trade history for a user id. Works for offline players by reading their profile through the same load and migrate code (read-only).
- **Re-grant by purchase id**: idempotent. Writes a support grant record with an idempotency key (`support:<ticketId>`) so a double click or a retried command cannot grant twice. Mints fresh Uids for items ([[Trading Systems Without Duplication]]).
- **Offline edits**: only through a path that respects session leases. If the player is online elsewhere, queue the grant for their next join (a mailbox key, same pattern as `Clawbacks`).
- **Audit**: every support action logs who did it, why (ticket id), and what changed.

```lua
--!strict
-- Idempotent support re-grant applied inside the session-locked profile.
local function supportGrant(profile: any, ticketId: string, grant: { [string]: number }, staffId: number): boolean
	profile.SupportGrants = profile.SupportGrants or {}
	local key = `support:{ticketId}`
	for _, g in profile.SupportGrants do
		if g.k == key then
			return false -- already granted for this ticket
		end
	end
	for field, amount in grant do
		profile[field] = (profile[field] or 0) + amount
	end
	table.insert(profile.SupportGrants, { k = key, by = staffId, g = grant, t = os.time() })
	while #profile.SupportGrants > 100 do
		table.remove(profile.SupportGrants, 1)
	end
	return true
end
```

Restricting this to trusted staff matters more than any code detail. A support tool is a currency faucet; treat its permissions like production credentials and review its audit log ([[Economy Inflation Sinks and Faucets Math]] shows how an unmodelled faucet appears in metrics).

### Reply templates (rule of thumb)

Keep replies short, specific and free of blame:

- **Found and fixed:** "Thanks for reporting this. Our records show your purchase of [product] on [date] did not finish delivering. We have added it to your account; it will appear next time you join."
- **Not found:** "We could not find a purchase of [product] on your account around [date]. Could you check your Roblox transaction history and tell us the exact date and the name shown there? Please do not send passwords or payment details."
- **Refund request:** "We are not able to refund Robux ourselves. Roblox Support handles refund requests. If something did not work as described, tell us and we will look into it."

---

## 6. Metrics that tell you something is wrong

- **Refunds per 1,000 purchases, per product.** A product with a much higher refund rate than its peers is misleading or broken. Check its description against code values first.
- **Receipts returning `NotProcessedYet`, per day.** A rise means your grant path or data stores are failing ([[Crash and Error Telemetry]]).
- **Support grants per week, per staff member.** Spikes are either an incident or misuse.
- **Debt outstanding.** If it grows, your clawback policy is creating unhappy players who cannot progress.
- **Webhook health.** Alert if no refund notifications arrive for an unusually long time relative to your purchase volume; it may mean the URL was marked invalid after failed retries.

---

## 7. Resets, migrations and paid value

Every data reset and destructive migration is a support event. Rules:

- Keep receipts and the purchase log across resets ([[Data Schema Design and Migrations]]); the reference project kept its receipts store through three resets (measured).
- Re-grant permanent paid items after a reset from the purchase log, or announce clearly what happens to them before you reset.
- Leave audit records when a migration removes anything ([[Schema Migrations - Worked Case Studies]]); support cannot answer "where did it go" without them.

---

## Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| No purchase log | Cannot answer, reverse or re-grant | Log every processed receipt with real Robux spent |
| Using the webhook Robux amount as revenue lost | Over-counts refunds under regional prices | Use the logged amount |
| Webhook handler does the work before replying | Timeouts, retries exhausted, URL disabled | Verify, queue, reply, then process |
| Game modifies profiles from the webhook path | Overwritten by the live session | Append to a per-user key; apply on load |
| Removing items the receiver traded for | Innocent players punished | Write off traded items |
| Silent debt | "My gems are broken" tickets | Show debt plainly |
| Support tool without idempotency | Double grants from double clicks | Ticket-keyed grant records |
| Asking players for account details | Safety and privacy failure | Date, time, product name only |
| Pass grants that wrote permanent rewards | Rewards survive pass refunds | Track and remove them on refund |

## Checklist

- [ ] Purchase log with purchase id, product key, real Robux spent, grant contents, time.
- [ ] Boot assertion: every product has a supported grant.
- [ ] Transaction Refunded (and Subscription Refunded if relevant) webhooks configured with a secret.
- [ ] Receiver verifies signature on the raw body, checks timestamp age, dedupes by id, replies fast.
- [ ] Refunds bridged into a per-user key; applied on load inside the session-locked path.
- [ ] Clawback policy written per product type; traded items and consumables written off.
- [ ] Debt shown to the player; future grants repay it.
- [ ] Support tool: server-checked permissions, read-only lookup, idempotent re-grant, audit log.
- [ ] Reply templates that never ask for credentials.
- [ ] Refund rate per product, stuck receipts, support grants and webhook health monitored.

## See also
[[Developer Products and ProcessReceipt]] · [[Purchase Data and Receipts]] · [[Game Passes]] · [[Subscriptions and Premium Payouts]] · [[Open Cloud APIs]] · [[HttpService and External APIs]] · [[Cross-Server Messaging]] · [[Data Loss Prevention and Recovery]] · [[Trading Systems Without Duplication]] · [[Schema Migrations - Worked Case Studies]] · [[Robux Price Points and Offer Design]] · [[Community Building]] · [[Ethical Design and Player Trust]]

## Connected notes
<!-- auto-links:start -->
[[Shop with Game Passes and Developer Products End to End]] · Subscriptions and Recurring Revenue · Skill - Roblox Monetization Compliance · Commerce and Physical Goods · Idempotency · Player Privacy and Data Deletion
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Purchase Receipts and Purchase History in UI]] · [[Monetization Overview]] · [[Subscriptions and Recurring Revenue]] · [[Pricing and Store Design]] · [[Roblox Policies Ratings and Compliance]] · [[Publishing an Experience]] · [[Paid Random Items and Odds Disclosure in Practice]] · [[Analytics and Funnels]] · [[Ads and Rewarded Video]] · [[Unit Economics - ARPDAU, Payer Conversion, LTV and Ad Payback]]
<!-- related:end -->
