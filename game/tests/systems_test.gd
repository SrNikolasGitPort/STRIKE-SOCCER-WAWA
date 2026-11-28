extends SceneTree
## Teste de sistemas: menus, partida 4v4 com bots, skills, Despertar, missões Nel,
## códigos de sala e dados. Sai com código 1 se algo falhar.

var _failures: int = 0
var G: Node = null
var N: Node = null


func _initialize() -> void:
	_run()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  OK     ", message)
	else:
		print("  FALHOU ", message)
		_failures += 1


func _frames(count: int) -> void:
	for i: int in range(count):
		await process_frame


func _run() -> void:
	await _frames(5)
	G = root.get_node("Game")
	N = root.get_node("Net")
	print("[1] Dados")
	var order: Array = G.char_order()
	_check(order.size() == 30, "30 personagens carregados (%d)" % order.size())
	var bad: int = 0
	for cid: Variant in order:
		var c: Dictionary = G.character(String(cid))
		for sid: Variant in c.get("skills", []) + c.get("awakening", []):
			if G.skill(String(sid)).is_empty():
				bad += 1
	_check(bad == 0, "todas as skills dos personagens existem")
	_check(G.is_unlocked("isagi_nel") and G.is_unlocked("kaiser"), "dev.unlock_all libera tudo (temporário)")
	var cfg: Node = root.get_node("Config")
	var dev: Dictionary = (cfg.get("_gameplay") as Dictionary)["dev"]
	dev["unlock_all"] = 0
	_check(G.is_unlocked("isagi") and not G.is_unlocked("isagi_nel"), "Nel começa bloqueado (sem flag dev)")

	print("[2] Missões Nel")
	var qs: Array = G.quests_for("isagi")
	_check(qs.size() == 3, "Isagi tem 3 missões")
	var first: Dictionary = qs[0]
	G.report_event(String(first["event"]), "isagi", int(first["target"]))
	_check(G.quest_done.has(String(first["id"])), "missão concluída pelo evento")
	_check(G.is_unlocked("isagi_nel"), "Nel liberado após 1ª missão")
	_check(G.awakening_skills("isagi_nel").size() == 1, "1 skill de Despertar Nel liberada")
	dev["unlock_all"] = 1
	_check(G.awakening_skills("isagi_nel").size() == (G.character("isagi_nel").get("awakening", []) as Array).size(), "flag dev libera todas as skills Nel")

	print("[3] Códigos de sala")
	var code: String = N.encode_room("192.168.1.23", 24565)
	var dec: Dictionary = N.decode_room(code)
	_check(code.length() == 11 and String(dec.get("ip", "")) == "192.168.1.23" and int(dec.get("port", 0)) == 24565, "código %s ida e volta" % code)
	_check(N.decode_room("xxxx").is_empty(), "código inválido rejeitado")

	print("[4] Menus")
	var main: Node = (load("res://scenes/menu/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(5)
	for screen: String in ["mode", "settings", "online", "select", "main"]:
		main.call("_go", screen)
		await _frames(5)
	_check(true, "todas as telas de menu abriram sem erro")
	main.queue_free()
	await _frames(3)

	print("[5] Partida 4v4 com bots")
	G.mode = "4v4"
	G.selected_char = "isagi"
	var m: Node = (load("res://scenes/match/Match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await _frames(10)
	var players: Array = m.get("players")
	_check(players.size() == 10, "8 jogadores + 2 goleiros em campo (%d)" % players.size())
	var keepers: int = 0
	for kp: Node in players:
		if str(kp.get("role")) == "keeper":
			keepers += 1
	_check(keepers == 2, "um goleiro bot por time")
	var start_ball: Vector3 = (m.get("ball") as Node3D).global_position
	await _frames(600)
	var moved: int = 0
	for p: Node in players:
		if (p as Node3D).global_position.distance_to(Vector3.ZERO) > 3.0:
			moved += 1
	_check(moved >= 6, "bots se movimentaram (%d/8)" % moved)
	_check((m.get("ball") as Node3D).global_position.distance_to(start_ball) > 0.5 or int(m.get("score")[0]) + int(m.get("score")[1]) > 0, "a bola foi movida pelos bots")

	print("[6] Skills e Despertar")
	var h: Node = m.get("human")
	h.set("controls_enabled", true)
	var ball: RigidBody3D = m.get("ball")
	ball.reset_to((h as Node3D).global_position + Vector3(1.0, 0.4, 0.0))
	await _frames(3)
	h.call("try_skill", 0)
	await _frames(30)
	_check(float(h.call("cooldown_left", 0)) > 0.0, "skill 1 entrou em recarga")
	h.set("flow", 100.0)
	_check(bool(h.call("awaken_ready")), "barra de Fluxo cheia libera o Despertar")
	_check(bool(h.call("try_awaken")), "Despertar ativado pelo jogador")
	await _frames(5)
	_check(bool(h.get("awakened")), "Despertar em andamento")
	_check(not bool(h.call("awaken_ready")), "não dá para despertar duas vezes")
	var used: int = 0
	for slot: int in range(1, 6):
		ball.reset_to((h as Node3D).global_position + Vector3(1.0, 0.4, 0.0))
		await _frames(3)
		if h.call("try_skill", slot):
			used += 1
		await _frames(30)
	_check(used >= 2, "skills normais e de Despertar executaram (%d)" % used)
	await _frames(240)
	Engine.time_scale = 1.0

	print("[7] Todos os efeitos de skill")
	var errors_before: int = _failures
	for sid: Variant in G.char_order():
		var c2: Dictionary = G.character(String(sid))
		for skid: Variant in c2.get("skills", []) + c2.get("awakening", []):
			var sk: Dictionary = G.skill(String(skid))
			ball.reset_to((h as Node3D).global_position + Vector3(1.0, 0.4, 0.0))
			h.set("stamina", 100.0)
			h.set("silence_t", 0.0)
			h.call("clear_kick_cd")
			m.get("players")[0].call("add_buff", "x", 1.0, 0.1)
			(load("res://scripts/gameplay/skills.gd") as GDScript).call("execute", h, sk, m)
	await _frames(30)
	_check(_failures == errors_before, "137 skills executaram sem erro de script")

	print("[7b] Mecânicas novas (pulo, carrinho, drible, passe, predict, Metavisão, perfil)")
	Engine.time_scale = 1.0
	h.set("stun_t", 0.0)
	h.set("fall_t", 0.0)
	h.set("controls_enabled", true)
	await _frames(60)
	var y0: float = (h as Node3D).global_position.y
	h.set("in_jump", true)
	var ymax: float = y0
	for _i: int in 40:
		await _frames(1)
		ymax = maxf(ymax, (h as Node3D).global_position.y)
	_check(ymax > y0 + 0.5, "pulo levanta o jogador (%.2f -> %.2f)" % [y0, ymax])
	await _frames(60)
	h.call("start_slide")
	await _frames(2)
	_check(float(h.get("slide_t")) > 0.0, "carrinho iniciou")
	await _frames(80)
	_check(float(h.get("slide_t")) <= 0.0, "carrinho terminou")
	h.set("recover_t", 0.0)
	h.call("start_dribble", "zigzag", 0.6, 1.5, 40.0, 2.0, 1.0, Vector3(1, 0, 0))
	await _frames(3)
	_check(not (h.get("dsk") as Dictionary).is_empty(), "drible de skill ativo")
	await _frames(60)
	_check((h.get("dsk") as Dictionary).is_empty(), "drible de skill terminou")
	var foe: Node = null
	for q: Node in m.get("players"):
		if int(q.get("team")) == 1 and str(q.get("role")) != "keeper":
			foe = q
	foe.set("immune_t", 0.0)
	foe.set("shield_t", 0.0)
	foe.call("knockdown", 1.0)
	_check(float(foe.get("fall_t")) > 0.5, "knockdown derruba o adversário")
	var info: Dictionary = m.call("choose_mate", h)
	_check(info.get("mate") != null, "passe escolhe um parceiro (aleatório balanceado sem mira)")
	var pred: Node3D = (load("res://scripts/gameplay/ball_predict.gd") as GDScript).new()
	root.add_child(pred)
	var sim: Dictionary = pred.call("simulate", Vector3(0, 0.3, 0), Vector3(18, 6, 0), 0.0, 2.0, 0.04, 1)
	_check((sim["pts"] as Array).size() > 10, "Ball Predict simula a trajetória (%d pontos)" % (sim["pts"] as Array).size())
	pred.queue_free()
	var before_dim: int = 0
	for ch: Node in m.get_children():
		if ch.get_script() != null and String((ch.get_script() as Script).resource_path).ends_with("omni_dimension.gd"):
			before_dim += 1
	(load("res://scripts/gameplay/skills.gd") as GDScript).call("execute", h, G.skill("isagi_spatial"), m)
	await _frames(5)
	var dims: int = 0
	for ch2: Node in m.get_children():
		if ch2.get_script() != null and String((ch2.get_script() as Script).resource_path).ends_with("omni_dimension.gd"):
			dims += 1
	_check(dims == before_dim + 1, "Metavisão abre a Dimensão Omnisférica")
	_check(float(h.get("vision_t")) > 0.0 and float(h.call("buff", "speed")) >= 1.08, "Metavisão dá buff mínimo de velocidade")
	var matches0: int = int(G.career["matches"])
	G.record_match({"score": [2, 1], "won": true, "draw": false, "stats": {"goals": 2}, "mode": "2v2"}, "isagi", 100.0)
	_check(int(G.career["matches"]) == matches0 + 1 and G.history.size() >= 1, "perfil registra a partida no histórico")

	print("[8] Fim")
	Engine.time_scale = 1.0
	m.set("time_left", 0.05)
	await _frames(600)
	_check(int(m.get("state")) == 2, "partida 4v4 terminou")

	print("== Resultado: %d falha(s) ==" % _failures)
	quit(1 if _failures > 0 else 0)
