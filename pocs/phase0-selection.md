# Phase 0 selection boundary

Phase 0 selected Godot 4.6 with typed GDScript on 2026-08-10. The production
line starts at `game/`; `pocs/unity/` and `pocs/godot/` are frozen comparison
lanes whose purpose is to reproduce retained evidence, not receive Phase 1
features.

Primary checkpoints are:

- `artifacts/raw/unity-u06/run-manifest.json`
- `artifacts/raw/godot-g06/run-manifest.json`
- `artifacts/raw/e01-comparison/run-manifest.json`
- `artifacts/raw/e02-real-device/run-manifest.json`
- `artifacts/raw/e03-release-drift/run-manifest.json`
- `artifacts/raw/e03-engine-selection/score-result.json`

The first intentional repository checkpoint is recorded by the annotated
`phase0-complete` tag. This tag freezes both comparison lanes, the raw evidence,
the evaluation contract, and the selected production baseline together.
