# LihFolk Benchmark v2

## Set A (24 tasks, 64 points, 3 graders)

| Setup | Mean score | 95% CI (tasks bootstrap) | Accuracy | Runs | Time / run | Tokens / run |
|---|---:|---:|---:|---:|---:|---:|
| direct | 60.4 / 64 (±0.6) | 90-98% | 94.4% | 3 | 215 s | 67k |
| lookup | 58.2 / 64 (±0.9) | 80-96% | 90.9% | 3 | 197 s | 49k |
| plain | 43.8 / 64 (±2.2) | 56-82% | 68.4% | 3 | 129 s | 44k |

| Category | direct | lookup | plain |
|---|---:|---:|---:|
| classic_gotcha | 17.2/20 | 17.4/20 | 16.9/20 |
| post_training | 22.8/23 | 21.8/23 | 8.2/23 |
| practical | 20.5/21 | 19.0/21 | 18.7/21 |

Grader agreement: mean |difference| between graders = 3.6% of task points (lower is better).

## Set B (24 tasks, 66 points, 3 graders)

| Setup | Mean score | 95% CI (tasks bootstrap) | Accuracy | Runs | Time / run | Tokens / run |
|---|---:|---:|---:|---:|---:|---:|
| direct | 62.6 / 66 (±0.3) | 91-98% | 94.8% | 3 | 215 s | 67k |
| lookup | 61.0 / 66 (±0.6) | 89-96% | 92.5% | 3 | 197 s | 49k |
| plain | 60.5 / 66 (±0.4) | 87-95% | 91.7% | 3 | 129 s | 44k |

| Category | direct | lookup | plain |
|---|---:|---:|---:|
| architecture | 10.5/12 | 10.5/12 | 10.5/12 |
| code-writing | 18.0/18 | 17.3/18 | 17.5/18 |
| debugging | 15.5/16 | 15.6/16 | 15.6/16 |
| performance | 9.2/10 | 9.3/10 | 9.1/10 |
| recent-platform | 9.4/10 | 8.3/10 | 7.8/10 |

Grader agreement: mean |difference| between graders = 2.9% of task points (lower is better).
