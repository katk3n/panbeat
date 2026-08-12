class_name FfmpegAudioConverter
extends RefCounted

const MAX_DURATION_SEC := 3600.0

func convert(source: String, destination: String) -> Dictionary:
	var probe := inspect(source, false)
	if not probe.get("ok", false): return probe
	var output: Array[String] = []
	var args := PackedStringArray(["-v", "error", "-y", "-i", source, "-map_metadata", "-1", "-ar", "48000", "-ac", "2", "-c:a", "vorbis", "-strict", "experimental", "-q:a", "5", "-fflags", "+bitexact", "-flags:a", "+bitexact", "-serial_offset", "1", destination])
	var exit_code := OS.execute("ffmpeg", args, output, true)
	if exit_code != 0: return _failed("audio_conversion_failed", source, "FFmpeg conversion failed: %s" % "\n".join(output), "Install FFmpeg and use a supported WAV or OGG file.")
	var generated := inspect(destination, true)
	if not generated.get("ok", false): return generated
	return {"ok":true, "probe":generated["probe"], "duration_sec":generated["duration_sec"]}

func inspect(path: String, require_canonical: bool = false) -> Dictionary:
	var output: Array[String] = []
	var exit_code := OS.execute("ffprobe", PackedStringArray(["-v", "error", "-show_streams", "-show_format", "-of", "json", path]), output, true)
	if exit_code != 0: return _failed("corrupt_or_unreadable_audio", path, "FFprobe could not read the audio file.", "Use a valid WAV or OGG file.")
	var parsed: Variant = JSON.parse_string("\n".join(output))
	if parsed is not Dictionary: return _failed("corrupt_or_unreadable_audio", path, "FFprobe returned invalid metadata.", "Use a valid WAV or OGG file.")
	var probe := parsed as Dictionary
	var streams: Array = probe.get("streams", [])
	var audio: Dictionary = {}
	for value: Variant in streams:
		if value is Dictionary and value.get("codec_type") == "audio": audio = value; break
	if audio.is_empty(): return _failed("corrupt_or_missing_audio", path, "No audio stream was found.", "Choose a WAV or OGG audio file.")
	var codec := str(audio.get("codec_name", ""))
	if codec not in ["pcm_s16le", "vorbis"]: return _failed("unsupported_audio_codec", path, "Unsupported audio codec: %s" % codec, "Use PCM 16-bit WAV or Ogg Vorbis.")
	if require_canonical and int(audio.get("sample_rate", 0)) != 48000: return _failed("sample_rate_mismatch", path, "Canonical audio must use a 48000 Hz sample rate.", "Check the deterministic conversion pipeline.")
	if require_canonical and int(audio.get("channels", 0)) != 2: return _failed("channel_mismatch", path, "Canonical audio must contain two channels.", "Check the deterministic conversion pipeline.")
	var duration := float(probe.get("format", {}).get("duration", audio.get("duration", 0.0)))
	if duration <= 0.0 or duration > MAX_DURATION_SEC: return _failed("audio_duration_limit", path, "Audio duration must be greater than 0 and at most 3600 seconds.", "Choose a shorter valid audio file.")
	return {"ok":true, "probe":probe, "duration_sec":duration}

func _failed(code: String, file: String, message: String, remediation: String) -> Dictionary:
	return {"ok":false, "diagnostics":[{"severity":"error", "code":code, "file":file, "part":"", "measure":"", "element":"audio", "message":message, "remediation":remediation}]}
