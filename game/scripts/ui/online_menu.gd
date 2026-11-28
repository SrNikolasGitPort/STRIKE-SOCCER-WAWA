extends Control
## Menu Multiplayer: login Google (opcional), criar sala pública/privada, entrar por
## código, salas encontradas (LAN / lista pública), amigos e lobby da sala.

signal back
signal pick_character
signal open_profile

const Kit = preload("res://scripts/ui/ui_kit.gd")
const GoogleAuth = preload("res://scripts/online/google_auth.gd")

var _body: VBoxContainer
var _msg: Label
var _auth: Node = null
var _tab: String = "join"
var _name_edit: LineEdit
var _code_edit: LineEdit
var _public_check: CheckButton
var _size: int = 2
var _rooms_box: VBoxContainer
var _login_label: Label
var _code_label: Label


func _ready() -> void:
	Kit.full(self)
	Kit.background(self)
	Net.lobby_changed.connect(_refresh)
	Net.status.connect(_say)
	Net.join_failed.connect(_on_join_failed)
	Net.rooms_updated.connect(_fill_rooms)
	Net.start_discovery()
	Net.fetch_public_rooms()
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
	top.add_child(Kit.label("MULTIPLAYER", 34, Kit.GOLD))
	_msg = Kit.label("", 18, Color(1.0, 0.9, 0.6))
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_msg)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)
	_refresh()


func _exit_tree() -> void:
	Net.stop_discovery()


func _say(t: String) -> void:
	if _msg != null:
		_msg.text = t


func _on_profile() -> void:
	open_profile.emit()


func _on_back() -> void:
	if Net.role != "":
		Net.leave()
	back.emit()


func _panel(title: String) -> VBoxContainer:
	var p: PanelContainer = PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(p)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	if title != "":
		v.add_child(Kit.label(title, 24, Kit.GOLD))
	return v


func _refresh() -> void:
	if _body == null:
		return
	for c: Node in _body.get_children():
		c.queue_free()
	if Net.role != "":
		_build_lobby()
		return
	_build_account()
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	_body.add_child(tabs)
	for t: Array in [["join", Game.t("Entrar", "Join")], ["create", Game.t("Criar sala", "Create room")], ["friends", Game.t("Amigos", "Friends")]]:
		var tid: String = String(t[0])
		tabs.add_child(Kit.button(String(t[1]), _set_tab.bind(tid), Vector2(170, 46), 20))
	match _tab:
		"create":
			_build_create()
		"friends":
			_build_friends()
		_:
			_build_join()


# ----------------------------------------------------------------- conta
func _build_account() -> void:
	var v: VBoxContainer = _panel(Game.t("Conta", "Account"))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var signed: bool = not Game.google_user.is_empty()
	_login_label = Kit.label((Game.t("Google: ", "Google: ") + String(Game.google_user.get("name", ""))) if signed else Game.t("Jogando como convidado", "Playing as guest"), 20)
	_login_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_login_label)
	if signed:
		row.add_child(Kit.button(Game.t("Sair da conta", "Sign out"), _sign_out, Vector2(200, 46), 18))
	else:
		row.add_child(Kit.button(Game.t("Entrar com Google", "Sign in with Google"), _start_google, Vector2(260, 46), 18))
	v.add_child(Kit.button(Game.t("Meu perfil / Personalizar", "My profile / Customize"), _on_profile, Vector2(300, 46), 18))
	v.add_child(Kit.label(Game.t("Seu código de amigo: ", "Your friend code: ") + Net.friend_code(), 18, Color(0.7, 0.9, 1.0)))
	var ne: HBoxContainer = HBoxContainer.new()
	v.add_child(ne)
	ne.add_child(Kit.label(Game.t("Apelido: ", "Nickname: "), 18))
	_name_edit = LineEdit.new()
	_name_edit.text = Game.player_name
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(220, 40)
	_name_edit.text_changed.connect(_on_name_changed)
	ne.add_child(_name_edit)


func _set_tab(tid: String) -> void:
	_tab = tid
	_refresh()


func _sign_out() -> void:
	Game.google_user = {}
	Game.save_game()
	_refresh()


func _refresh_rooms() -> void:
	Net.fetch_public_rooms()
	_fill_rooms()


func _set_room_size(n: int) -> void:
	_size = n
	_say(Game.t("Formato: %dv%d", "Format: %dv%d") % [n, n])


func _create_room(room_name: LineEdit) -> void:
	var err: int = Net.host_room(room_name.text, _public_check.button_pressed, _size)
	if err != OK:
		_say(Game.t("Não foi possível criar a sala (porta em uso?).", "Could not create room (port in use?)."))


func _add_friend(code: LineEdit, fname: LineEdit) -> void:
	var c: String = code.text.strip_edges().to_upper()
	if c.length() == 9 and c[4] == "-":
		Game.friends.append({"code": c, "name": fname.text.strip_edges().substr(0, 16)})
		Game.save_game()
		_refresh()
	else:
		_say(Game.t("Código inválido.", "Invalid code."))


func _remove_friend(i: int) -> void:
	Game.friends.remove_at(i)
	Game.save_game()
	_refresh()


func _switch_team() -> void:
	var mine: int = int((Net.members.get(multiplayer.get_unique_id(), {"team": 0}) as Dictionary)["team"])
	Net.set_my_team(1 - mine)


func _leave_room() -> void:
	Net.leave()
	_refresh()


func _on_join_failed(t: String) -> void:
	_say(t)
	_refresh()


func _on_code_ready(code: String, url: String) -> void:
	_say(Game.t("Abra %s e digite o código: %s  (o navegador foi aberto)", "Open %s and enter code: %s  (browser opened)") % [url, code])


func _on_auth_finished(ok: bool, text: String) -> void:
	_say(text)
	if ok:
		_refresh()


func _on_name_changed(t: String) -> void:
	Game.player_name = t
	Game.save_game()


func _start_google() -> void:
	if not GoogleAuth.configured():
		_say(Game.t("Login Google não configurado neste build. Veja docs/SETUP.md (Google Cloud → OAuth 'TV e dispositivos limitados').", "Google login is not configured in this build. See docs/SETUP.md."))
		return
	if _auth != null:
		_auth.call("cancel")
		_auth.queue_free()
	_auth = GoogleAuth.new()
	add_child(_auth)
	_auth.connect("code_ready", _on_code_ready)
	_auth.connect("finished", _on_auth_finished)
	_auth.call("start")


# ----------------------------------------------------------------- entrar
func _build_join() -> void:
	var v: VBoxContainer = _panel(Game.t("Entrar com código", "Join with code"))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "XXXXX-XXXXX"
	_code_edit.custom_minimum_size = Vector2(260, 48)
	_code_edit.max_length = 12
	row.add_child(_code_edit)
	row.add_child(Kit.button(Game.t("Entrar", "Join"), func() -> void: Net.join_by_code(_code_edit.text), Vector2(160, 48), 22))
	var rv: VBoxContainer = _panel(Game.t("Salas públicas", "Public rooms"))
	var rr: HBoxContainer = HBoxContainer.new()
	rv.add_child(rr)
	rr.add_child(Kit.button(Game.t("Atualizar", "Refresh"), _refresh_rooms, Vector2(160, 40), 18))
	rr.add_child(Kit.label(Game.t("  (LAN automática; internet se houver servidor mestre)", "  (LAN auto; internet if a master server is set)"), 14, Color(0.7, 0.8, 1.0)))
	_rooms_box = VBoxContainer.new()
	_rooms_box.add_theme_constant_override("separation", 6)
	rv.add_child(_rooms_box)
	_fill_rooms()


func _fill_rooms() -> void:
	if _rooms_box == null or not is_instance_valid(_rooms_box):
		return
	for c: Node in _rooms_box.get_children():
		c.queue_free()
	var my_friends: Array = []
	for f: Variant in Game.friends:
		my_friends.append(String((f as Dictionary).get("code", "")))
	var any: bool = false
	for k: Variant in Net.found_rooms:
		var d: Dictionary = Net.found_rooms[k]
		any = true
		var has_friend: bool = false
		for fc: Variant in d.get("f", []):
			if my_friends.has(String(fc)):
				has_friend = true
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var title: String = "%s%s — %s  (%d/%d)  %dv%d" % ["★ " if has_friend else "", String(d.get("n", "?")), String(d.get("h", "?")), int(d.get("c", 1)), int(d.get("s", 2)) * 2, int(d.get("s", 2)), int(d.get("s", 2))]
		var l: Label = Kit.label(title, 18)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var ip: String = String(d.get("ip", ""))
		var port: int = int(d.get("p", Net.DEFAULT_PORT))
		row.add_child(Kit.button(Game.t("Entrar", "Join"), func() -> void: Net.join(ip, port), Vector2(120, 40), 18))
		_rooms_box.add_child(row)
	if not any:
		_rooms_box.add_child(Kit.label(Game.t("Nenhuma sala encontrada.", "No rooms found."), 16, Color(0.7, 0.8, 1.0)))


# ------------------------------------------------------------------ criar
func _build_create() -> void:
	var v: VBoxContainer = _panel(Game.t("Criar sala", "Create room"))
	var ne: HBoxContainer = HBoxContainer.new()
	v.add_child(ne)
	ne.add_child(Kit.label(Game.t("Nome da sala: ", "Room name: "), 18))
	var room_name: LineEdit = LineEdit.new()
	room_name.text = Game.player_name + "'s room"
	room_name.max_length = 24
	room_name.custom_minimum_size = Vector2(280, 40)
	ne.add_child(room_name)
	_public_check = CheckButton.new()
	_public_check.text = Game.t("Sala pública (aparece na lista)", "Public room (listed)")
	_public_check.button_pressed = true
	v.add_child(_public_check)
	var sz: HBoxContainer = HBoxContainer.new()
	sz.add_theme_constant_override("separation", 8)
	v.add_child(sz)
	for n: int in [2, 4]:
		var b: Button = Kit.button("%dv%d" % [n, n], _set_room_size.bind(n), Vector2(100, 44), 20)
		sz.add_child(b)
	v.add_child(Kit.button(Game.t("Criar", "Create"), _create_room.bind(room_name), Vector2(220, 52), 22))
	v.add_child(Kit.label(Game.t("Dica: pelo celular/PC no mesmo Wi-Fi funciona direto; pela internet o jogo tenta abrir a porta via UPnP.", "Tip: same Wi-Fi works directly; over the internet the game tries UPnP."), 14, Color(0.7, 0.8, 1.0)))


# ----------------------------------------------------------------- amigos
func _build_friends() -> void:
	var v: VBoxContainer = _panel(Game.t("Amigos", "Friends"))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var code: LineEdit = LineEdit.new()
	code.placeholder_text = Game.t("Código do amigo (XXXX-XXXX)", "Friend code (XXXX-XXXX)")
	code.custom_minimum_size = Vector2(240, 44)
	row.add_child(code)
	var fname: LineEdit = LineEdit.new()
	fname.placeholder_text = Game.t("Apelido", "Nickname")
	fname.custom_minimum_size = Vector2(160, 44)
	row.add_child(fname)
	row.add_child(Kit.button(Game.t("Adicionar", "Add"), _add_friend.bind(code, fname), Vector2(150, 44), 18))
	if Game.friends.is_empty():
		v.add_child(Kit.label(Game.t("Nenhum amigo ainda. Troque códigos com seus amigos; salas onde eles estão aparecem com ★.", "No friends yet. Exchange codes; rooms with friends show a ★."), 16, Color(0.7, 0.8, 1.0)))
	for i: int in range(Game.friends.size()):
		var fd: Dictionary = Game.friends[i]
		var fr: HBoxContainer = HBoxContainer.new()
		fr.add_child(Kit.label("%s   (%s)" % [String(fd.get("name", "?")), String(fd.get("code", ""))], 18))
		var sp: Control = Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fr.add_child(sp)
		fr.add_child(Kit.button(Game.t("Remover", "Remove"), _remove_friend.bind(i), Vector2(130, 38), 16))
		v.add_child(fr)


# ------------------------------------------------------------------ lobby
func _build_lobby() -> void:
	var v: VBoxContainer = _panel(Game.t("Sala: ", "Room: ") + String(Net.room.get("name", "")))
	var code: String = String(Net.room.get("code", ""))
	if Net.role == "host":
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		_code_label = Kit.label(Game.t("Código: ", "Code: ") + code + ("   (pública)" if bool(Net.room.get("public", false)) else "   (privada)"), 24, Color(0.6, 1.0, 0.8))
		row.add_child(_code_label)
		row.add_child(Kit.button(Game.t("Copiar", "Copy"), func() -> void: DisplayServer.clipboard_set(code), Vector2(120, 40), 18))
	for team: int in range(2):
		v.add_child(Kit.label(Game.t("TIME AZUL", "BLUE TEAM") if team == 0 else Game.t("TIME VERMELHO", "RED TEAM"), 20, Color(0.5, 0.75, 1.0) if team == 0 else Color(1.0, 0.5, 0.5)))
		for k: Variant in Net.members:
			var md: Dictionary = Net.members[k]
			if int(md["team"]) == team:
				var cn: String = String(Game.character(String(md["char"])).get("name", md["char"]))
				v.add_child(Kit.label("  %s%s — %s" % [String(md["name"]), " (host)" if int(k) == 1 else "", cn], 18))
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	v.add_child(actions)
	actions.add_child(Kit.button(Game.t("Trocar personagem", "Change character"), func() -> void: pick_character.emit(), Vector2(240, 48), 18))
	actions.add_child(Kit.button(Game.t("Trocar de time", "Switch team"), _switch_team, Vector2(200, 48), 18))
	if Net.role == "host":
		actions.add_child(Kit.button(Game.t("INICIAR PARTIDA", "START MATCH"), func() -> void: Net.start_game(), Vector2(260, 52), 22))
	else:
		actions.add_child(Kit.label(Game.t("Aguardando o host iniciar...", "Waiting for the host to start..."), 18, Color(0.8, 0.9, 1.0)))
	actions.add_child(Kit.button(Game.t("Sair da sala", "Leave room"), _leave_room, Vector2(180, 48), 18))
