# Phase 0 toolchain audit (F06)

Audit date: 2026-08-09 (Asia/Tokyo). Sanitized observations are stored in
`artifacts/raw/f06-toolchain-audit-20260809/environment.json`. License tokens,
machine identifiers, and Unity licensing IPC data are intentionally excluded.

## Result

| Component | Planned | Observed | Status |
|---|---|---|---|
| Host | macOS arm64 | macOS 26.5.2 (25F84), arm64, 24 GiB | Ready |
| Xcode / SDK | macOS build capable | Xcode 26.6, SDK 26.5 | Ready |
| Compiler | C/C++ compiler | Homebrew clang 22.1.1 | Ready |
| .NET | Audit only | `dotnet` not found | Missing; not required for typed-GDScript Godot lane |
| Godot | 4.6-stable Standard | Repository-local 4.6.stable.official.89cea1439 | Ready (F07) |
| Godot templates | 4.6-stable Standard | Repository-local macOS template | Ready (F07) |
| Unity Hub | Installed | `/Applications/Unity Hub.app` | Present; headless help exited 134 |
| Unity Editor | Unity 6 LTS | 6000.3.21f1 | Ready (F08) |
| Unity macOS module | Mac Standalone Support | Present in 6000.3.21f1 | Ready (F08) |
| Unity license | Batch mode license | Unity Personal assigned, unlimited | Ready (F08) |

Unity's binary is `/Applications/Unity/Hub/Editor/6000.1.17f1/Unity.app/Contents/MacOS/Unity`.
Its CLI version check succeeded. An isolated empty project reached the licensing
service in batch mode but failed before import with `No valid Unity Editor
license found`; headless test/build is therefore unavailable.

Godot 4.6-stable was released on 2026-01-26. F07 must install the official
Standard macOS Universal editor and Standard export templates, record download
checksums, and expose an explicit repository-resolved binary path.

## Reproduction commands

```sh
sw_vers
uname -m
xcode-select -p
xcodebuild -version
xcrun --sdk macosx --show-sdk-version
command -v dotnet
command -v godot
/Applications/Unity/Hub/Editor/6000.1.17f1/Unity.app/Contents/MacOS/Unity -version -batchmode -quit -logFile -
find /Applications/Unity/Hub/Editor/6000.1.17f1/Unity.app/Contents/PlaybackEngines -maxdepth 2 -type d -print
```

The batch project-open probe used the same Unity binary with `-batchmode
-nographics -quit -projectPath <isolated-temp-project> -logFile -`. Repeat it
after activation; the current failure is the F08 license blocker.

## Handoff

- F07 completed with repository-local Godot 4.6-stable and Standard templates.
- F08 completed with Unity 6000.3.21f1 and an assigned Personal entitlement.
- No engine PoC story may start until its F07/F08 acceptance conditions pass.
