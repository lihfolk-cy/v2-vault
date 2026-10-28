---
tags: [community, moderation, voice-chat, safety, audio-api, luau]
---
# Voice Chat and Safety Features

Voice turns a game into a place: callouts in a shooter, laughter in a hangout, panic in a horror game. It is also the hardest communication channel to moderate, because speech is fast, ephemeral and hard to filter. This note covers what Roblox controls (eligibility, moderation, reporting), what you control (whether voice is on, who hears whom, how voices sound), the audio API patterns for team, radio and non-spatial voice, and the design work that keeps a voice game fair for the many players who will never use a microphone. It builds on [[The Audio API - Players Emitters Wires and Effects]] (section 7, voice and speech) and [[Age Checks and Safety Features]].

Facts are labelled "Roblox docs (as of October 2026)", "Announcement", or "rule of thumb". Voice eligibility rules changed several times in 2025 and 2026; re-check before shipping.

---

## 1. Safety first

Voice is subject to the Community Standards exactly like text. Things to hold to before any feature work:

- **Roblox decides who can speak and who can hear whom.** Players opt in from their account settings after meeting the eligibility rules (Roblox docs: 13+ and age verified, with ID verification in some countries). Your code never grants voice to anyone, and never tries to detect or infer a player's age from whether they have voice.
- **Your routing can only restrict.** Team voice, radios and rooms decide which eligible players hear each other inside your game. They must not create a way for two players to talk privately where they otherwise could not, and they must not hide players from Roblox's own report and mute tools.
- **No recording.** You cannot and must not capture, store or transmit voice audio. `AudioAnalyzer` exposes levels on the client, never audio data to keep, and its spectrum is empty when any input is an `AudioDeviceInput` (Roblox docs).
- **Private voice spaces need extra thought.** A "private room" that combines voice with seclusion is exactly what the safety guidance warns about for under-18 games: avoid primarily private settings such as bedrooms, and limit adult settings to 18+ (Roblox docs, Safety). A voice-enabled booth with a lock is a red flag; a team radio in a match is not.
- **Never make voice required.** Most players in most servers cannot use it. Section 6 covers design.
- **Watch the Voice channel in the Safety Dashboard** (Creator Dashboard, Safety, Overview). Report rates there are your signal that a voice feature is being abused ([[Player Reports and In-Game Moderation]]).

---

## 2. What the platform does (Roblox docs, as of October 2026)

| Topic | Fact |
|---|---|
| Who can use voice | Users 13+ who are age verified, in a set of supported countries; others can complete ID verification. They opt in once in Settings or from inside a voice game, then voice works in any voice-enabled game |
| Default state | Voice is on by default for eligible users in new games with a maximum of 100 players |
| Server size | Voice only works in places with a maximum of 100 players. Larger places do not support it; lower Maximum Visitor Count and restart servers |
| Enabling | Studio, File, Experience Settings, Communication, Enable Voice Chat (and optionally Enable Camera for face-driven avatar animation), then publish |
| Disabling per place | `VoiceChatService.EnableDefaultVoice` false; publish and restart servers |
| Default behaviour | Proximity voice: loudness depends on distance |
| Audio API | `VoiceChatService.UseAudioApi` set to `Enabled` exposes each voice as an `AudioDeviceInput` you can route |
| Checking a user | `VoiceChatService:IsVoiceEnabledForUserIdAsync(userId)` from client code (a `LocalScript` or a client-run-context script), wrapped in `pcall` |
| Chat groups | `VoiceChatService:GetChatGroupsAsync(players)` and `TextChatService:GetChatGroupsAsync(players)`: players with a matching group id can communicate (Roblox reference) |
| Speech to text | Requires voice chat enabled (Roblox docs) |

The 2026 age-check work (chat groups by age band, the Kids and Select audiences) sits on top of this. Players under 13 do not get voice. Exactly how age-band rules apply to voice between, say, a 16-year-old and an adult was not documented on the developer pages I could check; treat it as Roblox's job and do not design around guesses (unverified, see report).

**Moderation.** Roblox moderates voice under the Community Standards and players can report a voice user through the platform report menu. Roblox has publicly described automated voice safety systems, and it applies consequences such as voice timeouts to accounts (Announcement, earlier years). The specific current thresholds and durations are not published for developers and I could not confirm them for October 2026.

---

## 3. Should your game have voice at all?

A decision table (rule of thumb):

| Game type | Voice? | Why |
|---|---|---|
| Social hangout, roleplay (16+ label) | Often yes | The game is the conversation; still provide non-voice expression |
| Co-op horror, heist, puzzle | Yes, proximity | Proximity creates tension and emergent play |
| Competitive team shooter | Team-only, optional | Team callouts help; cross-team voice invites harassment |
| Simulator, tycoon, idle | Usually no | Little coordination needed; adds moderation surface for nothing |
| Games aimed at Kids and Select | No value | Those audiences cannot use voice |
| Large servers (over 100) | Not possible | Voice does not run above 100 players |

The hidden cost is moderation exposure. A voice game's report rate is higher, and the Safety Dashboard benchmark compares you against other games, not against your own text-only past. If voice does not add a core experience, leave it off.

---

## 4. Routing voices with the audio API

With `UseAudioApi` enabled and default voice on, each player has an `AudioDeviceInput` under their `Player` (Roblox docs). Default setups wire it to an emitter on the character for proximity voice. You can change who hears whom and how it sounds.

### Team-only voice (access lists)

`AudioDeviceInput` has an access list: set `AccessType` to `Allow` and call `SetUserIdAccessList` with the user ids allowed to hear. The docs use this for team voice.

```lua
--!strict
-- Server Script: only teammates hear each other. Reviewed, not run.
local Players = game:GetService("Players")

local function teammateIds(player: Player): { number }
	local ids = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Team ~= nil and other.Team == player.Team then
			table.insert(ids, other.UserId)
		end
	end
	return ids
end

local function refreshAll()
	for _, player in Players:GetPlayers() do
		local input = player:FindFirstChildWhichIsA("AudioDeviceInput")
		if input then
			input.AccessType = Enum.AccessModifierType.Allow
			input:SetUserIdAccessList(teammateIds(player))
		end
	end
end

local function watch(player: Player)
	player:GetPropertyChangedSignal("Team"):Connect(refreshAll)
	player.ChildAdded:Connect(function(child)
		if child:IsA("AudioDeviceInput") then
			refreshAll()
		end
	end)
	refreshAll()
end

Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function()
	task.defer(refreshAll)
end)
for _, p in Players:GetPlayers() do
	watch(p)
end
```

Nuances:
- Refresh on every team change, join and leave. A stale list after a team switch lets a defector hear their old team, which is both a fairness bug and an exploit players will find in a day.
- Spectators: decide explicitly. Usually spectators hear the living but are not heard, so their input gets an empty allow list.
- `refreshAll` is O(n squared) in players. At 100 players that is 10,000 comparisons, run only on changes; fine. Do not call it every frame.

### Radio and effect chains

Route the input through effects before the emitter: an `AudioEqualizer` with low and high bands cut gives a radio; an `AudioReverb` gives a cave. Effects are shared processing nodes; reuse one chain per style, not one per player per frame ([[Spatial Audio and Mixing]]). A walkie-talkie that lets a player be heard map-wide changes the social shape of the game: someone can now speak to strangers far away. Keep it team-scoped.

### Non-spatial voice (everyone equal)

The docs show disabling default voice, creating one `AudioDeviceInput` per player, and wiring them all to a shared `AudioFader` and `AudioDeviceOutput`. They also show a client script that destroys the wires connected to the local player so you do not hear yourself. Use this for small lobbies or tabletop-style games; in a 50-player server it is chaos.

### Mute and loudness controls you add

Players can mute others through the platform UI. Inside your game you can add per-player volume sliders on the client by adjusting your own fader per input. Make them local only. Never offer a "mute for everyone" button to ordinary players; that is a harassment tool against the muted person. Moderator tools are different ([[Player Reports and In-Game Moderation]]).

---

## 5. Server checks and exploit resistance

- Access lists are set on the server. A client can change its local copy of routing objects, but that only affects what it hears, not what others hear (rule of thumb from the replication model; [[Replication Rules]]).
- Do not trust a client claim of "I have voice" for rewards or matchmaking. If you must gate a voice-only room, check eligibility through Roblox's API on the client, then confirm on the server by observing that the player's `AudioDeviceInput` exists and is `Active`. Even then, treat it as a hint, not proof.
- Do not reward talking. "Speak to earn" mechanics push players to make noise, and they are trivially gamed by playing audio into the mic.
- Volume analysis for gameplay (a horror monster that hears you) works on the client only (`AudioAnalyzer` levels are always zero on the server, Roblox docs). It is therefore client-authoritative and spoofable: fine for atmosphere, never for anything competitive.

---

## 6. Designing for the voiceless majority

In a typical all-ages server, most players have no voice: under 13, not verified, in an unsupported country, on a device without a mic, or simply unwilling. Rule-of-thumb patterns:

| Need | Non-voice equivalent |
|---|---|
| Callouts | Ping wheel with fixed meanings ("Enemy", "Go here", "Need help") |
| Coordination | Ready checks, role pickers, objective markers |
| Emotion | Emotes, reactions over the head |
| Proximity drama in horror | Footsteps, breathing, flashlight sounds that the game generates |
| Social presence | Speaking indicators for voice users, and an equal "typing" or emote indicator for others |

Balance check: if a team with voice wins far more often than a team without, your game rewards a feature that young players cannot have. Measure win rate by "fraction of team with voice active" in your analytics ([[Analytics and Funnels]]); if the gap is large, add stronger non-voice coordination.

Matchmaking: the 2026 announcements describe a Text Chat matchmaking signal. A similar voice signal was not confirmed on the pages I checked (unverified). Do not try to sort servers by voice yourself with teleports; you would be inferring eligibility, which is close to inferring age.

---

## 7. Moderation in a voice game

Text tools do not transfer:
- **There is nothing to log.** You never get audio. Your evidence for a voice complaint is the reporter's account, timestamps, who was nearby (from your own position logs), and whether others reported the same user. Usually that is enough only for a server kick, not a ban; leave serious cases to Roblox through the report menu.
- **Make reporting easy.** Show players where the platform report option is (in your help panel or settings). Never hide or cover the Roblox menu button.
- **Moderator presence helps.** Group moderators with the right permissions can remove players from servers and manage bans across group games ([[Groups Roles and Permissions for Studios]]). In a voice-heavy game, a rota of trusted adult moderators during peak hours changes the culture.
- **Rules screen.** A short code-of-conduct panel on first join of a voice game ("Be kind. Do not ask people's age or where they live. Report anyone who makes you uncomfortable.") costs nothing. Keep it readable for a 13-year-old.

---

## 8. Camera and face animation

Enable Camera (Experience Settings, Communication) lets eligible players animate their avatar's face from their camera (Roblox docs). It is processed on the device; you receive animation, not video. It still affects safety: expressive faces in a private space read differently from a battle arena. Leave it off unless your game is social.

---

## 9. Common mistakes

| Mistake | How it shows up |
|---|---|
| Place max players above 100 with voice expected | Voice silently absent; players complain it is "broken" |
| Stale team access lists | Players hear the other team after switching |
| Map-wide radio for everyone | Strangers harass across the map; report rate climbs |
| Voice-only puzzles | Non-voice players stuck; one-star reviews from parents |
| Rewards for speaking | Noise, mic spam, recordings played into mics |
| Own "mute everyone" button | Used to bully a specific player |
| Private voice booths in an under-18 game | Safety Dashboard Voice channel spikes; possible moderation of the game |

---

## 10. Checklist

- [ ] Voice adds a core experience; otherwise disabled
- [ ] Place max players at or below 100 if voice is on
- [ ] Routing restricts only; nothing creates private channels between strangers
- [ ] Access lists refreshed on join, leave and team change
- [ ] Every voice mechanic has a non-voice equivalent; win rate checked
- [ ] No rewards for talking; no server trust in voice analysis
- [ ] Report path visible; moderators know voice evidence limits
- [ ] Safety Dashboard Voice channel reviewed weekly

## See also
[[Community and Moderation Start Here]] · [[Text Chat Customization with TextChatService]] · [[Player Reports and In-Game Moderation]] · [[The Audio API - Players Emitters Wires and Effects]] · [[Spatial Audio and Mixing]] · [[Age Checks and Safety Features]] · [[Social Design and Multiplayer Play]] · [[Roblox Policies Ratings and Compliance]] · [[Genre Playbook - Horror and Story]]

## Connected notes
<!-- auto-links:start -->
[[Captions and Audio Accessibility]] · [[AI Audio - Voice Music and SFX]] · [[Discord Servers for Roblox Games]] · [[Community Building]] · [[Publishing an Experience]] · [[Roblox Policies on AI-Generated Content]]
<!-- auto-links:end -->
