extends Node3D
## A hand-built, procedural city block. All materials and geometry are local.

var _materials: Dictionary = {}
var _intro_vehicle: Node3D
var _built := false
var _alarm_active := false
var _siren_time := 0.0
var _police_vehicles: Array[Node3D] = []
var _siren_pairs: Array[Dictionary] = []
var location: String = "bank"

func _ready() -> void:
	build_world()

func build_world() -> void:
	if _built:
		return
	_built = true
	_make_materials()
	_build_ground()
	if location == "bank":
		_build_bank()
	else:
		_build_mission_building(location=="home")
	_build_entrance_ramp()
	_build_city()
	_build_street_details()
	_batch_static_boxes()
	_intro_vehicle = _build_van(Vector3(0, 0, 11), Color("162e36"))
	_intro_vehicle.name = "EscapeVan"
	set_process(false)

func get_intro_vehicle() -> Node3D:
	return _intro_vehicle

func get_escape_position() -> Vector3:
	return Vector3(2.2, 0, 11.8)

func _build_mission_building(house: bool) -> void:
	_material("res_wall",Color("ab9d89") if house else Color("263447"))
	_material("res_floor",Color("685047") if house else Color("34414e"),0.46)
	_material("fabric",Color("426158") if house else Color("462e49"))
	_material("book_red",Color("975b4d"))
	_material("book_blue",Color("657785"))
	_material("art",Color("b2ab87"))
	_box(Vector3(27,0.26,25),Vector3(0,-0.055,-24),"res_floor",true)
	for side in [-1.0,1.0]:
		_box(Vector3(0.5,5.8,24.5),Vector3(side*13.3,2.9,-24),"res_wall",true)
		_box(Vector3(9.8,5.8,0.45),Vector3(side*8.2,2.9,-12),"res_wall",true)
		for x in [5.2,10.3]:
			_box(Vector3(3.4,2.8,0.06),Vector3(side*x,3.1,-11.75),"glass_black")
			_box(Vector3(3.55,0.12,0.18),Vector3(side*x,1.67,-11.72),"trim")
			_box(Vector3(0.08,2.8,0.09),Vector3(side*x,3.1,-11.7),"trim")
		_box(Vector3(0.24,4.9,0.24),Vector3(side*3.2,2.45,-10.5),"wood" if house else "trim",true)
		_box(Vector3(0.06,3.8,0.04),Vector3(side*3.0,2.3,-11.71),"warm" if house else "teal_light")
		_build_pot(Vector3(side*4,0.08,-10),0.55)
	_box(Vector3(27,5.8,0.5),Vector3(0,2.9,-36),"res_wall",true)
	_box(Vector3(28,0.3,25),Vector3(0,5.9,-24),"wood" if house else "charcoal")
	_box(Vector3(7.4,0.23,3.4),Vector3(0,4.9,-10.8),"charcoal")
	_box(Vector3(7.1,0.025,3.0),Vector3(0,4.76,-10.8),"warm")
	_label("CEDAR HOUSE" if house else "OBSIDIAN / CLUB",Vector3(0,5.46,-11.72),65,0.012,Color("e5d0a8") if house else Color("8de6e0"))
	_label("PRIVATE RESIDENCE" if house else "MEMBERS ONLY",Vector3(0,4.4,-11.67),28,0.011,Color("c3c8ba"))
	if house:
		for side in [-1.0,1.0]:
			var roof := _box(Vector3(14.6,0.25,26),Vector3(side*7.1,6.6,-24),"wood")
			roof.rotation.z = side*-0.13
		_box(Vector3(1.6,3,1.4),Vector3(8,6.6,-30),"stone")
		# A furnished living room, kitchen and bedroom with a clear central route.
		_sofa(Vector3(-7,0.08,-18),"fabric")
		_box(Vector3(4.2,0.03,5.0),Vector3(-7,0.096,-20),"art")
		_box(Vector3(2.3,0.13,1.2),Vector3(-7,0.64,-20),"wood",true)
		_box(Vector3(2.8,1.45,0.09),Vector3(-12.96,2.35,-19),"glass_black").rotation.y=PI/2
		_box(Vector3(4.0,0.16,2.2),Vector3(7,1.05,-19),"wood",true)
		for dx in [-1.35,1.35]:
			for dz in [-1.7,1.7]:
				_box(Vector3(0.6,0.9,0.6),Vector3(7+dx,0.53,-19+dz),"fabric",true)
		_box(Vector3(4.3,1.1,1.1),Vector3(9.8,0.63,-25),"stone",true)
		_box(Vector3(4.4,0.13,1.25),Vector3(9.8,1.24,-25),"dark_marble")
		_box(Vector3(3.1,0.55,4.0),Vector3(9,0.43,-31.5),"wood",true)
		_box(Vector3(3.1,0.26,3.9),Vector3(9,0.84,-31.5),"paper")
		_box(Vector3(2.9,0.15,2.4),Vector3(9,1.05,-30.9),"fabric")
		for x in [8.25,9.75]: _box(Vector3(1.05,0.18,0.7),Vector3(x,1.1,-33),"art")
		for x in [-9.5,-6.5]: _bookshelf(Vector3(x,0.1,-35.2))
		_label("STUDY",Vector3(0,3.9,-28.9),45,0.013,Color("e6d4b2"))
	else:
		# A different blue-lit lounge with bar, private office and server cabinets.
		_sofa(Vector3(-8,0.08,-18),"fabric")
		_sofa(Vector3(8,0.08,-18),"fabric")
		for side in [-1.0,1.0]:
			_box(Vector3(4.0,0.15,1.3),Vector3(side*8,0.76,-21),"glass",true)
			for z in [-16,-20,-24]:
				_box(Vector3(0.03,3.0,0.075),Vector3(side*12.99,2.3,z),"teal_light")
		_box(Vector3(5.7,1.3,1.5),Vector3(-8.7,0.73,-25),"charcoal",true)
		for x in [-10.5,-9.5,-8.5,-7.5]: _cylinder(0.095,0.35,Vector3(x,1.56,-25),"glass")
		for x in [-10,-7,7,10]:
			_box(Vector3(1.7,3.4,1.0),Vector3(x,1.79,-34.7),"charcoal",true)
			for y in [0.7,1.2,1.7,2.2,2.7]:
				_box(Vector3(1.4,0.025,0.03),Vector3(x,y,-34.18),"teal_light")
		_box(Vector3(4.6,0.14,1.9),Vector3(6.5,1.17,-31.6),"wood",true)
		_box(Vector3(1.2,0.72,0.07),Vector3(6.5,1.69,-31.9),"teal_light")
		_label("PRIVATE OFFICE",Vector3(0,4.0,-28.8),48,0.012,Color("80dece"))
	# Partitioned back rooms use a wide central opening, no doors or narrow steps.
	for side in [-1.0,1.0]:
		_box(Vector3(9.7,4.4,0.3),Vector3(side*8.05,2.2,-28.5),"res_wall",true)
		_box(Vector3(4.4,2.3,0.04),Vector3(side*8,2.3,-28.3),"art" if house else "glass_black")
		for x in [-1.5,0,1.5]:
			_box(Vector3(0.06,2.3,0.065),Vector3(side*8+x,2.3,-28.25),"trim")
	for z in [-16,-23,-32]:
		_box(Vector3(3.6,0.09,0.12),Vector3(0,5.55,z),"warm" if house else "teal_light")
		_light(Vector3(0,4.8,z),Color("ffdfaf") if house else Color("a7d9e7"),1.9,12)
	_light(Vector3(0,3.8,-10),Color("ffdfa2"),1.8,8)

func _sofa(pos: Vector3,mat: String) -> void:
	_box(Vector3(4.3,0.65,1.4),pos+Vector3(0,0.48,0),mat,true)
	_box(Vector3(4.3,0.9,0.3),pos+Vector3(0,1.0,-0.66),mat,true)
	for x in [-2.0,2.0]: _box(Vector3(0.4,0.8,1.6),pos+Vector3(x,0.75,0),mat,true)
	for x in [-1.25,0,1.25]: _box(Vector3(1.1,0.13,1.12),pos+Vector3(x,0.87,0),"paper")

func _bookshelf(pos: Vector3) -> void:
	_box(Vector3(2.7,3.3,0.3),pos+Vector3(0,1.65,0),"wood")
	for y in [0.2,1.1,2.0,2.9]:
		_box(Vector3(2.7,0.1,0.8),pos+Vector3(0,y,0.3),"wood")
		for i in 8:
			_box(Vector3(0.16,0.55+float(i%3)*0.1,0.42),pos+Vector3(-1.05+i*0.29,y+0.33,0.3),"book_red" if i%2==0 else "book_blue")

func set_alarm(active: bool) -> void:
	if not _built:
		build_world()
	if active and _police_vehicles.is_empty():
		_build_police_vehicles()
	_alarm_active = active
	_siren_time = 0.0
	for vehicle in _police_vehicles:
		vehicle.visible = active
		for candidate in vehicle.find_children("*", "StaticBody3D", true, false):
			var body := candidate as StaticBody3D
			body.collision_layer = 1 if active else 0
			body.collision_mask = 1 if active else 0
	_update_sirens()
	set_process(active)

func _process(delta: float) -> void:
	_siren_time += delta
	_update_sirens()

func _update_sirens() -> void:
	for pair in _siren_pairs:
		var red_on: bool = _alarm_active and (int(_siren_time * 8.0) + int(pair["offset"])) % 4 < 2
		var blue_on: bool = _alarm_active and not red_on
		pair["red"].visible = red_on
		pair["blue"].visible = blue_on
		pair["red_light"].light_energy = 2.1 if red_on else 0.0
		pair["blue_light"].light_energy = 2.1 if blue_on else 0.0

func _build_entrance_ramp() -> void:
	# The plaza is a visual paving layer above the continuous road collider.
	# This broad, gentle wedge lifts capsule feet before the raised lobby lip.
	var body := StaticBody3D.new()
	body.name = "EntranceAccessibilityRamp"
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(-3.0, -0.20, -9.9), Vector3(3.0, -0.20, -9.9),
		Vector3(-3.0, -0.041, -9.9), Vector3(3.0, -0.041, -9.9),
		Vector3(-3.0, -0.20, -11.6), Vector3(3.0, -0.20, -11.6),
		Vector3(-3.0, 0.084, -11.6), Vector3(3.0, 0.084, -11.6)
	])
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _build_police_vehicles() -> void:
	_material("police_paint", Color("111f29"), 0.28, 0.6)
	_material("police_white", Color("d5e1e2"), 0.43, 0.4)
	for index in range(2):
		var side: float = -1.0 if index == 0 else 1.0
		var vehicle := _build_car(Vector3(side * 9.0, 0, 8.0), side * -0.24, "police_paint")
		vehicle.name = "PoliceInterceptor" + str(index + 1)
		_police_vehicles.append(vehicle)
		_box(Vector3(1.5, 0.11, 0.51), Vector3(0, 1.98, 0.28), "charcoal", false, vehicle)
		_box(Vector3(0.64, 0.19, 0.42), Vector3(-0.40, 2.095, 0.28), "glass_black", false, vehicle)
		_box(Vector3(0.64, 0.19, 0.42), Vector3(0.40, 2.095, 0.28), "glass_black", false, vehicle)
		var red_lens := _box(Vector3(0.59, 0.16, 0.43), Vector3(-0.40, 2.105, 0.28), "red_light", false, vehicle)
		var blue_lens := _box(Vector3(0.59, 0.16, 0.43), Vector3(0.40, 2.105, 0.28), "blue_light", false, vehicle)
		var red_lamp := _light(Vector3(-0.45, 2.3, 0.28), Color("ff293f"), 0.0, 6.5, vehicle)
		var blue_lamp := _light(Vector3(0.45, 2.3, 0.28), Color("358dff"), 0.0, 6.5, vehicle)
		_siren_pairs.append({"red": red_lens, "blue": blue_lens, "red_light": red_lamp, "blue_light": blue_lamp, "offset": index * 2})
		for door_side in [-1.0, 1.0]:
			_box(Vector3(0.03, 0.48, 1.90), Vector3(door_side * 0.94, 0.92, 0.25), "police_white", false, vehicle)
			var sign := _label("POLICE", Vector3(door_side * 0.963, 0.94, 0.24), 52, 0.006, Color("162837"), vehicle)
			sign.rotation.y = door_side * PI * 0.5
		_box(Vector3(1.02, 0.12, 0.055), Vector3(0, 0.88, -2.13), "charcoal", false, vehicle)
		for guard_x in [-0.55, 0.55]:
			_box(Vector3(0.09, 0.58, 0.095), Vector3(guard_x, 0.82, -2.14), "charcoal", false, vehicle)

func _batch_static_boxes() -> void:
	# One instanced draw per material keeps the detailed skyline inexpensive on
	# integrated GPUs. Physics remains on independent, normally sized colliders.
	var groups: Dictionary = {}
	for candidate in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if not mesh_instance.mesh is BoxMesh:
			continue
		var box_mesh := mesh_instance.mesh as BoxMesh
		var material := mesh_instance.material_override
		var key: int = material.get_instance_id()
		if not groups.has(key):
			groups[key] = {"material": material, "transforms": []}
		var original_transform := _relative_transform(mesh_instance)
		var local_transform := original_transform
		local_transform.basis = local_transform.basis * Basis.from_scale(box_mesh.size)
		groups[key]["transforms"].append(local_transform)
		for child in mesh_instance.get_children():
			if child is StaticBody3D:
				var body_transform: Transform3D = original_transform * child.transform
				child.reparent(self, false)
				child.transform = body_transform
		mesh_instance.free()
	for key in groups:
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		var unit_box := BoxMesh.new()
		unit_box.size = Vector3.ONE
		instances.mesh = unit_box
		instances.instance_count = groups[key]["transforms"].size()
		for index in range(instances.instance_count):
			instances.set_instance_transform(index, groups[key]["transforms"][index])
		var batch := MultiMeshInstance3D.new()
		batch.name = "ArchitectureBatch"
		batch.multimesh = instances
		batch.material_override = groups[key]["material"]
		add_child(batch)

func _relative_transform(node: Node3D) -> Transform3D:
	var result := node.transform
	var ancestor := node.get_parent()
	while ancestor != null and ancestor != self:
		if ancestor is Node3D:
			result = ancestor.transform * result
		ancestor = ancestor.get_parent()
	return result

func _material(key: String, color: Color, roughness: float = 0.65, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metal
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	_materials[key] = mat
	return mat

func _make_materials() -> void:
	_material("road", Color("17242b"), 0.94)
	_material("sidewalk", Color("657278"), 0.91)
	_material("seam", Color("39464d"), 0.92)
	_material("stone", Color("c0b6a2"), 0.69)
	_material("marble", Color("9c9990"), 0.23)
	_material("dark_marble", Color("263439"), 0.24)
	_material("charcoal", Color("1c2b32"), 0.6, 0.25)
	_material("slate", Color("34444c"), 0.72)
	_material("trim", Color("b69a62"), 0.31, 0.8)
	_material("gold", Color("f4bd4f"), 0.25, 0.85)
	_material("brass_dark", Color("675239"), 0.44, 0.6)
	_material("glass", Color("294a54"), 0.12, 0.65)
	_material("glass_black", Color("0f2630"), 0.14, 0.5)
	_material("warm", Color("ffd28b"), 0.43, 0.0, 3.0)
	_material("white_light", Color("daf8fa"), 0.3, 0.0, 3.0)
	_material("teal_light", Color("57dfca"), 0.45, 0.0, 2.5)
	_material("red_light", Color("ff3544"), 0.45, 0.0, 2.0)
	_material("blue_light", Color("4ca8f4"), 0.45, 0.0, 1.0)
	_material("lane", Color("d2cabc"), 0.8)
	_material("yellow_lane", Color("ccb773"), 0.8)
	_material("rubber", Color("11191c"), 0.95)
	_material("chrome", Color("77929a"), 0.27, 0.85)
	_material("wood", Color("684c38"), 0.61)
	_material("trunk", Color("514840"), 0.94)
	_material("leaves", Color("294c42"), 0.95)
	_material("leaves_lit", Color("3b6855"), 0.95)
	_material("paper", Color("a0b59b"), 0.94)
	_material("tire_mark", Color("101c23"), 0.93)
	_material("car_blue", Color("325264"), 0.25, 0.6)
	_material("car_silver", Color("7c8c8e"), 0.3, 0.66)

func _box(size: Vector3, position_value: Vector3, mat: String, solid: bool = false, holder: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = _materials[mat]
	instance.position = position_value
	var target: Node3D = self if holder == null else holder
	target.add_child(instance)
	if solid:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
		instance.add_child(body)
	return instance

func _cylinder(radius: float, height: float, position_value: Vector3, mat: String, holder: Node3D = null, top_radius: float = -1.0, sides: int = 16) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = sides
	instance.mesh = mesh
	instance.material_override = _materials[mat]
	instance.position = position_value
	var target: Node3D = self if holder == null else holder
	target.add_child(instance)
	return instance

func _sphere(radius: float, position_value: Vector3, mat: String, holder: Node3D = null, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	instance.mesh = mesh
	instance.material_override = _materials[mat]
	instance.position = position_value
	instance.scale = scale_value
	var target: Node3D = self if holder == null else holder
	target.add_child(instance)
	return instance

func _label(text_value: String, position_value: Vector3, font_size: int, pixel_size: float, color: Color, holder: Node3D = null) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.shaded = false
	label.position = position_value
	var target: Node3D = self if holder == null else holder
	target.add_child(label)
	return label

func _light(position_value: Vector3, color: Color, energy: float, radius: float, holder: Node3D = null) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.position = position_value
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = radius
	lamp.omni_attenuation = 1.45
	lamp.shadow_enabled = false
	var target: Node3D = self if holder == null else holder
	target.add_child(lamp)
	return lamp

func _build_ground() -> void:
	_box(Vector3(180, 0.4, 155), Vector3(0, -0.24, -5), "road", true)
	_box(Vector3(74, 0.13, 16.0), Vector3(0, 0.005, -3.0), "sidewalk")
	_box(Vector3(74, 0.14, 0.25), Vector3(0, 0.01, 5.05), "stone")
	_box(Vector3(74, 0.13, 10), Vector3(0, 0.005, 23.0), "sidewalk")
	_box(Vector3(74, 0.14, 0.25), Vector3(0, 0.01, 18.0), "stone")
	# Narrow joints keep the paving legible at both first-person and cinematic scales.
	for x in range(-36, 37, 4):
		_box(Vector3(0.025, 0.006, 16), Vector3(x, 0.074, -3), "seam")
	for z in range(-11, 6, 4):
		_box(Vector3(74, 0.006, 0.025), Vector3(0, 0.074, z), "seam")
	for x in range(-42, 44, 6):
		_box(Vector3(3.5, 0.012, 0.13), Vector3(x, -0.022, 11.5), "lane")
	_box(Vector3(91, 0.012, 0.09), Vector3(0, -0.022, 6.0), "yellow_lane")
	_box(Vector3(91, 0.012, 0.09), Vector3(0, -0.022, 17.2), "yellow_lane")
	# A crossing to the right of the bank breaks up the long road.
	for z in range(7, 18, 2):
		_box(Vector3(4.0, 0.014, 0.85), Vector3(20, -0.019, z), "lane")
	for x in [-31.0, -19.0, 19.0, 31.0]:
		_box(Vector3(1.0, 0.017, 0.38), Vector3(x, -0.018, 5.5), "charcoal")
		for offset in [-0.3, -0.1, 0.1, 0.3]:
			_box(Vector3(0.04, 0.02, 0.30), Vector3(x + offset, -0.006, 5.5), "chrome")
	# Perimeter barriers prevent falling out of the authored play space.
	_box(Vector3(1, 4, 85), Vector3(-42, 2, -6), "charcoal", true)
	_box(Vector3(1, 4, 85), Vector3(42, 2, -6), "charcoal", true)
	_box(Vector3(84, 4, 1), Vector3(0, 2, 35), "charcoal", true)
	_box(Vector3(84, 4, 1), Vector3(0, 2, -46), "charcoal", true)

func _build_bank() -> void:
	# Pale stone on a charcoal plinth, with a copper framed, triple-height lobby.
	_box(Vector3(27, 0.26, 25), Vector3(0, -0.055, -24), "marble", true)
	_box(Vector3(0.60, 9, 24), Vector3(-13.3, 4.5, -24), "stone", true)
	_box(Vector3(0.60, 9, 24), Vector3(13.3, 4.5, -24), "stone", true)
	_box(Vector3(27.2, 9, 0.6), Vector3(0, 4.5, -36), "stone", true)
	_box(Vector3(28.6, 0.8, 25.2), Vector3(0, 9.3, -23.75), "charcoal", true)
	_box(Vector3(29.0, 0.24, 1.7), Vector3(0, 9.75, -11.25), "trim")
	_box(Vector3(28.2, 1.65, 1.15), Vector3(0, 7.7, -11.65), "charcoal", true)
	_box(Vector3(28.4, 0.11, 1.18), Vector3(0, 6.86, -11.58), "trim")
	_label("A U R E L", Vector3(0, 7.85, -11.04), 100, 0.016, Color("efd9aa"))
	_label("P R I V A T E   B A N K", Vector3(0, 7.13, -11.025), 42, 0.01, Color("c3c9c7"))
	# Frontage glazing is opaque reflection glass with vertical lit fins.
	for side in [-1.0, 1.0]:
		_box(Vector3(9.45, 5.8, 0.16), Vector3(side * 8.14, 3.65, -11.93), "glass", true)
		_box(Vector3(9.5, 0.55, 0.55), Vector3(side * 8.15, 0.40, -11.72), "charcoal", true)
		_box(Vector3(9.5, 0.13, 0.21), Vector3(side * 8.15, 3.55, -11.78), "trim")
		for x_index in range(5):
			var fin_x: float = side * (3.42 + x_index * 2.34)
			_box(Vector3(0.12, 6.1, 0.46), Vector3(fin_x, 3.6, -11.65), "trim")
			_box(Vector3(0.025, 5.2, 0.03), Vector3(fin_x + side * 0.07, 3.8, -11.405), "warm")
		# The continuous warm entrance canopy is visible from the van.
		_box(Vector3(0.25, 6.1, 0.9), Vector3(side * 3.20, 3.25, -11.55), "charcoal", true)
		_box(Vector3(0.08, 5.8, 0.07), Vector3(side * 3.03, 3.15, -11.04), "warm")
	_box(Vector3(7.1, 0.25, 3.3), Vector3(0, 5.93, -10.67), "charcoal", true)
	_box(Vector3(6.8, 0.03, 2.9), Vector3(0, 5.78, -10.64), "warm")
	_box(Vector3(6.4, 0.09, 0.22), Vector3(0, 0.13, -11.20), "trim")
	# Fully open central entrance; the leaves sit against the jambs.
	for side in [-1.0, 1.0]:
		var leaf := _box(Vector3(0.10, 3.9, 1.8), Vector3(side * 2.94, 2.03, -12.67), "glass")
		leaf.rotation.y = side * 0.11
		_box(Vector3(0.12, 0.75, 0.045), Vector3(side * 2.81, 1.85, -11.93), "trim")
	# Lobby floor inlays form a quiet axis from the street to the vault.
	_box(Vector3(4.7, 0.014, 22.8), Vector3(0, 0.083, -23.0), "dark_marble")
	for side in [-1.0, 1.0]:
		_box(Vector3(0.065, 0.018, 22.8), Vector3(side * 2.38, 0.087, -23), "trim")
	for z in [-16.0, -20.0, -24.0, -28.0]:
		_box(Vector3(25.8, 0.015, 0.028), Vector3(0, 0.085, z), "brass_dark")
	for x in [-8.0, -4.0, 4.0, 8.0]:
		_box(Vector3(0.025, 0.014, 22.0), Vector3(x, 0.084, -23), "brass_dark")
	# Interior walls with fluted wood and brushed metal baseboards.
	for side in [-1.0, 1.0]:
		_box(Vector3(0.1, 3.6, 22.7), Vector3(side * 12.94, 1.93, -24.0), "wood")
		_box(Vector3(0.14, 0.22, 22.7), Vector3(side * 12.89, 0.22, -24), "trim")
		for z in [-15.0, -19.0, -23.0, -27.0]:
			_box(Vector3(0.32, 6.0, 0.7), Vector3(side * 12.73, 3.2, z), "charcoal")
			_box(Vector3(0.035, 2.8, 0.12), Vector3(side * 12.54, 3.5, z), "warm")
		# Two chunky architectural columns also provide combat cover.
		for z in [-16.9, -24.0]:
			_box(Vector3(0.90, 8.7, 0.90), Vector3(side * 10.3, 4.45, z), "stone", true)
			_box(Vector3(1.02, 0.22, 1.02), Vector3(side * 10.3, 0.25, z), "trim")
			_box(Vector3(0.07, 6.0, 0.035), Vector3(side * 10.3, 4.1, z + 0.47), "warm")
		_build_counter(Vector3(side * 6.45, 0, -20.6))
		_build_bench(Vector3(side * 8.0, 0, -15.8), side * PI * 0.5)
		_build_pot(Vector3(side * 11.4, 0.1, -13.7), 0.56)
		_build_pot(Vector3(side * 11.5, 0.1, -28.7), 0.55)
	# Suspended square luminaires give the entry a recognizable overhead rhythm.
	for z in [-15.5, -22.2, -28.0]:
		for side in [-1.0, 1.0]:
			_box(Vector3(0.018, 1.15, 0.018), Vector3(side * 1.8, 8.35, z), "chrome")
			_box(Vector3(0.075, 0.11, 3.4), Vector3(side * 2.2, 7.8, z), "trim")
			_box(Vector3(0.050, 0.018, 3.2), Vector3(side * 2.2, 7.731, z), "warm")
		for direction in [-1.0, 1.0]:
			_box(Vector3(4.45, 0.11, 0.075), Vector3(0, 7.8, z + direction * 1.7), "trim")
			_box(Vector3(4.2, 0.018, 0.05), Vector3(0, 7.731, z + direction * 1.7), "warm")
		_light(Vector3(0, 5.9, z), Color("ffda9e"), 2.3, 12.5)
	_light(Vector3(0, 3.6, -10.4), Color("fbe0ba"), 1.5, 8)
	_build_vault()
	_build_atm(Vector3(11.9, 0, -9.0), -0.13)
	# A circular monogram inset below the entrance canopy.
	var emblem := _cylinder(0.92, 0.055, Vector3(0, 4.58, -12.02), "trim", null, -1.0, 32)
	emblem.rotation.x = PI * 0.5
	var emblem_inner := _cylinder(0.83, 0.065, Vector3(0, 4.58, -11.98), "charcoal", null, -1.0, 32)
	emblem_inner.rotation.x = PI * 0.5
	_label("A", Vector3(0, 4.57, -11.935), 100, 0.017, Color("f0d5a4"))

func _build_counter(position_value: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = position_value
	_box(Vector3(5.1, 1.18, 1.4), Vector3(0, 0.67, 0), "wood", true, root)
	_box(Vector3(5.32, 0.13, 1.62), Vector3(0, 1.325, 0), "dark_marble", false, root)
	_box(Vector3(4.96, 0.1, 0.025), Vector3(0, 0.23, 0.713), "trim", false, root)
	for i in range(11):
		_box(Vector3(0.033, 0.87, 0.025), Vector3(-2.35 + i * 0.47, 0.77, 0.711), "brass_dark", false, root)
	for x in [-1.35, 1.35]:
		_box(Vector3(0.65, 0.045, 0.45), Vector3(x, 1.416, 0), "charcoal", false, root)
		_box(Vector3(0.065, 0.28, 0.065), Vector3(x, 1.56, -0.1), "chrome", false, root)
		_box(Vector3(0.77, 0.48, 0.07), Vector3(x, 1.81, -0.10), "charcoal", false, root)
		_box(Vector3(0.68, 0.37, 0.013), Vector3(x, 1.81, -0.055), "teal_light", false, root)
		_box(Vector3(0.44, 0.025, 0.18), Vector3(x, 1.41, 0.41), "chrome", false, root)
		_box(Vector3(0.38, 0.015, 0.3), Vector3(x + 0.77, 1.41, 0.18), "paper", false, root)
		_box(Vector3(0.5, 0.09, 0.5), Vector3(x, 0.71, -1.21), "charcoal", false, root)
		_box(Vector3(0.5, 0.53, 0.08), Vector3(x, 0.99, -1.46), "charcoal", false, root)
		_cylinder(0.08, 0.60, Vector3(x, 0.38, -1.21), "chrome", root)

func _build_vault() -> void:
	# Central opening is three metres wide. The two side wings hide deposit rooms.
	for side in [-1.0, 1.0]:
		_box(Vector3(10.0, 6.8, 0.65), Vector3(side * 7.7, 3.48, -29.0), "dark_marble", true)
		_box(Vector3(9.7, 0.06, 0.04), Vector3(side * 7.7, 4.86, -28.65), "trim")
		_box(Vector3(0.25, 4.4, 0.85), Vector3(side * 2.82, 2.3, -29.0), "trim", true)
		_label("PRIVATE  CLIENTS" if side < 0 else "DEPOSIT  SERVICES", Vector3(side * 7.0, 3.9, -28.65), 45, 0.009, Color("e2d2b5"))
	_box(Vector3(5.8, 2.2, 0.85), Vector3(0, 5.8, -29.0), "charcoal", true)
	_box(Vector3(5.8, 0.19, 0.85), Vector3(0, 4.59, -29), "trim")
	_label("THE  RESERVE", Vector3(0, 5.5, -28.535), 54, 0.011, Color("e8d4a9"))
	# Open armoured vault door is parked alongside the aperture.
	var door := Node3D.new()
	add_child(door)
	door.position = Vector3(3.56, 2.23, -28.53)
	door.rotation.y = -0.55
	var disc := _cylinder(2.05, 0.48, Vector3.ZERO, "chrome", door, -1.0, 40)
	disc.rotation.x = PI * 0.5
	var inner := _cylinder(1.81, 0.505, Vector3(0, 0, 0.035), "charcoal", door, -1.0, 40)
	inner.rotation.x = PI * 0.5
	var bevel := _cylinder(1.52, 0.52, Vector3(0, 0, 0.055), "brass_dark", door, -1.0, 40)
	bevel.rotation.x = PI * 0.5
	var center := _cylinder(1.36, 0.54, Vector3(0, 0, 0.068), "slate", door, -1.0, 40)
	center.rotation.x = PI * 0.5
	for i in range(12):
		var angle := i * TAU / 12.0
		var bolt := _cylinder(0.06, 0.05, Vector3(sin(angle) * 1.7, cos(angle) * 1.7, 0.302), "trim", door, -1.0, 8)
		bolt.rotation.x = PI * 0.5
	for angle in [0.0, PI * 0.5, PI * 0.25, -PI * 0.25]:
		var handle := _box(Vector3(0.07, 1.1, 0.07), Vector3(0, 0, 0.41), "chrome", false, door)
		handle.rotation.z = angle
	var hub := _cylinder(0.21, 0.21, Vector3(0, 0, 0.47), "trim", door)
	hub.rotation.x = PI * 0.5
	_box(Vector3(5.1, 0.11, 6.0), Vector3(0, 0.1, -32.45), "dark_marble")
	_box(Vector3(5.1, 0.045, 0.07), Vector3(0, 0.17, -29.62), "warm")
	_box(Vector3(5.0, 4.7, 0.20), Vector3(0, 2.55, -35.58), "charcoal")
	# Deposit boxes, each with an inset name plate, flank the gold staging table.
	for side in [-1.0, 1.0]:
		for row in range(5):
			for col in range(3):
				var x: float = side * (0.49 + col * 0.73)
				var y := 0.65 + row * 0.73
				_box(Vector3(0.67, 0.64, 0.11), Vector3(x, y, -35.43), "chrome")
				_box(Vector3(0.17, 0.044, 0.04), Vector3(x + side * 0.15, y, -35.355), "charcoal")
	_box(Vector3(0.045, 4.4, 0.1), Vector3(-2.45, 2.5, -35.3), "warm")
	_box(Vector3(0.045, 4.4, 0.1), Vector3(2.45, 2.5, -35.3), "warm")
	_box(Vector3(2.4, 0.12, 0.9), Vector3(0, 1.03, -34.3), "chrome", true)
	_box(Vector3(0.11, 0.9, 0.7), Vector3(-0.97, 0.56, -34.3), "charcoal")
	_box(Vector3(0.11, 0.9, 0.7), Vector3(0.97, 0.56, -34.3), "charcoal")
	for row in range(3):
		for col in range(5 - row):
			var bar := _box(Vector3(0.38, 0.17, 0.52), Vector3(-0.88 + col * 0.43 + row * 0.2, 1.18 + row * 0.17, -34.3), "gold")
			bar.rotation.y = 0.04 * (col - 2)
	_light(Vector3(0, 3.1, -32.8), Color("ffe0a0"), 2.0, 6.7)

func _build_bench(position_value: Vector3, yaw: float = 0.0) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = position_value
	root.rotation.y = yaw
	_box(Vector3(2.8, 0.30, 0.85), Vector3(0, 0.63, 0), "charcoal", true, root)
	_box(Vector3(2.8, 0.6, 0.14), Vector3(0, 0.95, -0.40), "charcoal", false, root)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.08, 0.47, 0.65), Vector3(side * 1.07, 0.32, 0), "trim", false, root)
		_box(Vector3(0.12, 0.37, 0.77), Vector3(side * 1.35, 0.87, 0), "wood", false, root)

func _build_pot(position_value: Vector3, radius: float) -> void:
	_cylinder(radius * 0.85, 0.82, position_value + Vector3(0, 0.42, 0), "charcoal", null, radius, 12)
	_cylinder(radius * 1.01, 0.065, position_value + Vector3(0, 0.82, 0), "trim", null, -1.0, 12)
	_cylinder(0.07, 1.3, position_value + Vector3(0, 1.12, 0), "trunk", null, 0.03, 8)
	for i in range(5):
		var angle := i * TAU / 5.0
		var leaf := _sphere(radius * 0.61, position_value + Vector3(sin(angle) * radius * 0.55, 1.85, cos(angle) * radius * 0.55), "leaves_lit", null, Vector3(0.62, 1.9, 0.82))
		leaf.rotation.z = -sin(angle) * 0.5
		leaf.rotation.x = cos(angle) * 0.5

func _build_atm(position_value: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = position_value
	root.rotation.y = yaw
	_box(Vector3(1.2, 2.15, 0.85), Vector3(0, 1.15, 0), "charcoal", true, root)
	_box(Vector3(1.15, 0.075, 0.9), Vector3(0, 2.26, 0), "trim", false, root)
	_box(Vector3(0.73, 0.53, 0.026), Vector3(0, 1.64, 0.44), "teal_light", false, root)
	_label("AUREL", Vector3(0, 1.64, 0.46), 40, 0.006, Color("183c41"), root)
	_box(Vector3(0.41, 0.13, 0.035), Vector3(0, 0.96, 0.44), "chrome", false, root)
	_box(Vector3(0.34, 0.025, 0.04), Vector3(0, 0.96, 0.46), "rubber", false, root)

func _build_city() -> void:
	# Offset towers make a composed skyline without a resource-heavy city mesh.
	_build_building(Vector3(-24, 0, -24), Vector3(16, 21, 25), "slate", 5, 7)
	_build_building(Vector3(25, 0, -25), Vector3(16, 28, 26), "charcoal", 5, 9)
	_build_building(Vector3(-24, 0, 30), Vector3(18, 22, 12), "charcoal", 6, 7, true)
	_build_building(Vector3(25, 0, 30), Vector3(19, 16, 12), "slate", 6, 5, true)
	_build_building(Vector3(-8, 0, -47), Vector3(17, 34, 12), "slate", 5, 10)
	_build_building(Vector3(15, 0, -47), Vector3(18, 43, 12), "charcoal", 5, 13)
	_build_building(Vector3(-45, 0, -18), Vector3(13, 38, 20), "charcoal", 4, 10)
	_build_building(Vector3(45, 0, -10), Vector3(14, 33, 24), "slate", 4, 9)
	# Flanking streetfront shops have their own narrow canopies and muted signs.
	for side in [-1.0, 1.0]:
		var x: float = side * 24.0
		_box(Vector3(12.0, 3.2, 0.14), Vector3(x, 2.05, -11.36), "glass_black")
		_box(Vector3(13, 0.20, 2), Vector3(x, 4.0, -10.6), "charcoal")
		_box(Vector3(12.8, 0.034, 0.06), Vector3(x, 3.88, -9.61), "warm")
		_label("MAISON  08" if side < 0 else "NORTH  &  CO.", Vector3(x, 4.86, -11.35), 68, 0.011, Color("d0c7b7"))
		for offset in [-4.0, 0.0, 4.0]:
			_box(Vector3(0.12, 3.2, 0.24), Vector3(x + offset, 2.05, -11.2), "chrome")
		_box(Vector3(2.1, 2.7, 0.035), Vector3(x - side * 3.5, 2.0, -11.16), "warm")
		_box(Vector3(1.96, 2.56, 0.05), Vector3(x - side * 3.5, 2.0, -11.11), "dark_marble")
		_label("NIGHT\nDISTRICT", Vector3(x - side * 3.5, 2.0, -11.07), 55, 0.01, Color("e3ba7c"))

func _build_building(position_value: Vector3, size: Vector3, mat: String, columns: int, rows: int, face_back: bool = false) -> void:
	_box(size, position_value + Vector3(0, size.y * 0.5, 0), mat, true)
	_box(Vector3(size.x + 0.38, 0.40, size.z + 0.38), position_value + Vector3(0, size.y - 0.6, 0), "charcoal")
	var face_sign := -1.0 if face_back else 1.0
	var face_z := position_value.z + face_sign * (size.z * 0.5 + 0.025)
	var cell_width := (size.x - 2.2) / float(columns)
	for col in range(columns):
		var x := position_value.x - (size.x - 2.2) * 0.5 + cell_width * (col + 0.5)
		_box(Vector3(0.12, size.y - 2.2, 0.12), Vector3(x - cell_width * 0.5, size.y * 0.5, face_z), "brass_dark")
		for row in range(rows):
			var y := 2.1 + float(row) * (size.y - 3.3) / float(rows)
			var lit := ((col * 13 + row * 7 + int(abs(position_value.x))) % 9) < 3
			var window_mat := "warm" if lit else "glass_black"
			_box(Vector3(cell_width * 0.72, 1.35, 0.035), Vector3(x, y, face_z + face_sign * 0.07), window_mat)
			if lit:
				_box(Vector3(0.055, 1.36, 0.035), Vector3(x, y, face_z + face_sign * 0.1), mat)
	# Roof utility volumes add useful silhouettes when the player looks upward.
	_box(Vector3(size.x * 0.42, 1.0, size.z * 0.44), position_value + Vector3(0, size.y + 0.5, 0), "charcoal")

func _build_street_details() -> void:
	for x in [-17.0, 17.0]:
		_build_planter(Vector3(x, 0.08, -3.9))
		_build_tree(Vector3(x, 0.69, -3.9))
		_build_bench(Vector3(x + (2.65 if x < 0 else -2.65), 0.08, -2.6), PI * 0.5)
	for x in [-31.0, 31.0]:
		_build_tree(Vector3(x, 0.07, 21.2))
		_box(Vector3(2.25, 0.16, 2.25), Vector3(x, 0.1, 21.2), "charcoal")
	for x in [-26.0, -10.0, 10.0, 27.0]:
		_build_lamp(Vector3(x, 0.08, 3.8), false)
	for x in [-19.0, 19.0]:
		_build_lamp(Vector3(x, 0.08, 19.3), true)
	for x in [-5.6, 5.6]:
		for z in [-8.5, -4.4]:
			_cylinder(0.115, 0.95, Vector3(x, 0.57, z), "charcoal", null, -1.0, 12)
			_cylinder(0.12, 0.035, Vector3(x, 0.91, z), "warm", null, -1.0, 12)
	# A modest collection of low cover leaves the central approach unobstructed.
	_build_planter(Vector3(-7.8, 0.08, -8.9), Vector3(3.3, 0.75, 1.5))
	_build_planter(Vector3(7.8, 0.08, -8.9), Vector3(3.3, 0.75, 1.5))
	for x in [-7.8, 7.8]:
		for offset in [-0.9, 0.0, 0.9]:
			_sphere(0.56, Vector3(x + offset, 1.03, -8.9), "leaves", null, Vector3(1.1, 0.68, 0.82))
	_build_car(Vector3(-15.8, 0, 7.6), PI * 0.5, "car_blue")
	_build_car(Vector3(28.0, 0, 15.3), -PI * 0.5, "car_silver")
	# Street address and a slim information totem beside the arrival sightline.
	_box(Vector3(1.0, 2.9, 0.30), Vector3(-7.0, 1.53, -1.7), "charcoal", true)
	_box(Vector3(0.045, 2.72, 0.035), Vector3(-7.48, 1.53, -1.53), "warm")
	_label("08", Vector3(-7.0, 2.21, -1.536), 78, 0.009, Color("e5d1ad"))
	_label("AUREL\nPRIVATE BANK", Vector3(-7.0, 1.5, -1.536), 38, 0.0055, Color("e3e5df"))
	_label("EST. 1987", Vector3(-7.0, 0.58, -1.536), 33, 0.0055, Color("879f9f"))
	_box(Vector3(0.74, 1.17, 0.67), Vector3(14.1, 0.67, 2.9), "charcoal", true)
	_box(Vector3(0.60, 0.075, 0.03), Vector3(14.1, 1.12, 3.25), "chrome")

func _build_planter(position_value: Vector3, size: Vector3 = Vector3(3.1, 0.63, 3.1)) -> void:
	_box(size, position_value + Vector3(0, size.y * 0.5, 0), "charcoal", true)
	_box(Vector3(size.x + 0.08, 0.09, size.z + 0.08), position_value + Vector3(0, size.y, 0), "stone")
	_box(Vector3(size.x - 0.22, 0.03, size.z - 0.22), position_value + Vector3(0, size.y + 0.05, 0), "trunk")

func _build_tree(position_value: Vector3) -> void:
	_cylinder(0.23, 3.8, position_value + Vector3(0, 1.9, 0), "trunk", null, 0.11, 9)
	for i in range(5):
		var angle := i * TAU / 5.0
		var branch := _cylinder(0.12, 1.55, position_value + Vector3(sin(angle) * 0.40, 3.1, cos(angle) * 0.40), "trunk", null, 0.035, 7)
		branch.rotation.z = -sin(angle) * 0.65
		branch.rotation.x = cos(angle) * 0.65
		_sphere(1.35, position_value + Vector3(sin(angle) * 1.02, 4.12 + (i % 2) * 0.48, cos(angle) * 1.02), "leaves" if i % 2 == 0 else "leaves_lit", null, Vector3(1.06, 0.91, 1.06))
	_sphere(1.57, position_value + Vector3(0, 5.02, 0), "leaves_lit", null, Vector3(1.0, 0.80, 1.0))

func _build_lamp(position_value: Vector3, reversed: bool) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = position_value
	if reversed:
		root.rotation.y = PI
	_cylinder(0.17, 0.23, Vector3(0, 0.14, 0), "charcoal", root)
	_cylinder(0.08, 5.5, Vector3(0, 2.86, 0), "charcoal", root, 0.045, 10)
	_box(Vector3(0.10, 0.10, 1.35), Vector3(0, 5.56, 0.58), "charcoal", false, root)
	_box(Vector3(0.53, 0.15, 1.06), Vector3(0, 5.56, 1.07), "charcoal", false, root)
	_box(Vector3(0.43, 0.025, 0.86), Vector3(0, 5.472, 1.07), "warm", false, root)
	# Only the two lamps flanking the landing and two opposite lamps cast local light.
	if abs(position_value.x) < 21.0:
		_light(Vector3(0, 5.18, 1.06), Color("ffcf8e"), 1.65, 9.2, root)

func _build_van(position_value: Vector3, color: Color) -> Node3D:
	_material("van_paint", color, 0.28, 0.72)
	var root := Node3D.new()
	add_child(root)
	root.position = position_value
	# Vehicle forward is negative Z. Windows and mirrors are deliberately inset.
	_box(Vector3(2.28, 1.32, 4.65), Vector3(0, 1.03, 0.12), "van_paint", true, root)
	_box(Vector3(2.19, 1.14, 3.8), Vector3(0, 2.04, 0.40), "van_paint", false, root)
	_box(Vector3(2.13, 0.15, 3.86), Vector3(0, 2.63, 0.40), "charcoal", false, root)
	_box(Vector3(1.92, 0.83, 0.055), Vector3(0, 2.05, -1.535), "glass_black", false, root)
	_box(Vector3(0.08, 0.83, 0.067), Vector3(0, 2.05, -1.57), "charcoal", false, root)
	_box(Vector3(2.1, 0.20, 0.87), Vector3(0, 1.58, -1.99), "van_paint", false, root)
	_box(Vector3(1.27, 0.30, 0.055), Vector3(0, 0.96, -2.235), "rubber", false, root)
	for i in range(4):
		_box(Vector3(1.16, 0.025, 0.07), Vector3(0, 0.86 + i * 0.068, -2.27), "chrome", false, root)
	_box(Vector3(2.34, 0.24, 0.15), Vector3(0, 0.61, -2.29), "charcoal", false, root)
	_box(Vector3(2.34, 0.22, 0.14), Vector3(0, 0.62, 2.49), "charcoal", false, root)
	_box(Vector3(1.30, 0.14, 2.7), Vector3(0, 0.35, 0.1), "rubber", false, root)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.028, 0.75, 1.13), Vector3(side * 1.115, 2.05, -0.91), "glass_black", false, root)
		_box(Vector3(0.026, 0.026, 2.54), Vector3(side * 1.151, 1.24, 0.62), "chrome", false, root)
		_box(Vector3(0.035, 1.75, 0.026), Vector3(side * 1.149, 1.55, -0.21), "charcoal", false, root)
		_box(Vector3(0.054, 0.073, 0.29), Vector3(side * 1.17, 1.46, -0.48), "chrome", false, root)
		_box(Vector3(0.054, 0.073, 0.27), Vector3(side * 1.17, 1.46, 1.14), "chrome", false, root)
		_box(Vector3(0.32, 0.25, 0.20), Vector3(side * 1.27, 1.96, -1.38), "charcoal", false, root)
		_box(Vector3(0.02, 0.18, 0.16), Vector3(side * 1.44, 1.96, -1.36), "glass", false, root)
		_box(Vector3(0.46, 0.30, 0.07), Vector3(side * 0.82, 1.16, -2.26), "white_light", false, root)
		_box(Vector3(0.24, 0.56, 0.065), Vector3(side * 0.93, 1.37, 2.455), "red_light", false, root)
		_box(Vector3(0.14, 0.60, 2.67), Vector3(side * 1.125, 0.68, 0.16), "charcoal", false, root)
		for z in [-1.36, 1.63]:
			var wheel := _cylinder(0.47, 0.27, Vector3(side * 1.15, 0.49, z), "rubber", root, -1.0, 20)
			wheel.rotation.z = PI * 0.5
			var hub := _cylinder(0.25, 0.285, Vector3(side * 1.17, 0.49, z), "chrome", root, -1.0, 16)
			hub.rotation.z = PI * 0.5
			var cap := _cylinder(0.11, 0.296, Vector3(side * 1.175, 0.49, z), "charcoal", root)
			cap.rotation.z = PI * 0.5
		_box(Vector3(0.94, 0.80, 0.023), Vector3(side * 0.53, 2.05, 2.337), "glass_black", false, root)
	_box(Vector3(0.037, 1.92, 0.03), Vector3(0, 1.51, 2.47), "charcoal", false, root)
	_box(Vector3(0.46, 0.13, 0.026), Vector3(0, 0.82, 2.48), "lane", false, root)
	# Roof rack and two duffel cases make this van readable as the crew vehicle.
	for side in [-1.0, 1.0]:
		_box(Vector3(0.07, 0.11, 2.1), Vector3(side * 0.85, 2.78, 0.4), "chrome", false, root)
	_box(Vector3(1.60, 0.29, 1.48), Vector3(0, 2.91, 0.58), "charcoal", false, root)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.08, 0.033, 1.49), Vector3(side * 0.52, 3.069, 0.58), "brass_dark", false, root)
	return root

func _build_car(position_value: Vector3, yaw: float, mat: String) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = position_value
	root.rotation.y = yaw
	_box(Vector3(1.85, 0.65, 4.15), Vector3(0, 0.79, 0), mat, true, root)
	_box(Vector3(1.62, 0.72, 2.22), Vector3(0, 1.44, 0.28), "glass_black", false, root)
	_box(Vector3(1.63, 0.11, 2.29), Vector3(0, 1.83, 0.28), mat, false, root)
	_box(Vector3(1.8, 0.16, 1.04), Vector3(0, 1.18, -1.47), mat, false, root)
	_box(Vector3(1.80, 0.11, 0.68), Vector3(0, 1.16, 1.70), mat, false, root)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.04, 0.73, 0.12), Vector3(side * 0.82, 1.44, 0.32), mat, false, root)
		_box(Vector3(0.47, 0.18, 0.035), Vector3(side * 0.61, 0.94, -2.09), "white_light", false, root)
		_box(Vector3(0.41, 0.16, 0.035), Vector3(side * 0.61, 0.96, 2.09), "red_light", false, root)
		for z in [-1.34, 1.34]:
			var wheel := _cylinder(0.38, 0.23, Vector3(side * 0.93, 0.41, z), "rubber", root, -1.0, 16)
			wheel.rotation.z = PI * 0.5
			var hub := _cylinder(0.23, 0.245, Vector3(side * 0.94, 0.41, z), "chrome", root, -1.0, 12)
			hub.rotation.z = PI * 0.5
	return root
