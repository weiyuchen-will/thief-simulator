extends SceneTree
var failures: Array[String] = []
var moves: Array[Vector2] = []
var looks: Array[Vector2] = []
var actions: Array[String] = []
const WEAPONS: Array[String] = ["CAR-9 突击步枪", "P12 战术手枪", "M870 霰弹枪", "VECTOR 冲锋枪", "SVD 狙击步枪", "M249 轻机枪", "AS VAL 微声步枪"]
const MISSIONS: Array[Dictionary] = [
	{"mission_name":"银行资产回收", "mission_number":1, "mission_item":"资产箱", "mission_required":3, "loot":2, "mission_kind":"collect", "target_status":"待定位"},
	{"mission_name":"住宅情报回收", "mission_number":2, "mission_item":"情报箱", "mission_required":2, "loot":1, "mission_kind":"collect", "target_status":"待定位"},
	{"mission_name":"精准暗杀", "mission_number":3, "mission_item":"目标", "mission_required":1, "loot":1, "mission_kind":"eliminate", "target_status":"已完成"},
	{"mission_name":"控制与护送", "mission_number":4, "mission_item":"目标", "mission_required":1, "loot":0, "mission_kind":"capture", "target_status":"已控制"}
]
const SKINS: Array[Dictionary] = [
	{"index":0,"name":"原型·夜行","required":0,"color":Color("91a9ae"),"secondary":Color("25333a")},
	{"index":1,"name":"极光·青锋","required":1,"color":Color("78ffe0"),"secondary":Color("203f49")},
	{"index":2,"name":"赤焰·熔核","required":3,"color":Color("ff9856"),"secondary":Color("772e35")},
	{"index":3,"name":"紫电·脉冲","required":5,"color":Color("b99aff"),"secondary":Color("4de9eb")},
	{"index":4,"name":"黑金·特务91","required":8,"color":Color("efd083"),"secondary":Color("272527")}
]
func skin_catalog(wins: int) -> Array:
	var entries: Array = []
	for skin in SKINS:
		var entry: Dictionary = skin.duplicate()
		entry.unlocked = wins >= int(entry.required)
		entries.append(entry)
	return entries
func tap_mouse(hud, position: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = true
	hud._input(event)
	event.pressed = false
	hud._input(event)
func _initialize() -> void:
	call_deferred("run")
func fail(message: String) -> void:
	failures.append(message)
func run() -> void:
	for screen_size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(720,480),Vector2i(844,390),Vector2i(390,844)]:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = screen_size
		root.add_child(viewport)
		var hud = load("res://scripts/hud.gd").new()
		viewport.add_child(hud)
		hud.action.connect(func(name:String,pressed:bool):actions.append(name+":"+str(pressed)))
		await process_frame
		for phase in ["menu", "intro", "approach", "won", "lost", "paused", "arsenal", "skins", "menu_skins"]:
			var is_arsenal: bool = phase in ["arsenal","skins"]
			var actual_phase: String = "approach" if phase in ["paused","arsenal","skins"] else ("menu" if phase == "menu_skins" else phase)
			hud.set_state({"phase":actual_phase, "paused":phase == "paused" or is_arsenal, "arsenal_open":is_arsenal, "weapons":WEAPONS,"weapon":WEAPONS[0], "skins":skin_catalog(3), "skin_index":2, "wins":3, "credits":4500, "currency_delta":1400 if phase == "won" else (-300 if phase == "lost" else 0), "new_skin":"赤焰·熔核" if phase == "won" else "", "failure_reason":"信使死亡，活口委托失败" if phase == "lost" else ""})
			if phase in ["arsenal","skins"]:
				var tabs: Dictionary = hud.debug_layout().rectangles
				tap_mouse(hud, tabs["tab_skins" if phase == "skins" else "tab_weapons"].get_center())
			elif phase == "menu_skins":
				actions.clear()
				tap_mouse(hud, hud.debug_layout().rectangles.open_skins.get_center())
				if not actions.has("arsenal:true"):
					fail(str(screen_size) + " main menu skins entry did not open arsenal")
				hud.set_state({"paused":true,"arsenal_open":true})
			var info: Dictionary = hud.debug_layout()
			var bounds: Rect2 = Rect2(Vector2.ZERO, screen_size)
			var rects: Dictionary = info.rectangles
			var rect_keys: Array = rects.keys()
			for i in range(rect_keys.size()):
				var key: String = rect_keys[i]
				if not bounds.encloses(rects[key]):
					fail(str(screen_size) + " " + phase + " rect outside: " + key)
				for j in range(i + 1, rect_keys.size()):
					if rects[key].intersects(rects[rect_keys[j]]):
						fail(str(screen_size) + " " + phase + " rectangles overlap: " + key + "/" + rect_keys[j])
			var circles: Dictionary = info.circles
			var keys: Array = circles.keys()
			var joy: Vector2 = info.joystick.get_center()
			var joy_radius: float = info.joystick.size.x * 0.5
			for i in range(keys.size()):
				var circle: Dictionary = circles[keys[i]]
				var extent: Rect2 = Rect2(circle.center - Vector2.ONE * circle.radius, Vector2.ONE * circle.radius * 2)
				if not bounds.encloses(extent):
					fail(str(screen_size) + " " + phase + " circle outside: " + str(keys[i]))
				if circle.center.distance_to(joy) < circle.radius + joy_radius + 6:
					fail(str(screen_size) + " joystick overlap: " + str(keys[i]))
				if extent.intersects(info.status):
					fail(str(screen_size) + " status overlap: " + str(keys[i]))
				for rect_key in rect_keys:
					if extent.intersects(rects[rect_key]):
						fail(str(screen_size) + " circle/rect overlap: " + str(keys[i]) + "/" + rect_key)
				for j in range(i + 1, keys.size()):
					var other: Dictionary = circles[keys[j]]
					if circle.center.distance_to(other.center) < circle.radius + other.radius + 6:
						fail(str(screen_size) + " overlapping touch hits: " + str(keys[i]) + "/" + str(keys[j]))
			if phase == "arsenal":
				for i in range(7):
					var event: InputEventMouseButton = InputEventMouseButton.new()
					event.button_index = MOUSE_BUTTON_LEFT
					event.position = rects["equip_%d" % i].get_center()
					event.pressed = true
					hud._input(event)
					event.pressed = false
					hud._input(event)
					if not actions.has("equip_%d:true" % i):
						fail(str(screen_size) + " weapon card input failed: " + str(i))
				actions.clear()
			if phase in ["skins","menu_skins"]:
				if info.armory_tab != "skins" or info.skins.size() != 5:
					fail(str(screen_size) + " skins catalog/tab failed")
				for skin in info.skins:
					if bool(skin.unlocked) != (int(skin.required) <= 3) or bool(skin.selected) != (int(skin.index) == 2):
						fail(str(screen_size) + " skin lock/selection presentation failed")
				for index in range(5):
					actions.clear()
					tap_mouse(hud, rects["skin_%d" % index].get_center())
					if not actions.has("skin_%d:true" % index):
						fail(str(screen_size) + " skin card click failed: " + str(index))
				var skin_touch: InputEventScreenTouch = InputEventScreenTouch.new()
				skin_touch.index = 19
				skin_touch.position = rects.skin_4.get_center()
				skin_touch.pressed = true
				actions.clear()
				hud._input(skin_touch)
				skin_touch.pressed = false
				hud._input(skin_touch)
				if not actions.has("skin_4:true"):
					fail(str(screen_size) + " locked skin touch failed")
				if hud.debug_layout().skins[2].selected != true:
					fail(str(screen_size) + " locked skin changed selected state without main authorization")
				tap_mouse(hud, rects.tab_weapons.get_center())
				if not hud.debug_layout().rectangles.has("equip_6"):
					fail(str(screen_size) + " skins-to-weapons tab navigation failed")
			hud.surface.queue_redraw()
			await process_frame
		for settlement in [{"currency_delta":1600,"credits":4500,"wins":3,"new_skin":"赤焰·熔核","failure_reason":""},{"currency_delta":-300,"credits":700,"wins":0,"new_skin":"","failure_reason":"任务中止"},{"currency_delta":-175,"credits":0,"wins":0,"new_skin":"","failure_reason":"行动失败"},{"currency_delta":0,"credits":0,"wins":0,"new_skin":"","failure_reason":"行动失败"}]:
			hud.set_state(settlement)
			hud.set_state({"phase":"won" if int(settlement.currency_delta) > 0 else "lost", "paused":false,"arsenal_open":false})
			var displayed_settlement: Dictionary = hud.debug_layout().settlement
			if displayed_settlement.delta != settlement.currency_delta or displayed_settlement.balance != settlement.credits or displayed_settlement.new_skin != settlement.new_skin or displayed_settlement.failure_reason != settlement.failure_reason:
				fail(str(screen_size) + " settlement data was altered")
			if int(settlement.currency_delta) == -175 and displayed_settlement.delta_text != "-175":
				fail(str(screen_size) + " balance-floor settlement displayed full 300 penalty")
			if int(settlement.currency_delta) > 0:
				actions.clear()
				tap_mouse(hud, hud.debug_layout().rectangles.open_skins.get_center())
				if not actions.has("arsenal:true"):
					fail(str(screen_size) + " result unlock notice did not open skins")
			hud.surface.queue_redraw()
			await process_frame
		for mission in MISSIONS:
			hud.set_state(mission)
			for mission_phase in ["approach", "won", "lost"]:
				hud.set_state({"phase":mission_phase,"paused":false,"arsenal_open":false})
				var displayed: Dictionary = hud.debug_layout().mission
				if displayed.name != mission.mission_name or displayed.number != mission.mission_number:
					fail(str(screen_size) + " mission identity did not update: " + mission.mission_name)
				if displayed.item != mission.mission_item or displayed.required != mission.mission_required or displayed.completed != mission.loot:
					fail(str(screen_size) + " mission item/count did not update: " + mission.mission_name)
				if displayed.count != "%d / %d" % [mission.loot, mission.mission_required]:
					fail(str(screen_size) + " fixed mission denominator: " + mission.mission_name)
				if mission.mission_kind in ["capture","eliminate"] and (not displayed.has_target or displayed.target_status != mission.target_status):
					fail(str(screen_size) + " target status did not update: " + mission.mission_name)
				hud.surface.queue_redraw()
				await process_frame
		print("LAYOUT + ARMORY/SKINS + SETTLEMENT + FOUR MISSIONS ", screen_size)
		moves.clear()
		looks.clear()
		actions.clear()
		hud.set_state({"phase":"approach","paused":false,"arsenal_open":false})
		hud.move_input.connect(func(value:Vector2):moves.append(value))
		hud.look_input.connect(func(value:Vector2):looks.append(value))
		var info: Dictionary = hud.debug_layout()
		var joy: Vector2 = info.joystick.get_center()
		var fire: Vector2 = info.circles.fire.center
		for value in [[0,joy+Vector2(15,-15)],[1,fire],[2,Vector2(screen_size.x * 0.60, screen_size.y * 0.42)]]:
			var event: InputEventScreenTouch = InputEventScreenTouch.new()
			event.index = value[0]
			event.position = value[1]
			event.pressed = true
			hud._input(event)
		var drag: InputEventScreenDrag = InputEventScreenDrag.new()
		drag.index = 2
		drag.position = Vector2(screen_size.x * 0.60 + 15, screen_size.y * 0.42 - 9)
		drag.relative = Vector2(15,-9)
		hud._input(drag)
		for index in [0,1,2]:
			var event: InputEventScreenTouch = InputEventScreenTouch.new()
			event.index = index
			event.pressed = false
			hud._input(event)
		if moves.is_empty() or moves[0].length() < 0.1 or moves[-1] != Vector2.ZERO:
			fail("Touch movement start/stop failed")
		if looks != [Vector2(15,-9)]:
			fail("Independent swipe look failed")
		if not actions.has("fire:true") or not actions.has("fire:false"):
			fail("Independent held fire failed")
		for key in info.circles.keys():
			var tap: InputEventScreenTouch = InputEventScreenTouch.new()
			tap.index = 8
			tap.position = info.circles[key].center
			tap.pressed = true
			hud._input(tap)
			tap.pressed = false
			hud._input(tap)
			if not actions.has(key + ":true"):
				fail("Utility touch failed: " + key)
		var arsenal_tap: InputEventScreenTouch = InputEventScreenTouch.new()
		arsenal_tap.index = 9
		arsenal_tap.position = info.rectangles.arsenal.get_center()
		arsenal_tap.pressed = true
		hud._input(arsenal_tap)
		arsenal_tap.pressed = false
		hud._input(arsenal_tap)
		if not actions.has("arsenal:true"):
			fail(str(screen_size) + " arsenal touch entry failed")
		hud.set_state({"paused":true,"arsenal_open":true})
		var arsenal_layout: Dictionary = hud.debug_layout()
		actions.clear()
		arsenal_tap.position = arsenal_layout.rectangles.equip_6.get_center()
		arsenal_tap.pressed = true
		hud._input(arsenal_tap)
		arsenal_tap.pressed = false
		hud._input(arsenal_tap)
		if not actions.has("equip_6:true"):
			fail(str(screen_size) + " weapon card touch failed")
		print("MULTITOUCH + ALL ACTION BUTTONS + TOUCH WEAPON CARD ", screen_size)
		viewport.queue_free()
		await process_frame
	if failures.is_empty():
		print("AGENT SIMULATOR HUD CHECKS PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
