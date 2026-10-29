---
tags: [delta, datastore, limits, storage, open-cloud, web-api, rate-limits, deprecations, extended-services, type/guide, area/platform, level/intermediate]
verified: 2026-10-28
---
# Data and Cloud Changes 2025-2026

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Treating every DataStore throttle as one error.
> - Avoid: Expecting the storage cap to block writes.
> - Avoid: Quoting only per-server budgets. Budgets are per experience and shared with Open Cloud since July 29, 2026; per-server caps...
> - DataStore calls in `pcall` with backoff and jitter; throttle codes logged; per-server limits raised with...
> - Budgets taken from the per-experience table; `UpdateAsync` counted as read plus write.
> - Background jobs self-throttle with `GetRequestBudgetForRequestType` or HTTP-side limits.
>
> Cost: TL;DR ~180 tok · whole note ~2.1k tok. Read more: ## 1. Timeline · ## 2. Numbers to use now · ## Common mistakes · ## Checklist
<!-- tldr:end -->

DataStore limits moved from per-server to per-experience, then merged with Open Cloud into one budget, and a total storage cap arrived. Several legacy web endpoints that tools and bots used for passes and products were retired. Models trained on 2023-2024 material quote the old per-server formulas and the "one write per key every 6 seconds" rule. Labels follow [[Roblox Changes 2025-2026]].

## 1. Timeline

| Date | Change | Label and source |
|---|---|---|
| April 2025 | Announced: access limits move from per-server to per-experience; a total storage limit is coming | Roblox docs, https://devforum.roblox.com/t/datastores-access-and-storage-updates/3597255 |
| December 2025 | Per-experience access limits live; storage limit set so that fewer than 30 of the top 55 million experiences are affected | Roblox docs (update in the same thread) |
| April 9, 2026 | Storage limits enforced | Reported (rblx.news daily, April 16, 2026) |
| **July 29, 2026** | In-game and Open Cloud DataStore requests **share one per-experience budget** per request type; base raised to **300**; storage baseline raised to **500 MB + 1 MB per lifetime player**; Extended Services covers Open Cloud DataStores; Open Cloud usage visible in the Creator Dashboard | Roblox docs, https://devforum.roblox.com/t/unifying-data-stores-open-cloud-and-game-apis-and-increasing-storage-limits/4739240 (posted July 15, live July 29) |

## 2. Numbers to use now

Per-experience, per minute (Roblox docs limits page as recorded in [[DataStore Fundamentals]], October 2026; CCU = concurrent users):

| Request type | Budget |
|---|---|
| Read (standard or ordered) | 300 + CCU x 40 |
| Write | 300 + CCU x 20 |
| List | 300 + CCU x 2 |
| Remove | 300 + CCU x 40 |

- `UpdateAsync` costs one read and one write.
- **Per key:** value up to 4,194,304 characters serialized; write throughput **4 MB per minute** per key. The old "6 seconds between writes to one key" rule is not on the current limits page. Spacing saves several seconds apart is still sensible.
- **Storage:** 500 MB + 1 MB x lifetime players for the experience (up from a 100 MB base). Only the latest version of each key counts, by compressed size; old versions and deleted keys do not.
- Per-server defaults (60 + players x 40 for reads, and so on) still exist. `DataStoreService:SetRateLimitForRequestType(requestType, baseLimit, perPlayerLimit)` overrides them for this server and can raise them (for `StandardRead`, `StandardWrite` and the other new types, base up to 10,000 and per player up to 200; `UpdateAsync` and `OnUpdate` cannot be set). Call it once per type at server start (Roblox docs, DataStoreService reference, October 2026).
- **Throttle errors name the level hit:** `<RequestType>GameServerThrottled` (this server's limit or a full queue), `<RequestType>ExperienceThrottled` (the experience budget shared with Open Cloud), `DatastoreThrottled` and `KeyThrottled`, alongside the older 301 to 306 queue codes (Roblox docs, error codes and limits). Retry with exponential backoff plus jitter.
- **Storage overage does not throttle writes.** After a 2-week grace period it is billed: Robux deducted from the owner, or paid through Extended Services; unpaid dues unpublish the experience (Roblox DevForum, Extended Services for Data Stores announcement).
- **The trap:** an Open Cloud script (migration, support tool, RTBF bot, leaderboard export) now spends the same budget as live servers. A bulk job can throttle every server.

```lua
-- Self-throttle a background job on the shared budget
local DataStoreService = game:GetService("DataStoreService")
local function waitForBudget(kind: Enum.DataStoreRequestType, reserve: number)
	while DataStoreService:GetRequestBudgetForRequestType(kind) <= reserve do
		task.wait(1)
	end
end
for _, key in keysToMigrate do
	waitForBudget(Enum.DataStoreRequestType.StandardWrite, 50) -- leave headroom for live saves
	-- UpdateAsync(key, migrate) ...
end
```

For Open Cloud jobs, throttle on the HTTP side and watch the Data Stores Observability dashboard.

## 3. Legacy pass and product web endpoints retired (April 23, 2026)

**Roblox docs** (DevForum "Official List of Deprecated Web Endpoints", post of April 10, 2026: https://devforum.roblox.com/t/official-list-of-deprecated-web-endpoints/62889/119).

Deprecated: `apis.roblox.com/game-passes/v1/...` (creator listing, details, create, regional-pricing preview) and `apis.roblox.com/developer-products/v1|v2/...` (image upload, creator details, create, update, list, get, regional-pricing preview). Replacements: Open Cloud **Game Passes** and **Developer Products** APIs (https://create.roblox.com/docs/cloud/reference/features/game-passes, https://create.roblox.com/docs/cloud/reference/features/developer-products), which accept API keys, OAuth 2.0 and cookies.

Impact: price-update scripts, product-creation tooling and dashboards that used the old URLs must move to Open Cloud. Use an API key scoped to the universe; never a `.ROBLOSECURITY` cookie in automation.

## 4. Web API rate-limit tuning (after October 19, 2026)

**Roblox docs** (DevForum "[API Update] API Rate Limit Tuning": https://devforum.roblox.com/t/api-update-api-rate-limit-tuning/4906160): lower cookie-authenticated and unauthenticated per-IP limits for six web API services after October 19, 2026. **Unverified:** which six services and the new values (the recap did not list them). Proxies that scrape Roblox web APIs from game servers through a shared IP are the most exposed. Prefer Open Cloud with API keys.

## 5. Open Cloud Luau Execution

**Roblox docs** (DevForum beta thread: https://devforum.roblox.com/t/beta-open-cloud-engine-api-for-executing-luau/3172185): run a Luau script headlessly against a place version through Open Cloud and read return values and logs (structured logs added later). Changes to the place are **not saved**; some engine APIs were blocked to protect production data. **Unverified:** whether it left beta by October 2026. Good for CI tests of pure modules; not a deployment tool.

## Common mistakes

- Treating every DataStore throttle as one error. Codes ending in `GameServerThrottled` mean this server's limit, `ExperienceThrottled` the shared experience budget; log the code and retry with exponential backoff and jitter.
- Expecting the storage cap to block writes. Overage keeps writing and is billed after a 2-week grace period (Robux or Extended Services).
- Quoting only per-server budgets. Budgets are per experience and shared with Open Cloud since July 29, 2026; per-server caps also apply. Nor the old "6 second" per-key rule.
- Running a bulk Open Cloud migration at peak CCU without throttling.
- Ignoring the storage cap: 500 MB + 1 MB per lifetime player, counting only the latest version of each key.
- Automation still calling `apis.roblox.com/game-passes/v1` or `developer-products/v1` endpoints.
- Using a user cookie for tooling instead of a scoped Open Cloud API key.

## Checklist

- [ ] DataStore calls in `pcall` with backoff and jitter; throttle codes logged; per-server limits raised with `SetRateLimitForRequestType` at startup only when a server genuinely needs more.
- [ ] Budgets taken from the per-experience table; `UpdateAsync` counted as read plus write.
- [ ] Background jobs self-throttle with `GetRequestBudgetForRequestType` or HTTP-side limits.
- [ ] Storage usage checked in Data Stores Observability.
- [ ] Tooling migrated to Open Cloud Game Passes and Developer Products APIs.
- [ ] No production automation depends on cookie auth.

## See also

- [[Roblox Changes 2025-2026]]
- [[DataStore Fundamentals]]
- [[Open Cloud APIs]]
- [[Saving Correctly - Autosave and BindToClose]]
- [[Session Locking and Profile Libraries]]
- [[Debugging DataStore Problems]]
- [[AI Pitfalls - Data and Monetization]]

<!-- related:start -->
## Related
[[DataStoreService - Engine Reference Card]] · [[Cookbook - Data and Saving]] · [[Engine Limits, Quotas and Defaults - Cheat Sheet]] · [[Discovery and Monetization Changes 2025-2026]] · [[Engine and API Changes 2025-2026]] · [[Policy and Age Rules 2026]] · [[API Renames and Deprecations 2025-2026]]
<!-- related:end -->
