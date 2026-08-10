#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function usage() {
  process.stdout.write("Usage: scripts/validate-fixtures [--cases PATH]\n\nValidate the Phase 0 schema contract suite.\n\nOptions:\n  --cases PATH  Case manifest relative to the repository root\n                (default: shared/fixtures/schema-cases.json)\n  -h, --help    Show this help\n");
}

let casesPath = "shared/fixtures/schema-cases.json";
for (let index = 2; index < process.argv.length; index += 1) {
  const argument = process.argv[index];
  if (argument === "-h" || argument === "--help") {
    usage();
    process.exit(0);
  }
  if (argument === "--cases" && process.argv[index + 1]) {
    casesPath = process.argv[index + 1];
    index += 1;
    continue;
  }
  process.stderr.write(`validate-fixtures: invalid argument: ${argument}\n`);
  process.exit(64);
}

const absolutePath = (candidate) => path.isAbsolute(candidate)
  ? candidate
  : path.join(repositoryRoot, candidate);
const readJson = (candidate) => JSON.parse(fs.readFileSync(absolutePath(candidate), "utf8"));

const manifest = readJson(casesPath);
if (manifest.schema_version !== "1.0.0" || !Array.isArray(manifest.cases)) {
  throw new Error("case manifest must have schema_version 1.0.0 and a cases array");
}

const ajv = new Ajv2020({ allErrors: true, strict: true });
const validators = new Map();
let unexpected = 0;

for (const testCase of manifest.cases) {
  let validate = validators.get(testCase.schema);
  if (!validate) {
    const schema = readJson(testCase.schema);
    if (!ajv.validateSchema(schema)) {
      throw new Error(`invalid schema ${testCase.schema}: ${ajv.errorsText(ajv.errors)}`);
    }
    validate = ajv.compile(schema);
    validators.set(testCase.schema, validate);
  }

  const fixtureText = fs.readFileSync(absolutePath(testCase.fixture), "utf8");
  const instances = testCase.format === "jsonl"
    ? fixtureText.split(/\r?\n/u).filter((line) => line.length > 0).map((line) => JSON.parse(line))
    : [JSON.parse(fixtureText)];
  const valid = instances.every((instance) => validate(instance));
  const matches = valid === testCase.expected_valid;
  process.stdout.write(`${matches ? "PASS" : "FAIL"} ${testCase.fixture} expected=${testCase.expected_valid ? "valid" : "invalid"}\n`);
  if (!matches) {
    unexpected += 1;
    process.stderr.write(`${ajv.errorsText(validate.errors, { separator: "\n" })}\n`);
  }
}

if (unexpected > 0) {
  process.stderr.write(`validate-fixtures: ${unexpected} unexpected result(s)\n`);
  process.exit(1);
}

process.stdout.write(`Validated ${manifest.cases.length} schema cases.\n`);
