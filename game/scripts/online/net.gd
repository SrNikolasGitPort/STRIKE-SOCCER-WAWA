extends Node
## Autoload "Net": multiplayer ENet com servidor AUTORITATIVO (o host simula tudo;
## clientes enviam apenas entradas e recebem snapshots). Sala = código (IP+porta
## codificados), descoberta em LAN por UDP e lista pública opcional via servidor
## mestre HTTP (tools/master_server.py). Nunca confia em posição/estado do cliente.

signal lobby_changed
signal status(text: String)
signal join_failed(reason: String)
signal rooms_updated

const DEFAULT_PORT: int = 24565
const DISCOVERY_PORT: int = 24566
const ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const SNAP_HZ: float = 20.0
const INPUT_HZ: float = 30.0
const MAX_NAME: int = 16

var role: String = ""                   # "" | host | client
var room: Dictionary = {}               # name, public, size, port, code, ip
var members: Dictionary = {}            # peer_id -> {name, char, team, fcode}
var found_rooms: Dictionary = {}        # "ip:port" -> {info..., seen}
var roster: Array = []                  # [{peer, char, team, idx, name}]
var m: Node = null                      # Match atual
var master_url: String = ""

var _peer: ENetMultiplayerPeer = null
var _udp_rx: PacketPeerUDP = null
var _udp_tx: PacketPeerUDP = null
var _bcast_t: float = 0.0
var _snap_t: float = 0.0
var _input_t: float = 0.0
var _latched: int = 0
var _thread: Thread = null
var _connect_timeout: float = 0.0
var _last_input_ms: Dictionary = {}
var _http: HTTPRequest = null
var _master_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg: String = "res://data/config/online.json"
	if FileAccess.file_exists(cfg):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(cfg))
		if parsed is Dictionary:
			master_url = String((parsed as Dictionary).get("master_url", ""))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_conn_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


# ------------------------------------------------------------ códigos
func friend_code() -> String:
	var seed_str: String = String(Game.google_user.get("sub", "")) if not Game.google_user.is_empty() else OS.get_unique_id() + Game.player_name
	var h: String = seed_str.sha256_text()
	var out: String = ""
	for i: int in range(8):
		out += String(ALPHABET[("0x" + h.substr(i * 2, 2)).hex_to_int() % ALPHABET.length()])
	return out.substr(0, 4) + "-" + out.substr(4, 4)


static func encode_room(ip: String, port: int) -> String:
	var parts: PackedStringArray = ip.split(".")
	if parts.size() != 4:
		return ""
	var v: int = 0
	for p: String in parts:
		v = (v << 8) | clampi(int(p), 0, 255)
	v = (v << 16) | clampi(port, 0, 65535)
	var out: String = ""
	for i: int in range(10):
		out = String(ALPHABET[v & 31]) + out
		v = v >> 5
	return out.substr(0, 5) + "-" + out.substr(5, 5)


static func decode_room(code: String) -> Dictionary:
	var c: String = code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	if c.length() != 10:
		return {}
	var v: int = 0
	for i: int in range(10):
		var idx: int = ALPHABET.find(c[i])
		if idx < 0:
			return {}
		v = (v << 5) | idx
	var port: int = v & 0xFFFF
	var ip32: int = (v >> 16) & 0xFFFFFFFF
	var ip: String = "%d.%d.%d.%d" % [(ip32 >> 24) & 255, (ip32 >> 16) & 255, (ip32 >> 8) & 255, ip32 & 255]
	if port == 0:
		return {}
	return {"ip": ip, "port": port}


func _local_ip() -> String:
	for a: String in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
				return a
	return "127.0.0.1"


# ---------------------------------------------------------------- host
func host_room(room_name: String, is_public: bool, size: int, port: int = DEFAULT_PORT) -> int:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var err: int = _peer.create_server(port, 7)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	role = "host"
	var ip: String = _local_ip()
	room = {"name": room_name.substr(0, 24), "public": is_public, "size": size, "port": port, "ip": ip, "code": encode_room(ip, port)}
	members = {1: {"name": _my_name(), "char": Game.selected_char, "team": 0, "fcode": friend_code()}}
	lobby_changed.emit()
	status.emit(Game.t("Sala criada. Tentando abrir a porta (UPnP)...", "Room created. Trying to open port (UPnP)..."))
	_thread = Thread.new()
	_thread.start(_upnp_work.bind(port))
	_open_discovery_tx()
	return OK


func _upnp_work(port: int) -> void:
	var upnp: UPNP = UPNP.new()
	var ext: String = ""
	if upnp.discover(2000, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS and upnp.get_gateway() != null and upnp.get_gateway().is_valid_gateway():
		upnp.add_port_mapping(port, port, "Strike Soccer WAWA", "UDP", 7200)
		ext = upnp.query_external_address()
	call_deferred("_on_upnp_done", ext)


func _on_upnp_done(ext_ip: String) -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	if role != "host":
		return
	if ext_ip != "" and ext_ip != "0.0.0.0":
		room["ext_ip"] = ext_ip
		room["code"] = encode_room(ext_ip, int(room["port"]))
		status.emit(Game.t("Porta aberta. Código válido pela internet.", "Port open. Code works over the internet."))
	else:
		status.emit(Game.t("UPnP indisponível: o código só funciona na mesma rede (LAN). Abra a porta UDP %d no roteador para jogar pela internet.", "UPnP unavailable: code only works on the same network (LAN). Forward UDP port %d on your router for internet play.") % int(room["port"]))
	lobby_changed.emit()
	_master_register()


func _my_name() -> String:
	var n: String = Game.player_name.strip_edges()
	if not Game.google_user.is_empty():
		n = String(Game.google_user.get("name", n))
	return n.substr(0, MAX_NAME) if n != "" else "Jogador"


# -------------------------------------------------------------- cliente
func join_by_code(code: String) -> bool:
	var d: Dictionary = decode_room(code)
	if d.is_empty():
		join_failed.emit(Game.t("Código inválido.", "Invalid code."))
		return false
	return join(String(d["ip"]), int(d["port"]))


func join(ip: String, port: int) -> bool:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var err: int = _peer.create_client(ip, port)
	if err != OK:
		_peer = null
		join_failed.emit(Game.t("Não foi possível iniciar a conexão.", "Could not start connection."))
		return false
	multiplayer.multiplayer_peer = _peer
	role = "client"
	_connect_timeout = 8.0
	status.emit(Game.t("Conectando...", "Connecting..."))
	return true


func leave() -> void:
	if _peer != null:
		_peer.close()
	multiplayer.multiplayer_peer = null
	_peer = null
	role = ""
	members.clear()
	roster.clear()
	room = {}
	m = null
	_close_udp()
	if _thread != null and not _thread.is_alive():
		_thread.wait_to_finish()
		_thread = null


func stop() -> void:
	leave()


func _on_connected() -> void:
	_connect_timeout = 0.0
	rpc_id(1, "rpc_hello", _my_name(), Game.selected_char, friend_code())


func _on_conn_failed() -> void:
	leave()
	join_failed.emit(Game.t("Falha ao conectar.", "Connection failed."))


func _on_server_gone() -> void:
	var was_in_match: bool = m != null
	leave()
	join_failed.emit(Game.t("O host saiu da sala.", "The host left the room."))
	if was_in_match:
		get_tree().paused = false
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file("res://scenes/menu/Main.tscn")


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if role != "host":
		return
	members.erase(id)
	if m != null:
		for i: int in range(roster.size()):
			if int(roster[i]["peer"]) == id:
				roster[i]["peer"] = 0
				m.call("convert_to_bot", i)
	_push_lobby()


# ----------------------------------------------------------------- lobby
@rpc("any_peer", "call_remote", "reliable")
func rpc_hello(pname: String, char_id: String, fcode: String) -> void:
	if role != "host" or m != null:
		return
	var id: int = multiplayer.get_remote_sender_id()
	if members.size() >= int(room["size"]) * 2:
		rpc_id(id, "rpc_reject", "full")
		_peer.disconnect_peer(id)
		return
	if Game.character(char_id).is_empty():
		char_id = "isagi"
	var counts: Array[int] = [0, 0]
	for k: Variant in members:
		counts[int((members[k] as Dictionary)["team"])] += 1
	members[id] = {"name": pname.strip_edges().substr(0, MAX_NAME), "char": char_id, "team": 0 if counts[0] <= counts[1] else 1, "fcode": fcode.substr(0, 9)}
	_push_lobby()


@rpc("authority", "call_remote", "reliable")
func rpc_reject(reason: String) -> void:
	leave()
	join_failed.emit(Game.t("Sala cheia.", "Room is full.") if reason == "full" else reason)


@rpc("any_peer", "call_remote", "reliable")
func rpc_set_char(char_id: String) -> void:
	if role != "host" or m != null:
		return
	var id: int = multiplayer.get_remote_sender_id()
	if members.has(id) and not Game.character(char_id).is_empty():
		(members[id] as Dictionary)["char"] = char_id
		_push_lobby()


@rpc("any_peer", "call_remote", "reliable")
func rpc_set_team(team: int) -> void:
	if role != "host" or m != null:
		return
	var id: int = multiplayer.get_remote_sender_id()
	_assign_team(id, team)


func _assign_team(id: int, team: int) -> void:
	if not members.has(id) or team < 0 or team > 1:
		return
	var count: int = 0
	for k: Variant in members:
		if int((members[k] as Dictionary)["team"]) == team and k != id:
			count += 1
	if count < int(room["size"]):
		(members[id] as Dictionary)["team"] = team
		_push_lobby()


func set_my_char(char_id: String) -> void:
	Game.selected_char = char_id
	if role == "host":
		(members[1] as Dictionary)["char"] = char_id
		_push_lobby()
	elif role == "client":
		rpc_id(1, "rpc_set_char", char_id)


func set_my_team(team: int) -> void:
	if role == "host":
		_assign_team(1, team)
	elif role == "client":
		rpc_id(1, "rpc_set_team", team)


func _push_lobby() -> void:
	if role == "host":
		rpc("rpc_lobby", members, room)
		lobby_changed.emit()


@rpc("authority", "call_remote", "reliable")
func rpc_lobby(mem: Dictionary, info: Dictionary) -> void:
	members = mem
	room = info
	lobby_changed.emit()


func start_game() -> void:
	if role != "host" or m != null:
		return
	var size: int = int(room["size"])
	var base_ids: Array = []
	for cid: Variant in Game.char_order():
		if not Game.is_evolution(String(cid)):
			base_ids.append(String(cid))
	var used: Array = []
	var built: Array = []
	for team: int in range(2):
		var idx: int = 0
		for k: Variant in members:
			var md: Dictionary = members[k]
			if int(md["team"]) == team and idx < size:
				built.append({"peer": int(k), "char": String(md["char"]), "team": team, "idx": idx, "name": String(md["name"])})
				used.append(String(md["char"]))
				idx += 1
		while idx < size:
			var pick: String = String(base_ids[randi() % base_ids.size()])
			var tries: int = 0
			while used.has(pick) and tries < 30:
				pick = String(base_ids[randi() % base_ids.size()])
				tries += 1
			used.append(pick)
			built.append({"peer": 0, "char": pick, "team": team, "idx": idx, "name": "CPU"})
			idx += 1
	_master_unregister()
	rpc("rpc_start", built, size)
	_enter_match(built, size)


@rpc("authority", "call_remote", "reliable")
func rpc_start(built: Array, size: int) -> void:
	_enter_match(built, size)


func _enter_match(built: Array, size: int) -> void:
	roster = built
	Game.online_roster = built
	Game.online_size = size
	Game.mode = "online"
	Game.online_role = role
	get_tree().change_scene_to_file("res://scenes/match/Match.tscn")


# ---------------------------------------------------------------- partida
func start_match(match_node: Node) -> void:
	m = match_node
	_close_udp()
	var my_id: int = multiplayer.get_unique_id()
	m.set("team_size", Game.online_size)
	for i: int in range(roster.size()):
		var e: Dictionary = roster[i]
		var kind: String = "puppet"
		if role == "host":
			if int(e["peer"]) == my_id:
				kind = "human"
			elif int(e["peer"]) == 0:
				kind = "bot"
			else:
				kind = "remote"
		var p: Node = m.call("spawn_player", String(e["char"]), int(e["team"]), int(e["idx"]), kind)
		if role == "client" and int(e["peer"]) == my_id:
			p.set("is_human", true)
			p.set("cam_side", 1.0 if int(e["team"]) == 0 else -1.0)
			m.set("human", p)
		if kind == "puppet":
			p.set("display_name", String(e["name"]) if int(e["peer"]) != 0 else p.get("display_name"))
	if role == "client":
		(m.get("ball") as RigidBody3D).freeze = true
		(m.get("ball") as RigidBody3D).freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC


func send_event(d: Dictionary) -> void:
	if role == "host" and m != null:
		rpc("rpc_event", d)


@rpc("authority", "call_remote", "reliable")
func rpc_event(d: Dictionary) -> void:
	if m == null:
		return
	m.call("on_net_event", d)


func _physics_process(delta: float) -> void:
	if _connect_timeout > 0.0:
		_connect_timeout -= delta
		if _connect_timeout <= 0.0 and role == "client" and _peer != null and _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			leave()
			join_failed.emit(Game.t("Tempo esgotado ao conectar.", "Connection timed out."))
	if m == null or not is_instance_valid(m):
		return
	if role == "client":
		_latched |= _read_buttons_edges()
		_input_t -= delta
		if _input_t <= 0.0:
			_input_t = 1.0 / INPUT_HZ
			_send_input()
	elif role == "host":
		_snap_t -= delta
		if _snap_t <= 0.0:
			_snap_t = 1.0 / SNAP_HZ
			_send_snapshot()


func _read_buttons_edges() -> int:
	var b: int = 0
	if Input.is_action_just_pressed("pass"):
		b |= 4
	if Input.is_action_just_pressed("lob"):
		b |= 8
	for i: int in range(6):
		if Input.is_action_just_pressed("skill_%d" % (i + 1)):
			b |= 16 << i
	return b


func _send_input() -> void:
	var me: Node = m.get("human")
	if me == null:
		return
	var iv: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam: float = float(me.get("cam_side"))
	var wish: Vector3 = Vector3(-iv.y, 0.0, iv.x) * cam
	var bits: int = _latched
	_latched = 0
	if Input.is_action_pressed("sprint"):
		bits |= 1
	if Input.is_action_pressed("shoot"):
		bits |= 2
	rpc_id(1, "rpc_input", wish.x, wish.z, bits)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_input(wx: float, wz: float, bits: int) -> void:
	if role != "host" or m == null:
		return
	var id: int = multiplayer.get_remote_sender_id()
	var now: int = Time.get_ticks_msec()
	if now - int(_last_input_ms.get(id, 0)) < 15:
		return  # limite de taxa (anti-flood)
	_last_input_ms[id] = now
	var players: Array = m.get("players")
	for i: int in range(roster.size()):
		if int(roster[i]["peer"]) == id and i < players.size():
			var p: Node = players[i]
			var w: Vector3 = Vector3(clampf(wx, -1.0, 1.0), 0.0, clampf(wz, -1.0, 1.0)).limit_length(1.0)
			p.set("in_wish", w)
			p.set("in_sprint", bits & 1 != 0)
			p.set("in_shoot_held", bits & 2 != 0)
			if bits & 4 != 0:
				p.set("in_pass", true)
			if bits & 8 != 0:
				p.set("in_lob", true)
			var arr: Array[bool] = p.get("in_skill")
			for s: int in range(6):
				if bits & (16 << s) != 0:
					arr[s] = true


func _send_snapshot() -> void:
	var ball: RigidBody3D = m.get("ball")
	var flat: PackedFloat32Array = PackedFloat32Array()
	var bp: Vector3 = ball.global_position
	var bv: Vector3 = ball.linear_velocity
	flat.append_array([bp.x, bp.y, bp.z, bv.x, bv.y, bv.z, float(m.get("time_left")), float(m.get("state"))])
	var extra: Dictionary = {}
	var players: Array = m.get("players")
	for i: int in range(players.size()):
		var p: Node = players[i]
		var pos: Vector3 = (p as Node3D).global_position
		var f: Vector3 = p.get("facing")
		flat.append_array([pos.x, pos.y, pos.z, atan2(-f.x, -f.z), float(p.get("stun_t"))])
		if i < roster.size() and int(roster[i]["peer"]) > 1:
			var info: PackedFloat32Array = PackedFloat32Array([float(p.get("stamina")), float(p.get("flow")), float(p.get("awake_left")), 1.0 if bool(p.get("awakened")) else 0.0])
			for s: int in range(6):
				info.append(float(p.call("cooldown_left", s)))
			extra[i] = info
	rpc("rpc_snap", flat, extra)


@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_snap(flat: PackedFloat32Array, extra: Dictionary) -> void:
	if m == null or not is_instance_valid(m) or flat.size() < 8:
		return
	var ball: RigidBody3D = m.get("ball")
	var target: Vector3 = Vector3(flat[0], flat[1], flat[2])
	ball.global_position = ball.global_position.lerp(target, 0.6) if ball.global_position.distance_to(target) < 6.0 else target
	m.set("time_left", flat[6])
	var players: Array = m.get("players")
	for i: int in range(players.size()):
		var o: int = 8 + i * 5
		if o + 4 >= flat.size():
			break
		var p: Node = players[i]
		p.set("net_pos", Vector3(flat[o], flat[o + 1], flat[o + 2]))
		p.set("net_yaw", flat[o + 3])
		p.set("stun_t", flat[o + 4])
		if extra.has(i) and p == m.get("human"):
			var info: PackedFloat32Array = extra[i]
			p.set("stamina", info[0])
			p.set("flow", info[1])
			p.set("awake_left", info[2])
			var was: bool = bool(p.get("awakened"))
			p.set("awakened", info[3] > 0.5)
			if was and info[3] < 0.5:
				p.call("end_awakening")
			var cds: Dictionary = {}
			for s: int in range(6):
				var sid: String = String(p.call("skill_at", s))
				if sid != "":
					cds[sid] = info[4 + s]
			p.set("cooldowns", cds)


# ------------------------------------------------- descoberta em LAN
func _open_discovery_tx() -> void:
	_udp_tx = PacketPeerUDP.new()
	_udp_tx.set_broadcast_enabled(true)
	_udp_tx.set_dest_address("255.255.255.255", DISCOVERY_PORT)


func start_discovery() -> void:
	if _udp_rx != null:
		return
	_udp_rx = PacketPeerUDP.new()
	if _udp_rx.bind(DISCOVERY_PORT) != OK:
		_udp_rx = null
		return
	found_rooms.clear()


func stop_discovery() -> void:
	if _udp_rx != null:
		_udp_rx.close()
		_udp_rx = null


func _close_udp() -> void:
	if _udp_tx != null:
		_udp_tx.close()
		_udp_tx = null
	stop_discovery()


func _process(delta: float) -> void:
	if role == "host" and _udp_tx != null and bool(room.get("public", false)) and m == null:
		_bcast_t -= delta
		if _bcast_t <= 0.0:
			_bcast_t = 1.5
			var info: Dictionary = {"g": "SSW", "n": room["name"], "p": room["port"], "s": room["size"], "c": members.size(), "h": members[1]["name"], "f": _friend_list()}
			_udp_tx.put_packet(JSON.stringify(info).to_utf8_buffer())
	if _udp_rx != null:
		while _udp_rx.get_available_packet_count() > 0:
			var pkt: PackedByteArray = _udp_rx.get_packet()
			var from: String = _udp_rx.get_packet_ip()
			var parsed: Variant = JSON.parse_string(pkt.get_string_from_utf8())
			if parsed is Dictionary and (parsed as Dictionary).get("g", "") == "SSW":
				var d: Dictionary = parsed
				d["ip"] = from
				d["seen"] = Time.get_ticks_msec()
				d["code"] = encode_room(from, int(d.get("p", DEFAULT_PORT)))
				found_rooms["%s:%d" % [from, int(d.get("p", 0))]] = d
				rooms_updated.emit()
		var now: int = Time.get_ticks_msec()
		for k: Variant in found_rooms.keys():
			if now - int((found_rooms[k] as Dictionary)["seen"]) > 5000:
				found_rooms.erase(k)
	if _master_t > 0.0:
		_master_t -= delta


func _friend_list() -> Array:
	var out: Array = []
	for k: Variant in members:
		out.append(String((members[k] as Dictionary).get("fcode", "")))
	return out


# ---------------------------------------------------- servidor mestre
func _http_node() -> HTTPRequest:
	if _http == null:
		_http = HTTPRequest.new()
		_http.timeout = 6.0
		add_child(_http)
	return _http


func _master_register() -> void:
	if master_url == "" or not bool(room.get("public", false)):
		return
	var body: String = JSON.stringify({"name": room["name"], "code": room["code"], "size": room["size"], "players": members.size(), "host": members[1]["name"], "friends": _friend_list()})
	var h: HTTPRequest = HTTPRequest.new()
	h.timeout = 6.0
	add_child(h)
	h.request_completed.connect(func(_r: int, _c: int, _hd: PackedStringArray, _b: PackedByteArray) -> void: h.queue_free())
	h.request(master_url.rstrip("/") + "/rooms", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _master_unregister() -> void:
	if master_url == "" or room.is_empty():
		return
	var h: HTTPRequest = HTTPRequest.new()
	h.timeout = 6.0
	add_child(h)
	h.request_completed.connect(func(_r: int, _c: int, _hd: PackedStringArray, _b: PackedByteArray) -> void: h.queue_free())
	h.request(master_url.rstrip("/") + "/rooms/" + String(room["code"]), [], HTTPClient.METHOD_DELETE)


func fetch_public_rooms() -> void:
	if master_url == "":
		return
	var h: HTTPRequest = _http_node()
	if h.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	if not h.request_completed.is_connected(_on_rooms_fetched):
		h.request_completed.connect(_on_rooms_fetched)
	h.request(master_url.rstrip("/") + "/rooms")


func _on_rooms_fetched(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Array:
		for r: Variant in parsed:
			if r is Dictionary:
				var d: Dictionary = r
				var dec: Dictionary = decode_room(String(d.get("code", "")))
				if dec.is_empty():
					continue
				d["ip"] = dec["ip"]
				d["p"] = dec["port"]
				d["n"] = d.get("name", "?")
				d["s"] = d.get("size", 2)
				d["c"] = d.get("players", 1)
				d["h"] = d.get("host", "?")
				d["f"] = d.get("friends", [])
				d["seen"] = Time.get_ticks_msec()
				found_rooms["%s:%d" % [dec["ip"], int(dec["port"])]] = d
		rooms_updated.emit()
