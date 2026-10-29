# LihFolk Benchmark v1 (2026-10-28)

24 Roblox tasks, 64 points, answer keys verified against primary sources (Roblox Creator Docs, official DevForum, Roblox newsroom; Blender manual for one export task). Both arms are the same model; 3 independent blind graders scored the shuffled responses (labels X/Y randomised per task); median per task.

| Setup | Score | Accuracy | Time | Tokens |
|---|---:|---:|---:|---:|
| **Claude + LihFolk Vault V2** | **61.8 / 64** | **96.6%** | 470 s | 134k |
| Plain Claude | 45.4 / 64 | 70.9% | 242 s | 81k |

| Category | Plain | LihFolk | Max |
|---|---:|---:|---:|
| Post-training changes (2025-2026) | 7.9 | 22.6 | 23 |
| Classic gotchas | 18.5 | 18.7 | 20 |
| Practical tasks | 19.0 | 20.5 | 21 |

Reading it honestly:
- The gain is almost entirely knowledge the base model can't have (2025-2026 platform changes): +14.7 points there, about level on evergreen gotchas.
- LihFolk costs about 1.9x the time and 1.7x the tokens (48 vault lookups across 24 tasks).
- One task got slightly worse with LihFolk (G7, Blender glTF export: 1.3 vs 1.7 of 2).
- Limits: one run per arm; both arms ran as subagents in the same environment (the plain arm was instructed not to use the vault); 8 of 24 tasks target post-training changes, which favours any up-to-date knowledge source.