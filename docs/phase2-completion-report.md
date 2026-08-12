# PanBeat Phase 2 completion report

> Evidence retention: 本書から参照する`artifacts/raw/`はローカル／CI出力であり、Gitにはcommitしない。checkoutに存在しない場合はstory固有commandから再生成する。

## Gate decision

Phase 2 MVP is **complete** as of 2026-08-12. The requirement in [`requirement.md`](./requirement.md) is supported by automated import/replay evidence and Mood Pan real-device evidence: a MusicXML score with explicit PanBeat overlay annotations was imported through the product UI, then Tone, Ding, and Slap were played through the audio-backed Gameplay flow and saved to Results.

This decision means **MVP feature complete**, not release permission. The build is not claimed to be signed, notarized, distributable, or release-ready. Final Release Hardening remains required, and R-P1-001/R-P1-003 remain unresolved release-gate blockers.

## Evidence audit

| Area | Result | Canonical evidence |
|---|---|---|
| Phase 1 regression baseline | Pass | [`phase2-p201-baseline-20260812`](../artifacts/raw/phase2-p201-baseline-20260812/run-manifest.json) |
| Persistence and migration | Pass | [`phase2-p202-persistence-20260812`](../artifacts/raw/phase2-p202-persistence-20260812/run-manifest.json) |
| Safe MusicXML and deterministic chart | Pass | [`P203`](../artifacts/raw/phase2-p203-musicxml-20260812/run-manifest.json), [`P204`](../artifacts/raw/phase2-p204-runtime-chart-20260812/run-manifest.json) |
| Overlay and target mapping | Pass | [`P205`](../artifacts/raw/phase2-p205-overlay-20260812/run-manifest.json) |
| Runtime audio decision | Pass | [`P206`](../artifacts/raw/phase2-p206-audio-20260812/run-manifest.json), [`ADR-002`](./adr-002-runtime-audio.md) |
| Atomic import and Song Library | Pass | [`P207`](../artifacts/raw/phase2-p207-import-20260812/run-manifest.json), [`P208`](../artifacts/raw/phase2-p208-library-20260812/run-manifest.json) |
| Device and Calibration | Pass | [`P209 real device`](../artifacts/raw/phase2-p209-real-device-20260812/run-manifest.json), [`P210 real device`](../artifacts/raw/phase2-p210-real-device-20260812/run-manifest.json) |
| Results and product flow | Pass | [`P211`](../artifacts/raw/phase2-p211-results-20260812/run-manifest.json), [`P212`](../artifacts/raw/phase2-p212-product-flow-20260812/run-manifest.json) |
| Imported Gameplay | Pass | [`P213`](../artifacts/raw/phase2-p213-imported-gameplay-20260812/run-manifest.json) |
| Security and performance baseline | Pass with documented limitations | [`P214`](../artifacts/raw/phase2-p214-quality-20260812/run-manifest.json) |
| Release-build replay acceptance | Pass | [`P215 final regression`](../artifacts/raw/phase2-p215-audio-duration-fix-20260812/run-manifest.json) |
| Mood Pan MVP acceptance | Pass | [`P216`](../artifacts/raw/phase2-p216-real-device-20260812/run-manifest.json) |

The final P215 build is `PanBeat.zip`, SHA-256 `2ba8dd9fc809f635a82ba59e9862074650ec11e6fc40e432bbbc47c56b114d08`, 63,015,124 bytes. Its full suite passed: unit 44/44, P202–P213 story suites, integration 35/35, and replay 7/7. The final P213 regression specifically passed 15/15 after package duration was corrected to use the converted 36-second audio rather than the shorter 4.67-second score.

P216 preserved three valid post-fix sessions: session 1 completed the corrected 36-second package; session 2 restored Input Offset 37 ms / Audio Offset 0 ms and recorded pause/resume; session 3 mapped Tone, Ding, and Slap after USB reconnect and full app relaunch. Four P216 Results records were observed, exceeding the required minimum of three, with no corrupt records.

## Version contract

- Godot: `4.6.stable.official.89cea1439`
- Language: typed GDScript
- MusicXML root/version: `score-partwise`, MusicXML 4.0 MVP subset
- Importer: `panbeat-musicxml-importer-v1`
- Song package, chart, overlay, settings, result history, and diagnostic schema: `1.0.0`
- Instrument Profile: `roland-mn10-handpan-minor-v1`
- Judgement rule: `panbeat-phase1-standard-v1`
- Score rule: `panbeat-phase1-score-v1`
- Imported runtime audio: 48 kHz stereo Ogg Vorbis, deterministic FFmpeg conversion
- Gameplay clock: audio-backed transport; frame count is not a judgement clock

## Unexecuted work and residual risk

- `R-P1-001`: long-run drift remains `deferred-release-gate-blocker`; FH01/FH02/FH04 own it.
- `R-P1-003`: MIDI dispatch p95 remains `deferred-release-gate-blocker`; FH01/FH03/FH04 own it.
- Release heap monitoring returned zero. External allocation profiling remains required by FH04.
- Godot 4.6's macOS MIDI backend did not discover MN-10 after hot-plug in the accepted P216 environment. Reconnecting USB and relaunching PanBeat is the accepted Phase 2 recovery. FH03 will evaluate, but does not pre-commit to, a native CoreMIDI backend.
- External high-speed-camera/audio-loopback end-to-end latency measurement was explicitly not performed and is not planned by product decision. Software timestamps are not represented as physical end-to-end latency.
- Signing, notarization, distribution, updater, telemetry, and the platforms excluded by Phase 2 remain outside this gate.

## Definition of Done audit

Every P201–P216 story has implementation/documentation, story-specific verification, preserved raw evidence, and an explicit status. Product-facing changes have release-build evidence. Security negative cases cover DTD/XXE, archive traversal, Zip Slip/zip bomb limits, oversized inputs, corrupt audio, and atomic publication failure. No unexecuted verification is reported as a pass. P217 is documentation-only and therefore uses JSON parsing, evidence/link resolution, story/status consistency, terminology review, and Markdown structure checks in place of another product build.

Phase 0/1 decision history and raw evidence were not changed. The machine-readable gate is [`phase2-acceptance.json`](./phase2-acceptance.json), and the P217 audit manifest is [`phase2-p217-gate-20260812`](../artifacts/raw/phase2-p217-gate-20260812/run-manifest.json).
