extends CharacterBody3D
## Jogador (humano, bot ou fantoche de rede): corrida, sprint com stamina, condução,
## chute com barra de força, passe, passe alto, 3 skills + 3 skills de Despertar,
## Flow, desarme e modelo texturizado (uniforme/rosto em PNG + cabelo por primitivas).
## Eixos: o time 0 ataca +X e o time 1 ataca -X.

signal ball_kicked(kind: String, power: float)
signal skill_used(player: Node, skill_id: String)
signal stole_ball(player: Node)

const SkillsScript = preload("res://scripts/gameplay/skills.gd")
const TEX: String = "res://assets/textures/"

var ball: RigidBody3D = null
var arena: Node = null                  # Match (zonas, jogadores, FX)
var attack_goal: Vector3 = Vector3.ZERO
var own_goal: Vector3 = Vector3.ZERO
var controls_enabled: bool = true
var is_human: bool = false
var puppet: bool = false                # fantoche de rede (cliente): só interpola
var net_pos: Vector3 = Vector3.ZERO
var net_yaw: float = 0.0
var team: int = 0
var side: float = 1.0
var index: int = 0
var role: String = "attacker"
var char_id: String = ""
var data: Dictionary = {}
var display_name: String = ""

# entradas (preenchidas pelo humano, bot ou rede)
var in_wish: Vector3 = Vector3.ZERO
var in_sprint: bool = false
var in_shoot_held: bool = false
var in_pass: bool = false
var in_aim: Vector3 = Vector3.ZERO
var in_dribble: bool = false
var in_awaken: bool = false
var in_tackle: bool = false
var _dodge_cd: float = 0.0
var _tackle_t: float = 0.0
var in_jump: bool = false
var in_elev: float = 0.0                # 0..1: elevação do chute (mira para cima)
var aim_lock: bool = false              # trava de mira (shift lock): corpo sempre olha para a mira
var in_skill: Array[bool] = [false, false, false, false, false, false]
var cam_side: float = 1.0

var stamina: float = 100.0
var charge: float = 0.0
var charging: bool = false
var flow: float = 0.0
var awakened: bool = false
var awake_left: float = 0.0
var cooldowns: Dictionary = {}
var skill_ids: Array = []               # 3 normais
var awake_ids: Array = []               # até 3 de Despertar
var facing: Vector3 = Vector3.RIGHT

# estados temporários usados pelas skills
var buffs: Dictionary = {}              # nome -> {v: float, t: float}
var stun_t: float = 0.0
var immune_t: float = 0.0
var shield_t: float = 0.0
var block_t: float = 0.0
var block_r: float = 0.0
var vision_t: float = 0.0
var vision_assist: float = 0.0
var intercept_r: float = 0.0
var silence_t: float = 0.0
var dash_t: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO
var dash_speed: float = 0.0
var dash_shot: Dictionary = {}
var power_scale_once: float = 1.0
var last_skill: String = ""
var fall_t: float = 0.0                 # caído no chão (knockdown)
var slide_t: float = 0.0                # carrinho em andamento
var slide_hit: bool = false
var recover_t: float = 0.0              # recuperação após carrinho errado
var dsk: Dictionary = {}                # drible ativo (zigzag, elástico, roleta...)
var _step_phase: float = 0.0
var _pose_t: float = 0.0

var _stats: Dictionary = {}
var _speed_mult: float = 1.0
var _power_mult: float = 1.0
var _sprinting: bool = false
var _regen_wait: float = 0.0
var _kick_cd: float = 0.0
var _dribble_cd: float = 0.0
var _kick_anim: float = 0.0
var _anim_time: float = 0.0
var _tackle_cd: float = 0.0
var _gcd: float = 0.0
var _model: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _aura_node: Node3D
var _gravity: float = 9.8
var _prev_shoot: bool = false
var _prev_pass: bool = false
var _trail_t: float = 0.0
const KICK_ANIM_LEN: float = 0.18


func _ready() -> void:
	add_to_group("players")
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


## Aplica dados do personagem (JSON) à lógica e ao visual.
func setup(character: Dictionary, team_index: int, human: bool = false) -> void:
	data = character
	char_id = String(character.get("id", ""))
	display_name = String(character.get("name", char_id))
	team = team_index
	side = 1.0 if team == 0 else -1.0
	is_human = human
	facing = Vector3(side, 0.0, 0.0)
	_stats = character.get("stats", {})
	var factor_speed: float = Config.f("player.speed_stat_factor")
	var factor_power: float = Config.f("kick.power_stat_factor")
	_speed_mult = 1.0 + (float(_stats.get("velocidade", 50)) - 50.0) / 50.0 * factor_speed
	_power_mult = 1.0 + (float(_stats.get("chute", 50)) - 50.0) / 50.0 * factor_power
	skill_ids = character.get("skills", [])
	awake_ids = Game.awakening_skills(char_id) if human else character.get("awakening", [])
	_build_model(character.get("visual", {}))


func stamina_ratio() -> float:
	return stamina / Config.f("player.stamina_max")


func stat(key: String) -> float:
	return float(_stats.get(key, 50))


# ------------------------------------------------------------- buffs
func add_buff(buff_name: String, value: float, duration: float) -> void:
	buffs[buff_name] = {"v": value, "t": duration}


func buff(buff_name: String, default_value: float = 1.0) -> float:
	if buffs.has(buff_name):
		return float((buffs[buff_name] as Dictionary)["v"])
	return default_value


func stun(duration: float) -> void:
	if immune_t > 0.0 or shield_t > 0.0:
		return
	stun_t = maxf(stun_t, duration)


## Barra de Fluxo = barra de Despertar: enche jogando; cheia, o jogador ativa o Despertar.
func add_flow(amount: float) -> void:
	if awakened:
		return
	var was_full: bool = flow >= Config.f("flow.max")
	flow = minf(flow + amount, Config.f("flow.max"))
	if flow >= Config.f("flow.max") and not was_full and arena != null and arena.has_method("on_flow_full"):
		arena.call("on_flow_full", self)


func awaken_ready() -> bool:
	return not awakened and flow >= Config.f("flow.max") and not awake_ids.is_empty()


func try_awaken() -> bool:
	if not awaken_ready() or stun_t > 0.0 or arena == null:
		return false
	flow = 0.0
	arena.call("start_awakening", self)
	return true


func start_dash(dir: Vector3, speed_mult: float, duration: float) -> void:
	dash_dir = Vector3(dir.x, 0.0, dir.z).normalized()
	if dash_dir.length() < 0.1:
		dash_dir = facing
	dash_speed = Config.f("skills.dash_base_speed") * speed_mult * _speed_mult
	dash_t = duration


func awaken(duration: float) -> void:
	awakened = true
	awake_left = duration
	for sid: Variant in awake_ids:
		cooldowns[String(sid)] = 0.0
	if arena != null:
		var fx: Node = arena.get("fx")
		if fx != null:
			_aura_node = fx.call("attach_aura", self, _aura_color())


## Pose de despertar/cutscene: o modelo levita, inclina o peito para trás e gira.
func pose(duration: float) -> void:
	if _model == null:
		return
	var base_y: float = _model.position.y
	_pose_t = duration
	var tw: Tween = _model.create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_model, "position:y", base_y + 0.35, duration * 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(_model, "rotation:x", 0.35, duration * 0.4).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(duration * 0.3)
	tw.chain().tween_property(_model, "position:y", base_y, duration * 0.3).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_model, "rotation:x", 0.0, duration * 0.3)


func end_awakening() -> void:
	awakened = false
	awake_left = 0.0
	if _aura_node != null:
		_aura_node.queue_free()
		_aura_node = null


func _aura_color() -> Color:
	return Color(String((data.get("visual", {}) as Dictionary).get("aura", "#5CC8FF")))


func cooldown_left(slot: int) -> float:
	var ids: Array = skill_ids if slot < 3 else awake_ids
	var i: int = slot if slot < 3 else slot - 3
	if i >= ids.size():
		return -1.0
	return float(cooldowns.get(String(ids[i]), 0.0))


func skill_at(slot: int) -> String:
	var ids: Array = skill_ids if slot < 3 else awake_ids
	var i: int = slot if slot < 3 else slot - 3
	if i >= ids.size():
		return ""
	return String(ids[i])


func try_skill(slot: int) -> bool:
	if stun_t > 0.0 or silence_t > 0.0 or _gcd > 0.0:
		return false
	if slot >= 3 and not awakened:
		return false
	var sid: String = skill_at(slot)
	if sid == "" or float(cooldowns.get(sid, 0.0)) > 0.0:
		return false
	var sk: Dictionary = Game.skill(sid)
	if sk.is_empty():
		return false
	var ok: bool = SkillsScript.execute(self, sk, arena)
	if ok:
		var cd: float = float(sk.get("cooldown", 8.0))
		if awakened:
			cd *= Config.f("awakening.cooldown_mult")
		cooldowns[sid] = cd
		_gcd = Config.f("skills.global_cooldown_s")
		add_flow(Config.f("flow.per_skill"))
		skill_used.emit(self, sid)
	else:
		_gcd = 0.2
		if is_human and arena != null:
			var hud: Node = arena.get("hud")
			if hud != null:
				hud.call("toast", Game.t("Chegue perto da bola para usar essa skill", "Get close to the ball to use this skill"), Color(1.0, 0.7, 0.4))
	return ok


# --------------------------------------------------------------- modelo
func _mat(color: Color, tex_path: String = "") -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if tex_path != "" and ResourceLoader.exists(tex_path):
		m.albedo_texture = load(tex_path)
		m.albedo_color = Color.WHITE
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


func _cone(radius: float, height: float) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 8
	return c


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p: Node3D = Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p


func _build_hair(head: Node3D, style: String, hair: Color, accent: Color, has_accent: bool) -> void:
	if style == "bald":
		return
	var cap: MeshInstance3D = _part(head, _sphere(0.185), hair, Vector3(0.0, 0.06, 0.03), Vector3(1.0, 0.72, 1.0))
	cap.position.y = 0.05
	match style:
		"spiky", "wild":
			var n: int = 7 if style == "wild" else 5
			var h: float = 0.3 if style == "wild" else 0.22
			for i: int in range(n):
				var a: float = TAU * float(i) / float(n)
				var cone: MeshInstance3D = _part(head, _cone(0.07, h), accent if (has_accent and i % 2 == 0) else hair,
					Vector3(cos(a) * 0.1, 0.2, sin(a) * 0.1))
				cone.rotation = Vector3(sin(a) * 0.7, 0.0, -cos(a) * 0.7)
		"bob":
			_part(head, _capsule(0.2, 0.34), hair, Vector3(0.0, -0.03, 0.06), Vector3(1.0, 1.0, 0.9))
		"ponytail":
			var tail: MeshInstance3D = _part(head, _capsule(0.06, 0.4), hair, Vector3(0.0, 0.0, 0.22))
			tail.rotation = Vector3(0.9, 0.0, 0.0)
		"pompadour":
			var front: MeshInstance3D = _part(head, BoxMesh.new(), hair, Vector3(0.0, 0.2, -0.12), Vector3(0.3, 0.14, 0.3))
			front.rotation = Vector3(-0.4, 0.0, 0.0)
		"long":
			_part(head, _capsule(0.19, 0.62), hair, Vector3(0.0, -0.14, 0.1), Vector3(1.0, 1.0, 0.7))
	if has_accent and style in ["short", "bob", "long", "pompadour", "ponytail"]:
		_part(head, _sphere(0.08), accent, Vector3(0.0, 0.17, -0.07), Vector3(1.4, 0.5, 1.0))


func _build_model(visual: Dictionary) -> void:
	if _model != null:
		_model.queue_free()
	var kit: Dictionary = visual.get("kit", {})
	var main: Color = Color(String(kit.get("main", "#2F80ED")))
	var shorts: Color = Color(String(kit.get("shorts", "#0B1226")))
	var skin: Color = Color(String(visual.get("skin", "#F1C9A5")))
	var hair: Color = Color(String(visual.get("hair_color", "#14161F")))
	var accent_s: String = String(visual.get("hair_accent", ""))
	var is_goat: bool = char_id.ends_with("_goat")

	_model = Node3D.new()
	_model.position = Vector3(0.0, -Config.f("player.body_height") / 2.0, 0.0)
	if is_goat:
		_model.scale = Vector3(1.12, 1.12, 1.12)
	add_child(_model)

	var kit_path: String = TEX + "kits/kit_" + String(kit.get("id", "bluelock")) + ".png"
	var torso: MeshInstance3D = _part(_model, _capsule(0.25, 0.68), main, Vector3(0.0, 1.17, 0.0), Vector3(1.0, 1.0, 0.72))
	torso.material_override = _mat(main, kit_path)
	_part(_model, BoxMesh.new(), shorts, Vector3(0.0, 0.86, 0.0), Vector3(0.5, 0.26, 0.3))

	var head: Node3D = _pivot(_model, Vector3(0.0, 1.64, 0.0))
	_part(head, _sphere(0.17), skin, Vector3.ZERO)
	_build_hair(head, String(visual.get("hair", "short")), hair, Color(accent_s) if accent_s != "" else hair, accent_s != "")
	# Rosto em PNG (olhos/boca) numa placa à frente da cabeça (o modelo olha para -Z).
	var face_path: String = TEX + "faces/face_" + char_id + ".png"
	if ResourceLoader.exists(face_path):
		var face: MeshInstance3D = MeshInstance3D.new()
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(0.34, 0.17)
		face.mesh = q
		var fm: StandardMaterial3D = StandardMaterial3D.new()
		fm.albedo_texture = load(face_path)
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		face.material_override = fm
		face.position = Vector3(0.0, -0.01, -0.166)
		face.rotation = Vector3(0.0, PI, 0.0)
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.add_child(face)
	if is_goat:
		for sx: float in [-1.0, 1.0]:
			var horn: MeshInstance3D = _part(head, _cone(0.05, 0.26), Color(0.95, 0.85, 0.5), Vector3(sx * 0.13, 0.22, 0.0))
			horn.rotation = Vector3(0.0, 0.0, -sx * 0.5)
		_part(head, _cone(0.05, 0.16), Color(0.9, 0.9, 0.9), Vector3(0.0, -0.2, -0.12)).rotation = Vector3(PI, 0.0, 0.0)

	_leg_l = _pivot(_model, Vector3(-0.13, 0.85, 0.0))
	_leg_r = _pivot(_model, Vector3(0.13, 0.85, 0.0))
	for leg: Node3D in [_leg_l, _leg_r]:
		_part(leg, _capsule(0.1, 0.85), skin, Vector3(0.0, -0.425, 0.0))
		_part(leg, _capsule(0.105, 0.5), main, Vector3(0.0, -0.58, 0.0))
		_part(leg, BoxMesh.new(), Color(0.08, 0.08, 0.1), Vector3(0.0, -0.82, -0.05), Vector3(0.16, 0.1, 0.3))
	_arm_l = _pivot(_model, Vector3(-0.33, 1.4, 0.0))
	_arm_r = _pivot(_model, Vector3(0.33, 1.4, 0.0))
	for arm: Node3D in [_arm_l, _arm_r]:
		_part(arm, _capsule(0.07, 0.6), main, Vector3(0.0, -0.28, 0.0))

	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.72
	torus.rings = 24
	torus.ring_segments = 4
	ring.mesh = torus
	var team_col: Color = Color(0.3, 0.7, 1.0) if team == 0 else Color(1.0, 0.35, 0.35)
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = team_col
	ring_mat.emission_enabled = true
	ring_mat.emission = team_col
	ring_mat.emission_energy_multiplier = 1.6
	ring.material_override = ring_mat
	ring.scale = Vector3(1.0, 0.05, 1.0)
	ring.position = Vector3(0.0, 0.03, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(ring)

	var label: Label3D = Label3D.new()
	label.text = ("▼ " if is_human else "") + display_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.006
	label.font_size = 40
	label.outline_size = 12
	label.modulate = Color.WHITE if is_human else team_col.lerp(Color.WHITE, 0.4)
	label.position = Vector3(0.0, 2.55, 0.0)
	add_child(label)


# -------------------------------------------------------------- entrada
func _read_human_input() -> void:
	var in_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var rig: Node = arena.get("rig") if arena != null else null
	if rig != null:
		in_wish = rig.call("world_wish", in_vec)
		in_aim = rig.call("forward")
	else:
		in_wish = Vector3(-in_vec.y, 0.0, in_vec.x) * cam_side
	in_dribble = Input.is_action_just_pressed("dribble")
	in_tackle = Input.is_action_just_pressed("tackle")
	if Input.is_action_just_pressed("awaken"):
		in_awaken = true
	in_sprint = Input.is_action_pressed("sprint")
	in_shoot_held = Input.is_action_pressed("shoot")
	in_pass = Input.is_action_just_pressed("pass")
	if Input.is_action_just_pressed("jump"):
		in_jump = true
	var dv: float = Input.get_axis("aim_down", "aim_up")
	in_elev = clampf(in_elev + dv * 1.5 * get_physics_process_delta_time(), 0.0, 1.0)
	aim_lock = rig != null and bool(rig.get("locked"))
	for i: int in range(6):
		in_skill[i] = Input.is_action_just_pressed("skill_%d" % (i + 1))


func _physics_process(delta: float) -> void:
	if puppet:
		_puppet_step(delta)
		return
	_tick_timers(delta)
	if is_human and controls_enabled:
		_read_human_input()
	elif not controls_enabled:
		in_wish = Vector3.ZERO
		in_shoot_held = false
		in_sprint = false
		in_pass = false
		in_jump = false
		for i: int in range(6):
			in_skill[i] = false
	if stun_t > 0.0:
		in_wish = Vector3.ZERO
		in_shoot_held = false
		in_sprint = false
		in_jump = false
	if recover_t > 0.0 or fall_t > 0.0:
		in_wish = Vector3.ZERO
	var wish: Vector3 = in_wish
	if wish.length() > 1.0:
		wish = wish.normalized()
	var moving: bool = wish.length() > 0.1

	for i: int in range(6):
		if in_skill[i]:
			try_skill(i)
			in_skill[i] = false

	_update_stamina(delta, moving)
	_update_movement(delta, wish, moving)
	_update_kicking(delta, wish)
	_update_ball_interaction(delta, wish, moving)
	_update_actions()
	_update_slide(delta)
	_update_tackle(delta)
	_update_block()
	_update_intercept()
	_animate(delta)
	if (dash_t > 0.0 or awakened) and arena != null:
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.08
			var fx: Node = arena.get("fx")
			if fx != null and dash_t > 0.0:
				fx.call("trail", arena, global_position + Vector3(0, 0.1, 0), _aura_color())


func _tick_timers(delta: float) -> void:
	_kick_cd = maxf(_kick_cd - delta, 0.0)
	_dribble_cd = maxf(_dribble_cd - delta, 0.0)
	_kick_anim = maxf(_kick_anim - delta, 0.0)
	_tackle_cd = maxf(_tackle_cd - delta, 0.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_tackle_t = maxf(_tackle_t - delta, 0.0)
	fall_t = maxf(fall_t - delta, 0.0)
	recover_t = maxf(recover_t - delta, 0.0)
	_gcd = maxf(_gcd - delta, 0.0)
	stun_t = maxf(stun_t - delta, 0.0)
	immune_t = maxf(immune_t - delta, 0.0)
	shield_t = maxf(shield_t - delta, 0.0)
	block_t = maxf(block_t - delta, 0.0)
	vision_t = maxf(vision_t - delta, 0.0)
	silence_t = maxf(silence_t - delta, 0.0)
	if not awakened:
		var rate: float = Config.f("flow.per_second_ball") if has_ball() else Config.f("flow.per_second")
		add_flow(rate * delta)
	if in_awaken:
		in_awaken = false
		try_awaken()
	for k: Variant in cooldowns.keys():
		cooldowns[k] = maxf(float(cooldowns[k]) - delta, 0.0)
	for k: Variant in buffs.keys():
		var b: Dictionary = buffs[k]
		b["t"] = float(b["t"]) - delta
		if float(b["t"]) <= 0.0:
			buffs.erase(k)
	if dash_t > 0.0:
		dash_t -= delta
		if dash_t <= 0.0:
			_finish_dash()
	if awakened:
		awake_left -= delta
		if awake_left <= 0.0:
			end_awakening()


func _finish_dash() -> void:
	if not dash_shot.is_empty():
		var ds: Dictionary = dash_shot
		dash_shot = {}
		SkillsScript.fire_shot(self, ds, arena)


func _speed_total() -> float:
	var m: float = _speed_mult * buff("speed") * buff("debuff_speed")
	if awakened:
		m *= Config.f("awakening.speed_mult")
	if arena != null and arena.has_method("zone_factor"):
		m *= float(arena.call("zone_factor", self))
	return m


func power_total() -> float:
	var m: float = _power_mult * buff("shot") * buff("debuff_power") * power_scale_once
	if awakened:
		m *= Config.f("awakening.power_mult")
	return m


func _update_stamina(delta: float, moving: bool) -> void:
	var s_max: float = Config.f("player.stamina_max")
	var want_sprint: bool = controls_enabled and moving and in_sprint
	if _sprinting:
		if not want_sprint or stamina <= 0.0:
			_sprinting = false
	elif want_sprint and stamina >= Config.f("player.stamina_min_to_sprint"):
		_sprinting = true
	if _sprinting:
		var drain: float = Config.f("player.stamina_drain") * delta
		if awakened:
			drain *= Config.f("awakening.stamina_drain_mult")
		stamina = maxf(stamina - drain, 0.0)
		_regen_wait = Config.f("player.stamina_regen_delay")
	else:
		_regen_wait = maxf(_regen_wait - delta, 0.0)
		if _regen_wait <= 0.0:
			stamina = minf(stamina + Config.f("player.stamina_regen") * delta, s_max)


func _update_movement(delta: float, wish: Vector3, moving: bool) -> void:
	if not dsk.is_empty():
		_step_dribble(delta)
	var top_speed: float = Config.f("player.sprint_speed") if _sprinting else Config.f("player.run_speed")
	top_speed *= _speed_total()
	var target: Vector3 = wish * top_speed
	var rate: float = Config.f("player.accel") if moving else Config.f("player.decel")
	if dash_t > 0.0:
		target = dash_dir * dash_speed
		rate = Config.f("player.accel") * 3.0
		moving = true
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
		if in_jump and stun_t <= 0.0 and slide_t <= 0.0 and fall_t <= 0.0:
			velocity.y = Config.f("player.jump_speed")
			Sfx.play("whoosh", -9.0)
	else:
		velocity.y -= _gravity * delta
	in_jump = false
	move_and_slide()

	var look: Vector3 = dash_dir if dash_t > 0.0 else wish
	if aim_lock and in_aim.length() > 0.1 and dash_t <= 0.0:
		look = in_aim
		moving = true
	elif is_human and in_aim.length() > 0.1 and dash_t <= 0.0 and (charging or (ball != null and ball_in_range(1.5))):
		look = in_aim
		moving = true
	if moving:
		facing = facing.slerp(look.normalized(), clampf(Config.f("player.turn_speed") * delta, 0.0, 1.0))
		if facing.length() < 0.01:
			facing = look.normalized()
		facing = facing.normalized()
	if _model != null:
		_model.rotation.y = atan2(-facing.x, -facing.z)


func _puppet_step(delta: float) -> void:
	var prev: Vector3 = global_position
	global_position = global_position.lerp(net_pos, clampf(18.0 * delta, 0.0, 1.0))
	var v: Vector3 = (global_position - prev) / maxf(delta, 0.0001)
	velocity = Vector3(v.x, 0.0, v.z)
	facing = Vector3(-sin(net_yaw), 0.0, -cos(net_yaw))
	if _model != null:
		_model.rotation.y = lerp_angle(_model.rotation.y, net_yaw, clampf(14.0 * delta, 0.0, 1.0))
	_kick_anim = maxf(_kick_anim - delta, 0.0)
	_animate(delta)


# ------------------------------------------------------------------ chutes
func aim_assist_strength() -> float:
	var s: float = Config.f("kick.aim_assist_strength")
	if vision_t > 0.0:
		s = maxf(s, vision_assist)
	return s


func aim_direction() -> Vector3:
	var aim: Vector3 = Vector3(facing.x, 0.0, facing.z).normalized()
	if in_aim.length() > 0.1:
		aim = Vector3(in_aim.x, 0.0, in_aim.z).normalized()
	var to_goal: Vector3 = attack_goal - global_position
	to_goal.y = 0.0
	if to_goal.length() > 0.5:
		to_goal = to_goal.normalized()
		var max_angle: float = deg_to_rad(Config.f("kick.aim_assist_angle_deg"))
		if vision_t > 0.0:
			max_angle *= 1.8
		if aim.angle_to(to_goal) < max_angle:
			aim = aim.slerp(to_goal, aim_assist_strength()).normalized()
	return aim


func ball_in_range(extra: float = 0.0) -> bool:
	if ball == null:
		return false
	var d: Vector3 = ball.global_position - global_position
	d.y = 0.0
	return d.length() <= Config.f("kick.range") + extra + buff("reach", 0.0) and ball.global_position.y < 1.9


func _shot_error_deg() -> float:
	var base: float = Config.f("kick.error_deg") * clampf(1.3 - stat("chute") / 100.0, 0.3, 1.0)
	if charge > Config.f("kick.sweet_hi"):
		base += Config.f("kick.overcharge_error_deg") * (charge - Config.f("kick.sweet_hi")) / maxf(1.0 - Config.f("kick.sweet_hi"), 0.01)
	elif charge < Config.f("kick.sweet_lo"):
		base *= 0.6
	return base


func shot_loft() -> float:
	return lerpf(Config.f("kick.shot_loft"), Config.f("kick.max_loft"), in_elev)


func shot_power(ch: float) -> float:
	var power: float = lerpf(Config.f("kick.min_power"), Config.f("kick.max_power"), ch) * power_total()
	return power * lerpf(1.0, 0.86, in_elev)


func _update_kicking(delta: float, wish: Vector3) -> void:
	if not controls_enabled or stun_t > 0.0 or slide_t > 0.0:
		charging = false
		charge = 0.0
		_prev_shoot = in_shoot_held
		return
	if in_shoot_held:
		charging = true
		charge = minf(charge + delta / Config.f("kick.charge_time_s"), 1.0)
	elif charging:
		if ball_in_range() and _kick_cd <= 0.0:
			var aim: Vector3 = aim_direction()
			var err: float = _shot_error_deg()
			aim = aim.rotated(Vector3.UP, deg_to_rad(randf_range(-err, err)))
			var curve: float = 0.0
			if wish.length() > 0.3:
				curve = clampf(aim.cross(wish.normalized()).y, -1.0, 1.0) * Config.f("kick.curve_spin")
			do_kick(Vector3(aim.x, shot_loft(), aim.z), shot_power(charge), curve, "shot")
			in_elev = 0.0
		charging = false
		charge = 0.0
	_prev_shoot = in_shoot_held

	if in_pass and ball_in_range() and _kick_cd <= 0.0:
		_do_pass()
	in_pass = false


## Passe direto no parceiro mirado; sem mira, vai para um parceiro escolhido de forma equilibrada.
func _do_pass() -> void:
	var mate: Node = null
	if arena != null and arena.has_method("best_pass_mate"):
		mate = arena.call("best_pass_mate", self)
	var dirp: Vector3 = aim_direction()
	var spd: float = Config.f("kick.pass_speed")
	var loft: float = Config.f("kick.pass_loft") + in_elev * 0.5
	var err: float = 2.0
	if mate != null:
		var m3: Node3D = mate as Node3D
		var d: Vector3 = m3.global_position - global_position
		d.y = 0.0
		var dist: float = d.length()
		spd = clampf(9.0 + dist * 0.55, Config.f("kick.pass_speed") * 0.7, Config.f("kick.pass_max_speed"))
		var lead: Vector3 = m3.global_position + Vector3(m3.get("velocity")) * (dist / spd) * 0.8
		var dl: Vector3 = lead - global_position
		dl.y = 0.0
		dirp = dl.normalized()
		if dist > 20.0:
			loft += 0.16
		err = 1.5 + (1.0 - stat("passe") / 100.0) * 4.0
	dirp = dirp.rotated(Vector3.UP, deg_to_rad(randf_range(-err, err)))
	do_kick(Vector3(dirp.x, loft, dirp.z), spd, 0.0, "pass")


func do_kick(direction: Vector3, speed: float, spin_y: float, kind: String) -> void:
	if ball == null:
		return
	ball.call("kick", direction, speed, spin_y)
	ball.set_meta("last_team", team)
	ball.set_meta("last_char", char_id)
	ball.set_meta("last_player", index)
	ball.set_meta("last_skill", last_skill if kind == "skill" else "")
	ball.set_meta("last_awake", awakened)
	_kick_cd = Config.f("kick.cooldown_s")
	_dribble_cd = Config.f("player.dribble_cooldown_s")
	_kick_anim = KICK_ANIM_LEN
	ball_kicked.emit(kind, speed)


# ------------------------------------------------ condução e contato
func _update_ball_interaction(_delta: float, wish: Vector3, moving: bool) -> void:
	if ball == null or not controls_enabled or stun_t > 0.0:
		return
	var to_ball: Vector3 = ball.global_position - global_position
	to_ball.y = 0.0
	var dist: float = to_ball.length()
	var ball_radius: float = Config.f("ball.radius")
	var body_r: float = Config.f("player.body_radius")
	var hv: Vector3 = Vector3(velocity.x, 0.0, velocity.z)

	if dist < body_r + ball_radius and dist > 0.001 and ball.global_position.y < Config.f("player.body_height"):
		var normal: Vector3 = to_ball / dist
		var v: Vector3 = ball.linear_velocity
		var vn: float = v.dot(normal)
		if vn < 0.0:
			v -= (1.0 + Config.f("player.bump_restitution")) * vn * normal
		v += hv * Config.f("player.bump_player_speed_share") * 0.2
		ball.linear_velocity = v

	var magnet: float = buff("magnet", 0.0)
	var drange: float = Config.f("player.dribble_range") * (1.0 + magnet * 0.6) * (0.9 + stat("drible") / 500.0)
	if _dribble_cd > 0.0 or dist > drange or ball.global_position.y > 1.0:
		return
	var pull_k: float = Config.f("player.dribble_pull") * (1.0 + magnet)
	var blend: float = clampf(Config.f("player.dribble_blend") * (1.0 + magnet * 0.5), 0.0, 0.9)
	var bv: Vector3 = ball.linear_velocity
	if moving:
		var target: Vector3 = global_position + facing * Config.f("player.dribble_front_offset")
		var pull: Vector3 = (target - ball.global_position)
		pull.y = 0.0
		var desired: Vector3 = hv + pull * pull_k
		var flat: Vector3 = Vector3(bv.x, 0.0, bv.z).lerp(desired, blend)
		ball.linear_velocity = Vector3(flat.x, bv.y, flat.z)
		ball.set_meta("last_team", team)
		ball.set_meta("last_char", char_id)
		ball.set_meta("last_player", index)
	elif Vector3(bv.x, 0.0, bv.z).length() < Config.f("kick.pass_speed"):
		var damp: Vector3 = Vector3(bv.x, 0.0, bv.z).lerp(Vector3.ZERO, blend)
		ball.linear_velocity = Vector3(damp.x, bv.y, damp.z)
		ball.set_meta("last_team", team)
		ball.set_meta("last_char", char_id)
		ball.set_meta("last_player", index)


func has_ball() -> bool:
	if ball == null:
		return false
	var d: Vector3 = ball.global_position - global_position
	d.y = 0.0
	return d.length() < Config.f("player.dribble_range") * 1.1 and int(ball.get_meta("last_team", -1)) == team


## Desarme automático por contato: chance baseada em defesa x drible.
func _update_tackle(_delta: float) -> void:
	if ball == null or _tackle_cd > 0.0 or stun_t > 0.0 or not controls_enabled or slide_t > 0.0:
		return
	var dist_ball: float = global_position.distance_to(ball.global_position)
	var reach: float = Config.f("skills.steal_range")
	if dist_ball > reach or ball.global_position.y > 1.0:
		return
	if int(ball.get_meta("last_team", team)) == team:
		return
	if ball.linear_velocity.length() > 11.0:
		return
	var holder: Node = null
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n != self and int(n.get("team")) != team and n.call("has_ball"):
			holder = n
			break
	if holder == null:
		return
	if float(holder.get("immune_t")) > 0.0 or float(holder.get("shield_t")) > 0.0:
		_tackle_cd = 0.4
		return
	_tackle_cd = Config.f("skills.steal_cooldown_s")
	var chance: float = Config.f("skills.steal_base_chance") * (stat("defesa") + 20.0) / (float(holder.call("stat", "drible")) + 20.0)
	if randf() < clampf(chance, 0.1, 0.9):
		var dir: Vector3 = (global_position - ball.global_position)
		dir.y = 0.0
		ball.linear_velocity = dir.normalized() * 4.0
		ball.set_meta("last_team", team)
		ball.set_meta("last_char", char_id)
		ball.set_meta("last_player", index)
		ball.set_meta("last_skill", "")
		holder.call("stun", 0.25)
		stole_ball.emit(self)


## Q = drible rápido com pedaladas (pode dar Angle Breaker); C/Ctrl = carrinho de desarme.
func _update_actions() -> void:
	if stun_t > 0.0 or not controls_enabled or fall_t > 0.0:
		in_dribble = false
		in_tackle = false
		return
	if in_dribble and _dodge_cd <= 0.0 and stamina >= Config.f("skills.dodge_stamina") and dsk.is_empty() and slide_t <= 0.0:
		var base: Vector3 = in_wish if in_wish.length() > 0.2 else facing
		start_dribble("stepover", Config.f("skills.dodge_dur_s") + 0.2, Config.f("skills.dodge_speed"), 38.0, 2.4, 1.0, base)
		stamina -= Config.f("skills.dodge_stamina")
		_regen_wait = Config.f("player.stamina_regen_delay")
		_dodge_cd = Config.f("skills.dodge_cd_s")
	if in_tackle and _tackle_cd <= 0.0 and slide_t <= 0.0 and recover_t <= 0.0 and dsk.is_empty():
		start_slide()
	in_dribble = false
	in_tackle = false


var _slide_dir: Vector3 = Vector3.ZERO


## Drible de skill/botão: padrões (zigzag, elastic, roulette, feint, nutmeg, stepover).
func start_dribble(pattern: String, dur: float, speed_mult: float, amp_deg: float, freq: float, brk: float, base_dir: Vector3) -> void:
	var b: Vector3 = Vector3(base_dir.x, 0.0, base_dir.z)
	if b.length() < 0.1:
		b = facing
	dsk = {"pattern": pattern, "t": 0.0, "dur": dur, "speed": speed_mult, "amp": amp_deg, "freq": freq,
		"brk": brk, "base": b.normalized(), "side": 1.0 if randf() > 0.5 else -1.0, "hit": [], "pushed": false}
	immune_t = maxf(immune_t, dur * 0.8)
	add_buff("magnet", 0.9, dur + 0.3)
	Sfx.play("whoosh", -3.0)


func _step_dribble(delta: float) -> void:
	dsk["t"] = float(dsk["t"]) + delta
	var t: float = float(dsk["t"])
	var dur: float = float(dsk["dur"])
	if t >= dur:
		dsk = {}
		return
	var k: float = t / dur
	var amp: float = float(dsk["amp"])
	var freq: float = float(dsk["freq"])
	var side_s: float = float(dsk["side"])
	var base: Vector3 = dsk["base"]
	var spd: float = float(dsk["speed"])
	var ang: float = 0.0
	var dir: Vector3 = base
	match String(dsk["pattern"]):
		"zigzag", "stepover":
			ang = amp * sin(TAU * freq * t)
		"elastic":
			var w: float = sin(TAU * freq * t)
			ang = amp * signf(w) * pow(absf(w), 0.35)
		"roulette":
			dir = (base.rotated(Vector3.UP, TAU * k * side_s) * 0.8 + base * 0.6).normalized()
			spd *= 0.85
		"feint":
			if k < 0.38:
				ang = -amp * side_s
				spd *= 0.4
			else:
				ang = amp * 0.25 * side_s * (1.0 - k)
				spd *= 1.5
		"nutmeg":
			spd *= 1.25 if k > 0.15 else 0.7
			if not bool(dsk["pushed"]) and k > 0.15 and ball != null:
				dsk["pushed"] = true
				ball.linear_velocity = base * 12.0 + Vector3(0.0, 1.5, 0.0)
				ball.set_meta("last_team", team)
	if ang != 0.0:
		dir = base.rotated(Vector3.UP, deg_to_rad(ang) * side_s)
	dash_dir = dir.normalized()
	dash_speed = Config.f("skills.dash_base_speed") * spd * _speed_mult
	dash_t = maxf(dash_t, 0.06)
	_step_phase += delta * freq * TAU
	_angle_break()


## Angle Breaker: o driblador faz o marcador próximo cair no chão (chance por drible x defesa).
func _angle_break() -> void:
	var brk: float = float(dsk.get("brk", 0.0))
	if brk <= 0.0:
		return
	var hit: Array = dsk["hit"]
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n == self or int(n.get("team")) == team or hit.has(n):
			continue
		if global_position.distance_to((n as Node3D).global_position) > 1.9:
			continue
		hit.append(n)
		if float(n.get("fall_t")) > 0.0 or float(n.get("shield_t")) > 0.0:
			continue
		var chance: float = clampf(0.4 + (stat("drible") - float(n.call("stat", "defesa"))) / 110.0, 0.2, 0.85)
		if randf() < chance:
			n.call("knockdown", brk * 1.2)
			add_flow(5.0)
			Sfx.play("impact_1", -2.0)
			if arena != null:
				var fx: Node = arena.get("fx")
				if fx != null:
					fx.call("ring", arena, (n as Node3D).global_position, _aura_color(), 3.5, 0.4)
					fx.call("ono", "baki", Vector2.ZERO, _aura_color())
				if is_human:
					var hud: Node = arena.get("hud")
					if hud != null:
						hud.call("toast", "ANGLE BREAKER!", Color(0.5, 0.9, 1.0))


func knockdown(duration: float) -> void:
	if immune_t > 0.0 or shield_t > 0.0:
		return
	stun_t = maxf(stun_t, duration)
	fall_t = maxf(fall_t, duration)
	dsk = {}
	slide_t = 0.0
	charging = false
	Sfx.play("impact_1", -4.0)


func start_slide() -> void:
	var d: Vector3 = in_wish if in_wish.length() > 0.2 else facing
	_slide_dir = Vector3(d.x, 0.0, d.z).normalized()
	slide_t = Config.f("skills.slide_dur_s")
	slide_hit = false
	_tackle_cd = Config.f("skills.slide_cd_s")
	Sfx.play("dash", -2.0)


func _ball_holder_opponent() -> Node:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n != self and int(n.get("team")) != team and n.call("has_ball"):
			return n
	return null


func _update_slide(delta: float) -> void:
	if slide_t <= 0.0:
		return
	slide_t -= delta
	var dur: float = Config.f("skills.slide_dur_s")
	var k: float = clampf(slide_t / dur, 0.0, 1.0)
	dash_dir = _slide_dir
	dash_speed = Config.f("skills.dash_base_speed") * Config.f("skills.slide_speed") * (0.3 + 0.7 * k) * _speed_mult
	dash_t = maxf(dash_t, 0.06)
	facing = _slide_dir
	if not slide_hit and ball != null:
		var d: Vector3 = ball.global_position - global_position
		d.y = 0.0
		if d.length() < Config.f("skills.slide_reach") and ball.global_position.y < 1.0:
			_slide_contact()
	if slide_t <= 0.0 and not slide_hit:
		recover_t = Config.f("skills.slide_recover_s")


func _slide_contact() -> void:
	slide_hit = true
	var holder: Node = _ball_holder_opponent()
	if holder == null:
		if int(ball.get_meta("last_team", -1)) != team:
			ball.linear_velocity = _slide_dir * 8.0
			ball.set_meta("last_team", team)
			ball.set_meta("last_char", char_id)
			ball.set_meta("last_player", index)
			stole_ball.emit(self)
		return
	if not (holder.get("dsk") as Dictionary).is_empty():
		knockdown(Config.f("skills.slide_fail_fall_s"))
		if arena != null:
			var fx: Node = arena.get("fx")
			if fx != null:
				fx.call("ono", "hyu", Vector2.ZERO, Color(0.6, 0.9, 1.0))
		return
	if float(holder.get("immune_t")) > 0.0 or float(holder.get("shield_t")) > 0.0:
		recover_t = Config.f("skills.slide_recover_s")
		return
	ball.linear_velocity = _slide_dir * 5.0 + Vector3(0.0, 1.0, 0.0)
	ball.set_meta("last_team", team)
	ball.set_meta("last_char", char_id)
	ball.set_meta("last_player", index)
	ball.set_meta("last_skill", "")
	holder.call("knockdown", Config.f("skills.slide_steal_stun_s"))
	stole_ball.emit(self)
	if arena != null:
		var fx2: Node = arena.get("fx")
		if fx2 != null:
			fx2.call("burst", arena, (holder as Node3D).global_position + Vector3(0, 0.5, 0), _aura_color(), 14, 4.0, 0.4, 0.5, "star")


## Puxa a bola para os pés (usado pelas skills de chute quando a bola está perto).
func snap_ball() -> void:
	if ball == null:
		return
	var f: Vector3 = Vector3(facing.x, 0.0, facing.z).normalized()
	ball.global_position = global_position + f * 0.8 + Vector3(0.0, Config.f("ball.radius") - Config.f("player.body_height") / 2.0 + 0.1, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO


func _update_block() -> void:
	if block_t <= 0.0 or ball == null:
		return
	var to_ball: Vector3 = ball.global_position - global_position
	to_ball.y = 0.0
	if to_ball.length() < block_r and int(ball.get_meta("last_team", team)) != team:
		var v: Vector3 = ball.linear_velocity
		if v.length() > 3.0:
			var n: Vector3 = to_ball.normalized()
			ball.linear_velocity = n * (v.length() * 0.35) + Vector3(0.0, 2.0, 0.0)
			if arena != null:
				var fx: Node = arena.get("fx")
				if fx != null:
					fx.call("ring", arena, global_position, _aura_color(), 5.0, 0.4)
				Sfx.play("impact_1", -4.0)


## Metavisão com hitbox alta (Aiku/Karasu): intercepta chutes e passes inimigos que chegam perto.
func _update_intercept() -> void:
	if vision_t <= 0.0 or intercept_r <= 0.0 or ball == null:
		return
	if int(ball.get_meta("last_team", team)) == team:
		return
	var to_ball: Vector3 = ball.global_position - global_position
	var v: Vector3 = ball.linear_velocity
	if to_ball.length() > intercept_r or v.length() < 3.0 or ball.global_position.y > 3.0:
		return
	var target: Vector3 = global_position + facing * 0.6 + Vector3(0.0, 0.5, 0.0)
	var pull: Vector3 = target - ball.global_position
	if pull.length() < 1.1:
		ball.linear_velocity = Vector3.ZERO
		ball.set_meta("last_team", team)
		ball.set_meta("last_char", char_id)
		ball.set_meta("last_player", index)
		stole_ball.emit(self)
		Sfx.play("tackle", -4.0)
	else:
		ball.linear_velocity = pull.normalized() * maxf(v.length() * 0.8, 9.0)


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
	if not dsk.is_empty():
		var sp: float = _step_phase * 2.0
		_leg_l.rotation.x = sin(sp) * 1.0
		_leg_r.rotation.x = -sin(sp + 0.8) * 1.0
		_arm_l.rotation.x = sin(sp) * 0.6
		_arm_r.rotation.x = -sin(sp) * 0.6
	if stun_t > 0.0:
		_arm_l.rotation.x = -2.6
		_arm_r.rotation.x = -2.6
	elif not is_on_floor() and not puppet:
		_arm_l.rotation.x = -2.2
		_arm_r.rotation.x = -2.2
	if _kick_anim > 0.0:
		_leg_r.rotation.x = 1.3 * (_kick_anim / KICK_ANIM_LEN)
	elif charging:
		_leg_r.rotation.x = -0.7 * charge
	var tilt: float = 0.0
	if slide_t > 0.0:
		tilt = 1.15
		_leg_l.rotation.x = 1.35
		_leg_r.rotation.x = 1.35
		_arm_l.rotation.x = -1.2
		_arm_r.rotation.x = -1.2
	elif fall_t > 0.0 or (puppet and stun_t > 0.5):
		tilt = 1.45
		_leg_l.rotation.x = 0.2
		_leg_r.rotation.x = -0.2
	elif recover_t > 0.0:
		tilt = 0.45
	_pose_t = maxf(_pose_t - delta, 0.0)
	if _model != null and _pose_t <= 0.0:
		_model.rotation.x = lerpf(_model.rotation.x, tilt, clampf(18.0 * delta, 0.0, 1.0))


func kick_anim_now() -> void:
	_kick_anim = KICK_ANIM_LEN


func clear_kick_cd() -> void:
	_kick_cd = 0.0
