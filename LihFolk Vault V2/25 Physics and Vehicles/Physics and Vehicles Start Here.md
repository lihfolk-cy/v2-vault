---
cssclasses: [vault-hub]
tags: [physics, vehicles, hub, start-here, type/hub, area/physics, level/beginner]
---
# Physics and Vehicles Start Here

This section is about the things in a Roblox game that move by physics, or have to look as if they do: cars, boats, aircraft, projectiles, breaking walls, ropes, cloth and jelly. The foundations (assemblies, constraints, movers, ownership, collision) already live in other sections. These notes build on them and go system by system, with the maths, the code, the network design and the exploits for each.

Each note picks the approach first, then covers mechanics, ownership, security, budgets, common mistakes and a checklist. Code is strict Luau and marked reviewed, not run. Facts are labelled as Roblox docs (as of October 2026), community-tested, or rule of thumb.

## Read these first

The base layer; unfamiliar terms are explained there.

- [[Physics Assemblies and Constraints]]: assemblies, root parts, mass, collision groups, the mechanical constraints.
- [[Mover Constraints and Physics Controllers]]: LinearVelocity, AlignOrientation, VectorForce and the physics character controller.
- [[Network Ownership]] and [[Debugging Physics and Network Ownership]]: who simulates what, and how to tell when it goes wrong.
- [[Physics Performance]] and [[Collision and Physics Geometry]]: what physics costs and how to cut it.
- [[Raycasts Shapecasts and Spatial Queries]]: the casting API every note here relies on.

## The notes in this section

| Note | What it covers | Read it when |
|---|---|---|
| [[Cars with Constraints - Suspension Steering and Drive]] | Constraint cars versus raycast cars, computing spring stiffness and damping from frequency, motor and servo wheels, speed-sensitive steering, centre of mass, driver ownership, anti-cheat | You are building anything with wheels |
| [[Boats Buoyancy and Water]] | Engine buoyancy versus float points, calibrating draft and bob frequency, keel drag, deterministic waves on server time, players walking on moving decks | You are building boats, rafts or anything that floats |
| [[Aircraft and Flight Models]] | Arcade, simple aerodynamic and engine fluid-force tiers, lift and drag calibrated from cruise speed, stalls, helicopters, controls on every device, camera, streaming at speed | You are building planes, helicopters, flying mounts or jetpacks |
| [[Projectiles and Ballistics]] | Simulated points versus physical parts, closed-form motion, aiming with drop and leading, swept casts, shooter-predicts-server-decides networking, validation, spread seeds, ricochet and penetration | You are building guns, bows, spells or thrown weapons |
| [[Destruction and Fracture]] | Swap-and-fake, pre-fractured welds with connectivity, runtime fracture with GeometryService, explosions, terrain and voxel destruction, destruction budgets and rate limits | Anything in your game breaks |
| [[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] | The four chassis options, a decision guide, a complete minimal raycast car, auditing a community kit | You are about to build or adopt a car and have not picked what it is made of |
| [[Engine, Gearbox and Torque Curve Model for Arcade Cars]] | Running the model on the driver's client, RPM from road speed, a torque table, gear ratios with hysteresis and shift cut, audio and HUD from the same numbers | Your car accelerates flat like a scooter and has no gears |
| [[Steering Geometry and Arcade Drifting - Ackermann, Slip and Grip Tuning]] | Ackermann steering, speed-sensitive lock, a hand-tunable slip-angle tyre, arcade drifting, not fighting the solver | Handling feels wrong or you want drifting |
| [[Centre of Mass, Anti-Flip and Self-Righting]] | Why low cars still flip, anti-roll bars, in-air stabilisation, detecting "flipped" versus "steep", server-validated self-righting | Cars roll over or players get stuck upside down |
| [[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]] | Default VehicleSeat input versus Input Action System actions, a touch layout that works, gamepad details | Your car is only fun on WASD |
| [[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]] | Roles on seats, ownership staying with the driver, prompt-based entry, client input routing, cosmetic aim with server hits, safe switching | A vehicle carries more than one player or has a turret |
| [[Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits]] | The spawn flow, server limits, the garage as data, showroom previews | Players pick, spawn and own cars |
| [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] | The client-owned car threat model, ownership policy, a per-vehicle validator, flings, the 2026 Server Authority option | Your driving game goes public |
| [[Vehicle Damage, Repair and Wreck States]] | Damage states, collision damage without trusting the driver, detaching panels, repair stations, wrecks | Cars should take damage |
| [[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]] | What streaming does to a car, Atomic vehicles, streaming ahead, integrity pauses, other players' cars | Fast vehicles meet a streamed map |
| [[Racing AI on a Racing Line - Spline Following and Rubber-Banding]] | Authoring a racing line, pure-pursuit steering, carrying speed, overtaking, fair rubber-banding | Races need AI opponents |
| [[Standing on Moving Vehicles and Platforms - Keeping Players Glued]] | Why characters fall off, picking the mover by speed, physical elevators, kinematic movers, why welding is usually wrong | Players slide off trains, decks or lifts |
| [[Rides and Attractions - Roller Coasters, Ziplines, Elevators and Cable Cars]] | Picking the driver per ride, coasters on a shared clock, elevators, ziplines and rails, cable cars | You are building theme-park or hangout rides |
| [[Ropes Chains and Soft Bodies]] | What [[RopeConstraint]] really is, stable physical chains and bridges, client-side verlet ropes and cloth, spring-driven bones for jiggle, a grappling hook worked example | You need ropes, capes, flags, tails or anything squishy |

## Themes that run through every note

**Physics or visual?** The most important question in this section. If a thing must push the world, carry players or decide gameplay, it is physics, owned by someone and paid for in simulation and bandwidth. If it only has to look right, it should be simulated on each client and never replicated. Ropes, debris, cloth and most destruction belong in the second group far more often than people expect.

**Roblox gravity is strong.** The default 196.2 studs/s² is several times Earth gravity at the usual stud scale. Springs sag further, boats bob faster and planes need more lift than real-world numbers suggest. The car, boat and aircraft notes each show how to calibrate from the behaviour you want instead of from real-world constants.

**The controller owns the vehicle.** Cars, boats and aircraft are owned by the driver's client for responsiveness, set explicitly when they sit. That makes the driver's machine the authority on position, so the server must check speed, height, bounds and teleports with vehicle-aware limits. [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] has the general method.

**Budgets beat features.** Treat each note's rule-of-thumb budgets as starting points and measure on your lowest target phone ([[MicroProfiler Guide]]).

## Related sections

- Genre context: [[Genre Playbook - Racing and Driving]], [[Genre Playbook - Shooters FPS and TPS]], [[Genre Playbook - Battlegrounds and Arena Fighters]].
- Combat networking: [[Client Prediction and Reconciliation for Combat]], [[Hitboxes and Hit Detection]], [[Combat Systems Architecture]].
- Motion and feel: [[Springs Damping and Smoothing]], [[Ragdolls and Physics-Based Animation]], [[Procedural Animation]], [[Camera Systems]].
- World: [[Terrain Deep Dive - Materials Water and Performance]], [[Instance Streaming]].

## Connected notes
<!-- auto-links:start -->
[[Official Docs - Physics]] · Racing Laps and Checkpoints End to End · Multi-Bone IK - FABRIK and CCD · Genre Playbook - Roleplay and Social Hangouts · Snippets - Ragdoll
<!-- auto-links:end -->
