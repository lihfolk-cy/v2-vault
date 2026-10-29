# LihFolk Benchmark f1

## Set F (12 tasks, 34 points, 2 graders)

| Setup | Mean score | 95% CI (tasks bootstrap) | Accuracy | Runs | Time / run | Tokens / run |
|---|---:|---:|---:|---:|---:|---:|
| cur | 31.4 / 34 (±0.3) | 75-100% | 92.3% | 2 | 180 s | 81k |
| plain | 26.9 / 34 (±0.0) | 58-94% | 79.2% | 1 | 62 s | 66k |

| Category | cur | plain |
|---|---:|---:|
| architecture | 6.0/6 | 5.6/6 |
| code_writing | 8.0/8 | 7.6/8 |
| debugging | 6.2/8 | 6.5/8 |
| performance_networking | 6.0/6 | 5.0/6 |
| recent_platform | 5.2/6 | 2.2/6 |

Grader agreement: mean |difference| between graders = 3.1% of task points (lower is better).
