# Phase 0 deterministic test pack

This directory is generated from `../test-pack-source.json`. Do not edit its
generated JSON or WAV files by hand.

- `chart.json`: 30-second, 120 BPM chart containing Tone, Ding, Slap, two
  simultaneous-note timestamps, and a five-second rest
- `click.wav`: original 48 kHz, mono, 16-bit PCM click track
- `click-samples.json`: exact note timestamps and corresponding sample indices
- `golden-inputs.json` / `golden-results.json`: exact and just-outside timing
  window vectors for Perfect, Great, Good, and Miss
- `drift-loop-manifest.json`: ten-loop, 300-second drift test parameters
- `audio-license.json`: generated-audio provenance and license
- `checksums.json`: SHA-256 checksums for every generated file above

Run `scripts/generate-test-pack generate` to regenerate and
`scripts/generate-test-pack verify` to compare the checked-in files with a
fresh in-memory generation.
