extends Node
## 배경음악. 화면에 맞는 곡을 바꿔 틀고, 끝나면 처음부터 다시 튼다.
## 곡은 수노(Suno)에서 만든 연주곡을 ogg로 바꾼 assets/audio/bgm_<이름>.ogg.
## 다른 곡으로 갔다가 돌아오면 멈췄던 자리부터 이어서 튼다(전투 곡 ↔ 대전 곡).
## 웹에서는 사용자가 화면을 한 번 누른 뒤부터 소리가 난다(브라우저 규칙).

const TRACKS := {
	"title": "res://assets/audio/bgm_title.ogg",
	"lobby": "res://assets/audio/bgm_lobby.ogg",
	"shop": "res://assets/audio/bgm_shop.ogg",
	"match": "res://assets/audio/bgm_match.ogg",
	"boss": "res://assets/audio/bgm_boss.ogg",
	"victory": "res://assets/audio/bgm_victory.ogg",
	"defeat": "res://assets/audio/bgm_defeat.ogg",
}
## 한 번만 틀고 되풀이하지 않는 곡
const ONE_SHOT := ["victory", "defeat"]
const VOLUME_DB := -12.0

var _player: AudioStreamPlayer
var _current := ""
var _positions: Dictionary = {}
var enabled := true


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = VOLUME_DB
	add_child(_player)
	_player.finished.connect(_on_finished)


func current() -> String:
	return _current


func play_track(track: String) -> void:
	if track == _current and (_player.playing or ONE_SHOT.has(track)):
		return
	if _current != "" and _player.playing:
		_positions[_current] = _player.get_playback_position()
	_current = track
	if not enabled or not TRACKS.has(track) or not ResourceLoader.exists(TRACKS[track]):
		_player.stop()
		return
	_player.stream = load(TRACKS[track])
	_player.volume_db = -40.0
	_player.play(0.0 if ONE_SHOT.has(track) else float(_positions.get(track, 0.0)))
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
	_positions.erase(_current)
	if enabled and _current != "" and not ONE_SHOT.has(_current):
		_player.play()
