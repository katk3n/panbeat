# Mood Pan USB MIDI capture report (M02)

## Status

This report summarizes the append-only USB MIDI evidence captured on
2026-08-10. M02 is **complete** for Phase 0: it provides a profile basis for
Handpan / Minor, measured Tone/Style differences, raw Slap evidence, and
explicit unknowns.

The original `docs/architecture.md` 7.4 called for every Tone/Style setting.
On 2026-08-10 the user judged the MIDI Tone evidence sufficient and explicitly
approved omitting the exhaustive selector sweep. The architecture now requires
representative differences plus explicit unknowns for Phase 0. No unmeasured
setting is inferred from another setting.

## Environment and evidence

- Device: Roland Mood Pan MN-10, USB MIDI
- CoreMIDI source: port index `0`, reported name `MN-10`
- Host: macOS 26.5.2 (25F84), Apple Silicon
- Inspector: `scripts/midi-inspector capture`
- Clock: monotonic microseconds assigned in the CoreMIDI callback
- Raw directory: `artifacts/raw/m02-mood-pan-20260810/`
- Integrity manifest: `artifacts/raw/m02-mood-pan-20260810/checksums.sha256`

The initial `connection-smoke-default-tone-style.jsonl` session used an
unknown Tone/Style and is excluded from mappings. All strength labels describe
the requested physical action, not calibrated force. Mood Pan strength was
difficult to reproduce precisely, so velocity observations are qualitative.

## Measured pad mappings

All rows below are Note On messages. Pad numbers follow the device manual:
Pad 1 is the center pad, then Pads 2 through 9 follow the numbered physical
layout.

| Pad | Gamelan / Minor | Gamelan / Major | Handpan / Minor |
|---:|---:|---:|---:|
| 1 | Note 47, Ch.1 | Note 47, Ch.1 | Note 50, Ch.1 |
| 2 | Note 57, Ch.1 | Note 55, Ch.1 | Note 57, Ch.1 |
| 3 | Note 58, Ch.1 | Note 57, Ch.1 | Note 58, Ch.1 |
| 4 | Note 60, Ch.1 | Note 59, Ch.1 | Note 60, Ch.1 |
| 5 | Note 62, Ch.1 | Note 61, Ch.1 | Note 62, Ch.1 |
| 6 | Note 64, Ch.1 | Note 62, Ch.1 | Note 64, Ch.1 |
| 7 | Note 65, Ch.1 | Note 64, Ch.1 | Note 65, Ch.1 |
| 8 | Note 67, Ch.1 | Note 66, Ch.1 | Note 67, Ch.1 |
| 9 | Note 69, Ch.1 | Note 69, Ch.1 | Note 69, Ch.1 |

The canonical Gamelan / Minor mapping is supported by the medium and strong
sessions. In the weak session, the sixth requested strike produced Note 50 on
Ch.2 rather than Pad 6's Note 64 on Ch.1. That observation is consistent with
a Gamelan Slap, but the physical cause cannot be recovered from MIDI, so this
sample is marked ambiguous and is not used to change Pad 6's mapping.

Handpan / Minor adds a CC 81 event and Poly Pressure for each measured pad
strike before its Note On/Off pair. These messages are retained for diagnostic
handling; they are not extra pad hits.

## Techniques and delivery behavior

| Setting / action | Observation | Drop / duplicate assessment |
|---|---|---|
| Gamelan / Minor, left Slap x3 | Note 50, Ch.2, 3 Note On/Off pairs | 3/3 captured; no duplicate observed |
| Gamelan / Minor, right Slap x3 | Note 50, Ch.2, 3 Note On/Off pairs | 3/3 captured; no duplicate observed |
| Handpan / Minor, left Slap x3 | Note 93, Ch.1, 3 Note On/Off pairs | 3/3 captured; no duplicate observed |
| Handpan / Minor, right Slap x3 | Note 95, Ch.1, 3 Note On/Off pairs | 3/3 captured; no duplicate observed |
| Gamelan / Minor, Pad 2 + Pad 3 x3 | Both notes captured; arrival gaps 20,326, 11,064, and 11,532 us | 3/3 pairs captured; no duplicate observed |
| Gamelan / Minor, Pad 1 rapid x11 | 11 complete Note 47 On/Off pairs | User confirmed 11 physical strikes; 11/11 captured, no duplicate observed |
| Gamelan / Minor, Special Pad tap x3 + press 2 s | No MIDI event | Valid empty trace; no message mapping inferred |
| Handpan / Minor, Special Pad tap x3 | No MIDI event | No message mapping inferred |
| Handpan / Minor, Pad 1 slow pressure 2 s | Poly Pressure, Note 50, value 127; no Note On/Off | One pressure event observed |
| Handpan / Minor, Pad 1 hit then touch-to-mute x3 | Each hit has CC 81, Poly Pressure 0, Note On/Off 50; later Poly Pressure 127 | 3/3 action groups captured; no Ch.2 duplicate observed |

No Ch.1/Ch.2 duplicate pair was observed in the measured settings. The
channel difference is semantic here: Gamelan pad hits are Ch.1 and its Slap is
Ch.2, while measured Handpan pad hits and left/right Slaps are all Ch.1.

## Trace inventory

| File | Events | Purpose |
|---|---:|---|
| `all-tone-positions-style-minor-pad1-left-slap-right-slap.jsonl` | 0 | Valid session stopped when exhaustive Tone capture was waived |
| `connection-smoke-default-tone-style.jsonl` | 14 | Connection only; unknown setting, excluded from mapping |
| `gamelan-major-pads1-9-medium.jsonl` | 18 | Gamelan / Major, Pads 1-9 |
| `gamelan-minor-pads1-9-medium.jsonl` | 18 | Gamelan / Minor canonical pad mapping |
| `gamelan-minor-pads1-9-strong-approximate.jsonl` | 18 | Qualitative strong strikes |
| `gamelan-minor-pads1-9-weak.jsonl` | 18 | Qualitative weak strikes; Pad 6 action ambiguous |
| `gamelan-minor-simultaneous-pad2-pad3-then-pad1-rapid10.jsonl` | 34 | Simultaneous and rapid input |
| `gamelan-minor-slap-left3-then-right3.jsonl` | 12 | Gamelan left/right Slap |
| `gamelan-minor-special-pad-tap3-press2s.jsonl` | 0 | Valid empty Special Pad trace |
| `handpan-minor-pads1-9-medium.jsonl` | 36 | Handpan / Minor pad mapping and pressure messages |
| `handpan-minor-slap-left3-then-right3.jsonl` | 12 | Handpan left/right Slap |
| `handpan-minor-special3-pressure-pad1-2s-mute-pad1x3.jsonl` | 16 | Special Pad, pressure, and Mute |

Event counts exclude the JSONL session header.

## Deferred and unverified scope

- Remaining Tone and Style selector positions; exhaustive coverage was
  explicitly waived for Phase 0 after representative differences were captured
- Slap behavior for unmeasured Tone/Style settings and locations other than the
  measured left/right sides
- Calibrated force/velocity curves; weak, medium, and strong are qualitative
- Pressure curves and Mute behavior on Pads 2-9
- Bluetooth MIDI (explicitly outside the Phase 0 pass target)

These gaps must remain diagnostic/unknown in M03. They must not be populated
from the public manual or by extrapolating the measured settings. They should
be revisited before claiming a production profile supports those settings.
