---
tags: [reference, glossary]
---
# Glossary

Cross-section terms. Animation terms (Animator, KeyframeSequence, poles, rotation vectors and so on) are in [[Animation Glossary]].

| Term | Meaning | Read more |
|---|---|---|
| **Actor** | A container whose scripts can run in parallel (Parallel Luau) | [[Parallel Luau and Actors]] |
| **Active Spender** | A paying user, the unit of Creator Rewards payouts | [[Subscriptions and Premium Payouts]] |
| **Agent (AI)** | An AI that takes actions with tools (edit scripts, run Luau, render) instead of only chatting | [[AI Agents and Autonomous Workflows]] |
| **Assembly** | Parts welded or rigidly joined into one physics body | [[Physics Assemblies and Constraints]] |
| **Attribute** | A typed custom value on an Instance; replicates and fires change events | [[Instances Attributes and Tags]] |
| **Audio API** | The newer audio graph: AudioPlayer, AudioEmitter, AudioListener, Wire, effects | [[The Audio API - Players Emitters Wires and Effects]] |
| **BindToClose** | Server shutdown callback; up to 30 s to save | [[Saving Correctly - Autosave and BindToClose]] |
| **Buffer** | Fixed-size mutable byte array in Luau | [[Buffers and Binary Data]] |
| **CanvasGroup** | A GUI container rendered as one image (fades, clipping) | [[ScreenGui Fundamentals]] |
| **CCU** | Concurrent users; many quotas scale with it | [[DataStore Fundamentals]] |
| **CollectionService** | Tags on Instances, used to attach behaviour to groups | [[CollectionService Patterns]] |
| **CollisionFidelity** | How exact a MeshPart's physics shape is | [[Collision and Physics Geometry]] |
| **Core loop** | The repeated action players do most, with its reward | [[Core Loops and Session Design]] |
| **D1 / D7 / D30** | Retention: share of new players returning on day 1, 7, 30 | [[Retention and Return Hooks]] |
| **DataStore** | Roblox's persistent key-value storage | [[DataStore Fundamentals]] |
| **Developer Product** | A repeatable purchase (currency, boosts), granted via ProcessReceipt | [[Developer Products and ProcessReceipt]] |
| **Draw call** | One batch sent to the GPU; fewer is faster | [[Art Budgets - Triangles Draw Calls Memory]] |
| **ECS** | Entity Component System architecture | [[Entity Component Systems]] |
| **FTUE** | First-time user experience | [[First-Time User Experience and Onboarding]] |
| **Game Pass** | A one-time purchase that grants a permanent perk | [[Game Passes]] |
| **Idempotent** | Safe to run twice with the same result (essential for receipts and installers) | [[Developer Products and ProcessReceipt]], [[Pipeline Design Principles]] |
| **Instance streaming** | Sending the world to clients in pieces around them | [[Instance Streaming]] |
| **Juice** | Feedback (shake, flash, sound, particles) that makes actions feel good | [[Game Feel and Juice]] |
| **Lease / session lock** | Marking a save as owned by one server so two can't overwrite each other | [[Session Locking and Profile Libraries]] |
| **LightingStyle** | Realistic or Soft lighting, replacing `Lighting.Technology` | [[Lighting Technologies and Settings]] |
| **LOD** | Level of detail: cheaper versions of distant things | [[Level of Detail and Model Streaming]] |
| **MaterialVariant** | A custom material that overrides or extends built-in ones | [[Materials MaterialVariants and SurfaceAppearance]] |
| **MCP** | Model Context Protocol: a standard way for AI clients to use tools such as Studio and Blender | [[What Is MCP]] |
| **MemoryStore** | Fast, temporary, cross-server storage (queues, sorted maps) | [[MemoryStore Service]] |
| **MessagingService** | Cross-server publish/subscribe messages | [[Cross-Server Messaging]] |
| **MicroProfiler** | Frame-by-frame CPU timing tool | [[MicroProfiler Guide]] |
| **Network ownership** | Which machine simulates a part's physics | [[Network Ownership]] |
| **Normal map** | A texture that fakes surface detail through lighting | [[Normal Maps and Detail Baking]] |
| **Open Cloud** | Roblox's web APIs (assets, data stores, publishing, Luau execution) | [[Open Cloud APIs]] |
| **PBR** | Physically based rendering: colour, normal, roughness, metalness maps | [[Texturing and PBR Baking]] |
| **Pity** | A guarantee after N unlucky rolls | [[RNG Drops and Luck Systems]] |
| **Pipeline** | A repeatable sequence of steps that turns source into in-game content | [[Pipeline Design Principles]] |
| **ProcessReceipt** | The callback that grants Developer Product purchases | [[Developer Products and ProcessReceipt]] |
| **ProfileStore / profile library** | A wrapper that adds session locking and safe saving on DataStores | [[Session Locking and Profile Libraries]] |
| **Rebirth / prestige** | Resetting progress for a permanent multiplier | [[Progression and Pacing Design]] |
| **RemoteEvent / RemoteFunction** | Client-server messages; UnreliableRemoteEvent drops instead of queueing | [[RemoteEvents RemoteFunctions and Unreliable Remotes]] |
| **Replication** | How server changes reach clients | [[Replication Rules]] |
| **Retopology** | Rebuilding a mesh with clean, low-poly topology | [[Retopology and Decimation]] |
| **Rojo** | Tool that syncs files on disk with Studio, enabling Git | [[External Tooling - Rojo Wally Selene StyLua]] |
| **RunContext** | Whether a Script runs on server, client or legacy rules | [[Script Types and Run Context]] |
| **Safe area / insets** | Screen space free of notches and the top bar | [[Safe Areas and Insets]] |
| **Server authority** | The server decides outcomes; clients only request | [[Server Authority and Validation]] |
| **Shapecast** | Sweeping a shape through space to find hits | [[Raycasts Shapecasts and Spatial Queries]] |
| **SurfaceAppearance** | PBR texture set on a MeshPart | [[Materials MaterialVariants and SurfaceAppearance]] |
| **Team Create** | Collaborative editing of one place | [[Team Create and Collaboration]] |
| **Telemetry** | Data the game reports about errors and player behaviour | [[Crash and Error Telemetry]], [[Analytics and Funnels]] |
| **Texel density** | Texture pixels per stud; keep it consistent | [[UV Unwrapping]] |
| **Topology** | How a mesh's polygons are arranged; decides how it deforms | [[Topology and Edge Flow]] |
| **Trim sheet** | One texture with reusable strips mapped onto many meshes | [[Trim Sheets Atlases and Vertex Colors]] |
| **UGC** | User-generated avatar items sold on the Marketplace | [[UGC Avatar Items and Accessories]] |
| **UV** | 2D coordinates mapping a texture onto a mesh | [[UV Unwrapping]] |
| **Wally** | Package manager for Luau libraries | [[External Tooling - Rojo Wally Selene StyLua]] |

See [[00 Start Here]].
