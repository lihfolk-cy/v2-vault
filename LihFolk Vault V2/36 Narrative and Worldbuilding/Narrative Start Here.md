---
cssclasses: [vault-hub]
tags: [narrative, worldbuilding, index, start-here, writing, dialogue, type/hub, area/narrative, level/beginner, area/world]
---
# Narrative Start Here

This folder is about the words in a Roblox game: what NPCs say, how quests are phrased, how a world's history reaches players who never read, what things are called, and how all of it survives translation. Its audience is young, mostly on phones, often reading in a second language, and came to play rather than read. Roblox's own onboarding guidance notes that players often skip text (Roblox docs, as of October 2026). Every note here starts from that fact.

Older notes that touch the same ground, and that these notes build on rather than repeat, are listed at the end.

## The notes

- [[Writing Dialogue for Roblox Players]]: who is reading and how fast, word budgets per screen, giving a character a voice in eight words, choices that are real, branching shapes you can afford, barks, dialogue in a shared server, and a ten-step editing pass.
- [[Dialogue System End to End]]: a full `--!strict` build of a server-driven, branching, localisable dialogue system. Trees as server-only data, screen tokens against stale and replayed clicks, named conditions and effects, a validator, a typewriter on `MaxVisibleGraphemes` that respects reduced motion, and a test plan.
- [[Lore Delivery Without Walls of Text]]: three layers of readers (surface, curious, obsessed), channels other than text, one-line lore craft, a codex that keeps spoilers on the server, title cards and signs, mysteries and rumours, a lore bible, and when not to write lore at all.
- [[Quest Writing and Hooks]]: the seven pieces of quest text, hook types, the objective-line formula (verb, count, target, place), the three-beat quest with a mid-quest complication, chains as arcs, writing for the hundredth read of a daily, and return hooks that keep their promises.
- [[Naming Items Zones and Abilities]]: what a name must do, patterns that scale to large catalogues, names as a rarity ladder, zone and ability naming, length and distinctness budgets, ids versus display names versus instance names, legal and cultural risk, the chat filter, and a name validator.
- [[Localization-Ready Writing]]: complete sentences with named placeholders, plurals without plural support, writing around grammatical gender, names inside sentences in inflecting languages, ambiguous short words, idioms and puns, a style guide and glossary, and a source-string lint.

## Suggested reading order

1. Writers and designers: start with [[Writing Dialogue for Roblox Players]], then [[Quest Writing and Hooks]] and [[Naming Items Zones and Abilities]].
2. Scripters: read [[Dialogue System End to End]], then [[Localization-Ready Writing]] for the reasons behind its text format.
3. Anyone shipping to a global audience: [[Localization-Ready Writing]] before writing anything else.
4. Story-heavy games: [[Lore Delivery Without Walls of Text]] alongside [[Genre Playbook - Horror and Story]].

## Rules that run through every note

- **Every word costs about half a second of attention** for this audience. Budget words like you budget triangles.
- **A player who skips every line must still know what to do next.** Text adds; it never carries the only copy of an instruction.
- **Text travels as keys plus an English default** and is translated on each player's client.
- **Anything replicated can be read.** Secrets, spoilers and gated branches stay on the server.
- **Names, ids and instance names are three different things.** Saves store ids.

## Related older notes

- Quests: [[Quests and Objectives]] (the machinery), [[Quest Chain System End to End]] (a full build).
- Translation plumbing: [[Localization]] (platform features and APIs), [[Localization Pipeline]] (keys, CSV, checks, import).
- Story games: [[Genre Playbook - Horror and Story]].
- Onboarding text: [[First-Time User Experience and Onboarding]].
- Generated dialogue: [[In-Game AI - LLM NPCs and Text Generation]].
- Text rendering and chat: [[Text Fonts and Rich Text]], [[Text Chat Customization with TextChatService]].
- Cutscenes and NPC presence: [[Cameras and Cutscenes]], [[Enemy and NPC Animation]], [[Facial Animation and Dynamic Heads]].
- World and naming context: [[Zone and Biome Art Direction]], [[Level Design for Roblox]], [[Rarity Ladders and Drop Pacing Math]], [[Data and Config Pipeline - Spreadsheets to Game]].
- Player trust and audience: [[Ethical Design and Player Trust]], [[Accessibility]], [[Roblox Policies Ratings and Compliance]].

Back to [[00 Start Here]].

## Connected notes
<!-- auto-links:start -->
[[Accessibility Start Here]] · Links - Quests and progression · Captions and Audio Accessibility · Onboarding Funnel · Links - Chat and text filtering · Links - NPCs and AI
<!-- auto-links:end -->
