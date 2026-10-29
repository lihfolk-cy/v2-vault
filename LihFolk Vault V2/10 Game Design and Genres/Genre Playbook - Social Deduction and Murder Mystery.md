---
tags: [game-design, genre, social-deduction, murder-mystery, hidden-roles, rounds, information-control, anti-teaming, chat, type/guide, area/design, level/intermediate]
---
# Genre Playbook - Social Deduction and Murder Mystery

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Roles stored where clients can read them.
> - Avoid: Role-specific effects replicated at round start.
> - Avoid: No grace period: instant kills at spawn.
> - Roles only sent privately; nothing role-revealing replicated.
> - Round state in one server module with grace period and clear end reveal.
> - Dead and spectator information separated.
>
> Cost: TL;DR ~130 tok · whole note ~1.9k tok. Read more: ## 3. Information control is the core system · ## 4. Anti-teaming and griefing · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Hidden-role games give each player a secret role (murderer, sheriff, innocent; impostor, crew) and let the round play out as a contest of information. On Roblox the genre's flagship is Murder Mystery 2 ([[Case Study - Murder Mystery 2]]), and the format spans fast knife-and-gun rounds to slower vote-based deduction. The design lives in information control: who knows what, when, and how the game stops that information from leaking through the client, chat or friends teaming.

Labels: **Roblox docs**, **Rule of thumb**, **Unverified**.

## 1. Two families

| Family | Round | Resolution | Social load |
|---|---|---|---|
| Action deduction (murder mystery) | 2 to 4 min | Killer eliminates everyone, or is shot by a gun holder | Low: works without chat |
| Discussion deduction (impostor-style) | 5 to 15 min | Vote out suspects after meetings | High: needs chat or voice |

Most Roblox audiences are on phones and many have limited chat; action deduction suits them better. Discussion games need structured, non-chat tools (accuse buttons, vote UI, quick phrases) to work for players without chat access ([[Text Chat Customization with TextChatService]]).

## 2. Round flow

1. **Lobby / intermission** (10 to 20 s): cosmetics, map vote, role chance display.
2. **Role assignment** (server): shown privately to each player for 3 to 5 s.
3. **Grace period**: no kills for the first few seconds while players spread out.
4. **Play**: tasks or survival; murderer hunts; sheriff carries the gun.
5. **Resolution**: win screen showing all roles, the killer's kills, and who shot whom. Revealing everything at the end is how players learn.
6. **Rewards and back to lobby.**

Round state belongs to one server module; reuse the contract in [[Round-Based Minigame Loop End to End]].

## 3. Information control is the core system

**Roles must never replicate to clients that should not know them.**

- Do not store roles in `Team`, attributes on characters, `leaderstats`, `StringValue`s in workspace or names of tools that are visible to everyone. Exploiters read anything replicated.
- Send each player only their own role via `RemoteEvent:FireClient`. Teammates in team-based variants get each other's ids only.
- **Tools reveal roles.** A player's `Backpack` lives under the `Player` object, and its tools are visible to other clients (Unverified as a guarantee, but exploit scripts for this genre are reported to read backpacks, so assume it). Keep the role tool in `ServerStorage` and give it to the character only when the role holder asks to equip it through a validated remote; once equipped it is visible by design.
- **Sounds, animations and particles** can leak roles if played at round start for the role holder only but replicated. Trigger role-specific effects on the role holder's client only.
- **Spectators and dead players** must not pass information to the living: separate dead chat channel, and a spectator camera that does not reveal the killer's identity before the end (or accept leakage as part of design).

```lua
--!strict
-- Server: assign roles and tell each player only what they may know.
local RoleRemote = game:GetService("ReplicatedStorage").Remotes.Role :: RemoteEvent
local roles: {[Player]: string} = {}

local function assignRoles(players: {Player}, rng: Random)
	table.clear(roles)
	local shuffled = table.clone(players)
	for i = #shuffled, 2, -1 do
		local j = rng:NextInteger(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	for i, p in shuffled do
		roles[p] = if i == 1 then "Murderer" elseif i == 2 then "Sheriff" else "Innocent"
	end
	for p, role in roles do
		RoleRemote:FireClient(p, role)
	end
end
```

Use a server-side `Random` without a client-visible seed. If you sell "murderer chance" boosts, the boost changes weights on the server and the displayed chance must match the real weight; consider whether paid role chance is a fairness problem before selling it.

## 4. Anti-teaming and griefing

Friends joining the same server and telling each other roles over Discord or voice is the genre's chronic problem.

- **Reward structure**: innocents who survive get modest rewards; the killer's rewards come from kills. Teaming reduces fun for everyone else; make the incentive small.
- **Map voting and spawn spreading** so friends are not adjacent at start.
- **Party-aware role assignment** (rule of thumb): avoid assigning killer and sheriff to two members of the same party where you can detect parties (players who joined together via follow or invite).
- **False accusations and kill-stealing**: sheriff who shoots an innocent loses the gun and is penalised.
- **AFK players** are removed from the role pool after an idle check.
- Reporting and blocking tools left intact.

## 5. Readability without chat

- Clear role reveal screen with one-line goal.
- Body discovery cues (sound, marker) for innocents.
- Directional audio for footsteps and knife throws ([[Spatial Audio and Mixing]]).
- Visible gun pickup when the sheriff dies: the "hero" moment.

## 6. Maps

- Small to mid maps with loops, not dead ends; line-of-sight breakers for the killer; vents or shortcuts optional.
- Light enough for phones at low graphics ([[Genre Playbook - Horror and Story]] has phone darkness rules).
- Rotation of several maps keeps rounds fresh; vote on the last few.

## 7. Monetisation

- Cosmetic weapons (knife and gun skins), effects on kill, emotes. In MM2-style games, cosmetic weapons and their trading economy are the main business ([[Player-Driven Trading Economies]]).
- If cosmetics come from crates bought with Robux, disclose odds and gate with `PolicyService`; trading of paid items is also policy-gated ([[Regional Compliance - Paid Random Items and Country Rules]]).
- Avoid selling gameplay advantages (radar, longer knife throw).

## Common mistakes

- **Roles stored where clients can read them.**
- **Role-specific effects replicated** at round start.
- **No grace period**: instant kills at spawn.
- **Dead players chatting with the living.**
- **Discussion games that need chat** for an audience that often cannot chat.
- **Paid role chance** that is not disclosed accurately.

## Checklist

- [ ] Roles only sent privately; nothing role-revealing replicated.
- [ ] Round state in one server module with grace period and clear end reveal.
- [ ] Dead and spectator information separated.
- [ ] Anti-teaming: spawn spread, party-aware assignment, small survival rewards.
- [ ] Works without chat; quick-phrase tools for discussion variants.
- [ ] Cosmetic store; crates and trading policy-gated.

## See also

- [[Case Study - Murder Mystery 2]]
- [[Genre Playbook - Party and Minigame Collections]]
- [[Round-Based Minigame Loop End to End]]
- [[Text Chat Customization with TextChatService]]
- [[How Exploits Work - The Client Boundary]]

## Connected notes

[[Social Design and Multiplayer Play]] · [[Player-Driven Trading Economies]] · Spawn Points Safe Zones and Respawn Flow · Voice Chat and Safety Features

<!-- related:start -->
## Related
[[Case Study - Forsaken]] · [[Genre Playbook - Roleplay and Social Hangouts]] · [[Genre Playbook - Zombie and Wave Survival Co-op]] · [[Genre Playbook - Battle Royale]] · [[Genre Playbook - Shooters FPS and TPS]] · [[Genre Playbook - Tower Defense]] · [[Genre Playbook - Sports]] · [[Genre Playbook - Naval and Open-Sea Adventure]] · [[Genre Playbook - Open-World City and Crime Roleplay]]
<!-- related:end -->
