---
tags: [studio, places, universe, settings, environments, publishing]
---
# Places Universes and Experience Settings

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Studio API access on in the live universe -> Dev universe, or isolated keys
> - Avoid: Code assumes `PlaceId ~= 0` -> Handle 0 explicitly
> - Avoid: Publishing over the start place with plain Publish when changing... -> Publish As, choose the current start place
> - Dev universe exists and mirrors the live place structure.
> - Studio API access on only where data is disposable.
> - Environment module for ids; no ids scattered in scripts.
>
> Cost: TL;DR ~150 tok · whole note ~3.3k tok. Read more: ## 2. Creating and managing places · ## 5. Environments: dev, staging, live · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

A Roblox "game" (the docs also say experience) is a **universe** containing one or more **places**. Players enter through the **start place**; other places are reached only by teleport. Settings live at three levels: the universe (name, access, monetization, security toggles), each place (its data model, server size, version history), and the Creator Hub (audience, configs, server management). Getting this structure right early decides how you separate development from live, how you test risky changes, and how you ship without breaking players. Facts are from the docs as of October 2026.

Labels: **Docs**, **Measured**, **Rule of thumb**.

---

## 1. Vocabulary

| Term | Meaning | In code |
|---|---|---|
| Game / experience / universe | The product players find; owns places, DataStores, products, passes, badges | `game.GameId` (universe id) |
| Place | One data model: a world, its scripts, its settings | `game.PlaceId` |
| Start place | The place players load into from the game page | |
| Place version | A saved or published revision of a place | `game.PlaceVersion` |
| Server / job | One running instance of a place | `game.JobId` |

In Studio, an unpublished place has `PlaceId` and `GameId` of 0. Code that branches on ids must handle that.

Docs compare places to Unity scenes or Unreal maps, but the analogy breaks in one way: **places do not share runtime state**. Moving between places is a teleport to a different server; the only shared things are universe-level services (DataStores, MemoryStores, MessagingService, products, badges) and assets. See [[Teleporting and Multi-Place Games]] and [[Cross-Server Messaging]].

## 2. Creating and managing places

- **New game**: open a template, **File > Publish**, fill in name, genre, description, icon and thumbnail; Roblox creates the universe (Docs). New games are private until released (see [[Publishing an Experience]]).
- **Add a place**: open any place, **File > Publish As**, choose the game, **Add as a new place**, **Create** (Docs).
- **Change the start place**: it cannot be swapped instantly. Optionally back up the current start place, open the intended new start place via **Configurations > Places > Edit in Studio**, then **File > Publish As**, same game, choose the **current start place**, **Overwrite**; restart servers if live. Do not use plain Publish here, which publishes the place over itself (Docs).
- **Place size**: up to 100 MB (104,857,600 bytes); beyond that, save and publish may fail. If you hit it, look for obfuscated scripts (possible backdoors), redundant parts, heavy terrain, precise collision, or split the game across places (Docs). See [[Case Study - Instance Cleanup and Place Size]].
- **Copying**: games are copylocked by default. The start place's **Permissions**, **Allow users to download a copy of this Place** uncopylocks it (Docs). Never do that for a game with secrets in server scripts.

### One place or many?

| Choose one place when | Choose several when |
|---|---|
| The world fits in memory with streaming | Areas are huge, or memory per server is the limit |
| Players move freely and often between areas | Areas are distinct modes (lobby, match, dungeon) |
| You want instant transitions | You can hide a teleport behind a loading screen |
| One team edits everything | Separate teams own separate areas |

Rule of thumb: start with one place and streaming (see [[Instance Streaming]]); split when a mode needs different server sizes or a different data model. Each extra place multiplies publishing, testing and version management.

## 3. Experience Settings in Studio

**File > Experience Settings** opens the game-level dialog. Sections and items referenced in the docs include (as of October 2026, labels may shift):

| Area | Notable items | Notes |
|---|---|---|
| Basic info | Name, description, genre | Discovery-relevant; see [[Discovery and the Algorithm]] |
| Communication | Voice chat, camera-driven avatar animation | |
| Permissions | Who can play and edit | Group roles for group games |
| Monetization | Passes, products, paid access, private servers | See [[Monetization Overview]] |
| Security | **Allow HTTP Requests**, **Enable Studio Access to API Services**, **Allow Third Party Teleports**, third-party sales | HTTP must be on for `HttpService` calls; Studio API access lets Studio tests use DataStores and similar services |
| Places | The universe's places | |
| Avatar | Scaling, clothing overrides | |
| Other | **Enable Drafts Mode** (collaborative scripting) | See [[Team Create and Collaboration]] |

Two security toggles deserve care:
- **Enable Studio Access to API Services** lets Studio tests read and write the game's real DataStores. Combine it with a **separate development universe**, or isolated test keys, or you will corrupt live player data from Studio. Changes to this toggle appear in Activity History (Docs).
- **Allow Third Party Teleports** only matters for teleporting to games you do not own; teleports between your own games work without it (Docs).

For unpublished places, set `HttpService.HttpEnabled = true` from the Command Bar to test HTTP (Docs).

## 4. Creator Hub settings

Many settings live only in the Creator Dashboard (Docs):
- **Audience > Access Settings**: minimum age, regions.
- **Audience > Communication Settings**: strong language toggle (see [[Roblox Policies Ratings and Compliance]]).
- **Configurations > Places**: per-place settings, version history and restore.
- **Configurations > Server management**: restart servers, with **Restart only servers with outdated versions** and **Delay server restart** (1 to 60 minutes bleed-off) (Docs).
- **Configs**: live key/value config with staging and targeting, read through `ConfigService` (see [[Global State and Live Config]]).
- **Maturity & Compliance Questionnaire** (see [[Roblox Policies Ratings and Compliance]]).

Join restrictions per non-start place (Docs, teleport guide): **Limited to same universe** (client or server teleports within the game) or **Secure within universe only** (server-initiated teleports only). Use the secure option for test places that players must never reach and for places that require progression.

## 5. Environments: dev, staging, live

Roblox has no built-in environments. Teams build them from universes and places.

| Pattern | How | Pros | Cons |
|---|---|---|---|
| **Separate universes** (recommended) | A private "Game - Dev" universe and the live universe, same place structure | DataStores, products and configs are isolated; Studio API access safe in dev | Products, passes and badges have different ids; assets must be usable by both owners |
| **Test place in the live universe** | Extra place with secure join restriction | Same DataStores and products for realistic tests | Easy to touch live data; use separate DataStore names |
| **Single place only** | Everyone edits the live place | Simple | Every edit is one publish away from players; no staging |

With separate universes, keep ids in one config module keyed by environment:

```lua
--!strict
-- ReplicatedStorage.Shared.Environment
-- Ids below are placeholders. Unpublished Studio places report 0.
local Environment = {}

export type Env = "Studio" | "Dev" | "Live"

local DEV_UNIVERSE = 0000000000
local LIVE_UNIVERSE = 0000000000

function Environment.current(): Env
	local id = game.GameId
	if id == LIVE_UNIVERSE and LIVE_UNIVERSE ~= 0 then
		return "Live"
	elseif id == DEV_UNIVERSE and DEV_UNIVERSE ~= 0 then
		return "Dev"
	end
	return "Studio"
end

local PRODUCTS: { [Env]: { [string]: number } } = {
	Studio = { Coins100 = 0 },
	Dev = { Coins100 = 0 },
	Live = { Coins100 = 0 },
}

function Environment.productId(name: string): number
	local id = PRODUCTS[Environment.current()][name]
	assert(id, "unknown product " .. name)
	return id
end

return table.freeze(Environment)
```

Promotion from dev to live: publish the dev place file over the live place (Save to File then **Publish As**, or the Open Cloud place publishing API from CI; see [[Git and Source Control for Roblox]]). Assets referenced by id must be accessible to the live owner: animations especially must be owned by the same user or group as the game (see [[Animation Asset Permissions and Groups]]).

## 6. Shipping updates to running servers

Publishing does not move players (Docs). Running servers keep the old version until they empty or you restart them. Options (Docs):
- **Restart Servers** with **Restart only servers with outdated versions** (recommended) and optionally **Delay server restart** to give players 1 to 60 minutes to leave.
- Roblox stops matchmaking into outdated servers, waits the delay, then teleports players to updated servers; players from one old server go to the same new server.
- Servers receive `DataModel.ServerRestartScheduled(restartTime, source, attributes)`; `source` is `Enum.CloseReason.DeveloperUpdate` for your updates or `RobloxMaintenance` for platform maintenance.

```lua
--!strict
-- Server: warn players and flush saves before a scheduled restart.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local notice = ReplicatedStorage:WaitForChild("ServerNotice") :: RemoteEvent

game.ServerRestartScheduled:Connect(function(restartTime: DateTime, source: Enum.CloseReason, _attributes: any)
	local seconds = restartTime.UnixTimestamp - DateTime.now().UnixTimestamp
	notice:FireAllClients("update", math.max(0, seconds), source == Enum.CloseReason.DeveloperUpdate)
	-- Start an early autosave here; BindToClose still runs at shutdown (see Saving Correctly).
end)
```

If player data formats change between versions, restart all outdated servers; mixed versions writing the same data is a classic corruption source (Docs advise restarting in that case). See [[Saving Correctly - Autosave and BindToClose]], [[Data Schema Design and Migrations]] and [[Server Lifecycle and Shutdown]].

For time-sensitive launches, ship the code early behind a config and flip the config at launch (Docs suggestion, see [[Global State and Live Config]]).

## 7. Programmatic access

| Need | API |
|---|---|
| Publish a place file from CI | Open Cloud place publishing: `POST https://apis.roblox.com/universes/v1/{universeId}/places/{placeId}/versions?versionType=Published` with `x-api-key` (scope universe-places write) and the `.rbxl` (octet-stream) or `.rbxlx` (XML) body; returns `{"versionNumber": N}` (Docs) |
| Run Luau headlessly against a place version | Open Cloud Luau Execution (tasks up to 5 minutes, 10 concurrent per place) (Docs) |
| Restart servers | Open Cloud universe restart endpoint (Docs, external tools page) |
| Open a specific place or version in Studio | Studio CLI `--task EditPlace` / `EditPlaceRevision --placeVersion N` (Docs) |

Limitation (Docs): the place publishing API does not update `EditableImage`, `EditableMesh`, `PartOperation` (unions), `SurfaceAppearance` or `BaseWrap` instances. Publish from Studio after changing those. A CI pipeline that rebuilds a place containing unions can silently ship stale geometry.

## 8. Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Studio API access on in the live universe | Tests overwrite real player data | Dev universe, or isolated keys |
| Code assumes `PlaceId ~= 0` | Errors in unpublished Studio places | Handle 0 explicitly |
| Publishing over the start place with plain Publish when changing start place | Overwrites the wrong place | Publish As, choose the current start place |
| Publishing and assuming players updated | Mixed versions for hours | Restart outdated servers |
| Data format change without restart | Old servers write old format | Restart all outdated servers, migrations tolerant both ways |
| Test place reachable by players | Exploits, leaks | Secure within universe only |
| Hard-coded product ids | Dev purchases hit live products, or break | Environment module |

## 9. Checklist

- [ ] Dev universe exists and mirrors the live place structure.
- [ ] Studio API access on only where data is disposable.
- [ ] Environment module for ids; no ids scattered in scripts.
- [ ] Non-start places have deliberate join restrictions.
- [ ] Release procedure: publish, restart outdated servers, watch errors (see [[Release Process and Rollbacks]]).
- [ ] `ServerRestartScheduled` handled.
- [ ] Unions and SurfaceAppearances published from Studio if CI publishes places.

## See also

- [[Teleporting and Multi-Place Games]], [[Publishing an Experience]], [[Release Process and Rollbacks]]
- [[Global State and Live Config]], [[Open Cloud APIs]], [[Server Lifecycle and Shutdown]]
- [[Version History and Backups]], [[Git and Source Control for Roblox]]

## Connected notes
<!-- auto-links:start -->
[[Build Test and Release Pipeline]] · [[Server Shutdowns Soft Updates and Migration]] · [[Code Pipeline - Rojo Git and CI]] · [[Asset Upload Automation with Open Cloud]] · [[Packages and Shared Assets Across Places]] · [[Links - Settings and publishing]]
<!-- auto-links:end -->
