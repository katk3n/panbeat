# P101 Phase 1 contract and baseline

P101 freezes the Phase 1 contract before product implementation proceeds. The
machine-readable source is [`phase1-acceptance.json`](./phase1-acceptance.json).
The scope and deferrals are intentionally the same as
[`phase1-stories.md`](./phase1-stories.md); later stories may record results but
must not silently relax them.

## Starting-point audit

- ADR-001 is Accepted and selects Godot 4.6 with typed GDScript.
- `game/` is the product entry point and `scripts/check-game` exposes `test`,
  `build`, and `all` modes.
- The canonical profile is
  `shared/fixtures/instrument-profiles/roland-mn10-handpan-minor-v1.json`.
- Phase 0 schema, chart, golden input/result, real-device MIDI trace, engine
  selection, and hard-gate evidence are listed with immutable checksums in the
  acceptance manifest.
- The Phase 0 chart remains comparison evidence. P103 must create the distinct
  Phase 1 fixed-song package; it must not relabel the Phase 0 test pack as the
  product song.
- `pocs/` and existing Phase 0 raw evidence were not modified by P101.

## Baseline result

The baseline ran on 2026-08-10 at 12:44 UTC on macOS 26.5.2 (build 25F84),
arm64, with Godot 4.6.stable.official.89cea1439 and the
`gl_compatibility` renderer.

| Check | Result | Evidence |
|---|---|---|
| `scripts/check-game --mode test` | Pass, `PANBEAT_GAME_TESTS_OK 6/6` | `artifacts/raw/phase1-p101-baseline-20260810T124443Z/test.log` |
| `scripts/check-game --mode build` | Pass, release ZIP produced | `artifacts/raw/phase1-p101-baseline-20260810T124443Z/build.log` |

Both commands emitted the macOS system-CA warning in the restricted execution
environment. Build also emitted a Trash permission warning while replacing an
existing ignored ZIP. Neither command hid a failure: both returned zero and the
export reached `DONE`. P102 owns making story runs use unique output paths so
future evidence never relies on replacement behavior.

## Open Phase 1 risks

The following are not Phase 0 passes and remain required in P111:

- real-output drift for longer than five minutes;
- release product frame-time distribution;
- MIDI dispatch jitter through the Phase 1 product path.

The acceptance manifest assigns stable risk IDs and an owner story to each.

## Reproduction

```sh
node scripts/check-phase1-baseline.mjs
node --test scripts/check-phase1-baseline.test.mjs
scripts/check-game --mode test
scripts/check-game --mode build
```
