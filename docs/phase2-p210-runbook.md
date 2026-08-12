# P210 Mood Pan Calibration Acceptance

Use `artifacts/builds/phase2-p210-calibration-20260812/PanBeat.zip` with Mood Pan already connected in Handpan / Minor mode. The build SHA-256 is recorded in the preparation manifest. A Tone/Ding hit within 400 ms before or after a cue is associated with that cue; early hits are retained as negative timing deltas.

## Prepare

```sh
mkdir -p /tmp/panbeat-p210-calibration
unzip -oq artifacts/builds/phase2-p210-calibration-20260812/PanBeat.zip -d /tmp/panbeat-p210-calibration
```

Each run emits nine cues 1.5 seconds apart. Strike Tone or Ding once, promptly after each sound/`HIT NOW` flash. Do not strike between cues. `MISS`, `EXTRA HIT`, hits beyond 400 ms, and timing outliers more than 60 ms from the initial median are displayed as `EXCLUDED`. Analysis succeeds when at least five stable samples remain.

## Session 1: proposal and persistence

```sh
/tmp/panbeat-p210-calibration/PanBeat.app/Contents/MacOS/PanBeat -- --calibration --calibration-diagnostics-output="$PWD/artifacts/raw/phase2-p210-real-device-20260812/baseline-diagnostics.json"
```

1. Click **Start 9 Cues** and strike Tone/Ding for every cue.
2. Click **Analyze**. Confirm `PASS — PROPOSAL READY` shows median and MAD; otherwise repeat.
3. Note the before values, proposed Input Offset, and adjusted-median preview.
4. Click **Apply & Save**, then **Save Diagnostics**, then **Quit**.
5. Relaunch the same command. Confirm the saved offsets are restored. Quit without overwriting the first diagnostic.

## Session 2: positive Input Offset sign

```sh
/tmp/panbeat-p210-calibration/PanBeat.app/Contents/MacOS/PanBeat -- --calibration --calibration-diagnostics-output="$PWD/artifacts/raw/phase2-p210-real-device-20260812/positive-input-offset.json"
```

Capture and Analyze nine cues. Set **Input Offset** exactly 50 ms above the proposed value. Confirm `Adjusted median preview` becomes 50 ms later/more positive than at the proposal. Do not apply. Save Diagnostics and Quit.

## Session 3: negative Input Offset sign

```sh
/tmp/panbeat-p210-calibration/PanBeat.app/Contents/MacOS/PanBeat -- --calibration --calibration-diagnostics-output="$PWD/artifacts/raw/phase2-p210-real-device-20260812/negative-input-offset.json"
```

Capture and Analyze nine cues. Set **Input Offset** exactly 50 ms below the proposed value. Confirm `Adjusted median preview` becomes 50 ms earlier/more negative than at the proposal. Do not apply. Save Diagnostics and Quit.

Do not edit the generated JSON. Session 1 establishes the real-device proposal and persistence. Sessions 2 and 3 establish the existing sign convention with physical Mood Pan input; they are not external end-to-end latency measurements.
