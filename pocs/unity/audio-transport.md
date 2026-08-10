# Unity DSP audio transport (U02)

`DspGameTransport` derives song time directly from an injected audio clock; it
does not accumulate frame deltas. Production uses `UnityDspClock`, backed by
`AudioSettings.dspTime`. `ScheduledAudioTransport` schedules an `AudioSource`
with `PlayScheduled` and a default 100 ms lead, then starts the domain
transport at the exact scheduled DSP time.

Pause stores song time and shifts the DSP origin on resume. A frame stall needs
no recovery callback: the next read derives the correct position from the
audio clock. EditMode tests use a fake clock to cover scheduled lead,
pause/resume, and a 5.5 second frame jump.

Run tests and collect drift evidence from the repository root:

```sh
scripts/check-unity --mode test
scripts/measure-unity-drift --duration-seconds 30 --label 30s
scripts/measure-unity-drift --duration-seconds 300 --label 5m
```

Raw JSONL and its audio-settings manifest are written under
`artifacts/raw/unity-u02/`. Logs are written under
`artifacts/reports/unity-u02/`. Each manifest records Unity version, requested
duration, sample interval, output sample rate, DSP buffer length/count, and the
`unity_audio_settings_dsp_time` clock domain.

The 2026-08-10 U02 run produced 297 samples over 30 seconds and 2,970 samples
over five minutes at 44.1 kHz with a 1024 x 4 DSP buffer. Signed
DSP-minus-monotonic statistics are in `artifacts/raw/unity-u02/summary.json`;
the raw samples remain authoritative. Verify their integrity with:

```sh
(cd artifacts/raw/unity-u02 && shasum -a 256 -c checksums.sha256)
```
