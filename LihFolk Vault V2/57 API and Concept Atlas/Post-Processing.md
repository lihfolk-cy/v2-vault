---
tags: [atlas, concept, type/atlas, area/vfx, area/world]
---
# Post-Processing

<!-- tldr:start -->
> [!tldr] TL;DR
> - Post-processing is what makes rendered icons read at 64 px in a busy grid.
> - Avoid: Studio-only lighting or post-processing the live game does not have.
> - Phone drops frames on rewards only: Full-screen glows and post-processing -> Substitutes on low tiers; smaller, more opaque...
> - Personal effects (low-health tint, ultimate grade) belong in the camera, managed by a priority stack (Atmosphere Sky Clouds...
>
> Cost: TL;DR ~140 tok · whole note ~930 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Post-processing is what makes rendered icons read at 64 px in a busy grid. (from [[Icon and Thumbnail Rendering Pipeline]])

## Key facts

- Avoid: Studio-only lighting or post-processing the live game does not have. ([[Game Trailers and Clean Footage - Capture, Freecam and Editing]])
- Phone drops frames on rewards only: Full-screen glows and post-processing -> Substitutes on low tiers; smaller, more opaque effects. ([[Juice on a Budget - Mobile and Low-End]])
- Personal effects (low-health tint, ultimate grade) belong in the camera, managed by a priority stack (Atmosphere Sky Clouds and Post-Processing), so a zone change never overwrites them. ([[Stylized Lighting Recipes]])
- Atmosphere Sky Clouds and Post-Processing, Lighting Technologies and Settings, Lighting Mood and Time of Day, Light Sources and Shadows. ([[Water Sky and Atmosphere Art]])

## Mentioned in

46 notes in 26 sections. The 25 most relevant are linked:

### 06 World Building and Art
[[Art Budgets - Triangles Draw Calls Memory]] · [[Water Sky and Atmosphere Art]] · [[Zone and Biome Art Direction]]

### 07 Lighting VFX and Audio
[[Atmosphere Sky Clouds and Post-Processing]] · [[Lighting Mood and Time of Day]] · [[Lighting Technologies and Settings]] · [[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]] · [[Stylized Lighting Recipes]] · [[Weather System Architecture - State Machine, Transitions and Replication]]

### 09 Gameplay Systems
[[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]]

### 16 MCP and Agents
[[Blender MCP]] · [[Case Study - Building a Game with AI Agents]]

### 17 Pipelines
[[Icon and Thumbnail Rendering Pipeline]]

### 27 Marketing and Growth
[[Game Trailers and Clean Footage - Capture, Freecam and Editing]]

### 32 Case Studies of Top Roblox Games
[[Case Study - Fisch]]

### 42 Accessibility and Inclusive Design
[[Colour-Blind Safe Design]]

### 45 Procedural Blender Assets
[[Dramatic Showcase Renders in Eevee]]

### 46 Resource Library
[[Official Docs - Visual Effects]]

### 47 Game Feel and Juice
[[Juice on a Budget - Mobile and Low-End]]

### 49 Roblox Platform Features
[[Photo Mode and In-Game Screenshots with CaptureService]]

### 51 2D Game Development
[[Choosing GUI 2D or Locked-Camera 2.5D]]

### 52 Core Concepts
[[Accessibility Contrast]]

### 54 Untextured Stylised Modelling
[[Colour Scripts and Value Structure for Untextured Art]]

### 55 Modelling Nuance and Readability
[[Critiquing a Model - Paintovers and Iteration]]

### 61 Thumbnails and CTR
[[Making Thumbnails in Studio and Blender - Capture, Lighting and Posing]]

Also mentioned in (not linked): 00 Start Here · Accessibility Start Here · Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning · Environment Art Styles · First-Person Viewmodels - Arms Rig, Sway and Camera Binding · Genre Playbook - Horror and Story · Hand-Painted and Stylized Texturing · Level Design Principles - Flow Sightlines and Landmarks · Lighting Untextured Art in Roblox · Lightning Strikes and Thunder - Procedural Bolts and Sound Delay · Materials and Surfaces Start Here · Menu Archetypes - Shop Settings Codes Rewards · Music and Adaptive Audio · Procedural Materials and Skies - Lessons · Rain - Camera-Local Particles, Splashes and Wet Surfaces · Shape Language and Silhouette Testing · Snow, Sandstorm, Blizzard and Ash Recipes · Terrain Deep Dive - Materials Water and Performance · Thumbnail Specs, Rules and Upload - Sizes, Count and Policy · Thumbnails Icons and Store Page · Voxel Shading - Baked AO Edges and Lighting

<!-- atlas:generated -->
