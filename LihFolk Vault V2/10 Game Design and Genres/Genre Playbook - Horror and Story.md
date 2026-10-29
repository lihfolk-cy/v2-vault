---
tags: [game-design, genre, horror, story, narrative, tension, cutscenes, type/guide, area/design, level/intermediate, api/Atmosphere]
---
# Genre Playbook - Horror and Story

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Constant jump scares -> Build, spike, release
> - Avoid: Omniscient monster -> Senses, memory, search, give up
> - Avoid: Unplayable darkness on phones -> Test at low quality; minimum light
> - Structure chosen (chapter, round, roguelite, survival).
> - Tension curve planned with explicit release beats.
> - Monster rules learnable; signature sound; telegraphs.
>
> Cost: TL;DR ~130 tok · whole note ~3.9k tok. Read more: ## 4. Monster design · ## 10. A tension director (sketch) · ## 12. Common mistakes · ## 13. Checklist
<!-- tldr:end -->

Horror and story games are Roblox's "event" genres: a group of friends enters a chapter, gets chased, screams, and comes out with a story to tell. Story games (escape, break-in, chapter adventures) share the same structure without (or with less) fear. Both are built around **authored moments** rather than systems, which makes them expensive per minute of content and extremely strong at producing clips, word of mouth and co-play. This playbook covers why the genres work on Roblox, tension design, monster design, round and chapter structures, narrative in short sessions, replay value, maturity and safety considerations, and a small "tension director" you can build on.

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production combat game; used for cutscene and onboarding lessons), **Rule of thumb** (most of this note: horror and story design is craft, not platform rules).

---

## 1. Why horror and story work on Roblox

| Trait | Why it fits |
|---|---|
| Played with friends | Fear is social: screaming together is the fun. Discovery counts intentional co-play days (Docs, "Discovery") |
| Clip-friendly | Jump scares and chases are made for videos; players follow creators into games (Docs, "Design for Roblox") |
| Short, complete experiences | A 15 to 30 minute chapter fits a session |
| Low reading needed | Atmosphere, sound and chase need no translation |
| Strong identity | One memorable monster becomes the game's brand |

The risks: content is consumed once, so replay value must be designed; production cost is high (art, lighting, audio, animation); and horror needs care with a young audience.

---

## 2. Structures

| Structure | How it works | Replay driver |
|---|---|---|
| Chapter story | Linear levels with puzzles and set pieces, released episodically | New chapters (content cadence) |
| Round-based monster | One player or an AI is the monster; others escape or survive | Roles, maps, player unpredictability |
| Room roguelite | Procedurally chained rooms, random events, a run ends on death | Randomness, mastery, rare events |
| Survival nights | Hold out until dawn; manage resources | Difficulty modes, unlocks |
| Story with choices | Branching dialogue and endings | Multiple endings, secrets |
| Escape / break-in | Team works through a scripted scenario with roles | Roles, hidden routes, endings |

Pick one structure as the spine. Chapter stories need a content pipeline; roguelites need a strong room generator; round games need balance between roles.

---

## 3. Tension and release

Horror is a rhythm, not a constant. A useful model (rule of thumb, from general horror design):

```
tension
  |            /\                    /\
  |      /\   /  \              /\  /  \
  |     /  \_/    \___     ____/  \/    \___
  |____/              \___/                 \___
  +---------------------------------------------------> time
     build   scare  release  build     chase   release
```

| Phase | Tools | Length (rule of thumb) |
|---|---|---|
| Build | Quiet ambience, distant sounds, flicker, narrowing space, a hint of the monster | 1 to 3 min |
| Spike | Jump scare, monster reveal, chase | 5 to 60 s |
| Release | Safe room, light, music change, a reward, a laugh | 30 s to 2 min |

Rules:
- **Anticipation beats the scare.** A creak, a door left open, footsteps upstairs. The scare that never comes is often scarier than the one that does.
- **Do not spike constantly.** Players acclimatise within minutes; a jump scare every 20 seconds becomes comedy.
- **Release is mandatory.** Safe rooms, checkpoints and light let tension rebuild. Young players especially need a breath.
- **Silence is a tool.** Cut ambient audio before a scare. See [[Music and Adaptive Audio]] and [[Spatial Audio and Mixing]].
- **Light is the main pacing control.** Darkness raises tension; light releases it. See [[Lighting Mood and Time of Day]] and [[Light Sources and Shadows]].

---

## 4. Monster design

The monster is the game's brand and its main mechanic.

| Principle | Why |
|---|---|
| A clear, memorable silhouette | Readable in the dark and in a thumbnail |
| A signature sound | Players should hear it before they see it; sound is fairness |
| Learnable rules | "It hunts by sound", "it cannot see you in lockers", "it hates light": rules make players feel clever |
| Telegraphs before kills | A wind-up, a scream, a light change: deaths should feel earned |
| Escapable | Hiding spots, doors to slam, distractions |
| Varied behaviours | Patrol, investigate, chase, give up; never perfect tracking |

### Fair AI
A monster that always knows where you are is not scary, it is frustrating. Give the AI **senses** (sight cone, hearing radius) and **memory** (last known position that decays), and let it lose the player. Pathfinding to the last known position, then a search pattern, then a return to patrol, is a classic and effective loop. See [[NPC AI and Behaviour]], [[Pathfinding]] and [[Raycasts Shapecasts and Spatial Queries]].

### The monster in multiplayer
- A monster that targets the nearest player punishes the bravest; one that targets the noisiest rewards stealth.
- Keep chase speed slightly **below or equal to** player sprint, with stamina on the player side, so escapes depend on decisions (doors, hiding) rather than raw speed.
- Animate it well; a monster with a stiff walk is not scary. See [[Animating Creatures and Monsters]] and [[Enemy and NPC Animation]].

---

## 5. Group play: death, spectating and revives

In a group horror game, one player dies first. What they do next decides whether they stay.

| Option | Effect |
|---|---|
| Spectate the survivors | Keeps them watching (and screaming) |
| Ghost mode with small interactions | Dead players can knock or point; adds comedy |
| Revive mechanic | Survivors can rescue; creates heroic moments |
| Respawn at the next checkpoint | Best for story chapters with young players |
| Lobby until the round ends | Fine only if rounds are short (under about 5 minutes) |

Rule of thumb: in a chapter game, death should cost at most a minute or two of progress for the group. In a round game, rounds should be short enough that waiting is tolerable.

---

## 6. Narrative in short sessions

Roblox players skip text (Docs, "Onboarding techniques": "Players often skip text"). Story has to survive that.

| Technique | Notes |
|---|---|
| Environmental storytelling | Notes, drawings, blood trails, broken furniture: the room tells the story |
| Short spoken or typed lines | One sentence at a time, never a wall |
| Skippable cutscenes | Always skippable after a moment; the reference project's intro cutscene skipped after 3 s, and was later disabled because 27 s inside the first minute was too long |
| Objectives as story | "Find the fuse" is both a quest and a plot beat; see [[Quests and Objectives]] |
| Characters with one trait | A funny guide, a creepy janitor; memorable over detailed |
| Chapters of 15 to 30 minutes | Fit a session; end on a cliffhanger (the exit hook) |
| Recap on return | "Previously..." one-liner when a player rejoins mid-story |

### Cutscenes
- Lock controls only during the cutscene, never before a player has had control at least once.
- Play cutscenes **for the people involved**, not the whole server, unless it is a shared event. The reference project's ultimates were cinematic for the caster only, with a mild version for onlookers; the same rule applies to story beats in a shared server.
- See [[Cameras and Cutscenes]].

### Group decisions
In multiplayer stories, choices need a rule: majority vote with a timer, first to press, or the party leader. Show who voted what; it creates social moments.

---

## 7. Replay value

| Method | How |
|---|---|
| Randomised rooms or events | Room roguelites: chained rooms from a pool with weighted rare events |
| Multiple endings | Secret routes, choices, collectibles |
| Difficulty modes | Hard mode with changed monster rules |
| Roles | Different starting tools or abilities per player |
| Achievements and badges | "Escape without hiding", "find all notes" |
| Cosmetics earned by play | Skins for flashlights, lockers, characters |
| Rare events | A 1 in 100 spooky event that players tell each other about |

Rare events are especially valuable: they create rumours and videos. Treat their odds like any RNG table (see [[RNG Drops and Luck Systems]]) and, if anything random is ever **sold**, follow the paid-random-item disclosure rules (Docs).

---

## 8. Atmosphere on phones

Horror leans heavily on lighting and audio, and most players are on phones with small speakers and low graphics settings.

- **Test at the lowest graphics quality.** Shadows and fog differ; a scene that is moody on PC can be pitch black or flat grey on a phone. See [[Mobile and Low-End Optimization]].
- **Never make darkness unplayable.** Give a flashlight or ambient minimum; a player who cannot see anything leaves.
- **Sound cues need visual equivalents** for players without audio (subtitles for important sounds, a screen-edge pulse when the monster is near). See [[Accessibility]].
- **Avoid rapid full-screen flashing.** Strobe effects can trigger photosensitive reactions; keep flashes brief, infrequent, and offer a reduced-effects setting. See [[Accessibility]].

---

## 9. Maturity and safety

Roblox experiences carry content maturity labels based on a questionnaire about their content, and some content is not allowed at all. Horror sits close to those lines: intense fear, violence, blood and disturbing themes can each affect the label or be disallowed. Rules change; complete the questionnaire honestly and check the current guidelines in [[Roblox Policies Ratings and Compliance]] before designing gore or very intense content.

Design rules for a young audience (rule of thumb):
- Fear from **suspense and surprise**, not from realistic gore.
- A clear, cartoonish or stylised monster scares without disturbing.
- Always provide an exit: a settings option to reduce jump scares, a lobby that is safe and bright, a way to leave a chapter.
- No real-world hateful or self-harm themes.
- In social horror (players as monsters), prevent harassment: limit what monster players can say or show, and keep reporting available.

---

## 10. A tension director (sketch)

Room roguelites and survival games often use a **director**: a server module that tracks group tension and decides when to spawn threats, so pacing adapts to the players instead of being fixed to the map.

```lua
--!strict
-- ServerScriptService/TensionDirector (ModuleScript)
-- Tension rises with time and danger, falls after scares; the director spawns threats
-- only when tension is low enough to build toward a spike, and forces rest after one.
local TensionDirector = {}

export type Director = {
	tension: number,        -- 0..1
	phase: "Build" | "Spike" | "Release",
	phaseTime: number,
	onSpike: () -> (),      -- spawn monster, trigger scare
	onRelease: () -> (),    -- open safe room, change music
}

local BUILD_RATE = 1 / 120  -- reach full build in about 2 minutes
local SPIKE_MIN = 8         -- seconds a spike lasts at least
local RELEASE_TIME = 45     -- seconds of guaranteed rest

function TensionDirector.new(onSpike: () -> (), onRelease: () -> ()): Director
	return { tension = 0, phase = "Build", phaseTime = 0, onSpike = onSpike, onRelease = onRelease }
end

-- dangerSignal: 0..1 from the game (players near the monster, low health, darkness)
function TensionDirector.step(d: Director, dt: number, dangerSignal: number)
	d.phaseTime += dt
	if d.phase == "Build" then
		d.tension = math.min(1, d.tension + (BUILD_RATE + 0.01 * dangerSignal) * dt)
		-- Spike when built up, with some randomness so it is not predictable.
		if d.tension > 0.7 and math.random() < 0.02 * dt * 60 then
			d.phase, d.phaseTime = "Spike", 0
			d.onSpike()
		end
	elseif d.phase == "Spike" then
		if d.phaseTime > SPIKE_MIN and dangerSignal < 0.2 then
			d.phase, d.phaseTime = "Release", 0
			d.onRelease()
		end
	else -- Release
		d.tension = math.max(0, d.tension - dt / RELEASE_TIME)
		if d.phaseTime >= RELEASE_TIME then
			d.phase, d.phaseTime = "Build", 0
		end
	end
end

return TensionDirector
```

Call `step` from one server loop (for example once a second with `dt = 1`). Feed `dangerSignal` from the game state. Tune the rates in playtests with groups, not solo; groups are louder, braver and slower.

---

## 11. Monetisation

| Product | Notes |
|---|---|
| Cosmetics (skins, flashlights, emotes) | The safest and most common |
| Revives | Acceptable if free revives exist through play |
| Chapter access | Paid chapters work only if the free content is substantial |
| Private servers | Popular for friend groups; keep cheap (Docs advise against high private server prices) |
| Hints or skips | Fine for puzzles; never sell escape from a fear the game itself caused in a manipulative way |

Do not use fear to push purchases ("buy a revive NOW" during a chase with a countdown). See [[Ethical Design and Player Trust]].

---

## 12. Common mistakes

| Mistake | Better |
|---|---|
| Constant jump scares | Build, spike, release |
| Omniscient monster | Senses, memory, search, give up |
| Unplayable darkness on phones | Test at low quality; minimum light |
| Long unskippable cutscenes | Short, skippable, after first control |
| Dead players waiting minutes | Spectate, ghosts, revives, short rounds |
| One-time content only | Randomness, endings, modes, rare events |
| Sound-only cues | Visual equivalents and subtitles |
| Gore for shock | Suspense and stylised threat; check maturity rules |

## 13. Checklist

- [ ] Structure chosen (chapter, round, roguelite, survival).
- [ ] Tension curve planned with explicit release beats.
- [ ] Monster rules learnable; signature sound; telegraphs.
- [ ] Death keeps players engaged (spectate, revive, quick return).
- [ ] Story readable without text; cutscenes skippable.
- [ ] Replay drivers designed.
- [ ] Phone low-quality pass; flashing limited; visual cues for sounds.
- [ ] Maturity questionnaire answered; content checked against current rules.

## See also
- [[Lighting Mood and Time of Day]], [[Atmosphere Sky Clouds and Post-Processing]], [[Sound Design for Games]], [[Music and Adaptive Audio]]
- [[NPC AI and Behaviour]], [[Pathfinding]], [[Animating Creatures and Monsters]], [[Cameras and Cutscenes]]
- [[Social Design and Multiplayer Play]], [[Spawning Teams and Rounds]], [[Quests and Objectives]]
- [[Accessibility]], [[Roblox Policies Ratings and Compliance]], [[Ethical Design and Player Trust]]

## Connected notes
<!-- auto-links:start -->
[[Horror Monster Chase AI End to End]] · Links - Horror game mechanics · [[Genre Playbook - Puzzle and Escape Rooms]] · Case Study - Doors · Links - Music and ambience · Case Study - 99 Nights in the Forest
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Genre Playbook - Zombie and Wave Survival Co-op]] · [[Genre Playbook - Obbies and Platformers]] · [[Genre Playbook - Roleplay and Social Hangouts]] · [[Genre Playbook - Combat and RPG]] · [[Genre Playbook - Party and Minigame Collections]] · [[Genre Playbook - Survival and Crafting]] · [[Core Loops and Session Design]] · [[Genre Playbook - Social Deduction and Murder Mystery]]
<!-- related:end -->
