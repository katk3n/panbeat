# Godot PoC

This is the typed-GDScript Godot 4.6 Phase 0 project. Project settings, scene,
scripts, and export preset are text. Generated `.godot` state and credentials
are excluded by the repository ignore rules.

Domain is a `RefCounted` contract without Node, OS, GUI, or filesystem
dependencies. Infrastructure and Presentation may preload Domain but not each
other. The PoC consumes shared contracts and fixtures rather than maintaining
Godot-specific copies. It uses no C#, preserving a future Web path.

The fixed repository-local toolchain is documented in
[`toolchain.md`](toolchain.md). Run:

```sh
scripts/check-godot --mode test
scripts/check-godot --mode build
scripts/check-godot --mode all
```

Tests use a typed headless `SceneTree`. The macOS development export is written
to `artifacts/builds/godot-g01/PanBeat.zip`; logs go under
`artifacts/reports/godot-g01/`. No Editor GUI setup is required.
