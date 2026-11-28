extends Control
## Perfil do jogador: apelido, bio, título, avatar, status da carreira, histórico de partidas
## e personalização do personagem (cores do uniforme, shorts, cabelo e aura).

signal back

const Kit = preload("res://scripts/ui/ui_kit.gd")
const PALETTE: Array = ["", "#2F80ED", "#EB5757", "#27AE60", "#F2C94C", "#9B51E0", "#F2994A", "#FFFFFF", "#111111", "#FF6FB5", "#2AE0C9", "#8B5A2B"]
const BANNERS: Array = [Color(0.1, 0.25, 0.6), Color(0.5, 0.1, 0.15), Color(0.1, 0.4, 0.2), Color(0.4, 0.25, 0.6), Color(0.55, 0.4, 0.05)]

var _body: VBoxContainer
var _tab: String = "profile"
var _name_edit: LineEdit
var _bio_edit: TextEdit


func _ready() -> void:
	Kit.full(self)
	Kit.background(self)
	var margin: MarginContainer = MarginContainer.new()
	Kit.safe_full(margin)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	top.add_child(Kit.button("◀ " + Game.t("Voltar", "Back"), _on_back, Vector2(150, 48), 20))
	top.add_child(Kit.label(Game.t("PERFIL", "PROFILE"), 34, Kit.GOLD))
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	root.add_child(tabs)
	for t: Array in [["profile", Game.t("Perfil", "Profile")], ["stats", Game.t("Status", "Stats")], ["history", Game.t("Histórico", "History")], ["custom", Game.t("Personalizar", "Customize")]]:
		tabs.add_child(Kit.button(String(t[1]), _set_tab.bind(String(t[0])), Vector2(170, 46), 20))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)
	_refresh()


func _on_back() -> void:
	_commit()
	Game.save_game()
	back.emit()


func _set_tab(t: String) -> void:
	_commit()
	_tab = t
	_refresh()


## Guarda os campos de texto antes de trocar de aba.
func _commit() -> void:
	if _name_edit != null and is_instance_valid(_name_edit):
		var n: String = _name_edit.text.strip_edges()
		if n != "":
			Game.player_name = n
	if _bio_edit != null and is_instance_valid(_bio_edit):
		Game.profile["bio"] = _bio_edit.text.substr(0, 140)
	_name_edit = null
	_bio_edit = null


func _refresh() -> void:
	for c: Node in _body.get_children():
		c.queue_free()
	match _tab:
		"stats":
			_build_stats()
		"history":
			_build_history()
		"custom":
			_build_custom()
		_:
			_build_profile()
	Kit.animate_in(_body, 0.05)


func _card() -> VBoxContainer:
	var pc: PanelContainer = PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(pc)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	return v


func _avatar_id() -> String:
	var a: String = String(Game.profile.get("avatar", ""))
	return a if a != "" and Game.character(a).size() > 0 else Game.selected_char


func _build_profile() -> void:
	var v: VBoxContainer = _card()
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	var port: TextureRect = TextureRect.new()
	port.texture = Kit.portrait(_avatar_id())
	port.custom_minimum_size = Vector2(120, 150)
	port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	head.add_child(port)
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	info.add_child(Kit.label(Game.player_name, 32, Kit.GOLD))
	info.add_child(Kit.label("[%s]   %s %d   •   🪙 %d" % [Game.title_name(String(Game.profile.get("title", "rookie"))), Game.t("Nível", "Level"), Game.level(), Game.coins], 20))
	var bio: String = String(Game.profile.get("bio", ""))
	var bl: Label = Kit.label(bio if bio != "" else Game.t("(sem bio)", "(no bio)"), 18, Color(0.8, 0.9, 1.0))
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(bl)

	var e: VBoxContainer = _card()
	e.add_child(Kit.label(Game.t("Apelido", "Nickname"), 20, Kit.GOLD))
	_name_edit = LineEdit.new()
	_name_edit.text = Game.player_name
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(300, 44)
	e.add_child(_name_edit)
	e.add_child(Kit.label(Game.t("Bio (até 140 caracteres, sem dados pessoais)", "Bio (max 140 chars, no personal info)"), 20, Kit.GOLD))
	_bio_edit = TextEdit.new()
	_bio_edit.text = String(Game.profile.get("bio", ""))
	_bio_edit.custom_minimum_size = Vector2(300, 90)
	_bio_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	e.add_child(_bio_edit)

	var t: VBoxContainer = _card()
	t.add_child(Kit.label(Game.t("Título", "Title"), 20, Kit.GOLD))
	var tr: HFlowContainer = HFlowContainer.new()
	t.add_child(tr)
	for tt: Dictionary in Game.TITLES:
		var ok: bool = Game.title_unlocked(tt)
		var label: String = Game.title_name(String(tt["id"]))
		if not ok:
			label += "  🔒 %d %s" % [int(tt["n"]), String(tt["need"])]
		var b: Button = Kit.button(label, _pick_title.bind(String(tt["id"])), Vector2(180, 42), 16)
		b.disabled = not ok
		tr.add_child(b)

	var a: VBoxContainer = _card()
	a.add_child(Kit.label(Game.t("Avatar (personagem do perfil)", "Avatar (profile character)"), 20, Kit.GOLD))
	var ar: HFlowContainer = HFlowContainer.new()
	a.add_child(ar)
	for cid: Variant in Game.char_order():
		if not Game.is_unlocked(String(cid)):
			continue
		var cb: Button = Kit.button(String(Game.character(String(cid)).get("name", cid)), _pick_avatar.bind(String(cid)), Vector2(130, 38), 14)
		ar.add_child(cb)


func _pick_title(id: String) -> void:
	Game.profile["title"] = id
	_commit()
	_refresh()


func _pick_avatar(id: String) -> void:
	Game.profile["avatar"] = id
	_commit()
	_refresh()


func _stat_row(v: VBoxContainer, k: String, val: String) -> void:
	var r: HBoxContainer = HBoxContainer.new()
	v.add_child(r)
	var a: Label = Kit.label(k, 20, Color(0.8, 0.9, 1.0))
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(a)
	r.add_child(Kit.label(val, 22, Kit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT))


func _build_stats() -> void:
	var v: VBoxContainer = _card()
	var c: Dictionary = Game.career
	var m: int = int(c["matches"])
	_stat_row(v, Game.t("Partidas", "Matches"), str(m))
	_stat_row(v, Game.t("Vitórias / Empates / Derrotas", "Wins / Draws / Losses"), "%d / %d / %d" % [int(c["wins"]), int(c["draws"]), int(c["losses"])])
	_stat_row(v, Game.t("Taxa de vitória", "Win rate"), "%d%%" % (int(round(100.0 * float(c["wins"]) / float(maxi(m, 1))))))
	_stat_row(v, Game.t("Gols", "Goals"), str(int(c["goals"])))
	_stat_row(v, Game.t("Assistências", "Assists"), str(int(c["assists"])))
	_stat_row(v, Game.t("Roubos de bola", "Steals"), str(int(c["steals"])))
	_stat_row(v, Game.t("Skills usadas", "Skills used"), str(int(c["skills"])))
	_stat_row(v, Game.t("Despertares", "Awakenings"), str(int(c["awakens"])))
	_stat_row(v, Game.t("Tempo jogado", "Play time"), "%d min" % (int(c["seconds"]) / 60))
	var fav: String = Game.favorite_char()
	_stat_row(v, Game.t("Personagem favorito", "Favorite character"), String(Game.character(fav).get("name", "-")) if fav != "" else "-")
	_stat_row(v, Game.t("Nível / XP", "Level / XP"), "%d / %d" % [Game.level(), Game.xp])


func _build_history() -> void:
	var v: VBoxContainer = _card()
	if Game.history.is_empty():
		v.add_child(Kit.label(Game.t("Nenhuma partida registrada ainda.", "No matches recorded yet."), 20))
		return
	for h: Variant in Game.history:
		var d: Dictionary = h
		var res: String = Game.t("VITÓRIA", "WIN") if bool(d["won"]) else (Game.t("EMPATE", "DRAW") if bool(d["draw"]) else Game.t("DERROTA", "LOSS"))
		var col: Color = Color(0.5, 1.0, 0.6) if bool(d["won"]) else (Color(1.0, 0.9, 0.5) if bool(d["draw"]) else Color(1.0, 0.55, 0.55))
		var when: String = Time.get_datetime_string_from_unix_time(int(d["t"]), true).replace("T", " ")
		var line: String = "%s   %d x %d   %s   [%s]   ⚽%d 🅰%d   %s" % [res, int(d["my"]), int(d["other"]), String(Game.character(String(d["char"])).get("name", d["char"])), String(d["mode"]), int(d["goals"]), int(d["assists"]), when]
		var l: Label = Kit.label(line, 18, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)


func _color_row(v: VBoxContainer, title: String, key: String) -> void:
	v.add_child(Kit.label(title, 20, Kit.GOLD))
	var fl: HFlowContainer = HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 8)
	fl.add_theme_constant_override("v_separation", 8)
	v.add_child(fl)
	for hex: Variant in PALETTE:
		var h: String = String(hex)
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(46, 46)
		b.text = "∅" if h == "" else ""
		var sb: StyleBoxFlat = Kit.box(Color(h) if h != "" else Color(0.15, 0.15, 0.2), 10, Color.WHITE if String(Game.custom.get(key, "")) == h else Color(0, 0, 0, 0.6), 3)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.pressed.connect(_set_custom.bind(key, h))
		fl.add_child(b)


func _set_custom(key: String, hex: String) -> void:
	Game.custom[key] = hex
	Sfx.play("ui_click", -4.0)
	_commit()
	_refresh()


func _build_custom() -> void:
	var v: VBoxContainer = _card()
	var n: Label = Kit.label(Game.t("As cores valem para o seu personagem nas partidas (∅ = original). Em salas online os outros jogadores veem o visual padrão.", "Colors apply to your character in matches (∅ = original). In online rooms others see the default look."), 17, Color(0.8, 0.9, 1.0))
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(n)
	_color_row(v, Game.t("Uniforme (camisa)", "Kit (shirt)"), "kit")
	_color_row(v, Game.t("Shorts", "Shorts"), "shorts")
	_color_row(v, Game.t("Cabelo", "Hair"), "hair")
	_color_row(v, Game.t("Aura", "Aura"), "aura")
	var prev: TextureRect = TextureRect.new()
	prev.texture = Kit.portrait(Game.selected_char)
	prev.custom_minimum_size = Vector2(160, 200)
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(prev)
	v.add_child(Kit.button(Game.t("Restaurar original", "Reset to default"), _reset_custom, Vector2(260, 46), 18))


func _reset_custom() -> void:
	for k: String in ["kit", "shorts", "hair", "aura"]:
		Game.custom[k] = ""
	_refresh()
