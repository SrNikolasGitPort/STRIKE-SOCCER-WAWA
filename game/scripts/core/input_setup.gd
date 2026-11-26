extends Node
## Autoload "InputSetup": registra as ações de entrada por código
## (teclado, gamepad). Os botões de toque injetam as mesmas ações.
## Remapeamento completo na UI de configurações entra no M2.

const ACTIONS: PackedStringArray = [
	"move_left", "move_right", "move_forward", "move_back",
	"sprint", "shoot", "pass", "lob", "reset_ball", "toggle_quality",
]


func _ready() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
	_key("move_left", KEY_A)
	_key("move_left", KEY_LEFT)
	_key("move_right", KEY_D)
	_key("move_right", KEY_RIGHT)
	_key("move_forward", KEY_W)
	_key("move_forward", KEY_UP)
	_key("move_back", KEY_S)
	_key("move_back", KEY_DOWN)
	_key("sprint", KEY_SHIFT)
	_key("shoot", KEY_SPACE)
	_key("pass", KEY_E)
	_key("lob", KEY_Q)
	_key("reset_ball", KEY_R)
	_key("toggle_quality", KEY_F2)

	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_button("sprint", JOY_BUTTON_LEFT_SHOULDER)
	_button("shoot", JOY_BUTTON_X)
	_button("pass", JOY_BUTTON_A)
	_button("lob", JOY_BUTTON_Y)
	_button("reset_ball", JOY_BUTTON_BACK)


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
