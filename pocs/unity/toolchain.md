# Unity 6.3 LTS toolchain

F08 fixes the Unity lane to `6000.3.21f1` (`c02631ffc030`) at:

```text
/Applications/Unity/Hub/Editor/6000.3.21f1/Unity.app/Contents/MacOS/Unity
```

Use `scripts/unity` so repository commands do not depend on an implicit
`PATH`. Mac Standalone Support is present. Batch mode resolved an assigned,
unlimited Unity Personal entitlement and successfully imported and closed an
isolated empty project without GUI interaction.

Verification:

```sh
scripts/unity -version -batchmode -quit -logFile -
scripts/unity -batchmode -nographics -quit \
  -projectPath /absolute/path/to/project -logFile -
```

The second command needs access to the user's Unity licensing service. In a
restricted Codex sandbox it must run with the approved Unity batch-mode
permission. Sanitized evidence is stored at
`artifacts/raw/f08-unity-toolchain-20260809/install.json`.

The host does not expose a standalone `dotnet` SDK. Unity's internal compiler
completed the empty-project import, but a shutdown-time auxiliary warning noted
the missing external SDK. Reassess only if a later package requires it.
