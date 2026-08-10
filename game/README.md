# PanBeat game

This is the Phase 1 production entry point promoted from the selected Godot
4.6 / typed GDScript PoC. Phase 0 capture harnesses remain frozen under
`pocs/`; product work belongs here.

From the repository root:

```sh
scripts/check-game --mode test
scripts/check-game --mode build
scripts/check-game --mode all
```

The release embeds the selected Handpan / Minor profile under `config/`.
Headless tests require that copy to remain exactly equal to the canonical
fixture under `shared/fixtures/`. Domain code does not depend on SceneTree,
MIDI, filesystem, or presentation APIs.
