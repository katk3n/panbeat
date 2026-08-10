extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var duration_seconds: float = float(_read(arguments, "--duration-seconds"))
	var raw_path: String = _read(arguments, "--output")
	var manifest_path: String = _read(arguments, "--manifest")
	var raw := FileAccess.open(raw_path, FileAccess.WRITE)
	if raw == null:
		push_error("cannot open raw output")
		quit(1)
		return
	var origin_us: int = Time.get_ticks_usec()
	var previous_mix: float = AudioServer.get_time_since_last_mix()
	var previous_corrected_us: int = 0
	var corrections: int = 0
	var backwards: int = 0
	var max_backward_us: int = 0
	var sequence: int = 0
	while Time.get_ticks_usec() - origin_us <= roundi(duration_seconds * 1_000_000.0):
		var elapsed_us: int = Time.get_ticks_usec() - origin_us
		var mix: float = AudioServer.get_time_since_last_mix()
		var mix_delta_us: int = roundi((mix - previous_mix) * 1_000_000.0)
		if mix_delta_us < 0:
			backwards += 1
			corrections += 1
			max_backward_us = maxi(max_backward_us, -mix_delta_us)
		var raw_clock_us: int = roundi(mix * 1_000_000.0)
		var corrected_us: int = maxi(previous_corrected_us, elapsed_us)
		previous_corrected_us = corrected_us
		raw.store_line(JSON.stringify({"schema_version":"1.0.0","sequence":sequence,"monotonic_elapsed_us":elapsed_us,"time_since_last_mix_us":raw_clock_us,"mix_delta_us":mix_delta_us,"corrected_song_time_us":corrected_us}))
		sequence += 1
		previous_mix = mix
		await create_timer(0.1).timeout
	raw.close()
	var manifest := FileAccess.open(manifest_path, FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"schema_version":"1.0.0","engine":"godot","engine_version":Engine.get_version_info()["string"],"duration_seconds":duration_seconds,"audio_driver":AudioServer.get_driver_name(),"mix_rate_hz":AudioServer.get_mix_rate(),"output_latency_seconds":AudioServer.get_output_latency(),"backward_count":backwards,"correction_count":corrections,"max_backward_us":max_backward_us,"clock_domain":"audio_server_time_since_last_mix_with_monotonic_reference","measurement_scope":"headless diagnostic; Dummy driver is not real output latency evidence"}, "  ") + "\n")
	manifest.close()
	quit(0)

func _read(arguments: PackedStringArray, option: String) -> String:
	var index: int = arguments.find(option)
	if index < 0 or index + 1 >= arguments.size():
		push_error("missing option: " + option)
		return ""
	return arguments[index + 1]
