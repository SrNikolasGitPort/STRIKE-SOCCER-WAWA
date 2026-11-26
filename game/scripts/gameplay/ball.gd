extends RigidBody3D
## Bola de futebol: física responsiva (quique, atrito, arrasto, efeito/Magnus).
## No online (M5) esta simulação roda SOMENTE no servidor autoritativo.

var _radius: float
var _magnus_k: float
var _max_speed: float
var _trail: MeshInstance3D


func _ready() -> void:
	add_to_group("ball")
	_radius = Config.f("ball.radius")
	_magnus_k = Config.f("ball.magnus_k")
	_max_speed = Config.f("ball.max_speed")

	mass = Config.f("ball.mass")
	linear_damp = Config.f("ball.linear_damp")
	angular_damp = Config.f("ball.angular_damp")
	continuous_cd = true
	can_sleep = false
	collision_layer = 4
	collision_mask = 1
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.bounce = Config.f("ball.bounce")
	pm.friction = Config.f("ball.friction")
	physics_material_override = pm

	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = _radius
	shape.shape = sphere
	add_child(shape)

	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = _radius
	mesh.height = _radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	visual.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.97, 0.97, 0.97)
	mat.roughness = 0.55
	visual.material_override = mat
	add_child(visual)

	# Marcador de "gomos" escuros para a rotação ficar legível.
	for i: int in range(6):
		var patch: MeshInstance3D = MeshInstance3D.new()
		var pm_mesh: SphereMesh = SphereMesh.new()
		pm_mesh.radius = _radius * 0.3
		pm_mesh.height = _radius * 0.6
		pm_mesh.radial_segments = 8
		pm_mesh.rings = 4
		patch.mesh = pm_mesh
		var dark: StandardMaterial3D = StandardMaterial3D.new()
		dark.albedo_color = Color(0.1, 0.12, 0.2)
		patch.material_override = dark
		var dir: Vector3 = Vector3.ZERO
		match i:
			0: dir = Vector3.UP
			1: dir = Vector3.DOWN
			2: dir = Vector3.LEFT
			3: dir = Vector3.RIGHT
			4: dir = Vector3.FORWARD
			_: dir = Vector3.BACK
		patch.position = dir * _radius * 0.86
		add_child(patch)


func _physics_process(_delta: float) -> void:
	# Efeito (Magnus simplificado): só o giro vertical (curva lateral) gera força.
	var v: Vector3 = linear_velocity
	var spin_y: float = angular_velocity.y
	if v.length() > 1.0 and absf(spin_y) > 0.5:
		apply_central_force(Vector3(0.0, spin_y, 0.0).cross(v) * _magnus_k)
	if linear_velocity.length() > _max_speed:
		linear_velocity = linear_velocity.normalized() * _max_speed


## Chuta a bola. `direction` é normalizada; `spin_y` gera efeito lateral (curva).
func kick(direction: Vector3, speed: float, spin_y: float = 0.0) -> void:
	var dir: Vector3 = direction.normalized()
	linear_velocity = dir * speed
	# Giro visual de rolagem + giro vertical (efeito).
	angular_velocity = Vector3.UP.cross(dir) * (speed / _radius) * 0.35 + Vector3(0.0, spin_y, 0.0)


func reset_to(pos: Vector3) -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.IDENTITY, pos))
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
