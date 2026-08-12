# P214 external latency decision

External physical strike-to-feedback latency measurement is **not planned**. On 2026-08-12, the product owner confirmed that suitable high-speed camera or audio-loopback equipment is unavailable and explicitly chose not to perform this measurement, rather than postpone it to a later phase.

PanBeat does not convert software timestamps into an asserted end-to-end latency value. The distinct measurement points remain documented as physical contact, device/CoreMIDI arrival, Godot acceptance, judgement creation, and visible/audio feedback. Current Godot diagnostics do not expose the OS MIDI receive timestamp and cannot observe physical contact.

No future equipment procurement, recording session, or operator action is required by the current product plan. R-P1-001 and R-P1-003 remain recorded as existing Final Phase release-gate risks; this decision neither measures nor resolves them.
