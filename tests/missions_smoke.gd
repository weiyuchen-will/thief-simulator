extends SceneTree
var errors: Array[String] = []
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool,message: String) -> void:
	if not condition: errors.append(message)

func begin(id: String) -> void:
	game._start_game(id)
	game._finish_intro()
	game.player.position = Vector3(0,0.12,-16)
	await physics_frame
	game._update_game(0.01)
	expect(game.phase=="loot","Entering building did not advance "+id)
	expect(game.world.location==game.mission.location,"Location mismatch "+id)

func run() -> void:
	game = load("res://scripts/main.gd").new()
	root.add_child(game)
	game.qa_mode = "missions_test"
	game.progress = load("res://scripts/progress.gd").new()
	await process_frame
	var previous := ""
	for cycle in 5:
		var bag: Array[String] = []
		for i in 4:
			var id: String = game._next_mission()
			expect(id!=previous,"Mission immediately repeated")
			bag.append(id)
			previous = id
		bag.sort()
		expect(bag==["assassination","bank","capture","home"],"Mission cycle missing type")
	for id in ["bank","home"]:
		await begin(id)
		expect(game.loot_objects.size()==int(game.mission.required),"Wrong loot count "+id)
		for i in int(game.mission.required):
			game.player.position = game.LOOT_POSITIONS[i]+Vector3(0,0.1,1.5)
			await physics_frame
			game._interact()
		expect(game.phase=="escape","Collect completion failed "+id)
		game.player.position = game._escape_position()
		var before: int = game.progress.credits
		game._interact()
		expect(game.phase=="won","Extraction failed "+id)
		expect(game.progress.credits>before,"No currency award "+id)
		var after: int = game.progress.credits
		game._finish(true)
		expect(after==game.progress.credits,"Result granted twice")
	await begin("assassination")
	var target = game.mission_target
	expect(not target.is_in_group("enemies"),"Teammates target mission actor")
	game.player.position = Vector3(0,0.1,-29.5)
	await physics_frame
	var origin: Vector3 = game.player.position+Vector3.UP*1.3
	game._on_shot(origin,(target.position+Vector3.UP*1.3-origin).normalized(),200.0,40.0)
	expect(not target.alive and game.phase=="escape","Assassination hitscan completion failed")
	game.player.position = game._escape_position()
	game._interact()
	expect(game.phase=="won","Assassination extraction failed")
	await begin("capture")
	target = game.mission_target
	game.player.position = Vector3(0,0.1,-30)
	await physics_frame
	game._interact()
	expect(target.captured and game.phase=="escape","Capture failed")
	game.player.position = game._escape_position()
	game._interact()
	expect(game.phase=="escape","Escaped while target was not at van")
	game.police_eta = 999.0
	game._set_paused(true)
	var frozen: Vector3 = target.position
	await create_timer(0.15,true).timeout
	expect(target.position.is_equal_approx(frozen),"Paused escort moved")
	game._set_paused(false)
	# Actual collision-aware following all the way through two doorways to the van.
	for i in 1100:
		await physics_frame
		if target.position.distance_to(game._escape_position())<6.0: break
	expect(target.position.distance_to(game._escape_position())<6.5,"Escort stuck at %s"%target.position)
	game._interact()
	expect(game.phase=="won","Escort extraction failed")
	await begin("capture")
	var before_failure: int = game.progress.credits
	game.mission_target.apply_damage(200)
	expect(game.phase=="lost","Dead capture target did not fail mission")
	expect(game.progress.credits==maxi(0,before_failure-300),"Failure currency penalty incorrect")
	expect(not game.failure_reason.is_empty(),"No target death reason")
	await begin("home")
	game._on_action("menu",true)
	expect(game.phase=="menu","Abort to menu failed")
	for audio_node in game.find_children("*","AudioStreamPlayer",true,false):
		audio_node.stop()
		audio_node.stream = null
	await create_timer(0.12).timeout
	if errors.is_empty(): print("MISSIONS_SMOKE_OK: diverse shuffle, collection, target hitscan, capture escort, pause, success currency, failure penalty, abort")
	else:
		for message in errors: push_error(message)
	quit(0 if errors.is_empty() else 1)
