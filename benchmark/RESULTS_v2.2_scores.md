# LihFolk Benchmark v2.2

## Set A (24 tasks, 64 points, 3 graders)

| Setup | Mean score | 95% CI (tasks bootstrap) | Accuracy | Runs | Time / run | Tokens / run |
|---|---:|---:|---:|---:|---:|---:|
| v21lookup | 56.6 / 64 (±0.5) | 79-95% | 88.5% | 2 | 134 s | 51k |
| v22lookup | 60.8 / 64 (±1.1) | 91-98% | 95.0% | 2 | 312 s | 54k |
| v2lookup | 55.6 / 64 (±0.7) | 74-94% | 86.9% | 3 | 197 s | 49k |

| Category | v21lookup | v22lookup | v2lookup |
|---|---:|---:|---:|
| classic_gotcha | 16.0/20 | 18.6/20 | 16.8/20 |
| post_training | 20.6/23 | 21.9/23 | 19.8/23 |
| practical | 20.0/21 | 20.3/21 | 19.0/21 |

Grader agreement: mean |difference| between graders = 2.4% of task points (lower is better).

## Set B (24 tasks, 66 points, 3 graders)

| Setup | Mean score | 95% CI (tasks bootstrap) | Accuracy | Runs | Time / run | Tokens / run |
|---|---:|---:|---:|---:|---:|---:|
| v21lookup | 61.4 / 66 (±0.6) | 89-97% | 93.1% | 2 | 134 s | 51k |
| v22lookup | 62.1 / 66 (±0.8) | 90-97% | 94.1% | 2 | 312 s | 54k |
| v2lookup | 60.2 / 66 (±0.8) | 87-95% | 91.2% | 3 | 197 s | 49k |

| Category | v21lookup | v22lookup | v2lookup |
|---|---:|---:|---:|
| architecture | 10.2/12 | 10.2/12 | 10.2/12 |
| code-writing | 17.1/18 | 17.7/18 | 17.0/18 |
| debugging | 15.8/16 | 15.5/16 | 15.4/16 |
| performance | 9.8/10 | 9.3/10 | 9.2/10 |
| recent-platform | 8.6/10 | 9.4/10 | 8.3/10 |

Grader agreement: mean |difference| between graders = 2.3% of task points (lower is better).
