---
tags: [game-design, genre, party, minigames, rounds, lobby, social, replayability, type/guide, area/design, level/intermediate, area/gameplay]
---
# Genre Playbook - Party and Minigame Collections

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Long intermissions -> 10 to 20 s, with things to do
> - Avoid: Eliminated players with nothing to do -> Spectator activities or ghost roles
> - Avoid: Minigames hand-wired into the round loop -> One contract, one module per minigame
> - Every minigame implements the contract; the manager handles teleports, rewards and saving.
> - 10 or more minigames; recent-repeat avoidance in the picker.
> - 100-round soak test in Studio: memory and connection count stable.
>
> Cost: TL;DR ~160 tok · whole note ~3.7k tok. Read more: ## 3. The framework you must build · ## 4. Minigame design · ## 9. Common mistakes · ## 10. Launch checklist
<!-- tldr:end -->

A party game runs short rounds of different minigames for a whole server: a lobby, a vote or random pick, a 1 to 3 minute minigame, winners rewarded, back to the lobby. Variants include classic minigame rotations, elimination shows (last player standing across escalating rounds), "survive the disaster" rounds, hide and seek, tag variants, and social deduction (one hidden role among the players). The genre is native to Roblox: free-to-play friends joining a server together, short attention spans and a young audience all fit it.

It is also deceptively expensive. Each minigame is a small game with its own rules, map, edge cases and balance. This note covers the loop, round timing, monetisation, the framework you must build so minigames are cheap to add, the Roblox-specific risks, the patterns successful party games share, and a launch checklist. For the round engine itself, see [[Round-Based Minigame Loop End to End]] and [[Spawning Teams and Rounds]].

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production combat game; its onboarding and funnel lessons transfer), **Rule of thumb**.

---

## 1. Core loop

```
lobby (intermission) -> pick a minigame -> teleport into the map -> play the round -> results and rewards -> lobby
```

| Loop | Length | Content |
|---|---|---|
| Round | 1 to 3 min | One minigame's rules |
| Cycle | 2 to 4 min | Intermission, vote, round, results |
| Session | 15 to 40 min | Many cycles; levels and coins accumulate |
| Meta | Weeks | Cosmetics, levels, titles, unlocking minigames or maps |

### Why it works
- **Variety is the hook.** "One more round" works because the next round is different.
- **Low skill floor.** Each minigame has one rule, explained in one sentence.
- **Losing is cheap.** A lost round costs two minutes, and the next round is a fresh start.
- **Social chaos.** Watching others fail, teaming up, betraying: party games produce clips and laughs.

### Why it fails
- **Dead time.** Waiting in the lobby, waiting while eliminated, waiting for a minimum player count. Dead time is the genre's number one retention killer.
- **Too few minigames.** Players see repeats within 15 minutes and leave.
- **Unclear rules.** A minigame that needs a paragraph to explain loses young players before it starts.
- **Empty servers.** Most minigames need 4 or more players to work.

---

## 2. Timing and dead time

| Phase | Target (rule of thumb) | Notes |
|---|---|---|
| Intermission | 10 to 20 s | Long enough to vote and buy; short enough not to bore |
| Map vote | Inside intermission | 3 options; ties broken randomly |
| Rule card | 3 to 5 s | One sentence and one icon, while players load into the map |
| Round | 60 to 180 s | Hard time limit, always |
| Results | 5 to 8 s | Winners, rewards, a highlight |

Rules for eliminated players:
- **Spectate with something to do**: switch target, predict the winner for a small reward, throw harmless items, play a mini-activity in a spectator box.
- **Short rounds limit elimination time.** An elimination round that leaves early losers waiting 3 minutes is too long.
- **Eliminated players can also be "ghosts"** who affect the round (drop obstacles, cheer). This turns waiting into play.

Minimum player counts: let a single player play something (a solo course, a practice mode, bots) while waiting. A lobby showing "Waiting for 2 more players" with nothing to do loses the first player before the second arrives.

---

## 3. The framework you must build

The single most important engineering decision: **make adding a minigame cheap**. A good framework turns a new minigame into one module and one map.

### Minigame contract
Every minigame implements the same interface; the round manager owns everything else.

```lua
--!strict
-- ReplicatedStorage/Minigames/Types (ModuleScript)
export type Context = {
	players: { Player },
	map: Model,
	endRound: (winners: { Player }) -> (),
	timeLimit: number,
}

export type Minigame = {
	id: string,
	displayName: string,
	rule: string,              -- one sentence, localised
	minPlayers: number,
	maxPlayers: number?,
	teams: number?,            -- nil for free-for-all
	mapTag: string,            -- which maps can host it
	start: (ctx: Context) -> (),
	cleanup: () -> (),         -- disconnect everything start() created
}

return nil
```

The round manager's job: choose a minigame that fits the current player count, load a map, spawn players, show the rule card, call `start`, enforce the time limit, call `cleanup`, pay rewards, and return everyone to the lobby. Minigames never teleport players, pay rewards or save data themselves. See [[Round-Based Minigame Loop End to End]] for a full implementation.

### Cleanup discipline
Every minigame creates connections, parts, tools and timers. Forgetting to clean one up causes bugs that appear only after 30 rounds: a touch handler from round 3 still awarding points in round 31, memory growing, a tool from one minigame appearing in the next. Use a maid / janitor pattern per round: everything the round creates registers with a cleanup list, and the manager destroys the list unconditionally after the round, even if the minigame errored.

```lua
--!strict
-- A minimal per-round cleanup list.
local Janitor = {}
Janitor.__index = Janitor

export type Janitor = typeof(setmetatable({} :: { items: { any } }, Janitor))

function Janitor.new(): Janitor
	return setmetatable({ items = {} }, Janitor)
end

function Janitor.add<T>(self: Janitor, item: T): T
	table.insert(self.items, item)
	return item
end

function Janitor.clean(self: Janitor)
	for i = #self.items, 1, -1 do
		local item = self.items[i]
		if typeof(item) == "RBXScriptConnection" then
			item:Disconnect()
		elseif typeof(item) == "Instance" then
			item:Destroy()
		elseif typeof(item) == "thread" then
			pcall(task.cancel, item)
		elseif type(item) == "function" then
			pcall(item)
		end
		self.items[i] = nil
	end
end

return Janitor
```

Run each minigame's `start` inside `pcall` or `xpcall`, so an error in one minigame ends the round gracefully instead of freezing the server's loop. See [[Error Handling - pcall xpcall and Promise Patterns]] and [[Events Signals and Connections]].

### Maps
- **Load maps from ServerStorage** into Workspace per round, and destroy them after. Keep maps small; a large map loaded every two minutes causes a hitch and a replication burst for every client.
- **With streaming enabled**, freshly loaded maps stream to clients over time. Spawn players only after their area has streamed (`Player:RequestStreamAroundAsync` before teleporting) or the first seconds of the round happen in a void. See [[Instance Streaming]].
- **Spawn points** tagged per map and per team.
- **Kill planes** under every map; players who fall out are eliminated or respawned according to the minigame's rule.

### Player state
Track per-player round state on the server: in round, eliminated, spectating, AFK. Joining mid-round puts a player in the lobby or spectator mode. Leaving mid-round must never stall the round (for example a team game where the last player of a team leaves: end the round, the other team wins).

---

## 4. Minigame design

### A good minigame
- **One rule, one sentence.** "Stand on the platform when the music stops." "Last one on the falling tiles wins."
- **Visible state.** Everyone can see who is winning: elimination counts, scores above heads, a shrinking safe area.
- **Comeback possible.** Avoid early, permanent leads that make the rest of the round pointless.
- **Lasts the time limit** or ends early with a clear winner.
- **Works from 4 to 20 players** (or declares its range in `minPlayers` / `maxPlayers`).
- **Fair on phones.** No precise jumps in party minigames unless that is the point; no small buttons. See [[Genre Playbook - Obbies and Platformers]].

### A portfolio of minigames
| Type | Example rule | Feel |
|---|---|---|
| Survival / elimination | Avoid the falling things | Tension, spectacle |
| Race | First to the end of the course | Competition |
| Collection | Most coins in 60 s | Busy, chaotic |
| Team | Capture the flag, tug of war | Cooperation |
| Reaction | Press when the light turns green | Quick, fair |
| Social / deduction | Find the impostor | Talk, accuse, laugh |
| Creative | Build something; others vote | Expression |
| Asymmetric | One hunter, many hiders | Drama |

Launch with **at least 10 to 15 minigames** (rule of thumb) so a typical 20-minute session rarely repeats; with a weighted random pick that avoids the last few played, players see variety even with fewer.

### Social deduction and text
Deduction games depend on chat. Chat on Roblox is filtered and age-gated; some players cannot chat at all. Design deduction minigames that work with **quick-chat buttons and votes**, not only free text, and respect chat restrictions. Any text players enter for others to see (a team name, a drawing title) must go through `TextService` filtering. See [[Text Chat Customization with TextChatService]] and [[Age Checks and Safety Features]].

---

## 5. Rewards and progression

- **Pay everyone something** each round (participation), more for placement, a bonus for winning. A player who never wins must still progress.
- **Levels** from XP per round give the session a long goal.
- **Cosmetics** are the main reward and the main purchase: trails, hats, win effects, emotes, titles.
- **Win effects and victory poses** shown on the results screen are the genre's best cosmetic: everyone sees them.
- **Daily and weekly challenges** ("win 3 team minigames") steer players to new minigames. See [[Retention and Return Hooks]].

---

## 6. Monetisation that fits

| Product | Fit | Notes |
|---|---|---|
| Cosmetics (trails, win effects, emotes, titles) | Core | Visible to the whole server every round |
| VIP pass (coin multiplier, extra map vote weight, VIP lobby area) | Strong | Map vote weight should be modest so free players still win votes |
| Private servers | Strong | Friend groups and parties |
| Coin packs | Common | |
| Power-ups during rounds (shields, speed) | Risky | Feels pay-to-win in competitive minigames |
| "Choose next minigame" developer product | Common | Fine if limited and transparent; annoying if bought every round |

Free players must win often enough to enjoy the game. Measure win rate by spending tier; if payers win much more, rounds are pay-to-win.

---

## 7. Technical risks on Roblox

| Risk | What it looks like | Mitigation |
|---|---|---|
| Leaked connections across rounds | Points awarded by old handlers; memory grows | Per-round janitor; destroy everything |
| Map load hitches | Freeze at round start | Small maps, preloaded assets, streaming requests |
| Desynced round state | Client UI shows a different phase than the server | Server owns phase; replicate phase and end time via attributes; clients count down from `workspace:GetServerTimeNow()` |
| Exploited minigames | Teleport to the finish, fly over obstacles | Server checks per minigame (position plausibility, checkpoint order) |
| Physics minigames | Flinging, players knocked off map unfairly | Server-owned physics objects; collision groups |
| Mid-round leavers | Rounds that never end | End conditions that count remaining players every tick |
| Many minigames, little testing | A rare minigame breaks for weeks | Automated round tests: run every minigame with bots in Studio |

See [[Hunting Memory Leaks Step by Step]], [[Testing Strategies and Frameworks]] and [[Multi-Client and Device Playtesting Protocols]].

---

## 8. Patterns successful party games share

Patterns, not copies:
- **A charismatic host or theme** (a game-show presenter, a mascot) that ties random minigames together.
- **Escalation**: rounds get harder, or the final round is special.
- **Moments for clips**: a dramatic final two, slow-motion finishes, silly physics.
- **Frequent new minigames**, one or two per update; seasonal minigames for holidays.
- **Friends first**: parties stay together through teleports and teams; private servers are cheap.
- **Short rules, big text, icons**: playable without reading English. See [[Localization]].

---

## 9. Common mistakes

| Mistake | Better |
|---|---|
| Long intermissions | 10 to 20 s, with things to do |
| Eliminated players with nothing to do | Spectator activities or ghost roles |
| Minigames hand-wired into the round loop | One contract, one module per minigame |
| No cleanup between rounds | Janitor per round, unconditional |
| Launching with 5 minigames | 10 to 15, weighted random with no recent repeats |
| Deduction games requiring free chat | Quick-chat and votes |
| Pay-to-win power-ups | Cosmetics and modest VIP perks |
| Rounds waiting for 4 players with nothing to do | Solo activities while waiting |

## 10. Launch checklist

- [ ] Every minigame implements the contract; the manager handles teleports, rewards and saving.
- [ ] 10 or more minigames; recent-repeat avoidance in the picker.
- [ ] 100-round soak test in Studio: memory and connection count stable.
- [ ] Mid-round leave and join handled for every minigame.
- [ ] Rule card for each minigame in one sentence plus an icon; localised.
- [ ] Phone pass for every minigame.
- [ ] Participation rewards for every player each round.
- [ ] Per-minigame analytics: completion, quit rate during the round, vote share. See [[Analytics and Funnels]].
- [ ] Chat-dependent minigames work with quick-chat only.

## See also
- [[Round-Based Minigame Loop End to End]], [[Spawning Teams and Rounds]], [[Social Design and Multiplayer Play]]
- [[Core Loops and Session Design]], [[First-Time User Experience and Onboarding]], [[Retention and Return Hooks]]
- [[Genre Playbook - Obbies and Platformers]], [[Genre Playbook - Horror and Story]], [[Ethical Design and Player Trust]]

## Connected notes
<!-- auto-links:start -->
[[Arena Rounds with Teams and Spectating End to End]] · Links - Rounds and matchmaking · [[Genre Playbook - Sports]] · Worked Builds Start Here · Genre Systems Start Here · Multiplayer Services Start Here
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Genre Playbook - Social Deduction and Murder Mystery]] · [[Genre Playbook - Tower Defense]] · [[Genre Playbook - Battle Royale]] · [[Genre Playbook - Roleplay and Social Hangouts]] · [[Genre Playbook - Racing and Driving]] · [[Boss Fight Design Patterns]] · [[Genre Playbook - Zombie and Wave Survival Co-op]] · [[Genre Playbook - Puzzle and Escape Rooms]]
<!-- related:end -->
