# Godot 4.6 toolchain

F07 fixes the Godot lane to Standard Godot `4.6.stable.official.89cea1439`.
The editor and Standard export templates are installed under the ignored
repository-local `.tools/godot/4.6/` directory; no personal `PATH` entry is
required. Invoke it through `scripts/godot`.

The official macOS Universal editor SHA-256 is
`fc15ceb6280420f117ab4ef62332654db0088078faeeb9025dd814276185ed3b`.
The Standard export-template TPZ SHA-256 is
`3b30ac8c1772f25f5dfa5f65922cab0a90e7b960176891237c5772515ebccc46`.
Download URLs and the installation result are preserved in
`artifacts/raw/f07-godot-toolchain-20260809/install.json`.

Verification:

```sh
scripts/godot --version
scripts/godot --headless --path /path/to/project --editor --quit
scripts/godot --headless --path /path/to/project \
  --export-release macOS /absolute/output.zip
```

The isolated F07 fixture parsed and ran typed GDScript headlessly, printing
`PANBEAT_F07_HEADLESS_OK`, and produced a macOS release ZIP with exit status 0.
In the Codex sandbox, use an explicit `--log-file` under `/private/tmp` because
the sandbox denies Godot's default `user://logs` location.
