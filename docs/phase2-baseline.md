# Phase 2 P201 Baseline

## Decision

P201 is complete. Phase 2 starts from the accepted Phase 1 Godot product path without changing the fixed song, replay, canonical Instrument Profile, judgement rule, score rule, or offset sign convention.

Phase 2 completion means functional MVP acceptance. It does not permit a formal release. R-P1-001 and R-P1-003 remain `deferred-release-gate-blocker` items owned by the Final Release Hardening phase.

The machine-readable source of truth is [`phase2-acceptance.json`](./phase2-acceptance.json).

## Baseline verification

Run ID: `phase2-p201-baseline-20260812`

| Check | Result |
|---|---|
| Godot unit tests | Pass, 44/44 |
| Godot integration tests | Pass, 35/35 |
| Deterministic replay tests | Pass, 7/7 |
| macOS universal release export | Pass |
| Build SHA-256 | `66bc5d0fa75e3608cf885ff52ad39c5577bc0e3108ca35ebe6c56d5e070e4f4a` |

Godot printed the existing macOS sandbox warning while reading system CA certificates. It did not fail test or export. The warning is retained in the raw logs and is not treated as a successful certificate check.

## Commands

```sh
node scripts/check-phase2-baseline.mjs
node --test scripts/check-phase2-baseline.test.mjs
scripts/check-game --mode test --run-id phase2-p201-baseline-20260812
scripts/check-game --mode build --run-id phase2-p201-baseline-20260812
```

## Contract notes

- Accepted and rejected MusicXML cases are enumerated by fixture ID before importer implementation.
- Input limits in P201 are conservative candidates. Later stories may tighten them with evidence, but cannot silently broaden them.
- Imported sources are immutable. P207 must stage, validate, convert, and atomically publish derived assets.
- Domain remains independent of Godot, XML parsing, GUI, OS APIs, and file I/O.
- Security tests for XXE/DTD, excessive XML depth/elements, Zip Slip, symlinks, zip bombs, traversal, and oversized inputs are mandatory in their owning implementation stories.

## Evidence and remaining work

Raw evidence is stored at `artifacts/raw/phase2-p201-baseline-20260812/run-manifest.json`; execution logs and the generated build remain under `artifacts/reports/` and `artifacts/builds/` and are reproducible rather than product source.

P202 through P217 remain incomplete. No Phase 2 functionality or release permission is implied by this baseline.
