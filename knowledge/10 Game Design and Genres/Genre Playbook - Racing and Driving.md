---
tags: [game-design, genre, racing, driving, vehicles, physics, network-ownership, cars]
---
# Genre Playbook - Racing and Driving

Driving games on Roblox come in two broad families. **Racing** games are about competition: laps, checkpoints, times, positions. **Driving** games are about owning and using cars: open-world cruising, car collection, roleplay cities with traffic, delivery jobs, drift parks and car customisation. Many successful games blend both (an open world with races as an activity). The genre is car-collection-driven, attracts a slightly older audience, and rests on one hard technical problem: physics vehicles controlled by players over a network.

This playbook covers the loops, session shapes, monetisation, the systems you must build, the Roblox-specific technical risks (network ownership, physics stability, speed and streaming), the patterns successful driving games share, and a launch checklist. For the physics construction of the car itself, see [[Cars with Constraints - Suspension Steering and Drive]].

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production combat game; not a driving game, cited only for general lessons), **Rule of thumb**.

---

## 1. Core loops

### Racing
| Loop | Length | Content |
|---|---|---|
| Corner | 2 to 5 s | Brake, turn in, accelerate out |
| Lap | 30 s to 2 min | Learn the track, beat your time |
| Race | 2 to 6 min | Positions, overtakes, finish |
| Meta | Weeks | Cars, upgrades, rank, time leaderboards |

### Open-world driving
| Loop | Length | Content |
|---|---|---|
| Drive | Minutes | Cruise, explore, drift, show off |
| Activity | 2 to 10 min | A job, race, delivery, police chase, drift challenge |
| Session | 30 to 90 min | Earn money, buy or upgrade a car, hang out |
| Meta | Months | Garage collection, customisation, rare cars |

The open-world model retains better on Roblox (rule of thumb from the genre's public top lists): driving is fun on its own, cars are a collection, and the world is a social space. Pure racing needs enough players online to fill races, and its competition pushes newcomers away. A common successful pattern is an open world with races, time trials and events as optional activities.

---

## 2. Session design

- **Car within 30 seconds.** A new player should be driving a free car almost immediately. Garage menus before the first drive lose players.
- **Spawning cars:** a spawn menu (pick from the garage, car appears beside you) beats physical dealerships for convenience; physical dealerships are better for showing off. Many games use both.
- **Races start fast:** a race lobby or an in-world starting line with a 10 to 20 s countdown that others can join. Ghost-start or rolling-start options suit low player counts.
- **Rubber-banding** (slight speed help for trailing players) keeps casual races close. Disable it in ranked or time-trial modes, and never apply it in a way players can see as unfair.
- **Earnings pace:** the first car upgrade within the first session; the first new car within one or two sessions. See [[Progression and Pacing Design]].

---

## 3. The car: arcade or simulation

| Model | Feel | Build | Fit |
|---|---|---|---|
| `VehicleSeat` with hinge-driven wheels | Simple, bouncy | Fastest to build | Casual, roleplay |
| Constraint-based (springs, hinges, cylindrical constraints) | Realistic suspension | Moderate | Most driving games |
| Raycast car (no wheel physics; forces computed from rays down to the ground) | Tunable, stable, arcade or sim | Most code | Racing, drift, high speed |

`VehicleSeat` exposes `ThrottleFloat` and `SteerFloat` (the older integer `Throttle` and `Steer` are deprecated), plus `MaxSpeed`, `Torque` and `TurnSpeed` (Docs, VehicleSeat reference). For anything beyond basic driving, most developers read input themselves and drive constraints or forces from their own controller.

### Why raycast cars are popular for racing
A physics car with wheel cylinders is at the mercy of collision details: a wheel catching a seam between two parts at 150 studs/s can launch the car. A raycast car (a single body with four rays for suspension, forces applied for grip, drive and drag) never catches seams, can be tuned exactly, and behaves the same on every client. The cost: you write the vehicle model yourself, and it is easy to make it feel floaty. See [[Cars with Constraints - Suspension Steering and Drive]] and [[Mover Constraints and Physics Controllers]].

---

## 4. The technical risks

### Network ownership
A driven car must be **owned by the driver's client**: input applies immediately and the car responds without a round trip. Roblox assigns ownership to the nearest player automatically for unanchored assemblies; for vehicles, set it explicitly when a player sits and reset it when they leave (Docs, "Network ownership").

```lua
--!strict
-- Server: give the driver ownership of their car's assembly; return it to the server when they leave.
local function bindSeat(seat: VehicleSeat, chassis: BasePart)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = seat.Occupant
		local player = if humanoid
			then game:GetService("Players"):GetPlayerFromCharacter(humanoid.Parent)
			else nil
		if chassis.Anchored then return end
		if player then
			chassis:SetNetworkOwner(player)
		else
			chassis:SetNetworkOwner(nil) -- server owns idle cars, so nobody can fling them
		end
	end)
end

return bindSeat
```

Consequences you must design for:
- **The driver's client is authoritative for the car's position.** An exploiter can teleport their car, fly it, or set extreme speed. Server checks: speed above the car's maximum plus a margin, position jumps, airtime that does not match gravity. Respond with resets, not instant bans; physics glitches look similar. See [[Detecting Movement Exploits - Speed Fly Noclip Teleport]].
- **Car-on-car collisions** are between two client-owned assemblies. Each client simulates its own car and receives the other's position late. Ramming at speed produces "phantom" hits and launches. Many racing games turn off car-to-car collision in races (ghost cars), or reduce collision response, which is also the fix for griefers ramming others.
- **Flinging other players.** A client-owned car can hit pedestrians with huge force. Use collision groups so cars do not collide with characters, or limit the impulse. See [[Physics Assemblies and Constraints]] and [[Debugging Physics and Network Ownership]].

### Speed, physics stability and the world
- **High speed versus thin collision**: thin walls can be tunnelled through at high speed. Use thick barriers on tracks and simple invisible collision boxes rather than detailed mesh collision. See [[Collision and Physics Geometry]].
- **Seams**: smooth road surfaces with few seams; prefer long parts or meshes with simple collision fidelity.
- **Mass and density**: extremely light or heavy parts on a vehicle cause jitter in constraints. Keep mass ratios reasonable and use `Massless` on decorative parts.
- **Physics cost per car**: each driven car is an assembly with several constraints. Twenty cars in a server is normal; a hundred idle spawned cars is a performance problem. Despawn abandoned cars after a timeout (60 to 120 s rule of thumb) and limit one or two spawned cars per player. See [[Physics Performance]].

### Streaming and large worlds
Open-world driving games have large maps, and cars cross them quickly. With streaming enabled:
- Roads ahead must stream in before the car arrives. Tune `StreamingTargetRadius` and consider `RequestStreamAroundAsync` ahead of fast movement.
- **The car itself must not stream out from under the driver.** Make vehicle models `Atomic` or persistent as appropriate so the car arrives whole. See [[Instance Streaming]] and [[Level of Detail and Model Streaming]].
- Other players' cars far away may not be present on a client, which affects minimaps; drive minimap markers from replicated data, not from models.

### Timing races fairly
Do not trust client lap times. Use checkpoints on the server: each checkpoint is a volume; the server records the server time when the car's position (as replicated) crosses it, and checks order and plausibility (minimum segment time). The finish order comes from server timestamps. Because the server sees client-owned cars slightly late, there is a small offset common to everyone; it is consistent enough for positions. For very close finishes, also accept the client's own crossing time if it is within a small window of the server's, and log it.

---

## 5. Systems you must build

| System | Notes |
|---|---|
| Vehicle controller | Input (keyboard, touch, gamepad, tilt optional), forces or constraints |
| Car data module | Speed, acceleration, handling, price, unlock, tuning ranges |
| Garage and ownership | Saved list of cars and their customisation |
| Car spawning and despawning | Per-player caps; despawn on leave and when abandoned |
| Customisation | Paint, rims, decals (moderated), body kits, underglow |
| Upgrades / tuning | Engine, tyres, suspension; visible stat changes |
| Races and checkpoints | Server timing, positions, rewards |
| Leaderboards | Per-track best times; see [[Global Leaderboards End to End]] |
| Camera | Chase camera with speed-based field of view, look-back, first person optional |
| Audio | Engine pitch by RPM, tyre squeal, collisions; see [[Sound Design for Games]] |
| Anti-exploit | Speed, teleport, fly checks with fair thresholds |

### Customisation and user content
Player-uploaded decals on cars are a moderation risk: any image a player chooses must be an approved Roblox asset, and showing text players type (licence plates, car names) requires `TextService` filtering for every viewer (Docs, "Text filtering"). Offer preset decals and filtered text only. See [[Roblox Policies Ratings and Compliance]] and [[Text Chat Customization with TextChatService]].

### Mobile driving
Touch driving is hard: steering with a virtual stick or left/right buttons, throttle and brake on the right. Offer auto-accelerate as an option and generous steering assistance. Test at high speed on a phone, where frame drops make steering feel laggy. Tilt steering is a nice option but never the default. See [[Gamepad and Console UX]] and [[Mobile and Low-End Optimization]].

---

## 6. Monetisation that fits

| Product | Fit | Notes |
|---|---|---|
| Premium cars (game passes or direct buy) | Core | Keep their stats within the range of earnable top cars |
| Customisation packs (paint, rims, effects) | Excellent | Cars are displayed; expression sells |
| Garage slots | Good | |
| Cash packs | Common | Watch the economy |
| VIP (cash multiplier, exclusive spawn area) | Common | |
| Private servers | Good | Car meets, races with friends |
| Limited event cars | Strong | Time-limited, clearly earnable through events |

In a competitive race mode, consider normalised classes (cars grouped by performance rating), so paid cars do not dominate ranked races. Open-world showing-off is where premium cars belong.

---

## 7. Patterns successful driving games share

Patterns, not copies:
- **Recognisable car archetypes** (supercar, muscle car, off-roader, classic), designed originally. Real car brands and logos are trademarks; using them without a licence risks takedowns. See [[Legal Basics - IP Licenses and Assets]].
- **A large, interesting map** with highways for speed, twisty roads for handling, off-road areas, jumps and hidden spots.
- **Social spaces** for car meets: parking lots, showrooms, a place to park and look at each other's cars.
- **Jobs and activities** that give purpose to driving: delivery, taxi, police and criminal roles (see [[Genre Playbook - Roleplay and Social Hangouts]]).
- **Frequent car drops** as updates, often several per update, with an event car each season.
- **Tuning depth** for enthusiasts, invisible to casual players.

---

## 8. Common mistakes

| Mistake | Better |
|---|---|
| Server-owned driven cars | Driver owns the car; server owns idle cars |
| Detailed mesh collision on roads | Simple, thick collision |
| Unlimited spawned cars | One or two per player; despawn abandoned |
| Cars colliding with pedestrians | Collision groups |
| Client lap times trusted | Server checkpoints and plausibility |
| Real car brands | Original designs |
| Player-typed plate text unfiltered | `TextService` filtering per viewer |
| Garage menus before the first drive | Free car in under 30 seconds |

## 9. Launch checklist

- [ ] Driving feels good on keyboard, gamepad and touch; tested on a low-end phone at top speed.
- [ ] Network ownership set and reset on sit and leave.
- [ ] Speed, teleport and fly checks with reset responses; tuned against real physics glitches.
- [ ] Collision groups: cars versus characters, ghost cars in races if needed.
- [ ] Streaming tested at top speed across the whole map; cars arrive whole.
- [ ] Spawn caps and abandoned-car despawns measured with a full server.
- [ ] Race timing server-side; leaderboards reject impossible times.
- [ ] All custom text filtered; decals limited to approved assets.
- [ ] Premium cars balanced against top free cars.

## See also
- [[Cars with Constraints - Suspension Steering and Drive]], [[Physics and Vehicles Start Here]], [[Boats Buoyancy and Water]], [[Aircraft and Flight Models]]
- [[Network Ownership]], [[Physics Assemblies and Constraints]], [[Physics Performance]]
- [[Genre Playbook - Roleplay and Social Hangouts]], [[Core Loops and Session Design]], [[Level Design for Roblox]]

## Connected notes
<!-- auto-links:start -->
[[Racing Laps and Checkpoints End to End]] · [[Genre Playbook - Sports]] · [[Links - Constraints]] · [[Genre Systems Start Here]] · [[Case Study - Brookhaven RP]] · [[Roblox Generative AI - Cube Mesh and Texture Generation]]
<!-- auto-links:end -->
