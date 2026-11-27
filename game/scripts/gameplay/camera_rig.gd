extends Node3D
## Câmera 3ª pessoa dinâmica: acompanha jogador + bola, dá zoom-out quando
## eles se afastam, olha um pouco à frente (+X, direção do ataque) e treme
## em momentos de impacto (gol, chutes fortes).

var player: Node3D = null
var ball: Node3D = null
var side: float = 1.0  # +1 olha para +X (time 0); -1 olha para -X (time 1 no online)

var _cam: Camera3D
var _focus: Vector3 = Vector3.ZERO
var _shake: float = 0.0
var _fov_kick: float = 0.0
var _fov_tween: Tween
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_cam = Camera3D.new()
	_cam.fov = Config.f("camera.fov")
	_cam.near = 0.1
	_cam.far = 400.0
	_cam.current = true
	add_child(_cam)


func snap() -> void:
	if player != null:
		_focus = _target_focus()
		_apply(0.0)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func punch_fov(delta_deg: float, duration: float) -> void:
	if _fov_tween != null and _fov_tween.is_valid():
		_fov_tween.kill()
	_fov_kick = delta_deg
	_fov_tween = create_tween()
	_fov_tween.tween_property(self, "_fov_kick", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _target_focus() -> Vector3:
	var target: Vector3 = player.global_position
	if ball != null:
		target = target.lerp(ball.global_position, Config.f("camera.ball_weight"))
	target.y = 0.0
	return target


func _process(delta: float) -> void:
	if player == null:
		return
	var t: float = 1.0 - exp(-Config.f("camera.follow_speed") * delta)
	_focus = _focus.lerp(_target_focus(), t)
	_apply(delta)


func _apply(delta: float) -> void:
	var separation: float = 0.0
	if ball != null:
		separation = player.global_position.distance_to(ball.global_position)
	var zoom: float = clampf(separation / Config.f("camera.zoom_speed"), Config.f("camera.min_zoom_out"), Config.f("camera.max_zoom_out"))
	var offset: Vector3 = Vector3(-side * (Config.f("camera.distance") + zoom), Config.f("camera.height") + zoom * 0.6, 0.0)
	var pos: Vector3 = _focus + offset
	if _shake > 0.001:
		pos += Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * _shake
		_shake = lerpf(_shake, 0.0, clampf(8.0 * delta, 0.0, 1.0))
	var look: Vector3 = _focus + Vector3(side * Config.f("camera.look_ahead"), 0.0, 0.0)
	_cam.fov = Config.f("camera.fov") + _fov_kick
	_cam.look_at_from_position(pos, look, Vector3.UP)
