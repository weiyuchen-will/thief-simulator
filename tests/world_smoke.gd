extends SceneTree
## Exercise real capsule movement, including the raised entrance and return route.
## Run with: godot --headless --path . --fixed-fps 60 --script res://tests/world_smoke.gd

const WORLD = preload("res://scripts/world.gd")
const PLAYER = preload("res://scripts/player.gd")

func _initialize() -> void:
	for action: String in ["move_left", "move_right", "move_forward", "move_back", "sprint", "jump"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	_run_checks.call_deferred()

func _run_checks() -> void:
	for location_name: String in ["home", "office"]:
		var world: Node3D = WORLD.new()
		# Location must be chosen before _ready() builds its colliders.
		world.location = location_name
		root.add_child(world)
		var player: CharacterBody3D = PLAYER.new()
		root.add_child(player)
		player.position = Vector3(0, 0.05, -8)
		player.set_enabled(true)
		await physics_frame
		if not await _walk_to(player, Vector3(0, 0, -32.2), 450):
			push_error(location_name + " could not reach the rear room: " + str(player.position))
			quit(1)
			return
		var rear_position: Vector3 = player.position
		world.set_alarm(true)
		# Return through the same doorway, then approach the passenger side of the van.
		for waypoint: Vector3 in [Vector3(0, 0, -8), Vector3(2.2, 0, 6.5), world.get_escape_position()]:
			if not await _walk_to(player, waypoint, 600):
				push_error(location_name + " return blocked toward " + str(waypoint) + " at " + str(player.position))
				quit(1)
				return
		player.set_touch_move(Vector2.ZERO)
		var escape_position: Vector3 = player.position
		print("WORLD_ROUTE_OK location=", location_name, " rear=", rear_position, " escape=", escape_position, " on_floor=", player.is_on_floor())
		world.set_alarm(false)
		player.queue_free()
		world.queue_free()
		await process_frame
		await physics_frame
	print("WORLD_SMOKE_OK locations=2 entrance=true rear_room=true return=true escape=true jumping=false")
	quit()

func _walk_to(player: CharacterBody3D, target: Vector3, maximum_frames: int) -> bool:
	for frame in range(maximum_frames):
		var offset := Vector2(target.x - player.position.x, target.z - player.position.z)
		if offset.length() < 0.14:
			player.set_touch_move(Vector2.ZERO)
			return true
		if player.position.y < -0.25:
			return false
		player.set_touch_move(offset.normalized())
		await physics_frame
	player.set_touch_move(Vector2.ZERO)
	return false
