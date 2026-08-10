# E02 macOS real-device comparison

Each engine uses its release build and the same 90-second script for three
sessions. Keep Mood Pan in Handpan / Minor. Exact strike strength is not a
criterion.

| Elapsed time | User action |
|---|---|
| 0-10 s | Confirm USB is connected; do not strike. |
| 10-25 s | Pad 1 three times; Pads 2-9 once each; left Slap three times; right Slap three times. |
| 25-35 s | Rapidly strike Pad 1 about ten times. The observed count, not an intended exact count, is authoritative. |
| 35-45 s | Strike Pads 2+3 together three times. |
| 45-55 s | Disconnect the USB cable and leave it disconnected. |
| 55-65 s | Reconnect and wait for recovery. |
| 65-85 s | Pad 1 three times; Pad 2 once; left Slap three times; right Slap three times. |
| 85-90 s | Do not strike. |

Codex starts one session at a time with `scripts/run-e02-session`. Raw files
are refused rather than overwritten. Human timing and subjective notes are
kept separate from adapter arrival timing. Godot cannot report an OS receive
timestamp; Unity's CoreMIDI packet timestamp is retained without claiming
physical strike latency.
