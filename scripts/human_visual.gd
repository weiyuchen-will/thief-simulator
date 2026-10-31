extends RefCounted
## Smooth anatomical character mesh with modeled facial features and layered clothing.
## All dimensions are in metres; the head is about one eighth of total height.
var skin: StandardMaterial3D
var skin_warm: StandardMaterial3D
var hair: StandardMaterial3D
var cloth: StandardMaterial3D
var dark: StandardMaterial3D
var white: StandardMaterial3D
var accent: StandardMaterial3D
static var shared_face_mesh: ArrayMesh

func build(parent: Node3D,role: String,index: int=0) -> Dictionary:
	var civilian := role=="target"
	cloth = material(Color("273849") if civilian or role=="police" else Color("354b40"),0.87)
	dark = material(Color("101a20"),0.64)
	white = material(Color("d2d6ce"),0.77)
	accent = material(Color("c1a66c") if civilian else (Color("86b5c6") if role=="police" else Color("9cd2b3")),0.43)
	var skin_colors := [Color("bf8d70"),Color("d7ad8c"),Color("976747"),Color("c8967c")]
	skin = material(skin_colors[posmod(index,4)],0.77)
	skin_warm = material(skin.albedo_color.darkened(0.10).lerp(Color("ad6c54"),0.22),0.84)
	hair = material(Color("271f1a") if index%2==0 else Color("403028"),0.96)
	var body := Node3D.new()
	parent.add_child(body)
	# Rounded, tapered chest and waist rather than a box-shaped torso.
	loft(body,[Vector4(0.83,0.214,0.116,0),Vector4(0.94,0.207,0.122,0),Vector4(1.10,0.185,0.126,0),Vector4(1.27,0.226,0.136,0),Vector4(1.39,0.239,0.123,0),Vector4(1.46,0.230,0.119,0),Vector4(1.49,0.17,0.106,0),Vector4(1.535,0.08,0.082,-0.01)],cloth)
	var legs: Array[Node3D] = []
	for side in [-1.0,1.0]:
		var leg := pivot(body,Vector3(side*0.108,0.89,0))
		legs.append(leg)
		loft(leg,[Vector4(-0.775,0.066,0.067,0.012),Vector4(-0.69,0.072,0.069,0.012),Vector4(-0.53,0.082,0.078,0.012),Vector4(-0.37,0.083,0.083,0.010),Vector4(-0.24,0.094,0.088,0.008),Vector4(-0.08,0.10,0.099,0),Vector4(0.035,0.092,0.103,0)],cloth)
		sphere(leg,Vector3(0,-0.80,-0.046),Vector3(0.078,0.069,0.142),dark)
		sphere(leg,Vector3(0,-0.848,-0.046),Vector3(0.080,0.022,0.144),material(Color("0b1217"),0.98))
		if not civilian:
			sphere(leg,Vector3(0,-0.365,-0.068),Vector3(0.077,0.087,0.031),dark)
			box(leg,Vector3(0.127,0.042,0.13),Vector3(0,-0.40,0),dark)
			for lace in 3:
				line(leg,Vector3(-0.032,-0.768,-0.081-lace*0.023),Vector3(0.032,-0.768,-0.081-lace*0.023),0.004,cloth)
	var arms: Array[Node3D] = []
	for side in [-1.0,1.0]:
		var arm := pivot(body,Vector3(side*0.238,1.365,0))
		arms.append(arm)
		if civilian:
			arm.rotation.z = side*0.04
			loft(arm,[Vector4(-0.50,0.050,0.048,-0.014),Vector4(-0.43,0.057,0.059,-0.006),Vector4(-0.31,0.064,0.067,0.005),Vector4(-0.24,0.068,0.071,0.006),Vector4(-0.10,0.077,0.083,0),Vector4(0.035,0.078,0.080,0),Vector4(0.075,0.056,0.062,0)],cloth)
			sphere(arm,Vector3(0,0.025,0),Vector3(0.079,0.070,0.081),cloth)
			sphere(arm,Vector3(0,-0.502,-0.014),Vector3(0.050,0.016,0.047),white)
			hand(arm,Vector3(0,-0.548,-0.017),side,false)
		else:
			var elbow := Vector3(side*0.042,-0.25,-0.023)
			var wrist := Vector3(0.32,-0.22,-0.48) if side<0 else Vector3(-0.12,-0.22,-0.29)
			capsule(arm,Vector3.ZERO,elbow,0.091,cloth)
			capsule(arm,elbow,wrist,0.066,cloth)
			hand(arm,wrist+Vector3(0,-0.016,-0.033),side,true)
			box(arm,Vector3(0.095,0.07,0.022),Vector3(side*0.04,-0.079,-0.080),accent)
	# Seam, lapels and smaller hard equipment sit on top of the curved body.
	if civilian:
		poly(body,[Vector3(-0.061,1.516,-0.084),Vector3(0.061,1.516,-0.084),Vector3(0.098,1.439,-0.092),Vector3(0,1.152,-0.142),Vector3(-0.098,1.439,-0.092)],white)
		poly(body,[Vector3(-0.104,1.452,-0.10),Vector3(-0.199,1.363,-0.12),Vector3(-0.081,1.189,-0.138),Vector3(-0.024,1.306,-0.147)],material(Color("3b4b5a"),0.69))
		poly(body,[Vector3(0.104,1.452,-0.10),Vector3(0.199,1.363,-0.12),Vector3(0.081,1.189,-0.138),Vector3(0.024,1.306,-0.147)],material(Color("3b4b5a"),0.69))
		var tie := material(Color("714451"),0.68)
		sphere(body,Vector3(0,1.393,-0.117),Vector3(0.022,0.021,0.008),tie)
		poly(body,[Vector3(-0.011,1.38,-0.128),Vector3(0.012,1.38,-0.128),Vector3(0.023,1.215,-0.145),Vector3(0,1.191,-0.149),Vector3(-0.022,1.215,-0.145)],tie)
		for y in [1.105,1.022]: sphere(body,Vector3(0.021,y,-0.126),Vector3(0.009,0.009,0.003),dark)
		box(body,Vector3(0.055,0.012,0.008),Vector3(-0.143,1.32,-0.128),white)
		line(body,Vector3(-0.12,0.982,-0.107),Vector3(-0.18,1.0,-0.088),0.003,accent)
		line(body,Vector3(0.12,0.982,-0.107),Vector3(0.18,1.0,-0.088),0.003,accent)
	else:
		var vest := material(Color("17232a") if role=="police" else Color("27362c"),0.93)
		sphere(body,Vector3(0,1.223,-0.112),Vector3(0.198,0.234,0.070),vest)
		for x in [-0.123,0.0,0.123]:
			box(body,Vector3(0.098,0.142,0.045),Vector3(x,1.126,-0.169),vest)
			box(body,Vector3(0.091,0.027,0.05),Vector3(x,1.191,-0.171),cloth)
		box(body,Vector3(0.17,0.039,0.012),Vector3(0,1.336,-0.166),accent)
		for side in [-1.0,1.0]:
			capsule(body,Vector3(side*0.134,1.42,-0.06),Vector3(side*0.155,1.296,-0.145),0.029,vest)
			box(body,Vector3(0.112,0.057,0.089),Vector3(side*0.158,0.933,-0.081),dark)
		box(body,Vector3(0.059,0.041,0.02),Vector3(0,0.934,-0.128),accent)
	loft(body,[Vector4(1.505,0.108,0.092,-0.005),Vector4(1.535,0.096,0.085,-0.006),Vector4(1.550,0.090,0.082,-0.006)],white if civilian else cloth)
	face(body,role,index)
	return {"body":body,"left_leg":legs[0],"right_leg":legs[1],"left_arm":arms[0],"right_arm":arms[1],"cloth":cloth,"accent":accent}

func face(body: Node3D,role: String,index: int) -> void:
	# Licensed human scan supplies continuous facial anatomy, pores, brows and eyes.
	var source: Node3D = preload("res://assets/characters/LeePerrySmith.glb").instantiate()
	var original: MeshInstance3D = source.find_children("*","MeshInstance3D",true,false)[0]
	var head := MeshInstance3D.new()
	head.name = "DetailedHumanFace"
	if shared_face_mesh == null:
		shared_face_mesh = crop_face(original.mesh)
	head.mesh = shared_face_mesh
	head.scale = Vector3.ONE*0.052
	head.position = Vector3(0,1.605,0)
	head.rotation.y = PI
	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_texture = preload("res://assets/characters/Map-COL.jpg")
	face_mat.albedo_color = Color(0.96,0.93,0.91) if index%2==0 else Color.WHITE
	face_mat.normal_enabled = true
	face_mat.normal_texture = preload("res://assets/characters/Infinite-Level_02_Tangent_SmoothUV.jpg")
	face_mat.normal_scale = 0.18
	face_mat.uv1_scale = Vector3(1,-1,1)
	face_mat.uv1_offset = Vector3(0,1,0)
	face_mat.roughness = 0.78
	face_mat.metallic_specular = 0.3
	head.material_override = face_mat
	body.add_child(head)
	source.free()
	var sclera := material(Color("bdc1b6"),0.56)
	var iris_mat := material(Color("55635c"),0.55)
	var pupil_mat := material(Color("1a2222"),0.47)
	for eye in [Vector3(0.040668,1.693928,-0.10134),Vector3(-0.024508,1.694249,-0.101546)]:
		sphere(body,eye,Vector3(0.0130,0.0050,0.0019),sclera)
		sphere(body,eye+Vector3(0,0,-0.0018),Vector3(0.0045,0.0047,0.0008),iris_mat)
		sphere(body,eye+Vector3(0,0,-0.0024),Vector3(0.0020,0.0027,0.0006),pupil_mat)
		sphere(body,eye+Vector3(-0.0011,0.0018,-0.003),Vector3(0.0007,0.0007,0.0004),white)
	if role=="police":
		# A cap identifies police while leaving their faces unobstructed.
		sphere(body,Vector3(0,1.796,0.015),Vector3(0.099,0.033,0.089),dark)
		sphere(body,Vector3(0,1.777,-0.077),Vector3(0.088,0.010,0.048),dark)
		sphere(body,Vector3(0,1.802,-0.071),Vector3(0.012,0.014,0.003),accent)
	elif role=="ally":
		capsule(body,Vector3(0.103,1.686,0),Vector3(0.103,1.647,0),0.022,dark)
		line(body,Vector3(0.103,1.647,-0.012),Vector3(0.063,1.59,-0.11),0.003,dark)

func crop_face(source: Mesh) -> ArrayMesh:
	# Clip crossing triangles at the collar plane, interpolating skin UVs and normals.
	# Dropping whole triangles leaves a visibly jagged neckline on this scan.
	var arrays := source.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const CUT := -1.10
	for i in range(0,indices.size(),3):
		var triangle: Array = []
		for j in 3:
			var v := indices[i+j]
			triangle.append([positions[v],normals[v],uvs[v]])
		var clipped: Array = []
		for j in 3:
			var a: Array = triangle[j]
			var b: Array = triangle[(j+1)%3]
			var a_inside: bool = a[0].y >= CUT
			var b_inside: bool = b[0].y >= CUT
			if a_inside:
				clipped.append(a)
			if a_inside != b_inside:
				var t: float = (CUT-a[0].y)/(b[0].y-a[0].y)
				clipped.append([a[0].lerp(b[0],t),a[1].lerp(b[1],t).normalized(),a[2].lerp(b[2],t)])
		for j in range(1,clipped.size()-1):
			for v in [clipped[0],clipped[j],clipped[j+1]]:
				st.set_normal(v[1])
				st.set_uv(v[2])
				st.add_vertex(v[0])
	st.generate_tangents()
	st.index()
	return st.commit()


func hand(parent: Node3D,at: Vector3,side: float,gloved: bool) -> void:
	var hand_material := dark if gloved else skin
	sphere(parent,at,Vector3(0.043,0.048,0.028),hand_material)
	for i in 4:
		var offset := Vector3(-0.026+i*0.017,-0.023,-0.002)
		capsule(parent,at+offset,at+offset+Vector3(0,-0.044+absf(i-1.5)*0.006,-0.011),0.009,hand_material)
	capsule(parent,at+Vector3(side*0.032,0.006,0),at+Vector3(side*0.046,-0.021,-0.010),0.012,hand_material)

func material(color: Color,roughness: float=0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func pivot(parent: Node3D,at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = at
	parent.add_child(node)
	return node

func sphere(parent: Node3D,at: Vector3,radii: Vector3,mat: Material) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 1
	shape.height = 2
	shape.radial_segments = 24
	shape.rings = 12
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.scale = radii
	mesh.position = at
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh

func capsule(parent: Node3D,from: Vector3,to: Vector3,radius: float,mat: Material) -> MeshInstance3D:
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = from.distance_to(to)+radius*2.0
	shape.radial_segments = 20
	shape.rings = 6
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.material_override = mat
	mesh.position = (from+to)*0.5
	var direction := (to-from).normalized()
	mesh.quaternion = Quaternion(Vector3.UP,direction)
	parent.add_child(mesh)
	return mesh

func line(parent: Node3D,from: Vector3,to: Vector3,radius: float,mat: Material) -> void:
	capsule(parent,from,to,radius,mat)

func box(parent: Node3D,size: Vector3,at: Vector3,mat: Material) -> void:
	var shape := BoxMesh.new()
	shape.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.material_override = mat
	mesh.position = at
	parent.add_child(mesh)

func poly(parent: Node3D,vertices: Array,mat: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3(0,0,-1))
	for i in range(1,vertices.size()-1):
		for vertex in [vertices[0],vertices[i],vertices[i+1]]: surface.add_vertex(vertex+Vector3(0,0,-0.031))
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var copy: StandardMaterial3D = mat.duplicate()
	copy.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = copy
	parent.add_child(mesh)

func loft(parent: Node3D,rings: Array,mat: Material,segments: int=28) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(rings.size()-1):
		for column in segments:
			var angles := [float(column)/segments*TAU,float(column+1)/segments*TAU]
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for ri in [ring,ring+1]:
				var r: Vector4 = rings[ri]
				var low: Vector4 = rings[maxi(0,ri-1)]
				var high: Vector4 = rings[mini(rings.size()-1,ri+1)]
				var slope := ((high.y+high.z)-(low.y+low.z))*0.5/maxf(0.01,high.x-low.x)
				for angle in angles:
					points.append(Vector3(sin(angle)*r.y,r.x,cos(angle)*r.z+r.w))
					normals.append(Vector3(sin(angle),-slope,cos(angle)).normalized())
			for vi in [0,2,1,1,2,3]:
				st.set_normal(normals[vi])
				st.add_vertex(points[vi])
	var top: Vector4 = rings[-1]
	for column in segments:
		var a := float(column)/segments*TAU
		var b := float(column+1)/segments*TAU
		for vertex in [Vector3(0,top.x,top.w),Vector3(sin(b)*top.y,top.x,cos(b)*top.z+top.w),Vector3(sin(a)*top.y,top.x,cos(a)*top.z+top.w)]:
			st.set_normal(Vector3.UP)
			st.add_vertex(vertex)
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = mat
	parent.add_child(mesh)
