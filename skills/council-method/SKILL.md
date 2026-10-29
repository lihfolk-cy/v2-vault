---
name: council-method
description: 'LihFolk Council: blind multi-agent verdict for high-stakes Roblox decisions, ship-readiness, "be objective", "second opinion". Not for routine coding.'
---

# LihFolk Council

One model answering alone anchors on its first idea, agrees with the user and grades its own work generously. The council removes those biases structurally. It costs extra agents, so **pick the smallest tier that fits** and say which tier you used.

## Pick a tier

| Tier | When | Cost | Shape |
|---|---|---|---|
| **Quick** (default) | Most judgment calls: comparing 2-3 options, reviewing one asset or screenshot set, "is this good?" | 1 agent | One `council-member` with the **Skeptic** lens, blind to your answer, then you reconcile |
| **Standard** | Real stakes: economy numbers, art direction, launch readiness, architecture that is hard to undo | 3 agents | 3 blind seats in parallel; you rank anonymized answers against the rubric (no separate reviewer round) |
| **Full** | Only when the user asks for the full council, or a decision is costly to reverse (pricing a live game, public release) | 5 + 2 + 1 | All 5 seats, 2 anonymized reviewers, 1 `council-chair` |

Escalate one tier only when the lower tier comes back split or low-confidence. Never run Full on a whim.

## Every tier: frame first (no extra cost)

- Restate the question neutrally. Strip the user's preferred answer, your own leaning and any loaded wording ("isn't X better?" becomes "compare X and Y").
- Fix a 3-5 point rubric **before** seeing any answer (e.g. player experience, correctness/security, performance, cost to build, fit with the game).
- Gather evidence once and pass the same pack to every seat: the files, screenshots and Studio state, plus **the 2-3 most relevant note excerpts** (their Common mistakes / Checklist sections), never whole notes or folders. Keep the pack short; every seat pays for it.
- Start every seat's prompt with `VAULT=<absolute path>`: the plugin root's `LihFolk Vault V2` folder, resolved from this skill's base directory (`<base directory>/../../LihFolk Vault V2`), so seats can open a cited note.

## Quick

Write your own answer first, privately. Spawn one `council-member` (lens: Skeptic) with the framed question, rubric and evidence. It doesn't see your answer. Then compare the two. Where they disagree, the side with evidence wins. Report the verdict, the strongest objection and whether it changed your answer.

## Standard

Spawn 3 `council-member` agents **in one message, in parallel**. Pick the lenses that fit:
- **Player Advocate:** fun, clarity, onboarding, a 12-year-old on a phone.
- **Systems Engineer:** correctness, security, performance, data safety.
- **Art Director:** visual quality, readability, cohesion. For world, UI or model questions.
- **Producer:** scope, cost, risk, what to cut.
- **Skeptic:** assumes the obvious answer is wrong. Always include this seat.

Shuffle the answers as A, B, C, then score each against the rubric yourself, judging content, not length. Report the score table, the verdict, any dissent and your confidence.

## Full

Standard with all 5 seats, plus 2 fresh `council-member` reviewers that score the anonymized answers (each must name the best point of its lowest-ranked answer and the worst flaw of its highest), plus a `council-chair` to synthesize.

## Rules

- Evidence beats eloquence. A claim backed by Roblox docs, a note or a measurement outranks a confident claim without one.
- For built work, seats inspect the real artifact (screenshots, scripts), never a description of it.
- Stop early if the Quick seat agrees and the evidence is solid. Don't pad.
- Honest limit: the seats share a model family, so the council reduces bias without removing it. Playtest data and Roblox docs override it.
