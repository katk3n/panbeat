# P215 macOS MVP automated acceptance

From the repository root, run the complete acceptance pipeline with a unique run ID:

```sh
scripts/check-phase2-p215 phase2-p215-<unique-run-id>
```

The command runs all Godot tests, imports the acceptance MusicXML/overlay/audio through the production import service, exports the macOS release archive, inspects the export, executes the release binary in replay mode, reads the persisted Results back, captures the imported chart view, and writes a manifest under `artifacts/raw/<run-id>/`.

On macOS the command opens a short-lived Godot rendering window to capture the screenshot. It therefore needs permission to start a GUI process. A non-zero exit is a failed run; the script does not create a successful manifest after a failed step.

The acceptance import uses:

- `shared/fixtures/musicxml/p213-acceptance.musicxml`
- `shared/fixtures/musicxml/p213-acceptance-overlay.json`
- `game/content/phase1-fixed-song-v1/orbit-practice.wav`
- `game/config/default-instrument-profile.json`

The release export excludes `tests/*`. The pipeline also rejects an export log that packages test resources, and rejects a PCK containing raw-evidence or personal filesystem paths.

The P215 acceptance was independently completed as `phase2-p215-run-e-20260812` and `phase2-p215-run-f-20260812`. Both produced canonical chart SHA-256 `b5c1204f6aae8de66a69d672af10c09ba746120e74639d5ddada6751ba55da87` and replay SHA-256 `d7231ca3bb3d7238173464f87a0464375de8f03f2eb63f2a39eb0664fbbc0150`.
