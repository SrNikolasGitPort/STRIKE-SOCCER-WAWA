extends Node3D
## Campo de futebol 3D 100% procedural (sem assets externos):
## gramado listrado, linhas, traves, paredes invisíveis (arena fechada) e
## sensores de gol. Time 0 ataca o gol em +X; time 1 ataca o gol em -X.

signal goal_scored(scoring_team: int)

const GRASS_A: Color = Color(0.13, 0.46, 0.17)
const GRASS_B: Color = Color(0.11, 0.40, 0.15)
const LINE_COLOR: Color = Color(0.96, 0.96, 0.96)
const POST_COLOR: Color = Color(0.97, 0.97, 0.97)
const OUTSIDE_COLOR: Color = Color(0.07, 0.09, 0.16)
const NET_COLOR: Color = Color(0.9, 0.95, 1.0, 0.22)

var length: float
var width: float
var goal_w: float
var goal_h: float
var goal_d: float
var wall_h: float
var wall_t: float
var line_t: float
var post_t: float
var ball_radius: float


func _ready() -> void:
	length = Config.f("field.length")
	width = Config.f("field.width")
	goal_w = Config.f("field.goal_width")
	goal_h = Config.f("field.goal_height")
	goal_d = Config.f("field.goal_depth")
	wall_h = Config.f("field.wall_height")
	wall_t = Config.f("field.wall_thickness")
	line_t = Config.f("field.line_thickness")
	post_t = Config.f("field.post_thickness")
	ball_radius = Config.f("ball.radius")
	_build_ground()
	_build_markings()
	_build_goals()
	_build_walls()
	_build_goal_sensors()


# ---------------------------------------------------------------- materiais

func _mat(color: Color, rough: float = 1.0, emission: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


func _box(parent: Node, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _collider(pos: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	add_child(body)


# ------------------------------------------------------------------- campo

func _build_ground() -> void:
	var total_x: float = length + 2.0 * (goal_d + wall_t)
	var total_z: float = width + 2.0 * wall_t

	# Piso físico + visual do gramado.
	_collider(Vector3(0.0, -0.5, 0.0), Vector3(total_x, 1.0, total_z))
	_box(self, Vector3(0.0, -0.05, 0.0), Vector3(total_x, 0.1, total_z), _mat(GRASS_A))

	# Listras alternadas.
	var count: int = int(Config.f("field.stripe_count"))
	var stripe_len: float = length / float(count)
	for i: int in range(count):
		if i % 2 == 1:
			var x: float = -length / 2.0 + stripe_len * (float(i) + 0.5)
			_box(self, Vector3(x, 0.005, 0.0), Vector3(stripe_len, 0.012, width), _mat(GRASS_B))

	# Chão escuro ao redor do estádio.
	_box(self, Vector3(0.0, -0.3, 0.0), Vector3(total_x + 120.0, 0.1, total_z + 120.0), _mat(OUTSIDE_COLOR))


func _line(center: Vector3, size: Vector3) -> void:
	_box(self, center + Vector3(0.0, 0.016, 0.0), size, _mat(LINE_COLOR))


func _build_markings() -> void:
	var half_l: float = length / 2.0
	var half_w: float = width / 2.0
	# Bordas.
	_line(Vector3(0.0, 0.0, -half_w), Vector3(length, 0.012, line_t))
	_line(Vector3(0.0, 0.0, half_w), Vector3(length, 0.012, line_t))
	_line(Vector3(-half_l, 0.0, 0.0), Vector3(line_t, 0.012, width))
	_line(Vector3(half_l, 0.0, 0.0), Vector3(line_t, 0.012, width))
	# Linha do meio.
	_line(Vector3(0.0, 0.0, 0.0), Vector3(line_t, 0.012, width))

	# Círculo central (anel achatado).
	var radius: float = Config.f("field.center_circle_radius")
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = radius - line_t / 2.0
	torus.outer_radius = radius + line_t / 2.0
	torus.rings = 48
	torus.ring_segments = 4
	ring.mesh = torus
	ring.material_override = _mat(LINE_COLOR)
	ring.scale = Vector3(1.0, 0.05, 1.0)
	ring.position = Vector3(0.0, 0.02, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	# Grandes áreas.
	var pa_len: float = Config.f("field.penalty_area_length")
	var pa_w: float = Config.f("field.penalty_area_width")
	for side: float in [-1.0, 1.0]:
		var edge_x: float = side * half_l
		var inner_x: float = side * (half_l - pa_len)
		_line(Vector3(inner_x, 0.0, 0.0), Vector3(line_t, 0.012, pa_w))
		_line(Vector3((edge_x + inner_x) / 2.0, 0.0, -pa_w / 2.0), Vector3(pa_len, 0.012, line_t))
		_line(Vector3((edge_x + inner_x) / 2.0, 0.0, pa_w / 2.0), Vector3(pa_len, 0.012, line_t))


# -------------------------------------------------------------------- gols

func _build_goals() -> void:
	var half_l: float = length / 2.0
	var half_gw: float = goal_w / 2.0
	var post_mat: StandardMaterial3D = _mat(POST_COLOR, 0.4)
	var net_mat: StandardMaterial3D = _mat(NET_COLOR)
	for side: float in [-1.0, 1.0]:
		var front_x: float = side * half_l
		var back_x: float = side * (half_l + goal_d)
		# Traves frontais e travessão (com colisão para a bola bater).
		for z: float in [-half_gw, half_gw]:
			_box(self, Vector3(front_x, goal_h / 2.0, z), Vector3(post_t, goal_h, post_t), post_mat)
			_collider(Vector3(front_x, goal_h / 2.0, z), Vector3(post_t, goal_h, post_t))
			_box(self, Vector3(back_x, goal_h / 2.0, z), Vector3(post_t, goal_h, post_t), post_mat)
		_box(self, Vector3(front_x, goal_h, 0.0), Vector3(post_t, post_t, goal_w + post_t), post_mat)
		_collider(Vector3(front_x, goal_h - post_t / 2.0, 0.0), Vector3(post_t, post_t, goal_w + post_t))
		_box(self, Vector3(back_x, goal_h, 0.0), Vector3(post_t, post_t, goal_w + post_t), post_mat)
		for z: float in [-half_gw, half_gw]:
			_box(self, Vector3((front_x + back_x) / 2.0, goal_h, z), Vector3(goal_d, post_t, post_t), post_mat)
		# Rede translúcida (visual): fundo, laterais e teto.
		_box(self, Vector3(back_x, goal_h / 2.0, 0.0), Vector3(0.03, goal_h, goal_w), net_mat)
		for z: float in [-half_gw, half_gw]:
			_box(self, Vector3((front_x + back_x) / 2.0, goal_h / 2.0, z), Vector3(goal_d, goal_h, 0.03), net_mat)
		_box(self, Vector3((front_x + back_x) / 2.0, goal_h, 0.0), Vector3(goal_d, 0.03, goal_w), net_mat)


# ---------------------------------------------------------------- paredes

## Arena fechada: a bola nunca sai (configurável por modo no futuro).
func _build_walls() -> void:
	var half_l: float = length / 2.0
	var half_w: float = width / 2.0
	var total_x: float = length + 2.0 * (goal_d + wall_t)
	var total_z: float = width + 2.0 * wall_t
	# Laterais.
	for z: float in [-1.0, 1.0]:
		_collider(Vector3(0.0, wall_h / 2.0, z * (half_w + wall_t / 2.0)), Vector3(total_x, wall_h, wall_t))
	# Linhas de fundo (dos dois lados do gol) incluindo a lateral do gol.
	var seg_len: float = half_w - goal_w / 2.0
	var seg_depth: float = goal_d + wall_t
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var cx: float = x * (half_l + seg_depth / 2.0)
			var cz: float = z * (goal_w / 2.0 + seg_len / 2.0)
			_collider(Vector3(cx, wall_h / 2.0, cz), Vector3(seg_depth, wall_h, seg_len))
		# Fundo do gol e "tampa" acima do travessão.
		_collider(Vector3(x * (half_l + goal_d + wall_t / 2.0), wall_h / 2.0, 0.0), Vector3(wall_t, wall_h, goal_w))
		_collider(Vector3(x * (half_l + goal_d / 2.0), goal_h + (wall_h - goal_h) / 2.0, 0.0), Vector3(goal_d, wall_h - goal_h, goal_w))
	# Teto invisível.
	_collider(Vector3(0.0, wall_h + wall_t / 2.0, 0.0), Vector3(total_x, wall_t, total_z))


# ---------------------------------------------------------------- sensores

func _build_goal_sensors() -> void:
	var half_l: float = length / 2.0
	var depth: float = goal_d - 2.0 * ball_radius
	for side: float in [-1.0, 1.0]:
		var area: Area3D = Area3D.new()
		area.collision_layer = 0
		area.collision_mask = 4
		area.monitoring = true
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(depth, goal_h, goal_w)
		shape.shape = box
		area.add_child(shape)
		area.position = Vector3(side * (half_l + 2.0 * ball_radius + depth / 2.0), goal_h / 2.0, 0.0)
		# Bola em +X marca para o time 0; em -X marca para o time 1.
		var scoring_team: int = 0 if side > 0.0 else 1
		area.body_entered.connect(_on_goal_body_entered.bind(scoring_team))
		add_child(area)


func _on_goal_body_entered(body: Node3D, scoring_team: int) -> void:
	if body.is_in_group("ball"):
		goal_scored.emit(scoring_team)
