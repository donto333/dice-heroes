extends RefCounted
## data/ 폴더의 JSON을 읽어 오는 도우미.
## 규칙 코드와 화면 코드가 같은 데이터를 쓰도록 여기서만 파일을 읽는다.

const CHARACTERS_PATH := "res://data/characters.json"
const BOARD_PATH := "res://data/board.json"
const CARDS_PATH := "res://data/cards.json"
const ABILITIES_PATH := "res://data/abilities.json"


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


## 규칙 엔진에 넘길 데이터 묶음.
static func load_all() -> Dictionary:
	return {
		"characters": load_characters(),
		"board": load_json(BOARD_PATH),
		"cards": load_json(CARDS_PATH).get("cards", {}),
		"abilities": load_json(ABILITIES_PATH).get("abilities", {}),
	}


static func grade_stars(grade: int) -> String:
	return "★".repeat(grade)
