# LihFolk Benchmark v2.1

## Set A (24 tasks, 64 points, 2 graders)

| Setup | Mean score | 95% CI (tasks bootstrap) | Accuracy | Runs | Time / run | Tokens / run |
|---|---:|---:|---:|---:|---:|---:|
| lookup | 56.5 / 64 (±1.2) | 82-93% | 88.2% | 2 | 176 s | 51k |
| v2lookup | 55.5 / 64 (±0.9) | 75-93% | 86.8% | 3 | 197 s | 49k |

| Category | lookup | v2lookup |
|---|---:|---:|
| classic_gotcha | 16.5/20 | 16.6/20 |
| post_training | 20.0/23 | 19.9/23 |
| practical | 20.0/21 | 19.0/21 |

Grader agreement: mean |difference| between graders = 3.6% of task points (lower is better).

## Set B (24 tasks, 66 points, 2 graders)

| Setup | Mean score | 95% CI (tasks bootstrap) | Accuracy | Runs | Time / run | Tokens / run |
|---|---:|---:|---:|---:|---:|---:|
| lookup | 62.0 / 66 (±0.5) | 89-97% | 93.9% | 2 | 176 s | 51k |
| v2lookup | 60.1 / 66 (±0.6) | 86-95% | 91.1% | 3 | 197 s | 49k |

| Category | lookup | v2lookup |
|---|---:|---:|
| architecture | 10.3/12 | 10.3/12 |
| code-writing | 17.4/18 | 17.0/18 |
| debugging | 15.7/16 | 15.4/16 |
| performance | 9.8/10 | 9.2/10 |
| recent-platform | 8.8/10 | 8.2/10 |

Grader agreement: mean |difference| between graders = 4.3% of task points (lower is better).
