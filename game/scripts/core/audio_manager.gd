extends Node
## Autoload "Sfx": barramentos (Master/SFX/Music), efeitos com variação de pitch,
## música em loop e loop da torcida.

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"
const POOL_SIZE: int = 14

var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _crowd: AudioStreamPlayer
var _music_name: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("SFX")
	_ensure_bus("Music")
	for i: int in range(POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_crowd = AudioStreamPlayer.new()
	_crowd.bus = "SFX"
	_crowd.volume_db = -12.0
	add_child(_crowd)
	apply_volumes()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	_set_bus("Master", float(Game.settings.get("vol_master", 0.9)))
	_set_bus("SFX", float(Game.settings.get("vol_sfx", 1.0)))
	_set_bus("Music", float(Game.settings.get("vol_music", 0.6)))


func _set_bus(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(idx, linear <= 0.001)


func _stream(path: String, loop: bool) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	if loop and s is AudioStreamWAV:
		var w: AudioStreamWAV = s
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2
	_cache[path] = s
	return s


## Toca um efeito (arquivo em assets/audio/sfx/<nome>.wav).
func play(sfx_name: String, volume_db: float = 0.0, pitch_var: float = 0.06) -> void:
	var s: AudioStream = _stream(SFX_DIR + sfx_name + ".wav", false)
	if s == null:
		return
	for p: AudioStreamPlayer in _pool:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return


func music(track: String) -> void:
	if track == _music_name and _music.playing:
		return
	_music_name = track
	if track == "":
		_music.stop()
		return
	var s: AudioStream = _stream(MUSIC_DIR + track + ".wav", true)
	if s != null:
		_music.stream = s
		_music.play()


func crowd(on: bool) -> void:
	if on:
		var s: AudioStream = _stream(SFX_DIR + "crowd_loop.wav", true)
		if s != null and not _crowd.playing:
			_crowd.stream = s
			_crowd.play()
	else:
		_crowd.stop()


func duck_music(db: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_music, "volume_db", db, 0.2)
