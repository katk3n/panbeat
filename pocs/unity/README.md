# Unity PoC

This is the Unity 6000.3.21f1 Phase 0 project. Unity source, `.meta` files,
package lock, scene, and project settings are text and version controlled.
Generated `Library`, `Temp`, `Obj`, `Build`, `Logs`, and `UserSettings` data is
excluded by the repository ignore rules.

The assembly dependency direction is explicit: `PanBeat.Domain` has no Unity,
OS, GUI, or filesystem dependencies; Infrastructure and Presentation may
reference Domain but do not reference each other. The PoC consumes contracts
and fixtures outside this directory rather than maintaining Unity-specific
copies.

The fixed Editor path, license boundary, and verification commands are
documented in [`toolchain.md`](toolchain.md).

Run the reproducible U01 checks from the repository root:

```sh
scripts/check-unity --mode test
scripts/check-unity --mode build
scripts/check-unity --mode all
```

Test XML and logs are written under `artifacts/reports/unity-u01/`. The macOS
development player is written to `artifacts/builds/unity-u01/PanBeat.app`.
Both locations are generated and ignored. The build scene and PlayerSettings
are selected by text source and `PanBeat.Editor.BuildCommand`; no Editor GUI
setup is required.
