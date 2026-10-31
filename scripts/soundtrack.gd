extends Node
## Entire score is synthesized once; playback uses inexpensive, seamless WAV loops.
## Four-bar D minor progression: Dm / Bb / F / C.

const SAMPLE_RATE: int = 22050
const MUSIC_DB: float = -14.0
const SILENT_DB: float = -62.0

var _loops: Dictionary = {}
var _one_shots: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _cue: AudioStreamPlayer
var _active: int = 0
var _current_loop: String = ""
var _stage: String = "menu"
var _paused: bool = false
var _initialized: bool = false
var _fade: Tween
var _sample_cache: Dictionary = {}

func _exit_tree() -> void:
	for player in _players:
		player.stop()
		player.stream = null
	if is_instance_valid(_cue):
		_cue.stop()
		_cue.stream = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index: int in range(2):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "ScoreDeck%d" % index
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)
	_cue = AudioStreamPlayer.new()
	_cue.name = "ScoreStingers"
	_cue.volume_db = -15.5
	_cue.max_polyphony = 2
	add_child(_cue)
	_sample_cache["kick"] = _drum("kick")
	_sample_cache["snare"] = _drum("snare")
	_sample_cache["hat"] = _drum("hat")
	_sample_cache["open_hat"] = _drum("open_hat")
	_loops["calm"] = _compose_loop(108.0, 0)
	_loops["tension"] = _compose_loop(116.0, 1)
	_loops["combat"] = _compose_loop(128.0, 2)
	_loops["escape"] = _compose_loop(138.0, 3)
	_one_shots["won"] = _compose_stinger(true)
	_one_shots["lost"] = _compose_stinger(false)
	_one_shots["siren"] = _compose_siren()
	_sample_cache.clear()
	_initialized = true
	var requested_stage: String = _stage
	_stage = ""
	set_stage(requested_stage)


func set_stage(stage: String) -> void:
	if stage == _stage and _initialized:
		return
	_stage = stage
	if not _initialized:
		return
	var loop_name: String = "calm"
	match stage:
		"menu", "intro", "won":
			loop_name = "calm"
		"approach", "loot":
			loop_name = "tension"
		"combat":
			loop_name = "combat"
		"escape":
			loop_name = "escape"
		"lost":
			loop_name = ""
	_transition(loop_name)
	if stage in ["won", "lost", "combat"]:
		var cue_name: String = "siren" if stage == "combat" else stage
		_cue.stream = _one_shots[cue_name] as AudioStreamWAV
		_cue.play()
		_cue.stream_paused = _paused


func set_paused(value: bool) -> void:
	_paused = value
	for player: AudioStreamPlayer in _players:
		player.stream_paused = value
	if is_instance_valid(_cue):
		_cue.stream_paused = value


func _transition(loop_name: String) -> void:
	if loop_name == _current_loop:
		return
	_current_loop = loop_name
	if is_instance_valid(_fade):
		_fade.kill()
	_fade = create_tween()
	_fade.set_parallel(true)
	_fade.set_trans(Tween.TRANS_SINE)
	_fade.set_ease(Tween.EASE_IN_OUT)
	if loop_name.is_empty():
		for player: AudioStreamPlayer in _players:
			_fade.tween_property(player, "volume_linear", 0.0, 0.85)
		_fade.chain().tween_callback(_stop_music)
		return
	var previous: int = _active
	_active = 1 - _active
	var next_player: AudioStreamPlayer = _players[_active]
	next_player.stop()
	next_player.stream = _loops[loop_name] as AudioStreamWAV
	next_player.volume_db = SILENT_DB
	next_player.play()
	next_player.stream_paused = _paused
	_fade.tween_property(next_player, "volume_linear", db_to_linear(MUSIC_DB), 1.35)
	_fade.tween_property(_players[previous], "volume_linear", 0.0, 1.35)
	_fade.chain().tween_callback(_stop_deck.bind(previous))


func _stop_deck(index: int) -> void:
	_players[index].stop()


func _stop_music() -> void:
	for player: AudioStreamPlayer in _players:
		player.stop()


func _compose_loop(bpm: float, intensity: int) -> AudioStreamWAV:
	var beat: float = 60.0 / bpm
	var bar_duration: float = beat * 4.0
	var duration: float = bar_duration * 4.0
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(duration * float(SAMPLE_RATE)))
	var roots: Array[int] = [38, 34, 41, 36]
	var chords: Array[Array] = [[50, 53, 57], [46, 50, 53], [53, 57, 60], [48, 52, 55]]
	var kicks: Array[float] = [0.0, 2.0]
	if intensity == 1:
		kicks = [0.0, 1.5, 2.5]
	elif intensity == 2:
		kicks = [0.0, 0.75, 1.5, 2.0, 2.75, 3.5]
	elif intensity == 3:
		kicks = [0.0, 1.0, 2.0, 3.0, 3.75]
	for bar: int in range(4):
		var start: float = float(bar) * bar_duration
		var chord: Array = chords[bar]
		for note_value: int in chord:
			var pad: PackedFloat32Array = _tone(note_value, bar_duration, "pad")
			_mix(samples, pad, start, 0.105 if intensity < 2 else 0.075)
		for kick_beat: float in kicks:
			_mix(samples, _sample_cache["kick"] as PackedFloat32Array, start + kick_beat * beat, 0.57 if intensity == 0 else 0.77)
		var snare_beats: Array[float] = [1.0, 3.0]
		if intensity == 0:
			snare_beats = [2.0]
		for snare_beat: float in snare_beats:
			_mix(samples, _sample_cache["snare"] as PackedFloat32Array, start + snare_beat * beat, 0.26 if intensity == 0 else 0.45)
		var hat_steps: int = 8 if intensity < 2 else 16
		for step: int in range(hat_steps):
			var hat_volume: float = 0.082 if step % 2 == 0 else 0.052
			if intensity >= 2:
				hat_volume *= 1.2
			var hat_kind: String = "open_hat" if intensity == 3 and step % 4 == 2 else "hat"
			_mix(samples, _sample_cache[hat_kind] as PackedFloat32Array, start + float(step) * bar_duration / float(hat_steps), hat_volume)
		var bass_steps: int = 4 if intensity == 0 else 8
		var bass_pattern: Array[int] = [0, 0, 12, 7, 0, 0, 12, 7]
		for step: int in range(bass_steps):
			var bass_note: int = roots[bar] + bass_pattern[step]
			var bass_duration: float = beat * (0.75 if intensity == 0 else 0.38)
			var bass: PackedFloat32Array = _cached_tone(bass_note, bass_duration, "bass")
			_mix(samples, bass, start + float(step) * bar_duration / float(bass_steps), 0.34 if intensity == 0 else 0.43)
		var arp_steps: int = 4 if intensity == 0 else 8
		if intensity == 3:
			arp_steps = 16
		var arp_order: Array[int] = [0, 1, 2, 1, 0, 2, 1, 2]
		for step: int in range(arp_steps):
			var chord_index: int = arp_order[step % 8]
			var arp_note: int = int(chord[chord_index]) + 24
			if intensity == 2 and step % 4 == 3:
				arp_note -= 12
			var pluck: PackedFloat32Array = _cached_tone(arp_note, beat * 0.7, "pluck")
			var arp_start: float = start + (float(step) + 0.5) * bar_duration / float(arp_steps)
			var arp_gain: float = 0.07 if intensity == 0 else 0.1
			_mix(samples, pluck, arp_start, arp_gain)
			_mix(samples, pluck, arp_start + beat * 0.75, arp_gain * 0.25)
		if intensity >= 2 and bar == 3:
			for fill: int in range(4):
				_mix(samples, _sample_cache["snare"] as PackedFloat32Array, start + (3.0 + float(fill) * 0.25) * beat, 0.12 + float(fill) * 0.035)
	return _encode(samples, true)


func _cached_tone(note: int, duration: float, kind: String) -> PackedFloat32Array:
	var cache_key: String = "%s_%d_%d" % [kind, note, int(duration * 10000.0)]
	if not _sample_cache.has(cache_key):
		_sample_cache[cache_key] = _tone(note, duration, kind)
	return _sample_cache[cache_key] as PackedFloat32Array


func _tone(note: int, duration: float, kind: String) -> PackedFloat32Array:
	var count: int = int(duration * float(SAMPLE_RATE))
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(count)
	var frequency: float = 440.0 * pow(2.0, float(note - 69) / 12.0)
	var angle_step: float = TAU * frequency / float(SAMPLE_RATE)
	for index: int in range(count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var angle: float = float(index) * angle_step
		var envelope: float = minf(time / 0.008, 1.0) * minf((duration - time) / 0.028, 1.0)
		var value: float = 0.0
		if kind == "pad":
			envelope = minf(time / 0.32, 1.0) * minf((duration - time) / 0.32, 1.0)
			value = (sin(angle) * 0.5 + sin(angle * 1.003) * 0.27 + sin(angle * 2.0) * 0.08) * envelope
		elif kind == "bass":
			envelope *= exp(-time * 4.0)
			value = (sin(angle) * 0.68 + sin(angle * 2.0) * 0.16 + sin(angle * 3.0) * 0.1) * envelope
		else:
			envelope *= exp(-time * 10.0)
			value = (sin(angle) * 0.72 + sin(angle * 2.001) * 0.18 + sin(angle * 4.0) * 0.06) * envelope
		result[index] = value
	return result


func _drum(kind: String) -> PackedFloat32Array:
	var duration: float = 0.26
	if kind == "hat":
		duration = 0.065
	elif kind == "open_hat":
		duration = 0.18
	var result: PackedFloat32Array = PackedFloat32Array()
	var count: int = int(duration * float(SAMPLE_RATE))
	result.resize(count)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 7019 + kind.length() * 91
	var previous_noise: float = 0.0
	var kick_phase: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var noise: float = random.randf_range(-1.0, 1.0)
		var high_noise: float = (noise - previous_noise) * 0.5
		previous_noise = noise
		var value: float = 0.0
		if kind == "kick":
			kick_phase += TAU * (49.0 + 105.0 * exp(-time * 42.0)) / float(SAMPLE_RATE)
			value = sin(kick_phase) * exp(-time * 17.0) * 0.94 + noise * exp(-time * 160.0) * 0.12
		elif kind == "snare":
			value = noise * exp(-time * 30.0) * 0.58 + sin(TAU * 176.0 * time) * exp(-time * 42.0) * 0.3
		else:
			value = high_noise * exp(-time * (72.0 if kind == "hat" else 24.0))
		var fade: float = minf((duration - time) / 0.006, 1.0)
		result[index] = value * fade
	return result


func _mix(target: PackedFloat32Array, source: PackedFloat32Array, start_seconds: float, gain: float) -> void:
	var start: int = int(start_seconds * float(SAMPLE_RATE))
	if start >= target.size():
		return
	var count: int = mini(source.size(), target.size() - start)
	for index: int in range(count):
		target[start + index] += source[index] * gain


func _encode(samples: PackedFloat32Array, looping: bool) -> AudioStreamWAV:
	var peak: float = 0.001
	for value: float in samples:
		peak = maxf(peak, absf(value))
	var gain: float = 0.86 / maxf(peak, 0.6)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index: int in range(samples.size()):
		bytes.encode_s16(index * 2, int(clampf(samples[index] * gain, -0.95, 0.95) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.mix_rate = SAMPLE_RATE
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.data = bytes
	if looping:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


func _compose_stinger(success: bool) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(SAMPLE_RATE * 3)
	var notes: Array[int] = [62, 65, 69, 74]
	if not success:
		notes = [62, 61, 58, 50]
	for index: int in range(notes.size()):
		_mix(samples, _tone(notes[index], 0.9, "pluck"), float(index) * 0.17, 0.43)
		_mix(samples, _tone(notes[index], 0.9, "pluck"), float(index) * 0.17 + 0.3, 0.15)
	var chord: Array[int] = [50, 53, 57, 62]
	if not success:
		chord = [38, 41, 44]
	for note: int in chord:
		_mix(samples, _tone(note, 2.2, "pad"), 0.4, 0.24)
	_mix(samples, _sample_cache["kick"] as PackedFloat32Array, 0.0, 0.47)
	return _encode(samples, false)


func _compose_siren() -> AudioStreamWAV:
	var duration: float = 1.55
	var samples: PackedFloat32Array = PackedFloat32Array()
	var count: int = int(duration * float(SAMPLE_RATE))
	samples.resize(count)
	var phase: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var pitch: float = 640.0 + sin(TAU * 2.2 * time) * 190.0
		phase += TAU * pitch / float(SAMPLE_RATE)
		var envelope: float = minf(time / 0.09, 1.0) * minf((duration - time) / 0.45, 1.0)
		samples[index] = (sin(phase) * 0.65 + sin(phase * 3.0) * 0.15) * envelope * 0.55
	return _encode(samples, false)
