class_name RuntimeMetricsRecorder
extends RefCounted

const CAPACITY: int = 200_000

var _output_path: String
var _speed: float
var _context: Dictionary
var _play_origin_ticks_us: int = -1
var _play_origin_song_us: int = 0
var _sample_count: int = 0
var _elapsed := PackedInt64Array()
var _song := PackedInt64Array()
var _expected := PackedInt64Array()
var _frame := PackedInt64Array()
var _active := PackedInt32Array()
var _overflow := PackedInt32Array()
var _activated := PackedInt32Array()
var _memory := PackedInt64Array()
var _events: Array[Dictionary] = []

func _init(output_path: String, speed: float, context: Dictionary) -> void:
	_output_path = output_path
	_speed = speed
	_context = context.duplicate(true)
	_elapsed.resize(CAPACITY); _song.resize(CAPACITY); _expected.resize(CAPACITY); _frame.resize(CAPACITY)
	_active.resize(CAPACITY); _overflow.resize(CAPACITY); _activated.resize(CAPACITY); _memory.resize(CAPACITY)

func observe(song_time_us: int, frame_delta_seconds: float, scheduler: RefCounted) -> void:
	if _sample_count >= CAPACITY:
		return
	var ticks_us: int = Time.get_ticks_usec()
	if _play_origin_ticks_us < 0:
		_play_origin_ticks_us = ticks_us
		_play_origin_song_us = song_time_us
	_elapsed[_sample_count] = ticks_us - _play_origin_ticks_us
	_song[_sample_count] = song_time_us
	_expected[_sample_count] = _play_origin_song_us + roundi(_elapsed[_sample_count] * _speed)
	_frame[_sample_count] = roundi(frame_delta_seconds * 1_000_000.0)
	_active[_sample_count] = scheduler.active_count()
	_overflow[_sample_count] = scheduler.overflow_count
	_activated[_sample_count] = scheduler.activated_count
	_memory[_sample_count] = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	_sample_count += 1

func event(kind: String, values: Dictionary = {}) -> void:
	_events.append({"kind":kind,"monotonic_elapsed_us":Time.get_ticks_usec() - _play_origin_ticks_us}.merged(values))

func finish(summary: Dictionary) -> void:
	var file := FileAccess.open(_output_path, FileAccess.WRITE)
	assert(file != null)
	var sequence: int = 0
	file.store_line(JSON.stringify({"schema_version":"1.0.0","sequence":sequence,"record_type":"session","engine_version":Engine.get_version_info()["string"],"build_type":"release-equivalent","renderer":RenderingServer.get_current_rendering_method(),"resolution":[1280,720],"configured_max_fps":Engine.max_fps,"display_refresh_rate_hz":DisplayServer.screen_get_refresh_rate(),"audio_driver":AudioServer.get_driver_name(),"sample_rate_hz":AudioServer.get_mix_rate(),"output_latency_seconds":AudioServer.get_output_latency(),"replay_speed":_speed,"context":_context,"preallocated_sample_capacity":CAPACITY})); sequence += 1
	for index: int in _sample_count:
		file.store_line(JSON.stringify({"schema_version":"1.0.0","sequence":sequence,"record_type":"frame","monotonic_elapsed_us":_elapsed[index],"song_time_us":_song[index],"expected_song_time_us":_expected[index],"drift_us":_song[index]-_expected[index],"frame_time_us":_frame[index],"active_notes":_active[index],"pool_overflow_count":_overflow[index],"activated_notes":_activated[index],"static_memory_bytes":_memory[index]})); sequence += 1
	for event_record: Dictionary in _events:
		file.store_line(JSON.stringify({"schema_version":"1.0.0","sequence":sequence,"record_type":"event"}.merged(event_record))); sequence += 1
	file.store_line(JSON.stringify({"schema_version":"1.0.0","sequence":sequence,"record_type":"complete","summary":summary,"sample_count":_sample_count}))
	file.close()
