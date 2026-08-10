# Godot standard MIDI adapter (G03)

`GodotMidiAdapter` opens standard MIDI inputs and records every
`InputEventMIDI` with its `_input` arrival timestamp and process frame. Godot's
public API does not expose the CoreMIDI receive timestamp, so records explicitly
set `os_receive_timestamp_available` to false; no timestamp is invented.

Note On velocity zero becomes Note Off. Channel, pitch, velocity, CC, Poly
Pressure, and Channel Pressure fields are retained. The shared Handpan / Minor
profile produces normalized gameplay inputs; non-trigger and unknown messages
remain diagnostics. Port-list changes are recorded as lifecycle diagnostics.

Headless tests cover normalization and field preservation. Real startup,
disconnect, reconnect, and arrival-jitter evidence remains deferred until the
Mood Pan can be operated again.

The prepared real-device command is:

```sh
scripts/godot-midi-lifecycle 45 verified
```

Use the same script as Unity: Pad 1 x3, disconnect USB, wait three seconds,
reconnect USB, wait three seconds, then Pad 1 x3. Raw and normalized events,
port-list changes, arrival timestamps, process frames, and the explicit lack of
an OS receive timestamp are written to `artifacts/raw/godot-g03/lifecycle-verified.jsonl`.

The completed real-device result and public-API lifecycle limitation are
documented in `pocs/godot/midi-lifecycle-report.md`.
