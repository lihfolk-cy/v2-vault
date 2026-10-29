---
tags: [gameplay, combat, kill-credit, assists, kill-feed, death-recap, pvp, attribution, type/guide, area/gameplay, level/intermediate, server-authority]
---
# Kill Credit, Assists, Kill Feed and Death Recaps

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Credit from overkill damage -> Record damage removed from health only
> - Avoid: No environmental attribution -> Last player attacker within a short window
> - Avoid: Hazards with no owner -> Owner attribute on placed hazards
> - Single ledger record point in the damage core; window and heal adjustment implemented.
> - One kill rule chosen; environmental, owned-hazard, suicide and team-kill cases defined.
> - Assist threshold and non-damage contributions; anti-farm caps.
>
> Cost: TL;DR ~160 tok · whole note ~2.2k tok. Read more: ## 1. The damage ledger · ## 2. Deciding the killer · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Who gets the kill decides who gets paid, who climbs the leaderboard and who feels robbed. [[Combat Systems Architecture]] gives the kill payload and a one-line rule (most damage or last hit, assists over a threshold). This note is the full attribution system: a per-victim damage ledger with time windows, environmental and indirect kills, assist rules, the kill feed message and a death recap that tells the victim what happened. Everything is computed on the server from the damage core's records; clients only display.

Source labels: **Rule of thumb**, **Roblox docs** where engine calls are used.

---

## 1. The damage ledger

Every successful damage application (after mitigation, using damage actually removed from health, not overkill) appends to the victim's ledger:

```lua
--!strict
export type Entry = { attacker: number?, source: string, amount: number, t: number, crit: boolean, zone: string? }
-- attacker = UserId, or nil for the world; source = weapon or ability id, "Fall", "Lava", "Explosion:Barrel"

local WINDOW = 12 -- seconds of history kept per victim

local Ledger = {}
local ledgers: { [Model]: { Entry } } = {}

function Ledger.record(victim: Model, e: Entry)
	local list = ledgers[victim]
	if not list then
		list = {}
		ledgers[victim] = list
	end
	table.insert(list, e)
	local cutoff = e.t - WINDOW
	while list[1] and list[1].t < cutoff do
		table.remove(list, 1)
	end
end

function Ledger.take(victim: Model): { Entry }
	local list = ledgers[victim] or {}
	ledgers[victim] = nil
	return list
end

-- Healing reduces old claims: remove damage from the oldest entries first
function Ledger.heal(victim: Model, amount: number)
	local list = ledgers[victim]
	if not list then return end
	local i = 1
	while amount > 0 and list[i] do
		local take = math.min(list[i].amount, amount)
		list[i].amount -= take
		amount -= take
		i += 1
	end
end

return Ledger
```

Clear the ledger on death (after resolving credit), on respawn and on character removal. Use `workspace:GetServerTimeNow()` or `os.clock()` consistently for `t`.

## 2. Deciding the killer

Pick one rule and apply it everywhere (**Rule of thumb** options):

| Rule | Behaviour | Fits |
|---|---|---|
| Last hit | Whoever dealt the final damage | Arcade shooters; simple and transparent |
| Most damage in window | Highest total in the last N seconds | RPG and PvE; rewards contribution |
| Last hit, but environmental kills go to the last attacker within window | Players get credit for knocking someone into lava | Platform fighters, obbies with PvP, any game with hazards |

**Environmental and indirect kills.** When the final damage source is the world (fall, void, lava, drowning, a barrel nobody owned), credit the last *player* attacker within a short window (3 to 6 s). For knockback-only interactions that deal no damage (a shove off a cliff), record a zero-damage "touch" entry so the shover can receive credit.

**Owned hazards.** Barrels, turrets, traps and summons carry an `Owner` attribute set by the server when placed or triggered; damage from them is recorded with that owner as attacker.

**Suicide and self-damage.** Self-inflicted deaths with a recent enemy attacker go to that attacker (prevents "deny the kill" by jumping off the map). Without one, it is a suicide; decide whether it costs score.

**Team kills.** Friendly damage (if enabled) never grants kill credit; it may penalise.

## 3. Assists

- Anyone other than the killer whose damage in the window is at least a threshold of the victim's max health (10 to 25%) gets an assist.
- Non-damage contributions can also count: healing the killer in the last few seconds, applying a debuff or stun to the victim, spotting. Record them as zero-damage entries with a type.
- Pay assists meaningfully (half the kill reward is common) so groups do not fight over last hits ([[Social Design and Multiplayer Play]]).
- **Anti-farm**: cap credited kills per victim per attacker per minute in PvP, and ignore kills on AFK or newly spawned players inside spawn protection ([[Spawn Points Safe Zones and Respawn Flow]]).

## 4. The kill feed

- Server builds one message per death: killer display name, weapon or ability icon id, victim, flags (headshot, assist count, environmental, revenge, streak).
- Broadcast **reliably** to players who should see it (all players in small servers; teammates plus involved players in large servers). Kill feeds are low frequency; reliability matters more than bandwidth.
- Use display names, but the feed is user-facing text: names are already filtered by the platform; any custom text (clan tags, custom weapon names) needs filtering ([[Text Chat Customization with TextChatService]]).
- Client UI: newest on top, 4 to 6 lines, each fades after 4 to 6 s; the local player's kills and deaths highlighted; combine rapid multi-kills into one line ("x3").

## 5. Death recap

The victim deserves an answer to "what killed me?". Build it from the ledger at death:

| Field | From |
|---|---|
| Killer and how | Credit decision |
| Damage taken by source, in the window | Sum per attacker and source |
| Biggest hit | Max entry, with crit and zone |
| Time from first damage to death | `t_death - t_first` (a short time explains "I got melted") |
| Assisters | Assist list |

Send it to the victim only, reliably, and show it on the death screen ([[Cameras and Cutscenes]] for death cameras). **Rule of thumb:** show at most three sources plus "other"; a recap that lists twenty ticks of poison is noise.

A **killcam** (replay of the killer's view) is expensive to do properly on Roblox: it needs a server-recorded history of positions and aim. A cheap substitute is a camera that frames the killer for 2 to 3 seconds with their name and health, which often satisfies the same need.

## 6. Plumbing

- The damage core calls `Ledger.record` in exactly one place ([[Damage Formula Pipeline - Armor, Resistances, Crits and Order of Operations]]).
- Death is detected in one place (your health reaching zero, or `Humanoid.Died` if you use Humanoid health; **Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/Humanoid#Died), which takes the ledger, decides credit, builds the kill payload, fires rewards, feed and recap.
- Downed systems: decide whether credit happens at down or at final death and keep the ledger through the downed state ([[Downed, Revive and Bleed-Out States]]).
- Log every kill with killer, victim, weapon, distance and assists for balancing and exploit review ([[Detecting Combat Exploits - Reach Rate and Aim]]).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Credit from overkill damage | One-shot weapons dominate "most damage" | Record damage removed from health only |
| No environmental attribution | Knock-off kills give nothing | Last player attacker within a short window |
| Hazards with no owner | Trap kills uncredited | Owner attribute on placed hazards |
| Assists unpaid | Players steal last hits | Meaningful assist reward |
| Ledger not cleared | Credit from a previous life | Clear on death, respawn and removal |
| Recap lists every tick | Unreadable | Group by source, top three |

## Checklist
- [ ] Single ledger record point in the damage core; window and heal adjustment implemented.
- [ ] One kill rule chosen; environmental, owned-hazard, suicide and team-kill cases defined.
- [ ] Assist threshold and non-damage contributions; anti-farm caps.
- [ ] Kill feed message built on the server, broadcast reliably, multi-kills merged.
- [ ] Victim recap with top sources, biggest hit and time-to-death.
- [ ] Every kill logged for balance and exploit review.

## See also
[[Combat Systems Architecture]] · [[Arena Rounds with Teams and Spectating End to End]] · [[Spawning Teams and Rounds]] · [[Genre Playbook - Shooters FPS and TPS]] · [[Genre Playbook - Battlegrounds and Arena Fighters]] · [[HUD Design]]

## Connected notes
<!-- auto-links:start -->
[[Explosions - Radius Damage, Falloff and Cover Checks]] · [[Notification and Toast Systems]] · Time-to-Kill Math and a Weapon Balance Sheet
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Status Effects Buffs and Stacking Rules]] · [[Grabs, Carries and Throws - Moving Players Safely]] · [[Hitboxes and Hit Detection]] · [[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]] · [[Spawn Director - Credit Budgets and Player-Count Scaling]] · [[Characters and Humanoids]] · [[Quests and Objectives]] · [[Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder]]
<!-- related:end -->
