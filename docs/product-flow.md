# Product flow and recovery UX (P212)

Launching the packaged app without an explicit `--input-mode` opens the product flow. First launch, missing saved MIDI selection, or no currently visible MIDI port starts at Device Setup. A configured launch with a visible device starts at Song Library; an empty library explicitly asks the user to import a song.

The Application-layer `ProductFlowService` owns Boot, Device Setup, Song Library, Calibration, Gameplay, and Results transitions. The visible Device, Songs, Calibration, and Results navigation buttons are available from every inactive top-level screen. It rejects invalid transitions, duplicate sessions, and navigation away from an active session. Screen transitions remove view-owned resources immediately; on Godot 4.6/macOS the process-level CoreMIDI driver intentionally remains open because CoreMIDI cannot be reopened after a view closes it.

Recoverable errors show a user explanation, technical details, and keyboard-accessible Retry, Cancel, and Back actions. Fatal startup/storage errors stop with technical diagnostics and Back; they are never displayed as success. Import-specific remediation remains visible in Song Library, MIDI reopen/relaunch guidance remains in Device Setup, Calibration provides retry/reset, and Results isolates broken records.

Automation remains explicit and deterministic:

```sh
PanBeat -- --input-mode replay --replay-speed=4 --quit-on-complete
PanBeat -- --input-mode midi
PanBeat -- --device-setup
PanBeat -- --song-library
PanBeat -- --calibration
PanBeat -- --results
```

The MIDI/replay paths call the same ProductFlow session guard before creating Gameplay. P213 owns selecting an imported package and replacing the current Gameplay placeholder with the imported-song vertical slice.
