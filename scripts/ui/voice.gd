extends Node
## 영웅 음성. assets/audio/voice/<영웅 id>_<상황>.ogg 를 튼다(대사는 data/voice_lines.json).
## 상황: select(도감·대표 영웅 클릭) idle(대기) move(이동) attack(공격) defend(방어) skill(어빌리티) win lose
## 파일이 없으면 아무 소리도 내지 않는다. 두 사람이 이어서 말할 수 있게 재생기를 둘 둔다.

const DIR := "res://assets/audio/voice"
const VOLUME_DB := -3.0

## 말을 시작하면 그 길이(초)와 함께 알린다(배경음악을 잠깐 줄이는 데 쓴다).
signal spoke(seconds: float)

var enabled := true
## 설정의 음성 크기를 dB로 바꾼 값
var gain_db := 0.0
var _players: Array = []
var _next := 0


func _ready() -> void:
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = VOLUME_DB
		add_child(player)
		_players.append(player)


static func path_of(hero_id: String, kind: String) -> String:
	return "%s/%s_%s.ogg" % [DIR, hero_id, kind]


## 그 영웅의 그 상황 대사를 튼다. 틀었으면 true.
func say(hero_id: String, kind: String) -> bool:
	if not enabled or hero_id == "":
		return false
	var path := path_of(hero_id, kind)
	if not ResourceLoader.exists(path):
		return false
	var stream = load(path)
	if not (stream is AudioStream):
		return false
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = VOLUME_DB + gain_db
	player.play()
	spoke.emit(float(stream.get_length()))
	return true
