# Song Import Pipeline

P207 imports `.musicxml`, `.xml`, or `.mxl` plus optional PanBeat overlay JSON and optional WAV/Ogg backing audio. Run:

```sh
scripts/check-phase2-p207 phase2-p207-import-YYYYMMDD
```

The Application service inspects extensions, byte limits, and SHA-256 without modifying sources. MusicXML is parsed by the safe reader, compiled deterministically, merged with the source-bound overlay and selected Instrument Profile, and written with canonical JSON. When backing audio is supplied, FFmpeg converts it into 48 kHz stereo Ogg Vorbis using the accepted P206 settings. Without backing audio, package duration comes from the score and Gameplay uses a monotonic clock.

## MXL security limits

An MXL archive is rejected before rootfile parsing when it exceeds 32 MiB, 256 entries, 64 MiB expanded data, or a 100:1 compression ratio. The central directory is inspected for encrypted entries, duplicate names, absolute/drive/backslash paths, `.` or `..` traversal, Unix symlinks, and special files. `META-INF/container.xml` must contain exactly one safe `.xml` or `.musicxml` rootfile. DTD and entity declarations are forbidden.

Only the declared rootfile is read; the archive is never expanded into the Song Repository.

## Atomic publication and recovery

Import writes `source.musicxml`, optional `overlay.json`, `chart.json`, optional `runtime.ogg`, and `package.json` below a hidden staging directory. Every step must pass before the staging directory is renamed to its immutable version path. The atomic song index is saved last, so a crash, cancellation, conversion failure, or validation error cannot expose a partial song to Song Library. If index publication fails, the newly renamed package is removed.

The index stores paths relative to the Song Repository and package metadata stores only the original filename, never a user-specific absolute source path.

## Duplicate and update policy

The cache key covers importer version, cache contract version, MusicXML content SHA-256, overlay SHA-256, Instrument Profile SHA-256, explicit pitch mapping SHA-256, and audio SHA-256. The cache contract is bumped when NotePan technique semantics change so Re-import cannot return a chart produced by the older mapping.
It also covers `notation_octave_shift`. Song Library exposes “Written 1 octave high”; when selected, mapping resolves each written pitch one octave lower while preserving the source MusicXML pitch in the chart. This is explicit rather than auto-detected because the written and sounding ranges can overlap.

For NotePan-authored `<unpitched>` notes, the first NotePan lyric token is authoritative: `g` advances score time but is omitted from Gameplay, while standalone `S` and `T` both map to Slap. Mood Pan cannot play a Slap and Tone Field chord, so compound labels such as `T+1` and `S+6` omit the unpitched `T`/`S` member; only the pitched member from the following MusicXML chord note is imported and judged.

- Content matching the active indexed version is an idempotent duplicate and creates no files or index changes.
- Changed content imported with the same `song_id` keeps that ID and increments `import_version`.
- The index exposes one active version per `song_id`; previous immutable packages remain cache data for P208 lifecycle management.
- Re-importing older content after another version became active creates a new version rather than silently rolling the index backward.

Diagnostics contain severity, code, file, part, measure, element or overlay/archive location, message, and remediation. Unknown schema major versions are rejected by the owning MusicXML, overlay, profile, or persistence contract.
