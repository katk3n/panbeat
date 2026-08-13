# Phase 0 data contracts

These JSON Schema 2020-12 contracts are the executable specification shared by
the Unity and Godot PoCs:

- `panbeat-chart.schema.json`: minimal timed chart
- `instrument-profile.schema.json`: raw MIDI note to technique/target mapping
- `raw-midi-trace.schema.json`: one record in a JSON Lines MIDI trace
- `judgement-record.schema.json`: one expected or observed judgement
- `run-manifest.schema.json`: reproducibility metadata and artifact links
- `settings.schema.json`: device, profile, and offset settings
- `song-index.schema.json`: locally imported song metadata
- `result-history.schema.json`: bounded local gameplay result history
- `panbeat-overlay.schema.json`: source-bound explicit gameplay annotations
- `song-package.schema.json`: immutable imported source/chart/audio package metadata

All instances require an explicit supported `schema_version`. Most contracts
remain at `1.0.0`. PanBeat overlay supports `1.1.0` for optional
`handpan_scale_name` metadata. Imported song packages support that metadata in
`1.1.0` and add score-source format/path plus persistent NotePan import warnings
in `1.2.0`. Existing `1.0.0` documents remain valid. A breaking change requires
a new schema version and fixtures; consumers reject unknown versions.

## Cross-language representation rules

These rules are normative for both C# and typed GDScript:

- JSON `integer` values must be read as signed 64-bit integers. For exact JSON
  interoperability, schemas restrict general-purpose integers to the safe
  range `-9007199254740991..9007199254740991`. Timestamp and duration fields
  use non-negative integer microseconds and must never pass through a
  single-precision float.
- `timestamp_us` is meaningful only together with its explicit `clock_domain`.
  Values from different clock domains must not be compared until an adapter
  performs and records a conversion.
- Enum strings are lower-case ASCII and closed to values listed by the schema.
  C# and GDScript consumers must fail on unknown values.
- Optional properties are omitted. The schemas do not use JSON `null`, so a
  missing value must not be serialized as `null`, `0`, or an empty string.
- Objects reject undeclared properties. This prevents a spelling error from
  being silently ignored by one engine.
- MIDI `channel_wire` is zero-based (`0..15`); `channel_display` is one-based
  (`1..16`). Raw bytes remain integers in `0..255`.
- File paths in manifests are repository-relative POSIX-style paths. SHA-256
  values are lower-case hexadecimal strings.

Technique values are `tone`, `ding`, and `slap`. `target_id` is deliberately a
string because the instrument profile owns the physical layout. Both engines
must use the same profile rather than infer a target from the note number.
Profiles bind an explicit Tone/Style setting, velocity range, unknown-message
policy, and deduplication policy. A profile for one setting must not be used as
a fallback for another setting.

## Validation

Install the pinned dependency once and run the fixture contract suite:

```sh
npm install
scripts/validate-fixtures
```

The command validates each case listed in
`shared/fixtures/schema-cases.json`. Valid cases must pass and invalid cases
must fail for the suite to succeed. Use `--help` for options.

The measured Mood Pan profile and coverage audit are documented in
`pocs/instrument-profile.md`.
