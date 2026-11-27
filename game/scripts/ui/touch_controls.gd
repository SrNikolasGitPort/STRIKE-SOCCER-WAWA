extends Control
## Controles de toque: joystick flutuante (metade esquerda da tela) e
## botões virtuais à direita. Injeta as MESMAS ações do teclado/gamepad
## (move_*, sprint, shoot, pass, lob, reset_ball). Só aparece em dispositivos
## com tela de toque. Editor de posição/tamanho dos botões entra no M2.

var enabled: bool = false

var _joy_id: int = -1
var _joy_origin: Vector2 = Vector2.ZERO
var _joy_pos: Vector2 = Vector2.ZERO
var _joy_strength: Vector2 = Vector2.ZERO

# nome -> { action, label, center, radius, finger }
var _buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	enabled = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	visible = enabled
	_buttons = {
		"shoot": {"action": "shoot", "label": "CHUTE", "center": Vector2.ZERO, "radius": Config.f("touch.button_big_radius"), "finger": -1},
		"pass": {"action": "pass", "label": "PASSE", "center": Vector2.ZERO, "radius": Config.f("touch.button_small_radius"), "finger": -1},
		"lob": {"action": "lob", "label": "ALTO", "center": Vector2.ZERO, "radius": Config.f("touch.button_small_radius"), "finger": -1},
		"sprint": {"action": "sprint", "label": "SPRINT", "center": Vector2.ZERO, "radius": Config.f("touch.button_small_radius"), "finger": -1},
		"dribble": {"action": "dribble", "label": "DRIBLE", "center": Vector2.ZERO, "radius": Config.f("touch.button_small_radius"), "finger": -1},
		"tackle": {"action": "tackle", "label": "DESARME", "center": Vector2.ZERO, "radius": Config.f("touch.button_small_radius"), "finger": -1},
		"awaken": {"action": "awaken", "label": "DESPERTAR", "center": Vector2.ZERO, "radius": Config.f("touch.button_small_radius"), "finger": -1},
		"reset": {"action": "reset_ball", "label": "R", "center": Vector2.ZERO, "radius": Config.f("touch.button_small_radius") * 0.55, "finger": -1},
	}


## Verdadeiro se o dedo está controlando joystick ou botão (senão gira a câmera).
func claims(index: int) -> bool:
	if index == _joy_id:
		return true
	for key: String in _buttons.keys():
		if int((_buttons[key] as Dictionary)["finger"]) == index:
			return true
	return false


func _layout() -> void:
	var view: Vector2 = get_viewport_rect().size
	var m: float = Config.f("touch.margin")
	var big: float = Config.f("touch.button_big_radius")
	var small: float = Config.f("touch.button_small_radius")
	var gap: float = 14.0
	var shoot: Vector2 = Vector2(view.x - m - big, view.y - m - big)
	_buttons["shoot"]["center"] = shoot
	_buttons["pass"]["center"] = Vector2(shoot.x - big - small - gap, shoot.y + (big - small))
	_buttons["lob"]["center"] = Vector2(shoot.x, shoot.y - big - small - gap)
	_buttons["sprint"]["center"] = Vector2(shoot.x - big - small - gap, shoot.y - small * 2.0 - gap + (big - small))
	_buttons["dribble"]["center"] = Vector2(shoot.x - big - small * 3.0 - gap * 2.0, shoot.y + (big - small))
	_buttons["tackle"]["center"] = Vector2(shoot.x - big - small * 3.0 - gap * 2.0, shoot.y - small * 2.0 - gap + (big - small))
	_buttons["awaken"]["center"] = Vector2(shoot.x, shoot.y - big - small * 3.0 - gap * 2.0)
	_buttons["reset"]["center"] = Vector2(view.x - m - 30.0, 120.0)


func _process(_delta: float) -> void:
	if not enabled:
		return
	_layout()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_on_press(touch.index, touch.position)
		else:
			_on_release(touch.index)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == _joy_id:
			_joy_pos = drag.position
			_update_stick()


func _on_press(index: int, pos: Vector2) -> void:
	for key: String in _buttons.keys():
		var b: Dictionary = _buttons[key]
		if pos.distance_to(b["center"]) <= float(b["radius"]) * 1.15:
			b["finger"] = index
			Input.action_press(String(b["action"]))
			return
	var view: Vector2 = get_viewport_rect().size
	if _joy_id == -1 and pos.x < view.x * Config.f("touch.joystick_zone_fraction"):
		_joy_id = index
		_joy_origin = pos
		_joy_pos = pos
		_update_stick()


func _on_release(index: int) -> void:
	for key: String in _buttons.keys():
		var b: Dictionary = _buttons[key]
		if int(b["finger"]) == index:
			b["finger"] = -1
			Input.action_release(String(b["action"]))
	if index == _joy_id:
		_joy_id = -1
		_joy_strength = Vector2.ZERO
		_apply_stick()


func _update_stick() -> void:
	var radius: float = Config.f("touch.joystick_radius")
	var delta: Vector2 = (_joy_pos - _joy_origin).limit_length(radius)
	var s: Vector2 = delta / radius
	if s.length() < Config.f("touch.deadzone"):
		s = Vector2.ZERO
	_joy_strength = s
	_apply_stick()


func _apply_stick() -> void:
	_set_axis("move_right", "move_left", _joy_strength.x)
	_set_axis("move_back", "move_forward", _joy_strength.y)


func _set_axis(positive: String, negative: String, value: float) -> void:
	if value > 0.0:
		Input.action_press(positive, value)
		Input.action_release(negative)
	elif value < 0.0:
		Input.action_press(negative, -value)
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


func _draw() -> void:
	if not enabled:
		return
	var opacity: float = Config.f("touch.opacity")
	var radius: float = Config.f("touch.joystick_radius")
	var view: Vector2 = get_viewport_rect().size
	var base: Vector2 = _joy_origin if _joy_id != -1 else Vector2(Config.f("touch.margin") + radius * 1.2, view.y - Config.f("touch.margin") - radius * 1.2)
	var thumb: Vector2 = base + (_joy_strength * radius if _joy_id != -1 else Vector2.ZERO)
	draw_circle(base, radius, Color(1.0, 1.0, 1.0, opacity * 0.25))
	draw_arc(base, radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, opacity), 3.0)
	draw_circle(thumb, radius * 0.4, Color(1.0, 1.0, 1.0, opacity * 0.7))

	var font: Font = ThemeDB.fallback_font
	for key: String in _buttons.keys():
		var b: Dictionary = _buttons[key]
		var pressed: bool = int(b["finger"]) != -1
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		var fill: Color = Color(1.0, 0.8, 0.25, opacity * (1.3 if pressed else 0.45)) if key == "shoot" else Color(0.35, 0.7, 1.0, opacity * (1.3 if pressed else 0.4))
		draw_circle(c, r, fill)
		draw_arc(c, r, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, opacity), 3.0)
		var fs: int = int(r * 0.36)
		draw_string(font, c + Vector2(-r, fs * 0.35), String(b["label"]), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1.0, 1.0, 1.0, minf(opacity + 0.4, 1.0)))
