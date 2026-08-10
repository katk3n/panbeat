# Mood Pan capture handoff (M02)

M01 provides the CoreMIDI inspector. M02 begins only after the user connects
the Mood Pan over USB MIDI and confirms the desired device appears in:

```sh
scripts/midi-inspector list
```

Each guided technique/setting gets a separate append-only session under
`artifacts/raw/m02-mood-pan-<date>/`. Codex will start captures with an explicit
port and human label, for example:

```sh
scripts/midi-inspector capture --port 0 \
  --label tone-field-1-weak-gamelan \
  --output artifacts/raw/m02-mood-pan-<date>/tone-field-1-weak-gamelan.jsonl
```

The user will perform the physical actions in the order requested by Codex:
all nine pads at weak/medium/strong velocity, Slap positions, Special Pad,
pressure, Mute, simultaneous hits, rapid hits, and requested Tone/Style changes.
Ctrl-C flushes and closes each session. Codex then validates and summarizes
each trace without modifying it. Uncaptured or ambiguous techniques remain
explicitly unverified.

The current evidence inventory and interpretation are recorded in
`pocs/mood-pan-capture-report.md`. Verify the immutable raw files from the
repository root with:

```sh
(cd artifacts/raw/m02-mood-pan-20260810 && shasum -a 256 -c checksums.sha256)
```

To repeat any capture, choose a new output filename so the original is not
overwritten, set the device to the Tone/Style encoded in the label, start the
command, perform only the labeled actions in order, and stop with Ctrl-C:

```sh
scripts/midi-inspector capture --port 0 \
  --label gamelan-minor-pads1-9-medium-recapture \
  --output artifacts/raw/m02-mood-pan-<date>/gamelan-minor-pads1-9-medium-recapture.jsonl

scripts/midi-trace validate \
  --input artifacts/raw/m02-mood-pan-<date>/gamelan-minor-pads1-9-medium-recapture.jsonl

scripts/midi-trace summarize \
  --input artifacts/raw/m02-mood-pan-<date>/gamelan-minor-pads1-9-medium-recapture.jsonl
```

The expected pad order is Pad 1 through Pad 9. For Slap use left x3 followed
by right x3. For simultaneous/rapid testing use Pad 2 + Pad 3 x3, pause, then
Pad 1 x10. Strength labels are qualitative rather than calibrated force.
