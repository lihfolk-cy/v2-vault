---
tags: [atlas, concept, type/atlas, area/animation, area/gameplay]
---
# NPCs

<!-- tldr:start -->
> [!tldr] TL;DR
> - NPCs are the opposite problem: one or two characters that must feel alive for minutes while doing nothing.
> - Each NPC type mapped to the cheapest technique that expresses its design.
> - Avoid: Default agent size for big NPCs -> Real radius and height per size class.
> - Agent parameters match each NPC size class.
>
> Cost: TL;DR ~120 tok · whole note ~2.0k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

NPCs are the opposite problem: one or two characters that must feel alive for minutes while doing nothing. (from [[Enemy and NPC Animation]])

NPCs are found by the CollectionService tag `DialogueNpc` and say which tree they use through a `TreeId` attribute (CollectionService Patterns, Instances Attributes and Tags). (from [[Dialogue System End to End]])

## Key facts

- Each NPC type mapped to the cheapest technique that expresses its design. ([[Behaviour Trees Utility AI and State Machines for NPCs]])
- Avoid: Default agent size for big NPCs -> Real radius and height per size class. ([[Pathfinding]])
- Agent parameters match each NPC size class. ([[Pathfinding]])
- Avoid: Every NPC sounds the same -> Voice cards with one trait each. ([[Writing Dialogue for Roblox Players]])
- First conversation with any NPC is under about 50 words. ([[Writing Dialogue for Roblox Players]])

## Mentioned in

180 notes in 36 sections. The 25 most relevant are linked:

### 03 Architecture and Networking
[[Network Ownership]]

### 08 Animation
[[Replication and Ownership]] · [[Snippets - Animation Controller Module]]

### 09 Gameplay Systems
[[AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses]] · [[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Characters and Humanoids]] · [[Mover Constraints and Physics Controllers]] · [[Pathfinding]] · [[Pathfinding Edge Cases and Fallbacks]] · [[Physics Assemblies and Constraints]] · [[Police Chases and Wanted Levels]] · [[Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking]] · [[Visual AI Debugging - State Labels, Path Lines and Perception Gizmos]] · [[Weather That Changes Gameplay - Grip, Visibility and Hearing]]

### 12 Performance Testing and Debugging
[[Physics Performance]]

### 14 3D Modeling
[[Modeling Characters for R15 and Custom Rigs]]

### 15 AI Tools
[[In-Game AI - LLM NPCs and Text Generation]]

### 23 Debugging Deep Dives
[[Debugging Physics and Network Ownership]]

### 24 Worked Builds
[[Quest Chain System End to End]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]] · [[Localization-Ready Writing]] · [[Lore Delivery Without Walls of Text]] · [[Writing Dialogue for Roblox Players]]

### 37 Avatars and UGC
[[HumanoidDescription and Outfit Systems]]

### 40 Game Math
[[Dot and Cross Products in Gameplay]]

Also mentioned in (not linked): 00 Start Here · 3D Importer Settings Reference · AI Animation and Motion from Video · AI Audio - Voice Music and SFX · AI Code Assistants for Luau · AI Pitfalls - Networking and Security · AI Pitfalls - Physics and Animation · AI in Roblox Development Overview · Accessories and Armor That Follow Animation · Aim Assist and Generous Hitboxes · Animating Creatures and Monsters · Animation Capture and Mocap · Animation LOD · Animation Objects · Animation Start Here · AnimationConstraint and Physically Simulated Characters · AnimationTrack Reference · Animator Deep Dive · Anticipation · Art Pipeline - Concept to In-Game Asset · Avatar Body Types and Scale in Gameplay · Avatars and UGC Start Here · Bones and Skinned Meshes · Boss Animation and Phases · Boss Fight Design Patterns · Captions and Audio Accessibility · Case Study - 99 Nights in the Forest · Case Study - Adopt Me · Case Study - Blox Fruits · Case Study - Enemy Roster Rebuild · Case Study - Fisch · Character and Creature Pipeline · Cinematic Ultimates · Client Prediction and Reconciliation for Combat · Client-Server Model · Collision and Physics Geometry · Combat Arena and Encounter Layout · Combat Systems Architecture · Cookbook - Math CFrame and Vectors · Cookbook - Players and Characters · Creature Rig Conventions · CurveAnimation and Curve Channels · Custom Character Sounds - Replacing Default Footstep and Jump Sounds · Custom Characters and StarterCharacter · Debugging Animation Problems · Debugging Live Servers · Detecting Movement Exploits - Speed Fly Noclip Teleport · DevEx and Cashing Out · Downed, Revive and Bleed-Out States · Dungeon and Room Generation · Emotes and Social Animation · Enemy Animation State Protocol · Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder · Enemy and NPC Animation · Engine Gotchas · Entity Component Systems · Exploits and Anti-Cheat · Explosions - Radius Damage, Falloff and Cover Checks · Faceted Low-Poly - Flat Normals and Facet Size · Facial Animation and Dynamic Heads · Flight Flocks and Path Animation · Frame Budget · Frameworks - Knit Matter and Others · Free Mocap and Mixamo Licensing for Roblox · Genre Playbook - Combat and RPG · Genre Playbook - Horror and Story · Genre Playbook - Open-World City and Crime Roleplay · Genre Playbook - Survival and Crafting · Genre Playbook - Tower Defense · Grabs, Carries and Throws - Moving Players Safely · Ground Fitting Pipeline · Hard-Surface Modeling · Hit Reactions Stagger and Hit-Stop · Hitboxes and Hit Detection · Horror Monster Chase AI End to End · How Exploits Work - The Client Boundary · Humanoid States and Animation · Hunting Memory Leaks Step by Step · Idle Breathing and Secondary Motion · Infinite and Streamed Worlds · Interest Management and Per-Player Replication · Layered Clothing Cages and Animation · Level Design Principles - Flow Sightlines and Landmarks · Level Design for Roblox · Level of Detail and Model Streaming · Load and Soak Testing Servers - Long Sessions and Many Clients · Localization · Locomotion Systems · Look-At Aim and Head Tracking · Lua Keyframe Player · Luau Performance and Native Codegen · Math Vectors and CFrames · Melee Combat System End to End · Metatables and OOP - When and When Not · MicroProfiler Guide · Mobile and Low-End Optimization · Modeling Fundamentals for Games · Multi-Client and Live Testing · NPC AI and Behaviour · Nametags and Overhead Bars - Cost and Visibility Rules · Naming Items Zones and Abilities · Narrative Start Here · Network Bandwidth Budgets and Measuring Them · Network Performance · Open Questions - Whole Vault · Parallel Luau and Actors · Performance Fundamentals · Performance and Memory · Pipeline - Importing Animated Enemies · Playback, Priorities and Blending · Pricing and Store Design · Procedural Animation · Procedural Death Knockdown and Hit Reactions · Procedural Gait and Footstep Planning · Procedural Generation Start Here · Project Structure and Bootstrapping · Proportion Exaggeration and Gameplay Distance · Quests and Objectives · Ragdolls and Physics-Based Animation · Raycasts Shapecasts and Spatial Queries · Resource Library - Game Systems · Rigging in Blender · Rigs and Joints · Roblox Built-In AI Tools Timeline 2023-2026 · Roblox Generative AI - Cube Mesh and Texture Generation · Roblox Policies on AI-Generated Content · Rotations Angles and Quaternions · Scale and Animation · Shape Language and Silhouette Testing · Snapshot Interpolation for Custom Replication · Snippets - Enemy Client Animator · Snippets - Playing Animations · Snippets - Ragdoll · Social Design and Multiplayer Play · Sound Design for Games · Spawn Director - Credit Budgets and Player-Count Scaling · Spawning Teams and Rounds · Spending Triangles Where the Camera Looks · Squad AI - Attack Tokens, Flanking and Attacker Limits · Status Effects Buffs and Stacking Rules · Story State Flags and Chapter Saves · StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs · Teaching Through Level Design · Testing Animations in Studio · Testing Modes - Play Run and Multi-Client · Text Chat Customization with TextChatService · Tower Defense Waves and Placement End to End · Troubleshooting Table · Voxel Art - Studs Outlines and Style Kits · Voxel Characters - Proportions Joints and Rigging · Voxel and Blocky Modeling · Weapon and Combat Animation · Weekend Build - Roleplay Town with Jobs and Paychecks · Wildlife and Ambient Creature AI - Passive, Neutral and Hostile · World-Space UI - BillboardGui and SurfaceGui

<!-- atlas:generated -->
