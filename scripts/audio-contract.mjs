#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { extname } from "node:path";

export const AUDIO_CONTRACT = Object.freeze({ sampleRate: 48000, channels: 2, maxDurationSec: 3600, codecs: ["pcm_s16le", "vorbis"], extensions: [".wav", ".ogg"] });

export function validateProbe(path, probe, contract = AUDIO_CONTRACT) {
  const errors = [];
  const stream = probe?.streams?.find((candidate) => candidate.codec_type === "audio");
  if (!contract.extensions.includes(extname(path).toLowerCase())) errors.push({ code: "unsupported_audio_extension", message: `unsupported audio extension: ${extname(path)}` });
  if (!stream) return [...errors, { code: "corrupt_or_missing_audio", message: "no audio stream found" }];
  if (!contract.codecs.includes(stream.codec_name)) errors.push({ code: "unsupported_audio_codec", message: `unsupported codec: ${stream.codec_name}` });
  if (Number(stream.sample_rate) !== contract.sampleRate) errors.push({ code: "sample_rate_mismatch", message: `expected ${contract.sampleRate} Hz, got ${stream.sample_rate}` });
  if (Number(stream.channels) !== contract.channels) errors.push({ code: "channel_mismatch", message: `expected ${contract.channels} channels, got ${stream.channels}` });
  const duration = Number(probe?.format?.duration ?? stream.duration);
  if (!Number.isFinite(duration) || duration <= 0) errors.push({ code: "invalid_audio_duration", message: "duration must be positive" });
  else if (duration > contract.maxDurationSec) errors.push({ code: "audio_duration_limit", message: `duration exceeds ${contract.maxDurationSec} seconds` });
  return errors;
}

export function inspectAudio(path, ffprobe = "ffprobe") {
  try {
    const output = execFileSync(ffprobe, ["-v", "error", "-show_streams", "-show_format", "-of", "json", path], { encoding: "utf8", maxBuffer: 4 * 1024 * 1024 });
    const probe = JSON.parse(output);
    const errors = validateProbe(path, probe);
    return errors.length ? { ok: false, errors, probe } : { ok: true, probe };
  } catch (error) {
    return { ok: false, errors: [{ code: "corrupt_or_unreadable_audio", message: `ffprobe failed: ${error.status ?? "unknown"}` }] };
  }
}

if (process.argv[1] && process.argv[1].endsWith("audio-contract.mjs")) {
  const result = inspectAudio(process.argv[2] ?? "");
  console.log(JSON.stringify(result, null, 2));
  if (!result.ok) process.exitCode = 1;
}
