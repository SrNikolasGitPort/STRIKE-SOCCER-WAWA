extends Node
## Login com Google pelo fluxo OAuth 2.0 "Device Authorization" (TV/dispositivos
## limitados): o jogo mostra um código + link; o jogador autoriza no navegador
## (no celular ou PC) e o jogo recebe o perfil (nome/e-mail/sub) via userinfo.
## Nenhum token é gravado no disco. O client_id/secret vêm de um JSON gerado no
## build a partir dos Secrets do GitHub (res://data/config/google_oauth.json) ou do
## arquivo do usuário (user://google_oauth.json) — NUNCA ficam no repositório.

signal code_ready(user_code: String, url: String)
signal finished(ok: bool, message: String)

const DEVICE_URL: String = "https://oauth2.googleapis.com/device/code"
const TOKEN_URL: String = "https://oauth2.googleapis.com/token"
const USERINFO_URL: String = "https://www.googleapis.com/oauth2/v3/userinfo"

var _client_id: String = ""
var _client_secret: String = ""
var _device_code: String = ""
var _interval: float = 5.0
var _expires: float = 0.0
var _polling: bool = false
var _cancelled: bool = false


static func configured() -> bool:
	return not _load_cfg().is_empty()


static func _load_cfg() -> Dictionary:
	for path: String in ["user://google_oauth.json", "res://data/config/google_oauth.json"]:
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary and String((parsed as Dictionary).get("client_id", "")) != "":
				return parsed
	return {}


func start() -> void:
	var cfg: Dictionary = _load_cfg()
	if cfg.is_empty():
		finished.emit(false, Game.t("Login Google não configurado neste build (veja docs/SETUP.md).", "Google login is not configured in this build (see docs/SETUP.md)."))
		return
	_client_id = String(cfg["client_id"])
	_client_secret = String(cfg.get("client_secret", ""))
	_cancelled = false
	var r: Dictionary = await _post(DEVICE_URL, {"client_id": _client_id, "scope": "openid email profile"})
	if not r.get("ok", false) or not (r.get("json", {}) as Dictionary).has("device_code"):
		finished.emit(false, Game.t("Não foi possível iniciar o login (sem internet?).", "Could not start login (no internet?)."))
		return
	var j: Dictionary = r["json"]
	_device_code = String(j["device_code"])
	_interval = float(j.get("interval", 5))
	_expires = float(j.get("expires_in", 600))
	var url: String = String(j.get("verification_url", "https://www.google.com/device"))
	code_ready.emit(String(j.get("user_code", "")), url)
	OS.shell_open(url)
	_polling = true
	_poll()


func cancel() -> void:
	_cancelled = true
	_polling = false


func _poll() -> void:
	var waited: float = 0.0
	while _polling and not _cancelled and waited < _expires:
		await get_tree().create_timer(_interval).timeout
		waited += _interval
		if _cancelled:
			return
		var body: Dictionary = {"client_id": _client_id, "device_code": _device_code, "grant_type": "urn:ietf:params:oauth:grant-type:device_code"}
		if _client_secret != "":
			body["client_secret"] = _client_secret
		var r: Dictionary = await _post(TOKEN_URL, body)
		var j: Dictionary = r.get("json", {})
		if j.has("access_token"):
			_polling = false
			await _fetch_profile(String(j["access_token"]))
			return
		var err: String = String(j.get("error", ""))
		if err == "slow_down":
			_interval += 5.0
		elif err != "authorization_pending" and err != "":
			_polling = false
			finished.emit(false, Game.t("Login negado ou expirado.", "Login denied or expired."))
			return
	if not _cancelled:
		finished.emit(false, Game.t("Tempo do login esgotado.", "Login timed out."))


func _fetch_profile(token: String) -> void:
	var h: HTTPRequest = HTTPRequest.new()
	h.timeout = 10.0
	add_child(h)
	h.request(USERINFO_URL, ["Authorization: Bearer " + token])
	var res: Array = await h.request_completed
	h.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		finished.emit(false, Game.t("Falha ao ler o perfil do Google.", "Failed to read the Google profile."))
		return
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("sub"):
		finished.emit(false, Game.t("Resposta inválida do Google.", "Invalid Google response."))
		return
	var d: Dictionary = parsed
	Game.google_user = {"sub": String(d["sub"]), "name": String(d.get("name", "Jogador")), "email": String(d.get("email", ""))}
	Game.player_name = String(d.get("given_name", d.get("name", Game.player_name)))
	Game.save_game()
	finished.emit(true, Game.t("Conectado como %s", "Signed in as %s") % String(Game.google_user["name"]))


func _post(url: String, form: Dictionary) -> Dictionary:
	var h: HTTPRequest = HTTPRequest.new()
	h.timeout = 10.0
	add_child(h)
	var parts: PackedStringArray = PackedStringArray()
	for k: Variant in form:
		parts.append(String(k).uri_encode() + "=" + String(form[k]).uri_encode())
	var err: int = h.request(url, ["Content-Type: application/x-www-form-urlencoded"], HTTPClient.METHOD_POST, "&".join(parts))
	if err != OK:
		h.queue_free()
		return {"ok": false}
	var res: Array = await h.request_completed
	h.queue_free()
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return {"ok": int(res[0]) == HTTPRequest.RESULT_SUCCESS, "code": int(res[1]), "json": parsed if parsed is Dictionary else {}}
