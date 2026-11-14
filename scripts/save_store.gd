extends RefCounted
## 프로필 저장·불러오기. 기기 안(user://)에 JSON 파일 하나로 둔다.
## 웹 버전에서는 브라우저 저장소에 들어간다. 나중에 서버(Nakama)로 옮길 때 이 파일만 바꾸면 된다.

const PATH := "user://profile.json"


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func load_profile() -> Dictionary:
	if not exists():
		return {}
	var text := FileAccess.get_file_as_string(PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("저장 파일이 깨져서 새로 시작합니다.")
		return {}
	return parsed


static func save_profile(profile: Dictionary) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("저장하지 못했습니다: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(profile, "  "))
	file.close()


static func erase() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


# ---------------------------------------------------------------- 데이터 옮기기

## 프로필을 글자 한 줄(옮기기 코드)로 바꾼다. 다른 기기에 붙여 넣어 이어 할 수 있다.
static func export_text(profile: Dictionary) -> String:
	return "DH1:" + Marshalls.utf8_to_base64(JSON.stringify(profile))


## 옮기기 코드를 프로필로 되돌린다. 코드가 틀리면 빈 사전.
static func import_text(text: String) -> Dictionary:
	var cleaned := text.strip_edges().replace("\n", "").replace(" ", "")
	if not cleaned.begins_with("DH1:"):
		return {}
	var raw := Marshalls.base64_to_utf8(cleaned.substr(4))
	if raw == "":
		return {}
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	# 프로필 모양인지 간단히 확인한다.
	if typeof(parsed.get("nickname")) != TYPE_STRING or typeof(parsed.get("owned")) != TYPE_DICTIONARY or typeof(parsed.get("party")) != TYPE_DICTIONARY:
		return {}
	return parsed
