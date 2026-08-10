# Godot Phase 0 note visuals (G04)

The Godot slice uses the same radii and song-time kinematics as Unity. Tone is
a local outward ring, Ding a center-bound diamond, and Slap a complete outward
ring. `RadialView` draws all shapes without relying on color for identity.

The headless suite verifies the shared 30-second chart, identical positions at
60/120/144 Hz, and fixed-pool reuse/overflow. Generate the deterministic PNG:

```sh
scripts/check-godot --mode test
scripts/capture-godot-g04
```
