extends Node
## Autoload "Config": carrega os valores balanceáveis de res://data/config/*.json.
## Nenhum número mágico no código de gameplay: tudo vem daqui (Config.f("secao.chave")).

const VERSION: String = "0.1.0-m1"
const GAMEPLAY_PATH: String = "res://data/config/gameplay.json"
const RARITIES_PATH: String = "res://data/config/rarities.json"
const CHARACTERS_DIR: String = "res://data/characters/"

enum Quality { LOW, MEDIUM, HIGH }

var _gameplay: Dictionary = {}
var _rarities: Dictionary = {}
var quality_level: int = Quality.MEDIUM


func _ready() -> void:
	_gameplay = _load_json(GAMEPLAY_PATH)
	_rarities = _load_json(RARITIES_PATH)
	if OS.has_feature("mobile"):
		quality_level = int(f("quality.auto_mobile_level"))
	else:
		quality_level = int(f("quality.auto_desktop_level"))


## Lê um float de gameplay.json usando caminho com pontos, ex.: "ball.radius".
func f(path: String) -> float:
	var value: Variant = _lookup(path)
	if value == null:
		push_error("Config: chave ausente em gameplay.json: " + path)
		return 0.0
	return float(value)


func _lookup(path: String) -> Variant:
	var node: Variant = _gameplay
	for part: String in path.split("."):
		if node is Dictionary and (node as Dictionary).has(part):
			node = (node as Dictionary)[part]
		else:
			return null
	return node


func rarity_color(rarity_id: String) -> Color:
	for entry: Variant in _rarities.get("rarities", []):
		var d: Dictionary = entry
		if d.get("id", "") == rarity_id:
			return Color(String(d.get("color", "#FFFFFF")))
	return Color.WHITE


func load_character(character_id: String) -> Dictionary:
	return _load_json(CHARACTERS_DIR + character_id + ".json")


## Aplica o nível de qualidade gráfica (Baixo/Médio/Alto) na viewport e na luz.
func apply_quality(level: int, viewport: Viewport, light: DirectionalLight3D) -> void:
	quality_level = level
	match level:
		Quality.LOW:
			viewport.scaling_3d_scale = f("quality.low_scale_3d")
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			if light != null:
				light.shadow_enabled = false
		Quality.MEDIUM:
			viewport.scaling_3d_scale = f("quality.medium_scale_3d")
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			if light != null:
				light.shadow_enabled = true
		_:
			viewport.scaling_3d_scale = f("quality.high_scale_3d")
			viewport.msaa_3d = Viewport.MSAA_2X
			if light != null:
				light.shadow_enabled = true


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Config: arquivo não encontrado: " + path)
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("Config: JSON inválido: " + path)
	return {}
