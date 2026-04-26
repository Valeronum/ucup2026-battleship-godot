extends Node

var _players: Dictionary = {}
var _music: AudioStreamPlayer

func _safe_load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var stream_res := load(path)
	if stream_res is AudioStream:
		return stream_res
	return null

func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.volume_db = -9.0
	_music.stream = _safe_load_stream("res://assets/sounds/music.mp3")
	_music.autoplay = false
	if _music.stream is AudioStreamMP3:
		(_music.stream as AudioStreamMP3).loop = true
	elif _music.stream is AudioStreamOggVorbis:
		(_music.stream as AudioStreamOggVorbis).loop = true
	elif _music.stream is AudioStreamWAV:
		(_music.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	add_child(_music)

	_register_sfx("click", "res://assets/sounds/click.mp3", -4.0)
	_register_sfx("shot", "res://assets/sounds/shot.mp3", -4.0)
	_register_sfx("miss", "res://assets/sounds/miss.mp3", -4.0)
	_register_sfx("destroy", "res://assets/sounds/destroy.mp3", -4.0)
	_register_sfx("win", "res://assets/sounds/win.mp3", -4.0)
	_register_sfx("lose", "res://assets/sounds/lose.mp3", -4.0)

func _register_sfx(key: String, path: String, volume_db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	p.stream = _safe_load_stream(path)
	p.volume_db = volume_db
	add_child(p)
	_players[key] = p

func play_sfx(key: String) -> void:
	if not _players.has(key):
		return
	var p: AudioStreamPlayer = _players[key]
	if p.stream == null:
		return
	p.stop()
	p.play()

func start_music(enabled: bool) -> void:
	if not enabled:
		stop_music()
		return
	if _music != null and _music.stream != null and not _music.playing:
		_music.play()

func stop_music() -> void:
	if _music != null:
		_music.stop()
