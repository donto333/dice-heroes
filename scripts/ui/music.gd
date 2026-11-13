extends Node
## 배경음악. 로비 곡과 대전 곡을 바꿔 틀고, 끝나면 처음부터 다시 튼다.
## 곡은 tools/make_music.py로 만든 assets/audio/의 WAV.
## 웹에서는 사용자가 화면을 한 번 누른 뒤부터 소리가 난다(브라우저 규칙).

const TRACKS := {
	"lobby": "res://assets/audio/bgm_lobby.wav",
	"match": "res://assets/audio/bgm_match.wav",
}
const VOLUME_DB := -10.0

var _player: AudioStreamPlayer
var _current := ""
var enabled := true


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = VOLUME_DB
	add_child(_player)
	_player.finished.connect(_on_finished)


func play_track(track: String) -> void:
	if track == _current and _player.playing:
		return
	_current = track
	if not enabled or not TRACKS.has(track) or not ResourceLoader.exists(TRACKS[track]):
		_player.stop()
		return
	_player.stream = load(TRACKS[track])
	_player.volume_db = -40.0
	_player.play()
	var tween := create_tween()
	tween.tween_property(_player, "volume_db", VOLUME_DB, 0.8)


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_player.stop()
	else:
		var track := _current
		_current = ""
		play_track(track)


func _on_finished() -> void:
	if enabled and _current != "":
		_player.play()
