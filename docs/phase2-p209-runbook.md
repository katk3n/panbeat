# P209 Mood Pan Device Setup Acceptance

## Prepared build and evidence

Use the build at `artifacts/builds/phase2-p209-device-setup-20260812/PanBeat.zip`. Its checksum is recorded in the P209 preparation manifest. Evidence is written to `artifacts/raw/phase2-p209-real-device-20260812/device-diagnostics.json` only when **Save Diagnostics** is pressed.

## Setup

1. Set Mood Pan to **Handpan / Minor**.
2. Connect it by USB to the Mac.
3. Open Terminal at the PanBeat repository root.
4. Run:

   ```sh
   mkdir -p /tmp/panbeat-p209-device
   unzip -oq artifacts/builds/phase2-p209-device-setup-20260812/PanBeat.zip -d /tmp/panbeat-p209-device
   /tmp/panbeat-p209-device/PanBeat.app/Contents/MacOS/PanBeat -- --device-setup --device-diagnostics-output="$PWD/artifacts/raw/phase2-p209-real-device-20260812/device-diagnostics.json"
   ```

`-o` is required when rerunning after replacing the build: it overwrites the previously extracted app with the verified build.

The screen must show `READY`, an MN-10 MIDI port, and the canonical `roland-mn10-handpan-minor-v1` profile. If macOS asks for permission, allow MIDI access and relaunch the command.

## Session steps

1. Strike outer Tone Field 1. Confirm `MAPPED — TONE → tone-1` with note and velocity.
2. Strike Ding. Confirm `MAPPED — DING → ding`.
3. Strike left and right Slap. Confirm `MAPPED — SLAP → outer-hit-radius` for both.
4. Click **Reopen MIDI**, then repeat Tone and Ding. Confirm each physical strike produces one monitor row, not duplicates.
5. Disconnect USB. Confirm the screen does not claim that silence alone proves physical disconnection.
6. Reconnect USB and click **Reopen MIDI**. Repeat Tone, Ding, and Slap.
7. If input does not recover, click **Quit**, relaunch the exact command, and confirm the relaunch guidance works.
8. Click **Save Diagnostics** and confirm the screen reports the absolute evidence path.
9. Click **Quit**.

## Recovery

- `NO MIDI PORTS`: verify USB and Handpan / Minor, then click **Reopen MIDI**.
- `OPEN FAILED`: close other MIDI applications, click **Reopen MIDI**, then relaunch if necessary.
- `UNSUPPORTED DEVICE / PROFILE MISMATCH`: select the MN-10 port; do not continue with another device/profile.
- No input despite a listed port: Godot cannot expose physical disconnect state. Reopen once, then quit/relaunch after reconnecting.

Do not edit the diagnostic JSON. Report any mismatch between the physical strike and displayed technique/target separately.

## Follow-up session when reconnect evidence is missing

Keep the first diagnostic file unchanged. Disconnect Mood Pan **before** starting PanBeat, then run:

```sh
/tmp/panbeat-p209-device/PanBeat.app/Contents/MacOS/PanBeat -- --device-setup --device-diagnostics-output="$PWD/artifacts/raw/phase2-p209-real-device-20260812/connect-after-launch-diagnostics.json"
```

1. Confirm `NO MIDI PORTS` at launch.
2. Connect Mood Pan, click **Reopen MIDI**, and confirm `READY` with `MN-10`.
3. Strike outer Tone Field 1, Ding, left Slap, and right Slap once each.
4. Disconnect Mood Pan, click **Reopen MIDI**, and confirm the failure/no-port history remains visible.
5. Reconnect Mood Pan, click **Reopen MIDI**, and confirm `READY` again.
6. Strike Tone Field 1 and Ding once each. Confirm one mapped row per strike.
7. Click **Save Diagnostics**, then **Quit**.

This second file must contain the initial no-port lifecycle, successful reopen, disconnected reopen, reconnect reopen, and mapped Tone / Ding / Slap records. It complements rather than replaces the connected-at-launch diagnostic.
