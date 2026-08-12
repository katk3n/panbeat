# Results and local history (P211)

Launch the standalone product view with `PanBeat -- --results`. P212 will connect this view to the full product navigation.

Each result is rebuilt from Phase 1 Judgement Records using the identified score-rule document. Stored identity includes song, importer, chart, Instrument Profile, judgement-rule, and score-rule versions. Timing median and EARLY / ON TIME / LATE counts use only `outcome=judged` records with numeric `delta_us`; Miss retains null timestamps, and Extra Hit plus wrong target/technique remain separate counts.

History is stored atomically at `user://v1/results/history.json`, newest first, with `max_records` defaulting to 100. Appending trims the oldest valid records. Malformed individual records are isolated from the Results view and reported as broken instead of hiding valid sessions. **Delete Selected** removes one result; **Clear History** removes all result records without affecting settings or imported songs.

Verification:

```sh
scripts/check-phase2-p211 phase2-p211-results-20260812
scripts/check-game --mode test --run-id phase2-p211-regression-20260812
scripts/check-game --mode build --run-id phase2-p211-results-20260812
```
