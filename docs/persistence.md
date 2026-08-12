# PanBeat Local Persistence

P202 defines three separately owned versioned documents under the OS application data directory returned by Godot. No personal absolute path is stored in source or persisted metadata.

| Document | Relative path | Owner and deletion responsibility |
|---|---|---|
| Settings | `v1/settings/settings.json` | Device and calibration settings; reset deletes only this document and its backup |
| Song index | `v1/songs/index.json` | Imported song metadata; Song Library deletion owns only the selected repository package/cache, never external source files |
| Result history | `v1/results/history.json` | Results; clear history deletes only this document and its backup |

Every document requires `schema_version`. Version `0.1.0` has an explicit migration to `1.0.0`; unregistered versions and unknown major versions are rejected with a diagnostic instead of being guessed.

Writes use a temporary sibling, readback validation, a backup of the previous primary, and rename publication. If publication fails after backup creation, the previous primary is restored. Reads try the primary first and recover the last valid backup when the primary JSON is corrupt. Failure diagnostics distinguish missing data, corrupt JSON, permissions, disk-full, and general I/O errors.

Tests pass an isolated temporary root and never read or write real user settings. Production constructs `UserDataRepositories` without an override so `OS.get_user_data_dir()` is resolved at runtime.
