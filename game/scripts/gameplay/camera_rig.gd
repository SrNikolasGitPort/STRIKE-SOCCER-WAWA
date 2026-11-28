extends Node3D
## Câmera 3ª pessoa ORBITAL estilo Roblox: fica atrás do jogador, gira com botão
## direito do mouse / setas / analógico direito / arrastar o dedo (celular) e dá
## zoom com a roda do mouse. O movimento e a mira são relativos à câmera.

var player: Node3D = null
var ball: Node3D = null
var touch: Control = null
var side: float = 1.0  # +1: começa olhando para +X (time 0); -1: para -X (time 1 online)

var locked: bool = false  # trava de mira (shift lock): mouse controla a mira, corpo olha para a mira
var yaw: float = 0.0
var pitch: float = 0.0
var distance: float = 0.0

var _cam: Camera3D
var _focus: Vector3 = Vector3.ZERO
var _shake: float = 0.0
var _fov_kick: float = 0.0
var _fov_tween: Tween
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
# Modo cinemático (cutscenes de Despertar / skills): órbita ao redor de um alvo.
var _cin_target: Node3D = null
var _cin_t: float = 0.0
var _cin_dur: float = 0.0
var _cin_orbit: float = 0.0
var _cin_dist: float = 3.0
var _cin_h: float = 1.4
var _cin_fov: float = 50.0
var _cin_a0: float = 0.0


func _ready() -> void:
	_cam = Camera3D.new()
	_cam.fov = Config.f("camera.fov")
	_cam.near = 0.1
	_cam.far = 400.0
	_cam.current = true
	add_child(_cam)
	pitch = deg_to_rad(Config.f("camera.pitch_deg"))
	distance = Config.f("camera.distance")


func snap() -> void:
	yaw = 0.0 if side > 0.0 else PI
	if player != null:
		_focus = _target_focus()
		_apply(0.0)


## Câmera cinemática: gira `orbit_deg` graus ao redor do alvo durante `duration` s.
func cinematic(target: Node3D, duration: float, orbit_deg: float, fov: float, dist: float, height: float) -> void:
	if target == null:
		return
	_cin_target = target
	_cin_t = 0.0
	_cin_dur = duration
	_cin_orbit = deg_to_rad(orbit_deg)
	_cin_fov = fov
	_cin_dist = dist
	_cin_h = height
	_cin_a0 = yaw + PI * 0.5 + deg_to_rad(25.0)


func end_cinematic() -> void:
	_cin_target = null


func is_cinematic() -> bool:
	return _cin_target != null


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func punch_fov(delta_deg: float, duration: float) -> void:
	if _fov_tween != null and _fov_tween.is_valid():
		_fov_tween.kill()
	_fov_kick = delta_deg
	_fov_tween = create_tween()
	_fov_tween.tween_property(self, "_fov_kick", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Direção horizontal para onde a câmera olha (usada para mirar).
func forward() -> Vector3:
	return Vector3(cos(yaw), 0.0, sin(yaw))


## Converte o vetor do joystick/WASD (x = direita, y = frente negativo) em direção de mundo.
func world_wish(iv: Vector2) -> Vector3:
	var f: Vector3 = forward()
	var r: Vector3 = f.cross(Vector3.UP)
	return f * (-iv.y) + r * iv.x


func _rotate(dx: float, dy: float) -> void:
	yaw += dx * Config.f("camera.sensitivity")
	pitch = clampf(pitch + dy * Config.f("camera.sensitivity"), deg_to_rad(Config.f("camera.min_pitch_deg")), deg_to_rad(Config.f("camera.max_pitch_deg")))


func toggle_lock() -> void:
	locked = not locked
	_sync_mouse()
	if player != null and player.get("arena") != null:
		var hud: Node = player.arena.get("hud")
		if hud != null and hud.has_method("set_locked"):
			hud.call("set_locked", locked)


func _sync_mouse() -> void:
	if OS.has_feature("mobile"):
		return
	var want: bool = locked and not get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if want else Input.MOUSE_MODE_VISIBLE


func _exit_tree() -> void:
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("lock"):
		toggle_lock()
		return
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0 or (locked and not get_tree().paused):
			_rotate(mm.relative.x, mm.relative.y)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 0.6, Config.f("camera.min_distance"), Config.f("camera.max_distance"))
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 0.6, Config.f("camera.min_distance"), Config.f("camera.max_distance"))
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		if touch != null and bool(touch.call("claims", sd.index)):
			return
		_rotate(sd.relative.x * 1.3, sd.relative.y * 1.3)


func _target_focus() -> Vector3:
	var target: Vector3 = player.global_position
	if ball != null:
		target = target.lerp(ball.global_position, Config.f("camera.ball_weight"))
	target.y = 1.5
	return target


func _process(delta: float) -> void:
	if player == null:
		return
	if _cin_target != null:
		if not is_instance_valid(_cin_target):
			_cin_target = null
		else:
			# usa delta real (a cutscene pode rodar em câmera lenta)
			_cin_t += delta / maxf(Engine.time_scale, 0.05)
			var k: float = clampf(_cin_t / _cin_dur, 0.0, 1.0)
			var e: float = 1.0 - pow(1.0 - k, 2.0)
			var a: float = _cin_a0 + _cin_orbit * e
			var d: float = lerpf(_cin_dist * 1.25, _cin_dist, e)
			var c: Vector3 = _cin_target.global_position + Vector3(0.0, 1.0, 0.0)
			var cpos: Vector3 = c + Vector3(cos(a) * d, _cin_h * lerpf(0.5, 1.0, e), sin(a) * d)
			_cam.fov = lerpf(_cin_fov + 14.0, _cin_fov, e) + _fov_kick
			_cam.look_at_from_position(cpos, c + Vector3(0.0, 0.2, 0.0), Vector3.UP)
			if _cin_t >= _cin_dur:
				_cin_target = null
			return
	var stick: Vector2 = Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if stick.length() > 0.05:
		_rotate(stick.x * 520.0 * delta, stick.y * 380.0 * delta)
	var t: float = 1.0 - exp(-Config.f("camera.follow_speed") * delta)
	_focus = _focus.lerp(_target_focus(), t)
	if locked:
		_sync_mouse()
	_apply(delta)


func _apply(delta: float) -> void:
	var f: Vector3 = forward()
	var r: Vector3 = f.cross(Vector3.UP)
	var dist: float = minf(distance, Config.f("camera.lock_distance")) if locked else distance
	var shoulder: float = Config.f("camera.lock_shoulder") if locked else Config.f("camera.shoulder")
	var horiz: float = dist * cos(pitch)
	var pos: Vector3 = _focus - f * horiz + Vector3(0.0, dist * sin(pitch), 0.0) + r * shoulder
	pos.y = maxf(pos.y, 0.7)
	if _shake > 0.001:
		pos += Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * _shake
		_shake = lerpf(_shake, 0.0, clampf(8.0 * delta, 0.0, 1.0))
	_cam.fov = Config.f("camera.fov") + _fov_kick
	_cam.look_at_from_position(pos, _focus + f * 3.0, Vector3.UP)
