# Rubric: VFX

Sources: VFX notes and the `roblox-vfx` playbook if installed. Evidence: a frame sequence or recording from Studio at game camera distance, plus particle counts.

## Hard gates
- Cleans itself up (Debris or explicit destroy); no leaking instances or connections
- Burst effects use `:Emit()`, not emitters left enabled
- Particle and light budget OK for mobile (stated counts)
- No invented asset ids

## Criteria (0 / 1 / 2)
| # | Criterion | W | 0 | 1 | 2 |
|---|---|---|---|---|---|
| X1 | Read at game distance (silhouette, shape language) | 3 | noise | ok | instantly readable |
| X2 | Timing layers (flash, then main shape, then secondary, then fade) | 3 | one blob | some layering | crisp sequence |
| X3 | Colour and value (core-to-edge gradient, dark contrast layer) | 2 | flat | ok | punchy |
| X4 | Motion quality (drag, size and transparency curves, no linear fades) | 2 | default curves | some tuning | polished |
| X5 | Sync with gameplay (markers, hit frame, sound) | 1 | off | close | exact |
| X6 | Reads as a frontal attack (slash arcs stay within about +-100 deg of the LookVector; debris and ground marks biased forward. Explosions, auras and dashes: radial or path-shaped is fine, score 2 unless they read as an attack behind the character) | 2 | full circle or behind the back | mostly in front, spills past ~110 deg | entirely in front |

## Rules
- Slashes play only in front of the character: no 360 rings or spins. Arcs 120 to 200 deg centred on the LookVector, from the weapon side across the front.
- Scores logged before X6 existed (weights summed to 11) are not directly comparable; recompute with X6 when re-scoring.
