extends Node3D

const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const HudScript = preload("res://scripts/hud.gd")
const ActorScript = preload("res://scripts/actor.gd")
const SoundtrackScript = preload("res://scripts/soundtrack.gd")
const MissionsScript = preload("res://scripts/missions.gd")
const TargetScript = preload("res://scripts/target.gd")
const ProgressScript = preload("res://scripts/progress.gd")
const LOOT_POSITIONS = [Vector3(-5,0,-32),Vector3(0,0,-32),Vector3(5,0,-32)]

var world: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var cinematic: Camera3D
var van: Node3D
var crew: Array[Node3D] = []
var loot_objects: Array[Node3D] = []
var loot_collected: Array[bool] = [false,false,false]
var effects: Node3D
var cabin: Node3D
var phase: String = "menu"
var paused: bool = false
var phase_time: float = 0.0
var elapsed: float = 0.0
var score: int = 0
var kills: int = 0
var loot: int = 0
var result_bonus: int = 0
var alarm: bool = false
var police_eta: float = 35.0
var spawn_cooldown: float = 0.0
var police_spawned: int = 0
var hit_flash: float = 0.0
var hit_marker: float = 0.0
var toast: String = ""
var toast_time: float = 0.0
var dialogue_speaker: String = ""
var dialogue_text: String = ""
var dialogue_remaining: float = 0.0
var dialogue_queue: Array[Dictionary] = []
var touch_enabled: bool = true
var interaction_prompt: String = ""
var sound_player: AudioStreamPlayer
var soundtrack: Node
var qa_mode: String = ""
var qa_frames: int = 0
var damage_grace: float = 0.0
var last_health: float = 100.0
var touch_aim: bool = false
var rng := RandomNumberGenerator.new()
var persist_config := ConfigFile.new()
var best_score: int = 0
var grenades: int = 4
var smoke_grenades: int = 3
var throw_cooldown: float = 0.0
var smoke_zones: Array[Dictionary] = []
var arsenal_open: bool = false
var mission: Dictionary = MissionsScript.get_mission("bank")
var mission_bag: Array[String] = []
var last_mission: String = ""
var mission_number: int = 0
var mission_target: CharacterBody3D
var failure_reason: String = ""
var progress := ProgressScript.new()
var currency_delta: int = 0
var new_skin: String = ""
var skin_index: int = 0

func _exit_tree() -> void:
	if is_instance_valid(sound_player):
		sound_player.stop()
		sound_player.stream = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_setup_inputs()
	DisplayServer.window_set_min_size(Vector2i(360,360))
	world = WorldScript.new()
	add_child(world)
	world.build_world()
	_setup_lighting()
	van = world.get_node_or_null("EscapeVan")
	if van == null and "van" in world:
		van = world.van
	effects = Node3D.new()
	effects.name = "Effects"
	effects.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(effects)
	player = PlayerScript.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.position = Vector3(2,0,7)
	player.set_enabled(false)
	player.shot_fired.connect(_on_shot)
	player.interacted.connect(_interact)
	cinematic = Camera3D.new()
	cinematic.fov = 68
	cinematic.far = 180.0
	add_child(cinematic)
	cinematic.make_current()
	_create_cabin()
	_spawn_crew()
	_create_loot()
	hud = HudScript.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	hud.action.connect(_on_action)
	hud.move_input.connect(func(value: Vector2): player.set_touch_move(value))
	hud.look_input.connect(func(delta: Vector2):
		if phase == "intro":
			cinematic.rotation.y = clampf(cinematic.rotation.y-delta.x*0.002,-0.65,0.65)
			cinematic.rotation.x = clampf(cinematic.rotation.x-delta.y*0.002,-0.25,0.25)
		else:
			player.apply_look_delta(delta)
	)
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	soundtrack = SoundtrackScript.new()
	add_child(soundtrack)
	persist_config.load("user://nightfall.cfg")
	best_score = int(persist_config.get_value("scores","best",0))
	progress.load_profile()
	skin_index = progress.equipped_skin
	player.set_skin(skin_index)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa="):
			qa_mode = arg.trim_prefix("--qa=")
	if not qa_mode.is_empty():
		call_deferred("_prepare_qa")
	_update_hud()

func _setup_inputs() -> void:
	var bindings := {
		"move_forward":KEY_W,"move_back":KEY_S,"move_left":KEY_A,"move_right":KEY_D,
		"sprint":KEY_SHIFT,"jump":KEY_SPACE,"reload":KEY_R,"interact":KEY_E,
		"melee":KEY_F,"switch_weapon":KEY_Q,"pause":KEY_ESCAPE,
		"weapon_1":KEY_1,"weapon_2":KEY_2,"weapon_3":KEY_3,
		"weapon_4":KEY_4,"weapon_5":KEY_5,"weapon_6":KEY_6,"weapon_7":KEY_7,
		"grenade":KEY_G,"smoke":KEY_H,"arsenal":KEY_TAB
	}
	for action_name in bindings:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action_name]
		InputMap.action_add_event(action_name,event)
	for item in [["fire",MOUSE_BUTTON_LEFT],["aim",MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(item[0]):
			InputMap.add_action(item[0])
		var event := InputEventMouseButton.new()
		event.button_index = item[1]
		InputMap.action_add_event(item[0],event)

func _setup_lighting() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("101e34")
	sky_material.sky_horizon_color = Color("516976")
	sky_material.ground_bottom_color = Color("182630")
	sky_material.ground_horizon_color = Color("6e7780")
	sky_material.sky_curve = 0.18
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("91acba")
	environment.ambient_light_energy = 0.68
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("4b6372")
	environment.fog_light_energy = 0.45
	environment.fog_density = 0.0018
	environment_node.environment = environment
	add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32,-24,0)
	sun.light_color = Color("b2cbdb")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	add_child(sun)

func _process(delta: float) -> void:
	qa_frames += 1
	if not paused:
		phase_time += delta
		hit_flash = maxf(0.0,hit_flash-delta*1.7)
		hit_marker = maxf(0.0,hit_marker-delta)
		toast_time = maxf(0.0,toast_time-delta)
		damage_grace = maxf(0.0,damage_grace-delta)
		throw_cooldown = maxf(0.0,throw_cooldown-delta)
		for zone in smoke_zones:
			zone.time -= delta
		smoke_zones = smoke_zones.filter(func(zone: Dictionary): return zone.time>0)
		_update_dialogue(delta)
		if phase == "menu":
			cinematic.position = Vector3(16+sin(phase_time*0.1)*1.5,8.5,17)
			cinematic.look_at(Vector3(0,3.0,-15))
		elif phase == "intro":
			_update_intro(delta)
		elif phase in ["approach","loot","escape"]:
			_update_game(delta)
	for i in loot_objects.size():
		if is_instance_valid(loot_objects[i]) and not loot_collected[i]:
			loot_objects[i].position.y = 0.04+sin(phase_time*2.0+float(i))*0.04
	_update_hud()
	if is_instance_valid(soundtrack):
		var music_stage := "combat" if alarm and police_eta<=0 and phase=="loot" else phase
		soundtrack.set_stage(music_stage)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if phase in ["approach","loot","escape","intro"]:
				arsenal_open = false
				_set_paused(not paused)
		elif event.keycode == KEY_F11:
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event.keycode == KEY_ENTER and phase in ["menu","won","lost"]:
			_start_game()
		elif event.is_action_pressed("interact") and phase=="intro":
			_finish_intro()
		elif event.is_action_pressed("grenade"):
			_throw_grenade(false)
		elif event.is_action_pressed("smoke"):
			_throw_grenade(true)
		elif event.is_action_pressed("arsenal") and phase in ["approach","loot","escape"]:
			arsenal_open = not arsenal_open
			_set_paused(arsenal_open)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if phase in ["approach","loot","escape"] and not paused and not touch_enabled:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _next_mission() -> String:
	if mission_bag.is_empty():
		mission_bag.assign(["bank","home","assassination","capture"])
		mission_bag.shuffle()
		if mission_bag[-1] == last_mission:
			var swap: String = mission_bag[0]
			mission_bag[0] = mission_bag[-1]
			mission_bag[-1] = swap
	last_mission = mission_bag.pop_back()
	return last_mission

func _rebuild_mission() -> void:
	remove_child(world)
	world.queue_free()
	world = WorldScript.new()
	world.location = str(mission.location)
	add_child(world)
	van = world.get_intro_vehicle()
	for item in loot_objects:
		remove_child(item)
		item.queue_free()
	loot_objects.clear()
	loot_collected.clear()
	if mission.kind == "collect":
		for i in int(mission.required): loot_collected.append(false)
		_create_loot()
	mission_target = null
	if mission.kind in ["eliminate","capture"]:
		mission_target = TargetScript.new()
		mission_target.setup(str(mission.kind),"灰狐" if mission.kind=="eliminate" else "信使")
		mission_target.position = Vector3(0,0.1,-32)
		mission_target.rotation.y = PI
		mission_target.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(mission_target)
		mission_target.eliminated.connect(_on_target_eliminated)

func _start_game(forced_mission: String = "") -> void:
	get_tree().paused = false
	soundtrack.set_paused(false)
	for actor in get_tree().get_nodes_in_group("actors"):
		remove_child(actor)
		actor.queue_free()
	crew.clear()
	for effect in effects.get_children():
		effect.queue_free()
	mission = MissionsScript.get_mission(forced_mission if not forced_mission.is_empty() else _next_mission())
	mission_number += 1
	_rebuild_mission()
	_spawn_crew()
	failure_reason = ""
	currency_delta = 0
	new_skin = ""
	score = 0
	grenades = 4
	smoke_grenades = 3
	smoke_zones.clear()
	arsenal_open = false
	throw_cooldown = 0
	kills = 0
	loot = 0
	result_bonus = 0
	police_spawned = 0
	spawn_cooldown = 0.0
	police_eta = float(mission.alarm_delay)
	alarm = false
	elapsed = 0.0
	paused = false
	damage_grace = 0.0
	touch_aim = false
	player.reset_player()
	player.set_skin(skin_index)
	player.set_enabled(false)
	player.position = Vector3(2,0,7)
	player.rotation = Vector3.ZERO
	last_health = player.health
	phase = "intro"
	phase_time = 0.0
	cinematic.make_current()
	cinematic.rotation = Vector3.ZERO
	cabin.visible = true
	dialogue_queue.clear()
	dialogue_remaining = 0.0
	_say(str(mission.client),"特务 91，新的委托："+str(mission.brief),4.7)
	_say("司机 · 米洛","下一个路口就是"+str(mission.place)+"。准备行动。",4.0)
	_say("队友 · 白鸦","特务 91，无线电正常。门口见。",3.3)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _update_intro(_delta: float) -> void:
	var t := clampf(phase_time/9.0,0.0,1.0)
	var eased := 1.0-pow(1.0-t,2)
	cinematic.position = Vector3(0.66,1.78,lerpf(32,9.2,eased))
	cinematic.position.y += sin(phase_time*9)*0.018*(1.0-t)
	if is_instance_valid(van):
		van.visible = false
	if phase_time > 9.4:
		_finish_intro()

func _finish_intro() -> void:
	cabin.visible = false
	if is_instance_valid(van):
		van.visible = true
	phase = "approach"
	if is_instance_valid(mission_target): mission_target.active = true
	phase_time = 0.0
	player.position = Vector3(2.9,0.12,7)
	player.camera.make_current()
	player.set_enabled(true)
	player.rotation.y = 0.0
	for i in crew.size():
		crew[i].active = true
		crew[i].destination = Vector3(-1.25 if i==0 else 1.25,0,-17)
	_say("队友 · 幽灵","特务 91，下车。"+str(mission.arrival),4.6,true)
	_toast(str(mission.name)+"  /  跟随队友")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if touch_enabled else Input.MOUSE_MODE_CAPTURED

func _update_game(delta: float) -> void:
	elapsed += delta
	if player.health < last_health:
		hit_flash = 0.55
	last_health = player.health
	if player.health <= 0:
		_finish(false)
		return
	if player.position.y < -5.0:
		player.position = Vector3(2.9,0.2,7)
	if phase == "approach" and player.position.z < -13:
		phase = "loot"
		phase_time = 0.0
		alarm = true
		_say("队友 · 白鸦",str(mission.inside),4.6,true)
		_toast("警报已触发  /  增援正在赶来")
		for i in crew.size():
			crew[i].destination = Vector3(-1.5 if i==0 else 1.5,0,-25)
	if alarm:
		var old_eta := police_eta
		police_eta = maxf(0.0,police_eta-delta)
		if old_eta > 15 and police_eta <= 15:
			_say("司机 · 米洛","路口出现了警灯。后门走不了，原路回车上！",4.6,true)
		if old_eta > 0 and police_eta <= 0:
			_say("无线电","特务 91，警察到了！大门外有增援，保持移动！",4.2,true)
			_spawn_police_wave()
		if police_eta <= 0:
			spawn_cooldown -= delta
			if spawn_cooldown <= 0 and get_tree().get_nodes_in_group("enemies").size() < 9:
				_spawn_police_wave()
	for member in crew:
		if is_instance_valid(member):
			member.target = _nearest_enemy(member.position)
			if phase == "escape":
				member.destination = _escape_position()+Vector3(-3 if member.actor_index==0 else 3,0,-3)
	interaction_prompt = ""
	if phase == "loot":
		if mission.kind == "collect":
			for i in loot_objects.size():
				if not loot_collected[i] and player.position.distance_to(LOOT_POSITIONS[i])<2.65:
					interaction_prompt = "收集"+str(mission.item)+"  [ E ]"
		elif mission.kind == "capture" and is_instance_valid(mission_target) and player.position.distance_to(mission_target.position)<2.65:
			interaction_prompt = "控制信使并带走  [ E ]"
	elif phase == "escape" and player.position.distance_to(_escape_position()) < 4.6:
		interaction_prompt = "登车撤离  [ E ]" if _escort_ready() else "等信使靠近车辆  /  留意目标标记"

func _escort_ready() -> bool:
	return mission.kind != "capture" or (is_instance_valid(mission_target) and mission_target.alive and mission_target.captured and mission_target.position.distance_to(_escape_position())<6.5)

func _begin_escape() -> void:
	phase = "escape"
	phase_time = 0.0
	police_eta = minf(police_eta,3.0)
	player.reserve += 60
	player.health = minf(100.0,player.health+25.0)
	_say("司机 · 米洛","任务目标完成！"+("带信使一起上车，我们马上走！" if mission.kind=="capture" else "车还在门外，回来马上走！"),4.8,true)

func _on_target_eliminated(_actor: Node3D) -> void:
	if phase in ["won","lost","menu"]: return
	if mission.kind == "capture":
		failure_reason = "信使死亡，活口委托失败"
		_finish(false)
	else:
		loot = 1
		score += 2000
		_toast("灰狐已确认  /  委托完成 +2,000")
		_begin_escape()

func _interact() -> void:
	if paused: return
	if phase == "intro":
		_finish_intro()
	elif phase == "loot":
		if mission.kind == "collect":
			for i in loot_objects.size():
				if not loot_collected[i] and player.position.distance_to(LOOT_POSITIONS[i]) < 2.65:
					loot_collected[i] = true
					loot_objects[i].visible = false
					loot += 1
					score += 1000
					_play_tone(740,0.16,0.25)
					_toast("%s %d / %d  ·  +1,000" % [mission.item,loot,mission.required])
					if loot >= int(mission.required):
						_begin_escape()
					else:
						_say("队友 · 白鸦","已拿到一份，还剩 %d 份。我们守住通道。"%(int(mission.required)-loot),3.3,true)
					return
		elif mission.kind == "capture" and is_instance_valid(mission_target) and player.position.distance_to(mission_target.position)<2.65:
			if mission_target.capture(player):
				loot = 1
				score += 2000
				_toast("信使已控制  /  保持目标存活")
				_begin_escape()
	elif phase == "escape" and player.position.distance_to(_escape_position()) < 4.6:
		if _escort_ready(): _finish(true)
		else: _toast("信使还没到车边，返回接应他")

func _on_action(action_name: String,pressed: bool) -> void:
	if pressed and action_name.begins_with("skin_"):
		var selected := int(action_name.trim_prefix("skin_"))
		if progress.equip_skin(selected):
			skin_index = selected
			player.set_skin(skin_index)
			if qa_mode.is_empty(): progress.save_profile()
			_toast("已装备皮肤："+str(progress.SKINS[selected].name))
		else: _toast("完成更多任务以解锁这款皮肤")
		return
	if pressed and action_name.begins_with("equip_"):
		player.switch_weapon(int(action_name.trim_prefix("equip_")))
		arsenal_open = false
		_set_paused(false)
		return
	if action_name in ["fire","sprint","jump"]:
		if not paused:
			player.virtual_action(action_name,pressed)
		return
	if not pressed:
		return
	match action_name:
		"start","restart": _start_game()
		"pause": _set_paused(true)
		"resume":
			arsenal_open = false
			_set_paused(false)
		"touch":
			touch_enabled = not touch_enabled
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not touch_enabled and phase in ["approach","loot","escape"] and not paused else Input.MOUSE_MODE_VISIBLE
		"aim":
			if not paused:
				touch_aim = not player.aiming
				player.virtual_action("aim",touch_aim)
		"melee": player.virtual_action("melee",true)
		"reload": player.reload_weapon()
		"interact": _interact()
		"switch": player.cycle_weapon()
		"grenade": _throw_grenade(false)
		"smoke": _throw_grenade(true)
		"arsenal":
			arsenal_open = true
			_set_paused(true)
		"skip":
			if phase == "intro": _finish_intro()
		"menu":
			_set_paused(false)
			if phase in ["intro","approach","loot","escape"]:
				failure_reason = "任务中止"
				_finish(false)
			phase = "menu"
			phase_time = 0.0
			player.set_enabled(false)
			for actor in get_tree().get_nodes_in_group("actors"): actor.active = false
			cinematic.make_current()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	soundtrack.set_paused(value)
	player.set_enabled(not value and phase in ["approach","loot","escape"])
	player.set_touch_move(Vector2.ZERO)
	player.virtual_action("fire",false)
	player.virtual_action("sprint",false)
	for actor in get_tree().get_nodes_in_group("actors"):
		actor.active = not value and phase in ["approach","loot","escape"]
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not value and not touch_enabled else Input.MOUSE_MODE_VISIBLE

func _on_shot(origin: Vector3,direction: Vector3,damage: float,shot_range: float) -> void:
	if paused or not phase in ["approach","loot","escape"]:
		return
	var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*shot_range,3)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end := origin+direction*shot_range
	if not hit.is_empty():
		end = hit.position
		var collider: Object = hit.collider
		if collider.has_method("apply_damage"):
			var headshot: bool = end.y-collider.global_position.y > 1.5
			collider.apply_damage(damage*(1.8 if headshot else 1.0))
			hit_marker = 0.18
			_blood_impact(end,direction)
			_play_tone(120,0.075,0.16)
		else:
			_sparks(end)
	_tracer(origin+player.camera.global_basis.x*0.18-player.camera.global_basis.y*0.16,end,Color("ffe4ac"),0.045)

func _on_melee() -> void:
	if paused or not phase in ["approach","loot","escape"]:
		return
	for enemy in get_tree().get_nodes_in_group("enemies")+get_tree().get_nodes_in_group("mission_targets"):
		var direction: Vector3 = enemy.global_position-player.global_position
		if direction.length() < 2.6 and direction.normalized().dot(-player.camera.global_basis.z)>0.3:
			enemy.apply_damage(70.0)
			hit_marker = 0.22
			_toast("近战命中")
			break

func _spawn_crew() -> void:
	for i in 2:
		var actor := ActorScript.new()
		actor.process_mode = Node.PROCESS_MODE_PAUSABLE
		actor.setup(false,i)
		actor.position = Vector3(-1.7 if i==0 else 1.1,0,4.0 if i==0 else 3.2)
		add_child(actor)
		actor.attack.connect(_on_actor_attack)
		crew.append(actor)

func _spawn_police_wave() -> void:
	if police_spawned==0: soundtrack.set_stage("combat")
	spawn_cooldown = 16.0
	for i in 3:
		var actor := ActorScript.new()
		actor.process_mode = Node.PROCESS_MODE_PAUSABLE
		actor.setup(true,police_spawned)
		actor.position = Vector3(-12.0+float(i)*10.0,0,3.0+float(police_spawned%3)*1.4)
		add_child(actor)
		actor.target = player
		actor.active = true
		actor.attack.connect(_on_actor_attack)
		actor.eliminated.connect(_on_eliminated)
		police_spawned += 1
	if world.has_method("set_alarm"):
		world.set_alarm(true)
	_play_tone(380,0.4,0.2)

func _on_actor_attack(origin: Vector3,end: Vector3,enemy: bool) -> void:
	if paused:
		return
	for zone in smoke_zones:
		var closest := Geometry3D.get_closest_point_to_segment(zone.position,origin,end)
		if closest.distance_to(zone.position) < 4.2:
			return
	_tracer(origin,end,Color("ff8e72") if enemy else Color("bfffd9"),0.085)
	if enemy and damage_grace <= 0.0 and rng.randf() > 0.22:
		player.take_damage(6.0 if phase != "escape" else 7.0)
		damage_grace = 0.36
		hit_flash = 0.4

func _on_eliminated(_actor: Node3D) -> void:
	score += 250
	kills += 1
	_toast("击败增援  +250")
	_play_tone(530,0.08,0.13)

func _nearest_enemy(pos: Vector3) -> Node3D:
	var closest: Node3D
	var distance := 28.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var d: float = enemy.position.distance_to(pos)
		if d < distance:
			distance = d
			closest = enemy
	return closest

func _escape_position() -> Vector3:
	return world.get_escape_position()

func _finish(success: bool) -> void:
	if phase in ["won","lost"]: return
	phase = "won" if success else "lost"
	phase_time = 0.0
	player.set_enabled(false)
	player.virtual_action("fire",false)
	for actor in get_tree().get_nodes_in_group("actors"): actor.active = false
	if success:
		result_bonus = int(mission.reward)+maxi(0,3000-int(elapsed)*10)
		score += result_bonus
		_say("司机 · 米洛","特务 91，全员上车。抓稳，我们回家。",5.0,true)
	else:
		_say("队友 · 幽灵","听得到吗？坚持住……行动中止。",5.0,true)
	var settlement: Dictionary = progress.settle(success,int(float(mission.reward)/5.0))
	currency_delta = int(settlement.delta)
	new_skin = str(settlement.unlocked)
	if qa_mode.is_empty(): progress.save_profile()
	if score > best_score:
		best_score = score
		if qa_mode.is_empty():
			persist_config.set_value("scores","best",best_score)
			persist_config.save("user://nightfall.cfg")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _say(speaker: String,line: String,duration: float=4.0,urgent: bool=false) -> void:
	if urgent:
		dialogue_queue.clear()
		dialogue_remaining = 0.0
	dialogue_queue.append({"speaker":speaker,"text":line,"duration":duration})

func _update_dialogue(delta: float) -> void:
	dialogue_remaining = maxf(0,dialogue_remaining-delta)
	if dialogue_remaining <= 0 and not dialogue_queue.is_empty():
		var line: Dictionary = dialogue_queue.pop_front()
		dialogue_speaker = line.speaker
		dialogue_text = line.text
		dialogue_remaining = line.duration
	elif dialogue_remaining <= 0:
		dialogue_text = ""
		dialogue_speaker = ""

func _toast(message: String) -> void:
	toast = message
	toast_time = 3.0

func _update_hud() -> void:
	if not is_instance_valid(hud): return
	var objective := str(mission.name)
	var subobjective := str(mission.brief)
	match phase:
		"intro":
			objective = "乘车前往"+str(mission.place)
			subobjective = str(mission.brief)
		"approach":
			objective = "01  进入"+str(mission.place)
			subobjective = "跟随幽灵和白鸦，穿过正门"
		"loot":
			if mission.kind == "collect":
				objective = "02  收集%d份%s"%[mission.required,mission.item]
				subobjective = "接近发光箱子，点击交互或按 E"
			elif mission.kind == "eliminate":
				objective = "02  找到并暗杀灰狐"
				subobjective = "目标在后方办公室，跟随金色标记"
			else:
				objective = "02  控制信使，保持活口"
				subobjective = "靠近信使，点击交互或按 E"
		"escape":
			objective = "03  带信使登车撤离" if mission.kind=="capture" else "03  返回车辆，完成撤离"
			subobjective = "撤离 +%d 分，另有速度奖励"%int(mission.reward)
	var markers: Array = []
	if phase in ["approach","loot","escape"]:
		if phase == "approach":
			_append_marker(markers,Vector3(0,3,-13),str(mission.place)+"入口",Color("bfffd9"))
		elif phase == "loot" and mission.kind == "collect":
			for i in loot_objects.size():
				if not loot_collected[i]: _append_marker(markers,LOOT_POSITIONS[i]+Vector3(0,1.8,0),str(mission.item)+" %d"%(i+1),Color("f4d295"))
		if is_instance_valid(mission_target) and mission_target.alive:
			_append_marker(markers,mission_target.global_position+Vector3(0,2.7,0),"信使 · 护送" if mission_target.captured else ("信使 · 保持活口" if mission.kind=="capture" else "灰狐 · 暗杀目标"),Color("f4d295"))
		if phase == "escape":
			_append_marker(markers,_escape_position()+Vector3(0,3.2,0),"撤离车辆",Color("bfffd9"))
	var weapon_name: String = player.get_weapon_name()
	hud.set_state({
		"phase":phase,"paused":paused,"objective":objective,"subobjective":subobjective,
		"health":player.health,"ammo":player.ammo,"reserve":player.reserve,
		"weapon":weapon_name,"weapon_index":player.weapon_index,"aiming":player.aiming,"reloading":player.reloading,
		"score":score,"loot":loot,"police_eta":police_eta if alarm else -1.0,
		"elapsed":elapsed,"heat":0 if not alarm else (1 if police_eta>0 else 3),
		"tip":interaction_prompt,"toast":toast,"toast_time":toast_time,
		"hit_flash":hit_flash,"hit_marker":hit_marker,"compass":fposmod(-rad_to_deg(player.rotation.y),360),
		"touch_enabled":touch_enabled,"markers":markers,"success":phase=="won",
		"result_bonus":result_bonus,"kills":kills,"best_score":best_score,
		"dialogue_speaker":dialogue_speaker,"dialogue_text":dialogue_text,
		"dialogue_visible":dialogue_remaining>0 and phase!="menu"
		,"grenades":grenades,"smoke_grenades":smoke_grenades,"arsenal_open":arsenal_open,
		"weapons":player.weapon_names,
		"mission_name":mission.name,"mission_number":mission_number,"mission_item":mission.item,
		"mission_required":mission.required,"mission_kind":mission.kind,"mission_brief":mission.brief,
		"target_status":("已撤离" if phase=="won" else ("护送中" if loot>0 else "待控制")) if mission.kind=="capture" else ("已确认" if loot>0 else "待确认"),
		"failure_reason":failure_reason,"credits":progress.credits,"wins":progress.wins,
		"currency_delta":currency_delta,"new_skin":new_skin,"skins":progress.get_skins(),"skin_index":skin_index
	})

func _throw_grenade(smoke: bool) -> void:
	if paused or not phase in ["approach","loot","escape"] or throw_cooldown>0:
		return
	if (smoke and smoke_grenades<=0) or (not smoke and grenades<=0):
		_toast("投掷物已用尽")
		return
	if smoke: smoke_grenades -= 1
	else: grenades -= 1
	throw_cooldown = 0.85
	var grenade := RigidBody3D.new()
	grenade.mass = 0.5
	grenade.collision_layer = 8
	grenade.collision_mask = 1
	var physics_mat := PhysicsMaterial.new()
	physics_mat.bounce = 0.26
	physics_mat.friction = 0.8
	grenade.physics_material_override = physics_mat
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.12
	collider.shape = shape
	grenade.add_child(collider)
	_cube(grenade,Vector3.ZERO,Vector3(0.16,0.22,0.16),_material(Color("aec0bd") if smoke else Color("57684a"),0.5))
	_cube(grenade,Vector3(0,0.13,0),Vector3(0.09,0.05,0.08),_material(Color("212c30"),0.5))
	effects.add_child(grenade)
	grenade.global_position = player.camera.global_position-player.camera.global_basis.z*0.5
	grenade.linear_velocity = -player.camera.global_basis.z*11.0+Vector3.UP*3.5
	grenade.angular_velocity = Vector3(4,2,1)
	_toast("烟雾弹已投出" if smoke else "手雷已投出")
	var fuse := get_tree().create_timer(1.7,false)
	var grenade_ref: WeakRef = weakref(grenade)
	fuse.timeout.connect(func():
		var thrown: RigidBody3D = grenade_ref.get_ref()
		if thrown == null: return
		var pos: Vector3 = thrown.global_position
		thrown.queue_free()
		if smoke: _deploy_smoke(pos)
		else: _explode(pos)
	)

func _explode(pos: Vector3) -> void:
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	ball.mesh = sphere
	ball.material_override = _material(Color("ffb45f"),0,true)
	effects.add_child(ball)
	ball.position = pos
	var light := OmniLight3D.new()
	light.light_color = Color("ffb075")
	light.light_energy = 5
	light.omni_range = 12
	ball.add_child(light)
	var tween := ball.create_tween()
	tween.tween_property(ball,"scale",Vector3.ONE*3.8,0.15)
	tween.tween_property(ball,"scale",Vector3.ZERO,0.18)
	tween.tween_callback(ball.queue_free)
	_sparks(pos)
	_play_tone(58,0.7,0.7)
	for enemy in get_tree().get_nodes_in_group("enemies")+get_tree().get_nodes_in_group("mission_targets"):
		var distance: float = enemy.global_position.distance_to(pos)
		if distance < 6.0:
			var query := PhysicsRayQueryParameters3D.create(pos+Vector3.UP*0.2,enemy.global_position+Vector3.UP,1)
			if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				enemy.apply_damage(200.0*(1-distance/7.0))
	# Arcade cooperative rules: throwables do not damage the player or crew.

func _deploy_smoke(pos: Vector3) -> void:
	var center := pos+Vector3.UP*1.3
	smoke_zones.append({"position":center,"time":10.0})
	var cloud := Node3D.new()
	effects.add_child(cloud)
	cloud.position = center
	for i in 12:
		var puff := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(1.4,2.2)
		sphere.height = sphere.radius*1.8
		sphere.radial_segments = 16
		sphere.rings = 8
		puff.mesh = sphere
		var material := _material(Color(0.52,0.59,0.62,0.42))
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puff.material_override = material
		cloud.add_child(puff)
		puff.position = Vector3(rng.randf_range(-2,2),rng.randf_range(-0.2,1.3),rng.randf_range(-2,2))
		puff.scale = Vector3.ONE*0.15
		var tween := puff.create_tween()
		tween.tween_property(puff,"scale",Vector3.ONE,0.8)
		tween.tween_interval(8.5)
		tween.tween_property(material,"albedo_color:a",0.0,1.0)
	get_tree().create_timer(10.5,false).timeout.connect(cloud.queue_free)
	_toast("烟幕展开  /  阻断敌方视线 10 秒")

func _append_marker(markers: Array,pos: Vector3,label: String,color: Color) -> void:
	if not player.camera.is_position_behind(pos):
		markers.append({"screen":player.camera.unproject_position(pos),"label":label,"color":color})

func _create_loot() -> void:
	for i in loot_collected.size():
		var item := Node3D.new()
		item.position = LOOT_POSITIONS[i]
		add_child(item)
		var body_mat := _material(Color("253f39"),0.35)
		var edge_mat := _material(Color("c0c6a0"),0.65)
		_cube(item,Vector3(0,0.49,0),Vector3(1.25,0.7,0.65),body_mat)
		_cube(item,Vector3(0,0.87,0),Vector3(1.29,0.1,0.69),edge_mat)
		for x in [-0.46,0.46]: _cube(item,Vector3(x,0.52,-0.34),Vector3(0.09,0.66,0.035),edge_mat)
		_cube(item,Vector3(0,0.57,-0.345),Vector3(0.3,0.07,0.035),_material(Color("bfffd9"),0.0,true))
		_cube(item,Vector3(0,0.03,0),Vector3(1.6,0.025,1.0),_material(Color("80c6ad"),0.0,true))
		loot_objects.append(item)

func _create_cabin() -> void:
	cabin = Node3D.new()
	cinematic.add_child(cabin)
	cabin.visible = false
	var trim := _material(Color("10191e"),0.1)
	var cloth := _material(Color("303a3b"))
	_cube(cabin,Vector3(0,-0.63,-0.82),Vector3(2.6,0.45,0.68),trim)
	_cube(cabin,Vector3(0,0.78,-0.6),Vector3(2.6,0.12,1.5),cloth)
	for x in [-1.05,1.05]:
		var pillar := _cube(cabin,Vector3(x,0.08,-1.13),Vector3(0.1,1.6,0.12),cloth)
		pillar.rotation.z = -0.15*x
	_cube(cabin,Vector3(-0.55,-0.35,-0.64),Vector3(0.35,0.12,0.14),_material(Color("4d807d"),0.0,true))
	_cube(cabin,Vector3(0.28,-0.37,-0.66),Vector3(0.38,0.19,0.025),_material(Color("192f34"),0.0,true))
	for x in [-0.8,-0.25,0.75]: _cube(cabin,Vector3(x,-0.39,-1.14),Vector3(0.25,0.045,0.025),_material(Color("777f73")))

func _tracer(start: Vector3,end: Vector3,color: Color,lifetime: float) -> void:
	if start.distance_to(end) < 0.1: return
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.017,0.017,start.distance_to(end))
	mesh.mesh = box
	mesh.material_override = _material(color,0,true)
	effects.add_child(mesh)
	mesh.global_position = (start+end)*0.5
	mesh.look_at(end)
	get_tree().create_timer(lifetime,false).timeout.connect(mesh.queue_free)

func _sparks(pos: Vector3) -> void:
	for i in 3:
		var spark := _cube(effects,pos,Vector3.ONE*0.04,_material(Color("ffe0ab"),0,true))
		var tween := spark.create_tween()
		tween.tween_property(spark,"position",pos+Vector3(rng.randf_range(-0.45,0.45),rng.randf_range(0.0,0.45),rng.randf_range(-0.45,0.45)),0.16)
		tween.tween_callback(spark.queue_free)

func _blood_impact(pos: Vector3,direction: Vector3) -> void:
	var mat := _material(Color("8f2433"),0.0)
	for i in 7:
		var size := rng.randf_range(0.025,0.065)
		var droplet := _cube(effects,pos,Vector3.ONE*size,mat)
		var scatter := Vector3(rng.randf_range(-0.5,0.5),rng.randf_range(-0.1,0.55),rng.randf_range(-0.5,0.5))
		var tween := droplet.create_tween()
		tween.tween_property(droplet,"position",pos+direction*0.25+scatter,0.15)
		tween.tween_property(droplet,"position:y",maxf(0.018,pos.y-1.2),0.25).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(droplet.queue_free)
	var stain := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = rng.randf_range(0.1,0.2)
	disk.bottom_radius = disk.top_radius
	disk.height = 0.005
	disk.radial_segments = 9
	stain.mesh = disk
	stain.material_override = _material(Color("522530"))
	effects.add_child(stain)
	stain.position = Vector3(pos.x,0.013,pos.z)
	stain.scale.z = 0.6
	var fade := stain.create_tween()
	fade.tween_interval(10)
	fade.tween_property(stain,"scale",Vector3.ZERO,1.0)
	fade.tween_callback(stain.queue_free)

func _material(color: Color,metal: float=0.0,emission: bool=false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.48
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.8
	return mat

func _cube(parent: Node3D,pos: Vector3,size: Vector3,mat: Material) -> MeshInstance3D:
	var cube := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	cube.mesh = box
	cube.material_override = mat
	cube.position = pos
	parent.add_child(cube)
	return cube

func _play_tone(frequency: float,duration: float,volume: float) -> void:
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(int(duration*22050)*2)
	for i in data.size()/2:
		var t := float(i)/22050.0
		var v := sin(t*frequency*TAU)*exp(-t*14)*volume
		data.encode_s16(i*2,int(v*32767))
	audio.data = data
	sound_player.stream = audio
	sound_player.play()

func _prepare_qa() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-size="):
			var dimensions := arg.trim_prefix("--qa-size=").split("x")
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			get_window().size = Vector2i(int(dimensions[0]),int(dimensions[1]))
			get_window().content_scale_size = Vector2i.ZERO
			get_window().content_scale_factor = 1.0
	var forced := "bank"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mission="): forced = arg.trim_prefix("--mission=")
	if qa_mode != "menu":
		_start_game(forced)
		if qa_mode != "intro":
			_finish_intro()
			if qa_mode in ["lobby","scope","portrait","landscape","result","flow","target","skin"]:
				player.position = Vector3(0,0.15,-16)
				phase = "loot"
				alarm = true
				police_eta = 28.0
				toast_time = 0.0
				_say("队友 · 白鸦",str(mission.inside),4.2,true)
			if qa_mode in ["target","skin"]:
				player.position = Vector3(0,0.15,-28.7)
				player.rotation.y = 0
			if qa_mode == "scope":
				player.switch_weapon(4)
				player.virtual_action("aim",true)
			if qa_mode == "skins":
				hud._dispatch_action("open_skins",true)
			if qa_mode == "arsenal":
				_on_action("arsenal",true)
			if qa_mode == "combat":
				phase = "escape"
				loot = 3
				alarm = true
				police_eta = 0
				player.position = Vector3(0,0.15,-7)
				player.rotation.y = PI
				_spawn_police_wave()
				toast_time = 0.0
				_say("队友 · 幽灵","特务 91，警察到了！我们掩护你，回车上！",5,true)
			if qa_mode == "result":
				loot = 3
				score = 4250
				kills = 5
				elapsed = 98
				_finish(true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--skin="):
			progress.wins = 8
			skin_index = clampi(int(arg.trim_prefix("--skin=")),0,4)
			player.set_skin(skin_index)
	if qa_mode == "flow":
		await _qa_flow()
		return
	await get_tree().create_timer(1.5).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://screenshots/"+qa_mode+"_"+forced+("_"+str(skin_index) if qa_mode=="skin" else "")+".png")
		print("QA_CAPTURE ",qa_mode," ",img.get_size()," window=",get_window().size," viewport=",get_viewport().get_visible_rect().size)
	else:
		print("QA_HEADLESS_READY ",qa_mode)
	get_tree().quit()

func _qa_flow() -> void:
	var errors: Array[String] = []
	_update_hud()
	await get_tree().process_frame
	await get_tree().physics_frame
	# Move with physics through entrance and center aisle, checking real collisions.
	player.position = Vector3(0,0.05,-8)
	player.rotation.y = 0
	player.set_touch_move(Vector2(0,-1))
	await get_tree().create_timer(4.4).timeout
	player.set_touch_move(Vector2.ZERO)
	if player.position.z > -24: errors.append("Center aisle movement blocked at %s"%player.position)
	for i in LOOT_POSITIONS.size():
		player.position = LOOT_POSITIONS[i]+Vector3(0,0.05,1.5)
		await get_tree().physics_frame
		_interact()
	if loot != 3 or phase != "escape": errors.append("Loot progression failed")
	_spawn_police_wave()
	var enemy: Node3D = get_tree().get_nodes_in_group("enemies")[0]
	var old_score := score
	# Shoot with the real raycast from an unobstructed position.
	player.position = enemy.position+Vector3(0,0,4)
	await get_tree().physics_frame
	var from := player.position+Vector3(0,1.3,0)
	_on_shot(from,(enemy.position+Vector3(0,1.3,0)-from).normalized(),150.0,100.0)
	if score <= old_score: errors.append("Hitscan elimination failed")
	var grenade_score := score
	var blast_target: Node3D = get_tree().get_nodes_in_group("enemies")[0]
	_explode(blast_target.position+Vector3(0,0.4,0))
	if score <= grenade_score: errors.append("Grenade area damage failed")
	_throw_grenade(true)
	if smoke_grenades != 2: errors.append("Smoke inventory failed")
	await get_tree().create_timer(1.9).timeout
	if smoke_zones.is_empty(): errors.append("Thrown smoke fuse failed")
	else:
		var previous_health: float = player.health
		var center: Vector3 = smoke_zones[0].position
		_on_actor_attack(center-Vector3(2,0,0),center+Vector3(2,0,0),true)
		if player.health != previous_health: errors.append("Smoke failed to block shooting")
	var old_yaw: float = player.rotation.y
	player.apply_look_delta(Vector2(100,0))
	if is_equal_approx(old_yaw,player.rotation.y): errors.append("Swipe look failed")
	_set_paused(true)
	var paused_yaw: float = player.rotation.y
	player.apply_look_delta(Vector2(100,0))
	if not is_equal_approx(paused_yaw,player.rotation.y): errors.append("Pause does not block look")
	_set_paused(false)
	player.position = _escape_position()+Vector3(3,0.05,0)
	_interact()
	if phase != "won" or result_bonus < 5000: errors.append("Escape result failed")
	_start_game()
	_finish_intro()
	player.take_damage(400.0)
	await get_tree().create_timer(0.12).timeout
	if phase != "lost": errors.append("Failure state failed")
	_start_game()
	if score != 0 or loot != 0 or player.health <= 0: errors.append("Restart reset failed")
	if errors.is_empty():
		print("QA_FLOW_PASS: physical movement, loot, hitscan score, grenade damage, smoke fuse and cover, swipe, pause, extraction, failure, restart")
	else:
		for error in errors: push_error("QA_FLOW_FAIL: "+error)
	await get_tree().process_frame
	await get_tree().process_frame
	for audio_node in find_children("*","AudioStreamPlayer",true,false):
		audio_node.stop()
		audio_node.stream = null
	await get_tree().create_timer(0.12).timeout
	get_tree().quit(0 if errors.is_empty() else 1)
