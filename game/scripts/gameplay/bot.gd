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


func _physics_process(delta: float) -> void:
	if p == null or arena == null or not bool(p.get("controls_enabled")) or bool(p.get("puppet")):
		return
	_think -= delta
	_skill_t -= delta
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
		if int(n.get("team")) != int(p.get("team")):
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
	p.set("in_lob", false)
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
			_shoot_hold = randf_range(0.35, 0.8)
		elif opp != null and opp.global_position.distance_to(p.global_position) < 2.6 and randf() < Config.f("ai.pass_chance"):
			p.set("in_pass", true)
		_maybe_skill(dist, true)
		return

	var chaser: Node = _closest_teammate_to_ball()
	if chaser == p or ball.global_position.distance_to(p.global_position) < 4.0:
		var lead: Vector3 = ball.global_position + ball.linear_velocity * 0.25
		_go(lead, true)
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
