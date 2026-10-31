extends SceneTree
## Synthetic touch and trackpad events exercise the real HUD-to-player signal path.
## This does not replace testing input delivery on a physical phone or trackpad.

const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(720, 480), Vector2i(844, 390), Vector2i(390, 844)]
const DRIFT: Vector2 = Vector2(24.0, -12.0)
const EPSILON: float = 0.00001

var failures: Array[String] = []
var look_events: Array[Vector2] = []
var move_events: Array[Vector2] = []
var action_events: Array[String] = []
var contacts: Dictionary = {}
var viewport: SubViewport
var hud: CanvasLayer
var player: CharacterBody3D
var screen_label: String = ""
var case_label: String = ""
var left_blank: Vector2
var right_blank: Vector2
var other_right_blank: Vector2
var joystick: Vector2
var fire_button: Vector2
var normal_turn: Vector2


func _initialize() -> void:
	for binding: String in ["move_left", "move_right", "move_forward", "move_back", "sprint", "jump", "fire", "aim", "reload", "interact", "melee"]:
		if not InputMap.has_action(binding):
			InputMap.add_action(binding)
	call_deferred("run")


func run() -> void:
	for screen_size: Vector2i in SIZES:
		screen_label = str(screen_size)
		viewport = SubViewport.new()
		viewport.size = screen_size
		root.add_child(viewport)
		player = load("res://scripts/player.gd").new()
		viewport.add_child(player)
		hud = load("res://scripts/hud.gd").new()
		viewport.add_child(hud)
		await process_frame
		player.set_process(false)
		player.set_physics_process(false)
		hud.look_input.connect(func(delta: Vector2) -> void:
			look_events.append(delta)
			player.apply_look_delta(delta)
		)
		hud.move_input.connect(func(value: Vector2) -> void:
			move_events.append(value)
			player.set_touch_move(value)
		)
		hud.action.connect(func(name: String, pressed: bool) -> void:
			action_events.append(name + ":" + str(pressed))
			if name in ["fire", "aim", "sprint"]:
				player.virtual_action(name, pressed)
		)
		_reset("setup")
		var layout: Dictionary = hud.debug_layout()
		joystick = layout.joystick.get_center()
		fire_button = layout.circles.fire.center
		left_blank = _blank_point(Vector2(0.20, 0.38), false)
		right_blank = _blank_point(Vector2(0.54, 0.38), true)
		other_right_blank = _blank_point(Vector2(0.74, 0.48), true)
		_check(left_blank != Vector2.ZERO and right_blank != Vector2.ZERO and other_right_blank != Vector2.ZERO, "could not find unobstructed touch positions")
		_check(right_blank.distance_to(other_right_blank) > 15.0, "two view contacts overlap")

		# Establish the actual controller's camera response, without reimplementing it.
		player.apply_look_delta(DRIFT)
		normal_turn = _view()
		_check(normal_turn.x < 0.0 and normal_turn.y > 0.0, "controller yaw/pitch direction is incorrect")
		_test_single_and_mean()
		_test_membership_changes()
		_test_controls_are_independent()
		_test_drag_while_firing()
		_test_cleanup()
		_test_pan_gestures()
		_test_aim_sensitivity()
		print("GESTURE_VIEWPORT_CHECKED ", screen_size)
		hud._release_pointers()
		player.set_enabled(false)
		viewport.queue_free()
		await process_frame
	# Let the audio server release any synthesized shot buffers used by held fire.
	await create_timer(0.12).timeout
	if failures.is_empty():
		print("GESTURE_SMOKE_OK: five viewport sizes, single/two-finger look, mean sensitivity, held-fire dragging, full 360 turns, vertical aim, control isolation, release/cancel/pause/focus cleanup, trackpad pan and scope sensitivity")
		quit(0)
	else:
		for failure: String in failures:
			print("GESTURE_FAILURE ", failure)
		push_error("Gesture checks failed: %d assertions" % failures.size())
		quit(1)


func _test_single_and_mean() -> void:
	_reset("single right contact")
	_touch(0, right_blank)
	_drag(0, DRIFT)
	_expect(DRIFT, normal_turn)
	_touch(0, right_blank, false)

	_reset("single left blank can turn freely")
	_touch(0, left_blank)
	_drag(0, DRIFT)
	_expect(DRIFT, normal_turn)

	_reset("two right contacts use their mean")
	_touch(0, right_blank)
	_touch(1, other_right_blank)
	_drag(0, DRIFT)
	_expect(DRIFT * 0.5, normal_turn * 0.5)
	_drag(1, DRIFT)
	_expect(DRIFT, normal_turn)

	_reset("left and right blanks move the camera together")
	_touch(0, left_blank)
	_touch(1, right_blank)
	_drag(0, DRIFT)
	_drag(1, DRIFT)
	_expect(DRIFT, normal_turn)

	_reset("unequal two-contact motion is averaged")
	_touch(0, left_blank)
	_touch(1, right_blank)
	_drag(0, DRIFT)
	_drag(1, DRIFT * 0.25)
	_expect(DRIFT * 0.625, normal_turn * 0.625)

	_reset("opposed pinch motion cancels")
	_touch(0, left_blank)
	_touch(1, right_blank)
	_drag(0, DRIFT)
	_drag(1, -DRIFT)
	_expect(Vector2.ZERO, Vector2.ZERO)
	_check(not look_events.is_empty(), "opposed-motion test did not exercise the look signal")
	_drag(1, DRIFT)
	_drag(0, -DRIFT)
	_expect(Vector2.ZERO, Vector2.ZERO)


func _test_membership_changes() -> void:
	_reset("adding and lifting fingers does not jump")
	_touch(0, right_blank)
	_drag(0, DRIFT)
	var event_count: int = look_events.size()
	_touch(1, left_blank)
	_check(look_events.size() == event_count, "adding a distant finger emitted a position jump")
	_expect(DRIFT, normal_turn)
	_drag(0, DRIFT)
	_drag(1, DRIFT)
	_expect(DRIFT * 2.0, normal_turn * 2.0)
	event_count = look_events.size()
	_touch(1, contacts[1], false)
	_check(look_events.size() == event_count, "lifting a finger emitted a position jump")
	_expect(DRIFT * 2.0, normal_turn * 2.0)
	_drag(0, DRIFT)
	_expect(DRIFT * 3.0, normal_turn * 3.0)

	_reset("either remaining contact continues without jumps")
	_touch(0, left_blank)
	_drag(0, DRIFT)
	_touch(1, right_blank)
	_expect(DRIFT, normal_turn)
	_drag(0, DRIFT)
	_drag(1, DRIFT)
	_expect(DRIFT * 2.0, normal_turn * 2.0)
	_touch(1, contacts[1], false)
	_drag(0, DRIFT)
	_expect(DRIFT * 3.0, normal_turn * 3.0)
	_touch(2, other_right_blank)
	_expect(DRIFT * 3.0, normal_turn * 3.0)
	_drag(0, DRIFT)
	_drag(2, DRIFT)
	_expect(DRIFT * 4.0, normal_turn * 4.0)
	_touch(0, contacts[0], false)
	_drag(2, DRIFT)
	_expect(DRIFT * 5.0, normal_turn * 5.0)


func _test_controls_are_independent() -> void:
	_reset("joystick and firing fingers do not reduce view sensitivity")
	_touch(8, joystick)
	_drag(8, Vector2(16.0, -16.0))
	_touch(9, fire_button)
	_touch(0, right_blank)
	_drag(0, DRIFT)
	_expect(DRIFT, normal_turn)
	_check(player._virtual_move.length() > 0.1, "joystick stopped while looking")
	_check(player._virtual_fire, "held firing stopped while looking")
	# A stationary fire finger must not halve another finger's view sensitivity.
	_expect(DRIFT, normal_turn)
	_touch(1, left_blank)
	_drag(0, DRIFT)
	_drag(1, DRIFT)
	_expect(DRIFT * 2.0, normal_turn * 2.0)
	_drag(8, Vector2(-5.0, -3.0))
	_expect(DRIFT * 2.0, normal_turn * 2.0)
	_touch(0, contacts[0], false)
	_touch(1, contacts[1], false)
	_check(player._virtual_move.length() > 0.1 and player._virtual_fire, "view release also released joystick/fire")
	_touch(8, contacts[8], false)
	_touch(9, contacts[9], false)
	_check(player._virtual_move.is_zero_approx() and not player._virtual_fire, "movement or firing remained held after release")
	_check(action_events.has("fire:true") and action_events.has("fire:false"), "fire press/release signals were lost")

	_reset("left blank turns independently of held controls")
	_touch(8, joystick)
	_touch(9, fire_button)
	_touch(0, left_blank)
	_drag(0, DRIFT)
	_expect(DRIFT, normal_turn)


func _test_drag_while_firing() -> void:
	_reset("one finger can fire and aim outside the fire button")
	var initial_ammo: int = player.ammo
	_touch(0, fire_button)
	player._process(0.12)
	_check(player.ammo < initial_ammo, "holding fire did not fire a shot")
	_drag(0, DRIFT)
	_expect(DRIFT, normal_turn)
	_check(player._virtual_fire, "dragging fire stopped held shooting")
	# Crossing other buttons must preserve the original fire contact.
	_drag(0, joystick - Vector2(contacts[0]))
	_check(player._virtual_fire, "leaving fire hit area released shooting")
	_check(player._virtual_move.is_zero_approx(), "fire drag was reassigned to joystick")
	var before_continuing: int = player.ammo
	player._process(0.12)
	_check(player.ammo < before_continuing, "fire did not continue after dragging")
	_touch(0, contacts[0], false)
	var released_ammo: int = player.ammo
	player._process(0.5)
	_check(not player._virtual_fire and player.ammo == released_ammo, "release outside button did not stop fire")

	_reset("continuous full turns and vertical aiming during fire")
	_touch(0, fire_button)
	for i in 40:
		_drag(0, Vector2(100.0, 0.0))
	var turn: Vector2 = _view()
	_check(turn.x < -TAU, "yaw stopped before a full 360 degree turn")
	for i in 80:
		_drag(0, Vector2(-100.0, 0.0))
	_check(_view().x > TAU, "yaw could not turn continuously in the other direction")
	_drag(0, Vector2(0.0, -100000.0))
	_check(_view().y > deg_to_rad(88.0) and _view().y < PI * 0.5, "upward aiming did not reach near vertical safely")
	_drag(0, Vector2(0.0, 200000.0))
	_check(_view().y < deg_to_rad(-88.0) and _view().y > -PI * 0.5, "downward aiming did not reach near vertical safely")
	_check(player._virtual_fire, "turning all directions stopped fire")

	_reset("mouse can drag the on-screen fire button")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = fire_button
	hud._input(press)
	var motion := InputEventMouseMotion.new()
	motion.relative = DRIFT
	motion.position = fire_button + DRIFT
	hud._input(motion)
	_expect(DRIFT, normal_turn)
	_check(player._virtual_fire, "mouse drag did not preserve held shooting")
	press.pressed = false
	press.position = joystick
	hud._input(press)
	_check(not player._virtual_fire, "mouse release outside fire left shooting held")


func _test_cleanup() -> void:
	for cleanup: String in ["cancel", "pause", "focus", "intro"]:
		_reset(cleanup + " clears active contacts")
		_touch(8, joystick)
		_drag(8, Vector2(16.0, -16.0))
		_touch(9, fire_button)
		_touch(0, left_blank)
		_touch(1, right_blank)
		if cleanup == "cancel":
			for index: int in [0, 1, 8, 9]:
				_touch(index, contacts[index], false, true)
		elif cleanup == "pause":
			hud.set_state({"paused": true})
		elif cleanup == "focus":
			hud._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		else:
			hud.set_state({"phase": "intro"})
		_check(player._virtual_move.is_zero_approx(), "cleanup left movement held")
		_check(not player._virtual_fire, "cleanup left firing held")
		_expect(Vector2.ZERO, Vector2.ZERO)
		# End the modal state before stale drags: suppression alone is insufficient.
		hud.set_state({"phase": "approach", "paused": false})
		for index: int in [0, 1, 8, 9]:
			_drag(index, DRIFT)
		_expect(Vector2.ZERO, Vector2.ZERO)
		_check(player._virtual_move.is_zero_approx() and not player._virtual_fire, "an orphan drag revived a canceled control")
		_touch(0, right_blank)
		_drag(0, DRIFT)
		_expect(DRIFT, normal_turn)

	for blocked: String in ["pause", "intro"]:
		_reset(blocked + " prevents new screen gestures")
		hud.set_state({"paused": blocked == "pause", "phase": "intro" if blocked == "intro" else "approach"})
		_touch(0, left_blank)
		_touch(1, right_blank)
		_drag(0, DRIFT)
		_drag(1, DRIFT)
		_expect(Vector2.ZERO, Vector2.ZERO)


func _test_pan_gestures() -> void:
	for touch_controls: bool in [true, false]:
		_reset("trackpad pan, touch controls=" + str(touch_controls))
		hud.set_state({"touch_enabled": touch_controls})
		_pan(Vector2(2.0, -1.0))
		var first_signal: Vector2 = _look_sum()
		var first_turn: Vector2 = _view()
		_check(first_signal.x > 0.0 and first_signal.y < 0.0, "pan did not emit a correctly directed HUD look signal")
		_check(first_turn.x < 0.0 and first_turn.y > 0.0, "pan did not rotate actual yaw and camera pitch")
		_pan(Vector2(2.0, -1.0))
		_expect(first_signal * 2.0, first_turn * 2.0)
		_pan(Vector2(-4.0, 2.0))
		_expect(Vector2.ZERO, Vector2.ZERO)

	for blocked: String in ["pause", "intro"]:
		_reset(blocked + " prevents trackpad pan")
		hud.set_state({"paused": blocked == "pause", "phase": "intro" if blocked == "intro" else "approach"})
		_pan(Vector2(2.0, -1.0))
		_expect(Vector2.ZERO, Vector2.ZERO)
		_check(look_events.is_empty(), "blocked pan emitted a HUD look signal")


func _test_aim_sensitivity() -> void:
	_reset("aimed two-finger sensitivity")
	player.switch_weapon(4)
	player.toggle_aim()
	player._process(0.0)
	player.apply_look_delta(DRIFT)
	var aimed_turn: Vector2 = _view()
	_check(aimed_turn.length() > EPSILON and aimed_turn.length() < normal_turn.length(), "scope did not reduce controller sensitivity")
	player.rotation = Vector3.ZERO
	player._pitch = 0.0
	player.camera.rotation = Vector3.ZERO
	_touch(0, left_blank)
	_touch(1, right_blank)
	_drag(0, DRIFT)
	_drag(1, DRIFT)
	_expect(DRIFT, aimed_turn)


func _reset(label: String) -> void:
	case_label = label
	hud._release_pointers()
	hud.set_state({"phase": "approach", "paused": false, "arsenal_open": false, "touch_enabled": true})
	player.set_enabled(false)
	player.set_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.switch_weapon(0)
	player.rotation = Vector3.ZERO
	player._pitch = 0.0
	player.camera.rotation = Vector3.ZERO
	player._sway = Vector2.ZERO
	look_events.clear()
	move_events.clear()
	action_events.clear()
	contacts.clear()


func _blank_point(preferred: Vector2, right_side: bool) -> Vector2:
	var dimensions: Vector2 = Vector2(viewport.size)
	var candidates: Array[Vector2] = [preferred * dimensions]
	for y_fraction: float in [0.30, 0.38, 0.46, 0.54]:
		for x_fraction: float in ([0.52, 0.64, 0.76] if right_side else [0.12, 0.20, 0.27]):
			candidates.append(Vector2(x_fraction, y_fraction) * dimensions)
	for candidate: Vector2 in candidates:
		if hud.surface.action_at(candidate).is_empty() and candidate.distance_to(hud.surface.joystick_center) > hud.surface.joystick_radius * 1.7:
			if (candidate.x > dimensions.x * 0.32) == right_side:
				return candidate
	return Vector2.ZERO


func _touch(index: int, position: Vector2, pressed: bool = true, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	contacts[index] = position
	hud._input(event)


func _drag(index: int, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.relative = relative
	event.screen_relative = relative
	event.position = Vector2(contacts.get(index, right_blank)) + relative
	contacts[index] = event.position
	hud._input(event)


func _pan(delta: Vector2) -> void:
	var event := InputEventPanGesture.new()
	event.position = right_blank
	event.delta = delta
	hud._input(event)


func _look_sum() -> Vector2:
	var total := Vector2.ZERO
	for value: Vector2 in look_events:
		total += value
	return total


func _view() -> Vector2:
	player._process(0.0)
	_check(absf(player.camera.rotation.x - player._pitch) < EPSILON, "visible camera pitch did not follow controller pitch")
	return Vector2(player.rotation.y, player.camera.rotation.x)


func _expect(signal_total: Vector2, camera_rotation: Vector2) -> void:
	var actual_signal: Vector2 = _look_sum()
	var actual_view: Vector2 = _view()
	_check(actual_signal.distance_to(signal_total) < 0.0001, "look delta %s, expected %s" % [actual_signal, signal_total])
	_check(actual_view.distance_to(camera_rotation) < EPSILON, "camera yaw/pitch %s, expected %s" % [actual_view, camera_rotation])


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s | %s | %s" % [screen_label, case_label, message])
