extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1200,900)
	root.content_scale_size = Vector2i.ZERO
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("17252c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9c9ce")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-27,-36,0)
	sun.light_energy = 1.8
	sun.light_color = Color("ffddb8")
	scene.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.5,1.8,-1.0)
	fill.omni_range = 5
	fill.light_energy = 0.7
	fill.light_color = Color("c4e1f1")
	scene.add_child(fill)
	var human := preload("res://scripts/human_visual.gd").new()
	human.build(scene,"target",1)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0.28,1.68,-0.90)
	camera.look_at(Vector3(0,1.61,0))
	camera.fov = 35
	camera.current = true
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/character_closeup.png")
	camera.position = Vector3(0.45,1.55,-2.6)
	camera.look_at(Vector3(0,1.00,0))
	camera.fov = 45
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/character_full.png")
	print("CHARACTER_PREVIEW_OK")
	quit()
