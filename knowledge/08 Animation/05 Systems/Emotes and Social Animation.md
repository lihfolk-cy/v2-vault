---
tags: [systems, emotes, social, humanoiddescription, networking]
---
# Emotes and Social Animation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Wheel opens but emotes do nothing: `Animate` removed or replaced -> Keep Animate, or play emotes yourself and disable the menu
> - Only arms move during an emote: Locomotion at higher priority than the emote asset -> Play emotes at Action yourself
> - Emote survives into combat: No cancel hooks -> Central `stop()` from every gameplay action
>
> Read more (16 KB note): ## Roblox's built-in emotes · ## A custom emote layer · ## Common mistakes
<!-- tldr:end -->

Social animation is everything a character does for other people rather than for gameplay: emotes, dances, waves, flourishes, synchronised moments, NPCs that acknowledge you. It is low-stakes per clip and high-stakes overall, because it is how players express themselves and what makes a server feel inhabited. This note covers Roblox's built-in emote system (with the APIs checked against the official docs), how to build your own emote layer when you replace locomotion, how emotes interact with weapons and combat, and synchronised social animation.

## Roblox's built-in emotes

Facts from the official documentation (Characters > Emotes, and the `Humanoid`, `HumanoidDescription` and `GuiService` API pages):

- Players trigger emotes from the **emotes menu** (a wheel) or with chat commands such as `/e cheer`. Every user has default emotes (dance, point, cheer and others); more can be bought and equipped from the Marketplace.
- **Open or close the menu from code** with `GuiService:SetEmotesMenuOpen(isOpen: boolean)`, and read its state with `GuiService:GetEmotesMenuOpen()`.
- **Disable the menu** with `StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)`. This does **not** stop chat-command emotes.
- **Stop loading user-owned emotes** with `StarterPlayer.UserEmotesEnabled = false`. This is set in Studio (StarterPlayer > Character), not by scripts.
- **Custom emotes** go into the character's `HumanoidDescription`: `SetEmotes(table)` maps emote names to arrays of asset ids; `SetEquippedEmotes(list)` equips names to the wheel. **Up to 8** can be equipped. They show in the order given, starting at the top of the wheel and going clockwise, with the names as written.
- Other members: `AddEmote(name, assetId)`, `RemoveEmote(name)`, `GetEmotes()`, `GetEquippedEmotes()`, and the events `EmotesChanged` and `EquippedEmotesChanged`.
- **Playing from code**: `Humanoid:PlayEmote(emoteName)` returns `true` if the emote played. The emote must be in the character's `HumanoidDescription`. The current API reference lists `PlayEmote` as **deprecated** in favour of `Humanoid:PlayEmoteAsync(emoteName)`, which yields, returns `true` on success and errors if the emote is not in the description. Use the async version in new code.

```lua
-- LocalScript in StarterPlayer.StarterCharacterScripts (pattern from the official emotes guide).
-- Asset ids below are placeholders: use your own emote assets.
local humanoid = script.Parent:WaitForChild("Humanoid") :: Humanoid
local description = humanoid:WaitForChild("HumanoidDescription") :: HumanoidDescription

description:SetEmotes({
	Salute = { 1234567890 },
	Bow = { 1234567891 },
	Victory = { 1234567892 },
})
description:SetEquippedEmotes({ "Salute", "Bow", "Victory" }) -- wheel order: top, then clockwise

-- Later, e.g. from a button:
local ok, played = pcall(function()
	return humanoid:PlayEmoteAsync("Salute")
end)
if not (ok and played) then
	warn("emote did not play")
end
```

### How emotes are actually played (and why custom controllers break them)

In the stock setup, the default `Animate` script plays the emote animation on the character (it contains a `PlayEmote` handler that `Humanoid:PlayEmote` calls into). This is from the default `Animate` script's source rather than the API reference, so check your copy. The practical consequence:

- **If you delete or heavily replace `Animate`, built-in emotes stop working**, even though the wheel still opens. Either keep `Animate` (the recommended "replace partly" approach in [[Locomotion Systems]]), or reimplement emote playback in your controller and disable the built-in menu.
- **Your own locomotion can bury emotes.** If your locomotion plays at Movement priority and the emote asset was published at a lower priority (Core or Idle), your gait wins and the emote is invisible except for the joints your gait does not key. Check the priority of the emote assets you rely on, or play emotes yourself at a known priority.
- **Moving usually ends an emote** in the stock behaviour (locomotion takes over). If your controller keeps playing its idle under an emote, make sure it is lower priority, not higher.

See [[The Default Animate Script]].

## A custom emote layer

When the game owns locomotion and combat, owning emotes too is often simpler. Design points:

| Decision | Recommendation | Why |
|---|---|---|
| Priority | Action (above locomotion, below swings and abilities) | Any gameplay action overrides it without extra code |
| Full or upper body | Full body standing; upper-body variant for "wave while walking" emotes | Full-body dances on a running character slide |
| Cancel on | Movement input, swing, ability, guard, dash, damage taken, death, cutscene lock | Emotes must never cost a player a dodge |
| Weapon in hand | Hide or sheath the weapon, or allow only weapon emotes | A sword through the face during a dance |
| Loop | Dances loop; gestures are one-shots that end on the idle pose | One-shots must return cleanly |
| Replication | Play on the local Animator; it replicates | No remote needed for the clip itself |
| Ownership | Set an attribute (`Emoting`) | Other controllers step aside (carry, fidgets, flourish) |

```lua
--!strict
-- Minimal custom emote player for the local character.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Emotes = {}
local current: AnimationTrack? = nil
local cancelConn: RBXScriptConnection? = nil

function Emotes.stop(fade: number?)
	if current then current:Stop(fade or 0.2) end
	current = nil
	if cancelConn then cancelConn:Disconnect(); cancelConn = nil end
	local char = Players.LocalPlayer.Character
	if char then char:SetAttribute("Emoting", nil) end
end

function Emotes.play(anim: Animation, looped: boolean)
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not (char and hum and animator) then return end
	-- never during gameplay states
	if char:GetAttribute("KitControl") or char:GetAttribute("GuardingLocal") or char:GetAttribute("Dashing")
		or Players.LocalPlayer:GetAttribute("CutsceneLock") then return end
	Emotes.stop(0.1)
	local t = animator:LoadAnimation(anim)
	t.Priority = Enum.AnimationPriority.Action
	t.Looped = looped
	t:Play(0.2)
	current = t
	char:SetAttribute("Emoting", true)
	t.Stopped:Once(function()
		if current == t then Emotes.stop(0) end
	end)
	-- cancel on movement: MoveDirection is the Humanoid's current input direction
	cancelConn = hum:GetPropertyChangedSignal("MoveDirection"):Connect(function()
		if hum.MoveDirection.Magnitude > 0.1 then Emotes.stop(0.15) end
	end)
end

return Emotes
```

Combat code should call `Emotes.stop()` at the start of every swing, cast, guard and dash, and on damage. One central call beats each system checking the attribute.

## Emote craft notes

Rules of thumb that make emotes read in a crowded server:

- **Silhouette first.** Emotes are seen from 30 to 80 studs away, often from behind. Big arm shapes above the shoulders read; finger gestures do not.
- **Two to eight seconds** for one-shots. Longer gestures get interrupted; shorter ones are missed.
- **No root motion** in emotes. A dance that travels breaks on slopes, collides with walls and desyncs from the Humanoid's root (and the top-level root pose is never applied anyway, see [[How the Animator Really Behaves]]).
- **Feet planted or clearly lifted.** Sliding feet in a dance are more visible than in a walk, because the character is otherwise still.
- **End on the idle pose** (or within a small tolerance) so the hand-back does not snap. The same entry and exit rule as combat clips: last frame within about 75 degrees per joint of the idle.
- **Loops**: first and last keys identical, including tangents, or the loop pops once per cycle.
- **Scale**: author on a rig at your game's character scale; hand positions that clear the head at 1x can intersect it at another body scale.

## Weapons as social expression

In a weapon game, the weapon is the main social object. The reference project (one live action game) treated several systems as social features:

- **Equip flourishes**: every equip is a 3 s show-off that every nearby player sees (server-validated relay, see [[Equip Draw and Flourish Systems]]). It is the most-seen "emote" in the game.
- **Weapon nametag**: the held weapon's name above the player, added explicitly as "the social factor".
- **Ultimates**: a cutscene for the caster, but an onlooker sees the effect and a mild shake, so rare weapons advertise themselves.

The design lesson: if your game has a status object, animate showing it off, and make sure others see it.

## Synchronised social moments

Some moments must look identical on every screen: a shared prize wheel, a group dance, a fireworks show, a door opening for everyone. The pattern:

1. The server writes **one attribute** describing the event and its start time: in the reference project, `"<userId>:<index>:<serial>"` (who triggered it, which result, a serial so a repeat of the same result still fires), plus a server timestamp.
2. Every client plays the **same deterministic animation** from that data: a hub prize wheel spins 5 turns plus the offset to the winning slice in 4.4 s with the same quartic ease as the UI panel, the flapper ticks once per divider, bulbs flash, confetti on stop.
3. A client that arrives late computes `elapsed = GetServerTimeNow() - start` and jumps the animation to that point (or skips it if it is over).

For group dances on characters, the same idea: each participant plays its own clip, and each client sets `TimePosition = (now - t0) % Length` on join so everyone is on the same beat.

```lua
-- Join a synced looping emote: everyone started at server time t0.
local function joinSynced(track: AnimationTrack, t0: number)
	track:Play(0.2)
	if track.Length > 0 then
		local elapsed = workspace:GetServerTimeNow() - t0
		track.TimePosition = elapsed % track.Length
	end
end
```

## NPCs that acknowledge players

Small reactions make a hub feel social at almost no cost. The reference shopkeeper (procedural, through `Motor6D.Transform`): idles by polishing, looking around and flipping a coin; **waves at players within 15 studs**; **turns its head to players within 26 studs**; sleeps beyond 280 studs. A quest-giver portrait's head and waist follow the cursor through Neck and Waist `C0`. See [[Enemy and NPC Animation]] and [[Look-At Aim and Head Tracking]].

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Wheel opens but emotes do nothing | `Animate` removed or replaced | Keep Animate, or play emotes yourself and disable the menu |
| Only arms move during an emote | Locomotion at higher priority than the emote asset | Play emotes at Action yourself |
| Emote survives into combat | No cancel hooks | Central `stop()` from every gameplay action |
| Dance slides across the floor | Root motion or unplanted feet | In-place emotes, planted feet |
| Group dance out of sync for late joiners | Each client starts at 0 | Offset by server time |
| Repeat of the same synced result does nothing | Same attribute value written twice | Include a serial |

See also: [[The Default Animate Script]], [[Locomotion Systems]], [[Equip Draw and Flourish Systems]], [[Replication and Ownership]], [[UI and GUI Animation]].

## Nuances and edge cases

1. **Scale of social animation in big hubs.** In a 50-player hangout, an emote is cheap per player but every client animates every visible dancer. A plaza with 30 people dancing is 30 full-body tracks per viewer, plus any synced effects. That is fine on desktop; on low-end phones, cull emotes on distant characters to idle (beyond about 80 to 100 studs, rule of thumb), or freeze them in a mid pose.
2. **700-player servers and dense crowds.** In very large social servers, streaming already hides most characters. Synced group moments should be scoped to the participants' area, not broadcast to the whole server, or every client receives events it cannot see.
3. **Asset ownership and permissions.** Emotes in the catalog that a player owns can be played through the built-in system. Your own custom emote animations must be owned by the experience owner (user or group), or they silently fail to load for everyone. Paid emote packs belong to the catalog, not your game; you cannot sell catalog emotes inside your experience except through the marketplace systems Roblox provides.
4. **Emotes as an exploit vector.** A client can play any animation it can load on its own character, and it replicates. That includes animations you never intended as emotes (an attack clip played without the attack). Since damage is server-decided, this is mostly a visual nuisance, but it can be used to fake telegraphs in PvP or to mislead in social deduction games. Treat the visual as untrusted; never infer gameplay state from what animation a player shows.
5. **Inappropriate animations.** Players may own catalog emotes that are fine for the platform but clash with your game's tone, or that clip through custom character models. `StarterPlayer.UserEmotesEnabled = false` turns user emotes off entirely; there is no per-emote filter in the built-in system, so a curated custom wheel is the only middle ground.
6. **Body types and custom characters.** Catalog emotes are authored on standard R15 proportions. On a custom StarterCharacter with very different proportions, hands go through heads and feet float. If you ship custom characters, ship your own emotes and disable user emotes.
7. **Console and gamepad.** The built-in wheel works with a gamepad; a custom wheel must too. Map it to a button that is not used in combat, and make sure the wheel releases focus when closed, or the next gameplay input goes to the menu.
8. **Accessibility.** Rapid strobing dance effects (lights, flashes tied to emotes) need the same flashing-effects setting as combat flashes.

## Common mistakes in production

1. **Emote layer that ignores `Humanoid.Sit`.** Symptom: seated players dance on top of the seat pose. Fix: cancel or block emotes while seated, or offer seated variants.
2. **Synced dance using `os.clock`.** Symptom: participants drift apart by seconds. Fix: server time from `GetServerTimeNow`.
3. **Custom emote assets published to a personal account in a group game.** Symptom: emotes play in Studio for the author only. Fix: publish under the group that owns the experience.
4. **No rate limit on emote relays.** Symptom: a spammer triggers synced effects for the whole server. Fix: per-player cooldown on the server relay.
5. **Emote wheel input stuck after close.** Symptom: on gamepad the first attack after closing does nothing. Fix: release `GuiService.SelectedObject` and restore the action binding on close.

## Related decisions

- [[HumanoidDescription and Outfit Systems]]: where emotes are stored on the character and how outfits interact with them.
- [[Bundles Animation Packs and Emotes for Sale]]: selling animation content through the marketplace instead of in game.
- [[Social Design and Multiplayer Play]]: why expressive tools matter for retention in social games.
- [[Genre Playbook - Roleplay and Social Hangouts]]: the genre where emotes are a core feature.
- [[Rate Limiting and Abuse Prevention]]: protecting synced social effects from spam.
- [[Gamepad and Console UX]]: making a custom emote wheel work with a controller.
- [[Avatar Body Types and Scale in Gameplay]]: why catalog emotes break on unusual proportions.
- [[Lobby and Hub Design]]: designing spaces where players gather to emote.
- [[Colour-Blind Safe Design]]: keeping emote-linked effects readable for every player.

## Connected notes
<!-- auto-links:start -->
[[Avatars and UGC Start Here]] · [[Custom Locomotion Controller Design]] · [[Custom Characters and StarterCharacter]] · [[Snippets - Animation Controller Module]] · [[Avatar Context Menus Profiles and Social Surfaces]] · [[AI Animation and Motion from Video]] · [[Animation Start Here]]
<!-- auto-links:end -->
