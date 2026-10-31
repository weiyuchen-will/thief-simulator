extends CharacterBody3D

signal eliminated(actor)
signal attack(origin: Vector3, destination: Vector3, is_enemy: bool)

var is_enemy: bool = true
var actor_index: int = 0
var target: Node3D
var destination: Vector3 = Vector3.ZERO
var active: bool = false
var health: float = 100.0
var alive: bool = true
var cooldown: float = 1.5
var age: float = 0.0
var body: Node3D
var left_leg: Node3D
var right_leg: Node3D
var flash: MeshInstance3D
var flash_time: float = 0.0
var normal_material: StandardMaterial3D
var hit_time: float = 0.0
var current_goal: Vector3

func setup(enemy: bool, index: int) -> void:
	is_enemy = enemy
	actor_index = index
	health = 90.0 if enemy else 10000.0
	cooldown = 1.4 + float(index % 5) * 0.35
	add_to_group("enemies" if enemy else "allies")
	add_to_group("actors")
	name = ("Response_" if enemy else "Crew_") + str(index)

func _ready() -> void:
	collision_layer = 2 if is_enemy else 4
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.85
	shape.shape = capsule
	shape.position.y = 0.925
	add_child(shape)
	var human := preload("res://scripts/human_visual.gd").new()
	var parts: Dictionary = human.build(self,"police" if is_enemy else "ally",actor_index)
	body = parts.body
	left_leg = parts.left_leg
	right_leg = parts.right_leg
	normal_material = parts.cloth
	var dark := _mat(Color("11171c"))
	_box(body, Vector3(0.13,1.13,-0.42), Vector3(0.085,0.11,0.38), dark)
	_box(body, Vector3(0.13,1.13,-0.69), Vector3(0.025,0.032,0.25), dark)
	_box(body, Vector3(0.13,1.015,-0.37), Vector3(0.07,0.19,0.085), dark)
	_box(body, Vector3(0.13,1.21,-0.36), Vector3(0.064,0.04,0.10), dark)
	flash = _box(body, Vector3(0.13,1.13,-0.84), Vector3(0.13,0.13,0.19), _mat(Color("ffd58b"),0.0,true))
	flash.visible = false
	if not is_enemy:
		var label := Label3D.new()
		label.text = "GHOST / 幽灵" if actor_index == 0 else "ROOK / 白鸦"
		label.position.y = 2.10
		label.font = preload("res://assets/fonts/NotoSansSC.ttf")
		label.font_size = 28
		label.pixel_size = 0.004
		label.modulate = Color("bfffd9")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	age += delta
	flash_time = maxf(0.0,flash_time-delta)
	flash.visible = flash_time > 0
	if not active:
		return
	if not is_on_floor():
		velocity.y -= 18.0*delta
	var goal := destination
	var has_target := is_instance_valid(target)
	var can_fire := false
	var distance := 999.0
	if has_target:
		distance = global_position.distance_to(target.global_position)
		if is_enemy:
			goal = target.global_position
			# Route through the entrance instead of trying to cross exterior walls.
			if global_position.z > -11.0 and target.global_position.z < -14.0:
				goal = Vector3(clampf(global_position.x,-1.8,1.8),0,-14.5)
			elif global_position.z < -14.0 and target.global_position.z > -10.0:
				goal = Vector3(0,0,-8)
			elif global_position.z < -16.0 and global_position.z > -25.0:
				goal.x = clampf(goal.x,-2.0,2.0)
		var origin := global_position+Vector3(0,1.42,0)
		var end := target.global_position+Vector3(0,1.05,0)
		var query := PhysicsRayQueryParameters3D.create(origin,end,1)
		query.exclude = [get_rid()]
		can_fire = distance < (25.0 if is_enemy else 35.0) and get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	# Teammates also route through the central doorway during extraction.
	if not is_enemy:
		if global_position.z < -13.0 and goal.z > -10.0:
			goal = Vector3(clampf(global_position.x,-1.5,1.5),0,-8.0)
		elif global_position.z > -11.0 and goal.z < -14.0:
			goal = Vector3(clampf(goal.x,-1.5,1.5),0,-15.0)
	var direction := goal-global_position
	direction.y = 0
	var speed := 2.6 if is_enemy else 4.4
	if direction.length() > 0.8 and not (is_enemy and can_fire and distance<11.0):
		direction = direction.normalized()
		velocity.x = direction.x*speed
		velocity.z = direction.z*speed
	else:
		velocity.x = move_toward(velocity.x,0,delta*10)
		velocity.z = move_toward(velocity.z,0,delta*10)
	move_and_slide()
	var face := (target.global_position-global_position) if has_target and can_fire else direction
	if face.length_squared() > 0.1:
		rotation.y = lerp_angle(rotation.y,atan2(-face.x,-face.z),delta*7)
	var moving := Vector2(velocity.x,velocity.z).length() > 0.4
	left_leg.rotation.x = sin(age*11)*0.45 if moving else 0.0
	right_leg.rotation.x = -left_leg.rotation.x
	body.position.y = absf(sin(age*11))*0.035 if moving else 0.0
	cooldown -= delta
	if can_fire and cooldown <= 0.0:
		cooldown = (1.1+randf()*1.4) if is_enemy else (0.6+randf()*0.7)
		flash_time = 0.07
		attack.emit(global_position+Vector3(0,1.4,0),target.global_position+Vector3(0,1.1,0),is_enemy)
		if not is_enemy and target.has_method("apply_damage"):
			target.apply_damage(8.0)

func apply_damage(amount: float) -> void:
	if not alive or not is_enemy:
		return
	health -= amount
	body.position.z = 0.09
	var recoil_tween := create_tween()
	recoil_tween.tween_property(body,"position:z",0.0,0.12)
	if health <= 0:
		alive = false
		active = false
		collision_layer = 0
		remove_from_group("enemies")
		flash.visible = false
		eliminated.emit(self)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(body,"rotation:x",-PI/2,0.32).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(body,"position:y",0.15,0.32)
		tween.chain().tween_interval(12.0)
		tween.chain().tween_property(body,"scale",Vector3.ZERO,0.5)
		tween.chain().tween_callback(queue_free)

func _mat(color: Color,metallic: float=0.0,emissive: bool=false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.65
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.8
	return material

func _box(parent: Node3D,pos: Vector3,size: Vector3,material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)
	return mesh
