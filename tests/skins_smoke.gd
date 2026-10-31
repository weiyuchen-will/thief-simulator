extends SceneTree
## Cosmetic changes preserve combat state and survive weapon/mission resets.

const PLAYER = preload("res://scripts/player.gd")

func _initialize() -> void:
	for action: String in ["move_left", "move_right", "move_forward", "move_back", "sprint", "jump", "fire", "aim", "reload", "interact", "melee"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	_test.call_deferred()

func _test() -> void:
	var player: CharacterBody3D = PLAYER.new()
	player.set_skin(3)
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.set_enabled(true)
	assert(player.skin_index == 3 and player._skin_decorations.size() == 7, "Pre-ready skin was not applied")
	var body_colors: Array[Color] = []
	var sleeve_colors: Array[Color] = []
	for tier in range(5):
		var camera_pose: Transform3D = player.camera.transform
		var weapon_pose: Transform3D = player._weapon_rig.transform
		var ammo_before: int = player.ammo
		var reserve_before: int = player.reserve
		player.set_skin(tier)
		assert(player.ammo == ammo_before and player.reserve == reserve_before, "Skin modified ammunition")
		assert(player.camera.transform.is_equal_approx(camera_pose), "Skin moved the camera")
		assert(player._weapon_rig.transform.is_equal_approx(weapon_pose), "Skin moved the weapon")
		var body_color: Color = player._materials["tan"].albedo_color
		var sleeve_color: Color = player._materials["sleeve"].albedo_color
		assert(not body_colors.has(body_color), "Weapon skin is not visually distinct")
		assert(not sleeve_colors.has(sleeve_color), "Sleeves do not match a distinct skin")
		body_colors.append(body_color)
		sleeve_colors.append(sleeve_color)
		for gun in range(7):
			player.switch_weapon(gun)
			assert(player.skin_index == tier)
			assert(player.ammo == player.CAPACITIES[gun] and player.reserve == player.STARTING_RESERVE[gun])
			for other_gun in range(7):
				assert(player._models[other_gun].visible == (other_gun == gun))
			var decoration: Node3D = player._models[gun].get_node_or_null("SkinDecoration")
			if tier == 0:
				assert(decoration == null)
			else:
				assert(decoration != null and decoration.find_children("*", "MeshInstance3D", true, false).size() >= 20)
				if tier == 4:
					var badges: Array[Node] = decoration.find_children("*", "Label3D", true, false)
					assert(badges.size() == 4, "Gold skin must label both weapon sides and cuffs")
					for badge in badges:
						assert(badge.text == "91")
		var node_count: int = player.find_children("*", "", true, false).size()
		player.set_skin(tier)
		assert(node_count == player.find_children("*", "", true, false).size(), "Repeated skin selection leaked nodes")
		player.reset_player()
		assert(player.skin_index == tier and player._materials["tan"].albedo_color == body_color, "Mission reset discarded cosmetic selection")
		print("SKIN_OK tier=", tier, " weapons=7 reset_retained=true nodes=", node_count)
	player.set_skin(-1)
	assert(player.skin_index == 0)
	player.set_skin(99)
	assert(player.skin_index == 4)
	player.switch_weapon(4)
	player.ammo = 3
	player.reserve = 9
	player.reloading = true
	player.set_skin(1)
	assert(player.ammo == 3 and player.reserve == 9 and player.reloading, "Skin interrupted a reload")
	print("SKINS_SMOKE_OK skins=5 weapons=7 pre_ready=true ammo_preserved=true reset_retained=true")
	player.queue_free()
	await process_frame
	quit()
