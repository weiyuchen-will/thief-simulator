extends SceneTree
var score_node: Node
var started: int
func _initialize() -> void:
	started = Time.get_ticks_msec()
	score_node = load("res://scripts/soundtrack.gd").new()
	root.add_child.call_deferred(score_node)
	_test.call_deferred()
func _test() -> void:
	await process_frame
	var generation_ms: int = Time.get_ticks_msec() - started
	for loop_name: String in ["calm", "tension", "combat", "escape"]:
		var wav: AudioStreamWAV = score_node._loops[loop_name]
		assert(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD)
		var data: PackedByteArray = wav.data
		var peak: int = 0
		var energy: float = 0.0
		for index: int in range(0, data.size(), 2):
			var sample: int = data.decode_s16(index)
			peak = maxi(peak, absi(sample))
			energy += float(sample) * float(sample)
		var rms: float = sqrt(energy / float(data.size() / 2)) / 32768.0
		assert(peak > 5000 and peak < 32767)
		assert(rms > 0.04)
		print("LOOP ", loop_name, " length=", snappedf(wav.get_length(), 0.01), " peak=", peak, " rms=", snappedf(rms, 0.001))
	for stage: String in ["intro", "approach", "loot", "combat", "escape", "won", "lost", "menu"]:
		score_node.set_stage(stage)
		await process_frame
	assert(score_node._current_loop == "calm")
	await create_timer(1.5).timeout
	assert(is_equal_approx(score_node._players[score_node._active].volume_db, -14.0))
	assert(not score_node._players[1 - score_node._active].playing)
	score_node.set_paused(true)
	assert(score_node._players[score_node._active].stream_paused)
	score_node.set_paused(false)
	assert(not score_node._players[score_node._active].stream_paused)
	print("SOUNDTRACK_SMOKE_OK generation_ms=", generation_ms)
	score_node.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	quit()
