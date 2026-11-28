extends Node
## IA simples de futebol: carrega a bola e chuta/passa, persegue a bola quando é o
## mais próximo, mantém formação por função (atacante/apoio/zagueiro) e usa skills.

var p: Node3D = null
var arena: Node = null
var role: String = "attacker"
var difficulty: float = 0.7             # 0..1

var _think: float = 0.0
var _shoot_hold: float = 0.0
var _shoot_target: float = 0.5
var _skill_t: float = 2.0
var _wander: Vector3 = Vector3.ZERO
var _act_t: float = 0.0
var _dive_cd: float = 0.0
var _hold_t: float = 0.0


func _physics_process(delta: float) -> void:
	if p == null or arena == null or not bool(p.get("controls_enabled")) or bool(p.get("puppet")):
		return
	if role == "keeper":
		_keeper(delta)
		return
	_think -= delta
	_skill_t -= delta
	_act_t -= delta
	if _shoot_hold > 0.0:
		_shoot_hold -= delta
		if _shoot_hold <= 0.0:
			p.set("in_shoot_held", false)
	if _think > 0.0:
		return
	_think = Config.f("ai.reaction_s") * lerpf(1.6, 0.7, difficulty) + randf() * 0.05
	_decide()


func _field_half() -> Vector2:
	return Vector2(Config.f("field.length") / 2.0 - 1.5, Config.f("field.width") / 2.0 - 1.5)


func _closest_teammate_to_ball() -> Node:
	var best: Node = null
	var best_d: float = 1.0e9
	var ball: Node3D = p.get("ball")
	for n: Node in p.get_tree().get_nodes_in_group("players"):
		if int(n.get("team")) != int(p.get("team")) or str(n.get("role")) == "keeper":
			continue
		var d: float = (n as Node3D).global_position.distance_to(ball.global_position)
		if str(n.get("role")) == "defender":
			d += 8.0
		if d < best_d:
			best_d = d
			best = n
	return best


func _go(target: Vector3, sprint: bool) -> void:
	var d: Vector3 = target - p.global_position
	d.y = 0.0
	if d.length() < 0.6:
		p.set("in_wish", Vector3.ZERO)
	else:
		p.set("in_wish", d.normalized())
	p.set("in_sprint", sprint and float(p.call("stamina_ratio")) > 0.25)


func _nearest_opponent() -> Node3D:
	var best: Node3D = null
	var best_d: float = 1.0e9
	for n: Node in p.get_tree().get_nodes_in_group("players"):
		if int(n.get("team")) == int(p.get("team")):
			continue
		var d: float = (n as Node3D).global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = n as Node3D
	return best


func _decide() -> void:
	var ball: Node3D = p.get("ball")
	var side: float = float(p.get("side"))
	var goal: Vector3 = p.get("attack_goal")
	var own_goal: Vector3 = p.get("own_goal")
	var half: Vector2 = _field_half()
	p.set("in_pass", false)
	if bool(p.call("awaken_ready")) and randf() < 0.25:
		p.call("try_awaken")

	if bool(p.call("has_ball")):
		var opp: Node3D = _nearest_opponent()
		var to_goal: Vector3 = goal - p.global_position
		to_goal.y = 0.0
		var dir: Vector3 = to_goal.normalized()
		if opp != null:
			var away: Vector3 = p.global_position - opp.global_position
			away.y = 0.0
			if away.length() < 3.5:
				var lateral: Vector3 = Vector3(0.0, 0.0, signf(away.z + 0.01))
				dir = (dir + lateral * 0.9).normalized()
		_go(p.global_position + dir * 5.0, true)
		var dist: float = to_goal.length()
		if dist < Config.f("ai.shoot_range") and _shoot_hold <= 0.0 and randf() < 0.35 + difficulty * 0.4:
			p.set("in_wish", dir * 0.3)
			p.set("facing", dir)
			p.set("in_shoot_held", true)
			p.set("in_elev", 0.0 if randf() > 0.25 else randf_range(0.2, 0.45))
			_shoot_hold = randf_range(0.35, 0.8)
		elif opp != null and opp.global_position.distance_to(p.global_position) < 2.6 and randf() < Config.f("ai.pass_chance"):
			p.set("in_pass", true)
		if opp != null and opp.global_position.distance_to(p.global_position) < 2.8 and _act_t <= 0.0 and randf() < 0.3 * difficulty:
			_act_t = 1.6
			p.set("in_dribble", true)
		_maybe_skill(dist, true)
		return

	var chaser: Node = _closest_teammate_to_ball()
	if chaser == p or ball.global_position.distance_to(p.global_position) < 4.0:
		var lead: Vector3 = ball.global_position + ball.linear_velocity * 0.25
		_go(lead, true)
		if _act_t <= 0.0:
			var holder: Node3D = _nearest_opponent()
			if holder != null and holder.call("has_ball") and holder.global_position.distance_to(p.global_position) < 2.6 and randf() < 0.45 * difficulty:
				_act_t = 2.2
				p.set("in_tackle", true)
		_maybe_skill(0.0, false)
		return

	# formação por função
	var depth: float = Config.f("ai.formation_depth")
	var width: float = Config.f("ai.formation_width")
	var bx: float = ball.global_position.x
	var target: Vector3 = Vector3.ZERO
	match role:
		"attacker":
			target = Vector3(bx + side * depth, 0.0, ball.global_position.z * -0.5 + width * 0.5 * signf(float(p.get("index")) - 0.5))
		"support":
			target = Vector3(bx - side * 1.0, 0.0, ball.global_position.z + width * 0.6 * (1.0 if int(p.get("index")) % 2 == 0 else -1.0))
		_:
			target = Vector3(lerpf(own_goal.x, bx, 0.45) + side * 4.0, 0.0, ball.global_position.z * 0.4)
	target.x = clampf(target.x, -half.x, half.x)
	target.z = clampf(target.z, -half.y, half.y)
	_go(target, false)


func _maybe_skill(dist_goal: float, carrying: bool) -> void:
	if _skill_t > 0.0:
		return
	_skill_t = randf_range(1.2, 3.2)
	if randf() > Config.f("ai.skill_chance") * (0.5 + difficulty):
		return
	var awakened: bool = bool(p.get("awakened"))
	var slots: Array = [0, 1, 2]
	if awakened:
		slots.append_array([3, 4, 5])
	slots.shuffle()
	for s: int in slots:
		var sid: String = String(p.call("skill_at", s))
		if sid == "" or float(p.call("cooldown_left", s)) > 0.0:
			continue
		var eff: String = String(Game.skill(sid).get("effect", ""))
		var useful: bool = false
		match eff:
			"shot", "multishot", "dashshot":
				useful = carrying and dist_goal < 24.0 and bool(p.call("ball_in_range", 1.0))
			"pass":
				useful = carrying
			"steal", "shockwave", "block", "zone", "mark":
				useful = not carrying
			_:
				useful = true
		if useful:
			var arr: Array[bool] = p.get("in_skill")
			arr[s] = true
			return


# ----------------------------------------------------------------- goleiro
func _keeper(delta: float) -> void:
	_dive_cd = maxf(_dive_cd - delta, 0.0)
	var ball: RigidBody3D = p.get("ball")
	var own: Vector3 = p.get("own_goal")
	var inward: float = float(p.get("side"))          # direção do gol próprio para o campo
	var gl_x: float = own.x + inward * Config.f("keeper.line_offset")
	var bpos: Vector3 = ball.global_position
	var bv: Vector3 = ball.linear_velocity
	var half_w: float = Config.f("field.goal_width") / 2.0
	var pp: Vector3 = p.global_position
	var team: int = int(p.get("team"))

	# segurando a bola: solta depois de um tempo, passando ou chutando para frente
	if _hold_t > 0.0:
		_hold_t -= delta
		if float(p.get("stun_t")) > 0.0:
			_hold_t = 0.0
			return
		var f: Vector3 = p.get("facing")
		ball.global_position = pp + f * 0.7 + Vector3(0.0, 0.2, 0.0)
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO
		ball.set_meta("last_team", team)
		p.set("in_wish", Vector3.ZERO)
		if _hold_t <= 0.0:
			_release()
		return

	var thr: bool = false
	var target: Vector3 = Vector3.ZERO
	var t_hit: float = 9.0
	var y_hit: float = 0.0
	if bv.x * inward < -3.0 and not _ball_is_ours(ball, team):
		var tt: float = (gl_x - bpos.x) / bv.x
		if tt > 0.0 and tt < 1.8:
			var zc: float = bpos.z + bv.z * tt
			y_hit = bpos.y + bv.y * tt - 4.9 * tt * tt
			if absf(zc) < half_w + 1.2 and y_hit < Config.f("field.goal_height") + 0.6:
				thr = true
				t_hit = tt
				target = Vector3(gl_x, 0.0, clampf(zc, -half_w + 0.4, half_w - 0.4))
	if not thr:
		var dist_goal: float = absf(bpos.x - own.x)
		var slow: bool = bv.length() < 6.5
		var near_opp: bool = false
		for n: Node in p.get_tree().get_nodes_in_group("players"):
			if int(n.get("team")) != team and (n as Node3D).global_position.distance_to(bpos) < 3.0:
				near_opp = true
		if dist_goal < Config.f("keeper.max_out") + 3.0 and slow and (not near_opp or dist_goal < 4.0) and not _ball_is_ours(ball, team):
			target = Vector3(bpos.x, 0.0, bpos.z)
		else:
			var step: float = clampf(dist_goal * 0.1, 0.0, 2.5)
			target = Vector3(gl_x + inward * step, 0.0, clampf(bpos.z * 0.4, -half_w + 0.8, half_w - 0.8))
	var d: Vector3 = target - pp
	d.y = 0.0
	p.set("in_wish", d.normalized() if d.length() > 0.5 else Vector3.ZERO)
	p.set("in_sprint", thr or d.length() > 4.0)

	# mergulho (lateral + pulo) quando o chute está chegando
	if thr and t_hit < 0.5 and _dive_cd <= 0.0:
		var dz: float = target.z - pp.z
		if absf(dz) > 0.9:
			_dive_cd = Config.f("keeper.dive_cd_s")
			p.call("start_dash", Vector3(0.0, 0.0, signf(dz)), Config.f("keeper.dive_speed"), 0.45)
			if y_hit > 1.1:
				p.set("in_jump", true)
			p.set("block_t", 0.5)
			p.set("block_r", 1.9)
	elif thr and y_hit > 1.3 and t_hit < 0.5:
		p.set("in_jump", true)

	# defesa: segura ou espalma
	var to_ball: Vector3 = bpos - pp
	var flat: float = Vector2(to_ball.x, to_ball.z).length()
	if flat < Config.f("keeper.reach") and bpos.y < 2.6 and not _ball_is_ours(ball, team) and float(p.get("stun_t")) <= 0.0:
		var sp: float = bv.length()
		if sp < Config.f("keeper.catch_speed") and randf() < 0.82:
			_hold_t = Config.f("keeper.hold_s")
			var fx: Node = arena.get("fx")
			if fx != null:
				fx.call("ring", arena, pp, Color(1.0, 0.9, 0.3), 3.0, 0.4)
			Sfx.play("impact_1", -6.0)
			p.set("facing", Vector3(inward, 0.0, 0.0))
		elif sp >= 3.0:
			var side_dir: Vector3 = Vector3(0.0, 0.0, signf(to_ball.z + 0.001))
			ball.linear_velocity = Vector3(inward * sp * 0.35, 3.0, 0.0) + side_dir * 6.0
			ball.set_meta("last_team", team)
			Sfx.play("impact_1", -3.0)


func _ball_is_ours(ball: Node, team: int) -> bool:
	return int(ball.get_meta("last_team", -1)) == team and (ball as RigidBody3D).linear_velocity.length() < 12.0


func _release() -> void:
	var ball: RigidBody3D = p.get("ball")
	var inward: float = float(p.get("side"))
	var mate: Node = null
	if arena.has_method("best_pass_mate"):
		mate = arena.call("best_pass_mate", p)
	var dir: Vector3 = Vector3(inward, 0.0, randf_range(-0.4, 0.4))
	var spd: float = Config.f("keeper.clear_speed")
	var loft: float = 0.35
	if mate != null:
		var dd: Vector3 = (mate as Node3D).global_position - p.global_position
		dd.y = 0.0
		dir = dd.normalized()
		spd = clampf(8.0 + dd.length() * 0.5, 11.0, Config.f("keeper.clear_speed"))
		loft = 0.25
	ball.set_meta("last_team", int(p.get("team")))
	p.call("do_kick", Vector3(dir.x, loft, dir.z), spd, 0.0, "pass")
