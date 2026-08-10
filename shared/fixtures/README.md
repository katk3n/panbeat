# Shared fixtures

These version-controlled fixtures are the executable specification used by
both engine PoCs. Engine-specific variants are not allowed unless the common
contract and both consumers are updated together.

- `midi-traces/`: recorded or synthetic MIDI input fixtures
- `charts/`: deterministic Phase 0 chart inputs
- `expected-results/`: golden judgement and timing results
- `schema-valid/`: examples that every contract must accept
- `schema-invalid/`: negative examples that every contract must reject
- `schema-cases.json`: schema-to-fixture validation manifest
- `instrument-profiles/`: measured, engine-independent MIDI mappings
- `instrument-profile-cases.json`: M02 trace scope and expected mapping counts
- `test-pack-source.json`: source parameters for the deterministic Phase 0 pack
- `test-pack/`: generated 30-second pack, golden data, and drift manifest

Fixtures are immutable inputs. Evidence produced by running them belongs under
`artifacts/raw/`; reproducible summaries belong under `artifacts/reports/`.

Run `scripts/validate-fixtures` from any working directory to validate both the
positive and negative contract cases.
