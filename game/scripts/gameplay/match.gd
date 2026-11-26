extends Node3D
## Cena principal do M1: monta campo, bola, jogador, câmera e HUD por código;
## controla o fluxo da partida (saque, gol com câmera lenta, fim de jogo).

const FieldScript = preload("res://scripts/gameplay/field.gd")
const BallScript = preload("res://scripts/gameplay/ball.gd")
const PlayerScript = preload("res://scripts/gameplay/player.gd")
const CameraRigScript = preload("res://scripts/gameplay/camera_rig.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const TouchScript = preload("res://scripts/ui/touch_controls.gd")

enum State { PLAYING, GOAL, FINISHED }

var state: int = State.PLAYING
var score: Array[int] = [0, 0]
var time_left: float = 0.0

var field: FieldScript
var ball: BallScript
var player: PlayerScript
var rig: CameraRigScript
var hud: HudScript
var touch: TouchScript
var sun: DirectionalLight3D
var env: Environment
var _goal_token: int = 0


func _ready() -> void:
	_build_environment()
	field = FieldScript.new()
	add_child(field)

	ball = BallScript.new()
	ball.position = Vector3(0.0, Config.f("ball.reset_height"), 0.0)
	add_child(ball)

	player = PlayerScript.new()
	add_child(player)
	player.ball = ball
	player.attack_goal = Vector3(Config.f("field.length") / 2.0, 0.0, 0.0)
	player.setup(Config.load_character("isagi"), 0)

	rig = CameraRigScript.new()
	rig.player = player
	rig.ball = ball
	add_child(rig)

	hud = HudScript.new()
	add_child(hud)
	touch = TouchScript.new()
	add_child(touch)

	field.goal_scored.connect(_on_goal_scored)
	player.ball_kicked.connect(_on_ball_kicked)

	Config.apply_quality(Config.quality_level, get_viewport(), sun)
	_new_match()


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.03, 0.06, 0.2)
	sky_mat.sky_horizon_color = Color(0.22, 0.28, 0.5)
	sky_mat.ground_horizon_color = Color(0.12, 0.15, 0.3)
	sky_mat.ground_bottom_color = Color(0.03, 0.04, 0.1)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -35.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

	_build_floodlights()


## Quatro torres de refletor (visual) nos cantos do estádio.
func _build_floodlights() -> void:
	var half_l: float = Config.f("field.length") / 2.0 + Config.f("field.goal_depth") + 6.0
	var half_w: float = Config.f("field.width") / 2.0 + 6.0
	var pole_mat: StandardMaterial3D = StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.2, 0.22, 0.3)
	var lamp_mat: StandardMaterial3D = StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1.0, 0.97, 0.85)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.95, 0.8)
	lamp_mat.emission_energy_multiplier = 4.0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var pole: MeshInstance3D = MeshInstance3D.new()
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.3
			cyl.bottom_radius = 0.4
			cyl.height = 22.0
			pole.mesh = cyl
			pole.material_override = pole_mat
			pole.position = Vector3(sx * half_l, 11.0, sz * half_w)
			add_child(pole)
			var lamp: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(3.2, 1.6, 0.4)
			lamp.mesh = box
			lamp.material_override = lamp_mat
			add_child(lamp)
			lamp.look_at_from_position(Vector3(sx * half_l, 22.4, sz * half_w), Vector3.ZERO, Vector3.UP)


# ----------------------------------------------------------------- partida

func _new_match() -> void:
	_goal_token += 1
	Engine.time_scale = 1.0
	score = [0, 0]
	time_left = Config.f("match.duration_s")
	hud.set_score(0, 0)
	hud.set_time(time_left)
	_kickoff()
	hud.show_message("COMEÇOU!", Color(0.6, 0.9, 1.0), 1.2)


func _kickoff() -> void:
	ball.reset_to(Vector3(0.0, Config.f("ball.reset_height"), 0.0))
	player.global_position = Vector3(Config.f("match.kickoff_player_x"), Config.f("player.body_height") / 2.0 + 0.05, 0.0)
	player.velocity = Vector3.ZERO
	player.controls_enabled = true
	state = State.PLAYING
	rig.snap()


func _process(delta: float) -> void:
	hud.update_bars(player.stamina_ratio(), player.charge, player.charging)

	if Input.is_action_just_pressed("toggle_quality"):
		var next: int = (Config.quality_level + 1) % 3
		Config.apply_quality(next, get_viewport(), sun)
		hud.show_message(["QUALIDADE: BAIXA", "QUALIDADE: MÉDIA", "QUALIDADE: ALTA"][next], Color.WHITE, 1.0)

	match state:
		State.PLAYING:
			time_left -= delta
			hud.set_time(time_left)
			if Input.is_action_just_pressed("reset_ball"):
				ball.reset_to(Vector3(0.0, Config.f("ball.reset_height"), 0.0))
			if time_left <= 0.0:
				_finish_match()
		State.FINISHED:
			if Input.is_action_just_pressed("reset_ball"):
				_new_match()
		_:
			pass


func _finish_match() -> void:
	state = State.FINISHED
	player.controls_enabled = false
	hud.set_time(0.0)
	hud.show_message("FIM DE JOGO  %d x %d" % [score[0], score[1]], Color(1.0, 0.9, 0.4), 0.0)


func _on_goal_scored(scoring_team: int) -> void:
	if state != State.PLAYING:
		return
	state = State.GOAL
	score[scoring_team] += 1
	hud.set_score(score[0], score[1])
	hud.show_message("GOOOL!", Color(1.0, 0.85, 0.25), Config.f("match.goal_celebration_s"))
	rig.shake(0.6)
	_goal_sequence()


func _goal_sequence() -> void:
	_goal_token += 1
	var token: int = _goal_token
	Engine.time_scale = Config.f("match.goal_slowmo_scale")
	await get_tree().create_timer(Config.f("match.goal_slowmo_s"), true, false, true).timeout
	if token != _goal_token:
		return
	Engine.time_scale = 1.0
	await get_tree().create_timer(Config.f("match.goal_celebration_s") - Config.f("match.goal_slowmo_s"), true, false, true).timeout
	if token != _goal_token:
		return
	if time_left <= 0.0:
		_finish_match()
	else:
		_kickoff()


func _on_ball_kicked(kind: String, power: float) -> void:
	if kind == "shot" and power > Config.f("kick.max_power") * 0.8:
		rig.shake(0.15)
