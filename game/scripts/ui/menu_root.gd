extends Control
## Raiz dos menus: principal, seleção de modo, seleção de personagem, multiplayer
## e configurações. Cada tela é construída por código (sem .tscn manual).

const Kit = preload("res://scripts/ui/ui_kit.gd")
const CharSelectScript = preload("res://scripts/ui/char_select.gd")
const OnlineMenuScript = preload("res://scripts/ui/online_menu.gd")
const ProfileScript = preload("res://scripts/ui/profile_menu.gd")

var _current: Control = null
var _pending_mode: String = ""


func _ready() -> void:
	theme = Kit.make_theme()
	Kit.full(self)
	Sfx.music("menu_theme")
	Sfx.crowd(false)
	Engine.time_scale = 1.0
	get_tree().paused = false
	if Net.role != "" and Net.m == null:
		_go("online")
	else:
		_go("main")


func _go(screen: String) -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	match screen:
		"mode":
			_current = _build_modes()
		"settings":
			_current = _build_settings()
		"online":
			_current = _build_online()
		"select":
			_current = _build_select(false)
		"profile":
			_current = _build_profile_screen()
		"lobby_pick":
			_current = _build_select(true)
		_:
			_current = _build_main()
	add_child(_current)
	_current.modulate.a = 0.0
	create_tween().tween_property(_current, "modulate:a", 1.0, 0.25)
	for ch: Node in _current.get_children():
		if ch is VBoxContainer:
			Kit.animate_in(ch)


# ------------------------------------------------------------------ principal
func _build_main() -> Control:
	var c: Control = Control.new()
	Kit.full(c)
	Kit.background(c)
	var center: VBoxContainer = VBoxContainer.new()
	Kit.safe_full(center)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 12)
	c.add_child(center)
	var logo_holder: CenterContainer = CenterContainer.new()
	center.add_child(logo_holder)
	var logo: TextureRect = Kit.logo(logo_holder, minf(get_viewport_rect().size.x * 0.7, 760.0))
	logo.visible = true
	logo.pivot_offset = logo.custom_minimum_size / 2.0
	var pulse: Tween = logo.create_tween().set_loops()
	pulse.tween_property(logo, "scale", Vector2(1.03, 1.03), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(logo, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var info: Label = Kit.label("%s   •   %s %d   •   🪙 %d" % [Game.player_name, Game.t("Nível", "Level"), Game.level(), Game.coins], 22, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	center.add_child(info)
	var items: Array = [
		[Game.t("JOGAR", "PLAY"), "mode"],
		[Game.t("PERSONAGENS", "CHARACTERS"), "select"],
		["MULTIPLAYER", "online"],
		[Game.t("PERFIL", "PROFILE"), "profile"],
		[Game.t("CONFIGURAÇÕES", "SETTINGS"), "settings"],
	]
	for it: Array in items:
		var holder: CenterContainer = CenterContainer.new()
		center.add_child(holder)
		holder.add_child(Kit.button(String(it[0]), _on_nav.bind(String(it[1])), Vector2(420, 60), 28))
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		var q: CenterContainer = CenterContainer.new()
		center.add_child(q)
		q.add_child(Kit.button(Game.t("SAIR", "QUIT"), _on_quit, Vector2(420, 50), 22))
	var ver: Label = Kit.label("v" + Config.VERSION + "  •  Fan game não oficial", 14, Color(0.7, 0.8, 1.0, 0.8), HORIZONTAL_ALIGNMENT_RIGHT)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -420.0
	ver.offset_top = -30.0
	ver.offset_right = -12.0
	ver.offset_bottom = -6.0
	c.add_child(ver)
	return c


func _on_nav(screen: String) -> void:
	_go(screen)


func _on_quit() -> void:
	Game.save_game()
	get_tree().quit()


# ------------------------------------------------------------------- modos
func _build_modes() -> Control:
	var c: Control = Control.new()
	Kit.full(c)
	Kit.background(c)
	var box: VBoxContainer = VBoxContainer.new()
	Kit.safe_full(box)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	c.add_child(box)
	box.add_child(Kit.label(Game.t("ESCOLHA O MODO", "CHOOSE MODE"), 44, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var modes: Array = [
		["2v2", "2 vs 2", Game.t("Partida rápida de dupla contra bots", "Quick duo match vs bots")],
		["4v4", "4 vs 4", Game.t("Partida completa de 4 contra 4", "Full 4v4 match")],
		["training", Game.t("TREINAMENTO", "TRAINING"), Game.t("Sem adversários: treine chutes e skills (T = encher Fluxo)", "No opponents: practice shots and skills (T = Awaken)")],
		["online", "MULTIPLAYER", Game.t("Salas públicas/privadas, amigos e login Google", "Public/private rooms, friends and Google login")],
	]
	for m: Array in modes:
		var row: CenterContainer = CenterContainer.new()
		box.add_child(row)
		var b: Button = Kit.button("%s\n%s" % [String(m[1]), String(m[2])], _on_mode.bind(String(m[0])), Vector2(620, 84), 24)
		row.add_child(b)
	var back_row: CenterContainer = CenterContainer.new()
	box.add_child(back_row)
	back_row.add_child(Kit.button("◀ " + Game.t("Voltar", "Back"), _on_nav.bind("main"), Vector2(220, 50), 20))
	return c


func _on_mode(mode: String) -> void:
	if mode == "online":
		_go("online")
		return
	_pending_mode = mode
	_go("select")


func _build_select(for_lobby: bool) -> Control:
	var cs: Control = CharSelectScript.new()
	cs.set("play_label", Game.t("CONFIRMAR", "CONFIRM") if for_lobby else (Game.t("JOGAR", "PLAY") if _pending_mode != "" else Game.t("SELECIONAR", "SELECT")))
	cs.connect("back", _on_nav.bind("online" if for_lobby else ("mode" if _pending_mode != "" else "main")))
	cs.connect("chosen", _on_chosen.bind(for_lobby))
	return cs


func _on_chosen(char_id: String, for_lobby: bool) -> void:
	if for_lobby:
		Net.set_my_char(char_id)
		_go("online")
		return
	if _pending_mode == "":
		_go("main")
		return
	Game.mode = _pending_mode
	Game.online_role = ""
	Game.selected_char = char_id
	Game.save_game()
	get_tree().change_scene_to_file("res://scenes/match/Match.tscn")


# ------------------------------------------------------------------ online
func _build_profile_screen() -> Control:
	var o: Control = ProfileScript.new()
	o.connect("back", _on_nav.bind("main"))
	return o


func _build_online() -> Control:
	var o: Control = OnlineMenuScript.new()
	o.connect("back", _on_nav.bind("main"))
	o.connect("open_profile", _on_nav.bind("profile"))
	o.connect("pick_character", _on_pick_lobby)
	return o


func _on_pick_lobby() -> void:
	_pending_mode = ""
	_go("lobby_pick")


# ------------------------------------------------------------ configurações
func _build_settings() -> Control:
	var c: Control = Control.new()
	Kit.full(c)
	Kit.background(c)
	var margin: MarginContainer = MarginContainer.new()
	Kit.safe_full(margin)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	c.add_child(margin)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var top: HBoxContainer = HBoxContainer.new()
	root.add_child(top)
	top.add_child(Kit.button("◀ " + Game.t("Voltar", "Back"), _on_settings_back, Vector2(150, 48), 20))
	top.add_child(Kit.label("  " + Game.t("CONFIGURAÇÕES", "SETTINGS"), 34, Kit.GOLD))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var lang_row: HBoxContainer = HBoxContainer.new()
	lang_row.add_child(Kit.label(Game.t("Idioma: ", "Language: "), 22))
	lang_row.add_child(Kit.button("Português", _set_lang.bind("pt"), Vector2(160, 44), 20))
	lang_row.add_child(Kit.button("English", _set_lang.bind("en"), Vector2(160, 44), 20))
	v.add_child(lang_row)

	for entry: Array in [["vol_master", "Volume geral", "Master volume"], ["vol_music", "Música", "Music"], ["vol_sfx", "Efeitos", "Effects"]]:
		var row: HBoxContainer = HBoxContainer.new()
		var l: Label = Kit.label(Game.t(String(entry[1]), String(entry[2])), 20)
		l.custom_minimum_size = Vector2(200, 0)
		row.add_child(l)
		var sl: HSlider = HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(Game.settings[String(entry[0])])
		sl.custom_minimum_size = Vector2(320, 30)
		sl.value_changed.connect(_on_volume.bind(String(entry[0])))
		row.add_child(sl)
		v.add_child(row)

	var q_row: HBoxContainer = HBoxContainer.new()
	q_row.add_child(Kit.label(Game.t("Qualidade gráfica: ", "Graphics quality: "), 22))
	var q_names: Array = [Game.t("Auto", "Auto"), Game.t("Baixa", "Low"), Game.t("Média", "Medium"), Game.t("Alta", "High")]
	for i: int in range(4):
		q_row.add_child(Kit.button(String(q_names[i]), _set_quality.bind(i - 1), Vector2(110, 44), 18))
	v.add_child(q_row)

	var cut: CheckButton = CheckButton.new()
	cut.text = Game.t("Reduzir cutscenes de skill (sem câmera lenta/letterbox)", "Reduce skill cutscenes (no slow-mo/letterbox)")
	cut.button_pressed = bool(Game.settings.get("reduce_cutscenes", false))
	cut.toggled.connect(_on_toggle.bind("reduce_cutscenes"))
	v.add_child(cut)
	var fps: CheckButton = CheckButton.new()
	fps.text = Game.t("Mostrar FPS", "Show FPS")
	fps.button_pressed = bool(Game.settings.get("show_fps", false))
	fps.toggled.connect(_on_toggle.bind("show_fps"))
	v.add_child(fps)

	v.add_child(Kit.label(Game.t("Controles (PC): WASD mover • botão direito do mouse/setas girar câmera • roda zoom • Shift sprint • Espaço chute (segure) • E passe • F passe alto • Q drible • C desarme • 1-3 skills • G despertar (barra de Fluxo cheia) • 4-6 skills de Despertar • T enche o Fluxo (treino) • Esc pausa", "Controls (PC): WASD move • right mouse/arrows rotate camera • wheel zoom • Shift sprint • Space shoot (hold) • E pass • F lob • Q dribble • C tackle • 1-3 skills • G awaken (Flow bar full) • 4-6 Awakening skills • T fill Flow (training) • Esc pause"), 16, Color(0.8, 0.9, 1.0)))
	v.add_child(Kit.button(Game.t("Apagar progresso", "Reset progress"), _on_reset, Vector2(260, 44), 18))
	var cred: Label = Kit.label("Strike Soccer WAWA v%s — fan game não oficial de Blue Lock (obra de Muneyuki Kaneshiro e Kota Nomura). Sem fins lucrativos. Fonte Inter (OFL). Veja CREDITS.md." % Config.VERSION, 14, Color(0.7, 0.8, 1.0))
	cred.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cred.custom_minimum_size = Vector2(500, 0)
	v.add_child(cred)
	return c


func _on_settings_back() -> void:
	Game.save_game()
	_go("main")


func _set_lang(l: String) -> void:
	Game.settings["lang"] = l
	Game.save_game()
	_go("settings")


func _on_volume(value: float, key: String) -> void:
	Game.settings[key] = value
	Sfx.apply_volumes()


func _set_quality(level: int) -> void:
	Game.settings["quality"] = level
	if level >= 0:
		Config.quality_level = level
	else:
		Config.quality_level = int(Config.f("quality.auto_mobile_level")) if OS.has_feature("mobile") else int(Config.f("quality.auto_desktop_level"))
	Game.save_game()


func _on_toggle(on: bool, key: String) -> void:
	Game.settings[key] = on
	Game.save_game()


func _on_reset() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.coins = 300
	Game.xp = 0
	Game.unlocked = {}
	Game.quest_progress = {}
	Game.quest_done = {}
	Game.friends = []
	Game.google_user = {}
	for cid: String in Game.STARTERS:
		Game.unlocked[cid] = true
	Game.selected_char = "isagi"
	Game.save_game()
	_go("main")
