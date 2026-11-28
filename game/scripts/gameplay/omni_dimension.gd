extends Node3D
## Dimensão Omnisférica da Metavisão: cúpula quadriculada (ou radial) que se abre ao redor do
## jogador, piso com o mesmo padrão, motivos flutuantes do personagem (quebra-cabeça, gelo, cobras,
## corvos, rosas com espinhos, círculos dourados...), faíscas e luz colorida.

const DOME_SHADER: String = "res://assets/shaders/omni_dome.gdshader"
const FLOOR_SHADER: String = "res://assets/shaders/omni_floor.gdshader"
const MOTIF_DIR: String = "res://assets/textures/vfx/omni_"

var follow: Node3D = null
var cfg: Dictionary = {}
var life: float = 6.0

var _t: float = 0.0
var _radius: float = 11.0
var _col_a: Color = Color.BLUE
var _col_b: Color = Color.CYAN
var _dome_mat: ShaderMaterial
var _floor_mat: ShaderMaterial
var _motifs: Array = []
var _light: OmniLight3D
var _radial: bool = false


func setup(target: Node3D, config: Dictionary, duration: float) -> void:
	follow = target
	cfg = config
	life = duration


func _make_mat(shader_path: String) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(shader_path)
	m.set_shader_parameter("col_a", _col_a)
	m.set_shader_parameter("col_b", _col_b)
	m.set_shader_parameter("cells", float(cfg.get("cells", 14)))
	m.set_shader_parameter("pattern", int(cfg.get("pattern", 0)))
	m.set_shader_parameter("open_amt", 0.0)
	m.set_shader_parameter("power", 1.0)
	return m


func _ready() -> void:
	_col_a = Color(String(cfg.get("a", "#1B2A6B")))
	_col_b = Color(String(cfg.get("b", "#7FB8FF")))
	_radius = float(cfg.get("radius", 11.0))
	_radial = int(cfg.get("pattern", 0)) == 1

	var dome: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = _radius
	sm.height = _radius * 2.0
	sm.radial_segments = 64
	sm.rings = 32
	dome.mesh = sm
	_dome_mat = _make_mat(DOME_SHADER)
	dome.material_override = _dome_mat
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)

	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(_radius * 2.0, _radius * 2.0)
	floor_mi.mesh = q
	floor_mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	floor_mi.position = Vector3(0.0, 0.07, 0.0)
	_floor_mat = _make_mat(FLOOR_SHADER)
	floor_mi.material_override = _floor_mat
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mi)

	_build_motifs()
	_build_sparks()

	_light = OmniLight3D.new()
	_light.light_color = _col_b
	_light.omni_range = _radius * 1.4
	_light.light_energy = 0.0
	_light.position = Vector3(0.0, 3.0, 0.0)
	add_child(_light)
	if follow != null:
		global_position = Vector3(follow.global_position.x, 0.0, follow.global_position.z)


func _build_motifs() -> void:
	var path: String = MOTIF_DIR + String(cfg.get("motif", "diamond")) + ".png"
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(String(cfg.get("motif", "x")))
	var count: int = 26
	for i: int in count:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var qm: QuadMesh = QuadMesh.new()
		var sz: float = rng.randf_range(1.1, 2.4)
		qm.size = Vector2(sz, sz)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_texture = tex
		mat.albedo_color = Color(_col_b.r, _col_b.g, _col_b.b, 0.0)
		mat.no_depth_test = false
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		qm.material = mat
		mi.mesh = qm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var ang: float = rng.randf() * TAU
		var rad: float = _radius * rng.randf_range(0.25, 0.92)
		var h: float = rng.randf_range(0.6, _radius * 0.8)
		if _radial:
			rad = _radius * (0.3 + 0.2 * float(i % 4))
			ang = TAU * float(i) / float(count) * 4.0
		_motifs.append({"node": mi, "mat": mat, "ang": ang, "rad": rad, "h": h, "spd": rng.randf_range(0.05, 0.22) * (1.0 if i % 2 == 0 else -1.0),
			"rise": rng.randf_range(0.15, 0.5), "ph": rng.randf() * TAU, "size": sz})


func _build_sparks() -> void:
	var cp: CPUParticles3D = CPUParticles3D.new()
	cp.amount = 70
	cp.lifetime = 2.2
	cp.preprocess = 1.0
	cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cp.emission_sphere_radius = _radius * 0.85
	cp.direction = Vector3.UP
	cp.spread = 20.0
	cp.gravity = Vector3(0.0, 0.8, 0.0)
	cp.initial_velocity_min = 0.3
	cp.initial_velocity_max = 1.2
	cp.scale_amount_min = 0.5
	cp.scale_amount_max = 1.4
	cp.color = _col_b
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(0.28, 0.28)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	var gp: String = "res://assets/textures/vfx/glow.png"
	if ResourceLoader.exists(gp):
		mat.albedo_texture = load(gp)
	qm.material = mat
	cp.mesh = qm
	cp.position = Vector3(0.0, _radius * 0.4, 0.0)
	add_child(cp)


func _process(delta: float) -> void:
	_t += delta
	if follow != null and is_instance_valid(follow):
		global_position = Vector3(follow.global_position.x, 0.0, follow.global_position.z)
	var open_k: float = clampf(_t / 0.7, 0.0, 1.0)
	open_k = 1.0 - pow(1.0 - open_k, 3.0)
	var close_k: float = clampf((life - _t) / 0.5, 0.0, 1.0)
	var open_amt: float = open_k * close_k
	var power: float = clampf(close_k * 1.2, 0.0, 1.0) * (0.92 + 0.08 * sin(_t * 5.0))
	_dome_mat.set_shader_parameter("open_amt", open_amt)
	_dome_mat.set_shader_parameter("power", power)
	_floor_mat.set_shader_parameter("open_amt", open_amt)
	_floor_mat.set_shader_parameter("power", power)
	_light.light_energy = 1.6 * power * open_k
	for m: Dictionary in _motifs:
		m["ang"] = float(m["ang"]) + float(m["spd"]) * delta
		var h: float = fmod(float(m["h"]) + _t * float(m["rise"]), _radius * 0.9)
		var r: float = float(m["rad"])
		var node: Node3D = m["node"]
		node.position = Vector3(cos(float(m["ang"])) * r, 0.5 + h, sin(float(m["ang"])) * r)
		var fade: float = sin(clampf(h / (_radius * 0.9), 0.0, 1.0) * PI)
		var mat: StandardMaterial3D = m["mat"]
		mat.albedo_color.a = fade * 0.85 * open_amt * (0.75 + 0.25 * sin(_t * 3.0 + float(m["ph"])))
	if _t >= life:
		queue_free()
