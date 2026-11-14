extends RefCounted
## data/ 폴더의 JSON을 읽어 오는 도우미.
## 규칙 코드와 화면 코드가 같은 데이터를 쓰도록 여기서만 파일을 읽는다.

const CHARACTERS_PATH := "res://data/characters.json"
const BOARD_PATH := "res://data/board.json"
## 대전마다 이 중 하나를 고른다. 첫 번째가 기본 맵.
const BOARD_PATHS := [
	"res://data/board.json", "res://data/boards/desert.json", "res://data/boards/frost.json", "res://data/boards/river.json",
	"res://data/boards/ruins.json", "res://data/boards/volcano.json", "res://data/boards/forest.json", "res://data/boards/sky.json",
]
const CARDS_PATH := "res://data/cards.json"
const ABILITIES_PATH := "res://data/abilities.json"
const RULES_PATH := "res://data/rules.json"
const ECONOMY_PATH := "res://data/economy.json"
const ADVENTURE_PATH := "res://data/adventure.json"
const ACHIEVEMENTS_PATH := "res://data/achievements.json"


static func load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("데이터 파일을 읽지 못했습니다: %s" % path)
		return {}
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("데이터 형식이 잘못됐습니다: %s" % path)
		return {}
	return parsed


static func load_characters() -> Array:
	return load_json(CHARACTERS_PATH).get("characters", [])


static func load_boards() -> Array:
	var boards: Array = []
	for path in BOARD_PATHS:
		boards.append(load_json(path))
	return boards


## 규칙 엔진에 넘길 데이터 묶음.
static func load_all() -> Dictionary:
	return {
		"characters": load_characters(),
		"board": load_json(BOARD_PATH),
		"boards": load_boards(),
		"cards": load_json(CARDS_PATH).get("cards", {}),
		"abilities": load_json(ABILITIES_PATH).get("abilities", {}),
		"rules": load_json(RULES_PATH),
		"economy": load_json(ECONOMY_PATH),
		"adventure": load_json(ADVENTURE_PATH),
		"achievements": load_json(ACHIEVEMENTS_PATH),
	}


const PORTRAIT_PATH := "res://assets/portraits/%s.jpg"

static var _portraits: Dictionary = {}


## 캐릭터 초상화. 아직 그림이 없는 캐릭터면 null.
static func portrait(id: String) -> Texture2D:
	if _portraits.has(id):
		return _portraits[id]
	var path := PORTRAIT_PATH % id
	var texture: Texture2D = null
	if id != "" and ResourceLoader.exists(path):
		texture = load(path)
	_portraits[id] = texture
	return texture


static func grade_stars(grade: int) -> String:
	return "★".repeat(grade)
