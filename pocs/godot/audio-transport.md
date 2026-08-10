# Godot audio-backed transport (G02)

`GameTransport` has the same observable behavior as Unity's transport and
depends only on an injected clock. `GodotAudioClock` derives playback time from
`AudioStreamPlayer.get_playback_position()`, time since the last AudioServer
mix, and output latency. It clamps reversals and counts every correction.

```sh
scripts/check-godot --mode test
scripts/measure-godot-drift 30 30s
scripts/measure-godot-drift 300 5m
```

Raw clock samples and manifests are stored under `artifacts/raw/godot-g02/`.
The manifest records Godot version, audio driver, mix rate, output latency,
backward count, correction count, and maximum reversal.

Headless Godot uses the `Dummy` audio driver on this host. Those runs verify
logging and correction behavior but are not treated as real output-latency
measurements; a release-build audio-device run remains for G06.

The 2026-08-10 run captured 290 samples over 30 seconds and 2,899 over five
minutes. Statistics are in `artifacts/raw/godot-g02/summary.json`. Verify the
immutable evidence with:

```sh
(cd artifacts/raw/godot-g02 && shasum -a 256 -c checksums.sha256)
```
