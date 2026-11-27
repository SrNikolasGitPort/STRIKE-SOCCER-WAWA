extends RefCounted
## Executor genérico de skills dirigido por dados (data/skills/skills.json).
## Cada skill tem um `effect` (shot, pass, dash, evade, steal, shockwave, buff, zone,
## block, vision, mark, rest, copy, dashshot, multishot) e `params`.
## Tudo é chamado no host/offline; no online só o servidor executa.


static func _team_players(arena: Node, team: int, same: bool) -> Array:
	var out: Array = []
	for n: Node in arena.get_tree().get_nodes_in_group("players"):
		var t: int = int(n.get("team"))
		if (t == team) == same:
			out.append(n)
	return out


static func _color(p: Node) -> Color:
	return p.call("_aura_color")


static func _fx(arena: Node) -> Node:
	return arena.get("fx")


## Executa a skill. Retorna false quando não pôde ser usada (ex.: chute sem bola).
static func execute(p: Node, sk: Dictionary, arena: Node) -> bool:
	var effect: String = String(sk.get("effect", ""))
	var params: Dictionary = sk.get("params", {})
	var sid: String = String(sk.get("id", ""))
	p.set("last_skill", sid)
	var ok: bool = true
	match effect:
		"shot":
			ok = fire_shot(p, params, arena)
		"multishot":
			ok = _multishot(p, params, arena)
		"dashshot":
			ok = _dashshot(p, params)
		"pass":
			ok = _pass(p, params, arena)
		"dash":
			_dash(p, params, arena)
		"evade":
			_evade(p, params)
		"steal":
			_steal(p, params, arena)
		"shockwave":
			_shockwave(p, params, arena)
		"buff":
			_buff(p, params, arena)
		"zone":
			_zone(p, params, arena)
		"block":
			_block(p, params, arena)
		"vision":
			_vision(p, params, arena)
		"mark":
			_mark(p, params, arena)
		"rest":
			p.set("stamina", minf(float(p.get("stamina")) + float(params.get("amount", 40.0)), Config.f("player.stamina_max")))
		"copy":
			ok = _copy(p, params, arena)
		_:
			ok = false
	if ok:
		_cutscene(p, sk, arena)
		if arena != null and arena.has_method("on_skill"):
			arena.call("on_skill", p, sk)
	return ok


static func _cutscene(p: Node, sk: Dictionary, arena: Node) -> void:
	if arena == null:
		return
	var fx: Node = _fx(arena)
	if fx == null:
		return
	var human: bool = bool(p.get("is_human"))
	var big: bool = String(sk.get("cat", "")) != "normal"
	var name_txt: String = Game.skill_name(String(sk.get("id", "")))
	var jp: String = String(sk.get("jp", ""))
	if jp != "":
		name_txt += "\n" + jp
	var col: Color = _color(p)
	# Só o jogador humano (e skills de Despertar de qualquer um) ganham a cutscene completa.
	if human or big:
		fx.call("cutscene", String(p.get("display_name")).to_upper() + " — " + name_txt, String(sk.get("ono", "don")), col, big and human)
	else:
		fx.call("ono", String(sk.get("ono", "don")), Vector2.ZERO, col)
	fx.call("burst", arena, (p as Node3D).global_position + Vector3(0, 1.0, 0), col, 22, 6.0, 0.7, 0.6, "star")
	Sfx.play("awaken" if big and human else "skill_cast", -3.0)


# ---------------------------------------------------------------- chutes
static func fire_shot(p: Node, params: Dictionary, arena: Node) -> bool:
	if not p.call("ball_in_range", Config.f("skills.shot_range") - Config.f("kick.range")):
		return false
	var ball: RigidBody3D = p.get("ball")
	if (ball.global_position - (p as Node3D).global_position).length() > Config.f("kick.range") * 0.9:
		p.call("snap_ball")
	var pos: Vector3 = (p as Node3D).global_position
	var goal: Vector3 = p.get("attack_goal")
	var aim: Vector3 = p.call("aim_direction")
	var to_goal: Vector3 = goal + Vector3(0.0, 0.0, randf_range(-2.8, 2.8)) - pos
	to_goal.y = 0.0
	to_goal = to_goal.normalized()
	var blend: float = float(params.get("aim", 0.8))
	if bool(params.get("goal_aim", false)):
		aim = to_goal
	else:
		aim = aim.slerp(to_goal, blend * 0.6).normalized()
	var power: float = lerpf(Config.f("kick.min_power"), Config.f("kick.max_power"), float(params.get("power", 0.8)))
	power *= float(p.call("power_total"))
	var loft: float = float(params.get("loft", Config.f("kick.shot_loft")))
	if bool(params.get("air", false)):
		loft = maxf(loft, 0.45)
	var curve: float = float(params.get("curve", 0.0)) * Config.f("kick.curve_spin") * float(p.get("side"))
	p.call("do_kick", Vector3(aim.x, loft, aim.z), power, curve, "skill")
	p.call("kick_anim_now")
	Sfx.play("kick_strong", -2.0)
	if arena != null:
		var fx: Node = _fx(arena)
		if fx != null:
			fx.call("attach_trail", ball, _color(p), 1.6)
			fx.call("burst", arena, ball.global_position, _color(p), 18, 7.0, 0.6, 0.5, "glow")
	return true


static func _multishot(p: Node, params: Dictionary, arena: Node) -> bool:
	if not fire_shot(p, params, arena):
		return false
	var shots: int = int(params.get("shots", 3))
	for i: int in range(1, shots):
		p.get_tree().create_timer(0.16 * float(i)).timeout.connect(_follow_shot.bind(p, params, arena))
	return true


static func _follow_shot(p: Node, params: Dictionary, arena: Node) -> void:
	if is_instance_valid(p) and p.call("ball_in_range", 2.0):
		p.call("clear_kick_cd")
		fire_shot(p, params, arena)


static func _dashshot(p: Node, params: Dictionary) -> bool:
	var goal: Vector3 = p.get("attack_goal")
	var dir: Vector3 = goal - (p as Node3D).global_position
	p.call("start_dash", dir, float(params.get("speed", 1.6)), float(params.get("run", 0.5)))
	p.set("dash_shot", {"power": params.get("power", 1.2), "loft": params.get("loft", 0.12), "aim": 1.0, "goal_aim": true})
	return true


static func _pass(p: Node, params: Dictionary, arena: Node) -> bool:
	if not p.call("ball_in_range", 0.8):
		return false
	var target: Variant = arena.call("best_pass_target", p) if arena != null and arena.has_method("best_pass_target") else null
	var dir: Vector3 = p.call("aim_direction")
	var mate: Node = null
	if target is Vector3:
		dir = ((target as Vector3) - (p as Node3D).global_position)
		dir.y = 0.0
		dir = dir.normalized()
		mate = arena.call("best_pass_mate", p)
	var speed: float = Config.f("kick.pass_speed") * float(params.get("speed", 1.1)) * (0.9 + float(p.call("stat", "passe")) / 500.0)
	var curve: float = float(params.get("curve", 0.0)) * Config.f("kick.curve_spin") * float(p.get("side")) * 0.5
	p.call("do_kick", Vector3(dir.x, float(params.get("loft", 0.04)), dir.z), speed, curve, "skill")
	p.call("kick_anim_now")
	Sfx.play("pass", -1.0)
	if mate != null and params.has("target_buff"):
		mate.call("add_buff", "shot", float(params["target_buff"]), 4.0)
		mate.call("add_buff", "speed", 1.12, 4.0)
	return true


# ------------------------------------------------------------ movimento
static func _dash(p: Node, params: Dictionary, arena: Node) -> void:
	var wish: Vector3 = p.get("in_wish")
	var dir: Vector3 = wish if wish.length() > 0.2 else p.get("facing")
	p.call("start_dash", dir, float(params.get("speed", 1.3)), float(params.get("duration", 1.5)))
	if params.has("magnet"):
		p.call("add_buff", "magnet", float(params["magnet"]), float(params.get("duration", 1.5)) + 0.5)
	if params.has("push") and arena != null:
		for o: Node in _team_players(arena, int(p.get("team")), false):
			if (o as Node3D).global_position.distance_to((p as Node3D).global_position) < 3.0:
				o.call("stun", 0.3)
				o.set("velocity", dir.normalized() * float(params["push"]) * 0.5)
	Sfx.play("dash", -2.0)


static func _evade(p: Node, params: Dictionary) -> void:
	var wish: Vector3 = p.get("in_wish")
	var dir: Vector3 = wish if wish.length() > 0.2 else p.get("facing")
	var dur: float = float(params.get("duration", 1.2))
	p.call("start_dash", dir, float(params.get("speed", 1.4)), dur)
	p.set("immune_t", dur + 0.2)
	p.call("add_buff", "magnet", float(params.get("magnet", 0.6)), dur + 0.4)
	Sfx.play("whoosh", -2.0)


static func _steal(p: Node, params: Dictionary, arena: Node) -> void:
	var radius: float = float(params.get("radius", 3.5))
	var ball: RigidBody3D = p.get("ball")
	var pos: Vector3 = (p as Node3D).global_position
	if ball.global_position.distance_to(pos) < radius and int(ball.get_meta("last_team", -1)) != int(p.get("team")):
		var dir: Vector3 = pos - ball.global_position
		dir.y = 0.0
		ball.linear_velocity = dir.normalized() * (6.0 + 6.0 * float(params.get("pull", 0.8)))
		ball.set_meta("last_team", int(p.get("team")))
		ball.set_meta("last_char", String(p.get("char_id")))
		p.emit_signal("stole_ball", p)
		for o: Node in _team_players(arena, int(p.get("team")), false):
			if (o as Node3D).global_position.distance_to(pos) < radius:
				o.call("stun", 0.35)
	p.call("add_buff", "speed", float(params.get("speed", 1.25)), 2.5)
	p.call("add_buff", "magnet", 0.5, 2.5)
	Sfx.play("steal", -2.0)


static func _shockwave(p: Node, params: Dictionary, arena: Node) -> void:
	var radius: float = float(params.get("radius", 3.0))
	var pos: Vector3 = (p as Node3D).global_position
	for o: Node in _team_players(arena, int(p.get("team")), false):
		var d: Vector3 = (o as Node3D).global_position - pos
		d.y = 0.0
		if d.length() < radius:
			o.call("stun", float(params.get("stun", 0.5)))
			o.set("velocity", d.normalized() * float(params.get("knock", 3.0)) * 3.0)
	var ball: RigidBody3D = p.get("ball")
	var bd: Vector3 = ball.global_position - pos
	bd.y = 0.0
	if bd.length() < radius * 0.8 and int(ball.get_meta("last_team", -1)) != int(p.get("team")):
		ball.linear_velocity = bd.normalized() * 10.0
	var fx: Node = _fx(arena)
	if fx != null:
		fx.call("shockwave", arena, pos, _color(p), radius)
	Sfx.play("shockwave")


static func _buff(p: Node, params: Dictionary, arena: Node) -> void:
	var dur: float = float(params.get("duration", 5.0))
	var targets: Array = [p]
	if params.has("allies"):
		for a: Node in _team_players(arena, int(p.get("team")), true):
			if a != p and (a as Node3D).global_position.distance_to((p as Node3D).global_position) < float(params["allies"]):
				targets.append(a)
	for t: Node in targets:
		if params.has("speed"):
			t.call("add_buff", "speed", float(params["speed"]), dur)
		if params.has("shot"):
			t.call("add_buff", "shot", float(params["shot"]), dur)
		if params.has("magnet"):
			t.call("add_buff", "magnet", float(params["magnet"]), dur)
		if bool(params.get("shield", false)):
			t.set("shield_t", dur)
	Sfx.play("buff", -2.0)
	var fx: Node = _fx(arena)
	if fx != null:
		fx.call("ring", arena, (p as Node3D).global_position, _color(p), 5.0, 0.6)


static func _zone(p: Node, params: Dictionary, arena: Node) -> void:
	if arena != null and arena.has_method("add_zone"):
		arena.call("add_zone", (p as Node3D).global_position, float(params.get("radius", 6.0)), float(params.get("duration", 4.0)), float(params.get("slow", 0.5)), int(p.get("team")), _color(p))
	Sfx.play("stun", -2.0)


static func _block(p: Node, params: Dictionary, arena: Node) -> void:
	p.set("block_t", float(params.get("duration", 1.2)))
	p.set("block_r", float(params.get("radius", 3.0)))
	var fx: Node = _fx(arena)
	if fx != null:
		fx.call("ring", arena, (p as Node3D).global_position, _color(p), float(params.get("radius", 3.0)) * 2.0, 0.5)
	Sfx.play("buff", -2.0)


static func _vision(p: Node, params: Dictionary, arena: Node) -> void:
	p.set("vision_t", float(params.get("duration", 6.0)))
	p.set("vision_assist", float(params.get("assist", 0.9)))
	var slow: float = float(params.get("slow", 0.7))
	for o: Node in _team_players(arena, int(p.get("team")), false):
		o.call("add_buff", "debuff_speed", lerpf(1.0, slow, 0.5), float(params.get("duration", 6.0)) * 0.6)
	Sfx.play("vision")


static func _mark(p: Node, params: Dictionary, arena: Node) -> void:
	var radius: float = float(params.get("radius", 10.0))
	var dur: float = float(params.get("duration", 4.0))
	var pos: Vector3 = (p as Node3D).global_position
	var best: Node = null
	var best_d: float = radius
	for o: Node in _team_players(arena, int(p.get("team")), false):
		var d: float = (o as Node3D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = o
	if best != null:
		best.call("add_buff", "debuff_speed", float(params.get("speed_debuff", 0.75)), dur)
		best.call("add_buff", "debuff_power", float(params.get("power_debuff", 0.75)), dur)
		if bool(params.get("silence", false)):
			best.set("silence_t", dur)
		var fx: Node = _fx(arena)
		if fx != null:
			fx.call("burst", arena, (best as Node3D).global_position + Vector3(0, 1.0, 0), Color(1.0, 0.3, 0.3), 16, 3.0, 0.6, 0.8, "ring")
	Sfx.play("stun")


static func _copy(p: Node, params: Dictionary, arena: Node) -> bool:
	var pool: Array = []
	for o: Node in _team_players(arena, int(p.get("team")), false):
		for sid: Variant in o.get("skill_ids"):
			var s: Dictionary = Game.skill(String(sid))
			if String(s.get("effect", "")) in ["shot", "dash", "evade", "buff"]:
				pool.append(s)
	if pool.is_empty():
		return false
	var pick: Dictionary = pool[randi() % pool.size()]
	p.set("power_scale_once", float(params.get("fraction", 0.9)))
	var ok: bool = execute(p, pick, arena)
	p.set("power_scale_once", 1.0)
	Sfx.play("copy")
	return ok
