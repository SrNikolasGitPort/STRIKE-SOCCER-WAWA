extends CanvasLayer
## HUD da partida: placar, cronômetro, stamina, força do chute, Flow, Despertar,
## 6 slots de skill (3 normais + 3 de Despertar, clicáveis/tocáveis), avisos e FPS.

signal pause_requested

var _score: Label
var _time: Label
var _message: Label
var _fps: Label
var _stamina_bar: ProgressBar
var _power_bar: ProgressBar
var _flow_bar: ProgressBar
var _awake_bar: ProgressBar
var _awake_label: Label
var _toast_box: VBoxContainer
var _msg_tween: Tween
var _slots: Array[Dictionary] = []
var _player: Node = null
var _names: Array[String] = ["AZUL", "VERMELHO"]
var _last_score: Array[int] = [0, 0]


func _ready() -> void:
	layer = 10
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_score = _label(root, 38, Control.PRESET_CENTER_TOP, Vector2(-300.0, 8.0), Vector2(600.0, 52.0))
	_time = _label(root, 26, Control.PRESET_CENTER_TOP, Vector2(-120.0, 58.0), Vector2(240.0, 34.0))
	_fps = _label(root, 16, Control.PRESET_TOP_RIGHT, Vector2(-190.0, 10.0), Vector2(110.0, 24.0))
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_message = _label(root, 88, Control.PRESET_CENTER, Vector2(-520.0, -90.0), Vector2(1040.0, 130.0))
	_message.visible = false

	_stamina_bar = _bar(root, Control.PRESET_TOP_LEFT, Vector2(20.0, 20.0), Vector2(220.0, 14.0), Color(0.3, 0.85, 1.0))
	_flow_bar = _bar(root, Control.PRESET_TOP_LEFT, Vector2(20.0, 40.0), Vector2(220.0, 10.0), Color(0.75, 0.45, 1.0))
	_awake_bar = _bar(root, Control.PRESET_TOP_LEFT, Vector2(20.0, 58.0), Vector2(220.0, 14.0), Color(1.0, 0.82, 0.2))
	_awake_bar.visible = false
	_awake_label = _label(root, 16, Control.PRESET_TOP_LEFT, Vector2(20.0, 74.0), Vector2(220.0, 22.0))
	_awake_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_power_bar = _bar(root, Control.PRESET_CENTER_BOTTOM, Vector2(-130.0, -150.0), Vector2(260.0, 14.0), Color(1.0, 0.75, 0.2))
	_power_bar.visible = false

	_toast_box = VBoxContainer.new()
	_place(_toast_box, Control.PRESET_TOP_RIGHT, Vector2(-380.0, 44.0), Vector2(360.0, 200.0))
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast_box)

	var pause: Button = Button.new()
	pause.text = "II"
	_place(pause, Control.PRESET_TOP_RIGHT, Vector2(-70.0, 8.0), Vector2(56.0, 40.0))
	pause.pressed.connect(func() -> void: pause_requested.emit())
	pause.focus_mode = Control.FOCUS_NONE
	root.add_child(pause)

	for i: int in range(6):
		_make_slot(root, i)

	set_score(0, 0)
	set_time(0.0)


func _make_slot(root: Control, i: int) -> void:
	var size: float = 62.0
	var gap: float = 8.0
	var group_gap: float = 26.0 if i >= 3 else 0.0
	var total: float = 6.0 * size + 5.0 * gap + 26.0
	var x: float = -total / 2.0 + float(i) * (size + gap) + group_gap
	var panel: Panel = Panel.new()
	_place(panel, Control.PRESET_CENTER_BOTTOM, Vector2(x, -size - 14.0), Vector2(size, size))
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.12, 0.8)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.82, 0.2) if i >= 3 else Color(0.4, 0.7, 1.0)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	var icon: TextureRect = TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6.0
	icon.offset_top = 6.0
	icon.offset_right = -6.0
	icon.offset_bottom = -6.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	var cd: Label = Label.new()
	cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd.add_theme_font_size_override("font_size", 24)
	cd.add_theme_color_override("font_outline_color", Color.BLACK)
	cd.add_theme_constant_override("outline_size", 6)
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(cd)
	var key: Label = Label.new()
	key.text = str(i + 1)
	key.position = Vector2(4.0, 0.0)
	key.add_theme_font_size_override("font_size", 14)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(key)
	var action: String = "skill_%d" % (i + 1)
	panel.gui_input.connect(func(ev: InputEvent) -> void: _slot_input(ev, action))
	_slots.append({"panel": panel, "icon": icon, "cd": cd, "sb": sb, "sid": ""})


func _slot_input(ev: InputEvent, action: String) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		Input.action_press(action)
		get_tree().create_timer(0.12).timeout.connect(func() -> void: Input.action_release(action))


func _place(c: Control, preset: int, offset: Vector2, size: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y


func _label(parent: Control, font_size: int, preset: int, offset: Vector2, size: Vector2) -> Label:
	var l: Label = Label.new()
	_place(l, preset, offset, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.08))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _bar(parent: Control, preset: int, offset: Vector2, size: Vector2, color: Color) -> ProgressBar:
	var b: ProgressBar = ProgressBar.new()
	_place(b, preset, offset, size)
	b.min_value = 0.0
	b.max_value = 1.0
	b.step = 0.001
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	back.set_corner_radius_all(6)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", back)
	parent.add_child(b)
	return b


func set_team_names(a: String, b: String) -> void:
	_names = [a, b]
	set_score(_last_score[0], _last_score[1])


func set_score(blue: int, red: int) -> void:
	_last_score = [blue, red]
	_score.text = "%s  %d  -  %d  %s" % [_names[0], blue, red, _names[1]]


@warning_ignore("integer_division")
func set_time(seconds_left: float) -> void:
	if seconds_left > 3000.0:
		_time.text = "∞"
		return
	var s: int = int(ceilf(maxf(seconds_left, 0.0)))
	_time.text = "%d:%02d" % [s / 60, s % 60]


func bind_player(p: Node) -> void:
	_player = p
	for i: int in range(6):
		_slots[i]["sid"] = "?"


func update_bars(stamina_ratio: float, charge: float, charging: bool) -> void:
	_stamina_bar.value = stamina_ratio
	_power_bar.visible = charging
	_power_bar.value = charge
	_fps.visible = bool(Game.settings.get("show_fps", false)) or OS.is_debug_build()
	_fps.text = "%d FPS" % Engine.get_frames_per_second()
	if _player == null or not is_instance_valid(_player):
		return
	_flow_bar.value = float(_player.get("flow")) / Config.f("flow.max") if float(_player.get("flow_t")) <= 0.0 else float(_player.get("flow_t")) / Config.f("flow.duration_s")
	var awake: bool = bool(_player.get("awakened"))
	_awake_bar.visible = awake
	_awake_label.text = (Game.t("DESPERTAR!", "AWAKENING!") if awake else "")
	if awake:
		_awake_bar.value = float(_player.get("awake_left")) / Config.f("awakening.duration_s")
	for i: int in range(6):
		_update_slot(i, awake)


func _update_slot(i: int, awake: bool) -> void:
	var slot: Dictionary = _slots[i]
	var sid: String = String(_player.call("skill_at", i))
	var panel: Panel = slot["panel"]
	if sid != String(slot["sid"]):
		slot["sid"] = sid
		var icon: TextureRect = slot["icon"]
		if sid == "":
			icon.texture = null
		else:
			var eff: String = String(Game.skill(sid).get("effect", "shot"))
			icon.texture = load("res://assets/textures/icons/skill_" + eff + ".png")
	panel.visible = sid != "" or i < 3
	var left: float = float(_player.call("cooldown_left", i))
	var cd: Label = slot["cd"]
	var usable: bool = sid != "" and (i < 3 or awake)
	cd.text = "%.0f" % ceilf(left) if left > 0.05 and usable else ""
	panel.modulate = Color(1, 1, 1, 1.0 if usable and left <= 0.05 else 0.45)


func toast(text: String, color: Color = Color.WHITE) -> void:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_child(l)
	var tw: Tween = l.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


## Mensagem grande no centro. duration <= 0 mantém até a próxima mensagem.
func show_message(text: String, color: Color, duration: float) -> void:
	if _msg_tween != null:
		_msg_tween.kill()
	_message.text = text
	_message.add_theme_color_override("font_color", color)
	_message.visible = true
	_message.modulate = Color.WHITE
	_message.pivot_offset = _message.size / 2.0
	_message.scale = Vector2(1.6, 1.6)
	_msg_tween = create_tween()
	_msg_tween.tween_property(_message, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if duration > 0.0:
		_msg_tween.tween_interval(duration)
		_msg_tween.tween_property(_message, "modulate:a", 0.0, 0.3)
		_msg_tween.tween_callback(func() -> void: _message.visible = false)


func hide_message() -> void:
	if _msg_tween != null:
		_msg_tween.kill()
	_message.visible = false
