# ADR-002: Phase 2 Imported-Song Runtime Audio

## Status

Accepted for the Phase 2 MVP on 2026-08-12. This does not supersede the Phase 1 fixed-song WAV contract or the Final Release Hardening measurements.

## Decision

Imported accompaniment is normalized to 48 kHz stereo Ogg Vorbis, quality 5. Accepted MVP inputs are WAV (`pcm_s16le`) and OGG (`vorbis`) within the P201 size/duration limits. Other codecs remain unsupported until separately measured.

Conversion uses the locally pinned FFmpeg 8.1 CLI and its built-in experimental Vorbis encoder. The exact output flags include fixed sample rate/channels, metadata removal, bitexact codec/mux flags, and fixed Ogg serial offset. The installed build reports GNU GPL version 3 or later via `ffmpeg -L`; the converter is a development/import tool and is not bundled into the PanBeat application. Install with Homebrew `brew install ffmpeg` and reproduce with:

```sh
scripts/check-phase2-p206 phase2-p206-audio-20260812
```

## Evidence

The source is the repository-owned 36-second Phase 1 WAV repeated to exactly six minutes. WAV and OGG use identical 48 kHz stereo conditions.

| Metric | WAV | OGG Vorbis |
|---|---:|---:|
| Bytes | 69,120,078 | 1,960,462 |
| Full decode, 3 trials | 83.5–84.8 ms | 198.5–200.6 ms |
| Godot load, 3 trials | 184.1–195.3 ms | 4.0–4.9 ms |
| Reported duration | 360.0 s | 360.0 s |
| Godot start/pause/resume/seek/loop/completion | 3/3 pass | 3/3 pass |
| 180-second seek observation error | about 2.67 ms | about 2.67 ms |

The deterministic repeat OGG SHA-256 is `fb90f5cf4fa522f03346ecd3cf9380e36c16e9a2280745416361d6040e21aa5a`. Raw conversion/decode data and Godot lifecycle trials are under `artifacts/raw/phase2-p206-audio-20260812/`.

## Consequences and limits

- OGG reduces this fixture by about 97% while keeping decode time far below the two-second chart-load target.
- The built-in FFmpeg 8.1 Vorbis encoder supports stereo only, so both comparison candidates and the canonical import contract are stereo. This is an evidence-backed change from the P201 mono candidate, not a change to the Phase 1 mono fixture.
- Godot measurements used the headless Dummy driver at a reported 44.1 kHz mix rate. They establish decode and lifecycle behavior, not CoreAudio timing quality.
- The automated loop check observes wrap and continuity of playback state, not an acoustic discontinuity. Seek/loop are not Phase 2 product features; audible seam and release-speed synchronization remain Final Phase work.
- Conversion occurs in a staging directory. The source is never modified, and the canonical asset is published only after ffprobe validation and repeat-checksum verification.
