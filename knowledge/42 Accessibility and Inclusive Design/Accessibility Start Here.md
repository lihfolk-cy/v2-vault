---
cssclasses: [vault-hub]
tags: [accessibility, hub, inclusive-design, colour-blindness, text, motion, captions, input, difficulty]
---
# Accessibility Start Here

This section is about making Roblox games playable by more people: players with low vision or colour blindness, players who get motion sick, deaf and hard-of-hearing players, players with limited dexterity or one usable hand, and players who find busy games overwhelming. It also helps the player on a small phone in sunlight or on a muted bus ride.

It builds on three older notes. Read them first; the notes here go deeper without repeating them.

- [[Accessibility]]: the three Roblox player preferences, contrast, colour and sound non-reliance, flashing, and a settings group.
- [[Responsive UI for Phone Tablet Console and PC]]: device classes and the measured phone rules.
- [[Gamepad and Console UX]]: selection, focus and ten-foot UI.

## The six notes

| Note | Who it serves | Key ideas |
|---|---|---|
| [[Colour-Blind Safe Design]] | Colour-blind players (and anyone on a washed-out screen) | Deficiency types, redundant encoding, a palette audit with simulation matrices and Oklab distance, semantic tokens with palette modes, why a `ColorCorrectionEffect` filter cannot fix it, telegraphs that read in greyscale |
| [[Readable Text and UI Scale]] | Low-vision players, young readers, TV and phone players | Physical size targets per device, how preferred text size, device `UIScale` and a player UI slider multiply, layouts that grow, type and outline choices, world-space text, an automated `TextFits` audit |
| [[Motion Sensitivity and Camera Comfort]] | Players prone to motion sickness, vestibular and photosensitive players | Why players get sick, a comfort settings module with overrides, FOV ranges and one owner, a camera motion budget, speed vignette, horizon-locked vehicle camera, a flash gate under the three-per-second guideline |
| [[Captions and Audio Accessibility]] | Deaf and hard-of-hearing players, muted sessions | Subtitles vs sound captions, timing and layout rules, a caption queue with merging, priority and direction, directional indicators that stay fair, volume categories, `HapticEffect`, text to speech |
| [[Input Remapping and One-Handed Play]] | Players with limited dexterity, one-handed and adaptive-controller players | CAS vs Input Action System for remapping, a shared schema with server sanitising, capture with swap on conflict, hold/toggle wrapper, layout-aware labels, one-handed presets, movable touch layouts |
| [[Difficulty Options and Cognitive Load]] | Players who struggle with speed, memory or overwhelm | Assists as separate dials, how multiplayer changes difficulty, server-authoritative assists, fair leaderboards, adaptive help that offers rather than imposes, cutting cognitive load, rest in a world that never pauses |

## Suggested reading paths

- **Short on time:** the checklists at the end of each note.
- **UI designer:** Readable Text, then Colour-Blind Safe Design. Pair with [[UI Design Systems]], [[Text Fonts and Rich Text]] and [[Safe Areas and Insets]].
- **Combat or action programmer:** Motion Sensitivity, Input Remapping, then Difficulty Options. Pair with [[Camera Shake and Camera FX]], [[Camera Systems]], [[Input - UserInputService and ContextActionService]] and [[Combat Systems Architecture]].
- **Audio and narrative:** Captions and Audio, then the cognitive load half of Difficulty Options. Pair with [[Spatial Audio and Mixing]], [[Sound Design for Games]], [[Dialogue System End to End]] and [[Lore Delivery Without Walls of Text]].
- **Designer or producer:** Difficulty Options first, then skim every checklist. Pair with [[First-Time User Experience and Onboarding]], [[Ethical Design and Player Trust]] and [[Analytics and Funnels]].

## Related notes elsewhere in the vault

- Motion and feel: [[UI and GUI Animation]], [[UI Motion Language and Timing]], [[Game Feel and Juice]], [[Cameras and Cutscenes]].
- Visual signals: [[Highlights and Selection Effects]], [[VFX Design Playbook]], [[Rarity Ladders and Drop Pacing Math]], [[Atmosphere Sky Clouds and Post-Processing]].
- Text and language: [[Localization]], [[Localization-Ready Writing]], [[Text Chat Customization with TextChatService]].
- Settings that persist: [[Data Schema Design and Migrations]], [[Saving Correctly - Autosave and BindToClose]].
- Testing: [[Multi-Client and Device Playtesting Protocols]], [[QA Checklists Before Release]].

## Conventions used in this section

Engine facts are labelled "Roblox docs (as of October 2026)" and should be rechecked, since accessibility APIs have changed quickly. Design numbers are "rule of thumb", and lessons from one production game are "measured in the reference project". Code is strict Luau; anything that changes gameplay is validated on the server. Most players never open settings, so the default game should already pass the checklists.

## Connected notes
<!-- auto-links:start -->
[[Accessibility Contrast]] · [[Narrative Start Here]] · [[Game Feel Start Here]] · [[Snippets - Camera Shake and FX]] · [[Safe Area]] · [[Skill - Roblox UI Builder]]
<!-- auto-links:end -->
