extends CanvasLayer
## Resolution-independent tactical overlay. World rendering remains entirely 3D.

signal action(name: String, pressed: bool)
signal move_input(value: Vector2)
signal look_input(delta: Vector2)

var state: Dictionary = {
	"phase": "menu", "paused": false, "objective": "与小队前往任务区域", "subobjective": "保持移动，留意队友的提示",
	"health": 100.0, "ammo": 30, "reserve": 180, "weapon": "CAR-9 突击步枪", "score": 0,
	"heat": 0, "loot": 0, "police_eta": 0.0, "aiming": false, "touch_enabled": true,
	"dialogue_speaker": "", "dialogue_text": "", "dialogue_visible": true, "markers": [],
	"grenades": 4, "smoke_grenades": 3, "arsenal_open": false, "weapons": [],
	"mission_name": "随机行动", "mission_number": 1, "mission_item": "目标", "mission_required": 1,
	"mission_kind": "collect", "target_status": "待定位", "mission_brief": "完成目标，与小队撤离。",
	"credits": 1000, "wins": 0, "currency_delta": 0, "new_skin": "", "skin_index": 0, "skins": [], "failure_reason": ""
}
var surface: HudSurface
var _pointers: Dictionary = {}
var _mouse_pointer: String = ""
var _mouse_action: String = ""
var _move_pointer: int = -1
var _joystick_vector: Vector2 = Vector2.ZERO
var _last_modal: bool = true
var _armory_tab: String = "weapons"


func _ready() -> void:
	layer = 20
	surface = HudSurface.new()
	surface.hud = self
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(surface)


func set_state(data: Dictionary) -> void:
	var was_intro: bool = str(state.get("phase", "")) == "intro"
	state.merge(data, true)
	if data.has("required") and not data.has("mission_required"):
		state["mission_required"] = data["required"]
	if data.has("item") and not data.has("mission_item"):
		state["mission_item"] = data["item"]
	var modal: bool = _is_modal()
	if modal != _last_modal or (not was_intro and str(state.get("phase", "")) == "intro"):
		_release_pointers()
	_last_modal = modal
	if is_instance_valid(surface):
		surface.queue_redraw()


func _process(_delta: float) -> void:
	if is_instance_valid(surface):
		surface.queue_redraw()


func _is_modal() -> bool:
	return bool(state.get("paused", false)) or bool(state.get("arsenal_open", false)) or str(state.get("phase", "menu")) in ["menu", "won", "lost"]


func _can_look() -> bool:
	return not _is_modal() and str(state.get("phase", "")) != "intro"


func _look_pointer_count() -> int:
	var count: int = 0
	for pointer in _pointers.values():
		if str(pointer.get("kind", "")) == "look":
			count += 1
	return maxi(count, 1)


func _release_pointers() -> void:
	for data in _pointers.values():
		if str(data.get("kind", "")) == "action":
			action.emit(str(data.get("action", "")), false)
	if not _mouse_action.is_empty():
		action.emit(_mouse_action, false)
	_pointers.clear()
	_move_pointer = -1
	_mouse_pointer = ""
	_mouse_action = ""
	_joystick_vector = Vector2.ZERO
	move_input.emit(Vector2.ZERO)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_pointers()


func _update_move(position: Vector2) -> void:
	_joystick_vector = ((position - surface.joystick_center) / surface.joystick_radius).limit_length(1.0)
	move_input.emit(_joystick_vector)


func _input(event: InputEvent) -> void:
	if not is_instance_valid(surface):
		return
	surface.calculate_layout()
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and not touch.canceled:
			var button: String = surface.action_at(touch.position)
			if not button.is_empty():
				_pointers[touch.index] = {"kind": "action", "action": button}
				_dispatch_action(button, true)
			elif _is_modal():
				_pointers[touch.index] = {"kind": "blocked"}
			elif str(state.get("phase", "")) == "intro":
				_pointers[touch.index] = {"kind": "blocked"}
			elif bool(state.get("touch_enabled", true)) and _move_pointer < 0 and touch.position.distance_to(surface.joystick_center) < surface.joystick_radius * 1.55:
				_move_pointer = touch.index
				_pointers[touch.index] = {"kind": "move"}
				_update_move(touch.position)
			else:
				_pointers[touch.index] = {"kind": "look"}
		elif _pointers.has(touch.index):
			var tracked: Dictionary = _pointers[touch.index]
			if str(tracked.get("kind", "")) == "action":
				_dispatch_action(str(tracked.get("action", "")), false)
			elif str(tracked.get("kind", "")) == "move":
				_move_pointer = -1
				_joystick_vector = Vector2.ZERO
				move_input.emit(Vector2.ZERO)
			_pointers.erase(touch.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if _pointers.has(drag.index):
			var tracked: Dictionary = _pointers[drag.index]
			if str(tracked.get("kind", "")) == "move":
				_update_move(drag.position)
			elif str(tracked.get("kind", "")) == "look" and _can_look():
				# Average finger motion: a two-finger swipe keeps the same sensitivity.
				# Joystick and held action fingers are excluded from this gesture.
				look_input.emit(drag.relative / float(_look_pointer_count()))
			elif str(tracked.get("action", "")) == "fire" and _can_look():
				# Keep firing until release, even after dragging outside the button.
				look_input.emit(drag.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		# macOS trackpads report two-finger movement as pan gestures.
		if _can_look():
			look_input.emit((event as InputEventPanGesture).delta)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _is_modal():
			return
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			var button: String = surface.action_at(mouse.position)
			if not button.is_empty():
				_mouse_pointer = "action"
				_mouse_action = button
				_dispatch_action(button, true)
			elif _is_modal() or str(state.get("phase", "")) == "intro":
				_mouse_pointer = "blocked"
			elif bool(state.get("touch_enabled", true)) and mouse.position.distance_to(surface.joystick_center) < surface.joystick_radius * 1.55:
				_mouse_pointer = "move"
				_update_move(mouse.position)
			else:
				_mouse_pointer = "look"
		else:
			if _mouse_pointer == "action":
				_dispatch_action(_mouse_action, false)
			elif _mouse_pointer == "move":
				_joystick_vector = Vector2.ZERO
				move_input.emit(Vector2.ZERO)
			_mouse_pointer = ""
			_mouse_action = ""
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _is_modal():
			return
		if _mouse_pointer == "move":
			_update_move(motion.position)
		elif (_mouse_pointer == "look" or (_mouse_pointer == "action" and _mouse_action == "fire")) and _can_look():
			look_input.emit(motion.relative)
		if not _mouse_pointer.is_empty() or _is_modal():
			get_viewport().set_input_as_handled()


func _dispatch_action(action_name: String, pressed: bool) -> void:
	if action_name in ["tab_weapons", "tab_skins"]:
		if pressed:
			_armory_tab = "skins" if action_name == "tab_skins" else "weapons"
			surface.queue_redraw()
		return
	if action_name == "open_skins":
		if pressed:
			_armory_tab = "skins"
			action.emit("arsenal", true)
		return
	if action_name == "arsenal" and pressed:
		_armory_tab = "weapons"
	action.emit(action_name, pressed)


func debug_layout() -> Dictionary:
	if not is_instance_valid(surface):
		return {}
	surface.calculate_layout()
	return {"viewport": surface.viewport_size, "portrait": surface.portrait, "rectangles": surface.rect_buttons.duplicate(true), "circles": surface.circle_buttons.duplicate(true), "joystick": Rect2(surface.joystick_center - Vector2.ONE * surface.joystick_radius, Vector2.ONE * surface.joystick_radius * 2.0), "status": surface.status_rect, "dialogue": surface.dialogue_rect, "mission": surface.mission_display(), "armory_tab": _armory_tab, "settlement": surface.settlement_display(), "skins": surface.skin_display()}


class HudSurface extends Control:
	const MINT: Color = Color("c2f3d7")
	const WHITE: Color = Color("f2f2e9")
	const MUTED: Color = Color("8daba7")
	const ORANGE: Color = Color("f4a06b")
	const DARK: Color = Color(0.022, 0.058, 0.064, 0.9)
	const LINE: Color = Color(0.64, 0.84, 0.78, 0.25)
	var hud: CanvasLayer
	var font: Font
	var viewport_size: Vector2 = Vector2(1280, 720)
	var portrait: bool = false
	var compact: bool = false
	var ui_scale: float = 1.0
	var margin: float = 24.0
	var rect_buttons: Dictionary = {}
	var circle_buttons: Dictionary = {}
	var joystick_center: Vector2 = Vector2.ZERO
	var joystick_radius: float = 56.0
	var menu_rect: Rect2
	var status_rect: Rect2
	var dialogue_rect: Rect2

	func _ready() -> void:
		if ResourceLoader.exists("res://assets/fonts/NotoSansSC.ttf"):
			var source_font: Font = load("res://assets/fonts/NotoSansSC.ttf") as Font
			var medium_font: FontVariation = FontVariation.new()
			medium_font.base_font = source_font
			# Godot exposes this variable font axis by its integer OpenType tag.
			medium_font.variation_opentype = {2003265652: 500.0}
			font = medium_font
		if font == null:
			font = ThemeDB.fallback_font
		resized.connect(queue_redraw)

	func calculate_layout() -> void:
		viewport_size = get_viewport_rect().size
		var w: float = viewport_size.x
		var h: float = viewport_size.y
		portrait = w < h * 0.8
		compact = h < 530.0 and not portrait
		ui_scale = clampf(minf(w / 1280.0, h / 720.0), 0.72, 1.65) if not portrait else clampf(w / 430.0, 0.84, 1.3)
		margin = 22.0 * ui_scale if not portrait else 18.0 * ui_scale
		rect_buttons.clear()
		circle_buttons.clear()
		var phase: String = str(hud.state.get("phase", "menu"))
		if bool(hud.state.get("paused", false)) and bool(hud.state.get("arsenal_open", false)):
			_layout_arsenal()
		elif bool(hud.state.get("paused", false)):
			var pw: float = minf(w - margin * 2.0, 410.0 * ui_scale)
			var ph: float = minf(h - margin * 2.0, 310.0 * ui_scale)
			menu_rect = Rect2(Vector2((w - pw) * 0.5, (h - ph) * 0.5), Vector2(pw, ph))
			rect_buttons["resume"] = Rect2(menu_rect.position + Vector2(26, 156) * ui_scale, Vector2(pw - 52 * ui_scale, 52 * ui_scale))
			rect_buttons["restart"] = Rect2(menu_rect.position + Vector2(26, 222) * ui_scale, Vector2(pw - 52 * ui_scale, 46 * ui_scale))
		elif phase == "menu":
			if portrait:
				var start_y: float = maxf(388.0 * ui_scale, h * 0.515)
				rect_buttons["start"] = Rect2(Vector2(margin + 7 * ui_scale, start_y), Vector2(w - margin * 2 - 14 * ui_scale, 58 * ui_scale))
				rect_buttons["touch"] = Rect2(Vector2(margin + 7 * ui_scale, start_y + 74 * ui_scale), Vector2(w - margin * 2 - 14 * ui_scale, 40 * ui_scale))
			else:
				var left: float = maxf(28.0, w * 0.05)
				var start_y: float = h * (0.24 if compact else 0.30) + 232 * ui_scale
				rect_buttons["start"] = Rect2(Vector2(left, start_y), Vector2(340 * ui_scale, 58 * ui_scale))
				rect_buttons["touch"] = Rect2(Vector2(left, start_y + 71 * ui_scale), Vector2(340 * ui_scale, 34 * ui_scale))
			var settings_row: Rect2 = rect_buttons["touch"]
			var settings_gap: float = 12 * ui_scale
			var settings_width: float = (settings_row.size.x - settings_gap) * 0.5
			rect_buttons["touch"] = Rect2(settings_row.position, Vector2(settings_width, settings_row.size.y))
			rect_buttons["open_skins"] = Rect2(settings_row.position + Vector2(settings_width + settings_gap, 0), Vector2(settings_width, settings_row.size.y))
		elif phase in ["won", "lost"]:
			var rw: float = minf(w - margin * 2.0, 650.0 * ui_scale)
			var rh: float = 470.0 * ui_scale if portrait else minf(440.0 * ui_scale, h - margin * 2.0)
			menu_rect = Rect2(Vector2((w - rw) * 0.5, (h - rh) * 0.5), Vector2(rw, rh))
			rect_buttons["restart"] = Rect2(Vector2(menu_rect.position.x + 28 * ui_scale, menu_rect.end.y - 79 * ui_scale), Vector2(rw - 56 * ui_scale, 52 * ui_scale))
			if not str(hud.state.get("new_skin", "")).is_empty():
				rect_buttons["open_skins"] = Rect2(Vector2(menu_rect.end.x - 122 * ui_scale, menu_rect.position.y + 285 * ui_scale), Vector2(94 * ui_scale, 42 * ui_scale))
		elif phase == "intro":
			rect_buttons["skip"] = Rect2(Vector2(w - margin - 132 * ui_scale, h - margin - 42 * ui_scale), Vector2(132 * ui_scale, 42 * ui_scale))
		else:
			rect_buttons["pause"] = Rect2(Vector2(w - margin - 34 * ui_scale, margin), Vector2(34 * ui_scale, 34 * ui_scale))
			if bool(hud.state.get("touch_enabled", true)):
				if portrait:
					joystick_center = Vector2(margin + 56 * ui_scale, h - margin - 93 * ui_scale)
					joystick_radius = 49 * ui_scale
					_circle("fire", Vector2(w - margin - 40 * ui_scale, h - margin - 90 * ui_scale), 35 * ui_scale)
					_circle("aim", Vector2(w - margin - 113 * ui_scale, h - margin - 133 * ui_scale), 26 * ui_scale)
					_circle("melee", Vector2(w - margin - 174 * ui_scale, h - margin - 67 * ui_scale), 24 * ui_scale)
					_circle("reload", Vector2(w - margin - 112 * ui_scale, h - margin - 65 * ui_scale), 24 * ui_scale)
					_circle("interact", Vector2(w - margin - 39 * ui_scale, h - margin - 187 * ui_scale), 27 * ui_scale)
					_circle("switch", Vector2(w - margin - 183 * ui_scale, h - margin - 142 * ui_scale), 23 * ui_scale)
					_circle("sprint", Vector2(margin + 35 * ui_scale, h - margin - 190 * ui_scale), 23 * ui_scale)
					_circle("jump", Vector2(margin + 111 * ui_scale, h - margin - 194 * ui_scale), 23 * ui_scale)
					_circle("grenade", Vector2(margin + 42 * ui_scale, h - margin - 278 * ui_scale), 23 * ui_scale)
					_circle("smoke", Vector2(margin + 112 * ui_scale, h - margin - 278 * ui_scale), 23 * ui_scale)
					rect_buttons["arsenal"] = Rect2(Vector2(w - margin - 139 * ui_scale, h - margin - 298 * ui_scale), Vector2(133 * ui_scale, 40 * ui_scale))
				else:
					joystick_center = Vector2(margin + 61 * ui_scale, h - margin - 62 * ui_scale)
					joystick_radius = maxf(42.0, 56 * ui_scale)
					_circle("fire", Vector2(w - margin - 46 * ui_scale, h - margin - 53 * ui_scale), maxf(29.0, 40 * ui_scale))
					_circle("aim", Vector2(w - margin - 137 * ui_scale, h - margin - 104 * ui_scale), maxf(23.0, 27 * ui_scale))
					_circle("melee", Vector2(w - margin - 207 * ui_scale, h - margin - 39 * ui_scale), maxf(21.0, 24 * ui_scale))
					_circle("reload", Vector2(w - margin - 131 * ui_scale, h - margin - 28 * ui_scale), maxf(21.0, 24 * ui_scale))
					_circle("interact", Vector2(w - margin - 50 * ui_scale, h - margin - 158 * ui_scale), maxf(24.0, 28 * ui_scale))
					_circle("switch", Vector2(w - margin - 215 * ui_scale, h - margin - 119 * ui_scale), maxf(20.0, 22 * ui_scale))
					_circle("sprint", Vector2(margin + 136 * ui_scale, h - margin - 133 * ui_scale), maxf(20.0, 22 * ui_scale))
					_circle("jump", Vector2(margin + 213 * ui_scale, h - margin - 133 * ui_scale), maxf(20.0, 22 * ui_scale))
					_circle("grenade", Vector2(margin + 54 * ui_scale, h - margin - 230 * ui_scale), maxf(20.0, 23 * ui_scale))
					_circle("smoke", Vector2(margin + 130 * ui_scale, h - margin - 230 * ui_scale), maxf(20.0, 23 * ui_scale))
					var arsenal_width: float = maxf(110.0, 146 * ui_scale)
					rect_buttons["arsenal"] = Rect2(Vector2(w * 0.5 - arsenal_width * 0.5, h - margin - 120 * ui_scale), Vector2(arsenal_width, maxf(32.0, 38 * ui_scale)))
		if portrait:
			status_rect = Rect2(Vector2(margin, h - margin - 367 * ui_scale), Vector2(w - margin * 2.0, 53 * ui_scale))
			dialogue_rect = Rect2(Vector2(margin, 161 * ui_scale), Vector2(w - margin * 2.0, 94 * ui_scale))
		else:
			status_rect = Rect2(Vector2(w * 0.5 - 150 * ui_scale, h - margin - 61 * ui_scale), Vector2(300 * ui_scale, 61 * ui_scale))
			var dw: float = minf(w - margin * 2.0, 620 * ui_scale)
			dialogue_rect = Rect2(Vector2((w - dw) * 0.5, (94.0 if not compact else 99.0) * ui_scale), Vector2(dw, 65 * ui_scale))

	func _layout_arsenal() -> void:
		var w: float = viewport_size.x
		var h: float = viewport_size.y
		var panel_width: float = minf(w - margin * 2.0, 910 * ui_scale)
		var panel_height: float = minf(h - margin * 2.0, (624 if portrait else 448) * ui_scale)
		menu_rect = Rect2(Vector2((w - panel_width) * 0.5, (h - panel_height) * 0.5), Vector2(panel_width, panel_height))
		var skins_tab: bool = hud._armory_tab == "skins"
		var entries: Array = skin_display() if skins_tab else hud.state.get("weapons", [])
		var columns: int = 2 if portrait else (3 if skins_tab else 4)
		var gutter: float = 12 * ui_scale
		var padding: float = 23 * ui_scale
		var card_width: float = (panel_width - padding * 2.0 - gutter * (columns - 1)) / columns
		var card_height: float = (110 if portrait else 102) * ui_scale if skins_tab else (83 if portrait else 90) * ui_scale
		var origin: Vector2 = menu_rect.position + Vector2(padding, 150 * ui_scale)
		for i in range(entries.size()):
			var row: int = int(i / columns)
			var column: int = i % columns
			var index: int = int(entries[i].index) if skins_tab else i
			var key: String = "skin_%d" % index if skins_tab else "equip_%d" % index
			rect_buttons[key] = Rect2(origin + Vector2(column * (card_width + gutter), row * (card_height + gutter)), Vector2(card_width, card_height))
		rect_buttons["tab_weapons"] = Rect2(menu_rect.position + Vector2(padding, 106 * ui_scale), Vector2(111 * ui_scale, 31 * ui_scale))
		rect_buttons["tab_skins"] = Rect2(menu_rect.position + Vector2(padding + 123 * ui_scale, 106 * ui_scale), Vector2(111 * ui_scale, 31 * ui_scale))
		rect_buttons["resume"] = Rect2(Vector2(menu_rect.position.x + padding, menu_rect.end.y - 66 * ui_scale), Vector2(panel_width - padding * 2.0, 43 * ui_scale))

	func _circle(action_name: String, center: Vector2, radius: float) -> void:
		circle_buttons[action_name] = {"center": center, "radius": radius}

	func action_at(point: Vector2) -> String:
		for action_name in rect_buttons:
			if (rect_buttons[action_name] as Rect2).has_point(point):
				return str(action_name)
		for action_name in circle_buttons:
			var button: Dictionary = circle_buttons[action_name]
			if point.distance_to(button.center) <= float(button.radius) + 3.0:
				return str(action_name)
		return ""

	func _draw() -> void:
		if font == null:
			return
		calculate_layout()
		var phase: String = str(hud.state.get("phase", "menu"))
		if bool(hud.state.get("paused", false)) and bool(hud.state.get("arsenal_open", false)):
			_draw_arsenal()
			return
		if phase == "menu":
			_draw_menu()
		elif phase in ["won", "lost"]:
			_draw_results(phase == "won")
		elif phase == "intro":
			_draw_intro()
		else:
			_draw_play()
		if bool(hud.state.get("paused", false)):
			if bool(hud.state.get("arsenal_open", false)):
				_draw_arsenal()
			else:
				_draw_pause()

	func _label(text: String, point: Vector2, size_px: float, color: Color = WHITE) -> void:
		draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(10, roundi(size_px)), color)

	func _center(text: String, point: Vector2, size_px: float, color: Color = WHITE) -> void:
		var fs: int = maxi(10, roundi(size_px))
		var extent: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, point - Vector2(extent.x * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

	func _panel(rect: Rect2, fill: Color = DARK, border: Color = LINE, radius: float = 8.0) -> void:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = fill
		style.border_color = border
		style.set_border_width_all(1)
		style.set_corner_radius_all(roundi(radius * ui_scale))
		draw_style_box(style, rect)

	func _lines(text: String, max_width: float, fs: float, max_lines: int = 3) -> Array[String]:
		var rows: Array[String] = []
		var current: String = ""
		for i in range(text.length()):
			var ch: String = text.substr(i, 1)
			if ch == "\n" or (not current.is_empty() and font.get_string_size(current + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(10, roundi(fs))).x > max_width):
				rows.append(current)
				current = ""
				if rows.size() >= max_lines:
					rows[max_lines - 1] = rows[max_lines - 1].left(maxi(0, rows[max_lines - 1].length() - 1)) + "…"
					return rows
			if ch != "\n":
				current += ch
		if not current.is_empty():
			rows.append(current)
		return rows

	func _paragraph(text: String, point: Vector2, max_width: float, fs: float, color: Color = MUTED, max_lines: int = 3) -> void:
		var rows: Array[String] = _lines(text, max_width, fs, max_lines)
		for i in range(rows.size()):
			_label(rows[i], point + Vector2(0, i * fs * 1.6), fs, color)

	func _button(name: String, text: String, primary: bool = false, hint: String = "") -> void:
		if not rect_buttons.has(name):
			return
		var rect: Rect2 = rect_buttons[name]
		var pressed: bool = _pressed(name)
		var bg: Color = MINT if primary else Color(0.04, 0.095, 0.10, 0.80)
		if pressed:
			bg = bg.lightened(0.13)
		_panel(rect, bg, MINT if primary else LINE, 5)
		var ink: Color = Color("153932") if primary else WHITE
		_label(text, rect.position + Vector2(20 * ui_scale, rect.size.y * 0.5 + 6 * ui_scale), 16 * ui_scale, ink)
		if not hint.is_empty():
			var extent: Vector2 = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(12 * ui_scale))
			_label(hint, Vector2(rect.end.x - extent.x - 17 * ui_scale, rect.position.y + rect.size.y * 0.5 + 4 * ui_scale), 12 * ui_scale, ink if primary else MUTED)

	func _pressed(name: String) -> bool:
		if hud._mouse_action == name:
			return true
		for pointer in hud._pointers.values():
			if str(pointer.get("action", "")) == name:
				return true
		return false

	func _draw_menu() -> void:
		var w: float = viewport_size.x
		var h: float = viewport_size.y
		for i in range(32):
			var alpha: float = lerpf(0.96, 0.05 if not portrait else 0.69, float(i) / 31.0)
			draw_rect(Rect2(i * w / 32.0, 0, w / 32.0 + 1, h), Color(0.016, 0.045, 0.051, alpha))
		var left: float = margin + 7 * ui_scale if portrait else maxf(28.0, w * 0.05)
		var title_y: float = h * 0.215 if portrait else h * (0.24 if compact else 0.30)
		var heading: float = 48 * ui_scale if portrait else 72 * ui_scale
		_label("行动资金 %d  ·  成功 %d 次" % [int(hud.state.get("credits", 0)), int(hud.state.get("wins", 0))], Vector2(left, title_y - 96 * ui_scale), 10 * ui_scale, MINT)
		_label("AGENT / 91    第一人称任务模拟", Vector2(left, title_y - 69 * ui_scale), 11 * ui_scale, MINT)
		_label("特工模拟器", Vector2(left - 3 * ui_scale, title_y), heading, WHITE)
		_label("代号：特务 91", Vector2(left, title_y + 50 * ui_scale), 28 * ui_scale, WHITE)
		draw_line(Vector2(left, title_y + 70 * ui_scale), Vector2(left + 38 * ui_scale, title_y + 70 * ui_scale), MINT, 3 * ui_scale)
		_label("AI 队友协作 · 无后坐力 · 随机行动", Vector2(left, title_y + 99 * ui_scale), 13 * ui_scale, MUTED)
		var mission: Rect2 = Rect2(Vector2(left, title_y + 128 * ui_scale), Vector2((w - left * 2) if portrait else 395 * ui_scale, 78 * ui_scale))
		_panel(mission, Color(0.047, 0.092, 0.09, 0.88), LINE, 6)
		draw_line(mission.position + Vector2(0, 15 * ui_scale), mission.position + Vector2(0, 62 * ui_scale), MINT, 3 * ui_scale)
		_label("04", mission.position + Vector2(18, 43) * ui_scale, 27 * ui_scale, MINT)
		_label("随机部署 · 四类任务", mission.position + Vector2(67, 25) * ui_scale, 15 * ui_scale, WHITE)
		_label("银行 · 住宅 · 暗杀", mission.position + Vector2(67, 47) * ui_scale, 11 * ui_scale, MUTED)
		_label("控制目标并带走", mission.position + Vector2(67, 65) * ui_scale, 11 * ui_scale, MUTED)
		_button("start", "随机部署", true, "ENTER  →")
		_button("touch", "触控", false, "开启 ●" if bool(hud.state.get("touch_enabled", true)) else "关闭 ○")
		_button("open_skins", "外观", false, "→")
		var help_y: float = (rect_buttons["touch"] as Rect2).end.y + 38 * ui_scale
		if portrait:
			_label("左侧摇杆移动 · 空白处单指 / 双指转向", Vector2(left, help_y), 12 * ui_scale, WHITE)
			_label("按住射击并拖动瞄准 · 左右 360° 转向", Vector2(left, help_y + 27 * ui_scale), 11 * ui_scale, MUTED)
			_label("键鼠：G 手雷 · H 烟雾 · TAB 武器库", Vector2(left, help_y + 65 * ui_scale), 11 * ui_scale, MUTED)
		else:
			var controls_help: String = "WASD 移动 · 双指转向 · 按住射击拖动瞄准" if compact else "W A S D  移动     鼠标  转向 / 射击     右键  瞄准"
			_label(controls_help, Vector2(left, help_y), 11 * ui_scale, MUTED)
			_label("E 交互   R 换弹   F 拳击   G 手雷   H 烟雾   TAB 武器库", Vector2(left, help_y + 24 * ui_scale), 10 * ui_scale, MUTED)
			if not compact:
				_label("双指滑动转向 · 按住射击键拖动瞄准", Vector2(left, help_y + 47 * ui_scale), 10 * ui_scale, MUTED)
			var rx: float = w - maxf(28.0, w * 0.05)
			_label("OPERATION / RANDOM", Vector2(rx - 164 * ui_scale, margin + 18 * ui_scale), 11 * ui_scale, MINT)
			draw_line(Vector2(rx - 164 * ui_scale, margin + 31 * ui_scale), Vector2(rx, margin + 31 * ui_scale), LINE, 1)
			_label("任务随机分配 · 小队待命", Vector2(rx - 164 * ui_scale, margin + 52 * ui_scale), 10 * ui_scale, MUTED)
			var badge: Rect2 = Rect2(Vector2(w - 276 * ui_scale - margin, h - 114 * ui_scale), Vector2(276 * ui_scale, 55 * ui_scale))
			_panel(badge, Color(0.02, 0.05, 0.055, 0.73), LINE, 3)
			draw_circle(badge.position + Vector2(20, 27) * ui_scale, 3 * ui_scale, MINT)
			_label("特务 91 · 小队已就位", badge.position + Vector2(36, 25) * ui_scale, 12 * ui_scale, WHITE)
			_label("TACTICAL TEAM / 随机行动", badge.position + Vector2(36, 43) * ui_scale, 9 * ui_scale, MUTED)
		if not compact:
			_label("虚构剧情 · 街机计分 · 第一人称", Vector2(left, h - 22 * ui_scale), 9 * ui_scale, Color(0.61, 0.71, 0.66, 0.65))

	func _draw_intro() -> void:
		var w: float = viewport_size.x
		var h: float = viewport_size.y
		draw_rect(Rect2(0, 0, w, 49 * ui_scale), Color(0.01, 0.027, 0.032, 0.85))
		draw_rect(Rect2(0, h - 69 * ui_scale, w, 69 * ui_scale), Color(0.01, 0.027, 0.032, 0.87))
		_label("特工模拟器   /   特务 91", Vector2(margin, 30 * ui_scale), 13 * ui_scale, MINT)
		var mission_data: Dictionary = mission_display()
		var mission_width: float = w - margin * 2.0 - 155 * ui_scale if portrait else 270 * ui_scale
		_paragraph("任务 %02d · %s" % [mission_data.number, mission_data.name], Vector2(margin, h - 35 * ui_scale), mission_width, 12 * ui_scale, WHITE, 1)
		if not portrait:
			_label("与小队前往行动区域", Vector2(margin + 295 * ui_scale, h - 35 * ui_scale), 11 * ui_scale, MUTED)
		_draw_dialogue(true)
		_button("skip", "跳过剧情", false, "E →")

	func _draw_play() -> void:
		var w: float = viewport_size.x
		var h: float = viewport_size.y
		if bool(hud.state.get("aiming", false)):
			_draw_scope()
		_draw_top()
		_draw_markers()
		_draw_reticle()
		_draw_status()
		if bool(hud.state.get("touch_enabled", true)) and not bool(hud.state.get("paused", false)):
			_draw_controls()
		else:
			if not portrait:
				_label("WASD 移动  ·  E 交互  ·  R 换弹  ·  F 拳击  ·  G 手雷  ·  H 烟雾  ·  TAB 武器库", Vector2(margin, h - margin - 90 * ui_scale), 10 * ui_scale, MUTED)
		_draw_dialogue(false)
		var tip: String = str(hud.state.get("tip", ""))
		if not tip.is_empty():
			var tip_y: float = h * 0.60 if not portrait else h * 0.50
			var tw: float = minf(w - margin * 2, font.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(12 * ui_scale)).x + 32 * ui_scale)
			_panel(Rect2(Vector2((w - tw) * 0.5, tip_y - 22 * ui_scale), Vector2(tw, 33 * ui_scale)), Color(0.017, 0.05, 0.046, 0.88), LINE, 5)
			_center(tip, Vector2(w * 0.5, tip_y), 12 * ui_scale, MINT)
		var toast: String = str(hud.state.get("toast", ""))
		if not toast.is_empty() and float(hud.state.get("toast_time", 0.0)) > 0.0:
			_center(toast, Vector2(w * 0.5, h * 0.43), 15 * ui_scale, MINT)
		var flash: float = clampf(float(hud.state.get("hit_flash", 0.0)), 0.0, 1.0)
		if flash > 0.01:
			for i in range(5):
				var inset: float = i * 8 * ui_scale
				draw_rect(Rect2(Vector2.ONE * inset, viewport_size - Vector2.ONE * inset * 2.0), Color(0.88, 0.18, 0.1, flash * 0.13 * (1.0 - i / 5.0)), false, 8 * ui_scale)

	func _draw_top() -> void:
		var w: float = viewport_size.x
		var obj_width: float = w - margin * 2 if portrait else 340 * ui_scale
		var objective: Rect2 = Rect2(Vector2(margin, margin), Vector2(obj_width - (47 * ui_scale if portrait else 0), 71 * ui_scale))
		_panel(objective, Color(0.022, 0.055, 0.058, 0.85), LINE, 5)
		draw_rect(Rect2(objective.position, Vector2(3 * ui_scale, objective.size.y)), MINT)
		var mission_data: Dictionary = mission_display()
		_label("特务 91   /   任务 %02d" % int(mission_data.number), objective.position + Vector2(15, 18) * ui_scale, 9 * ui_scale, MINT)
		_paragraph(str(mission_data.name), objective.position + Vector2(15, 41) * ui_scale, objective.size.x - 26 * ui_scale, 14 * ui_scale, WHITE, 1)
		var instruction: String = str(hud.state.get("objective", hud.state.get("mission_brief", "完成任务目标")))
		if mission_data.has_target:
			instruction = str(mission_data.target_status) + " · " + instruction
		_paragraph(instruction, objective.position + Vector2(15, 59) * ui_scale, objective.size.x - 26 * ui_scale, 9 * ui_scale, MUTED, 1)
		var score_x: float = w - margin - 214 * ui_scale
		var score_y: float = margin
		if portrait:
			score_x = margin
			score_y = 103 * ui_scale
		_label("行动积分", Vector2(score_x, score_y + 12 * ui_scale), 9 * ui_scale, MUTED)
		_label("%06d" % int(hud.state.get("score", 0)), Vector2(score_x, score_y + 38 * ui_scale), 24 * ui_scale, WHITE)
		var heat: int = clampi(int(hud.state.get("heat", 0)), 0, 5)
		var heat_x: float = score_x + 118 * ui_scale
		_label("通缉等级", Vector2(heat_x, score_y + 12 * ui_scale), 9 * ui_scale, MUTED)
		for i in range(5):
			draw_rect(Rect2(heat_x + i * 11 * ui_scale, score_y + 24 * ui_scale, 7 * ui_scale, 10 * ui_scale), ORANGE if i < heat else Color(0.55, 0.7, 0.64, 0.19))
		var eta: float = float(hud.state.get("police_eta", 0))
		if eta > 0:
			_label("警力抵达  %02d:%02d" % [int(eta) / 60, int(eta) % 60], Vector2(score_x, score_y + 57 * ui_scale), 10 * ui_scale, ORANGE)
		elif heat > 0:
			_label("警力已抵达 · 寻找撤离机会", Vector2(score_x, score_y + 57 * ui_scale), 9 * ui_scale, ORANGE)
		var compass_y: float = 30 * ui_scale if not portrait else 146 * ui_scale
		if not portrait and w > 880:
			_draw_compass(Vector2(w * 0.5, compass_y), 202 * ui_scale)
		elif portrait:
			var yaw: int = posmod(roundi(float(hud.state.get("compass", 0))), 360)
			_label("航向  %03d°" % yaw, Vector2(w - margin - 88 * ui_scale, 130 * ui_scale), 10 * ui_scale, MUTED)
		if rect_buttons.has("pause"):
			var pause_rect: Rect2 = rect_buttons["pause"]
			_panel(pause_rect, Color(0.025, 0.058, 0.062, 0.76), LINE, 5)
			var pc: Vector2 = pause_rect.get_center()
			draw_line(pc + Vector2(-4, -6) * ui_scale, pc + Vector2(-4, 6) * ui_scale, WHITE, 2 * ui_scale)
			draw_line(pc + Vector2(4, -6) * ui_scale, pc + Vector2(4, 6) * ui_scale, WHITE, 2 * ui_scale)

	func mission_display() -> Dictionary:
		var required: int = maxi(1, int(hud.state.get("mission_required", hud.state.get("required", 1))))
		var completed: int = clampi(int(hud.state.get("loot", 0)), 0, required)
		var item: String = str(hud.state.get("mission_item", hud.state.get("item", "目标")))
		var kind: String = str(hud.state.get("mission_kind", "collect"))
		var has_target: bool = kind in ["eliminate", "capture"] or item == "目标"
		return {
			"name": str(hud.state.get("mission_name", "随机行动")),
			"number": maxi(1, int(hud.state.get("mission_number", 1))),
			"item": item, "required": required, "completed": completed,
			"kind": kind, "has_target": has_target,
			"target_status": str(hud.state.get("target_status", "待定位")),
			"count": "%d / %d" % [completed, required],
			"progress": "%s %d / %d" % [item, completed, required]
		}

	func _draw_compass(center: Vector2, width: float) -> void:
		var yaw: float = fposmod(float(hud.state.get("compass", 0.0)), 360.0)
		for i in range(-3, 4):
			var degree: int = posmod(int(round(yaw / 15.0)) * 15 + i * 15, 360)
			var dx: float = (float(i) * 28.0 - fposmod(yaw + 7.5, 15.0) / 15.0 * 28.0 + 14.0) * ui_scale
			if absf(dx) > width * 0.5:
				continue
			var cardinal: Dictionary = {0: "N", 90: "E", 180: "S", 270: "W"}
			_center(str(cardinal.get(degree, str(degree))), center + Vector2(dx, 0), 9 * ui_scale, MINT if cardinal.has(degree) else MUTED)
			draw_line(center + Vector2(dx, 8 * ui_scale), center + Vector2(dx, 12 * ui_scale), LINE, 1)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-3, -20) * ui_scale, center + Vector2(3, -20) * ui_scale, center + Vector2(0, -15) * ui_scale]), MINT)

	func _draw_status() -> void:
		_panel(status_rect, Color(0.016, 0.046, 0.05, 0.9), LINE, 6)
		var p: Vector2 = status_rect.position
		var health: float = clampf(float(hud.state.get("health", 100.0)), 0.0, 100.0)
		var health_ink: Color = MINT if health > 30 else ORANGE
		_label("生命", p + Vector2(13, 19) * ui_scale, 9 * ui_scale, MUTED)
		_label("%03d" % roundi(health), p + Vector2(44, 23) * ui_scale, 19 * ui_scale, health_ink)
		draw_rect(Rect2(p + Vector2(13, 34) * ui_scale, Vector2(82, 4) * ui_scale), Color(0.38, 0.56, 0.51, 0.25))
		draw_rect(Rect2(p + Vector2(13, 34) * ui_scale, Vector2(82 * health / 100, 4) * ui_scale), health_ink)
		var ammo_x: float = status_rect.end.x - 134 * ui_scale
		draw_line(Vector2(ammo_x - 13 * ui_scale, p.y + 13 * ui_scale), Vector2(ammo_x - 13 * ui_scale, p.y + 39 * ui_scale), LINE)
		var ammo_text: String = "%02d" % int(hud.state.get("ammo", 30))
		_label(ammo_text, Vector2(ammo_x, p.y + 30 * ui_scale), 28 * ui_scale, ORANGE if int(hud.state.get("ammo", 30)) == 0 else WHITE)
		_label("/ %03d" % int(hud.state.get("reserve", 180)), Vector2(ammo_x + 51 * ui_scale, p.y + 28 * ui_scale), 12 * ui_scale, MUTED)
		var weapon: String = "正在换弹…" if bool(hud.state.get("reloading", false)) else str(hud.state.get("weapon", "CAR-9 突击步枪"))
		_label(weapon, Vector2(ammo_x, p.y + 45 * ui_scale), 9 * ui_scale, MINT)
		var mission_data: Dictionary = mission_display()
		if not portrait:
			_label(str(mission_data.progress), p + Vector2(13, 52) * ui_scale, 8 * ui_scale, MUTED)
		else:
			var footer: String = str(mission_data.progress) + "  ·  " + (str(mission_data.target_status) if mission_data.has_target else "撤离后结算")
			_center(footer, Vector2(viewport_size.x * 0.5, viewport_size.y - 16 * ui_scale), 10 * ui_scale, MUTED)

	func _draw_controls() -> void:
		var joy: Vector2 = joystick_center
		var jr: float = joystick_radius
		draw_circle(joy, jr, Color(0.026, 0.068, 0.069, 0.40))
		draw_arc(joy, jr, 0, TAU, 64, Color(0.77, 0.91, 0.84, 0.32), 1.2 * ui_scale, true)
		draw_arc(joy, jr * 0.67, 0, TAU, 48, Color(0.77, 0.91, 0.84, 0.10), 1.0, true)
		for vector in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			draw_line(joy + vector * (jr - 7 * ui_scale), joy + vector * (jr - 3 * ui_scale), LINE, 1.0)
		var knob: Vector2 = joy + hud._joystick_vector * jr * 0.58
		draw_circle(knob, jr * 0.32, Color(0.70, 0.91, 0.8, 0.22))
		draw_arc(knob, jr * 0.32, 0, TAU, 32, Color(0.77, 0.91, 0.84, 0.65), 1.2, true)
		_center("移动", joy + Vector2(0, jr + 18 * ui_scale), 9 * ui_scale, MUTED)
		for name in circle_buttons:
			var data: Dictionary = circle_buttons[name]
			var center: Vector2 = data.center
			var radius: float = data.radius
			var active: bool = _pressed(str(name)) or (name == "aim" and bool(hud.state.get("aiming", false)))
			var ink: Color = MINT if active or name == "fire" else Color(0.88, 0.93, 0.86, 0.85)
			draw_circle(center, radius, Color(0.21, 0.40, 0.31, 0.55) if active else Color(0.018, 0.048, 0.052, 0.48))
			draw_arc(center, radius, 0, TAU, 48, ink * Color(1, 1, 1, 0.60 if name == "fire" else 0.38), 1.5 if name == "fire" else 1.0, true)
			_draw_action_icon(str(name), center - Vector2(0, 4 * ui_scale), ink)
			var names: Dictionary = {"fire": "射击", "aim": "瞄准", "melee": "拳击", "reload": "换弹", "interact": "交互", "switch": "切枪", "sprint": "疾跑", "grenade": "手雷", "smoke": "烟雾", "jump": "跳跃"}
			_center(str(names.get(name, name)), center + Vector2(0, radius * 0.61), 8 * ui_scale, ink)
			if name in ["grenade", "smoke"]:
				var count: int = int(hud.state.get("grenades" if name == "grenade" else "smoke_grenades", 0))
				var badge: Vector2 = center + Vector2(radius * 0.78, -radius * 0.76)
				draw_circle(badge, 8.5 * ui_scale, MINT if count > 0 else Color("46615c"))
				_center(str(count), badge + Vector2(0, 3.5 * ui_scale), 9 * ui_scale, Color("16382f"))
		_button("arsenal", "武器库", false, "TAB")
		if not portrait and viewport_size.y > 550:
			_center("双指转向 · 按住射击拖动瞄准", Vector2(viewport_size.x * 0.70, viewport_size.y - 202 * ui_scale), 9 * ui_scale, Color(0.78, 0.9, 0.84, 0.44))

	func _draw_action_icon(name: String, c: Vector2, ink: Color) -> void:
		var s: float = ui_scale
		match name:
			"fire":
				draw_arc(c, 12 * s, 0, TAU, 32, ink, 1.5 * s, true)
				draw_circle(c, 3 * s, ink)
				for v in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
					draw_line(c + v * 8 * s, c + v * 17 * s, ink, 1.5 * s)
			"aim":
				draw_arc(c, 9 * s, 0, TAU, 32, ink, 1.3 * s, true)
				draw_line(c - Vector2(14 * s, 0), c + Vector2(14 * s, 0), ink, 1.1 * s)
				draw_line(c - Vector2(0, 14 * s), c + Vector2(0, 14 * s), ink, 1.1 * s)
			"melee":
				var points: PackedVector2Array = PackedVector2Array([Vector2(-9, -5), Vector2(-5, -9), Vector2(-2, -9), Vector2(0, -7), Vector2(3, -9), Vector2(6, -7), Vector2(9, -7), Vector2(10, 1), Vector2(5, 7), Vector2(-5, 7), Vector2(-10, 1), Vector2(-9, -5)])
				for i in range(points.size() - 1):
					draw_line(c + points[i] * s, c + points[i + 1] * s, ink, 1.5 * s)
				draw_line(c + Vector2(-3, -6) * s, c + Vector2(-3, -1) * s, ink, s)
				draw_line(c + Vector2(2, -6) * s, c + Vector2(2, -1) * s, ink, s)
			"reload":
				draw_arc(c, 10 * s, -PI * 0.45, PI * 1.1, 24, ink, 1.6 * s, true)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -4) * s, c + Vector2(-8, 3) * s, c + Vector2(-4, -3) * s]), ink)
			"interact":
				draw_rect(Rect2(c - Vector2(9, 8) * s, Vector2(18, 16) * s), ink, false, 1.4 * s)
				draw_line(c - Vector2(9, 3) * s, c + Vector2(9, -3) * s, ink, 1 * s)
				draw_line(c + Vector2(0, -8) * s, c + Vector2(0, 8) * s, ink, 1 * s)
			"switch":
				draw_line(c + Vector2(-10, -5) * s, c + Vector2(9, -5) * s, ink, 1.4 * s)
				draw_line(c + Vector2(5, -9) * s, c + Vector2(9, -5) * s, ink, 1.4 * s)
				draw_line(c + Vector2(-9, 3) * s, c + Vector2(10, 3) * s, ink, 1.4 * s)
				draw_line(c + Vector2(-9, 3) * s, c + Vector2(-5, 7) * s, ink, 1.4 * s)
			"grenade":
				draw_arc(c + Vector2(0, 2) * s, 8 * s, 0, TAU, 24, ink, 1.5 * s, true)
				draw_rect(Rect2(c + Vector2(-4, -11) * s, Vector2(8, 5) * s), ink, false, 1.3 * s)
				draw_line(c + Vector2(4, -10) * s, c + Vector2(9, -4) * s, ink, 1.5 * s)
				draw_line(c + Vector2(-6, 1) * s, c + Vector2(6, 1) * s, ink, s)
				draw_line(c + Vector2(0, -4) * s, c + Vector2(0, 7) * s, ink, s)
			"smoke":
				draw_rect(Rect2(c + Vector2(-6, -4) * s, Vector2(12, 15) * s), ink, false, 1.4 * s)
				draw_line(c + Vector2(-3, -8) * s, c + Vector2(3, -8) * s, ink, 1.4 * s)
				draw_arc(c + Vector2(5, -12) * s, 3 * s, -PI, 0.5 * PI, 12, ink, s, true)
				draw_arc(c + Vector2(-3, -14) * s, 3 * s, -PI, 0.3 * PI, 12, ink, s, true)
				draw_line(c + Vector2(-3, 4) * s, c + Vector2(3, 4) * s, ink, s)
			"jump":
				draw_line(c + Vector2(-8, -1) * s, c + Vector2(0, -9) * s, ink, 1.7 * s)
				draw_line(c + Vector2(0, -9) * s, c + Vector2(8, -1) * s, ink, 1.7 * s)
				draw_line(c + Vector2(0, -7) * s, c + Vector2(0, 8) * s, ink, 1.7 * s)
				draw_line(c + Vector2(-9, 10) * s, c + Vector2(9, 10) * s, ink, 1.4 * s)
			"sprint":
				draw_circle(c + Vector2(3, -9) * s, 2.6 * s, ink)
				var segments: Array = [[Vector2(2, -4), Vector2(-2, 3)], [Vector2(-2, 3), Vector2(-9, 8)], [Vector2(-2, 3), Vector2(5, 4)], [Vector2(5, 4), Vector2(7, 10)], [Vector2(2, -4), Vector2(7, -1)], [Vector2(2, -4), Vector2(-4, -4)], [Vector2(-4, -4), Vector2(-7, 0)]]
				for pair in segments:
					draw_line(c + pair[0] * s, c + pair[1] * s, ink, 1.8 * s)

	func _draw_dialogue(intro: bool) -> void:
		if not bool(hud.state.get("dialogue_visible", true)):
			return
		var words: String = str(hud.state.get("dialogue_text", ""))
		if words.is_empty():
			return
		var r: Rect2 = dialogue_rect
		if intro:
			r.position.y = 74 * ui_scale
		var speaker: String = str(hud.state.get("dialogue_speaker", "队内通讯"))
		_panel(r, Color(0.018, 0.047, 0.052, 0.93), Color(0.58, 0.79, 0.70, 0.27), 6)
		draw_line(r.position + Vector2(0, 12 * ui_scale), r.position + Vector2(0, r.size.y - 12 * ui_scale), MINT, 2 * ui_scale)
		_label("▸ " + speaker + "  /  队内通讯", r.position + Vector2(15, 20) * ui_scale, 10 * ui_scale, MINT)
		_paragraph(words, r.position + Vector2(15, 44) * ui_scale, r.size.x - 30 * ui_scale, 12 * ui_scale, WHITE, 3 if portrait else 2)

	func _draw_markers() -> void:
		var markers: Array = hud.state.get("markers", [])
		for marker in markers:
			if not marker is Dictionary:
				continue
			var position: Vector2 = marker.get("screen", Vector2(-100, -100))
			if position.x < -30 or position.x > viewport_size.x + 30 or position.y < -30 or position.y > viewport_size.y + 30:
				continue
			position.x = clampf(position.x, margin + 45 * ui_scale, viewport_size.x - margin - 45 * ui_scale)
			position.y = clampf(position.y, 185 * ui_scale if portrait else 165 * ui_scale, viewport_size.y - 320 * ui_scale if portrait else viewport_size.y - 150 * ui_scale)
			var ink: Color = marker.get("color", MINT)
			var shape: PackedVector2Array = PackedVector2Array([position + Vector2(0, -8) * ui_scale, position + Vector2(8, 0) * ui_scale, position + Vector2(0, 8) * ui_scale, position + Vector2(-8, 0) * ui_scale, position + Vector2(0, -8) * ui_scale])
			draw_polyline(shape, ink, 1.4 * ui_scale, true)
			draw_circle(position, 2 * ui_scale, ink)
			_center(str(marker.get("label", "")), position + Vector2(0, 27 * ui_scale), 10 * ui_scale, ink)

	func _draw_reticle() -> void:
		var c: Vector2 = viewport_size * 0.5
		var aiming: bool = bool(hud.state.get("aiming", false))
		if not aiming:
			for v in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_line(c + v * 6 * ui_scale, c + v * 11 * ui_scale, Color(0.90, 0.98, 0.92, 0.82), 1.2 * ui_scale)
			draw_circle(c, 1.4 * ui_scale, MINT)
		if float(hud.state.get("hit_marker", 0.0)) > 0.0:
			for v in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				draw_line(c + v * 7 * ui_scale, c + v * 12 * ui_scale, MINT, 2 * ui_scale)

	func _draw_scope() -> void:
		var w: float = viewport_size.x
		var h: float = viewport_size.y
		var c: Vector2 = viewport_size * 0.5
		var r: float = minf(w, h) * 0.35
		var corners: Array = [
			[Vector2(c.x, 0), Vector2(w, 0), Vector2(w, c.y)],
			[Vector2(w, c.y), Vector2(w, h), Vector2(c.x, h)],
			[Vector2(c.x, h), Vector2(0, h), Vector2(0, c.y)],
			[Vector2(0, c.y), Vector2(0, 0), Vector2(c.x, 0)]
		]
		for q in range(4):
			var polygon: PackedVector2Array = PackedVector2Array(corners[q])
			var begin: float = q * PI * 0.5
			for i in range(25):
				var angle: float = begin - float(i) / 24 * PI * 0.5
				polygon.append(c + Vector2(cos(angle), sin(angle)) * r)
			draw_colored_polygon(polygon, Color(0.006, 0.018, 0.021, 0.76))
		draw_arc(c, r + 2, 0, TAU, 100, Color(0.022, 0.038, 0.035, 0.95), 7 * ui_scale, true)
		draw_arc(c, r - 4, 0, TAU, 100, Color(0.55, 0.7, 0.64, 0.48), 1, true)
		draw_line(c + Vector2(-r + 10, 0), c + Vector2(-10, 0), Color(0.07, 0.14, 0.10, 0.8), 1)
		draw_line(c + Vector2(10, 0), c + Vector2(r - 10, 0), Color(0.07, 0.14, 0.10, 0.8), 1)
		draw_line(c + Vector2(0, -r + 10), c + Vector2(0, -10), Color(0.07, 0.14, 0.10, 0.8), 1)
		draw_line(c + Vector2(0, 10), c + Vector2(0, r - 10), Color(0.07, 0.14, 0.10, 0.8), 1)
		for i in range(1, 5):
			draw_line(c + Vector2(-3, i * 18) * ui_scale, c + Vector2(3, i * 18) * ui_scale, Color(0.09, 0.16, 0.11, 0.8), 1)
		draw_circle(c, 2 * ui_scale, ORANGE)

	func skin_display() -> Array:
		var entries: Array = []
		var wins: int = maxi(0, int(hud.state.get("wins", 0)))
		for raw in hud.state.get("skins", []):
			if not raw is Dictionary:
				continue
			var entry: Dictionary = raw.duplicate()
			entry["unlocked"] = bool(raw.get("unlocked", wins >= int(raw.get("required", 0))))
			entry["selected"] = int(raw.get("index", 0)) == int(hud.state.get("skin_index", 0))
			entry["progress"] = clampf(float(wins) / maxf(1.0, float(raw.get("required", 0))), 0.0, 1.0) if int(raw.get("required", 0)) > 0 else 1.0
			var threshold: int = int(raw.get("required", 0))
			var availability: String = "初始外观" if threshold == 0 else "%d 次成功" % threshold
			entry["status"] = (("已装备" if entry.selected else "点击装备") + " · " + availability) if entry.unlocked else "%d 次成功行动解锁" % threshold
			entries.append(entry)
		return entries

	func settlement_display() -> Dictionary:
		var delta: int = int(hud.state.get("currency_delta", 0))
		return {"delta": delta, "delta_text": ("+" if delta > 0 else "") + str(delta), "balance": maxi(0, int(hud.state.get("credits", 0))), "wins": maxi(0, int(hud.state.get("wins", 0))), "new_skin": str(hud.state.get("new_skin", "")), "failure_reason": str(hud.state.get("failure_reason", ""))}

	func _draw_arsenal() -> void:
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.006, 0.027, 0.033, 0.86))
		_panel(menu_rect, Color(0.025, 0.063, 0.064, 0.99), LINE, 10)
		var skins_tab: bool = hud._armory_tab == "skins"
		var p: Vector2 = menu_rect.position + Vector2(23, 28) * ui_scale
		_label("LOADOUT / AGENT 91", p, 10 * ui_scale, MINT)
		_label("特务外观" if skins_tab else "战术武器库", p + Vector2(0, 37 * ui_scale), 27 * ui_scale, WHITE)
		var description: String = "成功行动解锁 · 外观自动保存" if skins_tab else "选择武器，点击装备。"
		if float(hud.state.get("toast_time", 0.0)) > 0.0 and not str(hud.state.get("toast", "")).is_empty():
			description = str(hud.state.get("toast", ""))
		_paragraph(description, p + Vector2(0, 63 * ui_scale), menu_rect.size.x - 46 * ui_scale, 10 * ui_scale, MUTED, 1)
		var wallet_x: float = menu_rect.end.x - 137 * ui_scale
		_label("行动资金", Vector2(wallet_x, p.y), 9 * ui_scale, MUTED)
		_label(str(int(hud.state.get("credits", 0))), Vector2(wallet_x, p.y + 26 * ui_scale), 21 * ui_scale, MINT)
		_label("成功行动 %d 次" % int(hud.state.get("wins", 0)), Vector2(wallet_x, p.y + 45 * ui_scale), 9 * ui_scale, MUTED)
		_draw_armory_tab("tab_weapons", "武器", not skins_tab)
		_draw_armory_tab("tab_skins", "外观", skins_tab)
		if skins_tab:
			_draw_skin_cards()
		else:
			_draw_weapon_cards()
		var phase: String = str(hud.state.get("phase", ""))
		_button("resume", "返回主菜单" if phase == "menu" else ("返回结算" if phase in ["won", "lost"] else "返回行动"), true, "TAB / ESC →")

	func _draw_armory_tab(key: String, title: String, selected: bool) -> void:
		var rect: Rect2 = rect_buttons[key]
		_panel(rect, Color(0.14, 0.27, 0.22, 0.95) if selected else Color(0.026, 0.062, 0.063, 0.95), MINT if selected else LINE, 4)
		_center(title, rect.get_center() + Vector2(0, 5 * ui_scale), 12 * ui_scale, MINT if selected else MUTED)

	func _draw_weapon_cards() -> void:
		var weapons: Array = hud.state.get("weapons", [])
		var equipped: String = str(hud.state.get("weapon", ""))
		var kinds: Array[String] = ["ASSAULT", "SIDEARM", "SHOTGUN", "SMG", "SNIPER", "LMG", "SUPPRESSED"]
		for i in range(weapons.size()):
			var key: String = "equip_%d" % i
			if not rect_buttons.has(key):
				continue
			var rect: Rect2 = rect_buttons[key]
			var selected: bool = equipped == str(weapons[i])
			_panel(rect, Color(0.095, 0.19, 0.155, 0.98) if selected or _pressed(key) else Color(0.035, 0.086, 0.086, 0.97), MINT if selected else LINE, 5)
			_label("%02d / %s" % [i + 1, kinds[i] if i < kinds.size() else "WEAPON"], rect.position + Vector2(11, 18) * ui_scale, 8 * ui_scale, MINT if selected else MUTED)
			_paragraph(str(weapons[i]), rect.position + Vector2(11, 42) * ui_scale, rect.size.x - 22 * ui_scale, 13 * ui_scale, WHITE, 2)
			_label("已装备 ●" if selected else "点击装备 →", Vector2(rect.position.x + 11 * ui_scale, rect.end.y - 10 * ui_scale), 9 * ui_scale, MINT if selected else MUTED)

	func _draw_skin_cards() -> void:
		var entries: Array = skin_display()
		for entry in entries:
			var key: String = "skin_%d" % int(entry.index)
			if not rect_buttons.has(key):
				continue
			var rect: Rect2 = rect_buttons[key]
			var tint: Color = entry.get("color", MINT)
			var secondary: Color = entry.get("secondary", Color("25333a"))
			var selected: bool = bool(entry.selected)
			_panel(rect, Color(0.045, 0.088, 0.088, 0.99), tint if selected else Color(tint, 0.29), 6)
			var accent: PackedVector2Array = PackedVector2Array([rect.position + Vector2(rect.size.x * 0.52, 1), rect.position + Vector2(rect.size.x - 2, 1), rect.position + Vector2(rect.size.x - 2, rect.size.y * 0.68), rect.position + Vector2(rect.size.x * 0.69, rect.size.y * 0.68)])
			draw_colored_polygon(accent, Color(tint, 0.075))
			_label(str(entry.name), rect.position + Vector2(10, 19) * ui_scale, 12 * ui_scale, WHITE if entry.unlocked else MUTED)
			var icon_center: Vector2 = Vector2(rect.end.x - 14 * ui_scale, rect.position.y + 14 * ui_scale)
			if selected:
				draw_circle(icon_center, 5 * ui_scale, tint)
			elif not entry.unlocked:
				draw_rect(Rect2(icon_center + Vector2(-4, 0) * ui_scale, Vector2(8, 7) * ui_scale), MUTED, false, 1)
				draw_arc(icon_center, 3 * ui_scale, PI, TAU, 12, MUTED, 1, true)
			var preview: Rect2 = Rect2(rect.position + Vector2(10, 28) * ui_scale, Vector2(rect.size.x - 20 * ui_scale, 41 * ui_scale))
			_draw_skin_preview(preview, tint, secondary, int(entry.index))
			_label(str(entry.status), Vector2(rect.position.x + 10 * ui_scale, rect.end.y - 21 * ui_scale), 9 * ui_scale, tint if entry.unlocked else MUTED)
			var progress_rect: Rect2 = Rect2(Vector2(rect.position.x + 10 * ui_scale, rect.end.y - 11 * ui_scale), Vector2(rect.size.x - 20 * ui_scale, 3 * ui_scale))
			draw_rect(progress_rect, Color(tint, 0.12))
			progress_rect.size.x *= float(entry.progress)
			draw_rect(progress_rect, tint if entry.unlocked else Color(tint, 0.55))
		if entries.size() == 5 and rect_buttons.has("skin_4"):
			var final_card: Rect2 = rect_buttons["skin_4"]
			var rules: Rect2 = Rect2(final_card.position + Vector2(final_card.size.x + 12 * ui_scale, 0), final_card.size)
			_panel(rules, Color(0.018, 0.046, 0.047, 0.98), LINE, 6)
			_label("行动规则", rules.position + Vector2(10, 19) * ui_scale, 11 * ui_scale, WHITE)
			_label("成功 +1000～1600", rules.position + Vector2(10, 43) * ui_scale, 10 * ui_scale, MINT)
			_label("失败最多扣 300", rules.position + Vector2(10, 64) * ui_scale, 10 * ui_scale, ORANGE)
			_label("余额最低为 0", rules.position + Vector2(10, 84) * ui_scale, 9 * ui_scale, MUTED)

	func _draw_skin_preview(area: Rect2, tint: Color, secondary: Color, index: int) -> void:
		var factor: float = minf(area.size.x / 204.0, area.size.y / 61.0)
		var origin: Vector2 = area.get_center() - Vector2(102, 30.5) * factor
		var dark: Color = Color("142126")
		var steel: Color = Color("53656a")
		draw_line(origin + Vector2(10, 58) * factor, origin + Vector2(195, 58) * factor, Color(tint, 0.12), 3 * factor, true)
		var stock: PackedVector2Array = PackedVector2Array([Vector2(3, 24), Vector2(38, 19), Vector2(48, 24), Vector2(39, 39), Vector2(3, 43)])
		for i in range(stock.size()): stock[i] = origin + stock[i] * factor
		draw_colored_polygon(stock, secondary)
		draw_polyline(PackedVector2Array([stock[0], stock[1], stock[2]]), tint.darkened(0.1), 2 * factor, true)
		draw_rect(Rect2(origin + Vector2(43, 23) * factor, Vector2(87, 17) * factor), tint.darkened(0.25))
		draw_rect(Rect2(origin + Vector2(103, 23) * factor, Vector2(49, 15) * factor), secondary)
		draw_rect(Rect2(origin + Vector2(38, 18) * factor, Vector2(111, 5) * factor), dark)
		draw_rect(Rect2(origin + Vector2(151, 27) * factor, Vector2(35, 5) * factor), steel)
		draw_rect(Rect2(origin + Vector2(185, 24) * factor, Vector2(16, 11) * factor), secondary)
		var grip: PackedVector2Array = PackedVector2Array([Vector2(59, 40), Vector2(74, 40), Vector2(69, 57), Vector2(57, 54)])
		var magazine: PackedVector2Array = PackedVector2Array([Vector2(85, 39), Vector2(104, 39), Vector2(110, 55), Vector2(91, 59)])
		for i in range(grip.size()): grip[i] = origin + grip[i] * factor
		for i in range(magazine.size()): magazine[i] = origin + magazine[i] * factor
		draw_colored_polygon(grip, dark)
		draw_colored_polygon(magazine, secondary)
		draw_line(origin + Vector2(89, 43) * factor, origin + Vector2(105, 43) * factor, tint, 2 * factor, true)
		draw_rect(Rect2(origin + Vector2(73, 13) * factor, Vector2(5, 7) * factor), steel)
		draw_rect(Rect2(origin + Vector2(92, 13) * factor, Vector2(5, 7) * factor), steel)
		draw_rect(Rect2(origin + Vector2(67, 7) * factor, Vector2(37, 8) * factor), dark)
		draw_rect(Rect2(origin + Vector2(100, 6) * factor, Vector2(7, 11) * factor), tint.darkened(0.1))
		draw_line(origin + Vector2(49, 25) * factor, origin + Vector2(129, 25) * factor, Color(tint, 0.65), 2 * factor, true)
		for i in range(4):
			draw_line(origin + Vector2(114 + i * 8, 26) * factor, origin + Vector2(110 + i * 8, 35) * factor, tint, 1.5 * factor, true)
		if index == 3:
			var lightning: PackedVector2Array = PackedVector2Array([Vector2(46, 28), Vector2(65, 34), Vector2(61, 26), Vector2(89, 34), Vector2(84, 26), Vector2(105, 32)])
			for i in range(lightning.size()): lightning[i] = origin + lightning[i] * factor
			draw_polyline(lightning, secondary.lightened(0.16), 2 * factor, true)
		else:
			for i in range(3):
				draw_line(origin + Vector2(48 + i * 17, 28) * factor, origin + Vector2(56 + i * 17, 36) * factor, tint.lightened(0.2) if index != 2 else Color("ffd180"), 2.5 * factor, true)

	func _draw_pause() -> void:
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.006, 0.027, 0.033, 0.78))
		_panel(menu_rect, Color(0.025, 0.065, 0.068, 0.98), LINE, 10)
		var p: Vector2 = menu_rect.position + Vector2(26, 36) * ui_scale
		_label("OPERATION / PAUSED", p, 10 * ui_scale, MINT)
		_label("行动暂停", p + Vector2(0, 44 * ui_scale), 30 * ui_scale, WHITE)
		_label("调整呼吸，准备返回行动。", p + Vector2(0, 77 * ui_scale), 12 * ui_scale, MUTED)
		_button("resume", "继续行动", true, "ESC →")
		_button("restart", "重新开始", false, "↻")

	func _draw_results(won: bool) -> void:
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.008, 0.030, 0.034, 0.87))
		_panel(menu_rect, Color(0.024, 0.064, 0.065, 0.97), MINT if won else Color(0.75, 0.42, 0.25, 0.55), 10)
		var ink: Color = MINT if won else ORANGE
		var p: Vector2 = menu_rect.position + Vector2(28, 33) * ui_scale
		var mission_data: Dictionary = mission_display()
		var account: Dictionary = settlement_display()
		_label("特务 91 / 任务 %02d / " % int(mission_data.number) + ("COMPLETE" if won else "FAILED"), p, 10 * ui_scale, ink)
		_label("成功撤离" if won else "行动终止", p + Vector2(0, 40 * ui_scale), 32 * ui_scale, WHITE)
		var outcome: String = str(mission_data.name) + (" · 任务完成，与小队成功撤离。" if won else "\n" + str(account.failure_reason))
		if not won and str(account.failure_reason).is_empty():
			outcome = str(mission_data.name) + " · 行动未完成。"
		_paragraph(outcome, p + Vector2(0, 70 * ui_scale), menu_rect.size.x - 56 * ui_scale, 11 * ui_scale, MUTED, 2)
		var wallet_x: float = p.x + (menu_rect.size.x - 56 * ui_scale) * 0.56
		_label("本次行动资金", p + Vector2(0, 109 * ui_scale), 10 * ui_scale, MUTED)
		_label(str(account.delta_text), p + Vector2(0, 153 * ui_scale), 39 * ui_scale, MINT if int(account.delta) >= 0 else ORANGE)
		_label("当前余额", Vector2(wallet_x, p.y + 109 * ui_scale), 10 * ui_scale, MUTED)
		_label(str(account.balance), Vector2(wallet_x, p.y + 151 * ui_scale), 31 * ui_scale, WHITE)
		_label("行动积分 %06d" % int(hud.state.get("score", 0)), p + Vector2(0, 176 * ui_scale), 10 * ui_scale, MUTED)
		_label("累计成功 %d 次" % int(account.wins), Vector2(wallet_x, p.y + 176 * ui_scale), 10 * ui_scale, MUTED)
		var stats_y: float = p.y + 207 * ui_scale
		var middle_label: String = "目标状态" if mission_data.has_target else "击败敌人"
		var middle_value: String = str(mission_data.target_status) if mission_data.has_target else str(int(hud.state.get("kills", 0)))
		var metrics: Array = [[str(mission_data.item), str(mission_data.count)], [middle_label, middle_value], ["撤离积分", "+%d" % int(hud.state.get("result_bonus", 0))]]
		var cell_w: float = (menu_rect.size.x - 56 * ui_scale) / 3
		for i in range(3):
			var x: float = p.x + i * cell_w
			_label(str(metrics[i][0]), Vector2(x, stats_y), 9 * ui_scale, MUTED)
			_label(str(metrics[i][1]), Vector2(x, stats_y + 25 * ui_scale), 19 * ui_scale, WHITE)
			draw_line(Vector2(x, stats_y - 12 * ui_scale), Vector2(x + cell_w - 14 * ui_scale, stats_y - 12 * ui_scale), LINE, 1)
		var notice: Rect2 = Rect2(Vector2(p.x, menu_rect.position.y + 281 * ui_scale), Vector2(menu_rect.size.x - 56 * ui_scale, 55 * ui_scale))
		if not str(account.new_skin).is_empty():
			_panel(notice, Color(0.095, 0.17, 0.13, 0.96), MINT, 5)
			_label("新外观已解锁", notice.position + Vector2(11, 20) * ui_scale, 9 * ui_scale, MINT)
			_paragraph(str(account.new_skin), notice.position + Vector2(11, 41) * ui_scale, notice.size.x - 123 * ui_scale, 14 * ui_scale, WHITE, 1)
			_button("open_skins", "换装", false, "→")
		else:
			_label("任务成功积累资金与胜场，逐步解锁外观。" if won else "本次损失已结算，行动资金最低为 0。", notice.position + Vector2(0, 20) * ui_scale, 10 * ui_scale, MUTED)
		_button("restart", "部署下一任务", true, "ENTER  →")
