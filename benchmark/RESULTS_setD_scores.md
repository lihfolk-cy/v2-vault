# LihFolk Benchmark d1

## Set D (24 tasks, 66 points, 3 graders)

| Setup | Mean score | 95% CI (tasks bootstrap) | Accuracy | Runs | Time / run | Tokens / run |
|---|---:|---:|---:|---:|---:|---:|
| cur | 61.8 / 66 (±0.5) | 89-98% | 93.7% | 2 | 239 s | 93k |
| plain | 57.7 / 66 (±0.1) | 82-94% | 87.4% | 2 | 150 s | 77k |
| v240 | 61.8 / 66 (±0.8) | 90-97% | 93.7% | 2 | 216 s | 86k |

| Category | cur | plain | v240 |
|---|---:|---:|---:|
| architecture | 10.3/12 | 9.6/12 | 10.2/12 |
| code-writing | 14.8/15 | 14.5/15 | 14.4/15 |
| debugging | 12.0/13 | 13.0/13 | 12.2/13 |
| performance-networking | 10.0/11 | 9.0/11 | 10.2/11 |
| recent-platform | 14.8/15 | 11.6/15 | 14.8/15 |

Grader agreement: mean |difference| between graders = 1.4% of task points (lower is better).
