extends Node
## Autoload "Game": estado global (modo escolhido, personagem, progressão, save,
## configurações) e acesso aos dados (personagens, skills, missões Nel).

signal quest_completed(quest: Dictionary)
signal coins_changed(value: int)

const SAVE_PATH: String = "user://save.cfg"
const SKILLS_PATH: String = "res://data/skills/skills.json"
const QUESTS_PATH: String = "res://data/quests/quests.json"
const INDEX_PATH: String = "res://data/characters/index.json"
const UNLOCK_COST: Dictionary = {"raro": 0, "epico": 600, "lendario": 1500, "mitico": 3500, "world_class": 6000}
const RARITY_NAMES_PT: Dictionary = {"raro": "RARO", "epico": "ÉPICO", "lendario": "LENDÁRIO", "mitico": "MÍTICO", "world_class": "WORLD CLASS"}
const RARITY_ORDER: Array = ["raro", "epico", "lendario", "mitico", "world_class"]
const STARTERS: Array = ["isagi", "igaguri", "chigiri", "zantetsu", "otoya"]

# Seleção atual (menu -> partida)
var mode: String = "training"          # training | 2v2 | 4v4 | online
var selected_char: String = "isagi"
var online_role: String = ""           # "" | host | client
var online_address: String = ""
var online_port: int = 24565
var last_result: Dictionary = {}
var online_roster: Array = []
var online_size: int = 2

# Progressão / configurações (salvas)
var coins: int = 300
var xp: int = 0
var player_name: String = "Jogador"
var unlocked: Dictionary = {}
var quest_progress: Dictionary = {}
var quest_done: Dictionary = {}
var friends: Array = []
var google_user: Dictionary = {}
var settings: Dictionary = {
	"vol_master": 0.9, "vol_sfx": 1.0, "vol_music": 0.6,
	"lang": "pt", "reduce_cutscenes": false, "quality": -1, "show_fps": false, "touch_scale": 1.0,
}

# Perfil e personalização (Multiplayer): bio, título, avatar, cores do uniforme/aura/cabelo.
var profile: Dictionary = {"bio": "", "title": "rookie", "avatar": "", "banner": 0}
var custom: Dictionary = {"kit": "", "shorts": "", "hair": "", "aura": ""}
var career: Dictionary = {"matches": 0, "wins": 0, "draws": 0, "losses": 0, "goals": 0, "assists": 0, "steals": 0,
	"skills": 0, "awakens": 0, "seconds": 0, "chars": {}}
var history: Array = []   # últimas 30 partidas

const TITLES: Array = [
	{"id": "rookie", "pt": "Novato", "en": "Rookie", "need": "", "n": 0},
	{"id": "striker", "pt": "Artilheiro", "en": "Striker", "need": "goals", "n": 10},
	{"id": "ego", "pt": "Egoísta", "en": "Egoist", "need": "goals", "n": 40},
	{"id": "playmaker", "pt": "Armador", "en": "Playmaker", "need": "assists", "n": 10},
	{"id": "thief", "pt": "Ladrão de Bola", "en": "Ball Thief", "need": "steals", "n": 25},
	{"id": "awakened", "pt": "Despertado", "en": "Awakened", "need": "awakens", "n": 5},
	{"id": "champion", "pt": "Campeão", "en": "Champion", "need": "wins", "n": 10},
	{"id": "legend", "pt": "Lenda do Blue Lock", "en": "Blue Lock Legend", "need": "wins", "n": 50},
]

var _skills: Dictionary = {}
var _quests: Array = []
var _order: Array = []
var _chars: Dictionary = {}


func _ready() -> void:
	_skills = _read_json(SKILLS_PATH)
	var q: Variant = JSON.parse_string(FileAccess.get_file_as_string(QUESTS_PATH)) if FileAccess.file_exists(QUESTS_PATH) else []
	_quests = q if q is Array else []
	var idx: Dictionary = _read_json(INDEX_PATH)
	_order = idx.get("order", [])
	for cid: Variant in _order:
		_chars[String(cid)] = Config.load_character(String(cid))
	load_game()
	for cid: String in STARTERS:
		unlocked[cid] = true
	var qlevel: int = int(settings.get("quality", -1))
	if qlevel >= 0:
		Config.quality_level = qlevel


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


# ---------------------------------------------------------------- dados
func t(pt: String, en: String) -> String:
	return pt if String(settings.get("lang", "pt")) == "pt" else en


func char_order() -> Array:
	return _order


func character(cid: String) -> Dictionary:
	if _chars.has(cid):
		return _chars[cid]
	return {}


func skill(sid: String) -> Dictionary:
	if _skills.has(sid):
		return _skills[sid]
	return {}


func skill_name(sid: String) -> String:
	var s: Dictionary = skill(sid)
	return String(s.get("name_pt" if String(settings["lang"]) == "pt" else "name_en", sid))


func quests_for(cid: String) -> Array:
	var out: Array = []
	for q: Variant in _quests:
		if String((q as Dictionary).get("char", "")) == cid:
			out.append(q)
	return out


func quest_text(q: Dictionary) -> String:
	var ev: String = String(q.get("event", ""))
	var n: int = int(q.get("target", 1))
	var base: String = ev
	var arg: String = ""
	if ev.contains(":"):
		base = ev.get_slice(":", 0)
		arg = ev.get_slice(":", 1)
	match base:
		"goal": return t("Marque %d gols" % n, "Score %d goals" % n)
		"assist": return t("Dê %d assistências" % n, "Get %d assists" % n)
		"steal": return t("Roube a bola %d vezes" % n, "Steal the ball %d times" % n)
		"win": return t("Vença %d partidas" % n, "Win %d matches" % n)
		"awaken": return t("Entre em Despertar %d vezes" % n, "Awaken %d times" % n)
		"awaken_goal": return t("Marque %d gols em Despertar" % n, "Score %d goals while awakened" % n)
		"skill_goal": return t("Marque %d gols com %s" % [n, skill_name(arg)], "Score %d goals with %s" % [n, skill_name(arg)])
		"skill_use": return t("Use %s %d vezes" % [skill_name(arg), n], "Use %s %d times" % [skill_name(arg), n])
	return ev


# ---------------------------------------------------------- desbloqueio
func rarity_of(cid: String) -> String:
	return String(character(cid).get("rarity", "raro"))


func cost_of(cid: String) -> int:
	return int(UNLOCK_COST.get(rarity_of(cid), 0))


func is_evolution(cid: String) -> bool:
	return character(cid).get("base_id") != null


## TEMPORÁRIO (testes): "dev.unlock_all" em gameplay.json libera todos os personagens e Nel/GOAT.
func dev_unlock_all() -> bool:
	return Config.f("dev.unlock_all") > 0.5


func is_unlocked(cid: String) -> bool:
	if dev_unlock_all():
		return true
	if is_evolution(cid):
		for q: Variant in quests_for(String(character(cid).get("base_id", ""))):
			if quest_done.has(String((q as Dictionary)["id"])):
				return true
		return false
	return unlocked.has(cid)


func can_buy(cid: String) -> bool:
	return not is_evolution(cid) and not unlocked.has(cid) and coins >= cost_of(cid)


func buy(cid: String) -> bool:
	if not can_buy(cid):
		return false
	coins -= cost_of(cid)
	unlocked[cid] = true
	coins_changed.emit(coins)
	save_game()
	return true


func add_coins(n: int) -> void:
	coins += n
	coins_changed.emit(coins)


## Skills de Despertar disponíveis para o personagem (Nel/GOAT: só as liberadas por missão).
func awakening_skills(cid: String) -> Array:
	var c: Dictionary = character(cid)
	var all: Array = c.get("awakening", [])
	if not is_evolution(cid) or dev_unlock_all():
		return all
	var out: Array = []
	for sid: Variant in all:
		var unlocked_by_quest: bool = false
		for q: Variant in quests_for(String(c.get("base_id", ""))):
			var qd: Dictionary = q
			if String(qd.get("unlock", "")) == String(sid) and quest_done.has(String(qd["id"])):
				unlocked_by_quest = true
		if unlocked_by_quest:
			out.append(sid)
	return out


# --------------------------------------------------------------- missões
## Chamado pela partida a cada evento do jogador humano (gol, roubo, ...).
func report_event(event: String, cid: String, amount: int = 1) -> void:
	var base_id: String = cid
	var ch: Dictionary = character(cid)
	if ch.get("base_id") != null:
		base_id = String(ch["base_id"])
	for q: Variant in quests_for(base_id):
		var qd: Dictionary = q
		var qid: String = String(qd["id"])
		if quest_done.has(qid) or String(qd.get("event", "")) != event:
			continue
		quest_progress[qid] = int(quest_progress.get(qid, 0)) + amount
		if int(quest_progress[qid]) >= int(qd.get("target", 1)):
			quest_done[qid] = true
			quest_completed.emit(qd)
	# progresso nunca é perdido: salva ao fim da partida (save_game)


func quest_progress_of(q: Dictionary) -> int:
	return mini(int(quest_progress.get(String(q["id"]), 0)), int(q.get("target", 1)))


func title_unlocked(t: Dictionary) -> bool:
	if String(t["need"]) == "":
		return true
	return int(career.get(String(t["need"]), 0)) >= int(t["n"])


func title_name(id: String) -> String:
	for t: Dictionary in TITLES:
		if String(t["id"]) == id:
			return String(t["pt"]) if String(settings.get("lang", "pt")) == "pt" else String(t["en"])
	return ""


## Registra o resultado de uma partida na carreira e no histórico.
func record_match(res: Dictionary, char_id: String, seconds: float) -> void:
	var st: Dictionary = res.get("stats", {})
	career["matches"] = int(career["matches"]) + 1
	if bool(res.get("won", false)):
		career["wins"] = int(career["wins"]) + 1
	elif bool(res.get("draw", false)):
		career["draws"] = int(career["draws"]) + 1
	else:
		career["losses"] = int(career["losses"]) + 1
	for k: String in ["goals", "assists", "steals", "skills", "awakens"]:
		career[k] = int(career[k]) + int(st.get(k, 0))
	career["seconds"] = int(career["seconds"]) + int(seconds)
	var chars: Dictionary = career["chars"]
	chars[char_id] = int(chars.get(char_id, 0)) + 1
	var sc: Array = res.get("score", [0, 0])
	history.push_front({"t": Time.get_unix_time_from_system(), "mode": String(res.get("mode", "")), "my": int(sc[0]), "other": int(sc[1]),
		"won": bool(res.get("won", false)), "draw": bool(res.get("draw", false)), "char": char_id, "goals": int(st.get("goals", 0)), "assists": int(st.get("assists", 0))})
	while history.size() > 30:
		history.pop_back()


func favorite_char() -> String:
	var best: String = ""
	var n: int = 0
	for k: Variant in (career["chars"] as Dictionary):
		if int((career["chars"] as Dictionary)[k]) > n:
			n = int((career["chars"] as Dictionary)[k])
			best = String(k)
	return best


## Aplica a personalização do jogador (cores) a uma ficha de personagem (cópia).
func apply_custom(character: Dictionary) -> Dictionary:
	var c: Dictionary = character.duplicate(true)
	var v: Dictionary = c.get("visual", {})
	var kit: Dictionary = v.get("kit", {})
	if String(custom.get("kit", "")) != "":
		kit["main"] = String(custom["kit"])
	if String(custom.get("shorts", "")) != "":
		kit["shorts"] = String(custom["shorts"])
	if String(custom.get("hair", "")) != "":
		v["hair_color"] = String(custom["hair"])
	if String(custom.get("aura", "")) != "":
		v["aura"] = String(custom["aura"])
	v["kit"] = kit
	c["visual"] = v
	return c


func level() -> int:
	return 1 + int(sqrt(float(xp) / 100.0))


# ----------------------------------------------------------------- save
func save_game() -> void:
	var cf: ConfigFile = ConfigFile.new()
	cf.set_value("p", "coins", coins)
	cf.set_value("p", "xp", xp)
	cf.set_value("p", "name", player_name)
	cf.set_value("p", "unlocked", unlocked)
	cf.set_value("p", "qp", quest_progress)
	cf.set_value("p", "qd", quest_done)
	cf.set_value("p", "friends", friends)
	cf.set_value("p", "selected", selected_char)
	cf.set_value("p", "google", google_user)
	cf.set_value("p", "profile", profile)
	cf.set_value("p", "custom", custom)
	cf.set_value("p", "career", career)
	cf.set_value("p", "history", history)
	cf.set_value("s", "settings", settings)
	cf.save(SAVE_PATH)


func load_game() -> void:
	var cf: ConfigFile = ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	coins = int(cf.get_value("p", "coins", coins))
	xp = int(cf.get_value("p", "xp", 0))
	player_name = String(cf.get_value("p", "name", player_name))
	unlocked = cf.get_value("p", "unlocked", {})
	quest_progress = cf.get_value("p", "qp", {})
	quest_done = cf.get_value("p", "qd", {})
	friends = cf.get_value("p", "friends", [])
	selected_char = String(cf.get_value("p", "selected", "isagi"))
	google_user = cf.get_value("p", "google", {})
	var pr: Variant = cf.get_value("p", "profile", {})
	if pr is Dictionary:
		for k: Variant in (pr as Dictionary):
			profile[k] = (pr as Dictionary)[k]
	var cu: Variant = cf.get_value("p", "custom", {})
	if cu is Dictionary:
		for k: Variant in (cu as Dictionary):
			custom[k] = (cu as Dictionary)[k]
	var ca: Variant = cf.get_value("p", "career", {})
	if ca is Dictionary:
		for k: Variant in (ca as Dictionary):
			career[k] = (ca as Dictionary)[k]
	var hi: Variant = cf.get_value("p", "history", [])
	if hi is Array:
		history = hi
	var s: Variant = cf.get_value("s", "settings", {})
	if s is Dictionary:
		for k: Variant in (s as Dictionary):
			settings[k] = (s as Dictionary)[k]
