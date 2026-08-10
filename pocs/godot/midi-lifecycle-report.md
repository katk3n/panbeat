# Godot Mood Pan lifecycle result (G03)

The verified 45-second run captured Pad 1 x3 before USB disconnect and Pad 1
x3 after reconnect: 24 raw events total and six Note 50 / Ch.1 Note On events.
All six Note On events normalized to Handpan `ding` / `ding`.

Godot's public MIDI API continued to list `MN-10` during physical disconnect,
so no port disappearance is claimed. The existing standard adapter stopped
receiving during disconnection and resumed automatically after reconnection.
OS receive timestamps are unavailable and are not fabricated. Relative
delivery-jitter spread calculated from the 24 Godot arrival records was 0 us
minimum, 20 us p50, 69 us p95, 74 us p99, and 74 us maximum; this is arrival
handling jitter, not CoreMIDI receive latency.

Evidence: `artifacts/raw/godot-g03/lifecycle-verified.jsonl`. Verify with:

```sh
(cd artifacts/raw/godot-g03 && shasum -a 256 -c checksums.sha256)
```
