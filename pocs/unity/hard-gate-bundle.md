# Unity hard-gate bundle (U06)

Run the no-retry, CLI-only clean-import test and release build with:

```sh
scripts/run-unity-u06
```

The command copies source and retained inputs to a temporary clean-checkout
equivalent while excluding Unity's `Library` and `UserSettings`, runs the
EditMode suite once, builds once, then generates the deterministic judgement
slice and visual capture. It does not delete or reuse the working project's
cache for the clean timing.

The E01-readable manifest, build metadata, and per-gate result are written to
`artifacts/raw/unity-u06/`. Generated logs, screenshot, and release player are
under the ignored `artifacts/reports/unity-u06/` and
`artifacts/builds/unity-u06/` directories. A `Not Measured` or `Fail` result is
retained as such; the command performs no automatic retry.
