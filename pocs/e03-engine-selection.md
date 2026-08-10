# E03 engine selection

Recalculate the fixed weighted score and eligibility with:

```sh
node scripts/score-engine-evaluation.mjs
```

Godot 4.6 with typed GDScript is selected. Its six hard gates pass after the
approved EC-001 release/CoreAudio drift measurement, and its weighted score is
75.00. Unity scores 61.00 and its EC-001 drift result passes, but its input
dispatch jitter remains `Not Measured`; it is not eligible without risk
acceptance.

Residual risks are retained: drift beyond one minute moves to Phase 1,
Godot's public MIDI API does not expose an OS receive timestamp or physical
disconnect state, and the release-drift harness emitted a now-fixed Node
cleanup warning after writing each valid raw file.
