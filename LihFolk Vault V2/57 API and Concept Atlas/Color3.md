---
tags: [atlas, api, type/atlas, area/vfx, area/ui, api/Color3]
---
# Color3

<!-- tldr:start -->
> [!tldr] TL;DR
> - `Color3` stores floats, but the Properties window shows and edits 0 to 255 integers.
> - Avoid: Feeding Roblox `Color3` sRGB numbers into Blender as linear values.
> - Tokens are attributes on a token `StyleSheet` (for example `Magenta = Color3`), referenced as `"$Magenta"`.
> - Palette built from `Color3.fromRGB` integers; exact equality preserved.
>
> Cost: TL;DR ~130 tok · whole note ~1.3k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`Color3` stores floats, but the Properties window shows and edits 0 to 255 integers. (from [[Voxel Palettes - Ramps Hue Shifting and Limits]])

API snapshot: Luau data type (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Feeding Roblox `Color3` sRGB numbers into Blender as linear values. ([[VFX Previews in Blender for Roblox - Colour and Framing]])
- Tokens are attributes on a token `StyleSheet` (for example `Magenta = Color3`), referenced as `"$Magenta"`. ([[UI Design Systems]])
- Palette built from `Color3.fromRGB` integers; exact equality preserved. ([[Voxel Palettes - Ramps Hue Shifting and Limits]])
- Through HSV, for hue sweeps such as a health bar going green to yellow to red: convert with `Color3:ToHSV()`, lerp hue along the shortest way round the wheel (hue wraps at 1), and rebuild with `Color3.fromHSV`. ([[Interpolation Easing and Curves Math]])

## Mentioned in

92 notes in 34 sections. The 25 most relevant are linked:

### 05 UI and UX
[[Accessibility]] · [[UI Design Systems]] · [[UI Style Directions - A Visual Vocabulary for Briefs]]

### 06 World Building and Art
[[Environment Art Styles]] · [[Zone and Biome Art Direction]]

### 07 Lighting VFX and Audio
[[Highlights and Selection Effects]] · [[Lighting Mood and Time of Day]] · [[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]] · [[Stylized Lighting Recipes]]

### 14 3D Modeling
[[Voxel and Blocky Modeling]]

### 15 AI Tools
[[AI Material and Texture Generation]]

### 17 Pipelines
[[Character and Creature Pipeline]] · [[UI Asset Pipeline]]

### 24 Worked Builds
[[Daily Rewards System End to End]] · [[Pet Hatching and Following End to End]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]]

### 40 Game Math
[[Interpolation Easing and Curves Math]]

### 42 Accessibility and Inclusive Design
[[Colour-Blind Safe Design]]

### 52 Core Concepts
[[Accessibility Contrast]]

### 53 Voxel Modelling Deep Dive
[[Voxel Palettes - Ramps Hue Shifting and Limits]]

### 54 Untextured Stylised Modelling
[[Keeping a Mixed Asset Library Consistent]] · [[Lighting Untextured Art in Roblox]]

### 55 Modelling Nuance and Readability
[[Style Bibles for Consistent Models]]

### 58 Player QoL and Game Tweaks
[[Colourblind Palettes Text Size and Tooltips]]

Also mentioned in (not linked): AI Pitfalls - Data and Monetization · Ability Kits Architecture · Art Pipeline - Concept to In-Game Asset · Atmosphere Sky Clouds and Post-Processing · Beams and Trails · Big Numbers Precision and Formatting · Camera Shake and Camera FX · Captions and Audio Accessibility · Choosing GUI 2D or Locked-Camera 2.5D · Codes Redemption System End to End · CollectionService Patterns · Colour Scripts and Value Structure for Untextured Art · Data Schema Design and Migrations · Data and Config Pipeline - Spreadsheets to Game · Debugging UI Layout and Input · Declarative UI - React-Lua and Fusion · Developer Console and Stats · Documentation and Knowledge Bases · EditableImage for Pixel Buffers and Procedural 2D · Engine and API Changes 2025-2026 · Explorer Properties and Selection · Feedback - Autosave Indicator Ping Display and Error Toasts · Game Feel and Juice · Grid Placement and Player Building Systems · HumanoidDescription and Outfit Systems · Instances Attributes and Tags · Inverse Kinematics · Juice on a Budget - Mobile and Low-End · Light Sources and Shadows · Luau Garbage Collection and the Memory Model · Materials MaterialVariants and SurfaceAppearance · Melee Combat System End to End · Memory Budgets and Leaks · Menu Archetypes - Shop Settings Codes Rewards · Metatables and OOP - When and When Not · Packages and Asset Reuse · Pipeline Design Principles · Quest Chain System End to End · Racing Laps and Checkpoints End to End · RemoteEvents RemoteFunctions and Unreliable Remotes · Replication Rules · Safe Areas and Insets · Safe Changes in a Shared Place · ScreenGui Fundamentals · Selection Editing and Bulk Tools · Serialization Formats for Saves and Networking · Shape Language and Silhouette Testing · Slash VFX Recipes - Crescent and Ring · Snippets - Camera Shake and FX · SurfaceAppearance PBR Workflow · Teaching Through Level Design · Terrain Deep Dive - Materials Water and Performance · Terrain Materials and Painting · Testing Your Own Remotes - Fuzzing and Abuse Tests · Textures Decals and Texture Memory · Tiling Trim Sheets and Decal Tricks · Trim Sheets Atlases and Vertex Colors · Tween and CFrame Animation of Objects · Tycoon Plots and Droppers End to End · UI and GUI Animation · VFX Design Playbook · VFX Previews in Blender for Roblox - Colour and Framing · Visual AI Debugging - State Labels, Path Lines and Perception Gizmos · Voxel Art - Studs Outlines and Style Kits · Voxel Shading - Baked AO Edges and Lighting · Water Sky and Atmosphere Art · World-Space UI - BillboardGui and SurfaceGui

<!-- atlas:generated -->
