# LihFolk Benchmark c1

## Set C (24 tasks, 66 points, 3 graders)

| Setup | Mean score | 95% CI (tasks bootstrap) | Accuracy | Runs | Time / run | Tokens / run |
|---|---:|---:|---:|---:|---:|---:|
| cur | 60.2 / 66 (±0.8) | 87-97% | 91.3% | 2 | 210 s | 84k |
| plain | 58.2 / 66 (±0.2) | 83-94% | 88.3% | 2 | 156 s | 80k |
| v240 | 59.8 / 66 (±0.8) | 87-96% | 90.5% | 2 | 191 s | 82k |

| Category | cur | plain | v240 |
|---|---:|---:|---:|
| architecture | 11.0/12 | 11.5/12 | 10.8/12 |
| code-writing | 15.0/17 | 14.8/17 | 15.2/17 |
| debugging | 15.0/15 | 15.0/15 | 15.0/15 |
| performance-networking | 10.2/11 | 9.2/11 | 10.0/11 |
| recent-platform | 9.0/11 | 7.8/11 | 8.8/11 |

Grader agreement: mean |difference| between graders = 0.8% of task points (lower is better).
