# NotePan Import Contract

P401 accepts uncompressed NotePan `.pan` schema 6 and schema 8 tablatures directly in the Godot product. The reader requires the literal `PAN` header, content type `0`, exactly one track, at least one bar and one playable attack. Bundles, compressed streams, unsupported schema versions, multiple tracks, malformed strings/counts, truncated input, invalid rhythmic references, and notes outside the reconstructed column grid fail with actionable diagnostics. Schema 8 handpan pitch enums, fixed-size note records, and bounded footer data are normalized into the same Symbolic Score contract as schema 6.

The source limit is 16 MiB. A single encoded string is limited to 1 MiB and all declared records share a 250,000-record budget. Counts and remaining bytes are checked before iteration or allocation. The reader uses 96 ticks per quarter; subdivisions and split cells that cannot be represented as integer ticks are rejected. Discrete tempo events are preserved at their bar and beat. NotePan tempo ramps are linearly expanded at the same 96-tick resolution, including both their starting and final BPM, so the existing deterministic tempo-map contract remains unchanged. When a later explicit NotePan tempo shares the ramp endpoint tick, that explicit value takes precedence and a playable warning is retained. Incomplete, overlapping, out-of-range, or excessively large ramp expansions are rejected with specific diagnostics.

Embedded absolute pitches resolve through the song-specific performance layout without MusicXML's written-octave option. Normal pitched slots and Ding use their source pitch. Ghost `g` advances score time without a Runtime Note. `S`, `T`, and Knock `K` map to Slap; `d`, `P`, and `F` map to Ding. Schema 6 code `40` and schema 8 code `152` are the canonical `K` encodings. When `S`, `T`, or `K` shares an attack with a pitched note, the technique member is omitted and the pitched member remains, matching the existing NotePan-authored MusicXML chord rule. A technique without exactly one matching target in the selected profile is rejected.

Nuance, effect, grace, finger-roll, background-only, annotation, and unknown trailing schema 6 data do not alter PanBeat gameplay. The importer preserves the base attack where applicable and writes explicit non-blocking warnings into package `1.3.0`. Such songs display `WARNING` but remain playable. A profile mismatch remains a non-playable warning. Schema 8's normal nuance value is normalized without a warning.

The `.pan` title and artist are defaults when the import request leaves them blank. Its explicit scale string becomes `handpan_scale_name` when it is a trimmed single-line value of at most 80 characters; invalid source metadata is warned and omitted. PanBeat overlay and `notation_octave_shift` are not accepted for `.pan` sources. Optional WAV/Ogg backing audio follows the existing atomic import path.

NotePan striking-hand lanes are preserved as Runtime Chart `hand` values. In schema 6 and schema 8, lanes 0–1 map to `right` and lanes 2–3 map to `left`; other values are rejected. Schema 8 files commonly use lanes 1 and 2, but may use lanes 0 and 3 for additional same-hand chord members. Hand is copied from the source lane and is never inferred from pitch, target position, or note order.

Run the focused contract with:

```sh
scripts/godot --path game --headless --script res://tests/run_p401_tests.gd
```
