# Song Import Pipeline

P207 imports `.musicxml`, `.xml`, or `.mxl` plus optional PanBeat overlay JSON and WAV/Ogg audio. Run:

```sh
scripts/check-phase2-p207 phase2-p207-import-YYYYMMDD
```

The Application service inspects extensions, byte limits, and SHA-256 without modifying sources. MusicXML is parsed by the safe reader, compiled deterministically, merged with the source-bound overlay and selected Instrument Profile, and written with canonical JSON. FFmpeg converts supported input audio into 48 kHz stereo Ogg Vorbis using the accepted P206 settings.

## MXL security limits

An MXL archive is rejected before rootfile parsing when it exceeds 32 MiB, 256 entries, 64 MiB expanded data, or a 100:1 compression ratio. The central directory is inspected for encrypted entries, duplicate names, absolute/drive/backslash paths, `.` or `..` traversal, Unix symlinks, and special files. `META-INF/container.xml` must contain exactly one safe `.xml` or `.musicxml` rootfile. DTD and entity declarations are forbidden.

Only the declared rootfile is read; the archive is never expanded into the Song Repository.

## Atomic publication and recovery

Import writes `source.musicxml`, optional `overlay.json`, `chart.json`, `runtime.ogg`, and `package.json` below a hidden staging directory. Every step must pass before the staging directory is renamed to its immutable version path. The atomic song index is saved last, so a crash, cancellation, conversion failure, or validation error cannot expose a partial song to Song Library. If index publication fails, the newly renamed package is removed.

The index stores paths relative to the Song Repository and package metadata stores only the original filename, never a user-specific absolute source path.

## Duplicate and update policy

The cache key covers importer version, MusicXML content SHA-256, overlay SHA-256, Instrument Profile SHA-256, explicit pitch mapping SHA-256, and audio SHA-256.

- Content matching the active indexed version is an idempotent duplicate and creates no files or index changes.
- Changed content imported with the same `song_id` keeps that ID and increments `import_version`.
- The index exposes one active version per `song_id`; previous immutable packages remain cache data for P208 lifecycle management.
- Re-importing older content after another version became active creates a new version rather than silently rolling the index backward.

Diagnostics contain severity, code, file, part, measure, element or overlay/archive location, message, and remediation. Unknown schema major versions are rejected by the owning MusicXML, overlay, profile, or persistence contract.
