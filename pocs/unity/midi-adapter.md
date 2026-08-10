# Unity CoreMIDI adapter (U03)

The macOS adapter is a repository-owned Objective-C++ CoreMIDI plugin under
`NativeMidi/`. It has no third-party dependency or separate license. Build it
with `scripts/build-unity-midi-plugin`; the generated dylib is ignored and is
rebuilt automatically by `scripts/check-unity`.

The CoreMIDI callback parses short channel messages into a fixed 1,024-entry
native SPSC ring. It does not call Unity APIs, allocate, or log. Unity polls the
queue through `NativeMidiAdapter`. A full queue increments an atomic dropped
counter, so loss is never silent. Callback timestamps are converted from
CoreMIDI host ticks to monotonic microseconds before enqueue.

Lifecycle monitoring uses CoreMIDI's `kMIDIPropertyOffline`, because an MN-10
endpoint may remain enumerated while its USB connection is offline. The
adapter disconnects the stale source and reconnects when it becomes online.

Automated EditMode tests inject at the native boundary to verify byte/timestamp
preservation and observable overflow. Real lifecycle evidence is captured with:

```sh
scripts/unity-midi-lifecycle 45 verified
```

During the 45-second window, strike Pad 1 three times, disconnect USB, wait
three seconds, reconnect USB, wait three seconds, then strike Pad 1 three more
times. The command records port disappearance/reappearance, reconnection,
events, and dropped count to `artifacts/raw/unity-u03/lifecycle-verified.jsonl`.

The completed real-device result is documented in
`pocs/unity/midi-lifecycle-report.md`.
