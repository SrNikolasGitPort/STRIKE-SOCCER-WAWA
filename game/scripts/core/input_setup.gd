extends Node
## Autoload "InputSetup": registra as ações de entrada por código
## (teclado, gamepad). Os botões de toque injetam as mesmas ações.
## Remapeamento completo na UI de configurações entra no M2.

const ACTIONS: PackedStringArray = [
	"move_left", "move_right", "move_forward", "move_back",
	"sprint", "shoot", "pass", "jump", "aim_up", "aim_down", "lock", "reset_ball", "toggle_quality", "pause", "awaken_test",
	"dribble", "tackle", "awaken", "cam_left", "cam_right", "cam_up", "cam_down",
	"skill_1", "skill_2", "skill_3", "skill_4", "skill_5", "skill_6",
]


func _ready() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("sprint", KEY_SHIFT)
	_key("jump", KEY_SPACE)
	_key("shoot", KEY_X)
	_mouse("shoot", MOUSE_BUTTON_LEFT)
	_key("pass", KEY_E)
	_key("aim_up", KEY_F)
	_key("aim_down", KEY_Z)
	_key("lock", KEY_TAB)
	_key("dribble", KEY_Q)
	_key("tackle", KEY_C)
	_key("tackle", KEY_CTRL)
	_key("cam_left", KEY_LEFT)
	_key("cam_right", KEY_RIGHT)
	_key("cam_up", KEY_UP)
	_key("cam_down", KEY_DOWN)
	_key("reset_ball", KEY_R)
	_key("toggle_quality", KEY_F2)
	_key("pause", KEY_ESCAPE)
	_key("pause", KEY_P)
	_key("awaken_test", KEY_T)
	_key("awaken", KEY_G)
	_key("awaken", KEY_V)
	var skill_keys: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
	var alt_keys: Array[Key] = [KEY_J, KEY_K, KEY_L, KEY_U, KEY_I, KEY_O]
	for i: int in range(6):
		_key("skill_%d" % (i + 1), skill_keys[i])
		_key("skill_%d" % (i + 1), alt_keys[i])

	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_button("sprint", JOY_BUTTON_LEFT_SHOULDER)
	_button("shoot", JOY_BUTTON_X)
	_button("dribble", JOY_BUTTON_RIGHT_STICK)
	_button("tackle", JOY_BUTTON_LEFT_STICK)
	_button("awaken", JOY_BUTTON_BACK)
	_button("reset_ball", JOY_BUTTON_MISC1)
	_axis("cam_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("cam_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("cam_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("cam_down", JOY_AXIS_RIGHT_Y, 1.0)
	_button("pass", JOY_BUTTON_A)
	_button("jump", JOY_BUTTON_Y)
	_button("aim_up", JOY_BUTTON_DPAD_LEFT)
	_button("aim_down", JOY_BUTTON_DPAD_RIGHT)
	_button("pause", JOY_BUTTON_START)
	_button("skill_1", JOY_BUTTON_B)
	_button("skill_2", JOY_BUTTON_RIGHT_SHOULDER)
	_button("skill_3", JOY_BUTTON_DPAD_UP)
	_axis("skill_4", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_axis("skill_5", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_button("skill_6", JOY_BUTTON_DPAD_DOWN)


func _key(action: String, keycode: Key) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _axis(action: String, axis: JoyAxis, value: float) -> void:
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _button(action: String, button: JoyButton) -> void:
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _mouse(action: String, button: MouseButton) -> void:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
