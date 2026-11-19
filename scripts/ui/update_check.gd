## 안드로이드 앱 새 버전 알림(2026-11-19 사용자 요청).
## 앱을 켤 때 한 번 릴리스의 app_version.json을 받아, 지금 버전보다 새 버전이면 로비에서 창을 띄운다.
## '업데이트'를 누르면 휴대폰 브라우저로 새 앱 파일을 받는다(설치 확인은 안드로이드가 따로 묻는다).
## 주소는 economy.json의 app_update(check_url·apk_url). 웹·PC·자동 사진에서는 돌지 않는다.
extends Node

const AppUpdate := preload("res://scripts/rules/app_update.gd")
const Kit := preload("res://scripts/ui/kit.gd")

var app: Control
var latest := ""
var _shown := false
var _http: HTTPRequest


func start(owner_app: Control) -> void:
	app = owner_app
	if not OS.has_feature("android") or app.instant:
		return
	var url := str(app.eco.get("app_update", {}).get("check_url", ""))
	if url == "":
		return
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	_http.max_redirects = 8
	add_child(_http)
	_http.request_completed.connect(_on_done)
	if _http.request(url) != OK:
		_http.queue_free()


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var version := AppUpdate.latest_from(body.get_string_from_utf8())
	if version == "" or not AppUpdate.is_newer(app.VERSION, version):
		return
	latest = version
	if app.current_name == "lobby":
		show_notice()


## 로비가 열릴 때·결과를 받았을 때 부른다. 새 버전이 있고 이번에 켠 뒤로 아직 안 띄웠으면 창을 띄운다.
func show_notice() -> void:
	if latest == "" or _shown:
		return
	_shown = true
	var text := Kit.para("새 버전 %s이 나왔어요. (지금 %s)\n\n'업데이트'를 누르면 새 앱 파일을 내려받아요.\n받은 뒤 설치 화면에서 '설치'를 누르면 기록은 그대로 남아요." % [latest, app.VERSION], 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	app.dialog("새 버전이 있어요", text, [["업데이트", Kit.ACCENT, _open_download], ["나중에", Kit.PANEL_LIGHT]], 620)


func _open_download() -> void:
	var url := str(app.eco.get("app_update", {}).get("apk_url", ""))
	if url != "":
		OS.shell_open(url)
