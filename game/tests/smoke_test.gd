extends SceneTree
## Smoke test headless do M1. Roda a partida de verdade (sem janela) e confere:
## física da bola, movimento/stamina, chute, gols nos dois lados e paredes.
##
## Uso local/CI:
##   godot --headless --fixed-fps 60 --path game -s res://tests/smoke_test.gd
## Sai com código 1 se qualquer verificação falhar.

var _failures: int = 0
var _match: Variant = null


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


func _ball() -> RigidBody3D:
	return _match.ball


func _player() -> CharacterBody3D:
	return _match.player


func _run() -> void:
	print("== Smoke test M1 ==")
	var packed: PackedScene = load("res://scenes/match/Match.tscn")
	_match = packed.instantiate()
	root.add_child(_match)
	await _frames(90)

	var half_l: float = _match.field.length / 2.0
	var half_w: float = _match.field.width / 2.0
	var wall_h: float = _match.field.wall_h

	print("[1] Cena e dados")
	var config: Node = root.get_node("Config")
	_check(config.call("rarity_color", "raro") == Color("#2F80ED"), "raridade Raro é azul")
	_check(config.call("rarity_color", "world_class") == Color("#FFFFFF"), "raridade World Class é branca")
	_check(_match.state == 0, "partida começa em PLAYING")

	print("[2] Física parada")
	var ball_y: float = _ball().global_position.y
	_check(ball_y > 0.2 and ball_y < 0.6, "bola descansa no gramado (y=%.2f)" % ball_y)
	var player_y: float = _player().global_position.y
	_check(player_y > 0.7 and player_y < 1.1, "jogador está no chão (y=%.2f)" % player_y)

	print("[3] Movimento e stamina")
	var start_x: float = _player().global_position.x
	Input.action_press("move_forward")  # "frente" = +X (direção do gol adversário)
	Input.action_press("sprint")
	await _frames(60)
	var vx: float = _player().velocity.x
	var stamina: float = _player().stamina
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_check(_player().global_position.x > start_x + 3.0, "jogador andou para frente (x=%.1f)" % _player().global_position.x)
	_check(vx > 8.0, "velocidade de sprint (%.1f m/s)" % vx)
	_check(stamina < 95.0, "stamina gastou no sprint (%.0f)" % stamina)
	await _frames(120)
	_check(_player().stamina > stamina + 5.0, "stamina recarrega depois de parar")

	print("[4] Chute do jogador")
	var p: Vector3 = _player().global_position
	_ball().reset_to(Vector3(p.x + 1.0, 0.4, p.z))
	await _frames(5)
	Input.action_press("shoot")
	await _frames(55)
	_check(_player().charge > 0.9, "barra de força carregou (%.2f)" % _player().charge)
	Input.action_release("shoot")
	await _frames(3)
	var kick_speed: float = _ball().linear_velocity.length()
	_check(kick_speed > 15.0, "chute forte deu velocidade à bola (%.1f m/s)" % kick_speed)
	_check(_ball().linear_velocity.x > 10.0, "chute foi em direção ao gol adversário (+X)")

	print("[5] Passe")
	await _frames(240)
	p = _player().global_position
	_ball().reset_to(Vector3(p.x + 1.0, 0.4, p.z))
	await _frames(5)
	Input.action_press("pass")
	await _frames(3)
	Input.action_release("pass")
	await _frames(2)
	var pass_speed: float = Vector2(_ball().linear_velocity.x, _ball().linear_velocity.z).length()
	_check(pass_speed > 8.0, "passe deu velocidade à bola (%.1f m/s)" % pass_speed)

	print("[6] Gol no lado +X (ponto do time 0)")
	# O chute do passo [4] pode ter entrado no gol; por isso o placar é comparado de forma relativa.
	var score_a: int = _match.score[0]
	var score_b: int = _match.score[1]
	_ball().reset_to(Vector3(half_l - 4.0, 0.4, 0.0))
	_ball().kick(Vector3.RIGHT, 18.0)
	await _frames(40)
	_check(_match.score[0] == score_a + 1 and _match.score[1] == score_b, "gol em +X marcou 1 ponto para o time 0 (%d x %d)" % [_match.score[0], _match.score[1]])
	_check(Engine.time_scale < 1.0, "câmera lenta do gol ativa")
	await _frames(350)
	_check(Engine.time_scale == 1.0, "câmera lenta terminou")
	_check(_match.state == 0, "partida voltou ao saque (PLAYING)")
	_check(absf(_ball().global_position.x) < 1.0, "bola voltou ao centro")

	print("[7] Gol no lado -X (ponto do time 1)")
	score_a = _match.score[0]
	score_b = _match.score[1]
	_ball().reset_to(Vector3(-half_l + 4.0, 0.4, 0.0))
	_ball().kick(Vector3.LEFT, 18.0)
	await _frames(40)
	_check(_match.score[1] == score_b + 1 and _match.score[0] == score_a, "gol em -X marcou 1 ponto para o time 1 (%d x %d)" % [_match.score[0], _match.score[1]])
	await _frames(300)

	print("[8] Paredes da arena")
	_ball().reset_to(Vector3(0.0, 0.4, 10.0))
	_ball().kick(Vector3(0.0, 0.0, 1.0), 30.0)
	await _frames(90)
	_check(absf(_ball().global_position.z) < half_w, "bola não atravessa a parede lateral (z=%.1f)" % _ball().global_position.z)
	_ball().reset_to(Vector3(0.0, 0.4, 0.0))
	_ball().kick(Vector3(0.0, 1.0, 0.0), 32.0)
	await _frames(150)
	var top: float = _ball().global_position.y
	_check(top < wall_h and top > 0.0, "bola não atravessa o teto nem o chão (y=%.1f)" % top)
	_ball().reset_to(Vector3(half_l - 3.0, 0.4, half_w - 2.0))
	_ball().kick(Vector3(1.0, 0.0, 0.2), 25.0)
	await _frames(90)
	var bz: float = _ball().global_position.z
	var bx: float = _ball().global_position.x
	_check(absf(bz) < half_w and absf(bx) < half_l + _match.field.goal_d, "bola fica dentro da arena (x=%.1f z=%.1f)" % [bx, bz])

	print("[9] Fim de jogo")
	_match.time_left = 0.05
	await _frames(30)
	_check(_match.state == 2, "partida terminou ao zerar o tempo (FINISHED)")

	print("== Resultado: %d falha(s) ==" % _failures)
	quit(1 if _failures > 0 else 0)
