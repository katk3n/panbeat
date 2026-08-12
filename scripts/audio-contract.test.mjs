import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { inspectAudio, validateProbe } from "./audio-contract.mjs";

const valid = { streams: [{ codec_type: "audio", codec_name: "vorbis", sample_rate: "48000", channels: 2 }], format: { duration: "360.0" } };

test("accepts canonical stereo 48 kHz Vorbis", () => assert.deepEqual(validateProbe("song.ogg", valid), []));
test("rejects unsupported codec", () => assert.equal(validateProbe("song.ogg", { streams: [{ ...valid.streams[0], codec_name: "mp3" }], format: valid.format })[0].code, "unsupported_audio_codec"));
test("rejects sample-rate and channel mismatch", () => assert.deepEqual(validateProbe("song.wav", { streams: [{ ...valid.streams[0], codec_name: "pcm_s16le", sample_rate: "44100", channels: 1 }], format: valid.format }).map((error) => error.code), ["sample_rate_mismatch", "channel_mismatch"]));
test("rejects excessive duration", () => assert.equal(validateProbe("song.ogg", { ...valid, format: { duration: "3600.1" } })[0].code, "audio_duration_limit"));
test("rejects unsupported extension", () => assert.equal(validateProbe("song.mp3", valid)[0].code, "unsupported_audio_extension"));
test("reports corrupt audio", () => {
  const directory = mkdtempSync(join(tmpdir(), "panbeat-audio-contract-"));
  const path = join(directory, "broken.ogg");
  writeFileSync(path, "not audio");
  try { assert.equal(inspectAudio(path).errors[0].code, "corrupt_or_unreadable_audio"); }
  finally { rmSync(directory, { recursive: true }); }
});
