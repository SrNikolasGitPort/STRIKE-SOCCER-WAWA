extends Node
## Camada de efeitos: partículas (sprites PNG), anéis de choque, aura de Despertar,
## flash de tela, linhas de velocidade, letterbox, onomatopeias em kana e
## cutscene curta de skill (FOV punch + câmera lenta local só offline).

const TEX_DIR: String = "res://assets/textures/"

var rig: Node = null
var _layer: CanvasLayer
var _root: Control
var _flash: ColorRect
var _lines: TextureRect
var _bar_top: ColorRect
var _bar_bot: ColorRect
var _banner: Label
var _tex_cache: Dictionary = {}
var _cut_token: int = 0
var online: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 8
	add_child(_layer)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)

	_lines = TextureRect.new()
	_lines.texture = tex("vfx/speedlines.png")
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lines.stretch_mode = TextureRect.STRETCH_SCALE
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.modulate = Color(1, 1, 1, 0)
	_root.add_child(_lines)

	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

	_bar_top = _letter(true)
	_bar_bot = _letter(false)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_banner.offset_left = -500.0
	_banner.offset_right = 500.0
	_banner.offset_top = -190.0
	_banner.offset_bottom = -110.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 46)
	_banner.add_theme_color_override("font_color", Color.WHITE)
	_banner.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.1))
	_banner.add_theme_constant_override("outline_size", 12)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_banner)


func _letter(top: bool) -> ColorRect:
	var c: ColorRect = ColorRect.new()
	c.color = Color.BLACK
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
	c.offset_left = 0.0
	c.offset_right = 0.0
	if top:
		c.offset_top = -90.0
		c.offset_bottom = 0.0
	else:
		c.offset_top = 0.0
		c.offset_bottom = 90.0
	_root.add_child(c)
	return c


func tex(rel: String) -> Texture2D:
	if _tex_cache.has(rel):
		return _tex_cache[rel]
	var path: String = TEX_DIR + rel
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_tex_cache[rel] = t
	return t


func _quality_scale() -> float:
	match Config.quality_level:
		Config.Quality.LOW: return 0.4
		Config.Quality.MEDIUM: return 0.7
	return 1.0


# --------------------------------------------------------------- 3D
func _particles(parent: Node, pos: Vector3, color: Color, count: int, speed: float, size: float, life: float, sprite: String, gravity: float, one_shot: bool) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = maxi(int(float(count) * _quality_scale()), 4)
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 0.95 if one_shot else 0.0
	p.emitting = true
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, -gravity, 0.0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var m: QuadMesh = QuadMesh.new()
	m.size = Vector2(1.0, 1.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex("vfx/" + sprite + ".png")
	mat.disable_receive_shadows = true
	m.material = mat
	p.mesh = m
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(color.r, color.g, color.b, 1.0))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = grad
	p.position = pos
	parent.add_child(p)
	if one_shot:
		get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)
	return p


func burst(world: Node3D, pos: Vector3, color: Color, count: int = 24, speed: float = 6.0, size: float = 0.6, life: float = 0.7, sprite: String = "glow") -> void:
	_particles(world, pos, color, count, speed, size, life, sprite, 2.0, true)


func ring(world: Node3D, pos: Vector3, color: Color, max_scale: float = 9.0, life: float = 0.55) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = tex("vfx/ring.png")
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	q.material = mat
	mi.mesh = q
	mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	mi.position = pos + Vector3(0.0, 0.08, 0.0)
	mi.scale = Vector3(0.5, 0.5, 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	var tw: Tween = mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(max_scale, max_scale, max_scale), life).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(mi.queue_free)


func shockwave(world: Node3D, pos: Vector3, color: Color, radius: float) -> void:
	ring(world, pos, color, radius * 2.2, 0.6)
	ring(world, pos, Color(1, 1, 1, 0.8), radius * 1.4, 0.4)
	burst(world, pos + Vector3(0, 0.4, 0), color, 36, radius * 1.6, 0.8, 0.8, "smoke")
	if rig != null:
		rig.call("shake", 0.5)


## Aura contínua presa ao jogador (Despertar). Retorna o nó para ser removido depois.
func attach_aura(player: Node3D, color: Color) -> Node3D:
	var holder: Node3D = Node3D.new()
	player.add_child(holder)
	var p: CPUParticles3D = _particles(holder, Vector3(0, -0.8, 0), color, 40, 2.4, 0.9, 0.9, "glow", -3.0, false)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	var p2: CPUParticles3D = _particles(holder, Vector3(0, 0.2, 0), Color(1, 1, 1), 14, 0.6, 0.35, 0.8, "star", -2.0, false)
	p2.spread = 60.0
	p2.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p2.emission_sphere_radius = 0.6
	return holder


func trail(world: Node3D, pos: Vector3, color: Color) -> void:
	burst(world, pos, color, 6, 1.2, 0.5, 0.35, "soft")


# --------------------------------------------------------------- 2D
func flash(color: Color, duration: float = 0.35, strength: float = 0.8) -> void:
	_flash.color = Color(color.r, color.g, color.b, strength)
	var tw: Tween = _flash.create_tween()
	tw.tween_property(_flash, "color:a", 0.0, duration)


func speedlines(on: bool, color: Color = Color.WHITE) -> void:
	var tw: Tween = _lines.create_tween()
	tw.tween_property(_lines, "modulate", Color(color.r, color.g, color.b, 0.55 if on else 0.0), 0.2)


func letterbox(on: bool) -> void:
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_bar_top, "offset_top", 0.0 if on else -90.0, 0.2)
	tw.tween_property(_bar_top, "offset_bottom", 90.0 if on else 0.0, 0.2)
	tw.tween_property(_bar_bot, "offset_top", -90.0 if on else 0.0, 0.2)
	tw.tween_property(_bar_bot, "offset_bottom", 0.0 if on else 90.0, 0.2)


## Onomatopeia em kana (PNG) que estoura na tela e some.
func ono(key: String, screen_pos: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> void:
	var t: Texture2D = tex("ono/" + key + ".png")
	if t == null:
		return
	var tr: TextureRect = TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var sz: Vector2 = Vector2(vp.x * 0.32, vp.x * 0.2)
	var center: Vector2 = screen_pos if screen_pos != Vector2.ZERO else Vector2(vp.x * randf_range(0.2, 0.75), vp.y * randf_range(0.2, 0.45))
	tr.size = sz
	tr.pivot_offset = sz / 2.0
	tr.position = center - sz / 2.0
	tr.rotation = deg_to_rad(randf_range(-12.0, 12.0))
	tr.scale = Vector2(0.3, 0.3)
	tr.modulate = tint
	_root.add_child(tr)
	var tw: Tween = tr.create_tween()
	tw.tween_property(tr, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tr, "scale", Vector2(1.0, 1.0), 0.1)
	tw.tween_interval(0.5)
	tw.tween_property(tr, "modulate:a", 0.0, 0.25)
	tw.tween_callback(tr.queue_free)


func banner(text: String, color: Color, duration: float = 1.6) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 1.0
	var tw: Tween = _banner.create_tween()
	tw.tween_interval(duration)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.3)


## Cutscene curta de skill/despertar: letterbox, flash, FOV punch, onomatopeia,
## câmera lenta local (apenas offline; no online nunca altera o tempo global).
func cutscene(title: String, ono_key: String, color: Color, big: bool) -> void:
	var reduce: bool = bool(Game.settings.get("reduce_cutscenes", false))
	banner(title, color, 1.4 if big else 0.9)
	ono(ono_key, Vector2.ZERO, color.lerp(Color.WHITE, 0.4))
	if reduce:
		return
	_cut_token += 1
	var token: int = _cut_token
	flash(color, 0.4 if big else 0.2, 0.7 if big else 0.35)
	if rig != null:
		rig.call("punch_fov", -14.0 if big else -7.0, 0.35 if big else 0.2)
		rig.call("shake", 0.45 if big else 0.2)
	if big:
		letterbox(true)
		speedlines(true, color)
		if not online:
			Engine.time_scale = 0.3
		await get_tree().create_timer(0.55, true, false, true).timeout
		if token == _cut_token:
			Engine.time_scale = 1.0
		await get_tree().create_timer(0.7, true, false, true).timeout
		if token == _cut_token:
			letterbox(false)
			speedlines(false)
	else:
		speedlines(true, color)
		await get_tree().create_timer(0.3, true, false, true).timeout
		speedlines(false)


func clear_all() -> void:
	_cut_token += 1
	Engine.time_scale = 1.0
	letterbox(false)
	speedlines(false)
