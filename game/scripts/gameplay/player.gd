extends CharacterBody3D
## Jogador controlável: corrida, sprint com stamina, condução de bola,
## chute com barra de força, passe, passe alto e efeito (curva).
## Movimento em eixos do mundo: "frente" = +X (direção do gol adversário),
## "direita" = +Z (a câmera olha para +X).

signal ball_kicked(kind: String, power: float)

var ball: RigidBody3D = null
var attack_goal: Vector3 = Vector3.ZERO
var controls_enabled: bool = true
var team: int = 0

var stamina: float = 100.0
var charge: float = 0.0
var charging: bool = false

var _stats: Dictionary = {}
var _speed_mult: float = 1.0
var _power_mult: float = 1.0
var _facing: Vector3 = Vector3.RIGHT
var _sprinting: bool = false
var _regen_wait: float = 0.0
var _kick_cd: float = 0.0
var _dribble_cd: float = 0.0
var _kick_anim: float = 0.0
var _anim_time: float = 0.0
var _model: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _gravity: float = 9.8
const KICK_ANIM_LEN: float = 0.18


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	stamina = Config.f("player.stamina_max")

	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = Config.f("player.body_radius") * 0.7
	capsule.height = Config.f("player.body_height")
	shape.shape = capsule
	add_child(shape)


## Aplica dados do personagem (JSON em data/characters) ao visual e aos stats.
func setup(character: Dictionary, team_index: int) -> void:
	team = team_index
	_stats = character.get("stats", {})
	var factor_speed: float = Config.f("player.speed_stat_factor")
	var factor_power: float = Config.f("kick.power_stat_factor")
	_speed_mult = 1.0 + (float(_stats.get("velocidade", 50)) - 50.0) / 50.0 * factor_speed
	_power_mult = 1.0 + (float(_stats.get("chute", 50)) - 50.0) / 50.0 * factor_power
	_build_model(character.get("visual", {}))


func stamina_ratio() -> float:
	return stamina / Config.f("player.stamina_max")


func _mat(color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	return m


func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scale_v: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	mi.scale = scale_v
	parent.add_child(mi)
	return mi


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var c: CapsuleMesh = CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = 12
	c.rings = 4
	return c


func _sphere(radius: float) -> SphereMesh:
	var s: SphereMesh = SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p: Node3D = Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p


## Modelo placeholder estilizado, colorido conforme a ficha do personagem.
func _build_model(visual: Dictionary) -> void:
	if _model != null:
		_model.queue_free()
	var uniform: Color = Color(String(visual.get("uniform_color", "#2F80ED")))
	var shorts: Color = Color(String(visual.get("shorts_color", "#0B1226")))
	var skin: Color = Color(String(visual.get("skin_color", "#F1C9A5")))
	var hair: Color = Color(String(visual.get("hair_color", "#14161F")))
	var aura: Color = Color(String(visual.get("aura_color", "#5CC8FF")))

	_model = Node3D.new()
	_model.position = Vector3(0.0, -Config.f("player.body_height") / 2.0, 0.0)
	add_child(_model)

	_part(_model, _capsule(0.25, 0.68), uniform, Vector3(0.0, 1.17, 0.0), Vector3(1.0, 1.0, 0.72))
	_part(_model, BoxMesh.new(), shorts, Vector3(0.0, 0.86, 0.0), Vector3(0.5, 0.26, 0.3))
	_part(_model, _sphere(0.17), skin, Vector3(0.0, 1.62, 0.0))
	_part(_model, _sphere(0.185), hair, Vector3(0.0, 1.67, 0.03), Vector3(1.0, 0.75, 1.0))

	_leg_l = _pivot(_model, Vector3(-0.13, 0.85, 0.0))
	_leg_r = _pivot(_model, Vector3(0.13, 0.85, 0.0))
	for leg: Node3D in [_leg_l, _leg_r]:
		_part(leg, _capsule(0.1, 0.85), skin, Vector3(0.0, -0.425, 0.0))
		_part(leg, BoxMesh.new(), Color(0.08, 0.08, 0.1), Vector3(0.0, -0.82, -0.05), Vector3(0.16, 0.1, 0.3))

	_arm_l = _pivot(_model, Vector3(-0.33, 1.4, 0.0))
	_arm_r = _pivot(_model, Vector3(0.33, 1.4, 0.0))
	for arm: Node3D in [_arm_l, _arm_r]:
		_part(arm, _capsule(0.07, 0.6), uniform, Vector3(0.0, -0.28, 0.0))

	# Anel no chão na cor da aura (identifica o jogador controlado).
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.72
	torus.rings = 24
	torus.ring_segments = 4
	ring.mesh = torus
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = aura
	ring_mat.emission_enabled = true
	ring_mat.emission = aura
	ring_mat.emission_energy_multiplier = 1.6
	ring.material_override = ring_mat
	ring.scale = Vector3(1.0, 0.05, 1.0)
	ring.position = Vector3(0.0, 0.03, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(ring)


func _physics_process(delta: float) -> void:
	_kick_cd = maxf(_kick_cd - delta, 0.0)
	_dribble_cd = maxf(_dribble_cd - delta, 0.0)
	_kick_anim = maxf(_kick_anim - delta, 0.0)

	var in_vec: Vector2 = Vector2.ZERO
	if controls_enabled:
		in_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish: Vector3 = Vector3(-in_vec.y, 0.0, in_vec.x)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var moving: bool = wish.length() > 0.1

	_update_stamina(delta, moving)
	_update_movement(delta, wish, moving)
	_update_kicking(delta, wish)
	_update_ball_interaction(delta, wish, moving)
	_animate(delta)


func _update_stamina(delta: float, moving: bool) -> void:
	var s_max: float = Config.f("player.stamina_max")
	var want_sprint: bool = controls_enabled and moving and Input.is_action_pressed("sprint")
	if _sprinting:
		if not want_sprint or stamina <= 0.0:
			_sprinting = false
	elif want_sprint and stamina >= Config.f("player.stamina_min_to_sprint"):
		_sprinting = true
	if _sprinting:
		stamina = maxf(stamina - Config.f("player.stamina_drain") * delta, 0.0)
		_regen_wait = Config.f("player.stamina_regen_delay")
	else:
		_regen_wait = maxf(_regen_wait - delta, 0.0)
		if _regen_wait <= 0.0:
			stamina = minf(stamina + Config.f("player.stamina_regen") * delta, s_max)


func _update_movement(delta: float, wish: Vector3, moving: bool) -> void:
	var top_speed: float = Config.f("player.sprint_speed") if _sprinting else Config.f("player.run_speed")
	top_speed *= _speed_mult
	var target: Vector3 = wish * top_speed
	var rate: float = Config.f("player.accel") if moving else Config.f("player.decel")
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	move_and_slide()

	if moving:
		_facing = _facing.slerp(wish.normalized(), clampf(Config.f("player.turn_speed") * delta, 0.0, 1.0))
		if _facing.length() < 0.01:
			_facing = wish.normalized()
		_facing = _facing.normalized()
	if _model != null:
		_model.rotation.y = atan2(-_facing.x, -_facing.z)


# ------------------------------------------------------------------ chutes

func _aim_direction() -> Vector3:
	var aim: Vector3 = Vector3(_facing.x, 0.0, _facing.z).normalized()
	var to_goal: Vector3 = attack_goal - global_position
	to_goal.y = 0.0
	if to_goal.length() > 0.5:
		to_goal = to_goal.normalized()
		var max_angle: float = deg_to_rad(Config.f("kick.aim_assist_angle_deg"))
		if aim.angle_to(to_goal) < max_angle:
			aim = aim.slerp(to_goal, Config.f("kick.aim_assist_strength")).normalized()
	return aim


func _ball_in_range() -> bool:
	if ball == null:
		return false
	var d: Vector3 = ball.global_position - global_position
	d.y = 0.0
	return d.length() <= Config.f("kick.range") and ball.global_position.y < 1.6


func _update_kicking(delta: float, wish: Vector3) -> void:
	if not controls_enabled:
		charging = false
		charge = 0.0
		return

	# Chute: segura para carregar a força, solta para chutar.
	if Input.is_action_pressed("shoot"):
		charging = true
		charge = minf(charge + delta / Config.f("kick.charge_time_s"), 1.0)
	elif charging:
		if _ball_in_range() and _kick_cd <= 0.0:
			var power: float = lerpf(Config.f("kick.min_power"), Config.f("kick.max_power"), charge) * _power_mult
			var aim: Vector3 = _aim_direction()
			var curve: float = 0.0
			if wish.length() > 0.3:
				curve = clampf(aim.cross(wish.normalized()).y, -1.0, 1.0) * Config.f("kick.curve_spin")
			_do_kick(Vector3(aim.x, Config.f("kick.shot_loft"), aim.z), power, curve, "shot")
		charging = false
		charge = 0.0

	if Input.is_action_just_pressed("pass") and _ball_in_range() and _kick_cd <= 0.0:
		var aim_p: Vector3 = _aim_direction()
		_do_kick(Vector3(aim_p.x, Config.f("kick.pass_loft"), aim_p.z), Config.f("kick.pass_speed"), 0.0, "pass")
	if Input.is_action_just_pressed("lob") and _ball_in_range() and _kick_cd <= 0.0:
		var aim_l: Vector3 = _aim_direction()
		_do_kick(Vector3(aim_l.x, Config.f("kick.lob_loft"), aim_l.z), Config.f("kick.lob_speed"), 0.0, "lob")


func _do_kick(direction: Vector3, speed: float, spin_y: float, kind: String) -> void:
	if ball == null:
		return
	ball.call("kick", direction, speed, spin_y)
	_kick_cd = Config.f("kick.cooldown_s")
	_dribble_cd = Config.f("player.dribble_cooldown_s")
	_kick_anim = KICK_ANIM_LEN
	ball_kicked.emit(kind, speed)


# ------------------------------------------------ condução e contato

func _update_ball_interaction(_delta: float, wish: Vector3, moving: bool) -> void:
	if ball == null or not controls_enabled:
		return
	var to_ball: Vector3 = ball.global_position - global_position
	to_ball.y = 0.0
	var dist: float = to_ball.length()
	var ball_radius: float = Config.f("ball.radius")
	var body_r: float = Config.f("player.body_radius")
	var hv: Vector3 = Vector3(velocity.x, 0.0, velocity.z)

	# Contato corporal: a bola quica no corpo do jogador.
	if dist < body_r + ball_radius and dist > 0.001 and ball.global_position.y < Config.f("player.body_height"):
		var normal: Vector3 = to_ball / dist
		var v: Vector3 = ball.linear_velocity
		var vn: float = v.dot(normal)
		if vn < 0.0:
			v -= (1.0 + Config.f("player.bump_restitution")) * vn * normal
		v += hv * Config.f("player.bump_player_speed_share") * 0.2
		ball.linear_velocity = v

	if _dribble_cd > 0.0 or dist > Config.f("player.dribble_range") or ball.global_position.y > 1.0:
		return

	var blend: float = Config.f("player.dribble_blend")
	var bv: Vector3 = ball.linear_velocity
	if moving:
		# Condução: puxa a bola para um ponto à frente dos pés.
		var target: Vector3 = global_position + _facing * Config.f("player.dribble_front_offset")
		var pull: Vector3 = (target - ball.global_position)
		pull.y = 0.0
		var desired: Vector3 = hv + pull * Config.f("player.dribble_pull")
		var flat: Vector3 = Vector3(bv.x, 0.0, bv.z).lerp(desired, blend)
		ball.linear_velocity = Vector3(flat.x, bv.y, flat.z)
	elif Vector3(bv.x, 0.0, bv.z).length() < Config.f("kick.pass_speed"):
		# Domínio (trapping): amortece a bola quando o jogador está parado.
		var damp: Vector3 = Vector3(bv.x, 0.0, bv.z).lerp(Vector3.ZERO, blend)
		ball.linear_velocity = Vector3(damp.x, bv.y, damp.z)


# --------------------------------------------------------------- animação

func _animate(delta: float) -> void:
	if _leg_l == null:
		return
	var hspeed: float = Vector3(velocity.x, 0.0, velocity.z).length()
	_anim_time += hspeed * delta * 1.1
	var amount: float = minf(hspeed / 8.0, 1.0) * 0.9
	var swing: float = sin(_anim_time) * amount
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_arm_l.rotation.x = -swing * 0.8
	_arm_r.rotation.x = swing * 0.8
	if _kick_anim > 0.0:
		_leg_r.rotation.x = 1.3 * (_kick_anim / KICK_ANIM_LEN)
	elif charging:
		_leg_r.rotation.x = -0.7 * charge
