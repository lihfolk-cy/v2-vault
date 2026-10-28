---
tags: [careers, portfolio, freelancing, job-search, showcase, minors]
---
# Building a Portfolio as a Roblox Developer

> **Not advice.** General career information. It is not legal or financial advice; job markets, contracts and working-age rules differ by country. If you are under 18, involve a parent or guardian before taking paid work or signing anything, and keep your personal information private.

A portfolio is the evidence that you can do the job. On Roblox, where most hiring happens through forums, Discord servers and referrals rather than formal applications, it often *is* the application. This note covers what to put in one for each discipline, how to show work you cannot share, how to present systems that are invisible in screenshots, and how to avoid the mistakes that make good developers look weak.

Related: [[Commissions Pricing and Contracts]] (getting paid), [[Hiring Freelancers and Revenue Shares]] (what clients look for), [[Running a Small Studio as a Business]].

---

## 1. What a hiring person actually checks

From the client's side ([[Hiring Freelancers and Revenue Shares]]), a portfolio answers four questions in under two minutes:

1. **Can they make work like mine?** Style, genre, platform (phone-friendly?), scale.
2. **Is it shipped?** Work in live games has met real players, exploiters and phones.
3. **What exactly did they do?** In team projects, their part.
4. **Can they communicate?** Clear captions, process notes, honest limits.

Everything below serves those four questions. Rule of thumb: a portfolio with six strong, relevant pieces beats one with forty mixed ones.

---

## 2. Format and where to host it

| Format | Strengths | Weaknesses |
|---|---|---|
| A single web page (personal site or a portfolio platform) | You control the order and captions | Needs upkeep |
| A DevForum portfolio post | Where many Roblox clients look | Formatting limits; buried over time |
| A video reel (60 to 120 seconds) | Fastest way to show motion, VFX, animation, UI flow | Hard to show code or process |
| A playable showcase place | Clients can feel the work | Must be maintained and safe to leave public |
| A code repository | Shows code quality, structure, tests | Only scripters' clients read it |

Most developers use one hub (a page) that links to a reel, a showcase place and, for scripters, a repository. Keep the hub's first screen focused on the best three pieces.

### Contact and privacy

- Use a professional handle and a contact method that does not reveal your real name, address, school or age if you do not want to. Many respected Roblox developers work under a handle.
- If you are under 18, have a parent or guardian aware of how clients contact you. Never move conversations to private apps because a client asks; real clients do not need that ([[Commissions Pricing and Contracts]]).
- Do not publish other people's personal information, private Discord messages, or client details you agreed to keep confidential.

---

## 3. By discipline: what to show

### Scripters and systems programmers

Systems are invisible in screenshots, so show behaviour and structure.

- **Short videos of systems working**, with on-screen labels: "server validates claim, rejects second claim within cooldown".
- **A written breakdown** per system: the problem, the architecture (a diagram of client, server, data), key decisions and trade-offs, numbers (players per server, bandwidth, memory), what you would change. Linking the concepts you applied shows depth: [[Server Authority and Validation]], [[Session Locking and Profile Libraries]], [[Remote Abuse Patterns and Rate Limiting in Practice]].
- **Code samples** you own: a clean module with types, tests and comments ([[Luau Type System and Strict Mode]], [[Automated Testing with TestEZ and Jest-Lua]]). One well-structured module says more than 5,000 lines of game code.
- **Performance work**: before and after numbers from the MicroProfiler or developer console ([[MicroProfiler Guide]], [[Case Study - Instance Cleanup and Place Size]] is an example of the format).

Do not post code from client projects unless you have permission, and never post anything with secrets (API keys, webhook URLs).

### Builders and environment artists

- Wide shots, then closer shots, then gameplay view (camera at character height). Clients play at character height; a map that only looks good from the sky is a warning sign.
- **Budgets**: part and mesh count, triangle counts, texture memory, performance on a phone ([[Art Budgets - Triangles Draw Calls Memory]], [[Mobile and Low-End Optimization]]).
- Before and after lighting passes ([[Stylized Lighting Recipes]]).
- A playable showcase place, kept small and safe (no free models with scripts: [[Creator Store and Toolbox Safety]]).

### 3D modellers

- Turntables, wireframes (topology), UV layouts and texture sheets ([[Topology and Edge Flow]], [[UV Unwrapping]]).
- Triangle counts and the in-Roblox result, not just renders from Blender. Clients worry about what it looks like in-engine.
- For UGC creators: items that passed validation and their constraints ([[UGC Avatar Items and Accessories]]).

### Animators

- A reel with each clip looped two or three times, at game camera distance.
- Show game-ready work: combat sets with clear anticipation and recovery, locomotion that loops, timing charts ([[Combat Animation Craft]], [[Timing Spacing and Frame Charts]]).
- Show it on the rigs games use (R15, custom rigs) ([[R15 Rig Anatomy and Attachments]]).

### UI and UX designers

- Full flows, not single screens: open shop, buy, confirmation, error.
- Phone, tablet and PC layouts side by side ([[Responsive UI for Phone Tablet Console and PC]]).
- Motion: a short video of transitions ([[UI Motion Language and Timing]]).
- Design system pages: colours, type, components ([[UI Design Systems]]).

### VFX artists

- Video at game speed and slowed down.
- Performance budgets: particle counts, emitters, culling approach ([[VFX Performance Budgets and Culling]]).
- Readability in a crowd and on a phone.

### Game designers and producers

- Design documents (redacted as needed), economy spreadsheets, retention analyses ([[Balancing with Spreadsheets and Data]], [[Analytics and Funnels]]).
- Post-mortems with honest lessons ([[Post-Mortem - Building a Melee Action Game]] shows the shape).

---

## 4. Showing work you cannot share

Much professional work is under confidentiality. Options, in order of preference:

1. **Ask.** Many clients allow showing work after release, or showing a short clip without their branding. Get it in writing.
2. **Rebuild the idea** in your own test place, from scratch, without their assets or code. A daily rewards system you rebuilt is yours; their exact UI art is not.
3. **Describe it** with numbers: "built the save system for a game with N concurrent players; zero data loss incidents over six months". Only if the client allows mentioning the work at all, and without naming them if they prefer.
4. **Leave it out.** Never show confidential work without permission. Getting caught ends client relationships across a small community.

Price confidentiality into contracts that forbid showing work ([[Commissions Pricing and Contracts]]).

---

## 5. Stating your role honestly

Inflated claims are the fastest way to lose trust, because the Roblox developer community is small and clients check.

| Weak | Strong |
|---|---|
| "Developer on a game with 100M visits" | "Built the pet inventory and trading UI (client side) for a game with 100M visits; the server side was another developer's" |
| "Worked on combat" | "Wrote the server hit validation and the lag compensation for melee; reduced false rejections from 6% to under 1% measured over a week" |
| "Made the map" | "Built the forest and cave zones (2 of 6) and did the final lighting pass" |

Visit numbers are context, not skill. A small game with a clean, well-explained system you wrote alone can be stronger evidence than a famous game you touched briefly.

### AI-assisted work

If AI tools helped (code assistants, texture generation, mesh generation), say how. Clients increasingly ask, and Roblox has its own rules about AI-generated content ([[Roblox Policies on AI-Generated Content]], [[AI in Roblox Development Overview]]). Show the parts you directed, reviewed and fixed. Passing off generated work as hand-made damages trust when discovered.

---

## 6. A strong portfolio piece, step by step

Template for one piece:

```
Title: Saved inventory with trading (systems, solo)
Context: Simulator-style game, ~2,000 concurrent players at peak
My role: All server and client code; UI art by another artist
Problem: Duplication exploits and lost items on server shutdown
Approach: session-locked profiles, atomic trade transactions,
          server-side validation of every trade step
Results: no confirmed duplications in 4 months; save failures under 0.01%
Media: 60 s video (trade flow, failed exploit attempt), architecture diagram
What I would change: move trade logs to a separate store earlier
Links: video, diagram, related code sample
```

Why it works: it answers all four questions from section 1, uses numbers, credits others, and shows judgement ("what I would change"). For the technical depth behind such a piece, see [[Trading Systems Without Duplication]] and [[Saved Inventory End to End]].

---

## 7. Starting with no clients

Everyone starts with no paid work. Ways to build a first portfolio that clients take seriously:

- **Build complete small things.** One finished, polished system or zone is worth more than ten half-done ones. The [[Worked Builds Start Here]] section has full systems to study and rebuild in your own way.
- **Ship a small game.** Even a modest one proves you can finish, publish and handle real players ([[Publishing an Experience]]).
- **Game jams.** Time-boxed, team-based, with a shipped result.
- **Open-source contributions** to community libraries (scripters).
- **Recreate a feature you admire** as a study, clearly labelled as your own recreation and without copying assets, names or branding ([[Legal Basics - IP Licenses and Assets]]).
- **Document your learning.** A short write-up of how you solved a hard bug shows debugging skill ([[The Debugging Method - Reproduce Isolate Bisect]]).

Avoid working for free for strangers' "big projects" in exchange for exposure. Most never launch; you get no portfolio piece and no pay.

---

## 8. Keeping it current

- Review the portfolio every three months: remove the weakest piece, add the newest strong one.
- Update numbers (players, results) when they change, with dates.
- Check every link and showcase place works; a broken showcase place is worse than none.
- Remove anything you no longer have permission to show.

---

## 9. From portfolio to career

The portfolio opens doors; how you work keeps them open.

- **Reliability** is the most valued trait in a freelance market: meeting deadlines, answering messages, telling clients early about problems.
- **Specialise, then broaden.** Being known for one thing (combat systems, phone UI, low-poly environments) brings referrals. Breadth comes later.
- **Rates rise with evidence.** Each strong, shipped piece with numbers justifies a higher rate ([[Commissions Pricing and Contracts]]).
- **Beyond Roblox.** Skills transfer: Luau to other scripting languages, Blender modelling to any engine, UI design anywhere. A portfolio framed around skills and results, not only Roblox visit counts, reads well to studios outside Roblox too. Whether outside studios value Roblox experience varies by employer; present it as professional game development with real players and real constraints.

---

## Common mistakes

- Forty pieces of uneven quality instead of six strong ones.
- Renders without in-game views; maps without gameplay camera shots.
- Systems shown only as screenshots; no explanation of how they work.
- Claiming a whole game when you did part of it.
- Showing confidential client work without permission.
- Personal information on the portfolio; private contact for young developers.
- Broken links and dead showcase places.
- Free models with scripts in showcase places.
- Copying another game's assets or branding for a "recreation".
- Unpaid "exposure" work as the main source of pieces.

## Checklist

- [ ] One hub page; best three pieces first.
- [ ] Each piece: context, your role, problem, approach, numbers, media, lessons.
- [ ] Discipline-specific evidence (budgets, wireframes, code, flows, reels).
- [ ] Permission recorded for any client work shown.
- [ ] Honest role statements; AI assistance disclosed.
- [ ] No personal information; parent or guardian aware if under 18.
- [ ] Showcase places safe, small and working.
- [ ] Reviewed every three months.

## See also

[[Business and Careers Start Here]], [[Commissions Pricing and Contracts]], [[Hiring Freelancers and Revenue Shares]], [[Legal Basics - IP Licenses and Assets]], [[Running a Small Studio as a Business]], [[Worked Builds Start Here]], [[Publishing an Experience]], [[Lessons Learned Index]], [[Documentation and Knowledge Bases]]

## Connected notes
<!-- auto-links:start -->
[[DevEx and Cashing Out]] · [[Groups Roles and Permissions for Studios]] · [[Team Collaboration Start Here]] · [[Publishing Selling and Updating Plugins]] · [[Documentation and Onboarding New Developers]] · [[Working with Content Creators]]
<!-- auto-links:end -->
