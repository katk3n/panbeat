extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var wav_path := _argument(arguments, "--wav")
	var ogg_path := _argument(arguments, "--ogg")
	var output_path := _argument(arguments, "--output")
	var results: Array[Dictionary] = []
	for format: String in ["wav", "ogg"]:
		var path := wav_path if format == "wav" else ogg_path
		for trial: int in 3: results.append(await _trial(format, path, trial + 1))
	var all_ok := true
	for result: Dictionary in results: all_ok = all_ok and result.get("ok", false)
	var output := {"schema_version":"1.0.0", "story":"P206", "engine":Engine.get_version_info().get("string", ""), "audio_driver":AudioServer.get_driver_name(), "mix_rate_hz":AudioServer.get_mix_rate(), "trials":results, "all_ok":all_ok}
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null: push_error("cannot write P206 output"); quit(1); return
	file.store_string(JSON.stringify(output, "  ") + "\n")
	if all_ok:
		print("PANBEAT_P206_AUDIO_OK 6/6"); quit(0)
	else:
		push_error("one or more P206 audio lifecycle trials failed"); quit(1)

func _trial(format: String, path: String, trial: int) -> Dictionary:
	var load_start := Time.get_ticks_usec()
	var stream: AudioStream = AudioStreamWAV.load_from_file(path) if format == "wav" else AudioStreamOggVorbis.load_from_file(path)
	var load_us := Time.get_ticks_usec() - load_start
	if stream == null: return {"format":format, "trial":trial, "ok":false, "error":"decode_failed"}
	var player := AudioStreamPlayer.new(); root.add_child(player); player.stream = stream
	var start_us := Time.get_ticks_usec(); player.play(); await process_frame; await process_frame
	var start_latency_us := Time.get_ticks_usec() - start_us
	var started := player.playing
	player.stream_paused = true; await process_frame
	var pause_position := player.get_playback_position()
	player.stream_paused = false; await process_frame
	var resumed := player.playing and not player.stream_paused
	var seek_target := 180.0
	player.seek(seek_target); await process_frame
	var seek_position := player.get_playback_position()
	var seek_error := absf(seek_position - seek_target)
	player.stop(); player.stream = null
	if format == "wav":
		(stream as AudioStreamWAV).loop_begin = 0
		(stream as AudioStreamWAV).loop_end = roundi(stream.get_length() * (stream as AudioStreamWAV).mix_rate)
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	else: (stream as AudioStreamOggVorbis).loop = true
	player.stream = stream; player.play()
	player.seek(maxf(stream.get_length() - 0.02, 0.0))
	var loop_frames := 0
	var looped := false
	while loop_frames < 120:
		await process_frame; loop_frames += 1
		if player.playing and player.get_playback_position() < 1.0: looped = true; break
	player.stop(); player.stream = null
	if format == "wav": (stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	else: (stream as AudioStreamOggVorbis).loop = false
	player.stream = stream; player.play()
	player.seek(maxf(stream.get_length() - 0.05, 0.0))
	var frames := 0
	while player.playing and frames < 120: await process_frame; frames += 1
	var end_position := player.get_playback_position()
	var completed := not player.playing
	player.queue_free(); await process_frame
	return {"format":format, "trial":trial, "ok":started and resumed and seek_error < 0.1 and looped and completed and absf(stream.get_length() - 360.0) < 0.001, "duration_sec":stream.get_length(), "load_us":load_us, "start_latency_us":start_latency_us, "pause_position_sec":pause_position, "seek_target_sec":seek_target, "seek_position_sec":seek_position, "seek_error_sec":seek_error, "looped":looped, "loop_frames":loop_frames, "completed":completed, "end_position_sec":end_position, "format_duration_error_sec":absf(stream.get_length() - 360.0)}

func _argument(arguments: PackedStringArray, name: String) -> String:
	var index := arguments.find(name)
	return arguments[index + 1] if index >= 0 and index + 1 < arguments.size() else ""
