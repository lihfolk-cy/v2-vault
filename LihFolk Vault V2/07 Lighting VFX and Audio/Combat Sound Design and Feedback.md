---
tags: [audio, combat, sound-design, feedback, networking, mixing, game-feel, type/guide, area/vfx, level/intermediate, area/audio, api/Sound]
---
# Combat Sound Design and Feedback

<!-- tldr:start -->
> [!tldr] TL;DR
> - Hits feel mushy online, fine in Studio: Impact played on server confirmation -> Predict the neutral contact on the attacker's client
> - False "you got hit": Hurt sound predicted -> Hurt only on server damage events
> - Crits do not feel special: Crit is just a louder hit -> A tonal sting above the impact's range
> - Outcome matrix written: each outcome distinct in spectrum and envelope.
> - Neutral contact predicted on the attacker; meaning waits for the server.
> - Kill and hurt confirms 2D and personal; never predicted.
>
> Cost: TL;DR ~170 tok · whole note ~5.7k tok. Read more: ## 3. Who plays what, and when: the network problem · ## 6. Priority, voice limits and stealing · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Sound Design for Games]] covers the general craft: layering, landing the peak on the beat, variation bags, weapon voices and cue rate limits. This note goes deeper into the one place where sound is gameplay, not decoration: combat. It covers what each combat **outcome** should sound like and why, the network question nobody asks until it hurts (who plays which sound, and when, on a 120 ms connection), how hit-stop and sound interact, telegraphs that players can actually react to, priority and voice stealing when twenty enemies die at once, ducking the rest of the mix around impacts, and a test protocol.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project** (one live action game with hundreds of weapons and dozens of enemy types), **rule of thumb**.

---

## 1. Sound is the combat feedback channel

In a fight the player's eyes are busy: on their character, the enemy's wind-up, the health bar, the effects. Sound arrives through a channel that is not busy, works off-screen, and is processed fast. That gives it three jobs in combat, in priority order:

1. **Confirm outcomes.** Did I hit? Was it a crit? Was I blocked? Did it die? The player should be able to fight with their eyes half closed and still know.
2. **Warn.** Something is about to hit me, from that direction, this soon.
3. **Convey weight and identity.** This is a heavy weapon; this is a fire enemy; this is my ultimate.

Most combat audio work goes into job 3 because it is the fun part. Most combat audio *problems* are in jobs 1 and 2: outcomes that sound the same, confirmations that arrive late, warnings drowned by impact noise. Design them first.

---

## 2. The outcome matrix

Every distinct outcome needs a distinct sound, and the distinctions must survive a busy mix. Write the matrix before you pick a single file.

| Outcome | What the player must feel | Sound treatment (rule of thumb) | Priority |
|---|---|---|---|
| **Whiff (miss)** | Nothing connected | Swing only: air layer, no transient body. Never a "fail" sting for a normal miss | Low |
| **Hit** | Contact | Swing plus a short transient (flesh, armour or element by target), 60 to 150 ms long | Medium |
| **Heavy hit / finisher** | Contact with weight | Hit plus a low sub layer and a longer tail; the extra layer, not more volume | Medium-high |
| **Critical / weak point** | Bonus | Hit plus a bright, *tonal* sting (a ring, a chime) above the impact's frequency range | High |
| **Blocked** | Contact, no damage | Hard metallic or wooden clack, dry, no flesh layer, no tail | High |
| **Parried / countered** | Timing success | A distinct ring with a rising pitch, plus a short hit-stop | High |
| **Immune / armoured** | Your damage did nothing | A dull thud with a high-cut filter: "muffled" reads as "no effect" | Medium |
| **Shield break** | State change | Glass or crystal shatter, louder than a hit, once | High |
| **Kill** | Reward | A short tonal confirm on top of the final hit, 2D for the killer only | Highest for the killer |
| **Player hurt** | Danger | A low, dry thump plus a short vocal or cloth layer, 2D | Highest |
| **Low health** | Urgency | A filtered heartbeat bed or a low-pass on the whole mix, fading in under about 25 percent health | Bed |

Rules that make the matrix work:

- **Separate by spectrum and envelope, not just loudness.** A crit sting is tonal and high; a block is dry and mid; a hurt thump is low. Two outcomes that differ only in volume are one outcome once compression and distance are applied.
- **Kill and hurt confirms are 2D and personal.** Everyone hears the 3D impact at the enemy; only the killer hears the kill confirm, at full clarity, regardless of distance.
- **Escalate with layers, not decibels.** A damage number that is 10 times higher should add a layer (sub, tail, sting), not be 10 times louder. Loudness is a shared, limited resource; layers are not.
- **Combos can climb.** Raising the hit transient's pitch by about one semitone per combo step (a factor of about 1.059), capped at four or five steps, makes a combo feel like it is building. Reset on a gap longer than the combo window.

The reference project's enemy sound kit added an element "sting" on every hit (fire, ice, lightning, void, glitch, rock, magic) and gave each enemy family its own hurt and death takes. That is the identity layer; the outcome layers sit on top.

---

## 3. Who plays what, and when: the network problem

On Roblox the server is authoritative for damage ([[Server Authority and Validation]]). A naive implementation plays the impact sound when the client receives "damage happened" from the server. At 120 ms round trip that impact arrives one RTT plus a frame after the swing connects on screen, and it feels mushy. Human tolerance for audio arriving after the visual event is small: rule of thumb, delays beyond about 50 to 100 ms start to feel disconnected for sharp impacts.

The answer is to split each outcome by who knows it first:

| Sound | Played by | When | Why |
|---|---|---|---|
| Swing / wind-up | Attacker's client | At input (or the animation marker) | Pure local cosmetic; no reason to wait |
| Predicted impact | Attacker's client | When its own hit test touches a target | Instant feel. Uses the generic hit layer only |
| Outcome layers (crit, block, immune, shield break) | Attacker's client | When the server's result arrives | Only the server knows; arriving 100 ms after the contact sound is fine because the contact already "landed" |
| Kill confirm | Attacker's client | On server confirmation | A reward can lag slightly; a false kill confirm cannot be taken back |
| Impact heard by others | Other clients | When the server's event arrives | They did not see the contact early either, so there is no mismatch |
| Player hurt | Victim's client | On server damage event | Must never be predicted: a false "you got hit" is worse than a late one |

### What happens when prediction is wrong

The attacker's client says "hit", plays the contact transient, and the server rejects it (target was already dead, out of range after lag, invulnerable). Options:

- **Do nothing extra.** The player heard a contact and saw no damage number. Slightly misleading, rarely noticed. This is the usual choice.
- **Play nothing predicted for blocks and immunity.** Only the neutral contact is predicted; anything that carries meaning waits for the server.
- **Never play a "correction" sound.** A "miss" sting 150 ms after a contact sound is worse than silence.

What never to predict: kills, crits, damage to the local player, currency or loot rewards. These are facts, and the player will remember a false one. The client prediction of hits itself is covered in [[Hitboxes and Hit Detection]] and [[Combat Systems Architecture]].

### Sending the outcome cheaply

One server event per hit, sent to the attacker with the outcome as a small enum, is enough. Others get a combined "impact at position, kind, intensity" event. Batch per frame in big fights (a single remote with an array) and consider an `UnreliableRemoteEvent` for onlooker impacts, which are cosmetic and replaceable; a dropped onlooker sound is invisible. See [[RemoteEvents RemoteFunctions and Unreliable Remotes]].

```lua
--!strict
-- Shared enum for combat outcomes, sent as a small number.
local Outcome = {
	Hit = 1,
	Heavy = 2,
	Crit = 3,
	Blocked = 4,
	Parried = 5,
	Immune = 6,
	ShieldBreak = 7,
	Kill = 8,
}
return Outcome
```

---

## 4. Hit-stop and sound

Hit-stop (freezing or slowing both fighters for a few frames on a strong hit) is one of the strongest weight cues in combat; see [[Hit Reactions Stagger and Hit-Stop]]. Its interaction with sound has three rules:

1. **The impact plays at the start of the stop, not after it.** The stop is the "frame" in which the impact happens; sound landing after the freeze ends feels like a second hit.
2. **Sound does not freeze.** Animation freezes; the impact transient and its tail run in real time. Pausing a sound for the stop and resuming it produces an audible glitch.
3. **Longer stops earn heavier tails.** A 40 ms stop pairs with a short transient. A 120 ms stop on a finisher pairs with a sub layer whose decay fills the stop. Silence during a long freeze reads as a bug.

The reference project tied all of this to the same animation markers that drove damage, effects and hit-stop, so the impact sound, the flash frame and the freeze were scheduled from one time. Audio and effects "key off the swing's hit time" was the rule, and every sound was started early by its measured onset and peak (sounds started about 15 ms before their measured onset; peaks scheduled onto the beat). See [[Markers and Events]] and [[VFX Timing with Animation]].

---

## 5. Telegraphs players can react to

A warning sound is only useful if it arrives early enough to act on. Rule of thumb budget:

| Phase | Time |
|---|---|
| Hearing and recognising a learned cue | about 0.2 to 0.3 s |
| Deciding and pressing dodge | about 0.15 to 0.25 s |
| Input to server, dodge state active | your latency plus a frame |
| **Total lead needed** | **about 0.5 to 0.8 s** for a normal attack; more for new players and new enemies |

The reference project's meteor hazard played its incoming whoosh 0.75 s before impact, then the explosion, which sits right in that window. Its weather lightning used a 1.5 s ring telegraph for big damage.

Telegraph design rules:

- **Same danger, same sound, everywhere.** Players learn "that rising whine means jump" once. A different whine per enemy throws that learning away.
- **Rising pitch or rising volume for "soon".** A cue that builds tells the player *when*, not just *that*.
- **Spatial, but with a 2D floor.** Play the wind-up 3D at the attacker so direction is audible, but give boss telegraphs a small 2D layer as well so they are never lost to attenuation when the boss is huge and the emitter is at its centre.
- **Visual twin always.** Every warning sound has a visual cue for players without sound ([[Accessibility]]).
- **Protect telegraphs in the mix.** Duck impacts slightly under telegraphs, not the other way round. The player can afford to miss a hit sound; they cannot afford to miss a warning.

---

## 6. Priority, voice limits and stealing

A twenty-enemy pull with five players produces hundreds of sound requests per second. Without control you get clipping, comb filtering (the same file layered on itself sounds thin and phasey) and CPU cost. [[Spatial Audio and Mixing]] covers throttles in general; for combat you need **priority-based stealing**: when the voice budget is full, a new important sound replaces the least important live one.

The reference project's effect audio layer capped live one-shots at 24 with per-key minimum gaps, and onlookers heard support ability sounds at 0.7 times volume. A priority scheme on top of a cap:

```lua
--!strict
-- CombatVoices: a capped pool of 3D one-shots with priority stealing and per-key gaps.
local SoundService = game:GetService("SoundService")

export type Cue = {
	key: string,          -- e.g. "hit_flesh"; used for gaps and repeats
	soundId: string,
	priority: number,     -- 1 low ... 5 highest (kill, hurt)
	volume: number,
	gap: number?,         -- minimum seconds between two plays of this key
}

type Voice = { sound: Sound, holder: Attachment, priority: number, endsAt: number }

local MAX_VOICES = 24
local voices: { Voice } = {}
local lastPlayed: { [string]: number } = {}

local bus = Instance.new("SoundGroup")
bus.Name = "CombatSFX"
bus.Parent = SoundService

local function newVoice(): Voice
	local holder = Instance.new("Attachment")
	holder.Parent = workspace.Terrain -- an attachment on Terrain can be positioned freely
	local sound = Instance.new("Sound")
	sound.SoundGroup = bus
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 150
	sound.Parent = holder
	return { sound = sound, holder = holder, priority = 0, endsAt = 0 }
end

local function pickVoice(priority: number, now: number): Voice?
	-- Free voice first.
	for _, v in voices do
		if v.endsAt <= now then
			return v
		end
	end
	if #voices < MAX_VOICES then
		local v = newVoice()
		table.insert(voices, v)
		return v
	end
	-- Steal the lowest-priority voice, oldest first, if it is below the new sound.
	local victim: Voice? = nil
	for _, v in voices do
		if v.priority < priority and (victim == nil or v.priority < victim.priority
			or (v.priority == victim.priority and v.endsAt < victim.endsAt)) then
			victim = v
		end
	end
	return victim
end

local CombatVoices = {}

function CombatVoices.play(cue: Cue, position: Vector3, pitch: number?): boolean
	local now = os.clock()
	local gap = cue.gap or 0.03
	if now - (lastPlayed[cue.key] or -math.huge) < gap then
		return false -- the same key just played: a second copy only adds phasing
	end
	local v = pickVoice(cue.priority, now)
	if not v then
		return false
	end
	lastPlayed[cue.key] = now
	local s = v.sound
	s:Stop()
	s.SoundId = cue.soundId
	s.Volume = cue.volume
	s.PlaybackSpeed = pitch or 1
	v.holder.WorldPosition = position
	v.priority = cue.priority
	-- TimeLength is 0 until loaded; assume a short one-shot in that case.
	local length = if s.TimeLength > 0 then s.TimeLength / s.PlaybackSpeed else 1
	v.endsAt = now + length
	s:Play()
	return true
end

return CombatVoices
```

Notes:

- **Per-key gaps** (about 30 ms here) stop the "twenty identical hits in one frame" problem. Twenty enemies hit by one sweep produce one or two transients plus the variety of different keys, which sounds bigger than twenty copies of one file.
- **Steal low, never high.** A kill confirm or hurt thump (priority 5) can steal a far enemy's footstep (1); nothing steals a hurt thump.
- **Changing `SoundId` on a pooled sound** means the new asset must load. Preload combat sounds at spawn with `ContentProvider:PreloadAsync` so the first hit is not silent. Freshly uploaded assets can fail to preload for a short while (about 20 to 60 s, measured in the reference project); never judge a new sound broken in the first minute.
- With the newer Audio API you would pool `AudioPlayer` plus `AudioEmitter` pairs instead; the stealing logic is the same. See [[The Audio API - Players Emitters Wires and Effects]].

---

## 7. Ducking around impacts

Big impacts need space. Ducking lowers ambience and music briefly when combat sounds play, so a hit sounds big without being loud. With the Audio API, a compressor whose **Sidechain** pin is fed by the combat bus does this automatically: the music only compresses when combat sound is present. The docs' `AudioCompressor` sample wires an explosion to the `"Sidechain"` target pin in exactly this way.

```lua
--!strict
-- Sidechain ducking: music and ambience compress when the combat bus is active.
-- Chain: musicFader -> compressor(Input) -> output ; combatFader -> compressor(Sidechain) and -> output.
local SoundService = game:GetService("SoundService")

local function wire(source: Instance, target: Instance, targetPin: string?): Wire
	local w = Instance.new("Wire")
	w.SourceInstance = source
	w.TargetInstance = target
	if targetPin then
		w.TargetName = targetPin
	end
	w.Parent = target
	return w
end

local output = Instance.new("AudioDeviceOutput")
output.Parent = SoundService

local musicBus = Instance.new("AudioFader")
musicBus.Name = "MusicBus"
musicBus.Parent = SoundService

local combatBus = Instance.new("AudioFader")
combatBus.Name = "CombatBus"
combatBus.Parent = SoundService

local duck = Instance.new("AudioCompressor")
duck.Name = "CombatDuck"
-- Starting values (rule of thumb). The reference page lists these properties without units or ranges;
-- confirm units and sensible values in Studio before relying on them.
duck.Threshold = -30
duck.Ratio = 4
duck.Attack = 0.01
duck.Release = 0.35
duck.Parent = SoundService

wire(musicBus, duck)              -- music into the compressor's main input
wire(combatBus, duck, "Sidechain") -- combat bus drives the gain reduction
wire(duck, output)                -- ducked music out
wire(combatBus, output)           -- combat itself goes straight out
```

Practical numbers (rule of thumb): duck music and ambience by 3 to 6 dB under heavy hits, release over 250 to 500 ms. Faster release "pumps" audibly; slower release leaves the music low through a whole combo, which is sometimes exactly right for a boss fight.

Classic `Sound` objects cannot sidechain. With them, duck by script: on a heavy or kill cue, tween the music `SoundGroup` volume down by about 30 percent over 30 ms and back over 400 ms. That is cruder (it reacts to your code, not to the actual audio) but works.

The reference project's mix rules match the intent even without sidechaining: ambience beds sat well below the wind and effect sounds (beds at an effective RMS of about 0.004 to 0.018), effect one-shots were levelled to a target peak of about 0.1 to 0.25 (big events 0.3), and every sound was measured with `AudioPlayer:GetWaveformAsync` before it went in. Levelling by measurement is the reason the outcome matrix stays distinct: when every file arrives at a different loudness, the loudest file wins, not the most important outcome.

---

## 8. Onlookers, crowds and fairness

- **Your fight first.** Others' combat should be audible but quieter and less detailed: lower volume (the reference project used 0.7 for onlookers on support abilities), no 2D layers, no kill confirms, fewer layers per hit.
- **Distance does the rest.** With roll-off up to about 150 studs, far fights become a rumble, which is what a battlefield should sound like.
- **Large bosses** need more than one emitter: a voice emitter at the head and a footstep emitter at the feet, or the roar sounds like it comes from the floor.
- **Fairness:** a player with sound off must not be at a disadvantage on things that matter. Every telegraph has a visual twin; directional damage has an on-screen indicator.
- **Players mute things.** Expose separate sliders (master, music, combat, ambience, UI). A player who turns combat down because it is too loud has told you the mix is wrong.

---

## 9. Testing combat audio

1. **Blind test.** Have a tester close their eyes; you perform each outcome in random order. They name it. Any two outcomes confused more than once share too much spectrum or envelope.
2. **Latency test.** Play at your normal connection, then with Studio's incoming replication lag set to 0.2 to 0.3 s (Studio's network simulation settings). The contact sound must still feel attached to the swing; outcome stings may trail. If the contact feels late, it is not being predicted. See [[Multi-Client and Live Testing]].
3. **Crowd test.** Pull the largest group your game allows and kill it with an area attack. Listen for clipping, phasing, and whether the kill confirm and hurt sounds still cut through.
4. **Phone speaker test.** Phone speakers have almost no bass. A hurt cue that is all sub-bass is silent on a phone. Every high-priority cue needs content between about 1 and 4 kHz.
5. **Long session test.** Play 15 minutes. Anything that annoys you by minute ten is too frequent or too loud, usually a hit transient with no variation or a low-health bed that never stops.
6. **Silence check.** Turn off sound and play the same fight. Can you still read every danger? If not, add visual twins.

---

## 10. When not to do this

- **Do not predict anything that carries meaning.** Prediction is for the neutral contact only.
- **Do not build a priority voice system for a small game** with a handful of enemies; per-key gaps and a cap are enough.
- **Do not pitch-randomise outcome stings.** Variation is for transients and bodies. A crit sting that changes pitch every time stops being a learned symbol.
- **Do not let music carry combat feedback.** Adaptive combat music is mood ([[Music and Adaptive Audio]]); it changes too slowly to confirm a hit.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Hits feel mushy online, fine in Studio | Impact played on server confirmation | Predict the neutral contact on the attacker's client |
| False "you got hit" | Hurt sound predicted | Hurt only on server damage events |
| Crits do not feel special | Crit is just a louder hit | A tonal sting above the impact's range |
| Big pulls sound thin and harsh | Twenty copies of one file in one frame | Per-key gaps, voice cap, stealing |
| Telegraph missed in a fight | Masked by impacts | Duck impacts under telegraphs; 2D floor on boss cues |
| Hit-stop feels broken | Sound paused or delayed with the freeze | Impact at stop start, sound runs in real time |
| First hit after joining is silent | Sounds not preloaded | Preload at spawn |
| Kill confirm heard by everyone | Played 3D at the enemy | 2D, killer only |
| Hurt cue inaudible on phones | All sub-bass | Add mid-range content |

## Checklist

- [ ] Outcome matrix written: each outcome distinct in spectrum and envelope.
- [ ] Neutral contact predicted on the attacker; meaning waits for the server.
- [ ] Kill and hurt confirms 2D and personal; never predicted.
- [ ] Impact at hit-stop start; sound never frozen.
- [ ] Telegraphs lead by 0.5 s or more, same sound per danger, visual twin.
- [ ] Voice cap with per-key gaps and priority stealing.
- [ ] Music and ambience duck under heavy hits.
- [ ] All combat sounds levelled by measurement and preloaded.
- [ ] Blind, latency, crowd, phone speaker and silence tests passed.

See also: [[Sound Design for Games]], [[Sound Fundamentals]], [[The Audio API - Players Emitters Wires and Effects]], [[Spatial Audio and Mixing]], [[Music and Adaptive Audio]], [[Game Feel and Juice]], [[Hit Reactions Stagger and Hit-Stop]], [[Hitboxes and Hit Detection]], [[Combat Systems Architecture]], [[Markers and Events]], [[Camera Shake and Camera FX]], [[Accessibility]].

## Connected notes
<!-- auto-links:start -->
[[Audio Pipeline]] · Feedback Timing - Sound Visual and Haptic Sync · Captions and Audio Accessibility · Resource Library - Audio · AI Audio - Voice Music and SFX · Links - Music and ambience
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Audio Mixer Settings with SoundGroups]] · [[Feedback Timing - Sound Visual and Haptic Sync]] · [[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Engine and Tyre Audio Driven by RPM and Slip]] · [[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]] · [[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]] · [[VFX Design Playbook]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Music Licensing and Audio Upload Rules for 2026]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]]
<!-- related:end -->
