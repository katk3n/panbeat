# Evaluation artifacts

`raw/` stores immutable raw evidence with a unique run ID. Raw evidence is not
ignored and may be committed when a later story produces it.

`reports/`, `builds/`, and `tmp/` contain reproducible or disposable generated
output and are ignored. Commands create those directories when needed; their
absence in a clean clone is expected.
