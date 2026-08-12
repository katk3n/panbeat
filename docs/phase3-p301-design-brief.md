# P301 visual baseline and design decision brief

## Status

P301 is **approved and complete**. On 2026-08-12 the product owner selected Option A, Quiet Forge. The decision is recorded in `phase3-p301-design-decision.md`; P302 and P303 may proceed from this direction.

This document and its token JSON are the historical P301 comparison snapshot. Later product-owner review evolved the shipped Phase 3 appearance to selectable meditative backgrounds, translucent copper, and cyan Tone orbs, and removed Reduced Effects from product scope. The final contract is recorded in `phase3-stories.md` and `phase3-completion-report.md`.

## Reproduction

Use a new, unique run ID each time; raw evidence is never overwritten.

```sh
scripts/check-phase3-p301 phase3-p301-<unique-run-id>
```

The command runs the complete Phase 2 regression suite, validates the P301 contract, captures the six current product screens at 1280×720, captures Gameplay at 1280×720 and 1728×720 in normal and monochrome modes, renders both design directions from the same immutable fixture, and writes `artifacts/raw/<run-id>/run-manifest.json`. A non-zero exit is a failed run and does not create a success manifest.

## Fixed comparison contract

Both options use the Phase 1 fixed chart and measured Mood Pan profile without changing target angles, radii, song time, score, combo, judgement data, navigation data, or window size. The representative Gameplay capture is at 10.000 seconds; count-in is fixed at −1.000 seconds and pause at 12.000 seconds. The manifest names the Perfect, Great, Good, and Miss states, and the fixed window includes Tone, Ding, Slap, and closely spaced notes.

The proposal previews intentionally show the Phase 3-required Ding full ring and direction grammar as a design target. The current baseline still shows the Phase 2 diamond Ding; implementing that contract belongs to P302.

## Option A — Quiet Forge

Warm, restrained gunmetal with amber resonance accents. It uses the lower glow budget, feels more instrument-like than sci-fi, and should remain comfortable during longer sessions. Technique separation relies on geometry first and modest warm hue differences second.

## Option B — Polar Resonance

Cool satin steel with cyan and violet resonance accents. It has deeper luminous layering and a more overt rhythm-game character. It remains compatible with Reduced Effects, but its normal-mode glow budget is intentionally higher than Option A.

## Tokens and assets

Exact candidate palette, typography sizes, spacing, corners, strokes, glow strengths, motion durations, and Reduced Effects values are in [`phase3-p301-design-tokens.json`](./phase3-p301-design-tokens.json). P301 bundles no external font, icon, or texture. Any later asset requires an upstream URL, exact version/hash, author, SPDX or equivalent license identifier, license text, attribution requirements, modification notes, embedding terms where relevant, and redistribution confirmation before commit.

## Baseline linkage

- Phase 2 completion and residual risks: [`phase2-completion-report.md`](./phase2-completion-report.md)
- Deterministic judgement and score: `artifacts/raw/phase2-p215-audio-duration-fix-20260812/run-manifest.json`
- Frame and scheduler baseline: `artifacts/raw/phase2-p214-quality-20260812/run-manifest.json`
- P301 run manifest: `artifacts/raw/<run-id>/run-manifest.json`

The Phase 2 performance reference is Gameplay p95/p99 16,667 µs at 60 fps, scheduler p95 3 µs, and zero pool overflow. External allocation profiling remains a Final Phase requirement and is not reported as complete here.
