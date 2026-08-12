# Orbit Practice — Phase 1 fixed song

This versioned package is the sole Phase 1 product song. All paths in
`package.json` are relative to this directory. Regenerate and verify it from the
repository root:

```sh
scripts/generate-phase1-song generate
scripts/generate-phase1-song verify
node --test scripts/generate-phase1-song.test.mjs
```

The checked-in audio is original deterministic CC0 synthesis; provenance and
format are recorded in `audio-provenance.json`. Audio sample zero is song time
zero. The first note is at 2 seconds and the last at 32 seconds in a 36-second
file, providing explicit preload/count-in and ending margins.

WAV PCM is the Phase 1 runtime format because Godot can decode it without codec
seek preroll or lossy encoder delay, and exact microsecond-to-sample sync is
reproducible. Its larger size is acceptable for one short fixed song. A five
minute mono 48 kHz/16-bit WAV would be about 28.8 MB; long-form content and
seek/loop storage trade-offs must be revisited with streaming formats in Phase
2. P111 validates playback longer than five minutes using a measurement asset,
not by extending this product song.
