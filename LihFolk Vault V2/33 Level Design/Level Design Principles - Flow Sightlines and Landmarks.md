---
tags: [level-design, flow, sightlines, landmarks, wayfinding, readability, camera, streaming]
---
# Level Design Principles - Flow Sightlines and Landmarks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: The brightest object is decoration -> Lower decoration brightness; light the objective
> - Avoid: Guidance by text only -> Add light, motion or an opening
> - Avoid: Landmarks too small -> Raise them, move them closer, or add a far stand-in
> - Each space audited for light, motion, skyline and openings; all four point the same way.
> - Critical path marked in the blockout; most first-time testers find it without UI.
> - Optional content branches off and rejoins the critical path.
>
> Cost: TL;DR ~160 tok · whole note ~5.1k tok. Read more: ## 2. Flow: making the intended route the easy one · ## 3. Sightlines: what the player actually sees · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

[[Level Design for Roblox]] covers the practical basics: measure the character, block out first, time the walks, give every zone one colour and one landmark, test for sight-line leaks into locked zones. This note goes a level deeper into the three ideas underneath all of that: **flow** (how players move through a space without being told), **sightlines** (what they can see from where they stand, and why it changes on every device), and **landmarks** (what they use to build a mental map). It ends with tools to measure all three instead of guessing.

Labels used: **Roblox docs (as of October 2026)**, **measured in the reference project** (one live action game with a hub and multi-zone realms), **rule of thumb** (general level design practice, not Roblox-specific).

## 1. Players read space in a predictable order

Players do not read a level the way its builder does. The builder sees a top-down plan. The player sees a 70 degree slice of it from behind a character, on a screen that may be 6 inches wide, while also watching a HUD, chat and other players. Under that load, players fall back on a small set of cues, roughly in this order (rule of thumb, consistent with most published level design writing):

1. **Light and contrast.** The brightest, most saturated or highest-contrast area in view pulls the eye first.
2. **Motion.** Anything moving (particles, NPCs, other players, a spinning pickup) beats anything static.
3. **Silhouettes against the sky.** Tall shapes that break the horizon register even at low graphics quality.
4. **Openings.** Doorways, gaps between rocks, the end of a path. Players assume an opening is an invitation.
5. **Text.** Signs come last. Many players never read them; younger players and non-English speakers often cannot.

The practical consequence: if your guidance relies on text, it is your weakest guidance. If your brightest object is a decorative lamp in a dead end, players will walk into the dead end. Audit every space by asking "what is the brightest thing here, what moves, what breaks the skyline, where are the openings?" and check that the answers all point the same way.

### Kevin Lynch's five elements

Urban planner Kevin Lynch (The Image of the City, 1960) found that people build mental maps of cities from five elements. They map almost one to one onto Roblox levels and are a good checklist for any space larger than one screen:

| Element | In a city | In a Roblox level | Failure when missing |
|---|---|---|---|
| Paths | Streets | Dirt trails, bridges, corridors, the spine of a hub | Players wander, then quit |
| Edges | Rivers, walls | Cliffs, canyon walls, water, invisible bounds | Players test every edge, fall, or feel trapped |
| Districts | Neighbourhoods | Zones, biomes, hub quarters (shop row, social plaza) | "Where am I?" in screenshots and reports |
| Nodes | Squares, junctions | Plazas, gate fronts, crossroads, spawn pads | No place to regroup or decide |
| Landmarks | Towers, monuments | Centrepieces, giant trees, bosses' arenas seen from afar | Players cannot orient after a respawn or teleport |

A useful test: after a 5-minute playtest, ask the tester to sketch the map from memory. The elements they draw are the ones that work. The ones they forget did not register, whatever they cost to build.

## 2. Flow: making the intended route the easy one

Flow is the feeling that the space itself carries you forward. It is produced by making the intended route the path of least resistance, not by blocking every other route.

### The critical path and the 80 percent rule

Mark the **critical path** in the blockout: the route a player must take to reach the next objective. A rule of thumb from commercial level design: about 80 percent of players should find the critical path on their first try without any UI help. If fewer do, the fix is almost always in the space (light, openings, path material) rather than in another arrow on the HUD.

Optional content should branch **off** the critical path and rejoin it, not sit at its end. A dead end with a reward feels good; a dead end with nothing feels like a mistake the designer made, and players remember it.

### Compression and release

Spaces feel larger after a narrow one. A short canyon or tunnel (compression) followed by an open valley or plaza (release) is the oldest trick for making a reveal land. On Roblox it has two extra jobs:

- **It hides streaming and loading.** A narrow passage limits what is in view, so the next area can stream in behind it. See [[Instance Streaming]].
- **It fixes the camera.** The default camera pulls in when walls occlude it (the default occlusion mode zooms the camera in front of obstacles, Roblox docs). In a long narrow corridor that means a cramped, close camera for the whole walk. Keep compression short (rule of thumb: under 5 seconds of walking) and keep ceilings at least 3 character heights tall, or the camera will press against the player's back.

### Leading lines

Edges that converge on a point drag the eye to that point: path borders, fences, rows of lamps, roof lines, a river. Point them at the objective. The most common accident is the reverse: a row of trees or lamps that leads to a decorative corner while the real exit sits off-axis.

### Thresholds

A threshold (an arch, a gate, a change of floor material, a step up) tells the player "you are entering somewhere new". Use one at every district boundary. Two practical details:

- **Change at least two cues at once**: floor material and lighting, or skyline and colour. One change alone is often missed on a small screen.
- **Put the threshold where the camera will see it.** A floor change under the character is invisible because the camera looks past the character's feet; an arch overhead is visible from 50 studs back.

### Breadcrumbs

Pickups, coins, small enemies and glowing plants along the route give players a reason to move forward and confirm they are on the right path. Breadcrumbs that end abruptly are the strongest "you went the wrong way" signal you have, stronger than a wall.

## 3. Sightlines: what the player actually sees

### The default camera in numbers

| Fact | Value | Source |
|---|---|---|
| Camera `FieldOfView` | 70 degrees, vertical | Roblox docs (as of October 2026) |
| Default max zoom (`StarterPlayer.CameraMaxZoomDistance`) | 400 studs | Roblox docs |
| Streaming target radius default | 1024 studs | Roblox docs (as of October 2026) |
| Streaming minimum radius default | 64 studs | Roblox docs (as of October 2026) |

The vertical FOV is fixed; the horizontal FOV depends on the screen's aspect ratio. Worked out from the 70 degree vertical value:

| Screen | Aspect | Horizontal FOV |
|---|---|---|
| Tablet | 4:3 | about 86 degrees |
| PC monitor | 16:9 | about 102 degrees |
| Modern phone, landscape | about 19.5:9 | about 113 degrees |
| Phone, portrait | about 9:19.5 | about 36 degrees |

Two nuances fall out of this table:

1. **Phone players see wider, not narrower.** Landscape phones show more to the left and right than PC. A secret you hid "just off screen" on PC may be in plain view on a phone.
2. **But everything is tiny.** The same 113 degrees spread across a physically small screen means each object covers far fewer real-world millimetres. Landmarks that read on a monitor can be noise on a phone. If your game supports portrait mode, horizontal view collapses to about a third and almost every lateral sightline breaks.

### Angular size: how big a landmark looks

A landmark of height `H` at distance `D` subtends `2 * atan(H / (2 * D))` degrees. Divide by 70 and multiply by the screen's height in pixels to get its rough on-screen height.

| Landmark height | Distance | Angle | On a 1080-pixel-tall screen |
|---|---|---|---|
| 50 studs | 500 studs | 5.7 degrees | about 88 px |
| 100 studs | 1000 studs | 5.7 degrees | about 88 px |
| 100 studs | 2000 studs | 2.9 degrees | about 44 px |
| 30 studs | 600 studs | 2.9 degrees | about 44 px |

Rule of thumb from this: a landmark meant to orient players should cover at least 3 to 5 degrees of view from where they need it. Below about 2 degrees it is a speck on a phone. That is the maths behind "make the landmark taller than you think".

```lua
--!strict
-- Approximate on-screen height (pixels) of a landmark from a viewpoint, using the live camera.
local function landmarkPixels(landmark: Model, eye: Vector3): number
	local cf, size = landmark:GetBoundingBox()
	local distance = (cf.Position - eye).Magnitude
	local angle = 2 * math.atan(size.Y / (2 * distance)) -- radians
	local camera = workspace.CurrentCamera
	local fov = math.rad(camera.FieldOfView)
	return angle / fov * camera.ViewportSize.Y
end

-- Example: from the spawn pad, at eye height (about 5 studs above the floor).
-- print(landmarkPixels(workspace.Landmarks.CentreTower, workspace.Spawn.Position + Vector3.new(0, 5, 0)))
```

### Sightlines across streaming

With streaming on, a landmark more than the streaming radius away may simply not exist on the client. Options, from cheapest to most expensive:

| Option | How | Trade-off |
|---|---|---|
| Keep landmarks inside the radius | Plan district sizes so key landmarks sit within about 1000 studs of where players need them | Constrains the map |
| `ModelStreamingMode.Persistent` on the landmark | The model is sent soon after join and never streamed out (Roblox docs) | Docs advise using it rarely; every persistent model costs memory on every device |
| Low-detail stand-in | A simple far version (few parts, no collision) that is persistent; the detailed version streams normally | Two assets to maintain |
| Skybox or distant terrain silhouettes | Paint the far landmark into the sky | Never gets closer, so only for truly unreachable shapes |

The low-detail stand-in is the usual answer for one or two hero landmarks. See [[Level of Detail and Model Streaming]] for building the far version.

### Fog and atmosphere

`Atmosphere` density and haze shorten visible range. That is a feature (depth, mood, hiding pop-in) and a cost (landmarks fade). Test the main landmark sightline after every lighting change, and at the lowest graphics quality, where draw distance and effects differ. See [[Atmosphere Sky Clouds and Post-Processing]] and [[Lighting Mood and Time of Day]]; a night or storm preset can erase a landmark that was fine at noon.

### Sightlines you do not want

Sightlines also leak: players see locked zones, the underside of floating geometry, the map edge, the build area you have not finished. [[Level Design for Roblox]] gives a ray test for leaks into locked zones. Add two more checks:

- **From above.** Jump pads, flight, knockback and ragdolls lift the camera. Check the view from 30 to 50 studs above the walkable floor for missing back faces and unfinished areas.
- **From the maximum zoom.** At 400 studs of zoom the camera can rise over walls and see behind them. Many games lower `CameraMaxZoomDistance` partly for this reason; if you keep the default, test the leak rays from the camera's possible positions, not only from eye height.

## 4. Landmarks: a working taxonomy

Not all landmarks do the same job. Mixing up the jobs produces maps with ten "landmarks" and no orientation.

| Type | Job | Visible from | Example |
|---|---|---|---|
| Global landmark | Orient anywhere in the district or game | Everywhere, including after respawn | A central tower, a mountain, a sky ring |
| Destination landmark | Pull players toward the next goal | The previous node or gate | The boss arena's glow, a portal |
| Local landmark | Make one area memorable and nameable | Inside the area | A crashed ship, a giant mushroom |
| Waymarker | Confirm the route at a junction | The junction | A lit lantern at the correct fork |

Rules that held up (rule of thumb, several confirmed in the reference project):

- **One global landmark per district, never two.** Two competing global landmarks split attention. The reference project's hub centred everything on one tall monument and later scaled the tower 1.6x when it read as too small; a second tall element would have diluted it.
- **Landmarks must be unique in silhouette, not just colour.** At distance and in fog, colour is gone first. Test by darkening the landmark to pure black against the sky: can you still tell it from the others?
- **Destination landmarks should be visible from the gate before them.** Measured in the reference project: each zone had one landmark (a giant tree, a frozen crown, a downed mech, a mine entrance) placed to be seen from its gate.
- **Local landmarks name the area for the player.** If players invent a name ("the mushroom place") the landmark works. Listen for it in playtests and chat.

### Landmarks and respawn

A player who respawns or teleports loses their mental map for a moment. The first frame after a respawn should contain a global landmark. That is a level design constraint on spawn placement and spawn facing, covered in depth in [[Spawn Points Safe Zones and Respawn Flow]].

## 5. Worked example: auditing a hub plaza

A hub plaza of radius 100 studs, six stations on a ring, a centre monument 60 studs tall, and an exit gate to the first zone on the north side. Spawn is 140 studs south of the centre.

1. **Brightest thing in view from spawn.** A playtest shows it is the shop's neon sign on the east side, not the monument. Players drift east. Fix: drop the sign's brightness, add a warm light at the monument base.
2. **Angular size of the monument from spawn.** `2 * atan(60 / 280)` is about 24 degrees, so it dominates the frame. Good.
3. **Exit gate.** It sits behind the monument from the spawn, so the monument hides it. Players never find the exit without the HUD arrow. Fix options: move spawn to the south-west so the gate and monument are both in view, or raise the gate's arch so its top clears the monument's silhouette. The reference project's principle "spawn facing the main thing" is right, but "the main thing" must not hide the second thing.
4. **Leading lines.** Paving lines run radially, which pulls players to the centre (good) but gives no hint about the north exit. Fix: a single wider paved avenue running north out of the plaza, with lamps along it.
5. **Re-test.** Measure how many testers reach the gate within 60 seconds without the HUD arrow. Target: most of them (the 80 percent rule).

## 6. Measuring flow instead of guessing

Opinions about flow are cheap. Position data is not much more expensive. A server heatmap samples every player's position on a grid and tells you where people actually go, where they stop and where nobody ever walks.

```lua
--!strict
-- Server: coarse position heatmap for playtests. Samples every SAMPLE_SECONDS,
-- bins positions into CELL-stud squares on the XZ plane, prints the top cells on demand.
local Players = game:GetService("Players")

local CELL = 16
local SAMPLE_SECONDS = 2

local counts: { [string]: number } = {}

local function key(position: Vector3): string
	return `{math.floor(position.X / CELL)},{math.floor(position.Z / CELL)}`
end

task.spawn(function()
	while true do
		task.wait(SAMPLE_SECONDS)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local k = key(root.Position)
				counts[k] = (counts[k] or 0) + 1
			end
		end
	end
end)

local function topCells(n: number): { { cell: string, samples: number } }
	local list = {}
	for cell, samples in counts do
		table.insert(list, { cell = cell, samples = samples })
	end
	table.sort(list, function(a, b) return a.samples > b.samples end)
	local out = {}
	for i = 1, math.min(n, #list) do
		out[i] = list[i]
	end
	return out
end

return { topCells = topCells, counts = counts }
```

How to read it:

- **Hot cells away from any objective** are places people stop. Either something interesting is there (fine) or they are lost (look at what they can see from that cell).
- **Cold corridors** you built carefully are content nobody sees. Move it, signpost it, or cut it.
- **Hot cells at edges** mean players are testing the bounds: either they think there is something beyond, or the edge looks walkable.
- **Compare by session minute.** A heatmap of the first 3 minutes of new players tells you about first-time flow; one of all sessions is dominated by veterans who know the map.

In production you would not keep this table forever; ship a sampled version that sends aggregated cells to your analytics as custom events (see [[Analytics and Funnels]]) or only run it on test servers. Sampling every player every 2 seconds is cheap on the server (one table write per player), but storing raw positions per player per session is a privacy and storage question; aggregate.

## 7. When not to follow these rules

- **Horror and mystery** deliberately break flow: dark spaces, obscured exits, misleading leading lines. The rule there is to break it on purpose and in a controlled place, not by accident. See [[Genre Playbook - Horror and Story]].
- **Social hangouts and roleplay** have no critical path. Flow there means circulation: people should drift past each other, and nodes (benches, stages, plazas) matter more than landmarks pulling toward a goal. See [[Genre Playbook - Roleplay and Social Hangouts]].
- **Competitive arenas** need symmetric or balanced sightlines more than they need flow. A landmark that gives one side a long view is a balance bug. See [[Combat Arena and Encounter Layout]].
- **Tiny spaces.** A single-room game does not need districts or global landmarks; spending a week on a skyline is wasted there.

## 8. Common mistakes

| Mistake | How to spot it | Fix |
|---|---|---|
| The brightest object is decoration | Heatmap shows a hot cell at a lamp or sign | Lower decoration brightness; light the objective |
| Guidance by text only | Testers ask "where do I go?" while standing under a sign | Add light, motion or an opening |
| Landmarks too small | Under 2 to 3 degrees of view from where they matter | Raise them, move them closer, or add a far stand-in |
| Landmark streamed out | Visible in Studio, missing on a phone at distance | Persistent stand-in or keep within the radius |
| Two competing global landmarks | Testers' sketch maps disagree on the centre | Demote one to a local landmark |
| Long compression corridors | Camera pressed against the character for many seconds | Shorten, raise the ceiling, widen |
| Floor-only thresholds | Testers do not notice entering a new area | Add an overhead or skyline cue |
| Only tested on PC | Secrets visible on phones; landmarks unreadable | Test 16:9, 19.5:9 and 4:3; portrait if supported |
| Testing at maximum quality only | Fog and draw distance differ at low quality | Test at the lowest graphics setting |

## 9. Checklist

- [ ] Each space audited for light, motion, skyline and openings; all four point the same way.
- [ ] Critical path marked in the blockout; most first-time testers find it without UI.
- [ ] Optional content branches off and rejoins the critical path.
- [ ] Compression spaces short, with ceilings at least 3 character heights.
- [ ] Thresholds change at least two cues and are visible to the camera.
- [ ] One global landmark per district; unique silhouette when blacked out.
- [ ] Landmarks cover at least 3 to 5 degrees of view where they are needed.
- [ ] Hero landmarks survive streaming (inside the radius or a persistent stand-in).
- [ ] Sightlines tested at low quality, at night presets, from above and from maximum zoom.
- [ ] Heatmap from first-time players reviewed after each layout change.

## See also

- [[Level Design Start Here]] for the rest of this section.
- [[Level Design for Roblox]], [[Zone and Biome Art Direction]], [[Environment Art Styles]].
- [[Camera Systems]], [[Instance Streaming]], [[Level of Detail and Model Streaming]].
- [[Lobby and Hub Design]], [[Teaching Through Level Design]], [[Spawn Points Safe Zones and Respawn Flow]].
- [[Analytics and Funnels]], [[Multi-Client and Device Playtesting Protocols]].

## Connected notes
<!-- auto-links:start -->
[[Modelling to the Roblox Camera and Player Scale]] · [[Voxel Props Environments and Modular Tiles]] · [[Wave Function Collapse on Roblox]] · [[Streaming Radius]] · [[Proportion Exaggeration and Gameplay Distance]] · [[Stylized Lighting Recipes]]
<!-- auto-links:end -->
