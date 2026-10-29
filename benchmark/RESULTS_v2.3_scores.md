# LihFolk Benchmark v2.3

## Set A (24 tasks, 64 points, 3 graders)

| Setup | Mean score | 95% CI (tasks bootstrap) | Accuracy | Runs | Time / run | Tokens / run |
|---|---:|---:|---:|---:|---:|---:|
| v21lookup | 57.1 / 64 (±0.6) | 81-95% | 89.3% | 2 | 134 s | 51k |
| v22lookup | 60.8 / 64 (±1.4) | 91-98% | 95.1% | 2 | 312 s | 54k |
| v23lookup | 61.7 / 64 (±0.6) | 93-99% | 96.5% | 2 | 316 s | 54k |
| v2lookup | 56.1 / 64 (±0.7) | 76-94% | 87.6% | 3 | 197 s | 49k |

| Category | v21lookup | v22lookup | v23lookup | v2lookup |
|---|---:|---:|---:|---:|
| classic_gotcha | 16.4/20 | 18.6/20 | 18.6/20 | 17.0/20 |
| post_training | 20.5/23 | 21.7/23 | 22.3/23 | 20.1/23 |
| practical | 20.2/21 | 20.5/21 | 20.8/21 | 19.0/21 |

Grader agreement: mean |difference| between graders = 3.0% of task points (lower is better).

## Set B (24 tasks, 66 points, 3 graders)

| Setup | Mean score | 95% CI (tasks bootstrap) | Accuracy | Runs | Time / run | Tokens / run |
|---|---:|---:|---:|---:|---:|---:|
| v21lookup | 61.8 / 66 (±0.3) | 90-97% | 93.7% | 2 | 134 s | 51k |
| v22lookup | 62.5 / 66 (±0.8) | 91-98% | 94.6% | 2 | 312 s | 54k |
| v23lookup | 64.1 / 66 (±0.6) | 94-99% | 97.1% | 2 | 316 s | 54k |
| v2lookup | 60.6 / 66 (±0.4) | 87-96% | 91.8% | 3 | 197 s | 49k |

| Category | v21lookup | v22lookup | v23lookup | v2lookup |
|---|---:|---:|---:|---:|
| architecture | 10.3/12 | 10.3/12 | 10.8/12 | 10.5/12 |
| code-writing | 17.4/18 | 17.8/18 | 18.0/18 | 17.1/18 |
| debugging | 15.4/16 | 15.1/16 | 15.7/16 | 15.1/16 |
| performance | 10.0/10 | 9.6/10 | 9.7/10 | 9.6/10 |
| recent-platform | 8.7/10 | 9.6/10 | 10.0/10 | 8.2/10 |

Grader agreement: mean |difference| between graders = 2.5% of task points (lower is better).
