# Phase 0 PoC development

Phase 0では、同じ実行可能仕様と測定条件を使ったmacOS向けvertical
sliceをUnity 6 LTSとGodot 4.6で作り、保存した証拠に基づいてエンジンを
選定する。Phase 0の目的と受け入れ条件の正本は
[`docs/phase0-stories.md`](../docs/phase0-stories.md)とする。

現在のhost toolchain監査と導入blockerは
[`toolchain-audit.md`](toolchain-audit.md)に記録する。
Mood Pan実機採取の操作境界と保存規約は
[`mood-pan-capture.md`](mood-pan-capture.md)に記録する。

## Repository layout

| Path | Purpose |
|---|---|
| `pocs/unity/` | Unity-only source and text project configuration |
| `pocs/godot/` | Godot-only source and text project configuration |
| `shared/fixtures/` | Version-controlled inputs and expected results shared by both PoCs |
| `shared/assets/` | Version-controlled source assets shared by both PoCs |
| `schemas/` | Engine-independent data contracts |
| `scripts/` | Stable repository command entry points |
| `artifacts/raw/` | Immutable raw evidence captured by evaluation runs |
| `artifacts/reports/` | Reproducible generated summaries; ignored by Git |
| `artifacts/builds/` | Generated engine builds; ignored by Git |
| `artifacts/tmp/` | Disposable working data; ignored by Git |

Do not edit raw evidence in place. A repeated capture receives a new run ID and
new file. Generated reports must link back to their raw inputs and should be
regenerated rather than committed. Canonical fixtures are inputs, not run
artifacts, and remain under `shared/fixtures/`.

## Commands

All command names use lower-case kebab-case, run from any working directory,
and resolve their default paths relative to the repository root. A command
prints diagnostics to standard error and returns a non-zero status when its
engine implementation is unavailable. Exit status `64` means invalid command
usage and `78` means that the requested Phase 0 implementation is not yet
present.

```text
scripts/check-unity [--project PATH] [--mode test|build|all]
scripts/check-godot [--project PATH] [--mode test|build|all]
scripts/compare-pocs [--unity-results DIR] [--godot-results DIR] [--output DIR]
scripts/validate-fixtures [--cases PATH]
scripts/generate-test-pack [generate|verify]
scripts/midi-trace validate|summarize|replay --input PATH [options]
scripts/midi-inspector list|capture|synthetic [options]
```

- `check-unity` will format/check, test, or build the Unity PoC. Its default
  project is `pocs/unity`; its default mode is `all`.
- `check-godot` provides the same contract for `pocs/godot`.
- `compare-pocs` will compare already-produced result bundles. Its default
  inputs are `artifacts/reports/unity` and `artifacts/reports/godot`, and its
  default output is `artifacts/reports/comparison`.
- Every command supports `--help`, which is safe before the implementation for
  that story exists.
- `validate-fixtures` checks the shared JSON Schema contract suite used by both
  engines. Its default case manifest is `shared/fixtures/schema-cases.json`.
- `generate-test-pack` deterministically creates or verifies the shared
  30-second chart/audio/golden-data pack and its ten-loop drift manifest.
- `midi-trace` validates raw JSONL without rewriting it, summarizes MIDI event
  distributions, and emits realtime or deterministic no-wait replay fixtures.
- `midi-inspector` lists CoreMIDI inputs and captures timestamped raw JSONL;
  its synthetic mode supports device-independent tests.

At repository story F02 these entry points deliberately fail with status `78`
for real work. Later engine and comparison stories replace that failure only
when the corresponding checks are implemented; they must never return success
without doing the documented work.

To validate the current shell entry points from the repository root:

```sh
sh -n scripts/check-unity scripts/check-godot scripts/compare-pocs
scripts/check-unity --help
scripts/check-godot --help
scripts/compare-pocs --help
scripts/validate-fixtures
scripts/generate-test-pack verify
```
