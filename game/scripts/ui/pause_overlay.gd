extends CanvasLayer
## Menu de pausa: continuar, volumes e sair da partida.

signal resume
signal leave

const Kit = preload("res://scripts/ui/ui_kit.gd")
var _age: float = 0.0


func _ready() -> void:
	layer = 50
	var root: Control = Control.new()
	Kit.full(root)
	root.theme = Kit.make_theme()
	add_child(root)
	var shade: ColorRect = ColorRect.new()
	Kit.full(shade)
	shade.color = Color(0, 0, 0, 0.6)
	root.add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	Kit.full(center)
	root.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(Kit.label(Game.t("PAUSADO", "PAUSED"), 40, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(Kit.button(Game.t("Continuar", "Resume"), func() -> void: resume.emit()))
	for entry: Array in [["vol_master", "Geral", "Master"], ["vol_music", "Música", "Music"], ["vol_sfx", "Efeitos", "SFX"]]:
		var row: HBoxContainer = HBoxContainer.new()
		var l: Label = Kit.label(Game.t(String(entry[1]), String(entry[2])), 20)
		l.custom_minimum_size = Vector2(110, 0)
		row.add_child(l)
		var sl: HSlider = HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(Game.settings[String(entry[0])])
		sl.custom_minimum_size = Vector2(240, 30)
		sl.value_changed.connect(func(v: float) -> void:
			Game.settings[String(entry[0])] = v
			Sfx.apply_volumes())
		row.add_child(sl)
		box.add_child(row)
	box.add_child(Kit.button(Game.t("Sair para o menu", "Quit to menu"), func() -> void: leave.emit()))


func _process(delta: float) -> void:
	_age += delta
	if _age > 0.25 and Input.is_action_just_pressed("pause"):
		resume.emit()
