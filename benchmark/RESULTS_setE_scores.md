# LihFolk Benchmark e1

## Set E (24 tasks, 66 points, 3 graders)

| Setup | Mean score | 95% CI (tasks bootstrap) | Accuracy | Runs | Time / run | Tokens / run |
|---|---:|---:|---:|---:|---:|---:|
| cur | 60.7 / 66 (±0.5) | 88-98% | 91.9% | 2 | 219 s | 87k |
| plain | 55.7 / 66 (±0.2) | 77-94% | 84.3% | 2 | 134 s | 76k |
| v240 | 60.5 / 66 (±0.3) | 87-98% | 91.7% | 2 | 239 s | 91k |

| Category | cur | plain | v240 |
|---|---:|---:|---:|
| architecture | 11.0/11 | 9.8/11 | 10.8/11 |
| code-writing | 13.5/14 | 13.5/14 | 13.5/14 |
| debugging | 14.0/14 | 13.5/14 | 14.0/14 |
| performance-networking | 9.2/10 | 8.8/10 | 9.2/10 |
| recent-platform | 13.0/17 | 10.1/17 | 13.0/17 |

Grader agreement: mean |difference| between graders = 1.6% of task points (lower is better).
