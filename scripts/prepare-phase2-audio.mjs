#!/usr/bin/env node
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, renameSync, rmSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { performance } from "node:perf_hooks";
import { inspectAudio } from "./audio-contract.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const runId = process.argv[2] ?? "phase2-p206-audio-latest";
if (!/^[A-Za-z0-9._-]+$/.test(runId)) throw new Error("invalid run ID");
const source = join(root, "game/content/phase1-fixed-song-v1/orbit-practice.wav");
const raw = join(root, "artifacts/raw", runId);
const staging = join(raw, ".staging");
mkdirSync(staging, { recursive: true });

const sha256 = (path) => createHash("sha256").update(readFileSync(path)).digest("hex");
const ffmpegVersion = execFileSync("ffmpeg", ["-version"], { encoding: "utf8" }).split("\n")[0];
const license = execFileSync("ffmpeg", ["-L"], { encoding: "utf8", maxBuffer: 1024 * 1024 }).split("\n").find((line) => line.includes("GNU General Public License"))?.trim() ?? "see ffmpeg -L";
const convert = (output, codecArgs) => {
  const start = performance.now();
  execFileSync("ffmpeg", ["-v", "error", "-y", "-stream_loop", "9", "-i", source, "-t", "360", "-ar", "48000", "-ac", "2", ...codecArgs, output], { stdio: "inherit" });
  return Math.round((performance.now() - start) * 1000) / 1000;
};
const decodeTrials = (path) => Array.from({ length: 3 }, () => {
  const start = performance.now();
  execFileSync("ffmpeg", ["-v", "error", "-i", path, "-f", "null", "-"], { stdio: "ignore" });
  return Math.round((performance.now() - start) * 1000) / 1000;
});

const stagedWav = join(staging, "comparison-6m.wav");
const stagedOgg = join(staging, "comparison-6m.ogg");
const secondOgg = join(staging, "comparison-6m-second.ogg");
const conversionMs = {
  wav: convert(stagedWav, ["-c:a", "pcm_s16le"]),
  ogg: convert(stagedOgg, ["-c:a", "vorbis", "-strict", "experimental", "-q:a", "5", "-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1", "-serial_offset", "1"]),
  oggRepeat: convert(secondOgg, ["-c:a", "vorbis", "-strict", "experimental", "-q:a", "5", "-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1", "-serial_offset", "1"]),
};
for (const path of [stagedWav, stagedOgg, secondOgg]) {
  const inspection = inspectAudio(path);
  if (!inspection.ok) throw new Error(`${path}: ${JSON.stringify(inspection.errors)}`);
}
const repeatedOggSha256 = sha256(secondOgg);
if (sha256(stagedOgg) !== repeatedOggSha256) throw new Error("Vorbis conversion is not deterministic");
const wav = join(raw, "comparison-6m.wav");
const ogg = join(raw, "comparison-6m.ogg");
renameSync(stagedWav, wav);
renameSync(stagedOgg, ogg);
rmSync(staging, { recursive: true });
const manifest = {
  schema_version: "1.0.0", run_id: runId, story: "P206", source: { path: "game/content/phase1-fixed-song-v1/orbit-practice.wav", sha256: sha256(source) },
  converter: { name: "FFmpeg", version: ffmpegVersion, license, install: "Homebrew: brew install ffmpeg", reproduce: `node scripts/prepare-phase2-audio.mjs ${runId}` },
  contract: { duration_sec: 360, sample_rate_hz: 48000, channels: 2, wav_codec: "pcm_s16le", ogg_codec: "vorbis", ogg_quality: 5, channel_decision: "FFmpeg 8.1 built-in deterministic Vorbis encoder supports stereo; both candidates use identical stereo conditions." },
  conversion_ms: conversionMs,
  assets: {
    wav: { path: `artifacts/raw/${runId}/comparison-6m.wav`, bytes: statSync(wav).size, sha256: sha256(wav), full_decode_ms: decodeTrials(wav) },
    ogg: { path: `artifacts/raw/${runId}/comparison-6m.ogg`, bytes: statSync(ogg).size, sha256: sha256(ogg), full_decode_ms: decodeTrials(ogg), deterministic_repeat_sha256: repeatedOggSha256 }
  }
};
writeFileSync(join(raw, "conversion-manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(JSON.stringify({ run_id: runId, wav: manifest.assets.wav, ogg: manifest.assets.ogg }, null, 2));
