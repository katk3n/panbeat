# E01 macOS automated comparison

Both engines completed one warm-up and three measured release builds. All three deterministic replay trials per engine matched the 14-record golden result (42 records each), and frame-independent outputs had zero differences.

| Metric | Unity | Godot |
|---|---:|---:|
| Release build p50 / p95 / p99 / max (ms) | 3316 / 3385 / 3385 / 3385 | 7506 / 7550 / 7550 / 7550 |
| Replay valid / planned | 3 / 3 | 3 / 3 |
| Replay records | 42 | 42 |
| Frame differences | 0 | 0 |
| Comparable release dispatch jitter | Not Measured | Not Measured |
| Comparable release frame time | Not Measured | Not Measured |

The retained five-minute Unity diagnostic has one of three planned trials and currently fails the fixed drift target. Godot's retained five-minute run used the Dummy driver and is excluded from real-output drift comparison; two planned trials are missing for each engine. Missing runs are not treated as successes. E01 makes no final engine selection.
