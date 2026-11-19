## 앱 새 버전 알림 규칙(2026-11-19). 화면 코드와 나눠 tests에서 검사한다.
## 버전은 "0.29.512"처럼 점으로 나눈 숫자다(base + Build 실행 번호).
extends RefCounted


## latest가 current보다 새 버전이면 true. 숫자 칸을 앞에서부터 비교하고, 모자란 칸은 0으로 본다.
static func is_newer(current: String, latest: String) -> bool:
	var a := _parts(current)
	var b := _parts(latest)
	if b.is_empty():
		return false
	for i in maxi(a.size(), b.size()):
		var x: int = a[i] if i < a.size() else 0
		var y: int = b[i] if i < b.size() else 0
		if y != x:
			return y > x
	return false


## 서버에서 받은 글(app_version.json)에서 최신 버전 글자를 꺼낸다. 알아볼 수 없으면 "".
static func latest_from(text: String) -> String:
	var info = JSON.parse_string(text)
	if typeof(info) != TYPE_DICTIONARY:
		return ""
	var version := str(info.get("version", "")).strip_edges()
	return version if not _parts(version).is_empty() else ""


static func _parts(version: String) -> Array:
	var out: Array = []
	for piece in version.strip_edges().split("."):
		if not piece.is_valid_int():
			return []
		out.append(int(piece))
	return out
