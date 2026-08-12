# P216 Mood Pan MVP real-device acceptance

This acceptance uses the P215 release build and the same production UI used by an end user. Keep Mood Pan in **Handpan / Minor** mode. The three sessions below must be separate app launches.

External high-speed-camera and audio-loopback latency measurement is **not planned by product decision**. Do not perform it for P216. Physical observations, PanBeat software diagnostics, and the explicit non-execution decision remain separate evidence categories.

## Prepare once

From the repository root:

```sh
mkdir -p /tmp/panbeat-p216
unzip -oq artifacts/raw/phase2-p215-audio-duration-fix-20260812/PanBeat.zip -d /tmp/panbeat-p216
```

Expected build SHA-256: `2ba8dd9fc809f635a82ba59e9862074650ec11e6fc40e432bbbc47c56b114d08`.

The 2026-08-12 build keeps the Godot CoreMIDI driver open for the process lifetime so Device → Calibration → Gameplay transitions do not attempt an unsupported CoreMIDI reopen. Calibration shows `MIDI READY — MN-10` before capture and provides **Refresh MIDI**. It also derives transport duration from the converted audio rather than the shorter score, so Gameplay remains visible until the 36-second acceptance audio ends.

Acceptance files selected in the native file dialogs:

- Score: `shared/fixtures/musicxml/p213-acceptance.musicxml`
- Overlay: `shared/fixtures/musicxml/p213-acceptance-overlay.json`
- Audio: `game/content/phase1-fixed-song-v1/orbit-practice.wav`

Do not delete the PanBeat application-data directory between sessions; settings, imported songs, calibration, and Results history must persist. “Clean launch” here means PanBeat is fully quit before starting each session.

## Session 1 — setup, import, calibration, play

Connect Mood Pan by USB, then run:

```sh
/tmp/panbeat-p216/PanBeat.app/Contents/MacOS/PanBeat -- \
  --device-diagnostics-output="$PWD/artifacts/raw/phase2-p216-real-device-20260812/session-1-retry-device.json" \
  --calibration-diagnostics-output="$PWD/artifacts/raw/phase2-p216-real-device-20260812/session-1-retry-calibration.json" \
  --diagnostics-output="$PWD/artifacts/raw/phase2-p216-real-device-20260812/session-1-retry-gameplay.json"
```

1. Open **Device**. Select the `MN-10` port if needed. Confirm profile `roland-mn10-handpan-minor-v1 — Handpan / Minor`.
2. Strike an outer Tone, Ding, and Slap. Confirm the input monitor shows mapped `TONE`, `DING`, and `SLAP`. Press **Save Diagnostics**.
3. Open **Songs**. Enter title `P216 Acceptance`. Choose the score, audio, and overlay listed above, then press **Import**. Import again even if the old row exists; the corrected build publishes a new import version and replaces the selected library entry.
4. Confirm `IMPORTED`, select the `VALID` library row, and confirm `VALID — No import diagnostics.`
5. Open **Calibration**. Run **Start 9 Cues**, strike Tone/Ding once per cue, then **Analyze**. If it says `RETRY`, repeat until `PASS — PROPOSAL READY`.
6. Press **Apply & Save**, then **Save Diagnostics**. Note the saved Input and Audio offsets shown on screen.
7. Return to **Songs**, select `P216 Acceptance`, and press **Play Selected**.
8. During play, press Space once to pause and once to resume. Complete the song with Mood Pan; score quality is not a pass/fail condition.
9. Confirm the Results screen contains the completed song, score, accuracy, max combo, timing distribution, and judgement breakdown. Fully quit PanBeat.

## Session 2 — restart persistence and second completion

With Mood Pan connected, run:

```sh
/tmp/panbeat-p216/PanBeat.app/Contents/MacOS/PanBeat -- \
  --diagnostics-output="$PWD/artifacts/raw/phase2-p216-real-device-20260812/session-2-gameplay.json"
```

1. Confirm the product flow opens without re-importing the song.
2. Open **Calibration** and confirm the Input/Audio offsets saved in session 1 are restored. Do not reset them.
3. Open **Songs**, select the existing valid `P216 Acceptance`, and complete it again.
4. Confirm Results history now contains at least two P216 completions. Fully quit PanBeat.

## Session 3 — disconnect recovery and third completion

Disconnect Mood Pan before launching:

```sh
/tmp/panbeat-p216/PanBeat.app/Contents/MacOS/PanBeat -- \
  --device-diagnostics-output="$PWD/artifacts/raw/phase2-p216-real-device-20260812/session-3-recovery-device.json" \
  --diagnostics-output="$PWD/artifacts/raw/phase2-p216-real-device-20260812/session-3-gameplay.json"
```

1. Confirm **Device** reports `NO MIDI PORTS`.
2. Reconnect Mood Pan, press **Reopen MIDI**, and confirm `READY` with `MN-10`.
3. Strike Tone, Ding, and Slap once; confirm the monitor maps them. Press **Save Diagnostics**.
4. Open **Songs**, select the existing `P216 Acceptance`, and complete it a third time.
5. Confirm Results history contains at least three P216 completions and no record is shown as corrupt. Fully quit PanBeat.

If **Reopen MIDI** still says `NO MIDI PORTS`, fully quit PanBeat after reconnecting USB and relaunch the same session-3 command. This relaunch route is an acceptable recovery, but report which route was required.

After all three sessions, reply with `完了` and include any confusing screen, unexpected sound/display behavior, or recovery issue you noticed. If there were none, say `問題なし`. Codex will validate the diagnostics and Results history before marking P216 complete.
