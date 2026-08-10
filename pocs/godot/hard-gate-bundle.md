# Godot hard-gate bundle (G06)

Run the no-retry, CLI-only clean-import test and release export with:

```sh
scripts/run-godot-g06
```

The command copies source and retained inputs to a temporary clean-checkout
equivalent while excluding Godot's `.godot` cache, runs the headless suite
once, exports once, then generates the deterministic judgement slice and
visual capture. It does not delete or reuse the working project's cache for
the clean timing.

The E01-readable manifest, build metadata, and per-gate result are written to
`artifacts/raw/godot-g06/`. Generated logs, screenshot, and release export are
under the ignored `artifacts/reports/godot-g06/` and
`artifacts/builds/godot-g06/` directories. A `Not Measured` or `Fail` result is
retained as such; the command performs no automatic retry.

The first clean-cache attempt exposed an implicit global-class dependency in
`note_visual_kinematics.gd` and stopped before export. Its failed
`artifacts/reports/godot-g06/headless.log` is retained. After replacing the
implicit lookup with an explicit preload, a separately invoked verification
attempt passed 45/45 and exported successfully; the bundle accounts for both
attempts rather than replacing the failure.
