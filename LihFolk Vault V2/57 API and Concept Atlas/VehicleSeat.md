---
tags: [atlas, api, type/atlas, area/physics, area/networking, api/VehicleSeat]
---
# VehicleSeat

<!-- tldr:start -->
> [!tldr] TL;DR
> - `VehicleSeat` exposes `ThrottleFloat` and `SteerFloat` (Docs; the older integer `Throttle` and `Steer` are deprecated).
> - Decided: default `VehicleSeat` floats, or a Driving `InputContext`.
> - Avoid: Two VehicleSeats -> One VehicleSeat, all others Seat.
> - One VehicleSeat; seats carry `Role`, `ExitAttachment`, optional `Locked`.
>
> Cost: TL;DR ~120 tok · whole note ~580 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`VehicleSeat` exposes `ThrottleFloat` and `SteerFloat` (Docs; the older integer `Throttle` and `Steer` are deprecated). (from [[Cars with Constraints - Suspension Steering and Drive]])

`VehicleSeat` exposes `ThrottleFloat` and `SteerFloat` (the older integer `Throttle` and `Steer` are deprecated), plus `MaxSpeed`, `Torque` and `TurnSpeed` (Docs, VehicleSeat reference). (from [[Genre Playbook - Racing and Driving]])

API snapshot: class, inherits `BasePart` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Decided: default `VehicleSeat` floats, or a Driving `InputContext`. ([[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]])
- Avoid: Two VehicleSeats -> One VehicleSeat, all others Seat. ([[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]])
- One VehicleSeat; seats carry `Role`, `ExitAttachment`, optional `Locked`. ([[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]])

## Mentioned in

17 notes in 7 sections. The 17 most relevant are linked:

### 03 Architecture and Networking
[[Network Ownership]]

### 07 Lighting VFX and Audio
[[Engine and Tyre Audio Driven by RPM and Slip]]

### 08 Animation
[[Humanoid States and Animation]]

### 09 Gameplay Systems
[[Chase Cameras and Speed Effects for Vehicles]]

### 10 Game Design and Genres
[[Genre Playbook - Racing and Driving]]

### 25 Physics and Vehicles
[[Aircraft and Flight Models]] · [[Boats Buoyancy and Water]] · [[Cars with Constraints - Suspension Steering and Drive]] · [[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] · [[Engine, Gearbox and Torque Curve Model for Arcade Cars]] · [[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]] · [[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]] · [[Vehicle Damage, Repair and Wreck States]] · [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] · [[Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits]] · [[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]]

### 43 Genre Systems End to End
[[Racing Laps and Checkpoints End to End]]

<!-- atlas:generated -->
