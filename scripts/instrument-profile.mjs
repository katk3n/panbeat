#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";
import { auditTrace, validateProfileSemantics } from "./lib/instrument-profile.mjs";
import { createTraceValidator, readTrace } from "./lib/midi-trace.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const absolute = (candidate) => path.isAbsolute(candidate) ? candidate : path.join(root, candidate);
const readJson = (candidate) => JSON.parse(fs.readFileSync(absolute(candidate), "utf8"));

function usage() {
  process.stdout.write("Usage:\n  scripts/instrument-profile audit [--cases PATH] [--output PATH]\n");
}

const [command, ...arguments_] = process.argv.slice(2);
if (command === "--help" || command === "-h") {
  usage();
  process.exit(0);
}
if (command !== "audit") {
  usage();
  process.exit(64);
}

let casesPath = "shared/fixtures/instrument-profile-cases.json";
let outputPath;
for (let index = 0; index < arguments_.length; index += 1) {
  const argument = arguments_[index];
  if (argument === "--cases" && arguments_[index + 1]) casesPath = arguments_[++index];
  else if (argument === "--output" && arguments_[index + 1]) outputPath = arguments_[++index];
  else {
    process.stderr.write(`instrument-profile: invalid option ${argument}\n`);
    process.exit(64);
  }
}

const cases = readJson(casesPath);
const profile = readJson(cases.profile);
const profileSchema = readJson("schemas/instrument-profile.schema.json");
const rawSchema = readJson("schemas/raw-midi-trace.schema.json");
const ajv = new Ajv2020({ allErrors: true, strict: true });
const validateProfile = ajv.compile(profileSchema);
if (!validateProfile(profile)) {
  throw new Error(`invalid profile: ${ajv.errorsText(validateProfile.errors)}`);
}
const semanticErrors = validateProfileSemantics(profile);
if (semanticErrors.length) throw new Error(`invalid profile semantics: ${semanticErrors.join("; ")}`);

const validateTrace = createTraceValidator(rawSchema);
const results = [];
let failures = 0;
let profileNoteOn = 0;
let profileMapped = 0;
let knownPhysicalAmbiguities = 0;

for (const testCase of cases.cases) {
  const trace = readTrace(absolute(testCase.trace), validateTrace);
  if (testCase.scope === "out_of_scope") {
    results.push({ trace: testCase.trace, scope: testCase.scope, reason: testCase.reason, event_count: trace.events.length });
    continue;
  }
  const audit = auditTrace(trace, profile);
  const matches = audit.note_on_count === testCase.expected_note_on
    && audit.mapped_count === testCase.expected_mapped
    && audit.unmapped_note_on_count === 0;
  if (!matches) failures += 1;
  profileNoteOn += audit.note_on_count;
  profileMapped += audit.mapped_count;
  knownPhysicalAmbiguities += testCase.known_physical_ambiguities ?? 0;
  results.push({ trace: testCase.trace, scope: testCase.scope, matches_expectation: matches, ...audit,
    known_physical_ambiguities: testCase.known_physical_ambiguities ?? 0 });
}

const report = {
  schema_version: "1.0.0",
  report_type: "instrument_profile_audit",
  profile_id: profile.profile_id,
  cases_file: casesPath,
  totals: {
    trace_count: cases.cases.length,
    profile_trace_count: cases.cases.filter((item) => item.scope === "profile").length,
    out_of_scope_trace_count: cases.cases.filter((item) => item.scope === "out_of_scope").length,
    profile_note_on_count: profileNoteOn,
    mapped_count: profileMapped,
    mapping_mismatch_count: profileNoteOn - profileMapped,
    known_physical_ambiguities: knownPhysicalAmbiguities,
    failed_expectations: failures
  },
  results
};
const text = `${JSON.stringify(report, null, 2)}\n`;
if (outputPath) {
  fs.mkdirSync(path.dirname(absolute(outputPath)), { recursive: true });
  fs.writeFileSync(absolute(outputPath), text);
}
process.stdout.write(text);
if (failures) process.exit(1);
