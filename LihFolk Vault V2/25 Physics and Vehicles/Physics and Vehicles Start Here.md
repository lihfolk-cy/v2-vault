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
