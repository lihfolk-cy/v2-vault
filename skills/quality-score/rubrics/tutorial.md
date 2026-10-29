# Rubric: tutorial / first-time user experience (FTUE)

Sources: skill `lihfolk-tutorial` and its `references/ftue-checklist.md`; vault notes "Onboarding and FTUE - Tutorials That Keep Players", "First-Time User Experience and Onboarding", "Measuring Onboarding - Funnels, Drop-off and A-B Tests". Evidence: a timed fresh-account playthrough recorded at phone (about 375 px wide) and PC sizes, one gamepad pass, the step list, and the server code. After launch, add the onboarding funnel.

## Hard gates
- A fresh account reaches control and the first objective with no error in the output, on phone, PC and gamepad
- Progress and rewards are decided on the server; the client can only report UI-only steps, which pay nothing that matters
- Progress is saved per step id: a rejoin mid-tutorial resumes, finished steps never show again, a failed data load never restarts the tutorial
- Skip exists (immediately for returning accounts) and leaves the player in the same state as finishing, rewards paid once
- No purchase prompt and no unskippable cutscene longer than about 5 seconds during onboarding
- Social play (joining, chatting, playing with friends) is never blocked by the tutorial

## Criteria (0 / 1 / 2)
| # | Criterion | W | 0 | 1 | 2 |
|---|---|---|---|---|---|
| T1 | Time to first meaningful action (from control) | 3 | over 45 s | 20 to 45 s | under 20 s |
| T2 | Teach by doing: one verb per step, objective text 8 words or fewer, no text walls or slideshows | 3 | reading-first | mostly doing | every step is an action |
| T3 | Reward pacing: first reward under 60 s, every step pays visibly, core loop completed once in the session | 3 | late or flat | some | early and every step |
| T4 | Guidance quality: one goal and one pointer at a time, exact targets, hints only when stuck, guidance fades with competence | 2 | cluttered or missing | ok | precise and adaptive |
| T5 | Progressive disclosure and hand-off: HUD revealed as taught, locked features visible, a next goal after the end | 2 | everything at once, dead end | partial | staged with a next goal |
| T6 | Device and accessibility: correct glyphs per device and on switch, safe areas, 44 px targets, colour plus shape, Reduced Motion honoured | 2 | wrong or missing | one device right | all devices right |
| T7 | Robustness: rejoin, death, two tutorial players in one server, step renamed after launch | 2 | breaks | some handled | all handled |
| T8 | Measurement: funnel per step (Joined to Finished), skip and hint events, versioned when steps change | 1 | none | partial | complete |
| T9 | Genre fit: the first five minutes match the genre pattern (feel, risk, social) | 1 | mismatched | ok | strong |
