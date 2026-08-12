# Local Song Repository and Song Library

P208 reads the versioned song index from the OS application data directory and resolves only repository-relative package paths. The list order is deterministic by case-folded title and song ID. A corrupt or missing package becomes an `INVALID` row with actionable diagnostics; it does not prevent valid songs from loading.

The screen displays textual `EMPTY`, `LOADING`, `VALID`, `WARNING`, and `INVALID` states. Each song exposes title, artist, duration, chart version, selected-profile compatibility, import version, artwork availability, and diagnostics. Buttons and list rows participate in normal keyboard focus order; the initial focus is placed on Import.

Import and Re-import use the P207 service. Users select MusicXML/MXL, WAV/Ogg audio, and an optional overlay. Re-import requires a selected song, retains its stable song ID, and creates a new immutable import version. Failures display their error code, explanation, and remediation in the details area.

Delete is a two-step confirmation. The preview names `packages/<song_id>` and states that external source MusicXML/audio are unchanged. Confirmation first removes the song from the atomic index, making it invisible, then removes all cached import versions. A cache cleanup failure is retained as a warning and never restores a stale Library entry.

Run verification with:

```sh
scripts/check-phase2-p208 phase2-p208-library-YYYYMMDD
```
