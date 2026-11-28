extends Control
## Seleção de personagem: grade de cartas por raridade, filtros, ficha com stats,
## skills, Despertar, compra com moedas e árvore de evolução Nel/GOAT com missões.

signal back
signal chosen(char_id: String)

const Kit = preload("res://scripts/ui/ui_kit.gd")
const STAT_LABELS: Dictionary = {
	"chute": "Chute", "velocidade": "Velocidade", "aceleracao": "Aceleração", "drible": "Drible",
	"passe": "Passe", "defesa": "Defesa", "fisico": "Físico", "visao": "Visão",
}

var play_label: String = "JOGAR"
var _filter: String = "todos"
var _grid: GridContainer
var _detail: VBoxContainer
var _coins_label: Label
var _current: String = ""


func _ready() -> void:
	Kit.full(self)
	Kit.background(self)
	var margin: MarginContainer = MarginContainer.new()
	Kit.safe_full(margin)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	top.add_child(Kit.button("◀ " + Game.t("Voltar", "Back"), func() -> void: back.emit(), Vector2(150, 48), 20))
	top.add_child(Kit.label(Game.t("PERSONAGENS", "CHARACTERS"), 34, Kit.GOLD))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_coins_label = Kit.label("", 24, Kit.GOLD)
	top.add_child(_coins_label)

	var filters: HBoxContainer = HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	root.add_child(filters)
	var fl: Array = [["todos", Game.t("Todos", "All")], ["raro", "Raro"], ["epico", Game.t("Épico", "Epic")], ["lendario", Game.t("Lendário", "Legendary")], ["mitico", Game.t("Mítico", "Mythic")], ["world_class", "World Class"]]
	for f: Array in fl:
		var fid: String = String(f[0])
		var b: Button = Kit.button(String(f[1]), func() -> void: _set_filter(fid), Vector2(110, 40), 17)
		if fid != "todos":
			b.add_theme_color_override("font_color", Config.rarity_color(fid))
		filters.add_child(b)

	var split: HBoxContainer = HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 14)
	root.add_child(split)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.25
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	var dpanel: PanelContainer = PanelContainer.new()
	dpanel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(dpanel)
	var dscroll: ScrollContainer = ScrollContainer.new()
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dpanel.add_child(dscroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 6)
	dscroll.add_child(_detail)

	_current = Game.selected_char if not Game.character(Game.selected_char).is_empty() else "isagi"
	_rebuild_grid()
	_show_detail(_current)


func _process(_d: float) -> void:
	_coins_label.text = "🪙 %d" % Game.coins


func _set_filter(f: String) -> void:
	_filter = f
	_rebuild_grid()


func _rebuild_grid() -> void:
	for c: Node in _grid.get_children():
		c.queue_free()
	var vw: float = get_viewport_rect().size.x
	_grid.columns = clampi(int(vw * 0.55 / 150.0), 2, 6)
	var ids: Array = Game.char_order().duplicate()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ra: int = Game.RARITY_ORDER.find(Game.rarity_of(String(a)))
		var rb: int = Game.RARITY_ORDER.find(Game.rarity_of(String(b)))
		return ra < rb if ra != rb else Game.char_order().find(a) < Game.char_order().find(b))
	for cid: Variant in ids:
		var id: String = String(cid)
		if _filter != "todos" and Game.rarity_of(id) != _filter:
			continue
		_grid.add_child(_card(id))


func _card(id: String) -> Control:
	var c: Dictionary = Game.character(id)
	var holder: Button = Button.new()
	holder.custom_minimum_size = Vector2(140, 196)
	holder.flat = true
	holder.focus_mode = Control.FOCUS_NONE
	holder.pressed.connect(func() -> void:
		Sfx.play("ui_click", -4.0)
		_show_detail(id))
	var port: TextureRect = TextureRect.new()
	port.texture = Kit.portrait(id)
	Kit.full(port)
	port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	port.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(port)
	var frame: TextureRect = TextureRect.new()
	frame.texture = Kit.texture("res://assets/textures/cards/frame_%s.png" % Game.rarity_of(id))
	Kit.full(frame)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(frame)
	var name_l: Label = Kit.label(String(c.get("name", id)), 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name_l.offset_top = -44.0
	name_l.offset_bottom = -22.0
	holder.add_child(name_l)
	if not Game.is_unlocked(id):
		var dark: ColorRect = ColorRect.new()
		Kit.full(dark)
		dark.color = Color(0, 0, 0, 0.62)
		dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(dark)
		var lock_text: String = "🔒" if Game.is_evolution(id) else "🪙 %d" % Game.cost_of(id)
		var lk: Label = Kit.label(lock_text, 22, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		lk.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		lk.offset_left = -60.0
		lk.offset_right = 60.0
		holder.add_child(lk)
	if id == _current:
		var sel: Panel = Panel.new()
		Kit.full(sel)
		sel.add_theme_stylebox_override("panel", Kit.box(Color(0, 0, 0, 0), 8, Color.WHITE, 3))
		sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(sel)
	return holder


func _show_detail(id: String) -> void:
	_current = id
	for c: Node in _detail.get_children():
		c.queue_free()
	var c: Dictionary = Game.character(id)
	if c.is_empty():
		return
	var rar: String = String(c.get("rarity", "raro"))
	var rc: Color = Config.rarity_color(rar)
	var big: TextureRect = TextureRect.new()
	big.texture = Kit.portrait(id)
	big.custom_minimum_size = Vector2(0, 190)
	big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail.add_child(big)
	_detail.add_child(Kit.label(String(c.get("name", id)), 34, rc))
	_detail.add_child(Kit.label("%s — %s   #%d" % [String(Game.RARITY_NAMES_PT.get(rar, rar)), String(c.get("position", "")), int(c.get("number", 0))], 18, rc))
	var bio: Label = Kit.label(String(c.get("bio", "")), 17, Color(0.85, 0.92, 1.0))
	bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bio.custom_minimum_size = Vector2(300, 0)
	_detail.add_child(bio)
	if bool(c.get("original", false)):
		_detail.add_child(Kit.label(Game.t("(forma original do jogo, não canônica)", "(original game form, non-canon)"), 15, Color(1.0, 0.7, 0.4)))
	var stats: Dictionary = c.get("stats", {})
	for key: String in STAT_LABELS:
		_detail.add_child(_stat_row(String(STAT_LABELS[key]), float(stats.get(key, 0)), rc))
	_detail.add_child(Kit.label(Game.t("SKILLS", "SKILLS"), 22, Kit.GOLD))
	for sid: Variant in c.get("skills", []):
		_detail.add_child(_skill_row(String(sid)))
	_detail.add_child(Kit.label(Game.t("DESPERTAR (encha a barra de Fluxo)", "AWAKENING (fill the Flow bar)"), 22, Kit.GOLD))
	var awake: Array = c.get("awakening", [])
	var avail: Array = Game.awakening_skills(id)
	for sid2: Variant in awake:
		var row: Control = _skill_row(String(sid2))
		if not avail.has(sid2):
			row.modulate = Color(1, 1, 1, 0.45)
		_detail.add_child(row)
	_build_quests(id, c)

	# Ação principal
	if Game.is_unlocked(id):
		_detail.add_child(Kit.button(play_label, _on_play.bind(id), Vector2(260, 60), 28))
	elif Game.is_evolution(id):
		_detail.add_child(Kit.label(Game.t("Complete as missões do personagem base para liberar.", "Complete the base character's quests to unlock."), 16, Color(1.0, 0.8, 0.5)))
	else:
		var buy: Button = Kit.button(Game.t("Comprar  🪙 %d", "Buy  🪙 %d") % Game.cost_of(id), _on_buy.bind(id), Vector2(260, 56), 24)
		buy.disabled = not Game.can_buy(id)
		_detail.add_child(buy)
	_rebuild_grid()


func _on_play(id: String) -> void:
	Game.selected_char = id
	Game.save_game()
	chosen.emit(id)


func _on_buy(id: String) -> void:
	if Game.buy(id):
		Sfx.play("coin")
		_show_detail(id)
	else:
		Sfx.play("ui_error")


func _stat_row(label: String, value: float, color: Color) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	var l: Label = Kit.label(label, 16)
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(150, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill: StyleBoxFlat = Kit.box(color, 5)
	var back: StyleBoxFlat = Kit.box(Color(0, 0, 0, 0.5), 5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	row.add_child(bar)
	row.add_child(Kit.label(" %d" % int(value), 16))
	return row


func _skill_row(sid: String) -> Control:
	var s: Dictionary = Game.skill(sid)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon: TextureRect = TextureRect.new()
	icon.texture = Kit.texture("res://assets/textures/icons/skill_%s.png" % String(s.get("effect", "shot")))
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var col: VBoxContainer = VBoxContainer.new()
	var nm: String = Game.skill_name(sid)
	var jp: String = String(s.get("jp", ""))
	col.add_child(Kit.label(nm + ("  " + jp if jp != "" else ""), 17))
	var ref: String = String(s.get("ref", ""))
	col.add_child(Kit.label("%s  •  %ds" % [ref, int(s.get("cooldown", 0))], 13, Color(0.65, 0.75, 0.95)))
	row.add_child(col)
	return row


func _build_quests(id: String, c: Dictionary) -> void:
	var base_id: String = String(c.get("base_id", "")) if c.get("base_id") != null else id
	var qs: Array = Game.quests_for(base_id)
	if qs.is_empty():
		return
	var evo: String = String(Game.character(base_id).get("evolution", ""))
	var evo_name: String = String(Game.character(evo).get("name", "Nel"))
	_detail.add_child(Kit.label(Game.t("EVOLUÇÃO: %s", "EVOLUTION: %s") % evo_name, 22, Color(0.85, 0.95, 1.0)))
	for q: Variant in qs:
		var qd: Dictionary = q
		var done: bool = Game.quest_done.has(String(qd["id"]))
		var txt: String = "%s %s  (%d/%d)\n   → %s" % ["✔" if done else "○", Game.quest_text(qd), Game.quest_progress_of(qd), int(qd.get("target", 1)), Game.skill_name(String(qd.get("unlock", "")))]
		var l: Label = Kit.label(txt, 15, Color(0.6, 1.0, 0.7) if done else Color(0.9, 0.9, 1.0))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		_detail.add_child(l)
	if id == base_id and Game.is_unlocked(evo):
		_detail.add_child(Kit.button(Game.t("Ver %s", "View %s") % evo_name, _show_detail.bind(evo), Vector2(220, 44), 18))
