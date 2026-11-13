extends SceneTree
## 화면 없이 도는 자동 검사. CI에서 `godot --headless --script res://tests/run_tests.gd`로 실행한다.
## 하나라도 실패하면 종료 코드 1로 끝나 빌드가 멈춘다.

const CHARACTERS_PATH := "res://data/characters.json"
const CATEGORIES := ["영웅", "위인", "신화", "근현대"]

var _failures: Array[String] = []


func _init() -> void:
	_test_character_data()
	if _failures.is_empty():
		print("모든 검사 통과")
		quit(0)
	else:
		for failure in _failures:
			printerr("실패: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _test_character_data() -> void:
	var text := FileAccess.get_file_as_string(CHARACTERS_PATH)
	_check(not text.is_empty(), "캐릭터 파일을 읽을 수 없음")
	var parsed: Variant = JSON.parse_string(text)
	_check(typeof(parsed) == TYPE_DICTIONARY, "캐릭터 파일이 JSON 객체가 아님")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var characters: Array = parsed.get("characters", [])
	_check(characters.size() >= 12, "프로토타입 캐릭터가 12명 미만")

	var seen_ids := {}
	for character in characters:
		var id: String = character.get("id", "")
		_check(id != "", "id가 없는 캐릭터가 있음")
		_check(not seen_ids.has(id), "id 중복: " + id)
		seen_ids[id] = true
		_check(character.get("category", "") in CATEGORIES, "분류가 잘못됨: " + id)
		var grade := int(character.get("grade", 0))
		_check(grade >= 1 and grade <= 3, "등급이 1~3이 아님: " + id)
		var move := int(character.get("move", 0))
		_check(move >= 1 and move <= 2, "이동이 1~2가 아님: " + id)
		for stat in ["attack", "defense", "intellect"]:
			var value := int(character.get(stat, 0))
			_check(value >= 1 and value <= 5, "%s가 1~5가 아님: %s" % [stat, id])
