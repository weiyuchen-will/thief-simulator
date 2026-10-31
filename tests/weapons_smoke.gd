extends SceneTree
var player: CharacterBody3D
var shots: int = 0
const CAPS: Array[int] = [30, 12, 6, 35, 8, 100, 20]
const RESERVES: Array[int] = [180, 72, 36, 210, 40, 300, 120]
func _initialize() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump", "fire", "aim", "reload", "interact", "melee", "pause", "switch_weapon", "weapon_1", "weapon_2", "weapon_3", "weapon_4", "weapon_5", "weapon_6", "weapon_7"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	player = load("res://scripts/player.gd").new()
	root.add_child.call_deferred(player)
	_test.call_deferred()
func _test() -> void:
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	player.set_enabled(true)
	player.shot_fired.connect(func(_o: Vector3, _d: Vector3, _a: float, _r: float) -> void: shots += 1)
	assert(player.weapon_names.size() == 7)
	assert(player._models.size() == 7)
	for index: int in range(7):
		player.switch_weapon(index)
		player._process(1.0)
		assert(player.ammo == CAPS[index])
		var pose: Vector3 = player._weapon_rig.position
		var camera_rotation: Vector3 = player.camera.rotation
		player._fire()
		player._process(0.016)
		assert(player.ammo == CAPS[index] - 1)
		assert(player.camera.rotation.is_equal_approx(camera_rotation), "Firing changed the camera")
		assert(player._weapon_rig.position.is_equal_approx(pose), "Firing moved the weapon")
		player.take_damage(1.0)
		player._process(0.016)
		assert(player.camera.rotation.is_equal_approx(camera_rotation), "Damage moved the camera")
		assert(player._weapon_rig.position.is_equal_approx(pose), "Damage moved the weapon")
		for model_index: int in range(7):
			assert(player._models[model_index].visible == (index == model_index))
		print("WEAPON_OK ", index, " ", player.get_weapon_name(), " capacity=", CAPS[index])
	assert(shots == 13)
	for index: int in range(7):
		player.switch_weapon(index)
		assert(player.ammo == CAPS[index] - 1, "Weapon ammo was not independent")
		player.reload_weapon()
		player._process(4.0)
		assert(player.ammo == CAPS[index] and player.reserve == RESERVES[index] - 1)
	player.switch_weapon(4)
	player.toggle_aim()
	player._process(1.0)
	assert(is_equal_approx(player.camera.fov, 24.0))
	var cycle_event: InputEventAction = InputEventAction.new()
	cycle_event.action = "switch_weapon"
	cycle_event.pressed = true
	player._unhandled_input(cycle_event)
	assert(player.weapon_index == 5)
	var number_event: InputEventAction = InputEventAction.new()
	number_event.action = "weapon_7"
	number_event.pressed = true
	player._unhandled_input(number_event)
	assert(player.weapon_index == 6)
	player.cycle_weapon()
	assert(player.weapon_index == 0)
	player.apply_look_delta(Vector2(120.0, 50.0))
	assert(player.rotation.y < 0.0)
	player.set_touch_move(Vector2(1.0, -1.0))
	assert(player._virtual_move.length() <= 1.0)
	player.set_enabled(false)
	var yaw: float = player.rotation.y
	player.apply_look_delta(Vector2(100.0, 0.0))
	assert(is_equal_approx(player.rotation.y, yaw))
	assert(player._virtual_move == Vector2.ZERO)
	player.reset_player()
	for index: int in range(7):
		player.switch_weapon(index)
		assert(player.ammo == CAPS[index] and player.reserve == RESERVES[index])
	assert(player.health == 100.0 and player.armor == 100.0)
	print("ARSENAL_SMOKE_OK weapons=7 shots=", shots, " no_firing_or_damage_recoil=true")
	player.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	quit()
