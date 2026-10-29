# LihFolk Benchmark v2.1

## Set A (24 tasks, 64 points, 2 graders)

| Setup | Mean score | 95% CI (tasks bootstrap) | Accuracy | Runs | Time / run | Tokens / run |
|---|---:|---:|---:|---:|---:|---:|
| brief | 57.1 / 64 (±0.7) | 82-94% | 89.2% | 2 | 176 s | 51k |
| lookup | 56.2 / 64 (±1.1) | 80-94% | 87.9% | 2 | 134 s | 51k |
| v2lookup | 55.4 / 64 (±0.6) | 75-93% | 86.6% | 3 | 197 s | 49k |

| Category | brief | lookup | v2lookup |
|---|---:|---:|---:|
| classic_gotcha | 16.8/20 | 16.2/20 | 17.0/20 |
| post_training | 20.3/23 | 20.0/23 | 19.4/23 |
| practical | 20.0/21 | 20.0/21 | 19.0/21 |

Grader agreement: mean |difference| between graders = 2.6% of task points (lower is better).

## Set B (24 tasks, 66 points, 2 graders)

| Setup | Mean score | 95% CI (tasks bootstrap) | Accuracy | Runs | Time / run | Tokens / run |
|---|---:|---:|---:|---:|---:|---:|
| brief | 62.3 / 66 (±0.5) | 90-98% | 94.4% | 2 | 176 s | 51k |
| lookup | 61.6 / 66 (±0.1) | 89-96% | 93.3% | 2 | 134 s | 51k |
| v2lookup | 60.7 / 66 (±0.7) | 88-95% | 92.0% | 3 | 197 s | 49k |

| Category | brief | lookup | v2lookup |
|---|---:|---:|---:|
| architecture | 10.5/12 | 10.5/12 | 10.5/12 |
| code-writing | 17.2/18 | 17.1/18 | 17.0/18 |
| debugging | 15.5/16 | 15.5/16 | 15.2/16 |
| performance | 10.0/10 | 9.8/10 | 9.5/10 |
| recent-platform | 9.0/10 | 8.8/10 | 8.5/10 |

Grader agreement: mean |difference| between graders = 2.3% of task points (lower is better).
