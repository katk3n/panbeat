# Evaluation artifacts

`raw/` stores immutable raw evidence with a unique run ID. Canonical structured
evidence may be committed when a later story produces it. Large reproducible
application archives, exploratory runs, and superseded capacity-limited logs
stay local and are ignored; committed manifests retain their checksum, command,
and classification. A clean clone regenerates release archives through the
documented acceptance/build command.

`reports/`, `builds/`, and `tmp/` contain reproducible or disposable generated
output and are ignored. Commands create those directories when needed; their
absence in a clean clone is expected.
