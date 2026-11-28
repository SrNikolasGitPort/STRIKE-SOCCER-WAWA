extends CanvasLayer
## Tela de resultado ao fim da partida: placar, recompensas e botões.

const Kit = preload("res://scripts/ui/ui_kit.gd")


func show_result(m: Node) -> void:
	layer = 40
	var r: Dictionary = Game.last_result
	var root: Control = Control.new()
	Kit.full(root)
	root.theme = Kit.make_theme()
	add_child(root)
	var shade: ColorRect = ColorRect.new()
	Kit.full(shade)
	shade.color = Color(0, 0, 0, 0.65)
	root.add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	Kit.safe_full(center)
	root.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title: String = Game.t("EMPATE", "DRAW")
	var col: Color = Color(0.9, 0.9, 0.5)
	if bool(r.get("won", false)):
		title = Game.t("VITÓRIA!", "VICTORY!")
		col = Kit.GOLD
	elif not bool(r.get("draw", false)):
		title = Game.t("DERROTA", "DEFEAT")
		col = Color(1.0, 0.45, 0.45)
	box.add_child(Kit.label(title, 56, col, HORIZONTAL_ALIGNMENT_CENTER))
	var sc: Array = r.get("score", [0, 0])
	box.add_child(Kit.label("%d  x  %d" % [int(sc[0]), int(sc[1])], 44, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var st: Dictionary = r.get("stats", {})
	box.add_child(Kit.label(Game.t("Gols: %d   Assistências: %d   Roubos: %d", "Goals: %d   Assists: %d   Steals: %d") % [int(st.get("goals", 0)), int(st.get("assists", 0)), int(st.get("steals", 0))], 20, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(Kit.label("+%d %s    +%d XP" % [int(r.get("coins", 0)), Game.t("moedas", "coins"), int(r.get("xp", 0))], 24, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if not bool(m.get("online")):
		row.add_child(Kit.button(Game.t("Jogar de novo", "Play again"), func() -> void: m.call("rematch")))
	row.add_child(Kit.button(Game.t("Menu", "Menu"), func() -> void: m.call("leave_to_menu")))
	box.add_child(row)
