extends CanvasLayer
## HUD da partida: placar, cronômetro, stamina, barra de força do chute,
## mensagens centrais (GOL!) e FPS. Construído por código (sem .tscn manual).

var _score: Label
var _time: Label
var _message: Label
var _fps: Label
var _stamina_bar: ProgressBar
var _power_bar: ProgressBar
var _msg_tween: Tween


func _ready() -> void:
	layer = 10
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_score = _label(root, 40, Control.PRESET_CENTER_TOP, Vector2(-240.0, 12.0), Vector2(480.0, 56.0))
	_time = _label(root, 26, Control.PRESET_CENTER_TOP, Vector2(-120.0, 66.0), Vector2(240.0, 36.0))
	_fps = _label(root, 16, Control.PRESET_TOP_RIGHT, Vector2(-120.0, 10.0), Vector2(110.0, 24.0))
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_message = _label(root, 88, Control.PRESET_CENTER, Vector2(-420.0, -90.0), Vector2(840.0, 130.0))
	_message.visible = false

	_stamina_bar = _bar(root, Control.PRESET_TOP_LEFT, Vector2(20.0, 20.0), Vector2(220.0, 16.0), Color(0.3, 0.85, 1.0))
	_power_bar = _bar(root, Control.PRESET_CENTER_BOTTOM, Vector2(-130.0, -34.0), Vector2(260.0, 14.0), Color(1.0, 0.75, 0.2))
	_power_bar.visible = false

	set_score(0, 0)
	set_time(0.0)


## Posiciona um Control por offsets relativos às âncoras do preset.
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


func set_score(blue: int, red: int) -> void:
	_score.text = "AZUL  %d  -  %d  VERMELHO" % [blue, red]


@warning_ignore("integer_division")
func set_time(seconds_left: float) -> void:
	var s: int = int(ceilf(maxf(seconds_left, 0.0)))
	_time.text = "%d:%02d" % [s / 60, s % 60]


func update_bars(stamina_ratio: float, charge: float, charging: bool) -> void:
	_stamina_bar.value = stamina_ratio
	_power_bar.visible = charging
	_power_bar.value = charge
	_fps.text = "%d FPS" % Engine.get_frames_per_second()


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
