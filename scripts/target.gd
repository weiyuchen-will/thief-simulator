extends CharacterBody3D
## A mission-only character. This actor never joins either combatant team.

signal eliminated(actor)

var alive: bool = true
var health: float = 100.0
var active: bool = false
var captured: bool = false
var follow_target: Node3D
var kind: String = "assassinate"
var target_name: String = "任务目标"
var capture_mode: bool = false

const FOLLOW_DISTANCE: float = 1.8
const FOLLOW_SPEED: float = 4.7
const GRID_RECT: Rect2i = Rect2i(-41, -45, 83, 81)

var _body: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _label: Label3D
var _suit: StandardMaterial3D
var _marker: StandardMaterial3D
var _age: float = 0.0
var _hit_time: float = 0.0
var _navigation: AStarGrid2D
var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _repath_time: float = 0.0
var _last_destination: Vector3 = Vector3.INF
var _last_position: Vector3 = Vector3.ZERO
var _stuck_time: float = 0.0
var _death_tween: Tween


func setup(mission_kind: String, label: String) -> void:
	kind = mission_kind
	target_name = label if not label.is_empty() else "任务目标"
	capture_mode = mission_kind in ["capture", "kidnap", "abduct", "abduction", "kidnapping", "hostage", "绑架"]
	add_to_group("actors")
	add_to_group("damageables")
	add_to_group("mission_targets")
	name = "MissionTarget"
	if is_instance_valid(_label):
		_update_label()


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(45.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.33
	capsule.height = 1.82
	collision.shape = capsule
	collision.position.y = 0.91
	add_child(collision)
	_build_character()
	_update_label()
	_last_position = global_position


func capture(player: Node3D) -> bool:
	if not alive or not capture_mode or captured or not is_instance_valid(player):
		return false
	if global_position.distance_to(player.global_position) > 3.2:
		return false
	if not _clear_sight(player.global_position):
		return false
	captured = true
	active = true
	follow_target = player
	_path.clear()
	_repath_time = 0.0
	_marker.albedo_color = Color("74ffd0")
	_marker.emission = Color("74ffd0")
	_update_label()
	return true


func apply_damage(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	_hit_time = 0.13
	_suit.emission_enabled = true
	_suit.emission = Color("873d35")
	_suit.emission_energy_multiplier = 0.75
	if health > 0.0:
		return
	alive = false
	active = false
	velocity = Vector3.ZERO
	collision_layer = 0
	remove_from_group("damageables")
	_update_label()
	_death_tween = create_tween()
	_death_tween.set_parallel(true)
	_death_tween.tween_property(_body, "rotation:x", -PI * 0.5, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_death_tween.tween_property(_body, "position:y", 0.18, 0.42)
	_death_tween.tween_property(_left_arm, "rotation:z", -0.42, 0.4)
	_death_tween.tween_property(_right_arm, "rotation:z", 0.5, 0.4)
	_death_tween.chain().tween_callback(func() -> void: _suit.emission_enabled = false)
	eliminated.emit(self)


func _physics_process(delta: float) -> void:
	if not alive or not active:
		velocity = Vector3.ZERO
		return
	_age += delta
	_hit_time = maxf(0.0, _hit_time - delta)
	_suit.emission_enabled = _hit_time > 0.0
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	if not captured or not is_instance_valid(follow_target):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_animate(false, delta)
		return
	var follower_position: Vector3 = follow_target.global_position
	var separation: Vector3 = follower_position - global_position
	separation.y = 0.0
	if separation.length() <= FOLLOW_DISTANCE and _clear_sight(follower_position):
		velocity.x = move_toward(velocity.x, 0.0, delta * 22.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 22.0)
		_stuck_time = 0.0
	else:
		if _navigation == null:
			_build_navigation()
		_repath_time -= delta
		if _repath_time <= 0.0 and (_path.is_empty() or follower_position.distance_to(_last_destination) > 0.9 or _stuck_time > 0.7):
			if _stuck_time > 0.7:
				# Reinforcements may introduce parked vehicles after capture.
				_build_navigation()
			_find_path(follower_position)
			_repath_time = 0.6
		var destination: Vector3 = _next_waypoint(follower_position)
		var direction: Vector3 = destination - global_position
		direction.y = 0.0
		if direction.length_squared() > 0.015:
			direction = direction.normalized()
			var speed: float = FOLLOW_SPEED if separation.length() > 3.6 else 3.1
			velocity.x = move_toward(velocity.x, direction.x * speed, delta * 20.0)
			velocity.z = move_toward(velocity.z, direction.z * speed, delta * 20.0)
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(delta * 9.0, 1.0))
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	move_and_slide()
	var moved: Vector3 = global_position - _last_position
	moved.y = 0.0
	var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.35
	if moving and moved.length() < delta * 0.15:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	_last_position = global_position
	_animate(moving, delta)


func _build_navigation() -> void:
	_navigation = AStarGrid2D.new()
	_navigation.region = GRID_RECT
	_navigation.cell_size = Vector2.ONE
	_navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_navigation.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_navigation.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_navigation.update()
	var probe: CapsuleShape3D = CapsuleShape3D.new()
	probe.radius = 0.43
	probe.height = 1.6
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = 1
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for z: int in range(GRID_RECT.position.y, GRID_RECT.end.y):
		for x: int in range(GRID_RECT.position.x, GRID_RECT.end.x):
			var cell: Vector2i = Vector2i(x, z)
			# Feet are above the low floor/ramp; furniture and walls remain blockers.
			query.transform = Transform3D(Basis.IDENTITY, Vector3(float(x), 1.05, float(z)))
			var blocked: bool = not space.intersect_shape(query, 1).is_empty()
			_navigation.set_point_solid(cell, blocked)
			if not blocked:
				# Prefer the clear axis through z=-28.5 and z=-12 over side furniture.
				var center_bias: float = 0.055 if z < -11 and z > -29 else 0.008
				_navigation.set_point_weight_scale(cell, 1.0 + absf(float(x)) * center_bias)


func _nearest_open(position_value: Vector3) -> Vector2i:
	var origin: Vector2i = Vector2i(roundi(position_value.x), roundi(position_value.z))
	origin.x = clampi(origin.x, GRID_RECT.position.x, GRID_RECT.end.x - 1)
	origin.y = clampi(origin.y, GRID_RECT.position.y, GRID_RECT.end.y - 1)
	if not _navigation.is_point_solid(origin):
		return origin
	var nearest: Vector2i = origin
	var best_distance: float = INF
	for radius: int in range(1, 6):
		for z: int in range(origin.y - radius, origin.y + radius + 1):
			for x: int in range(origin.x - radius, origin.x + radius + 1):
				var cell: Vector2i = Vector2i(x, z)
				if not GRID_RECT.has_point(cell) or _navigation.is_point_solid(cell):
					continue
				var distance: float = Vector2(float(x) - position_value.x, float(z) - position_value.z).length_squared()
				if distance < best_distance:
					best_distance = distance
					nearest = cell
		if best_distance < INF:
			break
	return nearest


func _find_path(destination: Vector3) -> void:
	_path.clear()
	_path_index = 0
	_last_destination = destination
	_stuck_time = 0.0
	var origin_cell: Vector2i = _nearest_open(global_position)
	var target_cell: Vector2i = _nearest_open(destination)
	if _navigation.is_point_solid(origin_cell) or _navigation.is_point_solid(target_cell):
		return
	var cells: Array[Vector2i] = _navigation.get_id_path(origin_cell, target_cell, false)
	for cell: Vector2i in cells:
		_path.append(Vector3(float(cell.x), global_position.y, float(cell.y)))


func _next_waypoint(destination: Vector3) -> Vector3:
	while _path_index < _path.size():
		var offset: Vector3 = _path[_path_index] - global_position
		offset.y = 0.0
		if offset.length() > 0.28:
			return _path[_path_index]
		_path_index += 1
	if _clear_sight(destination):
		return destination
	_repath_time = 0.0
	_path.clear()
	return global_position


func _clear_sight(destination: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var from: Vector3 = global_position + Vector3.UP * 1.1
	var to: Vector3 = destination + Vector3.UP * 1.1
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _animate(moving: bool, delta: float) -> void:
	var step: float = sin(_age * 10.5) * (0.38 if moving else 0.0)
	_left_leg.rotation.x = lerpf(_left_leg.rotation.x, step, minf(delta * 16.0, 1.0))
	_right_leg.rotation.x = lerpf(_right_leg.rotation.x, -step, minf(delta * 16.0, 1.0))
	_body.position.y = absf(sin(_age * 10.5)) * 0.024 if moving else sin(_age * 1.7) * 0.005
	if captured:
		_left_arm.rotation = _left_arm.rotation.lerp(Vector3(-0.88, -0.22, -0.3), minf(delta * 6.0, 1.0))
		_right_arm.rotation = _right_arm.rotation.lerp(Vector3(-0.88, 0.22, 0.3), minf(delta * 6.0, 1.0))
	else:
		_left_arm.rotation.x = sin(_age * 1.6) * 0.025
		_right_arm.rotation.x = -_left_arm.rotation.x


func _update_label() -> void:
	if not is_instance_valid(_label):
		return
	if not alive:
		_label.text = target_name + "\n目标已倒地"
		_label.modulate = Color("a2adb5")
	elif captured:
		_label.text = target_name + "\n已控制 · 跟随 91"
		_label.modulate = Color("92ffd4")
	else:
		_label.text = target_name + ("\n绑架目标" if capture_mode else "暗杀目标")
		_label.modulate = Color("ffe0a4")


func _build_character() -> void:
	var human := preload("res://scripts/human_visual.gd").new()
	var parts: Dictionary = human.build(self,"target",1 if capture_mode else 3)
	_body = parts.body
	_left_leg = parts.left_leg
	_right_leg = parts.right_leg
	_left_arm = parts.left_arm
	_right_arm = parts.right_arm
	_suit = parts.cloth
	_marker = parts.accent
	_label = Label3D.new()
	_label.name = "TargetName"
	_label.position.y = 2.0
	_label.font_size = 28
	_label.pixel_size = 0.003
	_label.outline_size = 5
	_label.outline_modulate = Color("132129")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font = preload("res://assets/fonts/NotoSansSC.ttf")
	add_child(_label)


func _limb(parent: Node3D, at: Vector3) -> Node3D:
	var limb: Node3D = Node3D.new()
	limb.position = at
	parent.add_child(limb)
	return limb


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _box(parent: Node3D, dimensions: Vector3, at: Vector3, material: Material, angles: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var cube: BoxMesh = BoxMesh.new()
	cube.size = dimensions
	mesh.mesh = cube
	mesh.material_override = material
	mesh.position = at
	mesh.rotation = angles
	parent.add_child(mesh)
	return mesh


func _sphere(parent: Node3D, dimensions: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	mesh.mesh = sphere
	mesh.scale = dimensions
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh
