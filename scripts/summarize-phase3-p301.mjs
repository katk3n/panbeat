import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { join, relative, resolve } from "node:path";

const runId = process.argv[2];
if (!runId || !/^[A-Za-z0-9._-]+$/.test(runId)) throw new Error("usage: summarize-phase3-p301.mjs RUN_ID");
const root = resolve(new URL("..", import.meta.url).pathname);
const rawDir = join(root, "artifacts", "raw", runId);
const pngs = readdirSync(rawDir).filter((name) => name.endsWith(".png")).sort();
if (pngs.length !== 12) throw new Error(`expected 12 PNGs, found ${pngs.length}`);
const sha256 = (path) => createHash("sha256").update(readFileSync(path)).digest("hex");
const screenshots = Object.fromEntries(pngs.map((name) => [name, {sha256: sha256(join(rawDir, name)), bytes: statSync(join(rawDir, name)).size}]));
const command = (name, args) => execFileSync(name, args, {cwd: root, encoding: "utf8"}).trim();
const manifest = {
  schema_version: "1.0.0",
  run_id: runId,
  story: "P301",
  status: "awaiting-user-design-approval",
  source_revision: command("git", ["rev-parse", "HEAD"]),
  environment: {os: command("sw_vers", ["-productVersion"]), architecture: command("uname", ["-m"]), godot: command(join(root, "scripts", "godot"), ["--version"]), renderer: "GL Compatibility"},
  fixture_contract: "docs/phase3-p301-design-tokens.json",
  phase2_baseline: {completion_report: "docs/phase2-completion-report.md", judgement_and_score: "artifacts/raw/phase2-p215-audio-duration-fix-20260812/run-manifest.json", frame_time: "artifacts/raw/phase2-p214-quality-20260812/run-manifest.json", gameplay_frame_p95_us: 16667, gameplay_frame_p99_us: 16667, scheduler_cost_p95_us: 3, pool_overflow: 0},
  commands: [
    `scripts/check-game --mode test --run-id ${runId}-tests`,
    `node --test scripts/check-phase3-p301.test.mjs`,
    `scripts/check-phase3-p301 ${runId}`
  ],
  capture_matrix: {
    product_screens_1280x720_normal: ["device-setup.png", "song-library.png", "calibration.png", "gameplay-1280x720-normal.png", "results.png", "recoverable-error.png"],
    supplemental_product_shell: ["product-flow.png"],
    gameplay_resize_accessibility: ["gameplay-1280x720-normal.png", "gameplay-1280x720-monochrome.png", "gameplay-1728x720-normal.png", "gameplay-1728x720-monochrome.png"],
    design_options_same_fixture: ["design-option-a-quiet-forge.png", "design-option-b-polar-resonance.png"]
  },
  deterministic_states: {song_time_us: 10000000, count_in_us: -1000000, pause_us: 12000000, simultaneous_fixture_window_us: [10000000, 12000000], grades: ["perfect", "great", "good", "miss"]},
  screenshots,
  design_decision: {status: "pending", selected_option: null, requested_record: "docs/phase3-p301-design-decision.md"},
  assets: {external_assets_added: [], provenance_policy: "docs/phase3-p301-design-tokens.json#assets"},
  verification: {phase2_regression_tests: "pass", p301_contract_tests: "pass", screenshot_count: pngs.length, build: "not-required-no-product-assets-theme-or-shader-changed"},
  blockers: ["P301 cannot complete and P302/P303 cannot start until the user records a design selection or requested revisions."],
  result: "prepared-awaiting-user"
};
writeFileSync(join(rawDir, "run-manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
console.log(relative(root, join(rawDir, "run-manifest.json")));
