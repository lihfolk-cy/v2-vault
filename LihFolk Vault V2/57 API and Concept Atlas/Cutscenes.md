---
tags: [atlas, concept, type/atlas, area/animation, area/gameplay]
---
# Cutscenes

<!-- tldr:start -->
> [!tldr] TL;DR
> - Cutscenes are the exception, and they own the camera fully.
> - HUD missing after a cutscene: No restore on an error path -> Watchdog and restore on every exit.
> - Cutscenes save and restore type, subject, FOV and GUI, with a watchdog.
> - Control within about 10 s of join; no unskippable cutscene.
>
> Cost: TL;DR ~120 tok · whole note ~1.3k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Cutscenes are the exception, and they own the camera fully. (from [[Snippets - Camera Shake and FX]])

## Key facts

- HUD missing after a cutscene: No restore on an error path -> Watchdog and restore on every exit. ([[Cameras and Cutscenes]])
- Cutscenes save and restore type, subject, FOV and GUI, with a watchdog. ([[Camera Systems]])
- Control within about 10 s of join; no unskippable cutscene. ([[First-Time User Experience and Onboarding]])
- Avoid: Long intro cutscene -> The reference project disabled its 27 s intro; start with the verb. ([[Core Loops and Session Design]])

## Mentioned in

105 notes in 26 sections. The 25 most relevant are linked:

### 05 UI and UX
[[Notification and Toast Systems]]

### 07 Lighting VFX and Audio
[[Atmosphere Sky Clouds and Post-Processing]] · [[Lighting Mood and Time of Day]] · [[Lighting Technologies and Settings]] · [[Music and Adaptive Audio]]

### 08 Animation
[[Boss Animation and Phases]] · [[Camera Shake and Camera FX]] · [[Cameras and Cutscenes]] · [[Cinematic Ultimates]] · [[Custom Locomotion Controller Design]] · [[Moon Animator and Third-Party Tools]] · [[Snippets - Camera Shake and FX]]

### 09 Gameplay Systems
[[Camera Systems]] · [[Custom Character Controllers]] · [[Quests and Objectives]]

### 10 Game Design and Genres
[[First-Time User Experience and Onboarding]] · [[Genre Playbook - Horror and Story]]

### 27 Marketing and Growth
[[Game Trailers and Clean Footage - Capture, Freecam and Editing]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]] · [[Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes]]

### 42 Accessibility and Inclusive Design
[[Motion Sensitivity and Camera Comfort]]

### 47 Game Feel and Juice
[[Reward Moments and Celebrations]]

### 49 Roblox Platform Features
[[Photo Mode and In-Game Screenshots with CaptureService]]

### 56 Field Notes
[[A Stuck Player Watchdog That Logs the Cause]] · [[Layering Camera Feedback on the Default Camera]]

Also mentioned in (not linked): 00 Start Here · AI Animation and Motion from Video · Ability Kits Architecture · Accessibility Start Here · Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools · Animation LOD · Animation Objects · Animation Start Here · AnimationTrack Reference · Baking Lighting and Detail into Textures · Behaviour Trees Utility AI and State Machines for NPCs · Boss Fight Design Patterns · Build Test and Release Pipeline · Camera Obstruction Handling - Occlusion Modes, Fades and Collision · Camera Settings - FOV Shake Sensitivity and Shift-Lock · Cars with Constraints - Suspension Steering and Drive · Characters and Humanoids · Chase Cameras and Speed Effects for Vehicles · Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits · Clip Buffer Format · Combat Combo Systems · Console and VR Release Checklists · Core Loops and Session Design · Curves in Luau - Paths Beams and Motion · Custom Schedulers and Coroutine Patterns · Data and Config Pipeline - Spreadsheets to Game · Downed, Revive and Bleed-Out States · Emotes and Social Animation · Equip Draw and Flourish Systems · Field Notes Start Here · Game Feel and Juice · Genre Playbook - Combat and RPG · Genre Playbook - Puzzle and Escape Rooms · HUD Design · Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots · Horror Monster Chase AI End to End · Humanoid States and Animation · Idle Breathing and Secondary Motion · Input Responsiveness Buffering and Coyote Time · Instance Streaming · Interpolation Easing and Curves Math · Kill Credit, Assists, Kill Feed and Death Recaps · Lore Delivery Without Walls of Text · Mesh Optimization for Mobile · Monetization Overview · NPC AI and Behaviour · Narrative Start Here · Open Questions · Performance and Memory · Pipeline Design Principles · Playback, Priorities and Blending · Pricing and Store Design · Principles of Animation for Games · Procedural Animation · Procedural Weapon Motion · Quest Chain System End to End · Quest Writing and Hooks · Release Process and Rollbacks · Rescuing a Weak Launch - Empty Servers, Low CCU and Relaunch Tactics · Robux Price Points and Offer Design · Safe Areas and Insets · Scale and Animation · Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur · Server-Authoritative Freeze and Stun Timestamps · Short-Form Video Marketing · Simulator and RNG Genre Teardown · Snippets - Animation Controller Module · Snippets - Lua Keyframe Player Core · Standing on Moving Vehicles and Platforms - Keeping Players Glued · Status Effects Buffs and Stacking Rules · Story State Flags and Chapter Saves · Team Roles and Workflows · Thumbnails Icons and Store Page · Tools and Inventory Systems · Tween vs Spring · Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver · Weapon and Combat Animation · Weather System Architecture - State Machine, Transitions and Replication · Writing Dialogue for Roblox Players · Zone Detection - Area Enter and Exit for Music, Lighting and Ambience

<!-- atlas:generated -->
