---
name: lihfolk-sfx
description: 'LihFolk combat and UI sound effects (licensed sounds only, pooled layered Luau module). Use for "sfx", "swing/hit/impact sound", "footsteps", "UI click", "sounds are repetitive", "hits feel late".'
---

# LihFolk SFX: premium, licensed, layered, on the beat

One client Luau module, a preset table matched to `lihfolk-vfx`, and a sourcing workflow that only accepts
high-quality sounds with a licence you can show. No procedurally generated placeholders and no free
"sound dump" sites. Distilled from the vault notes named below (titles in
`LihFolk Vault V2/07 Lighting VFX and Audio/` unless another folder is given).

## Rules
- **Never invent an asset id.** A take is `rbxassetid://REPLACE_ME` until it holds an id that either came back
  from a Creator Store search in this session (Studio MCP `search_asset` or the user's Toolbox) or was given by the
  user. The module skips placeholders with one warning per name. Old third-party ids usually do not play (audio
  privacy): replace them, do not reuse them by name (Field Notes: Sound Design Pitfalls - Reused Ids Onsets and Layered Loops).
- **Licensed premium sources only** (table below). Every real id gets a `source` line in its layer and in the
  project's audio manifest: where it came from, the licence, who uploaded it, the date. The module warns once
  about a layer that has real ids and no `source`.
- **The AI never downloads sound files.** The user downloads from libraries they licence, edits, and uploads.
  Raw library files never go into a repo, a plugin, a model file or a public place.
- **Cosmetic sounds play on the client.** Your swing, your predicted contact, UI, footsteps: local. Other players'
  actions: each client plays them from the same replicated event or animation marker that drives their VFX, at
  about 0.7x. Server-played sounds replicate to everyone and arrive a round trip late (Sound Fundamentals).
- **Predict only the neutral contact.** Crit, block, kill, loot and player-hurt sounds wait for the server; a false
  "you got hit" is worse than a late one. Kill and hurt confirms are 2D for that one player (Combat Sound Design and Feedback).
- **Every sound has a bus.** A Sound with `SoundGroup = nil` ignores the volume sliders (58 Player QoL: Audio Mixer Settings with SoundGroups).
- **Every information-bearing sound has a visual twin** (telegraphs, off-screen threats) and, where it changes what
  the player does, a caption. Ambient beds, UI clicks and footsteps are not captioned (42 Accessibility: Captions and Audio Accessibility).

## Where sounds come from (checked 2026-10-29)

Not legal advice: these are short facts read from each official page on the date shown. Re-read the licence
that comes with the actual purchase before shipping, and ask the vendor in writing when a use is unclear.

| Source | Tier | Cost | Commercial game use | Upload to Roblox | Attribution | Official page |
|---|---|---|---|---|---|---|
| **Roblox Creator Store, Roblox-licensed audio** (first choice) | Professional partner catalogue; Roblox says 100,000+ professionally produced SFX and music tracks from audio and music partners (the 2024 SFX announcement names APM Music and Monstercat as Roblox-provided audio) | Free | Yes, inside Roblox experiences | Nothing to upload: use the existing asset id | None stated | https://create.roblox.com/docs/audio/assets ; https://devforum.roblox.com/t/public-sound-effects-upload-are-now-available-for-creators/2980704 |
| **Sonniss GameAudioGDC bundles** | Professional library content, the same files Sonniss sells | Free (GDC 2026 bundle about 7.5 GB; archive of earlier years) | Yes: worldwide, royalty-free, unlimited projects, games named | Yes, as part of your game (private asset) | Not required | https://gdc.sonniss.com ; https://sonniss.com/gameaudiogdc ; licence v2.0 (effective 2026-08-27): https://sonniss.com/gdc-bundle-license/ |
| **BOOM Library** | Top tier (designed and construction-kit libraries) | Paid per library; single-user EULA, separate multi-user (team) licence | Yes: video games named as a permitted production; no extra fees | Yes, as part of your game (private asset) | Not required for synced use | https://www.boomlibrary.com/support/faq/what-am-i-allowed-to-do-with-your-sounds/ ; terms: https://www.boomlibrary.com/terms-conditions-regular/ |
| **A Sound Effect** (marketplace of independent and pro libraries) | High; varies by library, so vet each pack | Paid per library; seats = licences on the invoice | Yes: video games and mobile apps named; perpetual, royalty-free | Yes, as part of your game (private asset) | Not mentioned in the EULA | https://asoundeffect.com/license-agreement (EULA, last modified 2026-10-17) |
| **Soundly** (Pro subscription catalogue) | High (pro catalogue plus add-on libraries) | Subscription | Yes: video games named in the synchronisation grant | Yes, as part of your game (private asset) | Not required by the SFX licence | https://getsoundly.com/assets/Soundly-EULA.pdf (SFX licence dated 2024-11-04) |
| **Splice Sounds** | Mid to high; music-production oriented, SFX packs vary, so vet each one | Subscription (Creator 19.99 USD/month after the first month; Sounds 12.99 USD/month billed yearly, on 2026-10-29) | Yes: video games named; royalty-free and perpetual for what you downloaded | Yes, as part of your game (private asset) | Not required | https://intercom.help/splice-b7a2d5b83f2e/en/articles/8652642-splice-sounds-licensing-faq ; https://splice.com/terms |

Conditions that apply to all of them:
- **Redistribution ban (every vendor).** You may not pass the sounds on as sounds: no sample packs, sound libraries,
  stems, raw or processed files, in whole or part, edited or not (Sonniss says redesigned sounds stay licensed
  material). So raw files never go in a public repo, a plugin, a free model or a shared place file.
- **Roblox uploads stay private.** None of the vendor licences names Roblox. A private asset that only your
  experience plays is the sound used inside your game. Never tick "Distribute on Creator Store" for a library
  sound: that hands the standalone sound to every creator, which each licence forbids. Upload under the
  experience owner (the group for group games).
- **Soundly:** after the subscription ends, released versions stay licensed but a new major version of the game may
  not use Soundly sounds. Roblox games are live, so either keep the subscription for the game's life or prefer a
  perpetual purchase (BOOM, A Sound Effect, Sonniss). Its Freesound add-on is excluded from the Soundly licence:
  do not use it.
- **Splice:** keep the certified licence it can generate per sample, in case a copyright claim needs proof.
- **AI training** with the sounds is forbidden by Sonniss, A Sound Effect and Soundly.

Dropped (terms not confirmable for a commercial Roblox game on 2026-10-29): **Epidemic Sound** (its official terms
page did not load; what was found describes online-content use and a separate business route for apps),
**Artlist** (its licence does not name games and bars using assets as separate files), **ZapSplat** (its licence
page refused access; the free tier needs attribution and its quality is mixed, which this skill does not accept).
Community uploads in the Creator Store are allowed by Roblox but their rights chain cannot be checked: use one only
when the user picks it and accepts that.

### Roblox audio upload rules (2026)
From the audio assets docs (https://create.roblox.com/docs/audio/assets, checked 2026-10-29) and Music Licensing and
Audio Upload Rules for 2026:
- `.mp3`, `.ogg`, `.wav` or `.flac`; under 20 MB and 7 minutes; 48 kHz or lower; mono or stereo (also 3.0 and 5.1).
- Monthly import caps: 2,000 per 30 days for ID-verified accounts, 100 for unverified ones. Re-check before a big batch.
- Private by default; grant use per experience. A personal upload in a group game is silent live; upload to the group.
- The uploader must hold the rights. Takedowns fail silently, so keep the manifest and load-check ids.

## Sourcing workflow

**1. Roblox-licensed Creator Store audio (first choice).** When Studio is connected, the AI can use the Studio MCP
asset search tool `mcp__Roblox_Studio__search_asset`:

```
search_asset { studio_id, scope = "creator_store", assetType = "Audio", query = "sword swing whoosh",
               verifiedCreatorsOnly = true, priceFilter = "free", audioMaxDuration = 3, maxResults = 20 }
```

Keep results whose creator is Roblox (the licensed catalogue); treat anything else as a community upload (see
above). Show the user name, creator, duration and id for each candidate so they can audition it in the Toolbox
(the AI cannot listen); insert a candidate with `insert_asset` only when the user asks, into a scratch folder.
Without Studio, the user searches the Toolbox (Creator Store tab, Audio category, advanced filter for creator and
verification) and pastes ids. Use only ids that came back from the search or from the user, and set
`source = "Creator Store, Roblox-licensed, <asset name>"`. Run the vetting checklist on what you can observe
(duration, variations, dry or wet, onset when measured in Studio).

**2. A premium library the user licences (second choice).** Name the library and the keywords (table below). The
user downloads, runs the editing pipeline, uploads under the experience owner as private assets and pastes the
ids. `source = "<vendor> <pack>, <licence>, uploaded by <group>, <date>"`.

**3. Nothing fits.** Leave the take as `REPLACE_ME`, tell the user which layer is missing and what to search for.
Do not fill it with a synthesised, scraped or unlicensed sound.

## Quality vetting checklist

Reject a candidate that fails any line; most library sounds pass only after the editing pipeline.

| Check | Threshold | Why |
|---|---|---|
| Sample rate | 48 kHz or 44.1 kHz source; never upsampled from lower | Roblox accepts up to 48 kHz; lower rates lose the top end that makes cracks read |
| Clipping | No flat-topped peaks in the source; true peak at or below -1 dBTP after export | A clipped source cannot be fixed by turning it down; lossy encoding can push near-0 dB peaks over |
| Onset | First transient within about 10 ms of the file start after trimming; `peak` set to the measured time | Marker plays start at `peak`, so the crack lands on the frame; 30 ms late fuses, 80 ms reads as lag |
| Dry for 3D | No baked room or hall reverb on positional sounds; any reverb tail decays below -60 dB within 0.3 s for melee | The game supplies distance and space; baked reverb sounds wrong at range and smears combos |
| Loudness | -18 LUFS momentary max (400 ms window), within 1 LU, for every one-shot; UI too | See below |
| Tails | Trimmed where the tail falls below -60 dB, with a fade; melee 0.6 s total or less, explosions 2 s or less | Long tails stack under fast combos and eat voices |
| Variations | At least 3 takes for any sound that plays often (swings, hits, footsteps, clicks, pickups); 4 to 6 for footsteps | Pitch jitter alone cannot hide a single repeated file |
| Channels | Mono for every 3D (positional) sound; stereo only for 2D UI, own-character sweeteners, music, ambience beds | A positional source is a point; mono halves the size and avoids phase problems |
| Character | Matches the family: same weapon material and size across takes, no voice, no music | Mismatched takes break the round-robin illusion |

**Why -18 LUFS.** Roblox does not normalise sound-effect loudness, so if every source file sits at the same
loudness the `volume` value in each layer becomes the whole mix, and swapping a take never changes the balance.
-18 LUFS matches the common loudness reference for mobile and handheld game mixes (Roblox's largest audience is on
phones), and leaves headroom for three or four layers plus other players' sounds before the master clips. Use the
momentary maximum because integrated loudness is gated and unreliable on files shorter than about half a second.
The quiet UI and footstep levels then come from `volume` (0.15 to 0.35), not from quieter files.

## Editing pipeline

Done by the user on their own licensed copies, never on files in the repo.
1. **Import** at the native rate (48 or 44.1 kHz). Keep the original untouched in a private, backed-up library folder.
2. **Trim** the head to just before the transient (leave a few ms), keeping a 30 to 60 ms swell on whooshes and the
   full build on risers. Trim the tail at the -60 dB point.
3. **Fade**: 1 to 2 ms fade in unless the transient starts at the first sample; 10 to 50 ms fade out.
4. **Clean**: high-pass rumble below about 30 to 40 Hz; remove clicks and room noise.
5. **Mono** for 3D sounds: sum to mono and listen for phase cancellation; if it hollows out, keep one channel.
6. **Normalise** to -18 LUFS momentary max with a true-peak limit of -1 dBTP.
7. **Export OGG** (Vorbis, quality 6 or higher), same sample rate, named `<Def>_<layer>_<nn>.ogg`.
8. **Measure** the transient time (seconds) and write it into the layer's `peak`.
9. **Upload** privately under the experience owner; add one manifest line per id (source, licence, uploader, date, peak).

Tools. Free: **Audacity** (Truncate Silence, Fade In/Out, Loudness Normalization, Find Clipping, Plot Spectrum,
OGG export), **ocenaudio**, **Youlean Loudness Meter** (free edition) for LUFS and true peak. Pro: **REAPER** (batch
render with loudness normalise and true-peak limit), **iZotope RX** (de-click, de-noise, de-reverb), **Adobe
Audition** (Match Loudness), **Soundminer** or the Soundly app for library search and metadata.

## Playbook

**Layering.** One file rarely carries an action. Stack layers with different jobs and different frequency
content so they do not mask each other (Sound Design for Games):

| Layer | Job | Sword example |
|---|---|---|
| Transient | the instant: sharp, 5 to 60 ms | slash crack, contact thud |
| Body | weight and character | metallic or air swish |
| Tail | size and space | lower, quieter whoosh 0.1 s later |
| Sweetener (optional) | identity | element sting: ice crackle, zap, ring |

Bigger actions get more layers, not more volume. Keep tails short or combos smear. Premium "designed" sounds often
already contain all three layers: split them in the editor or use the library's construction-kit layers, so each
part keeps its own bag and timing.

**Variation.** Round-robin bags (shuffle, draw without replacement, never the same take twice in a row), pitch
+-3 to 6 % and volume +-1 to 2 dB on transients and bodies. Do **not** randomise tonal stings or a signature cue
(crit, charge riser, kill confirm): they are learned symbols. Combo steps may climb one semitone each (x1.059,
cap 4 to 5 steps). `PlaybackSpeed` changes pitch and length together; for big low creatures pick a lower take or
use a pitch shifter instead of slowing a roar down.

**Timing.** Never early, late by as little as possible: 0 to 30 ms late fuses, 80 ms+ feels like input lag
(47 Game Feel: Feedback Timing - Sound Visual and Haptic Sync). Measure each file's onset and peak once. On a marker
the module starts a layer at its `peak` so the transient lands on the frame (`onBeat`). Swells are part of the
motion: start whooshes on the earlier `TrailOn` marker (or from 0 on `Hit` so their swell covers the 0.11 to 0.13 s
VFX sweep-in) and never trim a swing to its loudest sample. Interrupted moves cancel their scheduled layers.
Hit-stop: the impact plays at the start of the freeze and the sound is never paused.

**Mix.** Bus tree `SoundService > Master > SFX / Music / UI / Ambience` (assign `Sound.SoundGroup`, do not parent
under the group). Sliders map 0..1 to `base * v^2`; a squared curve feels even. Shape of the mix: your own actions
loudest, enemies below, UI far below combat, music and ambience a bed. Duck music and ambience 3 to 6 dB under
heavy hits (release 250 to 500 ms); classic Sounds cannot sidechain, so tween the Music group (Spatial Audio and Mixing).
Level by measurement, not by ear: files at one loudness target, mix with `volume`.

**Spatial vs 2D.** A Sound under a `BasePart` or `Attachment` is positional; anywhere else (SoundService, a GUI)
it is 2D. The listener is the camera, often 15 to 25 studs behind a third-person character, so play **your own**
character's sounds 2D (or with a large min distance) and other players' at their root. Never leave the 10 / 10000
stud defaults on a positional sound. `InverseTapered` fades to zero at max instead of cutting off:

| Preset (`LihFolkSFX.Rolloff`) | Min | Max |
|---|---|---|
| `footstep` | 5 | 50 |
| `melee` | 8 | 100 |
| `ability` | 12 | 200 |
| `explosion` | 30 | 450 |

**Voice limits.** Cap live one-shots (24 on PC, 16 on touch here), give each name a cooldown (30 ms stops twenty
identical hits in one frame) and an instance cap, choke rapid repeats (a new swing stops the last), steal the
lowest priority and never the player's own hit or hurt. Gate by distance: never start what nobody can hear.
Reuse `Sound` instances; a new instance per hit churns memory and may wait on loading. Preload with
`ContentProvider:PreloadAsync` when the owner loads (equip, spawn); freshly uploaded assets can fail to preload for
20 to 60 s.

**Footsteps.** Replace the default `RbxCharacterSounds` (an empty LocalScript of that name in
`StarterPlayerScripts`) and play steps on `Footstep` markers, client-side for every character, one def per
surface material (Custom Character Sounds).

**Accessibility.** Captions for information-bearing sounds via `setCaptionHandler` (with a direction for 3D ones),
a visual twin for every telegraph, separate sliders per bus, and high-priority cues with 1 to 4 kHz content so
they survive phone speakers.

## Classic Sound vs the Audio API

| | Classic `Sound` + `SoundGroup` (this module) | Audio API |
|---|---|---|
| Objects | `Sound`, `SoundGroup`, `SoundEffect` children | `AudioPlayer` -> `Wire` -> `AudioEmitter` (3D) or `AudioFader` -> `AudioDeviceOutput` (2D); `AudioListener` -> output |
| Docs stance | still works everywhere; now "discouraged" | recommended for new work |
| Strengths | every tutorial and existing game; simple; works with no listener setup | real buses (faders), `AudioCompressor` "Sidechain" ducking, custom distance and angle curves (`SetDistanceAttenuation`), sample-accurate `Play(atTime)` on `SoundService:GetMixerTime()`, `AudioInteractionGroup` |
| Gotchas | no sidechain; pitch and speed coupled | 3D is silent without a listener (`SoundService.DefaultListenerLocation` `Camera`/`Character`, or `None` and build your own); `AudioPlayer.Volume` default is 1, not 0.5; pin names must match (`Wire.Connected`) |

Use the classic API for broad compatibility and small games (this module). Choose the Audio API for beat-locked
music and stingers, sidechain ducking, voice chat or directional sources; pool `AudioPlayer` + `AudioEmitter`
pairs the same way and keep the same layering, bag and cap logic (The Audio API - Players Emitters Wires and Effects).

## Preset table: what to search for (pairs with `lihfolk-vfx`)

Keywords per layer for the Creator Store search or a library's search box; they are also each layer's `search`
field in `LihFolkSFX.Defs`. Delays in seconds after the trigger. Prefer construction-kit layers or split designed sounds.

| VFX preset / sequence | Sound def | Transient | Body | Tail / sweetener |
|---|---|---|---|---|
| (any swing, `TrailOn`) | `Swing` (choke) | - | sword swing whoosh light (x3) | - |
| `SlashSweep` | `SlashSweep` | sword slash swipe metal | heavy sword swing whoosh | soft air whoosh @0.12, pitch 0.82-0.9 |
| `CrescentDouble` | `CrescentDouble` | blade slice swipe | fast sword whoosh, second body @0.08 pitch 1.05-1.12 | magic sparkle shimmer @0.05 |
| `OverheadCleave` | `OverheadCleave` | heavy ground impact hit @0.11 (lands in the crack) | heavy weapon swing whoosh low | rock debris crumble @0.17 |
| `ThrustPierce` | `ThrustPierce` (choke) | spear stab whoosh short (peak 0.05) | blade ring shing metal, quiet | body punch impact thump @0.05 |
| `DashTrail` | `DashTrail` | dash launch thump | fast whoosh pass by | wind whoosh tail @0.15 |
| `HitSpark` | `HitSpark` (priority 4, predicted contact) | sword hit impact flesh (x3) | metal hit clang short | impact grit debris small |
| `ChargeUp` | `ChargeUp` (clip start, fixed pitch, captioned) | - | energy charge riser power up | metal ping ting bright (ready glint) @0.95 |
| `IceExplosion` | `IceExplosion` (captioned) | ice impact hit | ice shatter glass break | ice crackle freeze @0.15; cold wind whoosh |
| IceBall cast | `IceBallCharge` / `IceBallRelease` / `IceExplosion` | - / - / see above | ice magic charge / magic projectile whoosh | ice crackle freeze / ice sparkle crackle |
| LightningBall cast | `LightningBallCharge` / `LightningBallRelease` / `LightningExplosion` | - / electric zap spark / thunder crack close lightning strike | electric charge riser + electric buzz hum / magic projectile whoosh / electric zap spark | electric zap spark @0.35 / - / heavy ground impact hit |
| GroundSlam `Impact` | `GroundImpact` | ground slam heavy impact | - | rock debris crumble @0.08 |
| Outcomes (server result) | `Blocked`, `Crit` (2D sting), `Kill` (2D) | sword block parry metal clash / critical hit sting metal ring / kill confirm sting | | |
| Footsteps | `Footstep` (one per surface) | footstep concrete shoe (also grass, wood, metal, sand), 4 to 6 takes | | |
| UI | `UIHover`, `UIClick`, `UIConfirm`, `UIError`, `CoinPickup` | ui hover tick soft / ui button click / ui confirm positive / ui error negative / coin pickup collect | | |

UI sounds form one family: same timbre, short, a pitch ladder (higher for positive, lower for negative). Pick
them from one library pack or one Roblox-licensed set.

Markers (`LihFolkSFX.Maps`): `Default` = `TrailOn` -> Swing, `Hit` "1"/"2"/"dash" -> CrescentDouble, "3" ->
OverheadCleave, "heavy" -> SlashSweep, "thrust" -> ThrustPierce, `DashStart` -> DashTrail, `Impact` "ice" /
"lightning" / other -> IceExplosion / LightningExplosion / GroundImpact, `Deflect` -> Blocked, `Footstep` -> Footstep.
`IceBallCast` and `LightningBallCast` map `ChargeStart` / `Release` / `Impact`.

## Files

| Path | What |
|---|---|
| `src/LihFolkSFX.luau` | the module (`--!strict`, client only, classic Sound API); every take ships as `rbxassetid://REPLACE_ME` |
| `examples/SwordSFXClient.client.luau` | sword combo for every character + a UI click/hover |

## API

```lua
local SFX = require(ReplicatedStorage.LihFolkSFX)
SFX.setupBuses(); SFX.preload()                                -- on spawn/equip
local cancel = SFX.play("HitSpark", targetRoot)                -- BasePart/Attachment (follows) | Vector3 | nil (2D)
SFX.play("CrescentDouble", nil, { pitch = 1.059 ^ comboStep }) -- options: volume, pitch, onBeat, priority
SFX.playUI("UIClick")
SFX.setBusVolume("Music", slider)                              -- 0..1 -> base * v^2 ; buses Master/SFX/Music/UI/Ambience
local unbind = SFX.bindAnimator(animator, SFX.Maps.Default, root, { volume = 0.7, onPlay = { SwordHeavy = "ChargeUp" } })
SFX.bindToTrack(track, SFX.Maps.IceBallCast, root)             -- one track; returns unbind
SFX.register("Parry", { priority = 4, rolloff = "melee", layers = { { ids = { "rbxassetid://REPLACE_ME" },
	search = "sword parry metal clash", volume = 0.5, pitch = NumberRange.new(1) } } }) -- add `source` with the real id
SFX.setCaptionHandler(function(text, position) --[[ show caption + direction arrow ]] end)
SFX.stopAll()
```
Layer fields: `ids`, `search`, `source`, `volume`, `pitch` (NumberRange), `volumeJitter`, `delay`, `peak`, `rolloff`, `group`.
Def fields: `layers`, `group`, `rolloff`, `cooldown`, `maxInstances`, `choke`, `priority` (1 to 5), `caption`.
`Config`: `maxVoices`, `defaultCooldown`, `defaultMaxInstances`, `pitch`, `volumeJitter`, `onlookerVolume`.

## Review before shipping
1. Every real id has a `source` and a manifest line; no library sound is distributed on the Creator Store; no raw
files in the repo. 2. Muted, then eyes closed: does each outcome read? 3. 0.25x speed: the crack lands on the frame.
4. Repeat 50 times: nothing grates. 5. Crowd: 8 players, 20 enemies, no clipping or phasing. 6. Phone speakers:
high-priority cues have 1 to 4 kHz content. 7. Sliders at extremes: nothing important depends on a mutable bus alone.
8. Live server test under the group: no silent ids. Score with `quality-score` (min 8.5).

See also: `lihfolk-vfx` (the matching visuals and marker names), `lihfolk-ui` (settings sliders), `roblox-performance-audit`,
Audio Pipeline (17 Pipelines), Music Licensing and Audio Upload Rules for 2026.
