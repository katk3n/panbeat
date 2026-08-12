# MusicXML Import Contract

P203 accepts MusicXML 4.0 `score-partwise` with one part, one voice, monophonic pitched notes and rests, positive integer durations/divisions, time signatures, `sound` or metronome tempo, and tie start/stop information. Divisions changes are normalized to an integer `ticks_per_quarter` model without using frame time.

Chord, tuplet, grace note, repeat/volta/navigation, backup/forward, multiple parts, and multiple voices are errors. They are never silently discarded. Diagnostics include severity, code, source, part, measure, element, parser line, message, and remediation.

The reader rejects sources above 16 MiB before XML decoding. It scans out `DOCTYPE` and entity declarations before opening Godot's streaming parser, then enforces depth 64 and 250,000 elements. No network or file entity resolution path is exposed. P207 `.mxl` archive security and atomic publication are specified in [`song-import.md`](./song-import.md).

PanBeat overlay `1.0.0` binds to the exact source MusicXML SHA-256. Each annotation selects exactly one runtime note by stable note ID or complete part/measure/tick/voice coordinate. Slap is accepted only as an explicit overlay annotation. Tone and Ding may resolve from pitch only through the selected Instrument Profile or an explicit pitch mapping; the importer does not guess from arbitrary MusicXML notation.

Run the story verification with:

```sh
scripts/check-phase2-p203 phase2-p203-musicxml-YYYYMMDD
```
