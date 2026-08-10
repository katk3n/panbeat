# Unity judgement slice (U05)

The Unity slice connects the shared Handpan profile mapper, recorded/native
MIDI event contract, DSP transport, shared chart model, and engine-independent
judgement windows. Input and audio offsets are both explicitly zero.

```sh
scripts/check-unity --mode test
scripts/run-unity-u05
```

The command writes judgement records for 60 Hz, 120 Hz, and an intentional
frame-stall scenario under `artifacts/raw/unity-u05/`, plus a performance log
and schema-valid run manifest. All scenario JSON must be identical to the F04
golden results.
