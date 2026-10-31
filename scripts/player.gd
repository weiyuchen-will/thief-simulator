extends CharacterBody3D
## First person controller, procedural view models and deliberately arcade combat.

signal shot_fired(origin: Vector3, direction: Vector3, damage: float, reach: float)
signal interacted()
signal state_changed()

var enabled: bool = false
var health: float = 100.0
var armor: float = 100.0
var aiming: bool = false
var ammo: int = 30
var reserve: int = 180
var weapon_index: int = 0
var reloading: bool = false
var skin_index: int = 0
var camera: Camera3D
var weapon_names: Array[String] = ["CAR-9 突击步枪", "P12 战术手枪", "M870 霰弹枪", "VECTOR 冲锋枪", "SVD 狙击步枪", "M249 轻机枪", "AS VAL 微声步枪"]

const CAPACITIES: Array[int] = [30, 12, 6, 35, 8, 100, 20]
const STARTING_RESERVE: Array[int] = [180, 72, 36, 210, 40, 300, 120]
const FIRE_INTERVALS: Array[float] = [0.105, 0.26, 0.8, 0.067, 1.1, 0.09, 0.10]
const RELOAD_TIMES: Array[float] = [1.7, 1.2, 2.15, 1.45, 2.5, 3.4, 1.8]
const DAMAGE: Array[float] = [28.0, 43.0, 13.0, 22.0, 145.0, 25.0, 36.0]
const REACH: Array[float] = [70.0, 55.0, 35.0, 58.0, 140.0, 90.0, 80.0]
const AIM_FOV: Array[float] = [51.0, 58.0, 55.0, 54.0, 24.0, 49.0, 40.0]
const SIGHT_HEIGHT: Array[float] = [0.146, 0.078, 0.112, 0.142, 0.174, 0.163, 0.165]
const WALK_SPEED: float = 5.0
const RUN_SPEED: float = 8.0
const LOOK_SENSITIVITY: float = 0.00225

var _stored_ammo: Array[int] = CAPACITIES.duplicate()
var _stored_reserve: Array[int] = STARTING_RESERVE.duplicate()
var _pitch: float = 0.0
var _virtual_move: Vector2 = Vector2.ZERO
var _virtual_fire: bool = false
var _virtual_aim: bool = false
var _physical_fire: bool = false
var _physical_aim: bool = false
var _virtual_sprint: bool = false
var _virtual_jump: bool = false
var _aim_toggled: bool = false
var _fire_cooldown: float = 0.0
var _reload_remaining: float = 0.0
var _punch_remaining: float = 0.0
var _equip_offset: float = 0.0
var _flash_remaining: float = 0.0
var _bob: float = 0.0
var _sway: Vector2 = Vector2.ZERO
var _weapon_rig: Node3D
var _models: Array[Node3D] = []
var _flashes: Array[Node3D] = []
var _muzzle_light: OmniLight3D
var _shot_audio: AudioStreamPlayer
var _reload_audio: AudioStreamPlayer
var _sounds: Array[AudioStreamWAV] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _materials: Dictionary = {}
var _base_skin_materials: Dictionary = {}
var _skin_decorations: Array[Node3D] = []
var _applied_skin_index: int = -1

const SKIN_NAMES: Array[String] = ["原型·夜行", "极光·青锋", "赤焰·熔核", "紫电·脉冲", "黑金·特务91"]
const SKIN_COLORS: Array[Dictionary] = [
	{},
	{"black":"102528", "graphite":"31534f", "tan":"418b7c", "wood":"255d56", "olive":"34776b", "steel":"a5d4c0", "sleeve":"193e39", "glove":"122725", "accent":"8bffe0", "secondary":"3fbdab", "glow":0.85},
	{"black":"281718", "graphite":"663b32", "tan":"b54e2d", "wood":"8c3423", "olive":"8c3e2b", "steel":"d29a77", "sleeve":"4c2927", "glove":"291b1c", "accent":"ff9149", "secondary":"ed3f34", "glow":0.85},
	{"black":"211a35", "graphite":"564275", "tan":"754baf", "wood":"5d398c", "olive":"634993", "steel":"b7a1d6", "sleeve":"392853", "glove":"261d39", "accent":"6cefff", "secondary":"c987ff", "glow":0.8},
	{"black":"121a1d", "graphite":"353b3c", "tan":"4b4537", "wood":"39372d", "olive":"393d31", "steel":"d0b579", "sleeve":"202b2e", "glove":"2e302b", "accent":"ebcb87", "secondary":"a58447", "glow":0.18}
]


func _ready() -> void:
	_rng.randomize()
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(45.0)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	camera = Camera3D.new()
	camera.name = "FirstPersonCamera"
	camera.position.y = 1.68
	camera.fov = 78.0
	camera.near = 0.025
	camera.far = 160.0
	camera.current = true
	add_child(camera)
	_weapon_rig = Node3D.new()
	_weapon_rig.name = "WeaponViewModel"
	camera.add_child(_weapon_rig)
	_weapon_rig.position = Vector3(0.255, -0.235, -0.39)
	_make_materials()
	_build_rifle()
	_build_pistol()
	_build_shotgun()
	_build_smg()
	_build_sniper()
	_build_lmg()
	_build_suppressed_rifle()
	set_skin(skin_index)
	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = Color(1.0, 0.69, 0.3)
	_muzzle_light.light_energy = 0.0
	_muzzle_light.omni_range = 4.5
	_muzzle_light.shadow_enabled = false
	_weapon_rig.add_child(_muzzle_light)
	_shot_audio = AudioStreamPlayer.new()
	_shot_audio.volume_db = -12.0
	_shot_audio.max_polyphony = 6
	add_child(_shot_audio)
	_reload_audio = AudioStreamPlayer.new()
	_reload_audio.volume_db = -16.0
	add_child(_reload_audio)
	for index: int in range(weapon_names.size()):
		_sounds.append(_make_sound(index))
	_reload_audio.stream = _make_sound(9)
	_update_weapon_visibility()
	_weapon_rig.visible = enabled

func _exit_tree() -> void:
	for audio_player in [_shot_audio,_reload_audio]:
		if is_instance_valid(audio_player):
			audio_player.stop()
			audio_player.stream = null


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_virtual_move = Vector2.ZERO
		_virtual_fire = false
		_virtual_aim = false
		_physical_fire = false
		_physical_aim = false
		_virtual_sprint = false
		_aim_toggled = false
		aiming = false
		velocity = Vector3.ZERO
	if is_instance_valid(_weapon_rig):
		_weapon_rig.visible = value
	if DisplayServer.get_name() != "headless":
		if value and not OS.has_feature("mobile"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif not value:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	state_changed.emit()


func _input(event: InputEvent) -> void:
	# Releases also clear a held button when the pointer is over an interface control.
	if event.is_action_released("fire"):
		_physical_fire = false
	if event.is_action_released("aim"):
		_physical_aim = false


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		add_look(mouse_event.relative)
	if event.is_action_pressed("fire"):
		_physical_fire = true
	if event.is_action_pressed("aim"):
		_physical_aim = true
	if event.is_action_pressed("reload"):
		reload_weapon()
	elif event.is_action_pressed("interact"):
		interacted.emit()
	elif event.is_action_pressed("melee"):
		melee_attack()
	elif InputMap.has_action("switch_weapon") and event.is_action_pressed("switch_weapon"):
		cycle_weapon()
	for index: int in range(weapon_names.size()):
		var action_name: String = "weapon_%d" % (index + 1)
		if InputMap.has_action(action_name) and event.is_action_pressed(action_name):
			switch_weapon(index)
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_weapon()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			switch_weapon((weapon_index + weapon_names.size() - 1) % weapon_names.size())


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	var movement: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	movement += _virtual_move
	if movement.length() > 1.0:
		movement = movement.normalized()
	var sprinting: bool = (Input.is_action_pressed("sprint") or _virtual_sprint) and not aiming
	var movement_speed: float = RUN_SPEED if sprinting else WALK_SPEED
	if aiming:
		movement_speed = 2.7
	var direction: Vector3 = global_transform.basis * Vector3(movement.x, 0.0, movement.y)
	var acceleration: float = 28.0 if is_on_floor() else 8.0
	velocity.x = move_toward(velocity.x, direction.x * movement_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * movement_speed, acceleration * delta)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	elif Input.is_action_just_pressed("jump") or _virtual_jump:
		velocity.y = 7.0
	_virtual_jump = false
	move_and_slide()
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if is_on_floor():
		_bob += delta * horizontal_speed * 1.6
	camera.position.y = lerpf(camera.position.y, 1.68 + sin(_bob * 2.0) * minf(horizontal_speed / 5.0, 1.0) * 0.014, delta * 10.0)


func _process(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	_punch_remaining = maxf(0.0, _punch_remaining - delta)
	_equip_offset = move_toward(_equip_offset, 0.0, delta * 0.34)
	_sway = _sway.lerp(Vector2.ZERO, minf(delta * 9.0, 1.0))
	if reloading:
		_reload_remaining -= delta
		if _reload_remaining <= 0.0:
			var loaded: int = mini(CAPACITIES[weapon_index] - ammo, reserve)
			ammo += loaded
			reserve -= loaded
			reloading = false
			_store_current_ammo()
			state_changed.emit()
	if enabled:
		var desired_aim: bool = (_aim_toggled or _virtual_aim or _physical_aim) and not reloading and _punch_remaining <= 0.0
		if aiming != desired_aim:
			aiming = desired_aim
			state_changed.emit()
		if _physical_fire or _virtual_fire:
			_fire()
		# The requested arcade handling has no firing or damage kick at all.
		camera.rotation.x = _pitch
	var target_fov: float = AIM_FOV[weapon_index] if aiming else 78.0
	camera.fov = lerpf(camera.fov, target_fov, minf(delta * 12.0, 1.0))
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var target: Vector3 = Vector3(0.255, -0.235, -0.39)
	if weapon_index == 1:
		target = Vector3(0.22, -0.24, -0.42)
	elif weapon_index == 3:
		target = Vector3(0.235, -0.245, -0.4)
	elif weapon_index == 5:
		target = Vector3(0.285, -0.265, -0.41)
	var view_size := get_viewport().get_visible_rect().size
	var aspect := view_size.x/maxf(1.0,view_size.y)
	if aspect < 1.0:
		target.x *= clampf(aspect,0.36,1.0)
		target.z -= (1.0-aspect)*0.12
		target.y -= (1.0-aspect)*0.025
	if aiming:
		target = Vector3(0.0, -SIGHT_HEIGHT[weapon_index], -0.37)
	var reload_fraction: float = 0.0
	if reloading:
		reload_fraction = sin(clampf(_reload_remaining / RELOAD_TIMES[weapon_index], 0.0, 1.0) * PI)
	var punch_fraction: float = sin(clampf(_punch_remaining / 0.43, 0.0, 1.0) * PI)
	target.y -= reload_fraction * 0.21
	target.y -= _equip_offset
	target += Vector3(sin(_bob) * 0.008, absf(cos(_bob)) * 0.007, 0.0) * minf(horizontal_speed / 5.0, 1.0) * (0.25 if aiming else 1.0)
	target.x += _sway.x
	target.y -= _sway.y
	target.z -= punch_fraction * 0.26
	target.x -= punch_fraction * 0.2
	_weapon_rig.position = _weapon_rig.position.lerp(target, minf(delta * 18.0, 1.0))
	var target_rotation: Vector3 = Vector3(reload_fraction * 0.35, -reload_fraction * 0.2 - punch_fraction * 0.6, reload_fraction * -0.55 + punch_fraction * 0.9)
	_weapon_rig.rotation = _weapon_rig.rotation.lerp(target_rotation, minf(delta * 15.0, 1.0))
	for index: int in range(_flashes.size()):
		_flashes[index].visible = enabled and index == weapon_index and _flash_remaining > 0.0
	_muzzle_light.light_energy = 3.0 if _flash_remaining > 0.0 and enabled else 0.0
	if _flashes.size() > weapon_index:
		_muzzle_light.position = _flashes[weapon_index].position
	# The screen-space optic is the view through the sight, so its exterior must
	# not expand across the reticle when a narrow-FOV scope is used.
	_weapon_rig.visible = enabled and not aiming


func add_look(delta: Vector2) -> void:
	if not enabled:
		return
	var sensitivity: float = LOOK_SENSITIVITY * (AIM_FOV[weapon_index] / 90.0 if aiming else 1.0)
	rotation.y -= delta.x * sensitivity
	_pitch = clampf(_pitch - delta.y * sensitivity, deg_to_rad(-89.0), deg_to_rad(89.0))
	_sway.x = clampf(_sway.x - delta.x * 0.00013, -0.025, 0.025)
	_sway.y = clampf(_sway.y - delta.y * 0.0001, -0.018, 0.018)


func apply_look_delta(delta: Vector2) -> void:
	add_look(delta)


func set_virtual_move(value: Vector2) -> void:
	_virtual_move = value.limit_length(1.0) if enabled else Vector2.ZERO


func set_touch_move(value: Vector2) -> void:
	set_virtual_move(value)


func set_touch_fire(pressed: bool) -> void:
	_virtual_fire = pressed and enabled


func toggle_aim() -> void:
	if enabled:
		_aim_toggled = not _aim_toggled


func virtual_action(action: String, pressed: bool) -> void:
	if not enabled:
		return
	match action:
		"fire":
			_virtual_fire = pressed
		"aim":
			_virtual_aim = pressed
		"sprint":
			_virtual_sprint = pressed
		"jump":
			_virtual_jump = pressed
		"reload":
			if pressed:
				reload_weapon()
		"interact":
			if pressed:
				interacted.emit()
		"melee":
			if pressed:
				melee_attack()
		"weapon_1", "weapon_2", "weapon_3", "weapon_4", "weapon_5", "weapon_6", "weapon_7":
			if pressed:
				switch_weapon(int(action.right(1)) - 1)
		"switch_weapon":
			if pressed:
				cycle_weapon()


func _fire() -> void:
	if not enabled or reloading or _fire_cooldown > 0.0 or _punch_remaining > 0.0:
		return
	if ammo <= 0:
		reload_weapon()
		return
	ammo -= 1
	_store_current_ammo()
	_fire_cooldown = FIRE_INTERVALS[weapon_index]
	_flash_remaining = 0.047 if weapon_index != 2 else 0.075
	_shot_audio.stream = _sounds[weapon_index]
	_shot_audio.volume_db = -20.0 if weapon_index == 6 else -12.0
	_shot_audio.pitch_scale = _rng.randf_range(0.94, 1.06)
	_shot_audio.play()
	var pellets: int = 7 if weapon_index == 2 else 1
	var spread: float = 0.004 if aiming else 0.011
	if weapon_index == 2:
		spread = 0.027 if aiming else 0.045
	elif weapon_index == 4:
		spread = 0.0003 if aiming else 0.008
	elif weapon_index == 3:
		spread = 0.0045 if aiming else 0.014
	elif weapon_index == 5:
		spread = 0.005 if aiming else 0.014
	elif weapon_index == 6:
		spread = 0.0025 if aiming else 0.009
	for pellet: int in range(pellets):
		var shot_direction: Vector3 = -camera.global_transform.basis.z
		shot_direction += camera.global_transform.basis.x * _rng.randf_range(-spread, spread)
		shot_direction += camera.global_transform.basis.y * _rng.randf_range(-spread, spread)
		shot_fired.emit(camera.global_position, shot_direction.normalized(), DAMAGE[weapon_index], REACH[weapon_index])
	state_changed.emit()


func reload_weapon() -> void:
	if not enabled or reloading or reserve <= 0 or ammo == CAPACITIES[weapon_index] or _punch_remaining > 0.0:
		return
	reloading = true
	_reload_remaining = RELOAD_TIMES[weapon_index]
	_aim_toggled = false
	aiming = false
	_reload_audio.play()
	state_changed.emit()


func melee_attack() -> void:
	if not enabled or reloading or _punch_remaining > 0.0:
		return
	_punch_remaining = 0.43
	_fire_cooldown = 0.5
	shot_fired.emit(camera.global_position, -camera.global_transform.basis.z, 65.0, 2.3)
	state_changed.emit()


func switch_weapon(index: int) -> void:
	if index < 0 or index >= weapon_names.size() or index == weapon_index:
		return
	_store_current_ammo()
	weapon_index = index
	ammo = _stored_ammo[index]
	reserve = _stored_reserve[index]
	reloading = false
	_reload_remaining = 0.0
	_fire_cooldown = 0.25
	_equip_offset = 0.1
	_update_weapon_visibility()
	state_changed.emit()


func cycle_weapon() -> void:
	if enabled:
		switch_weapon((weapon_index + 1) % weapon_names.size())


func get_weapon_name() -> String:
	return weapon_names[weapon_index]


func set_skin(index: int) -> void:
	# Cosmetics never change ammunition, damage, aiming, firing, or reset state.
	skin_index = clampi(index, 0, SKIN_NAMES.size() - 1)
	if _materials.is_empty() or _models.is_empty() or _applied_skin_index == skin_index:
		return
	for material_name: String in _base_skin_materials:
		var original: StandardMaterial3D = _base_skin_materials[material_name]
		var current: StandardMaterial3D = _materials[material_name]
		current.albedo_color = original.albedo_color
		current.roughness = original.roughness
		current.metallic = original.metallic
		current.emission_enabled = original.emission_enabled
		current.emission = original.emission
		current.emission_energy_multiplier = original.emission_energy_multiplier
	if skin_index > 0:
		var palette: Dictionary = SKIN_COLORS[skin_index]
		for material_name: String in ["black", "graphite", "tan", "wood", "olive", "steel", "sleeve", "glove"]:
			var material: StandardMaterial3D = _materials[material_name]
			material.albedo_color = Color(palette[material_name])
			if material_name not in ["sleeve", "glove"]:
				material.roughness = 0.32 if skin_index < 4 else 0.26
				material.metallic = 0.55 if skin_index < 4 else 0.72
		var accent := Color(palette["accent"])
		var secondary := Color(palette["secondary"])
		_materials["skin_panel"].albedo_color = Color(palette["black"])
		_materials["skin_accent"].albedo_color = secondary
		_materials["skin_inlay"].albedo_color = accent
		_materials["skin_glow"].albedo_color = accent
		_materials["skin_glow"].emission = accent
		_materials["skin_glow"].emission_energy_multiplier = float(palette["glow"])
		_materials["cyan"].albedo_color = accent
		_materials["cyan"].emission = accent
		_materials["cyan"].emission_energy_multiplier = 0.7
	for decoration in _skin_decorations:
		decoration.free()
	_skin_decorations.clear()
	if skin_index > 0:
		for model_index in range(_models.size()):
			_build_skin_decoration(model_index)
	_applied_skin_index = skin_index
	state_changed.emit()


func _build_skin_decoration(model_index: int) -> void:
	var decoration := Node3D.new()
	decoration.name = "SkinDecoration"
	_models[model_index].add_child(decoration)
	_skin_decorations.append(decoration)
	var widths: Array[float] = [0.093, 0.073, 0.091, 0.094, 0.077, 0.115, 0.081]
	var heights: Array[float] = [0.115, 0.060, 0.102, 0.082, 0.085, 0.130, 0.095]
	var lengths: Array[float] = [0.290, 0.265, 0.300, 0.240, 0.320, 0.380, 0.290]
	var center_y: Array[float] = [0.0, 0.022, 0.015, 0.032, 0.018, 0.010, 0.008]
	var center_z: Array[float] = [-0.030, -0.035, 0.025, -0.065, -0.015, -0.048, -0.020]
	var height: float = heights[model_index] * 0.67
	var length: float = lengths[model_index] * 0.77
	for side: float in [-1.0, 1.0]:
		var x: float = side * (widths[model_index] * 0.5 + 0.0018)
		var center := Vector3(x, center_y[model_index], center_z[model_index])
		_box(decoration, Vector3(0.0025, height, length), center, "skin_panel")
		var surface := center + Vector3(side * 0.002, 0, 0)
		if skin_index == 1:
			# Parallel angular circuits and three forward chevrons.
			for track: float in [-1.0, 1.0]:
				var points: Array[Vector3] = [surface + Vector3(0,track*height*0.28,length*0.40), surface + Vector3(0,track*height*0.28,length*0.05), surface + Vector3(0,-track*height*0.08,-length*0.14), surface + Vector3(0,-track*height*0.08,-length*0.43)]
				for segment in range(3):
					_skin_line(decoration, points[segment], points[segment+1], 0.0025, "skin_glow")
			for mark in range(3):
				var mark_z: float = length * (0.12 + mark * 0.105)
				_skin_line(decoration, surface + Vector3(0,-height*0.29,mark_z), surface + Vector3(0,-height*0.07,mark_z-length*0.04), 0.0028, "skin_accent")
		elif skin_index == 2:
			# Armoured orange plates with hot, diagonal cooling slots.
			for vent in range(4):
				var vent_z: float = -length * 0.31 + vent * length * 0.2
				_box(decoration, Vector3(0.002, height*0.8, length*0.12), surface + Vector3(0,0,vent_z), "skin_accent", Vector3(-17,0,0))
				_skin_line(decoration, surface + Vector3(side*0.0015,-height*0.27,vent_z+length*0.03), surface + Vector3(side*0.0015,height*0.28,vent_z-length*0.03), 0.0034, "skin_glow")
		elif skin_index == 3:
			# A continuous cyan lightning waveform over purple plating.
			var last := surface + Vector3(0, 0, length*0.45)
			for pulse in range(6):
				var point := surface + Vector3(0,height*(0.27 if pulse%2==0 else -0.27),length*(0.32-pulse*0.14))
				_skin_line(decoration, last, point, 0.0031, "skin_glow")
				last = point
			for edge: float in [-1.0, 1.0]:
				_skin_line(decoration, surface+Vector3(0,edge*height*0.43,-length*0.43), surface+Vector3(0,edge*height*0.43,length*0.43), 0.0018, "skin_accent")
		else:
			# Framed black-and-gold engraving and a readable callsign badge.
			for edge: float in [-1.0, 1.0]:
				_skin_line(decoration, surface+Vector3(0,edge*height*0.42,-length*0.43), surface+Vector3(0,edge*height*0.42,length*0.43), 0.0022, "skin_inlay")
				_skin_line(decoration, surface+Vector3(0,-height*0.42,edge*length*0.43), surface+Vector3(0,height*0.42,edge*length*0.43), 0.0022, "skin_inlay")
			for mark in range(3):
				_box(decoration, Vector3(0.003, height*0.48, 0.007), surface+Vector3(0,0,-length*(0.2+mark*0.07)), "skin_inlay", Vector3(-22,0,0))
			var badge := _skin_badge(decoration, surface+Vector3(side*0.003,0,length*0.16), minf(height*0.78,0.044))
			badge.rotation.y = side * PI * 0.5
	_build_skin_cuffs(decoration, float(_models[model_index].get_meta("support_z", -0.25)))


func _skin_line(parent: Node3D, from: Vector3, to: Vector3, thickness: float, material_name: String) -> void:
	var direction := to - from
	var line := _box(parent, Vector3(thickness, thickness, direction.length()), (from+to)*0.5, material_name)
	line.rotation.x = atan2(direction.y, -direction.z)


func _skin_badge(parent: Node3D, at: Vector3, height: float) -> Label3D:
	var badge := Label3D.new()
	badge.text = "91"
	badge.font_size = 96
	badge.pixel_size = height / 96.0
	badge.outline_size = 0
	badge.modulate = Color("f5d99d")
	badge.shaded = false
	badge.position = at
	parent.add_child(badge)
	return badge


func _build_skin_cuffs(parent: Node3D, support_z: float) -> void:
	for arm in range(2):
		var cuff := Node3D.new()
		parent.add_child(cuff)
		cuff.position = Vector3(0.04,-0.18,0.28) if arm == 0 else Vector3(-0.13,-0.17,support_z+0.12)
		cuff.rotation_degrees = Vector3(-24,-8,-8) if arm == 0 else Vector3(-17,32,-28)
		var top: float = 0.052 if arm == 0 else 0.057
		_box(cuff, Vector3(0.095,0.003,0.071), Vector3(0,top,0.035), "skin_panel")
		for edge: float in [-1.0,1.0]:
			_box(cuff, Vector3(0.099,0.004,0.006), Vector3(0,top+0.002,0.035+edge*0.036), "skin_inlay")
		if skin_index == 4:
			var badge := _skin_badge(cuff, Vector3(0,top+0.004,0.036), 0.04)
			badge.rotation.x = -PI*0.5
		else:
			for mark in range(3):
				_box(cuff, Vector3(0.016,0.004,0.031), Vector3(-0.028+mark*0.028,top+0.004,0.035), "skin_glow")
	for knuckle in range(3):
		_box(parent, Vector3(0.017,0.004,0.045), Vector3(-0.004+knuckle*0.028,-0.048,0.15), "skin_inlay")


func take_damage(amount: float) -> void:
	if not enabled or health <= 0.0:
		return
	var armor_hit: float = minf(armor, amount * 0.68)
	armor = maxf(0.0, armor - armor_hit)
	health = maxf(0.0, health - (amount - armor_hit))
	state_changed.emit()


func reset_player() -> void:
	health = 100.0
	armor = 100.0
	_stored_ammo = CAPACITIES.duplicate()
	_stored_reserve = STARTING_RESERVE.duplicate()
	weapon_index = 0
	ammo = 30
	reserve = 180
	reloading = false
	_reload_remaining = 0.0
	_fire_cooldown = 0.0
	_punch_remaining = 0.0
	_flash_remaining = 0.0
	_equip_offset = 0.0
	_aim_toggled = false
	_virtual_fire = false
	_virtual_aim = false
	_physical_fire = false
	_physical_aim = false
	_virtual_move = Vector2.ZERO
	aiming = false
	_pitch = 0.0
	velocity = Vector3.ZERO
	if is_instance_valid(camera):
		camera.rotation = Vector3.ZERO
		camera.fov = 78.0
	_update_weapon_visibility()
	state_changed.emit()


func _store_current_ammo() -> void:
	_stored_ammo[weapon_index] = ammo
	_stored_reserve[weapon_index] = reserve


func _update_weapon_visibility() -> void:
	for index: int in range(_models.size()):
		_models[index].visible = index == weapon_index


func _make_materials() -> void:
	_materials["black"] = _material(Color("131c22"), 0.55, 0.28)
	_materials["graphite"] = _material(Color("34434a"), 0.4, 0.52)
	_materials["tan"] = _material(Color("aa9672"), 0.76, 0.15)
	_materials["rubber"] = _material(Color("1a2025"), 0.93, 0.0)
	_materials["steel"] = _material(Color("8eaaa9"), 0.25, 0.8)
	_materials["cyan"] = _material(Color("71ffe5"), 0.3, 0.2, true)
	_materials["sleeve"] = _material(Color("435659"), 0.95, 0.0)
	_materials["glove"] = _material(Color("263135"), 0.87, 0.0)
	_materials["flash"] = _material(Color("fff0b0"), 0.0, 0.0, true)
	_materials["amber"] = _material(Color("f9af5c"), 0.4, 0.0, true)
	_materials["olive"] = _material(Color("647153"), 0.83, 0.12)
	_materials["wood"] = _material(Color("754b38"), 0.75, 0.0)
	_materials["brass"] = _material(Color("cba660"), 0.35, 0.64)
	_materials["skin_panel"] = _material(Color("17252a"), 0.34, 0.5)
	_materials["skin_accent"] = _material(Color("41766e"), 0.3, 0.68)
	_materials["skin_inlay"] = _material(Color("87e6c9"), 0.26, 0.72)
	_materials["skin_glow"] = _material(Color("87ffe0"), 0.3, 0.25, true)
	for material_name: String in _materials:
		_base_skin_materials[material_name] = _materials[material_name].duplicate()


func _material(color: Color, roughness: float, metallic: float, glow: bool = false) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
	return material


func _box(parent: Node3D, dimensions: Vector3, at: Vector3, material_name: String, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = dimensions
	mesh_instance.mesh = box
	mesh_instance.material_override = _materials[material_name] as Material
	mesh_instance.position = at
	mesh_instance.rotation_degrees = rotation_value
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)
	return mesh_instance


func _cylinder(parent: Node3D, radius: float, length: float, at: Vector3, material_name: String, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = radius if top_radius < 0.0 else top_radius
	cylinder.bottom_radius = radius
	cylinder.height = length
	cylinder.radial_segments = 12
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = _materials[material_name] as Material
	mesh_instance.position = at
	mesh_instance.rotation_degrees.x = 90.0
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)
	return mesh_instance


func _new_model(model_name: String) -> Node3D:
	var model: Node3D = Node3D.new()
	model.name = model_name
	_weapon_rig.add_child(model)
	_models.append(model)
	return model


func _arms(model: Node3D, support_z: float) -> void:
	# Hands are integrated into each view model, with raised knuckle pads and cuffs.
	model.set_meta("support_z", support_z)
	_box(model, Vector3(0.095, 0.095, 0.16), Vector3(0.018, -0.1, 0.12), "glove", Vector3(-15.0, 0.0, -7.0))
	_box(model, Vector3(0.105, 0.1, 0.22), Vector3(0.04, -0.18, 0.28), "sleeve", Vector3(-24.0, -8.0, -8.0))
	_box(model, Vector3(0.105, 0.034, 0.065), Vector3(0.025, -0.068, 0.15), "black")
	_box(model, Vector3(0.11, 0.065, 0.13), Vector3(-0.025, -0.085, support_z), "glove", Vector3(2.0, -8.0, -10.0))
	_box(model, Vector3(0.12, 0.11, 0.28), Vector3(-0.13, -0.17, support_z + 0.12), "sleeve", Vector3(-17.0, 32.0, -28.0))
	_box(model, Vector3(0.038, 0.068, 0.1), Vector3(-0.066, -0.032, support_z), "glove", Vector3(0.0, 0.0, -12.0))
	for finger: int in range(3):
		_box(model, Vector3(0.023, 0.016, 0.047), Vector3(-0.03 + finger * 0.027, -0.042, support_z + 0.045), "graphite")


func _build_rifle() -> void:
	var model: Node3D = _new_model("CAR9")
	_box(model, Vector3(0.093, 0.115, 0.29), Vector3(0.0, 0.0, -0.03), "tan")
	_box(model, Vector3(0.078, 0.07, 0.33), Vector3(0.0, 0.058, -0.065), "graphite")
	_box(model, Vector3(0.097, 0.09, 0.3), Vector3(0.0, 0.012, -0.33), "tan")
	_box(model, Vector3(0.073, 0.015, 0.32), Vector3(0.0, 0.065, -0.33), "black")
	_box(model, Vector3(0.061, 0.16, 0.095), Vector3(0.0, -0.102, -0.044), "black", Vector3(-11.0, 0.0, 0.0))
	_box(model, Vector3(0.065, 0.125, 0.063), Vector3(0.0, -0.092, 0.096), "rubber", Vector3(-20.0, 0.0, 0.0))
	_box(model, Vector3(0.067, 0.07, 0.19), Vector3(0.0, 0.004, 0.198), "tan")
	_box(model, Vector3(0.081, 0.127, 0.034), Vector3(0.0, -0.015, 0.3), "rubber")
	_cylinder(model, 0.018, 0.22, Vector3(0.0, 0.019, -0.56), "steel")
	_cylinder(model, 0.026, 0.063, Vector3(0.0, 0.019, -0.696), "black")
	_cylinder(model, 0.014, 0.003, Vector3(0.0, 0.019, -0.73), "rubber")
	_box(model, Vector3(0.01, 0.027, 0.09), Vector3(0.05, 0.037, -0.004), "black")
	_box(model, Vector3(0.018, 0.009, 0.044), Vector3(0.055, 0.038, -0.02), "steel")
	_box(model, Vector3(0.043, 0.045, 0.054), Vector3(0.0, 0.094, 0.065), "black")
	_box(model, Vector3(0.073, 0.012, 0.067), Vector3(0.0, 0.121, 0.065), "graphite")
	_box(model, Vector3(0.011, 0.053, 0.055), Vector3(-0.032, 0.146, 0.065), "graphite")
	_box(model, Vector3(0.011, 0.053, 0.055), Vector3(0.032, 0.146, 0.065), "graphite")
	_box(model, Vector3(0.073, 0.011, 0.055), Vector3(0.0, 0.173, 0.065), "graphite")
	_box(model, Vector3(0.005, 0.005, 0.004), Vector3(0.0, 0.146, 0.034), "cyan")
	_box(model, Vector3(0.006, 0.008, 0.072), Vector3(0.05, 0.02, -0.16), "cyan")
	for slot: int in range(7):
		_box(model, Vector3(0.003, 0.018, 0.018), Vector3(0.05, 0.014, -0.227 - slot * 0.032), "black")
		_box(model, Vector3(0.078, 0.01, 0.012), Vector3(0.0, 0.078, -0.22 - slot * 0.036), "black")
	for ridge: int in range(4):
		_box(model, Vector3(0.064, 0.009, 0.008), Vector3(0.0, -0.07 - ridge * 0.025, 0.004), "graphite")
	_arms(model, -0.265)
	_add_flash(model, Vector3(0.0, 0.019, -0.753))


func _build_pistol() -> void:
	var model: Node3D = _new_model("P12")
	_box(model, Vector3(0.073, 0.06, 0.265), Vector3(0.0, 0.022, -0.035), "graphite")
	_box(model, Vector3(0.065, 0.038, 0.235), Vector3(0.0, -0.025, -0.025), "tan")
	_box(model, Vector3(0.065, 0.13, 0.085), Vector3(0.0, -0.083, 0.064), "rubber", Vector3(-15.0, 0.0, 0.0))
	_box(model, Vector3(0.048, 0.017, 0.04), Vector3(0.0, -0.07, -0.02), "black")
	_box(model, Vector3(0.05, 0.05, 0.014), Vector3(0.0, -0.048, -0.047), "black")
	_cylinder(model, 0.022, 0.028, Vector3(0.0, 0.02, -0.176), "steel")
	_cylinder(model, 0.014, 0.004, Vector3(0.0, 0.02, -0.192), "rubber")
	_box(model, Vector3(0.05, 0.023, 0.016), Vector3(0.0, 0.064, 0.067), "black")
	_box(model, Vector3(0.009, 0.021, 0.015), Vector3(0.0, 0.059, -0.134), "cyan")
	_box(model, Vector3(0.005, 0.006, 0.005), Vector3(-0.018, 0.073, 0.077), "cyan")
	_box(model, Vector3(0.005, 0.006, 0.005), Vector3(0.018, 0.073, 0.077), "cyan")
	for slot: int in range(5):
		_box(model, Vector3(0.002, 0.036, 0.006), Vector3(0.037, 0.02, 0.065 - slot * 0.013), "black")
	_arms(model, 0.055)
	_add_flash(model, Vector3(0.0, 0.02, -0.215))


func _build_shotgun() -> void:
	var model: Node3D = _new_model("M870")
	_box(model, Vector3(0.091, 0.102, 0.3), Vector3(0.0, 0.015, 0.025), "graphite")
	_box(model, Vector3(0.09, 0.083, 0.19), Vector3(0.0, -0.02, 0.242), "tan", Vector3(-9.0, 0.0, 0.0))
	_box(model, Vector3(0.09, 0.14, 0.035), Vector3(0.0, -0.045, 0.34), "rubber")
	_cylinder(model, 0.026, 0.54, Vector3(0.0, 0.04, -0.378), "steel")
	_cylinder(model, 0.022, 0.46, Vector3(0.0, -0.017, -0.34), "graphite")
	_cylinder(model, 0.029, 0.04, Vector3(0.0, 0.04, -0.659), "black")
	_cylinder(model, 0.019, 0.003, Vector3(0.0, 0.04, -0.68), "rubber")
	_box(model, Vector3(0.097, 0.08, 0.2), Vector3(0.0, -0.025, -0.31), "tan")
	_box(model, Vector3(0.006, 0.018, 0.065), Vector3(0.047, 0.03, -0.01), "amber")
	_box(model, Vector3(0.06, 0.015, 0.28), Vector3(0.0, 0.077, -0.035), "black")
	_box(model, Vector3(0.038, 0.028, 0.02), Vector3(0.0, 0.094, 0.082), "black")
	_box(model, Vector3(0.009, 0.022, 0.021), Vector3(0.0, 0.069, -0.57), "cyan")
	for ring: int in range(7):
		_box(model, Vector3(0.1, 0.085, 0.008), Vector3(0.0, -0.025, -0.227 - ring * 0.027), "rubber")
	for shell: int in range(4):
		var shell_mesh: MeshInstance3D = _cylinder(model, 0.01, 0.053, Vector3(0.054, 0.007, -0.005 + shell * 0.035), "tan")
		shell_mesh.rotation_degrees = Vector3.ZERO
	_arms(model, -0.28)
	_add_flash(model, Vector3(0.0, 0.04, -0.706))


func _holographic_sight(model: Node3D, height: float, z_offset: float) -> void:
	_box(model, Vector3(0.041, 0.035, 0.065), Vector3(0.0, height - 0.05, z_offset), "black")
	_box(model, Vector3(0.073, 0.011, 0.06), Vector3(0.0, height - 0.028, z_offset), "graphite")
	_box(model, Vector3(0.01, 0.055, 0.06), Vector3(-0.032, height, z_offset), "graphite")
	_box(model, Vector3(0.01, 0.055, 0.06), Vector3(0.032, height, z_offset), "graphite")
	_box(model, Vector3(0.073, 0.011, 0.06), Vector3(0.0, height + 0.03, z_offset), "graphite")
	_box(model, Vector3(0.004, 0.004, 0.003), Vector3(0.0, height, z_offset - 0.033), "cyan")


func _scope(model: Node3D, height: float, z_offset: float, length: float) -> void:
	# Open rings preserve the sight line; the HUD supplies the magnified reticle.
	for index: int in range(6):
		var scope_ring: MeshInstance3D = MeshInstance3D.new()
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 0.033 if index in [0, 5] else 0.028
		ring.outer_radius = 0.052 if index in [0, 5] else 0.04
		ring.rings = 18
		ring.ring_segments = 8
		scope_ring.mesh = ring
		scope_ring.material_override = _materials["black"] as Material
		scope_ring.position = Vector3(0.0, height, z_offset - float(index) * length / 5.0)
		scope_ring.rotation_degrees.x = 90.0
		scope_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(scope_ring)
	_box(model, Vector3(0.034, 0.075, 0.028), Vector3(0.0, height - 0.072, z_offset - length * 0.22), "black")
	_box(model, Vector3(0.034, 0.075, 0.028), Vector3(0.0, height - 0.072, z_offset - length * 0.78), "black")
	var elevation_knob: MeshInstance3D = _cylinder(model, 0.025, 0.025, Vector3(0.0, height + 0.05, z_offset - length * 0.5), "graphite")
	elevation_knob.rotation = Vector3.ZERO
	var windage_knob: MeshInstance3D = _cylinder(model, 0.019, 0.02, Vector3(0.047, height, z_offset - length * 0.5), "graphite")
	windage_knob.rotation_degrees.y = 90.0
	_box(model, Vector3(0.003, 0.01, 0.022), Vector3(0.052, height, z_offset - length * 0.5), "cyan")


func _build_smg() -> void:
	var model: Node3D = _new_model("VECTOR")
	_box(model, Vector3(0.094, 0.082, 0.24), Vector3(0.0, 0.032, -0.065), "tan")
	_box(model, Vector3(0.087, 0.15, 0.12), Vector3(0.0, -0.07, -0.072), "graphite")
	_box(model, Vector3(0.09, 0.07, 0.13), Vector3(0.0, 0.005, -0.23), "black")
	_box(model, Vector3(0.059, 0.25, 0.058), Vector3(0.0, -0.195, -0.075), "black", Vector3(-5.0, 0.0, 0.0))
	_box(model, Vector3(0.069, 0.027, 0.071), Vector3(0.0, -0.319, -0.064), "tan")
	_box(model, Vector3(0.063, 0.135, 0.055), Vector3(0.0, -0.075, 0.083), "rubber", Vector3(-14.0, 0.0, 0.0))
	_box(model, Vector3(0.054, 0.028, 0.16), Vector3(0.0, 0.04, 0.159), "graphite")
	_box(model, Vector3(0.055, 0.032, 0.15), Vector3(0.0, -0.018, 0.158), "graphite", Vector3(-13.0, 0.0, 0.0))
	_box(model, Vector3(0.07, 0.13, 0.03), Vector3(0.0, -0.02, 0.245), "rubber")
	_cylinder(model, 0.026, 0.115, Vector3(0.0, 0.032, -0.34), "steel")
	_cylinder(model, 0.031, 0.045, Vector3(0.0, 0.032, -0.417), "black")
	_cylinder(model, 0.016, 0.003, Vector3(0.0, 0.032, -0.442), "rubber")
	_box(model, Vector3(0.054, 0.016, 0.3), Vector3(0.0, 0.084, -0.085), "black")
	_box(model, Vector3(0.045, 0.13, 0.055), Vector3(0.0, -0.087, -0.235), "rubber")
	for slot: int in range(5):
		_box(model, Vector3(0.004, 0.034, 0.009), Vector3(0.049, 0.027, -0.117 - float(slot) * 0.025), "black")
		_box(model, Vector3(0.061, 0.008, 0.06), Vector3(0.0, -0.125 - float(slot) * 0.033, -0.068), "graphite")
	_box(model, Vector3(0.005, 0.018, 0.047), Vector3(0.048, -0.033, -0.023), "cyan")
	_holographic_sight(model, SIGHT_HEIGHT[3], 0.008)
	_arms(model, -0.205)
	_add_flash(model, Vector3(0.0, 0.032, -0.458))


func _build_sniper() -> void:
	var model: Node3D = _new_model("SVD")
	_box(model, Vector3(0.077, 0.085, 0.32), Vector3(0.0, 0.018, -0.015), "graphite")
	_box(model, Vector3(0.078, 0.072, 0.35), Vector3(0.0, 0.005, -0.34), "wood")
	_box(model, Vector3(0.078, 0.077, 0.26), Vector3(0.0, -0.015, 0.22), "wood", Vector3(-5.0, 0.0, 0.0))
	_box(model, Vector3(0.045, 0.037, 0.145), Vector3(0.0, 0.047, 0.248), "black")
	_box(model, Vector3(0.088, 0.128, 0.025), Vector3(0.0, -0.04, 0.352), "rubber")
	_box(model, Vector3(0.055, 0.113, 0.066), Vector3(0.0, -0.075, 0.102), "wood", Vector3(-20.0, 0.0, 0.0))
	_box(model, Vector3(0.058, 0.113, 0.089), Vector3(0.0, -0.086, -0.025), "steel", Vector3(-12.0, 0.0, 0.0))
	_cylinder(model, 0.017, 0.43, Vector3(0.0, 0.027, -0.715), "steel")
	_cylinder(model, 0.024, 0.07, Vector3(0.0, 0.027, -0.955), "black")
	_cylinder(model, 0.012, 0.003, Vector3(0.0, 0.027, -0.993), "rubber")
	_box(model, Vector3(0.068, 0.025, 0.044), Vector3(0.0, 0.018, -0.51), "black")
	_box(model, Vector3(0.017, 0.026, 0.23), Vector3(-0.04, -0.038, -0.405), "graphite", Vector3(0.0, -5.0, 0.0))
	_box(model, Vector3(0.017, 0.026, 0.23), Vector3(0.04, -0.038, -0.405), "graphite", Vector3(0.0, 5.0, 0.0))
	_box(model, Vector3(0.066, 0.013, 0.35), Vector3(0.0, 0.072, -0.025), "black")
	_box(model, Vector3(0.045, 0.013, 0.025), Vector3(0.057, 0.035, 0.045), "steel")
	for slot: int in range(8):
		_box(model, Vector3(0.003, 0.025, 0.015), Vector3(0.04, 0.005, -0.217 - float(slot) * 0.035), "black")
	_scope(model, SIGHT_HEIGHT[4], 0.075, 0.32)
	_arms(model, -0.3)
	_add_flash(model, Vector3(0.0, 0.027, -1.01))


func _build_lmg() -> void:
	var model: Node3D = _new_model("M249")
	_box(model, Vector3(0.115, 0.13, 0.38), Vector3(0.0, 0.01, -0.048), "olive")
	_box(model, Vector3(0.12, 0.035, 0.3), Vector3(0.0, 0.09, -0.02), "graphite")
	_box(model, Vector3(0.105, 0.083, 0.25), Vector3(0.0, 0.002, -0.35), "black")
	_box(model, Vector3(0.19, 0.19, 0.18), Vector3(-0.037, -0.128, -0.05), "olive")
	_box(model, Vector3(0.195, 0.019, 0.187), Vector3(-0.037, -0.037, -0.05), "black")
	_box(model, Vector3(0.065, 0.126, 0.068), Vector3(0.0, -0.086, 0.133), "rubber", Vector3(-16.0, 0.0, 0.0))
	_box(model, Vector3(0.08, 0.085, 0.18), Vector3(0.0, 0.006, 0.246), "olive")
	_box(model, Vector3(0.09, 0.14, 0.031), Vector3(0.0, -0.011, 0.344), "rubber")
	_cylinder(model, 0.022, 0.36, Vector3(0.0, 0.039, -0.622), "steel")
	_cylinder(model, 0.03, 0.068, Vector3(0.0, 0.039, -0.828), "black")
	_cylinder(model, 0.017, 0.003, Vector3(0.0, 0.039, -0.864), "rubber")
	_box(model, Vector3(0.025, 0.016, 0.195), Vector3(-0.08, -0.041, -0.423), "graphite", Vector3(0.0, -7.0, 0.0))
	_box(model, Vector3(0.025, 0.016, 0.195), Vector3(0.08, -0.041, -0.423), "graphite", Vector3(0.0, 7.0, 0.0))
	_box(model, Vector3(0.018, 0.068, 0.017), Vector3(0.055, 0.12, -0.34), "black")
	_box(model, Vector3(0.018, 0.068, 0.017), Vector3(0.055, 0.12, -0.21), "black")
	_box(model, Vector3(0.028, 0.026, 0.15), Vector3(0.055, 0.153, -0.275), "rubber")
	for slot: int in range(6):
		_box(model, Vector3(0.004, 0.032, 0.016), Vector3(0.056, 0.012, -0.267 - float(slot) * 0.031), "graphite")
	for round_index: int in range(5):
		var cartridge: MeshInstance3D = _cylinder(model, 0.009, 0.069, Vector3(-0.078 - float(round_index) * 0.014, 0.017 - float(round_index) * 0.013, -0.03), "brass", 0.004)
		cartridge.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_holographic_sight(model, SIGHT_HEIGHT[5], 0.055)
	_arms(model, -0.29)
	_add_flash(model, Vector3(0.0, 0.039, -0.88))


func _build_suppressed_rifle() -> void:
	var model: Node3D = _new_model("ASVAL")
	_box(model, Vector3(0.081, 0.095, 0.29), Vector3(0.0, 0.008, -0.02), "black")
	_box(model, Vector3(0.084, 0.072, 0.215), Vector3(0.0, 0.003, -0.257), "wood")
	_box(model, Vector3(0.06, 0.155, 0.079), Vector3(0.0, -0.096, -0.022), "black", Vector3(-17.0, 0.0, 0.0))
	_box(model, Vector3(0.061, 0.12, 0.056), Vector3(0.0, -0.082, 0.103), "wood", Vector3(-20.0, 0.0, 0.0))
	_box(model, Vector3(0.024, 0.023, 0.185), Vector3(-0.024, 0.021, 0.24), "steel")
	_box(model, Vector3(0.024, 0.023, 0.19), Vector3(-0.024, -0.045, 0.24), "steel", Vector3(-13.0, 0.0, 0.0))
	_box(model, Vector3(0.061, 0.131, 0.029), Vector3(-0.024, -0.04, 0.336), "rubber")
	_cylinder(model, 0.037, 0.38, Vector3(0.0, 0.018, -0.535), "graphite")
	_cylinder(model, 0.039, 0.035, Vector3(0.0, 0.018, -0.738), "black")
	_cylinder(model, 0.014, 0.003, Vector3(0.0, 0.018, -0.758), "rubber")
	_box(model, Vector3(0.013, 0.038, 0.11), Vector3(0.046, 0.011, 0.024), "steel")
	_box(model, Vector3(0.004, 0.011, 0.058), Vector3(0.043, 0.026, -0.087), "cyan")
	for rib: int in range(5):
		_box(model, Vector3(0.087, 0.076, 0.008), Vector3(0.0, 0.003, -0.194 - float(rib) * 0.032), "black")
	for rib: int in range(3):
		_box(model, Vector3(0.062, 0.008, 0.075), Vector3(0.0, -0.077 - float(rib) * 0.032, -0.023 + float(rib) * 0.009), "graphite")
	_scope(model, SIGHT_HEIGHT[6], 0.055, 0.185)
	_arms(model, -0.25)
	_add_flash(model, Vector3(0.0, 0.018, -0.775))
	_flashes[_flashes.size() - 1].scale = Vector3.ONE * 0.34


func _add_flash(model: Node3D, at: Vector3) -> void:
	var flash: Node3D = Node3D.new()
	flash.position = at
	flash.visible = false
	model.add_child(flash)
	_cylinder(flash, 0.065, 0.14, Vector3(0.0, 0.0, -0.055), "flash", 0.008)
	_box(flash, Vector3(0.18, 0.012, 0.025), Vector3(0.0, 0.0, -0.035), "amber")
	_box(flash, Vector3(0.014, 0.14, 0.025), Vector3(0.0, 0.0, -0.035), "flash")
	_flashes.append(flash)


func _make_sound(kind: int) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.20
	if kind == 2:
		duration = 0.34
	elif kind == 4:
		duration = 0.39
	elif kind == 6:
		duration = 0.12
	elif kind == 9:
		duration = 0.42
	var count: int = int(float(sample_rate) * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	var sound_random: RandomNumberGenerator = RandomNumberGenerator.new()
	sound_random.seed = 3188 + kind
	var low_noise: float = 0.0
	for sample: int in range(count):
		var time: float = float(sample) / float(sample_rate)
		var noise: float = sound_random.randf_range(-1.0, 1.0)
		low_noise = lerpf(low_noise, noise, 0.24)
		var decay: float = 19.0
		if kind in [2, 4]:
			decay = 13.0
		elif kind in [3, 6]:
			decay = 29.0
		var tone_frequency: float = 95.0
		if kind == 1:
			tone_frequency = 160.0
		elif kind == 3:
			tone_frequency = 210.0
		elif kind == 4:
			tone_frequency = 61.0
		elif kind == 5:
			tone_frequency = 79.0
		elif kind == 6:
			tone_frequency = 310.0
		var envelope: float = exp(-time * decay)
		var tone: float = sin(TAU * tone_frequency * time * exp(-time * 4.0))
		var value: float = (noise * 0.44 + low_noise * 0.28 + tone * 0.27) * envelope
		if kind == 6:
			value = (low_noise * 0.43 + tone * 0.38) * envelope
		if kind == 9:
			var click_one: float = exp(-time * 85.0)
			var click_two: float = exp(-maxf(time - 0.21, 0.0) * 65.0) if time >= 0.21 else 0.0
			value = noise * (click_one + click_two) * 0.5
		var signed_value: int = int(clampf(value, -1.0, 1.0) * 30000.0)
		data.encode_s16(sample * 2, signed_value)
	var result: AudioStreamWAV = AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = sample_rate
	result.stereo = false
	result.data = data
	return result
