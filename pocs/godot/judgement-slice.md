# Godot judgement slice (G05)

The Godot slice uses the same shared Handpan profile, recorded MIDI evidence,
transport contract, chart, and judgement boundaries as Unity. Input and audio
offsets are explicitly zero.

```sh
scripts/check-godot --mode test
scripts/run-godot-g05
```

Outputs under `artifacts/raw/godot-g05/` contain 60 Hz, 120 Hz, and frame-stall
judgement JSON plus performance log and run manifest. Each scenario must match
the F04 golden results exactly.
