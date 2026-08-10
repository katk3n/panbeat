# Unity Mood Pan lifecycle result (U03)

The verified 45-second run started with MN-10 online, captured Pad 1 x3,
observed CoreMIDI `present -> absent -> present`, reconnected the source, and
captured Pad 1 x3 after reconnection. The trace contains 24 raw events and six
Note 50 / Ch.1 Note On events. Native queue dropped count is zero.

The MN-10 endpoint can remain enumerated while offline, so the adapter monitors
CoreMIDI `kMIDIPropertyOffline`, not source count alone. If that property is
not provided, the endpoint is treated as online; only an explicit offline value
marks it unavailable.

Evidence: `artifacts/raw/unity-u03/lifecycle-verified.jsonl`. Earlier failed
and smoke attempts are retained rather than overwritten. Verify all files with:

```sh
(cd artifacts/raw/unity-u03 && shasum -a 256 -c checksums.sha256)
```
