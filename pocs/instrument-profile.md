# Mood Pan Instrument Profile (M03)

## Phase 0 profile

`shared/fixtures/instrument-profiles/roland-mn10-handpan-minor-v1.json` is the
single source of truth for Phase 0 Mood Pan normalization. It applies only
when the physical device is configured to Tone **Handpan** and Style
**Minor**. Gamelan, unknown, and unmeasured settings must not silently fall
back to this profile.

| Input | Technique | Target |
|---|---|---|
| Ch.1 Note 50 | `ding` | `ding` |
| Ch.1 Notes 57, 58, 60, 62, 64, 65, 67, 69 | `tone` | `tone-2` through `tone-9` |
| Ch.1 Note 93 or 95 | `slap` | `outer-hit-radius` |

Every binding accepts velocities 1 through 127. Velocity 0 Note On is already
normalized to Note Off by the raw MIDI adapter and therefore does not trigger
a gameplay input.

No Ch.1/Ch.2 duplicate was observed in the measured Handpan / Minor traces.
The profile therefore uses deduplication mode `none` with a zero-microsecond
window. Repeated matching events are preserved as separate hits.

CC 81, Poly Pressure, Note Off, and unknown Note On messages produce
diagnostics that retain source sequence and raw bytes. Engines must expose or
persist these diagnostics; they must not discard them silently.

## Reproducible audit

```sh
scripts/validate-fixtures
node --test scripts/instrument-profile.test.mjs
scripts/instrument-profile audit \
  --output artifacts/reports/m03-instrument-profile-audit.json
```

- Cases: `shared/fixtures/instrument-profile-cases.json`
- Report: `artifacts/reports/m03-instrument-profile-audit.json`
- Capture interpretation: `pocs/mood-pan-capture-report.md`

The case manifest includes every M02 trace and explicitly separates Handpan /
Minor profile traces from other settings. Gamelan is retained as comparison
evidence only.

## Deferred scope

This profile does not claim support for other Handpan Styles, Gamelan, the
remaining Tone settings, BLE MIDI, or calibrated pressure/velocity curves.
Those settings require their own evidence-backed profiles or an explicit
profile extension.
