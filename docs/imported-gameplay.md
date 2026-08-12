# Imported song Gameplay (P213)

Song Library enables **Play Selected** only for a valid, profile-compatible imported package. The request passes the resolved package directory through the P212 Application flow and starts the existing Runtime Chart, radial scheduler, and judgement pipeline. With backing audio, external `runtime.ogg` is loaded from the atomic package and the audio playback clock remains musical time; package duration comes from the converted audio. Without backing audio, no runtime audio asset is required and an elapsed monotonic clock runs to the score duration. Frame count is never used as musical time. This keeps Gameplay visible until the audio ends when present, while allowing Mood Pan-only performance when accompaniment is unnecessary.

Completion is guarded by the existing one-shot summary flag, creates one P211 result with song/importer/chart/profile/judgement/score provenance, appends it atomically once, and opens Results. Duplicate `result_id` values are rejected. Pause/resume continues to use the same audio playback position and transport logic as the Phase 1 vertical slice.

The repository-authored CC0 fixture `shared/fixtures/musicxml/p213-acceptance.musicxml` and its checksum-bound overlay cover Tone, Ding, Slap, a tie across adjacent notes, and a 120→90 BPM tempo change. Its audio input for automated import is the existing repository-owned Phase 1 practice WAV; the importer creates the runtime Ogg without modifying the source.

Verification:

```sh
scripts/check-phase2-p213 phase2-p213-imported-gameplay-20260812
scripts/check-game --mode test --run-id phase2-p213-regression-20260812
scripts/check-game --mode build --run-id phase2-p213-imported-gameplay-20260812
```
