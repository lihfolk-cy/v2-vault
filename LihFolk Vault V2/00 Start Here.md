---
cssclasses: [vault-hub]
tags: [index, start]
---
# LihFolk Vault V2: Start Here

A field guide to **every aspect of making games in Roblox Studio**, written at senior-developer depth: Studio and workflow, Luau, architecture and networking, data, UI, world building, lighting/VFX/audio, animation, gameplay systems, game design, monetization and live ops, performance and testing, production, 3D modeling, AI tools, MCP and AI agents, and pipelines.

About 800 notes (roughly fifteen thick textbooks of original LihFolk writing), plus 9 skeleton rigs, 10 concept sheets, procedural Blender assets, and the LihFolk Claude Code plugin with 15+ AI skills. The visual home page is [[000 Home]].

## How to read the labels
- **Roblox docs**: the official engine reference and Creator Hub guides, checked in October 2026. Roblox changes fast, so anything marked "as of October 2026" (prices, payouts, policies, betas) is worth rechecking.
- **Measured / the reference project**: one live action game, which was built over many months and partly with AI agents connected to Studio and Blender. Its numbers, bugs and fixes are real and kept, but its name and identifiers are not.
- **Rule of thumb**: experience and craft knowledge, labelled as such.
- **Unverified**: something no official source confirmed. Conflicts are collected in [[Open Questions - Whole Vault]] (the Animation section keeps its own detailed [[Open Questions]]).

## Reading paths

**Brand new to Roblox development:**
[[Studio Interface Tour]] → [[Luau Language Essentials]] → [[Client-Server Model]] → [[RemoteEvents RemoteFunctions and Unreliable Remotes]] → [[DataStore Fundamentals]] → [[ScreenGui Fundamentals]] → [[Core Loops and Session Design]] → [[Publishing an Experience]]

**Programmer going deep:**
[[Luau Type System and Strict Mode]] → [[Task Library Coroutines and Yielding]] → [[Server Authority and Validation]] → [[Session Locking and Profile Libraries]] → [[Parallel Luau and Actors]] → [[Script Performance]] → [[Code Pipeline - Rojo Git and CI]]

**Artist (3D, environment, VFX):**
[[Modeling Fundamentals for Games]] → [[Blender Workflow for Roblox Creators]] → [[UV Unwrapping]] → [[Texturing and PBR Baking]] → [[Exporting and Validating Models for Roblox]] → [[Materials MaterialVariants and SurfaceAppearance]] → [[Lighting Technologies and Settings]] → [[VFX Design Playbook]]

**Animator:** [[Animation Start Here]]

**Designer and producer:**
[[Core Loops and Session Design]] → [[First-Time User Experience and Onboarding]] → [[Retention and Return Hooks]] → [[Progression and Pacing Design]] → [[Monetization Overview]] → [[Discovery and the Algorithm]] → [[Analytics and Funnels]] → [[Ethical Design and Player Trust]] → [[Roblox Policies Ratings and Compliance]]

**Building with AI tools and agents:**
[[AI in Roblox Development Overview]] → [[Prompting and Verifying AI Output]] → [[What Is MCP]] → [[Roblox Studio MCP Server]] → [[Safety Rules for AI Agents in Studio]] → [[Case Study - Building a Game with AI Agents]]

**Shipping and running a live game:**
[[QA Checklists Before Release]] → [[Release Process and Rollbacks]] → [[Build Test and Release Pipeline]] → [[Live Ops Events and Updates]] → [[Crash and Error Telemetry]] → [[Data Loss Prevention and Recovery]]

**Learning from a real project:**
[[Post-Mortem - Building a Melee Action Game]] → [[Lessons Learned Index]] → the case studies in Production and in Animation

**Securing a game against exploiters:**
[[Anti-Exploit Start Here]] → [[How Exploits Work - The Client Boundary]] → [[Threat Modeling a Roblox Game]] → [[Server Authority and Validation]] → [[Remote Abuse Patterns and Rate Limiting in Practice]] → [[Testing Your Own Remotes - Fuzzing and Abuse Tests]] → [[False Positives Lag and Fair Enforcement]]

**Building a feature from scratch:**
[[Worked Builds Start Here]] → [[Saved Inventory End to End]] → [[Shop with Game Passes and Developer Products End to End]] → [[Luau Cookbook Start Here]] → [[AI Skills Start Here]]

**Launching and growing a game:**
[[Marketing and Growth Start Here]] → [[Launch Strategy - The First Two Weeks]] → [[Community and Moderation Start Here]] → [[Business and Careers Start Here]] → [[Top Games Case Studies Start Here]]

**Designing worlds and content:**
[[Level Design Start Here]] → [[Procedural Generation Start Here]] → [[Narrative Start Here]] → [[Avatars and UGC Start Here]] → [[Live Ops Deep Dive Start Here]]

**Engineering depth:**
[[Advanced Luau Start Here]] → [[Game Math Start Here]] → [[Plugin Development Start Here]]

**Multiplayer, genres and polish:**
[[Multiplayer Services Start Here]] → [[Genre Systems Start Here]] → [[Materials and Surfaces Start Here]] → [[Accessibility Start Here]]

**Building art with scripts in Blender:**
[[Procedural Blender Assets Start Here]] → [[Matching a Concept Sheet - Boss Creature Case Study]] → [[Blender 5 Python Gotchas for Headless Builds]]

**Looking for an outside link:**
[[Resource Library Start Here]]

**Something is broken or slow:**
[[Debugging Start Here]] → [[The Debugging Method - Reproduce Isolate Bisect]] → [[Reading Luau Errors and Stack Traces]] → [[Performance Fundamentals]] → [[MicroProfiler Guide]] → [[Hunting Memory Leaks Step by Step]] → [[Debugger Breakpoints and Logging]] → [[Troubleshooting Table]] (animation)

## Map

### 01 Studio and Workflow (14 notes)
- [[Command Bar and Studio Scripting]]
- [[Creator Store and Toolbox Safety]]
- [[Explorer Properties and Selection]]
- [[External Tooling - Rojo Wally Selene StyLua]]
- [[Git and Source Control for Roblox]]
- [[Packages and Asset Reuse]]
- [[Places Universes and Experience Settings]]
- [[Plugins - Using and Writing]]
- [[Studio Assistant and AI Tools]]
- [[Studio Interface Tour]]
- [[Studio Settings and Shortcuts]]
- [[Team Create and Collaboration]]
- [[Testing Modes - Play Run and Multi-Client]]
- [[Version History and Backups]]

### 02 Luau Scripting (19 notes)
- [[Buffers and Binary Data]]
- [[CollectionService Patterns]]
- [[Error Handling - pcall xpcall and Promise Patterns]]
- [[Error Handling and Retries]]
- [[Events Signals and Connections]]
- [[Functions Closures and Upvalues]]
- [[Instances Attributes and Tags]]
- [[Luau Language Essentials]]
- [[Luau Performance Patterns with Benchmarks]]
- [[Luau Performance and Native Codegen]]
- [[Luau Type System and Strict Mode]]
- [[Math Vectors and CFrames]]
- [[Metatables and OOP - When and When Not]]
- [[Module Scripts and Requiring]]
- [[Parallel Luau and Actors]]
- [[Script Types and Run Context]]
- [[Strings Patterns and Formatting]]
- [[Tables Metatables and OOP]]
- [[Task Library Coroutines and Yielding]]

### 03 Architecture and Networking (17 notes)
- [[Client Prediction and Reconciliation for Combat]]
- [[Client-Server Model]]
- [[Cross-Server Messaging]]
- [[Entity Component Systems]]
- [[Exploits and Anti-Cheat]]
- [[Frameworks - Knit Matter and Others]]
- [[Instance Streaming]]
- [[Interest Management and Per-Player Replication]]
- [[Network Ownership]]
- [[Project Structure and Bootstrapping]]
- [[Rate Limiting and Abuse Prevention]]
- [[Remote Abuse Patterns and Rate Limiting in Practice]]
- [[RemoteEvents RemoteFunctions and Unreliable Remotes]]
- [[Replication Rules]]
- [[Server Authority and Validation]]
- [[Server Lifecycle and Shutdown]]
- [[Teleporting and Multi-Place Games]]

### 04 Data and Persistence (14 notes)
- [[Data Loss Prevention and Recovery]]
- [[Data Schema Design and Migrations]]
- [[DataStore Fundamentals]]
- [[Global State and Live Config]]
- [[HttpService and External APIs]]
- [[MemoryStore Service]]
- [[Open Cloud APIs]]
- [[OrderedDataStores and Leaderboards]]
- [[Player Privacy and Data Deletion]]
- [[Purchase Data and Receipts]]
- [[Saving Correctly - Autosave and BindToClose]]
- [[Schema Migrations - Worked Case Studies]]
- [[Session Locking and Profile Libraries]]
- [[Trading Systems Without Duplication]]

### 05 UI and UX (18 notes)
- [[Accessibility]]
- [[Declarative UI - React-Lua and Fusion]]
- [[Gamepad and Console UX]]
- [[HUD Design]]
- [[Input - UserInputService and ContextActionService]]
- [[Layout - Scale Offset and Constraints]]
- [[Localization]]
- [[Menu Archetypes - Shop Settings Codes Rewards]]
- [[Notification and Toast Systems]]
- [[Responsive UI for Phone Tablet Console and PC]]
- [[Safe Areas and Insets]]
- [[ScreenGui Fundamentals]]
- [[Text Fonts and Rich Text]]
- [[UI Design Systems]]
- [[UI Layout Objects - Lists Grids and Pages]]
- [[UI Motion Language and Timing]]
- [[Virtualized Lists and Large Inventories]]
- [[World-Space UI - BillboardGui and SurfaceGui]]

### 06 World Building and Art (17 notes)
- [[Art Budgets - Triangles Draw Calls Memory]]
- [[Collision and Physics Geometry]]
- [[Environment Art Styles]]
- [[Foliage Props and Scatter]]
- [[Grid Placement and Player Building Systems]]
- [[Level Design for Roblox]]
- [[Level of Detail and Model Streaming]]
- [[Materials MaterialVariants and SurfaceAppearance]]
- [[Modeling in Blender for Roblox]]
- [[Parts Unions and MeshParts]]
- [[Procedural World Generation]]
- [[Terrain Deep Dive - Materials Water and Performance]]
- [[Terrain Tools and Terrain API]]
- [[Textures Decals and Texture Memory]]
- [[Voxel Art - Studs Outlines and Style Kits]]
- [[Water Sky and Atmosphere Art]]
- [[Zone and Biome Art Direction]]

### 07 Lighting VFX and Audio (17 notes)
- [[Atmosphere Sky Clouds and Post-Processing]]
- [[Beams and Trails]]
- [[Combat Sound Design and Feedback]]
- [[Game Feel and Juice]]
- [[Highlights and Selection Effects]]
- [[Light Sources and Shadows]]
- [[Lighting Mood and Time of Day]]
- [[Lighting Technologies and Settings]]
- [[Music and Adaptive Audio]]
- [[Particle Emitters In Depth]]
- [[Sound Design for Games]]
- [[Sound Fundamentals]]
- [[Spatial Audio and Mixing]]
- [[Stylized Lighting Recipes]]
- [[The Audio API - Players Emitters Wires and Effects]]
- [[VFX Design Playbook]]
- [[VFX Performance Budgets and Culling]]

### 08 Animation (118 notes)
Start at [[Animation Start Here]] (reading paths and full map) and [[Animation Glossary]]. Subsections:
- **Fundamentals**: [[Animation Asset Permissions and Groups]], [[Animation Objects]], [[AnimationConstraint and Physically Simulated Characters]], [[AnimationTrack Reference]], [[Animator Deep Dive]], [[Bones and Skinned Meshes]], [[CurveAnimation and Curve Channels]], [[Frame Order and RunService Timing]], [[How the Animator Really Behaves]], [[Humanoid States and Animation]], [[Keyframes, Easing and Interpolation]], [[KeyframeSequence Keyframe and Pose Reference]], [[Markers and Events]], [[Motor6D Math and CFrame Composition]], [[Playback, Priorities and Blending]], [[Replication and Ownership]], [[Rigs and Joints]], [[Scale and Animation]], [[The Default Animate Script]]
- **Rigging and Importing**: [[3D Importer Settings Reference]], [[Accessories and Armor That Follow Animation]], [[Animation Data from Blender to Roblox]], [[Blender Armature and Bone Roll Conventions]], [[Creature Rig Conventions]], [[Custom Characters and StarterCharacter]], [[Custom Rigs - Weapons and Props]], [[Exporting FBX vs GLB]], [[Facial Animation and Dynamic Heads]], [[Importing Models and Rigs]], [[Layered Clothing Cages and Animation]], [[R15 Rig Anatomy and Attachments]], [[Retargeting Animations Between Rigs]], [[Rigging in Blender]], [[Weight Painting and Skinning for Roblox]]
- **Authoring**: [[Animating Creatures and Monsters]], [[Animation Capture and Mocap]], [[Animation Editor Advanced]], [[Animation Editor Workflow]], [[Animation Quality Standard]], [[Animation Review Checklist]], [[Authoring Clips in Code]], [[Combat Animation Craft]], [[Idle Breathing and Secondary Motion]], [[Moon Animator and Third-Party Tools]], [[Posing and Silhouettes]], [[Principles of Animation for Games]], [[Publishing Animations]], [[Spec-Driven Move Authoring]], [[Timing Spacing and Frame Charts]], [[Weapon Swing Design]]
- **Procedural**: [[Elbow Poles Swivel and Joint Limits]], [[Flight Flocks and Path Animation]], [[Foot Placement and Ground IK]], [[IKControl Reference]], [[Inverse Kinematics]], [[Look-At Aim and Head Tracking]], [[Multi-Bone IK - FABRIK and CCD]], [[Procedural Animation]], [[Procedural Death Knockdown and Hit Reactions]], [[Procedural Gait and Footstep Planning]], [[Procedural Weapon Motion]], [[Ragdolls and Physics-Based Animation]], [[Springs Damping and Smoothing]], [[Tween and CFrame Animation of Objects]], [[Two-Bone IK Math]]
- **Systems**: [[Ability Kits Architecture]], [[Boss Animation and Phases]], [[Camera Shake and Camera FX]], [[Cameras and Cutscenes]], [[Cinematic Ultimates]], [[Combat Combo Systems]], [[Custom Locomotion Controller Design]], [[Emotes and Social Animation]], [[Enemy and NPC Animation]], [[Enemy Animation State Protocol]], [[Equip Draw and Flourish Systems]], [[Hit Reactions Stagger and Hit-Stop]], [[Locomotion Systems]], [[Stance and Charge Moves]], [[UI and GUI Animation]], [[VFX Timing with Animation]], [[Weapon and Combat Animation]]
- **Pipelines and Tooling**: [[Arm Baker Internals]], [[Arm QA Metrics Reference]], [[Baked Clip Stubs and Archiving]], [[Case Study - Abilities That Only Worked in Studio]], [[Case Study - Cutting a Million Instances]], [[Case Study - Fixing Hundreds of Attack Clips]], [[Clip Archive Server]], [[Clip Buffer Format]], [[Enemy Import Axis Fix]], [[Ground Fitting Pipeline]], [[Lua Keyframe Player Internals]], [[Lua Keyframe Player]], [[Pipeline - Arm IK Baking and QA]], [[Pipeline - Importing Animated Enemies]], [[Pipeline - New Animated Weapon]], [[Studio Tooling Architecture]], [[Weapon Design Rig Builder]], [[Weapon Rig Player]]
- **Gotchas**: [[Animation LOD]], [[Debugging Animation Problems]], [[Engine Gotchas]], [[Open Questions]], [[Performance and Memory]], [[Testing Animations in Studio]], [[Troubleshooting Table]]
- **Snippets**: [[Snippets - Animation Controller Module]], [[Snippets - Building and Sampling Clips]], [[Snippets - Camera Shake and FX]], [[Snippets - Enemy Client Animator]], [[Snippets - IK]], [[Snippets - Lua Keyframe Player Core]], [[Snippets - Playing Animations]], [[Snippets - Procedural Motion]], [[Snippets - Ragdoll]]

- **References**: [[Reference - Purple Anime Settings UI (Claude + Figma)]]

### 09 Gameplay Systems (19 notes)
- [[Behaviour Trees Utility AI and State Machines for NPCs]]
- [[Camera Systems]]
- [[Characters and Humanoids]]
- [[Combat Systems Architecture]]
- [[Custom Character Controllers]]
- [[Economies and Currencies]]
- [[Hitboxes and Hit Detection]]
- [[Mover Constraints and Physics Controllers]]
- [[NPC AI and Behaviour]]
- [[Pathfinding]]
- [[Pathfinding Edge Cases and Fallbacks]]
- [[Physics Assemblies and Constraints]]
- [[Progression Levels and Unlocks]]
- [[Quests and Objectives]]
- [[RNG Drops and Luck Systems]]
- [[Raycasts Shapecasts and Spatial Queries]]
- [[Spawning Teams and Rounds]]
- [[Status Effects Buffs and Stacking Rules]]
- [[Tools and Inventory Systems]]

### 10 Game Design and Genres (25 notes)
- [[Balancing with Spreadsheets and Data]]
- [[Boss Fight Design Patterns]]
- [[Core Loops and Session Design]]
- [[Ethical Design and Player Trust]]
- [[First-Time User Experience and Onboarding]]
- [[Genre Playbook - Battlegrounds and Arena Fighters]]
- [[Genre Playbook - Combat and RPG]]
- [[Genre Playbook - Horror and Story]]
- [[Genre Playbook - Obbies and Platformers]]
- [[Genre Playbook - Party and Minigame Collections]]
- [[Genre Playbook - Puzzle and Escape Rooms]]
- [[Genre Playbook - RNG and Collection Games]]
- [[Genre Playbook - Racing and Driving]]
- [[Genre Playbook - Roleplay and Social Hangouts]]
- [[Genre Playbook - Shooters FPS and TPS]]
- [[Genre Playbook - Simulators]]
- [[Genre Playbook - Sports]]
- [[Genre Playbook - Survival and Crafting]]
- [[Genre Playbook - Tower Defense]]
- [[Genre Playbook - Tycoons]]
- [[Progression and Pacing Design]]
- [[Rarity Ladders and Drop Pacing Math]]
- [[Retention and Return Hooks]]
- [[Simulator and RNG Genre Teardown]]
- [[Social Design and Multiplayer Play]]

### 11 Monetization Publishing and Live Ops (18 notes)
- [[Ads and Rewarded Video]]
- [[Age Checks and Safety Features]]
- [[Analytics and Funnels]]
- [[Community Building]]
- [[Developer Products and ProcessReceipt]]
- [[Discovery and the Algorithm]]
- [[Economy Inflation Sinks and Faucets Math]]
- [[Game Passes]]
- [[Live Ops Events and Updates]]
- [[Monetization Overview]]
- [[Paid Random Items and Odds Disclosure in Practice]]
- [[Pricing and Store Design]]
- [[Publishing an Experience]]
- [[Refunds Chargebacks and Purchase Support]]
- [[Roblox Policies Ratings and Compliance]]
- [[Robux Price Points and Offer Design]]
- [[Subscriptions and Premium Payouts]]
- [[Thumbnails Icons and Store Page]]

### 12 Performance Testing and Debugging (18 notes)
- [[Automated Testing with TestEZ and Jest-Lua]]
- [[Crash and Error Telemetry]]
- [[Debugger Breakpoints and Logging]]
- [[Developer Console and Stats]]
- [[Hunting Memory Leaks Step by Step]]
- [[Memory Budgets and Leaks]]
- [[MicroProfiler Guide]]
- [[Mobile and Low-End Optimization]]
- [[Multi-Client and Device Playtesting Protocols]]
- [[Multi-Client and Live Testing]]
- [[Network Bandwidth Budgets and Measuring Them]]
- [[Network Performance]]
- [[Performance Fundamentals]]
- [[Physics Performance]]
- [[QA Checklists Before Release]]
- [[Rendering Performance]]
- [[Script Performance]]
- [[Testing Strategies and Frameworks]]

### 13 Production and Case Studies (15 notes)
- [[Asset Pipelines]]
- [[Case Study - Enemy Roster Rebuild]]
- [[Case Study - Fast Join and Deferred Loading]]
- [[Case Study - Instance Cleanup and Place Size]]
- [[Case Study - Phone UI Overhaul]]
- [[Documentation and Knowledge Bases]]
- [[Lessons Learned Index]]
- [[Live Incident Response and Post-Mortems]]
- [[Planning and Scoping a Roblox Game]]
- [[Post-Mortem - Building a Melee Action Game]]
- [[Release Process and Rollbacks]]
- [[Safe Changes in a Shared Place]]
- [[Scoping and Roles for Small Teams]]
- [[Team Roles and Workflows]]
- [[Working with AI Assistants in Studio]]

### 14 3D Modeling (21 notes)
- [[Blender Workflow for Roblox Creators]]
- [[Exporting and Validating Models for Roblox]]
- [[Hand-Painted and Stylized Texturing]]
- [[Hard-Surface Modeling]]
- [[Low-Poly and Stylized Modeling]]
- [[Mesh Optimization for Mobile]]
- [[Modeling Characters for R15 and Custom Rigs]]
- [[Modeling Fundamentals for Games]]
- [[Modeling Weapons and Props]]
- [[Modular Environment Kits]]
- [[Normal Maps and Detail Baking]]
- [[Organic and Creature Modeling]]
- [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]]
- [[Retopology and Decimation]]
- [[Substance Painter and Texturing Tools]]
- [[Texturing and PBR Baking]]
- [[Topology and Edge Flow]]
- [[Trim Sheets Atlases and Vertex Colors]]
- [[UGC Avatar Items and Accessories]]
- [[UV Unwrapping]]
- [[Voxel and Blocky Modeling]]

### 15 AI Tools (14 notes)
- [[AI 3D Model Generation Outside Roblox]]
- [[AI Agents and Autonomous Workflows]]
- [[AI Animation and Motion from Video]]
- [[AI Audio - Voice Music and SFX]]
- [[AI Code Assistants for Luau]]
- [[AI Image Generation for Icons Thumbnails and Concepts]]
- [[AI Material and Texture Generation]]
- [[AI in Roblox Development Overview]]
- [[Evaluating AI Tools - A Practical Rubric]]
- [[In-Game AI - LLM NPCs and Text Generation]]
- [[Prompting and Verifying AI Output]]
- [[Roblox Generative AI - Cube Mesh and Texture Generation]]
- [[Roblox Policies on AI-Generated Content]]
- [[Roblox Studio Assistant]]

### 16 MCP and Agents (12 notes)
- [[Agent Review Loops and Guardrails in Practice]]
- [[Blender MCP]]
- [[Case Study - Building a Game with AI Agents]]
- [[MCP Workflows for Building Worlds]]
- [[MCP Workflows for Scripting and Debugging]]
- [[Multiple Agents in One Studio]]
- [[Roblox Studio MCP Server]]
- [[Safety Rules for AI Agents in Studio]]
- [[Setting Up MCP Clients]]
- [[Studio Plugins and Local HTTP Bridges]]
- [[What Is MCP]]
- [[Writing Your Own MCP Server]]

### 17 Pipelines (15 notes)
- [[Art Pipeline - Concept to In-Game Asset]]
- [[Asset Upload Automation with Open Cloud]]
- [[Audio Pipeline]]
- [[Batch Processing Tools in Studio]]
- [[Blender Automation with Python]]
- [[Build Test and Release Pipeline]]
- [[Character and Creature Pipeline]]
- [[Code Pipeline - Rojo Git and CI]]
- [[Data and Config Pipeline - Spreadsheets to Game]]
- [[Environment and Level Pipeline]]
- [[Icon and Thumbnail Rendering Pipeline]]
- [[Live Content Pipeline]]
- [[Localization Pipeline]]
- [[Pipeline Design Principles]]
- [[UI Asset Pipeline]]

### 18 Rigs and Skeletons (9 rigs, .fbx .glb .blend)
- [[Skeleton Library]]

### 19 Concept Sheets (10 sheets, 4K PNG)
- [[Concept Sheets]]

### 21 LihFolk UI Design System
- [[LihFolk UI Design System]]

### 22 Anti-Exploit and Security (9 notes)
- [[Anti-Exploit Start Here]]
- [[Detecting Combat Exploits - Reach Rate and Aim]]
- [[Detecting Movement Exploits - Speed Fly Noclip Teleport]]
- [[Economy Exploits - Dupes Races and Purchase Abuse]]
- [[False Positives Lag and Fair Enforcement]]
- [[How Exploits Work - The Client Boundary]]
- [[Logging Bans and Appeals]]
- [[Testing Your Own Remotes - Fuzzing and Abuse Tests]]
- [[Threat Modeling a Roblox Game]]

### 23 Debugging Deep Dives (9 notes)
- [[Debugging Client-Server Desync]]
- [[Debugging DataStore Problems]]
- [[Debugging Live Servers]]
- [[Debugging Physics and Network Ownership]]
- [[Debugging Race Conditions and Yield Order]]
- [[Debugging Start Here]]
- [[Debugging UI Layout and Input]]
- [[Reading Luau Errors and Stack Traces]]
- [[The Debugging Method - Reproduce Isolate Bisect]]

### 24 Worked Builds (11 notes)
- [[Codes Redemption System End to End]]
- [[Daily Rewards System End to End]]
- [[Global Leaderboards End to End]]
- [[Melee Combat System End to End]]
- [[Pet Hatching and Following End to End]]
- [[Quest Chain System End to End]]
- [[Rebirth and Prestige System End to End]]
- [[Round-Based Minigame Loop End to End]]
- [[Saved Inventory End to End]]
- [[Shop with Game Passes and Developer Products End to End]]
- [[Worked Builds Start Here]]

### 25 Physics and Vehicles (7 notes)
- [[Aircraft and Flight Models]]
- [[Boats Buoyancy and Water]]
- [[Cars with Constraints - Suspension Steering and Drive]]
- [[Destruction and Fracture]]
- [[Physics and Vehicles Start Here]]
- [[Projectiles and Ballistics]]
- [[Ropes Chains and Soft Bodies]]

### 26 Community and Moderation (7 notes)
- [[Community and Moderation Start Here]]
- [[Discord Servers for Roblox Games]]
- [[Groups Roles and Permissions for Studios]]
- [[Player Reports and In-Game Moderation]]
- [[Text Chat Customization with TextChatService]]
- [[Voice Chat and Safety Features]]
- [[Working with Content Creators]]

### 27 Marketing and Growth (7 notes)
- [[A-B Testing and Experiments on Roblox]]
- [[Competitor Analysis Method]]
- [[Launch Strategy - The First Two Weeks]]
- [[Marketing and Growth Start Here]]
- [[Short-Form Video Marketing]]
- [[Sponsored Ads and Campaign Math]]
- [[Update Cadence and Hype Cycles]]

### 28 Business and Careers (7 notes)
- [[Building a Portfolio as a Roblox Developer]]
- [[Business and Careers Start Here]]
- [[Commissions Pricing and Contracts]]
- [[DevEx and Cashing Out]]
- [[Hiring Freelancers and Revenue Shares]]
- [[Legal Basics - IP Licenses and Assets]]
- [[Running a Small Studio as a Business]]

### 29 Luau Cookbook (7 notes)
- [[Cookbook - Data and Saving]]
- [[Cookbook - Math CFrame and Vectors]]
- [[Cookbook - Players and Characters]]
- [[Cookbook - Remotes and Networking]]
- [[Cookbook - Tables Strings and Time]]
- [[Cookbook - UI]]
- [[Luau Cookbook Start Here]]

### 31 LihFolk AI Skills (11 notes)
- [[AI Skills Start Here]]
- [[Skill - Roblox Anti-Exploit Review]]
- [[Skill - Roblox Asset Import]]
- [[Skill - Roblox DataStore Safety]]
- [[Skill - Roblox Debugging]]
- [[Skill - Roblox Monetization Compliance]]
- [[Skill - Roblox Performance Audit]]
- [[Skill - Roblox Secure Remotes]]
- [[Skill - Roblox System Builder]]
- [[Skill - Roblox UI Builder]]
- [[Skill - Roblox Vault Research]]

### 32 Case Studies of Top Roblox Games (12 notes)
- [[Top Games Case Studies Start Here]]
- [[Case Study - 99 Nights in the Forest]]
- [[Case Study - Adopt Me]]
- [[Case Study - Blox Fruits]]
- [[Case Study - Brookhaven RP]]
- [[Case Study - Doors]]
- [[Case Study - Dress to Impress]]
- [[Case Study - Fisch]]
- [[Case Study - Grow a Garden]]
- [[Case Study - Pet Simulator 99]]
- [[Case Study - Steal a Brainrot]]
- [[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]]

### 33 Level Design (7 notes)
- [[Combat Arena and Encounter Layout]]
- [[Level Design Principles - Flow Sightlines and Landmarks]]
- [[Level Design Start Here]]
- [[Lobby and Hub Design]]
- [[Obby and Platforming Level Design]]
- [[Spawn Points Safe Zones and Respawn Flow]]
- [[Teaching Through Level Design]]

### 34 Procedural Generation (7 notes)
- [[Dungeon and Room Generation]]
- [[Infinite and Streamed Worlds]]
- [[Noise Functions and Terrain Generation]]
- [[Procedural Generation Start Here]]
- [[Procedural Loot and Item Generation]]
- [[Seeds Determinism and Reproducible Worlds]]
- [[Wave Function Collapse on Roblox]]

### 35 Advanced Luau (7 notes)
- [[Advanced Luau Start Here]]
- [[Advanced Types - Generics and Type Functions]]
- [[Building a Signal Library]]
- [[Custom Schedulers and Coroutine Patterns]]
- [[Luau Garbage Collection and the Memory Model]]
- [[Module Design and Dependency Injection]]
- [[Serialization Formats for Saves and Networking]]

### 36 Narrative and Worldbuilding (7 notes)
- [[Dialogue System End to End]]
- [[Localization-Ready Writing]]
- [[Lore Delivery Without Walls of Text]]
- [[Naming Items Zones and Abilities]]
- [[Narrative Start Here]]
- [[Quest Writing and Hooks]]
- [[Writing Dialogue for Roblox Players]]

### 37 Avatars and UGC (7 notes)
- [[Avatar Body Types and Scale in Gameplay]]
- [[AvatarEditorService and In-Game Avatar Editors]]
- [[Avatars and UGC Start Here]]
- [[Bundles Animation Packs and Emotes for Sale]]
- [[HumanoidDescription and Outfit Systems]]
- [[Layered Clothing Creation Workflow]]
- [[UGC Pricing Limiteds and Marketplace Rules]]

### 38 Live Ops Deep Dive (7 notes)
- [[Battle Pass and Season Design]]
- [[Economy Resets and Seasonal Wipes]]
- [[Event Calendars and Content Planning]]
- [[Feature Flags and Staged Rollouts]]
- [[Limited-Time Offers - Design and Ethics]]
- [[Live Ops Deep Dive Start Here]]
- [[Patch Notes and Player Communication]]

### 39 Studio Plugins and Tooling (7 notes)
- [[Building a Studio Plugin End to End]]
- [[Plugin Development Start Here]]
- [[Plugin Security and Permissions]]
- [[Plugin UI with DockWidgets]]
- [[Publishing Selling and Updating Plugins]]
- [[Selection Editing and Bulk Tools]]
- [[Undo and ChangeHistoryService Done Right]]

### 40 Game Math (7 notes)
- [[Big Numbers Precision and Formatting]]
- [[Dot and Cross Products in Gameplay]]
- [[Game Math Start Here]]
- [[Interpolation Easing and Curves Math]]
- [[Intersection and Collision Math]]
- [[Probability and Statistics for Designers]]
- [[Rotations Angles and Quaternions]]

### 41 Multiplayer Services (7 notes)
- [[Matchmaking Queues with MemoryStore]]
- [[Multiplayer Services Start Here]]
- [[Parties and Group Teleports]]
- [[Reserved and Private Servers in Practice]]
- [[Server Browsers and Server Lists]]
- [[Server Shutdowns Soft Updates and Migration]]
- [[Session State Across Places]]

### 42 Accessibility and Inclusive Design (7 notes)
- [[Accessibility Start Here]]
- [[Captions and Audio Accessibility]]
- [[Colour-Blind Safe Design]]
- [[Difficulty Options and Cognitive Load]]
- [[Input Remapping and One-Handed Play]]
- [[Motion Sensitivity and Camera Comfort]]
- [[Readable Text and UI Scale]]

### 43 Genre Systems End to End (7 notes)
- [[Arena Rounds with Teams and Spectating End to End]]
- [[Genre Systems Start Here]]
- [[Horror Monster Chase AI End to End]]
- [[Obby Checkpoints and Stage Saves End to End]]
- [[Racing Laps and Checkpoints End to End]]
- [[Tower Defense Waves and Placement End to End]]
- [[Tycoon Plots and Droppers End to End]]

### 44 Materials and Surfaces (7 notes)
- [[Baking Lighting and Detail into Textures]]
- [[Materials and Surfaces Start Here]]
- [[MaterialService and Custom Materials]]
- [[Stylised vs Realistic Material Pipelines]]
- [[SurfaceAppearance PBR Workflow]]
- [[Terrain Materials and Painting]]
- [[Tiling Trim Sheets and Decal Tricks]]

### 45 Procedural Blender Assets (8 notes)
- [[Blender 5 Python Gotchas for Headless Builds]]
- [[Chibi Character Rules in Practice]]
- [[Dramatic Showcase Renders in Eevee]]
- [[Low-Poly Tree Set Worked Example]]
- [[Matching a Concept Sheet - Boss Creature Case Study]]
- [[Mesh VFX Packs Built in Blender]]
- [[Procedural Blender Assets Start Here]]
- [[Stylised Weapons From a Concept]]

### 46 Resource Library (121 notes, about 3,600 links)
Start at [[Resource Library Start Here]]: 19 chapters, one note per topic.

### 47 Game Feel and Juice (7 notes)
- [[Game Feel Start Here]]
- [[Feedback Timing - Sound Visual and Haptic Sync]]
- [[Hit-Stop and Screen Shake Tuning by Numbers]]
- [[Input Responsiveness Buffering and Coyote Time]]
- [[Juice on a Budget - Mobile and Low-End]]
- [[Reward Moments and Celebrations]]
- [[Squash Stretch and Anticipation in UI and Characters]]

### 48 Economy Design Deep Dive (7 notes)
- [[Economy Design Start Here]]
- [[Currency Architecture - Soft Hard and Event Currencies]]
- [[Drop Tables Rarity and Pity Systems]]
- [[Economy Telemetry and Balancing Live]]
- [[Player-Driven Trading Economies]]
- [[Pricing Curves and Upgrade Costs]]
- [[Simulating an Economy Before Launch]]

### 49 Roblox Platform Features (7 notes)
- [[Platform Features Start Here]]
- [[Avatar Context Menus Profiles and Social Surfaces]]
- [[Badges and Achievement Design]]
- [[Commerce and Physical Goods]]
- [[Experience Notifications and Return Prompts]]
- [[Friend Invites Referrals and Experience Invites]]
- [[Subscriptions and Recurring Revenue]]

### 50 Team Collaboration and Project Management (7 notes)
- [[Team Collaboration Start Here]]
- [[Code Review for Luau Teams]]
- [[Documentation and Onboarding New Developers]]
- [[Packages and Shared Assets Across Places]]
- [[Roadmaps Milestones and Scope Control]]
- [[Team Create Permissions and Workflows]]
- [[Working with Contractors and Revenue Splits]]

### 51 2D Game Development (10 notes)
- [[2D Game Development Start Here]]
- [[2D Collision Physics and Platformer Movement]]
- [[2D Multiplayer - Server Authority and Replicating GUI Worlds]]
- [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]
- [[Choosing GUI 2D or Locked-Camera 2.5D]]
- [[EditableImage for Pixel Buffers and Procedural 2D]]
- [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]]
- [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]
- [[Sprite Sheets and Frame Animation with ImageRectOffset]]
- [[Tilemaps Cameras and Parallax for 2D Levels]]

### 52 Core Concepts (38 notes)
- [[Core Concepts Start Here]]
- [[Accessibility Contrast]]
- [[Anticipation]]
- [[Click-Through Rate]]
- [[Core Loop]]
- [[Data Schema Versioning]]
- [[Dependency Injection in Luau]]
- [[Deterministic Simulation]]
- [[Draw Calls]]
- [[Easing]]
- [[Event Bus]]
- [[Expected Value]]
- [[Faucets and Sinks]]
- [[Feature Flags]]
- [[Frame Budget]]
- [[Hit-Stop]]
- [[Idempotency]]
- [[Input Buffering]]
- [[Instance Count]]
- [[Object Pooling]]
- [[Onboarding Funnel]]
- [[Pity Timer]]
- [[Power Curve]]
- [[Rate Limiting]]
- [[Replication Boundary]]
- [[Retention Cohorts]]
- [[Safe Area]]
- [[Server Authority]]
- [[Session Length]]
- [[Session Lock]]
- [[Skinning Weights]]
- [[Streaming Radius]]
- [[Telemetry Events]]
- [[Texel Density]]
- [[Thumbnail Contrast]]
- [[Triangle Budget]]
- [[Tween vs Spring]]
- [[Variance]]

### 53 Voxel Modelling Deep Dive (8 notes)
- [[Voxel Modelling Start Here]]
- [[MagicaVoxel Goxel and Blockbench Workflows Compared]]
- [[Meshing Voxels for Roblox - Greedy Meshing and Export]]
- [[Voxel Characters - Proportions Joints and Rigging]]
- [[Voxel Palettes - Ramps Hue Shifting and Limits]]
- [[Voxel Props Environments and Modular Tiles]]
- [[Voxel Scale Grids and Stud Alignment]]
- [[Voxel Shading - Baked AO Edges and Lighting]]

### 54 Untextured Stylised Modelling (8 notes)
- [[Untextured Stylised Modelling Start Here]]
- [[Clean Stylised Shading - Weighted and Custom Normals]]
- [[Colour Scripts and Value Structure for Untextured Art]]
- [[Faceted Low-Poly - Flat Normals and Facet Size]]
- [[Flat Colour vs Gradient Atlas vs Vertex Colour]]
- [[Keeping a Mixed Asset Library Consistent]]
- [[Lighting Untextured Art in Roblox]]
- [[The Gradient Palette Texture Workflow]]

### 55 Modelling Nuance and Readability (8 notes)
- [[Modelling Nuance Start Here]]
- [[Bevels Chamfers and Edge Highlights Without Textures]]
- [[Critiquing a Model - Paintovers and Iteration]]
- [[Modelling to the Roblox Camera and Player Scale]]
- [[Proportion Exaggeration and Gameplay Distance]]
- [[Shape Language and Silhouette Testing]]
- [[Spending Triangles Where the Camera Looks]]
- [[Style Bibles for Consistent Models]]

### 56 Field Notes (21 notes)
Start at [[Field Notes Start Here]]: 20 hard-won lessons from a shipped action RPG (camera, UI, input, animation, audio, data, Studio automation, many-agent workflows).

### Reference
- [[Using This Vault in Obsidian]] (search, speed, AI tools)
- [[Glossary]], [[Animation Glossary]]
- [[Open Questions - Whole Vault]]
