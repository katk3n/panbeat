# Unity Phase 0 note visuals (U04)

`NoteVisualKinematics` computes position directly from song time in
microseconds. Tone moves from Spawn Ring to its target, Ding converges to the
center, and Slap expands toward the common Outer Hit Radius. No frame counter
or accumulated `deltaTime` participates in position.

The shared 30-second chart is loaded directly from
`shared/fixtures/test-pack/chart.json`; there is no Unity-specific chart copy.
EditMode tests verify chart loading, shape motion, identical positions for the
same song time at 60/120/144 Hz, and fixed-pool overflow accounting.

Generate the deterministic 768 x 768, color-independent preview with:

```sh
scripts/check-unity --mode test
scripts/capture-unity-u04
```

The preview uses a small local ring for Tone, a center-bound diamond for Ding,
and a complete expanding ring for Slap. A second local ring shows the minimal
HIT ripple. Output is `artifacts/reports/unity-u04/three-techniques.png`.
