extends Node3D
## Ball Predict: mostra a trajetória prevista da bola.
## Básico: enquanto o jogador carrega o chute (arco até o 1º quique / gol).
## Avançado (Metavisão): trajetória mais longa com quique, da bola em movimento também,
## marcador de queda e marcador de entrada no gol, na cor do personagem.

var arena: Node = null

var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
var _land: MeshInstance3D
var _gate: MeshInstance3D


func _ready() -> void:
	var n: int = int(Config.f("predict.dots"))
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(0.3, 0.3)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	var gp: String = "res://assets/textures/vfx/glow.png"
	if ResourceLoader.exists(gp):
		mat.albedo_texture = load(gp)
	qm.material = mat
	_mm.mesh = qm
	_mm.instance_count = n
	_mm.visible_instance_count = 0
	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = _mm
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mmi)
	_land = _marker("res://assets/textures/vfx/ring.png", 1.6)
	_gate = _marker("res://assets/textures/vfx/star.png", 1.4)


func _marker(path: String, size: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	q.material = m
	mi.mesh = q
	mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Simula a bola com gravidade, arrasto, efeito (Magnus) e quique. Retorna os pontos.
func simulate(pos: Vector3, vel: Vector3, spin_y: float, total_s: float, step: float, bounces: int) -> Dictionary:
	var pts: Array = []
	var land: Variant = null
	var gate: Variant = null
	var r: float = Config.f("ball.radius")
	var g: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var damp: float = Config.f("ball.linear_damp")
	var k: float = Config.f("ball.magnus_k") / Config.f("ball.mass")
	var bounce: float = Config.f("ball.bounce")
	var half_l: float = Config.f("field.length") / 2.0
	var half_w: float = Config.f("field.goal_width") / 2.0
	var t: float = 0.0
	var nb: int = 0
	var p: Vector3 = pos
	var v: Vector3 = vel
	var spin: float = spin_y
	while t < total_s:
		var a: Vector3 = Vector3(0.0, -g, 0.0)
		if v.length() > 1.0 and absf(spin) > 0.5:
			a += Vector3(0.0, spin, 0.0).cross(v) * k
		v += a * step
		v *= maxf(1.0 - damp * step, 0.0)
		spin *= maxf(1.0 - Config.f("ball.angular_damp") * step, 0.0)
		p += v * step
		if p.y <= r and v.y < 0.0:
			p.y = r
			if land == null:
				land = p
			v.y = -v.y * bounce
			v.x *= 0.92
			v.z *= 0.92
			nb += 1
			if nb > bounces:
				pts.append(p)
				break
		if gate == null and absf(p.x) >= half_l and absf(p.z) < half_w and p.y < Config.f("field.goal_height"):
			gate = p
			pts.append(p)
			break
		pts.append(p)
		t += step
	return {"pts": pts, "land": land, "gate": gate}


func _process(_delta: float) -> void:
	_mm.visible_instance_count = 0
	_land.visible = false
	_gate.visible = false
	if arena == null:
		return
	var h: Node = arena.get("human")
	var ball: RigidBody3D = arena.get("ball")
	if h == null or ball == null or int(arena.get("state")) != 0 or bool(h.get("puppet")):
		return
	var advanced: bool = float(h.get("vision_t")) > 0.0
	var col: Color = h.call("_aura_color")
	var step: float = Config.f("predict.step_s")
	var total: float = Config.f("predict.advanced_s") if advanced else Config.f("predict.basic_s")
	var sim: Dictionary = {}
	var shooting: bool = bool(h.get("charging")) and bool(h.call("ball_in_range"))
	if shooting:
		var aim: Vector3 = h.call("aim_direction")
		var wish: Vector3 = h.get("in_wish")
		var curve: float = 0.0
		if wish.length() > 0.3:
			curve = clampf(aim.cross(wish.normalized()).y, -1.0, 1.0) * Config.f("kick.curve_spin")
		var dir: Vector3 = Vector3(aim.x, float(h.call("shot_loft")), aim.z).normalized()
		var speed: float = float(h.call("shot_power", maxf(float(h.get("charge")), 0.1)))
		sim = simulate(ball.global_position, dir * speed, curve, total, step, 2 if advanced else 1)
	elif advanced and ball.linear_velocity.length() > 2.0:
		sim = simulate(ball.global_position, ball.linear_velocity, ball.angular_velocity.y, total, step, 2)
		col = col.lerp(Color.WHITE, 0.35)
	if sim.is_empty():
		return
	var pts: Array = sim["pts"]
	var n: int = mini(pts.size(), _mm.instance_count)
	var stride: int = maxi(int(ceil(float(pts.size()) / float(_mm.instance_count))), 1)
	var idx: int = 0
	var i: int = 0
	while i < pts.size() and idx < _mm.instance_count:
		var fade: float = 1.0 - float(i) / float(maxi(pts.size(), 1)) * 0.75
		_mm.set_instance_transform(idx, Transform3D(Basis.IDENTITY, pts[i] as Vector3))
		_mm.set_instance_color(idx, Color(col.r, col.g, col.b, fade * (0.95 if advanced else 0.7)))
		idx += 1
		i += stride
	_mm.visible_instance_count = idx
	if n > 0 and sim["land"] != null:
		var lp: Vector3 = sim["land"]
		_land.global_position = Vector3(lp.x, 0.09, lp.z)
		(_land.mesh as QuadMesh).material.set("albedo_color", Color(col.r, col.g, col.b, 0.9))
		_land.visible = true
	if advanced and sim["gate"] != null:
		var gp: Vector3 = sim["gate"]
		_gate.rotation = Vector3(0.0, PI * 0.5, 0.0)
		_gate.global_position = gp
		_gate.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		(_gate.mesh as QuadMesh).material.set("albedo_color", Color(1.0, 0.95, 0.5, 0.95))
		_gate.visible = true
