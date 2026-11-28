extends RefCounted
## Utilitários de UI por código: tema (fonte Inter, botões arredondados), fundo com
## textura, painéis e botões. Usado por todos os menus.

const FONT_PATH: String = "res://assets/fonts/Inter-ExtraBold.otf"
const BG_PATH: String = "res://assets/textures/ui/menu_bg.png"
const HALFTONE_PATH: String = "res://assets/textures/ui/halftone.png"
const LOGO_PATH: String = "res://assets/textures/ui/logo.png"
const ACCENT: Color = Color(0.18, 0.5, 0.95)
const DARK: Color = Color(0.04, 0.06, 0.14, 0.92)
const GOLD: Color = Color(1.0, 0.82, 0.2)


static func box(color: Color, radius: int = 12, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.set_border_width_all(border_w)
		sb.border_color = border
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


static func make_theme() -> Theme:
	var t: Theme = Theme.new()
	if ResourceLoader.exists(FONT_PATH):
		var f: Font = load(FONT_PATH)
		t.default_font = f
	t.default_font_size = 22
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", Color(0.02, 0.03, 0.1))
	t.set_constant("outline_size", "Label", 4)
	t.set_stylebox("normal", "Button", box(Color(0.1, 0.16, 0.34, 0.95), 12, Color(0.3, 0.55, 1.0, 0.9), 2))
	t.set_stylebox("hover", "Button", box(Color(0.16, 0.3, 0.62, 1.0), 12, Color(0.6, 0.85, 1.0), 2))
	t.set_stylebox("pressed", "Button", box(Color(0.25, 0.45, 0.9, 1.0), 12, Color.WHITE, 2))
	t.set_stylebox("disabled", "Button", box(Color(0.1, 0.1, 0.16, 0.7), 12, Color(0.3, 0.3, 0.4), 1))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 12, GOLD, 3))
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.55, 0.65))
	t.set_stylebox("panel", "PanelContainer", box(DARK, 16, Color(0.3, 0.5, 0.9, 0.6), 2))
	t.set_stylebox("panel", "Panel", box(DARK, 16, Color(0.3, 0.5, 0.9, 0.6), 2))
	t.set_stylebox("normal", "LineEdit", box(Color(0.02, 0.04, 0.1, 0.9), 8, Color(0.3, 0.5, 0.9), 2))
	t.set_color("font_color", "LineEdit", Color.WHITE)
	return t


static func full(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Tela cheia respeitando as margens seguras (notch/cantos).
static func safe_full(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	apply_safe(c)


## Entrada animada: cada filho aparece deslizando/escalando com atraso escalonado.
static func animate_in(container: Node, step: float = 0.06) -> void:
	var i: int = 0
	for ch: Node in container.get_children():
		if ch is Control:
			var c: Control = ch
			c.modulate.a = 0.0
			var tw: Tween = c.create_tween()
			tw.tween_interval(step * float(i))
			tw.tween_property(c, "modulate:a", 1.0, 0.25)
			i += 1


## Pulso suave em loop (logo, destaques).
static func float_loop(c: Control, amp: float = 6.0, period: float = 2.4) -> void:
	var tw: Tween = c.create_tween().set_loops()
	tw.tween_property(c, "position:y", c.position.y - amp, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "position:y", c.position.y + amp, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func hover_scale(b: Control, k: float = 1.05) -> void:
	b.mouse_entered.connect(_hover.bind(b, k))
	b.mouse_exited.connect(_hover.bind(b, 1.0))


static func _hover(b: Control, k: float) -> void:
	b.pivot_offset = b.size / 2.0
	var tw: Tween = b.create_tween()
	tw.tween_property(b, "scale", Vector2(k, k), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func background(parent: Control) -> void:
	var bg: TextureRect = TextureRect.new()
	full(bg)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(BG_PATH):
		bg.texture = load(BG_PATH)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	# fundo vivo: zoom lento em vai-e-vem
	bg.resized.connect(_center_pivot.bind(bg))
	var zoom: Tween = bg.create_tween().set_loops()
	zoom.tween_property(bg, "scale", Vector2(1.07, 1.07), 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	zoom.tween_property(bg, "scale", Vector2.ONE, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var shade: ColorRect = ColorRect.new()
	full(shade)
	shade.color = Color(0.0, 0.02, 0.08, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)


static func _center_pivot(c: Control) -> void:
	c.pivot_offset = c.size / 2.0


static func label(text: String, size: int = 22, color: Color = Color.WHITE, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align as HorizontalAlignment
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, callback: Callable, min_size: Vector2 = Vector2(220, 56), font_size: int = 24) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(callback)
	b.pressed.connect(func() -> void: Sfx.play("ui_click", -4.0, 0.02))
	b.mouse_entered.connect(func() -> void: Sfx.play("ui_hover", -14.0, 0.02))
	hover_scale(b)
	return b


static func texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


static func logo(parent: Control, width: float = 640.0) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.texture = texture(LOGO_PATH)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(width, width * 0.24)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## Retrato do personagem: usa imagem do próprio jogador se existir
## (user://portraits/<id>.png ou res://assets/custom_portraits/<id>.png),
## senão o retrato gerado do jogo.
static func portrait(id: String) -> Texture2D:
	for path: String in ["user://portraits/%s.png" % id, "res://assets/custom_portraits/%s.png" % id]:
		if path.begins_with("user://"):
			if FileAccess.file_exists(path):
				var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
				if img != null:
					return ImageTexture.create_from_image(img)
		elif ResourceLoader.exists(path):
			return load(path)
	return texture("res://assets/textures/portraits/%s.png" % id)


## Margens seguras (notch, cantos arredondados, barra de gestos) em unidades do viewport:
## x = esquerda, y = topo, z = direita, w = baixo. No desktop volta zero.
static func safe_inset(vp: Viewport) -> Vector4:
	if not (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()):
		return Vector4.ZERO
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	if win.x < 1.0 or win.y < 1.0:
		return Vector4(14, 8, 14, 10)
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen: Vector2 = Vector2(DisplayServer.screen_get_size())
	var vs: Vector2 = vp.get_visible_rect().size
	var sx: float = vs.x / win.x
	var sy: float = vs.y / win.y
	var l: float = maxf(float(safe.position.x) * sx, 0.0)
	var t: float = maxf(float(safe.position.y) * sy, 0.0)
	var r: float = maxf((screen.x - float(safe.end.x)) * sx, 0.0)
	var b: float = maxf((screen.y - float(safe.end.y)) * sy, 0.0)
	return Vector4(maxf(l, 14.0), maxf(t, 8.0), maxf(r, 14.0), maxf(b, 10.0))


## Aplica a margem segura a um Control de tela cheia.
static func apply_safe(c: Control, extra: float = 0.0) -> void:
	var v: Vector4 = safe_inset(c.get_viewport())
	c.offset_left = v.x + extra
	c.offset_top = v.y + extra
	c.offset_right = -(v.z + extra)
	c.offset_bottom = -(v.w + extra)
