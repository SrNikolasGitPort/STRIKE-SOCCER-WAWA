extends Node3D
## Partida: monta campo, bola, times (humano + bots), câmera, HUD e FX; controla
## saque, gols, Despertar a cada 90 s, zonas de skill, missões Nel, pausa e resultado.
## Modos (Game.mode): training | 2v2 | 4v4 | online.

const FieldScript = preload("res://scripts/gameplay/field.gd")
const BallScript = preload("res://scripts/gameplay/ball.gd")
const PlayerScript = preload("res://scripts/gameplay/player.gd")
const BotScript = preload("res://scripts/gameplay/bot.gd")
const FxScript = preload("res://scripts/gameplay/fx.gd")
const CameraRigScript = preload("res://scripts/gameplay/camera_rig.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const TouchScript = preload("res://scripts/ui/touch_controls.gd")

enum State { PLAYING, GOAL, FINISHED }

var state: int = State.PLAYING
var score: Array[int] = [0, 0]
var time_left: float = 0.0
var players: Array = []
var human: Node = null
var online: bool = false
var is_client: bool = false
var net: Node = null
var team_size: int = 1

var field: FieldScript
var ball: BallScript
var player: PlayerScript
var rig: CameraRigScript
var hud: HudScript
var touch: TouchScript
var fx: FxScript
var sun: DirectionalLight3D
var env: Environment
var _goal_token: int = 0
var _awaken_clock: float = 0.0
var _awaken_next_team: int = 0
var _zones: Array = []
var _stats: Dictionary = {"goals": 0, "assists": 0, "steals": 0}
var _last_kick: Array = [{}, {}]
var _paused_layer: CanvasLayer = null
var _result_layer: CanvasLayer = null
var _was_awake_human: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	online = Game.mode == "online"
	is_client = online and Game.online_role == "client"
	_build_environment()
	field = FieldScript.new()
	add_child(field)

	ball = BallScript.new()
	ball.position = Vector3(0.0, Config.f("ball.reset_height"), 0.0)
	add_child(ball)
	ball.set_meta("last_team", -1)

	fx = FxScript.new()
	fx.online = online
	add_child(fx)

	hud = HudScript.new()
	add_child(hud)
	touch = TouchScript.new()
	add_child(touch)

	rig = CameraRigScript.new()
	add_child(rig)
	fx.rig = rig

	field.goal_scored.connect(_on_goal_scored)
	hud.pause_requested.connect(_toggle_pause)
	Game.quest_completed.connect(_on_quest_completed)

	if online:
		net = Net
		net.call("start_match", self)
	else:
		_build_offline_teams()

	if human == null and not is_client:
		push_warning("Partida sem jogador humano")
	_finalize_setup()
	Config.apply_quality(Config.quality_level, get_viewport(), sun)
	Sfx.music("match_theme")
	Sfx.crowd(true)
	_new_match()


func _finalize_setup() -> void:
	if human != null:
		player = human
		rig.player = human
		hud.bind_player(human)
		rig.side = float(human.get("cam_side"))
	rig.ball = ball
	if player != null:
		rig.snap()
	hud.set_team_names(Game.t("AZUL", "BLUE"), Game.t("VERMELHO", "RED"))


# ------------------------------------------------------------- jogadores
func spawn_player(char_id: String, team: int, index: int, kind: String) -> Node:
	var p: PlayerScript = PlayerScript.new()
	add_child(p)
	p.ball = ball
	p.arena = self
	p.index = index
	var half_l: float = Config.f("field.length") / 2.0
	var s: float = 1.0 if team == 0 else -1.0
	p.attack_goal = Vector3(s * half_l, 0.0, 0.0)
	p.own_goal = Vector3(-s * half_l, 0.0, 0.0)
	p.setup(Game.character(char_id), team, kind == "human")
	p.cam_side = s if kind == "human" else 1.0
	match kind:
		"human":
			human = p
		"bot":
			var bot: BotScript = BotScript.new()
			bot.p = p
			bot.arena = self
			bot.difficulty = clampf(0.55 + 0.1 * float(team_size - 1), 0.4, 0.9)
			p.add_child(bot)
			p.role = _role_for(index)
			bot.role = p.role
		"puppet":
			p.puppet = true
	p.ball_kicked.connect(_on_player_kick.bind(p))
	p.stole_ball.connect(_on_stole)
	p.skill_used.connect(_on_skill_used)
	players.append(p)
	return p


func _role_for(index: int) -> String:
	if team_size <= 1:
		return "attacker"
	if index == 0:
		return "attacker"
	if team_size == 2:
		return "support"
	return ["attacker", "support", "defender", "support"][index % 4]


func _build_offline_teams() -> void:
	match Game.mode:
		"2v2":
			team_size = 2
		"4v4":
			team_size = 4
		_:
			team_size = 1
	var used: Array = [Game.selected_char]
	var base_ids: Array = []
	for cid: Variant in Game.char_order():
		if not Game.is_evolution(String(cid)):
			base_ids.append(String(cid))
	var human_id: String = Game.selected_char
	if Game.character(human_id).is_empty() or not Game.is_unlocked(human_id):
		human_id = "isagi"
	var team0: Array = [human_id]
	var count: int = team_size
	var training: bool = Game.mode == "training"
	if training:
		count = 1
	while team0.size() < count:
		var c: String = _pick(base_ids, used)
		team0.append(c)
	for i: int in range(team0.size()):
		spawn_player(String(team0[i]), 0, i, "human" if i == 0 else "bot")
	if not training:
		for i: int in range(count):
			spawn_player(_pick(base_ids, used), 1, i, "bot")


func _pick(pool: Array, used: Array) -> String:
	var choices: Array = pool.filter(func(c: Variant) -> bool: return not used.has(c))
	if choices.is_empty():
		choices = pool
	var c: String = String(choices[_rng.randi() % choices.size()])
	used.append(c)
	return c


func _kickoff_positions() -> void:
	var counts: Array[int] = [0, 0]
	for p: Node in players:
		counts[int(p.get("team"))] += 1
	for p: Node in players:
		var t: int = int(p.get("team"))
		var s: float = 1.0 if t == 0 else -1.0
		var i: int = int(p.get("index"))
		var x: float = -s * (Config.f("match.kickoff_player_x") * -1.0 + 4.0 * float(i))
		var z: float = 0.0
		if counts[t] > 1:
			z = (3.5 if i % 2 == 0 else -3.5) * (1.0 if i > 0 else 0.0)
		if bool(p.get("is_human")) and t == 0 and counts[t] == 1:
			x = Config.f("match.kickoff_player_x")
		(p as Node3D).global_position = Vector3(x, Config.f("player.body_height") / 2.0 + 0.05, z)
		p.set("velocity", Vector3.ZERO)
		p.set("facing", Vector3(s, 0.0, 0.0))


## Online (host): jogador desconectado vira bot.
func convert_to_bot(i: int) -> void:
	if i < 0 or i >= players.size():
		return
	var p: Node = players[i]
	var bot: BotScript = BotScript.new()
	bot.p = p
	bot.arena = self
	bot.difficulty = 0.6
	p.add_child(bot)
	p.role = _role_for(int(p.get("index")))
	bot.role = p.role
	p.set("controls_enabled", true)


## Online (cliente): reage aos eventos enviados pelo host.
func on_net_event(d: Dictionary) -> void:
	match String(d.get("t", "")):
		"goal":
			var sc: Array = d.get("score", [0, 0])
			score = [int(sc[0]), int(sc[1])]
			state = State.GOAL
			hud.set_score(score[0], score[1])
			hud.show_message(Game.t("GOOOL!", "GOAAAL!"), Color(1.0, 0.85, 0.25), Config.f("match.goal_celebration_s"))
			rig.shake(0.6)
			Sfx.play("goal_horn")
			Sfx.play("crowd_cheer", -2.0)
			fx.call("flash", Color(1, 1, 1), 0.5, 0.6)
			fx.call("burst", self, ball.global_position, Color(1.0, 0.85, 0.3), 60, 12.0, 0.9, 1.2, "star")
		"kickoff":
			state = State.PLAYING
			Sfx.play("whistle", -4.0)
		"awaken":
			for p: Node in players:
				if int(p.get("team")) == int(d.get("team", -1)) and int(p.get("index")) == int(d.get("idx", -1)):
					p.call("awaken", Config.f("awakening.duration_s"))
					var col: Color = p.call("_aura_color")
					fx.call("cutscene", "%s — %s" % [String(p.get("display_name")).to_upper(), Game.t("DESPERTAR!", "AWAKENING!")], "gogogo", col, p == human)
					Sfx.play("awaken")
		"end":
			var sc2: Array = d.get("score", [0, 0])
			score = [int(sc2[0]), int(sc2[1])]
			state = State.FINISHED
			var mine: int = int(human.get("team")) if human != null else 0
			var won: bool = score[mine] > score[1 - mine]
			var draw: bool = score[0] == score[1]
			var coins: int = int(Config.f("modes.win_coins")) if won else (int(Config.f("modes.draw_coins")) if draw else int(Config.f("modes.loss_coins")))
			var xp: int = int(Config.f("modes.win_xp")) if won else int(Config.f("modes.loss_xp"))
			Game.add_coins(coins)
			Game.xp += xp
			Game.save_game()
			Game.last_result = {"score": [score[mine], score[1 - mine]], "won": won, "draw": draw, "coins": coins, "xp": xp, "stats": {}, "mode": "online"}
			hud.set_time(0.0)
			hud.show_message(Game.t("FIM DE JOGO  %d x %d", "FULL TIME  %d x %d") % [score[0], score[1]], Color(1.0, 0.9, 0.4), 0.0)
			Sfx.play("whistle_long")
			get_tree().create_timer(2.2).timeout.connect(_show_results)


# ------------------------------------------------------------- ambiente
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
	_build_stands()


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


## Arquibancadas simples (blocos inclinados com textura de halftone) ao redor da arena.
func _build_stands() -> void:
	var half_l: float = Config.f("field.length") / 2.0 + Config.f("field.goal_depth") + 4.0
	var half_w: float = Config.f("field.width") / 2.0 + 4.0
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.13, 0.28)
	var tex_path: String = "res://assets/textures/ui/halftone.png"
	if ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
		mat.uv1_scale = Vector3(14.0, 3.0, 1.0)
		mat.albedo_color = Color(0.55, 0.65, 1.0)
	for sz: float in [-1.0, 1.0]:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(Config.f("field.length") + 24.0, 9.0, 3.0)
		mi.mesh = box
		mi.material_override = mat
		mi.position = Vector3(0.0, 4.0, sz * (half_w + 6.0))
		mi.rotation_degrees = Vector3(-sz * 24.0, 0.0, 0.0)
		add_child(mi)
	for sx: float in [-1.0, 1.0]:
		var mi2: MeshInstance3D = MeshInstance3D.new()
		var box2: BoxMesh = BoxMesh.new()
		box2.size = Vector3(3.0, 9.0, Config.f("field.width") + 24.0)
		mi2.mesh = box2
		mi2.material_override = mat
		mi2.position = Vector3(sx * (half_l + 6.0), 4.0, 0.0)
		mi2.rotation_degrees = Vector3(0.0, 0.0, sx * 24.0)
		add_child(mi2)


# ----------------------------------------------------------------- partida
func _new_match() -> void:
	_goal_token += 1
	Engine.time_scale = 1.0
	score = [0, 0]
	_stats = {"goals": 0, "assists": 0, "steals": 0}
	match Game.mode:
		"training":
			time_left = 3600.0
		"4v4":
			time_left = Config.f("modes.match_4v4_s")
		_:
			time_left = Config.f("modes.match_2v2_s") if Game.mode == "2v2" else Config.f("match.duration_s")
	_awaken_clock = 0.0
	_awaken_next_team = _rng.randi() % 2
	hud.set_score(0, 0)
	hud.set_time(time_left)
	_kickoff()
	hud.show_message(Game.t("COMEÇOU!", "KICK OFF!"), Color(0.6, 0.9, 1.0), 1.2)
	Sfx.play("whistle")


func _kickoff() -> void:
	ball.reset_to(Vector3(0.0, Config.f("ball.reset_height"), 0.0))
	ball.set_meta("last_team", -1)
	_kickoff_positions()
	for p: Node in players:
		p.set("controls_enabled", not is_client or p == human)
		p.set("stun_t", 0.0)
	state = State.PLAYING
	if player != null:
		rig.snap()


func _process(delta: float) -> void:
	if player != null:
		hud.update_bars(player.stamina_ratio(), player.charge, player.charging)
	_update_zones(delta)

	if Input.is_action_just_pressed("toggle_quality"):
		var next: int = (Config.quality_level + 1) % 3
		Config.apply_quality(next, get_viewport(), sun)
		hud.show_message(["QUALIDADE: BAIXA", "QUALIDADE: MÉDIA", "QUALIDADE: ALTA"][next], Color.WHITE, 1.0)
	if Input.is_action_just_pressed("pause") and state != State.FINISHED:
		_toggle_pause()

	match state:
		State.PLAYING:
			if not is_client:
				time_left -= delta
				_tick_awakening(delta)
			hud.set_time(time_left)
			if Input.is_action_just_pressed("reset_ball") and not online:
				ball.reset_to(Vector3(0.0, Config.f("ball.reset_height"), 0.0))
				ball.set_meta("last_team", -1)
			if Game.mode == "training" and Input.is_action_just_pressed("awaken_test") and human != null:
				_awaken(human)
			if time_left <= 0.0 and not is_client:
				_finish_match()
		State.FINISHED:
			if Input.is_action_just_pressed("reset_ball") and not online and _result_layer == null:
				_new_match()
		_:
			pass


# --------------------------------------------------------------- Despertar
func _tick_awakening(delta: float) -> void:
	_awaken_clock += delta
	if _awaken_clock >= Config.f("awakening.interval_s"):
		_awaken_clock = 0.0
		var pool: Array = []
		for p: Node in players:
			if int(p.get("team")) == _awaken_next_team and not bool(p.get("awakened")):
				pool.append(p)
		_awaken_next_team = 1 - _awaken_next_team
		if pool.is_empty():
			return
		_awaken(pool[_rng.randi() % pool.size()])


func _awaken(p: Node) -> void:
	if p.get("awake_ids").is_empty():
		return
	p.call("awaken", Config.f("awakening.duration_s"))
	var col: Color = p.call("_aura_color")
	var is_human_p: bool = p == human
	fx.call("cutscene", "%s — %s" % [String(p.get("display_name")).to_upper(), Game.t("DESPERTAR!", "AWAKENING!")], "gogogo", col, is_human_p or Game.mode != "training")
	fx.call("shockwave", self, (p as Node3D).global_position, col, 6.0)
	Sfx.play("awaken")
	if is_human_p:
		Game.report_event("awaken", String(p.get("char_id")))
		hud.toast(Game.t("Você despertou!", "You awakened!"), Color(1.0, 0.85, 0.3))
	else:
		hud.toast(Game.t("%s despertou!" % String(p.get("display_name")), "%s awakened!" % String(p.get("display_name"))), col)
	if net != null:
		net.call("send_event", {"t": "awaken", "team": p.get("team"), "idx": p.get("index")})


func on_flow(p: Node) -> void:
	fx.call("ring", self, (p as Node3D).global_position, Color(0.75, 0.45, 1.0), 6.0, 0.6)
	if p == human:
		hud.toast(Game.t("FLOW!", "FLOW!"), Color(0.8, 0.5, 1.0))
		Sfx.play("buff")


func on_skill(p: Node, _sk: Dictionary) -> void:
	if p == human:
		rig.shake(0.1)


# ------------------------------------------------------------------ zonas
func add_zone(pos: Vector3, radius: float, duration: float, slow: float, team: int, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = fx.call("tex", "vfx/ring.png")
	mat.albedo_color = Color(color.r, color.g, color.b, 0.7)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = mat
	mi.mesh = q
	mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	mi.position = Vector3(pos.x, 0.1, pos.z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_zones.append({"pos": pos, "r": radius, "t": duration, "slow": slow, "team": team, "node": mi})


func _update_zones(delta: float) -> void:
	for z: Dictionary in _zones.duplicate():
		z["t"] = float(z["t"]) - delta
		(z["node"] as Node3D).rotation.z += delta * 0.8
		if float(z["t"]) <= 0.0:
			(z["node"] as Node).queue_free()
			_zones.erase(z)


func zone_factor(p: Node) -> float:
	var f: float = 1.0
	for z: Dictionary in _zones:
		if int(z["team"]) == int(p.get("team")):
			continue
		var d: Vector3 = (p as Node3D).global_position - (z["pos"] as Vector3)
		d.y = 0.0
		if d.length() < float(z["r"]):
			f = minf(f, float(z["slow"]))
	return f


# ----------------------------------------------------------------- passes
func best_pass_mate(p: Node) -> Node:
	var best: Node = null
	var best_score: float = -1.0e9
	var facing: Vector3 = p.get("facing")
	var pos: Vector3 = (p as Node3D).global_position
	var s: float = float(p.get("side"))
	for n: Node in players:
		if n == p or int(n.get("team")) != int(p.get("team")):
			continue
		var d: Vector3 = (n as Node3D).global_position - pos
		d.y = 0.0
		var dist: float = d.length()
		if dist < 2.0 or dist > 34.0:
			continue
		var ang: float = rad_to_deg(facing.angle_to(d))
		if ang > 55.0:
			continue
		var sc: float = -ang - dist * 0.4 + d.x * s * 0.3
		if sc > best_score:
			best_score = sc
			best = n
	return best


func best_pass_target(p: Node) -> Variant:
	var mate: Node = best_pass_mate(p)
	if mate == null:
		return null
	var m3: Node3D = mate as Node3D
	return m3.global_position + Vector3(m3.get("velocity")) * 0.45


# ------------------------------------------------------------ eventos
func _on_player_kick(_kind: String, _power: float, p: Node) -> void:
	var t: int = int(p.get("team"))
	var prev: Dictionary = _last_kick[t]
	_last_kick[t] = {"idx": p.get("index"), "prev_idx": prev.get("idx", -1), "time": Time.get_ticks_msec(), "prev_time": prev.get("time", 0)}
	if _kind == "shot" and _power > Config.f("kick.max_power") * 0.8:
		rig.shake(0.15)
	var snd: String = "kick_light"
	if _kind == "shot":
		snd = "kick_strong" if _power > Config.f("kick.max_power") * 0.7 else "kick_medium"
	elif _kind == "pass" or _kind == "lob":
		snd = "pass"
	Sfx.play(snd, -3.0 if p != human else 0.0)


func _on_stole(p: Node) -> void:
	Sfx.play("tackle", -2.0)
	if p == human:
		_stats["steals"] = int(_stats["steals"]) + 1
		Game.report_event("steal", String(p.get("char_id")))
		p.call("add_flow", Config.f("flow.per_steal"))
		hud.toast(Game.t("Bola roubada!", "Steal!"), Color(0.5, 1.0, 0.7))


func _on_skill_used(p: Node, sid: String) -> void:
	if p == human:
		Game.report_event("skill_use:" + sid, String(p.get("char_id")))


func _on_quest_completed(q: Dictionary) -> void:
	var unlock: String = String(q.get("unlock", ""))
	hud.toast(Game.t("MISSÃO COMPLETA! Desbloqueou: ", "QUEST COMPLETE! Unlocked: ") + Game.skill_name(unlock), Color(1.0, 0.9, 0.3))
	Sfx.play("unlock")
	Game.save_game()


func _on_goal_scored(scoring_team: int) -> void:
	if state != State.PLAYING or is_client:
		return
	state = State.GOAL
	score[scoring_team] += 1
	hud.set_score(score[0], score[1])
	hud.show_message(Game.t("GOOOL!", "GOAAAL!"), Color(1.0, 0.85, 0.25), Config.f("match.goal_celebration_s"))
	rig.shake(0.6)
	Sfx.play("goal_horn")
	Sfx.play("crowd_cheer", -2.0)
	Sfx.play("net")
	fx.call("flash", Color(1, 1, 1), 0.5, 0.6)
	fx.call("burst", self, ball.global_position, Color(1.0, 0.85, 0.3), 60, 12.0, 0.9, 1.2, "star")
	var scorer_team: int = int(ball.get_meta("last_team", -1))
	var scorer_char: String = String(ball.get_meta("last_char", ""))
	var scorer_idx: int = int(ball.get_meta("last_player", -1))
	if human != null and scoring_team == int(human.get("team")):
		var mine: bool = scorer_team == scoring_team and scorer_idx == int(human.get("index"))
		if mine:
			_stats["goals"] = int(_stats["goals"]) + 1
			var cid: String = String(human.get("char_id"))
			Game.report_event("goal", cid)
			human.call("add_flow", Config.f("flow.per_goal"))
			var sk: String = String(ball.get_meta("last_skill", ""))
			if sk != "":
				Game.report_event("skill_goal:" + sk, cid)
				fx.call("ono", String(Game.skill(sk).get("ono", "don")), Vector2.ZERO, Color(1.0, 0.9, 0.4))
			if bool(ball.get_meta("last_awake", false)):
				Game.report_event("awaken_goal", cid)
			Game.add_coins(int(Config.f("modes.goal_coins")))
		elif scorer_team == scoring_team and scorer_char != "":
			var lk: Dictionary = _last_kick[scoring_team]
			if int(lk.get("prev_idx", -1)) == int(human.get("index")) and Time.get_ticks_msec() - int(lk.get("prev_time", 0)) < 8000:
				_stats["assists"] = int(_stats["assists"]) + 1
				Game.report_event("assist", String(human.get("char_id")))
				hud.toast(Game.t("Assistência!", "Assist!"), Color(0.6, 0.9, 1.0))
	if net != null:
		net.call("send_event", {"t": "goal", "team": scoring_team, "score": score})
	_goal_sequence()


func _goal_sequence() -> void:
	_goal_token += 1
	var token: int = _goal_token
	if not online:
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
		if net != null:
			net.call("send_event", {"t": "kickoff"})
		Sfx.play("whistle", -4.0)


func _finish_match() -> void:
	if state == State.FINISHED:
		return
	state = State.FINISHED
	for p: Node in players:
		p.set("controls_enabled", false)
	hud.set_time(0.0)
	Sfx.play("whistle_long")
	Sfx.crowd(false)
	var my: int = score[0]
	var other: int = score[1]
	var won: bool = my > other
	var draw: bool = my == other
	var coins: int = int(Config.f("modes.win_coins")) if won else (int(Config.f("modes.draw_coins")) if draw else int(Config.f("modes.loss_coins")))
	var xp: int = int(Config.f("modes.win_xp")) if won else int(Config.f("modes.loss_xp"))
	if Game.mode == "training":
		coins = 0
		xp = 20
	if won and Game.mode != "training" and human != null:
		Game.report_event("win", String(human.get("char_id")))
	Game.add_coins(coins)
	Game.xp += xp
	Game.save_game()
	Game.last_result = {"score": score.duplicate(), "won": won, "draw": draw, "coins": coins, "xp": xp, "stats": _stats.duplicate(), "mode": Game.mode}
	hud.show_message(Game.t("FIM DE JOGO  %d x %d", "FULL TIME  %d x %d") % [score[0], score[1]], Color(1.0, 0.9, 0.4), 0.0)
	if net != null:
		net.call("send_event", {"t": "end", "score": score})
	get_tree().create_timer(2.2).timeout.connect(_show_results)


func _show_results() -> void:
	if _result_layer != null:
		return
	_result_layer = (load("res://scripts/ui/results_overlay.gd") as GDScript).new()
	add_child(_result_layer)
	_result_layer.call("show_result", self)


# ------------------------------------------------------------------- pausa
func _toggle_pause() -> void:
	if online or state == State.FINISHED:
		return
	if _paused_layer != null:
		_paused_layer.queue_free()
		_paused_layer = null
		get_tree().paused = false
		return
	get_tree().paused = true
	_paused_layer = (load("res://scripts/ui/pause_overlay.gd") as GDScript).new()
	_paused_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_paused_layer)
	_paused_layer.connect("resume", _toggle_pause)
	_paused_layer.connect("leave", _leave_match)


func _leave_match() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	fx.call("clear_all")
	Sfx.crowd(false)
	if net != null:
		net.call("stop")
	Game.save_game()
	get_tree().change_scene_to_file("res://scenes/menu/Main.tscn")


func leave_to_menu() -> void:
	_leave_match()


func rematch() -> void:
	if _result_layer != null:
		_result_layer.queue_free()
		_result_layer = null
	Sfx.crowd(true)
	_new_match()
