extends RefCounted
## data/ 폴더의 JSON을 읽어 오는 도우미.
## 규칙 코드와 화면 코드가 같은 데이터를 쓰도록 여기서만 파일을 읽는다.

const CHARACTERS_PATH := "res://data/characters.json"

## 등급별 소환 포인트. 파티 합계는 PARTY_POINT_LIMIT 이하여야 한다.
const GRADE_POINTS := {3: 3, 2: 2, 1: 1}
const PARTY_POINT_LIMIT := 6


static func load_characters() -> Array:
	var text := FileAccess.get_file_as_string(CHARACTERS_PATH)
	if text.is_empty():
		push_error("캐릭터 데이터를 읽지 못했습니다: %s" % CHARACTERS_PATH)
		return []
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("characters"):
		push_error("캐릭터 데이터 형식이 잘못됐습니다.")
		return []
	return parsed["characters"]


static func grade_stars(grade: int) -> String:
	return "★".repeat(grade)
