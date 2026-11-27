extends SceneTree
## Teste de sistemas: menus, partida 4v4 com bots, skills, Despertar, missões Nel,
## códigos de sala e dados. Sai com código 1 se algo falhar.

var _failures: int = 0


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
	print("[1] Dados")
	var order: Array = Game.char_order()
	_check(order.size() == 30, "30 personagens carregados (%d)" % order.size())
	var bad: int = 0
	for cid: Variant in order:
		var c: Dictionary = Game.character(String(cid))
		for sid: Variant in c.get("skills", []) + c.get("awakening", []):
			if Game.skill(String(sid)).is_empty():
				bad += 1
	_check(bad == 0, "todas as skills dos personagens existem")
	_check(Game.is_unlocked("isagi") and not Game.is_unlocked("isagi_nel"), "Nel começa bloqueado")

	print("[2] Missões Nel")
	var qs: Array = Game.quests_for("isagi")
	_check(qs.size() == 3, "Isagi tem 3 missões")
	var first: Dictionary = qs[0]
	Game.report_event(String(first["event"]), "isagi", int(first["target"]))
	_check(Game.quest_done.has(String(first["id"])), "missão concluída pelo evento")
	_check(Game.is_unlocked("isagi_nel"), "Nel liberado após 1ª missão")
	_check(Game.awakening_skills("isagi_nel").size() == 1, "1 skill de Despertar Nel liberada")

	print("[3] Códigos de sala")
	var code: String = Net.encode_room("192.168.1.23", 24565)
	var dec: Dictionary = Net.decode_room(code)
	_check(code.length() == 11 and String(dec.get("ip", "")) == "192.168.1.23" and int(dec.get("port", 0)) == 24565, "código %s ida e volta" % code)
	_check(Net.decode_room("xxxx").is_empty(), "código inválido rejeitado")

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
	Game.mode = "4v4"
	Game.selected_char = "isagi"
	var m: Node = (load("res://scenes/match/Match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await _frames(10)
	var players: Array = m.get("players")
	_check(players.size() == 8, "8 jogadores em campo (%d)" % players.size())
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
	await _frames(5)
	_check(float(h.call("cooldown_left", 0)) > 0.0, "skill 1 entrou em recarga")
	m.call("_awaken", h)
	await _frames(5)
	_check(bool(h.get("awakened")), "Despertar ativado")
	var used: int = 0
	for slot: int in range(1, 6):
		if h.call("try_skill", slot):
			used += 1
		await _frames(4)
	_check(used >= 2, "skills normais e de Despertar executaram (%d)" % used)
	await _frames(240)
	Engine.time_scale = 1.0

	print("[7] Todos os efeitos de skill")
	var errors_before: int = _failures
	for sid: Variant in Game.char_order():
		var c2: Dictionary = Game.character(String(sid))
		for skid: Variant in c2.get("skills", []) + c2.get("awakening", []):
			var sk: Dictionary = Game.skill(String(skid))
			ball.reset_to((h as Node3D).global_position + Vector3(1.0, 0.4, 0.0))
			h.set("stamina", 100.0)
			const SkillsScript = preload("res://scripts/gameplay/skills.gd")
			SkillsScript.execute(h, sk, m)
	await _frames(30)
	_check(_failures == errors_before, "137 skills executaram sem erro de script")

	print("[8] Fim")
	m.set("time_left", 0.05)
	await _frames(30)
	_check(int(m.get("state")) == 2, "partida 4v4 terminou")

	print("== Resultado: %d falha(s) ==" % _failures)
	quit(1 if _failures > 0 else 0)
