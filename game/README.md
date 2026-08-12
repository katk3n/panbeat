# PanBeat game

This is the Phase 1 production entry point promoted from the selected Godot
4.6 / typed GDScript PoC. Phase 0 capture harnesses remain frozen under
`pocs/`; product work belongs here.

From the repository root:

```sh
scripts/check-game --mode unit
scripts/check-game --mode integration
scripts/check-game --mode replay
scripts/check-game --mode test
scripts/check-game --mode build
scripts/check-game --mode all
scripts/check-phase1-acceptance UNIQUE_RUN_ID
```

Pass `--run-id NAME` to keep logs and builds in unique
`artifacts/reports/NAME` and `artifacts/builds/NAME` directories. `test` runs
unit, integration, and replay suites as separate Godot processes so a failure
in any layer cannot be hidden by another suite.

The release embeds the selected Handpan / Minor profile under `config/`.
Domain code does not depend on SceneTree, MIDI, filesystem, or presentation
APIs. Application transport receives its clock by constructor injection. Raw
MIDI records from a physical adapter or recorded replay pass through the same
normalizer and `NormalizedInputQueue`. JSON chart filesystem access is isolated
in `JsonChartSource`; tests use a product-test fixture rather than the Phase 0
test pack. Phase 0 capture harnesses and evidence remain under `pocs/` and
`artifacts/raw/` and are not product runtime dependencies.

The fixed Phase 1 song is `content/phase1-fixed-song-v1/package.json`. Its JSON,
original CC0 WAV, expected events, provenance, and checksums are generated and
verified with `scripts/generate-phase1-song`.

Gameplay time is provided by `AudioTransportService`. Before playback it emits
a negative scheduled count-in; after start it reads only the audio backend's
playback position. Frame delta is never accumulated. Pause gates input and
freezes time, while resume returns to the audio position. Diagnostics include
start lead/anchor/lateness, mix rate, output latency, estimated buffer frames,
and failure reason.

USB MIDI uses `MidiPortService` for open/close/reopen lifecycle and
`GodotMidiAdapter` for a lightweight raw queue. The `_input` callback only
captures fields and timestamps; normalization and signals happen in `_process`.
`RecordedMidiReplay` feeds the same `MidiNormalizer` contract. Godot exposes no
public OS receive timestamp or reliable physical-disconnect state: a device may
remain listed while unplugged, so port-list changes trigger reopen but silence
alone is diagnostic, not proof of disconnect. Godot opens all MIDI inputs; the
preferred port is therefore a validated logical selection, not an OS-level
exclusive open.

The backend must be opened before cold-start port enumeration. P113 caught and
repaired a regression that performed those operations in the opposite order.
The accepted real-device build is recorded in `docs/phase1-acceptance.json`;
`docs/phase1-completion-report.md` records the successful Phase 1 gate and the
performance items deferred to the mandatory Final Release Hardening Phase.
