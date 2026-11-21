extends Node
## 기기 저장과 독립적으로 게스트 인증, 최초 조회, 지연 업로드를 차례로 처리한다.

signal server_profile_received(profile: Dictionary)
signal status_changed

const GameData := preload("res://scripts/game_data.gd")
const DEVICE_PATH := "user://device_id.cfg"
const COLLECTION := "profile"
const PROFILE_KEY := "main"

var connected := false
var last_saved_at := 0

var _settings := ConfigFile.new()
var _device_id := ""
var _url := ""
var _server_key := ""
var _token := ""
var _user_id := ""
var _expires_at := 0
var _http: HTTPRequest
var _timer: Timer
var _delay := 3.0
var _pending := {}
var _working := false
var _awaiting_choice := false
var _synced := false
var _reset_generation := 0
var _save_generation := 0


func start(disabled: bool) -> void:
	if disabled:
		return
	var config := GameData.load_json("res://data/online.json")
	if not bool(config.get("enabled", false)):
		return
	_settings.load(DEVICE_PATH)
	var device_id := OS.get_unique_id() if OS.has_feature("android") else ""
	if device_id.length() < 10:
		device_id = str(_settings.get_value("device", "id", ""))
		if device_id.length() < 10:
			device_id = Crypto.new().generate_random_bytes(16).hex_encode()
			if device_id.length() < 10:
				return
			_settings.set_value("device", "id", device_id)
			if _settings.save(DEVICE_PATH) != OK:
				return
	_device_id = device_id
	last_saved_at = int(_settings.get_value("sync", "last_saved_at", 0))
	_url = "%s://%s:%d" % [config["scheme"], config["host"], int(config["port"])]
	_server_key = str(config["server_key"])
	_delay = float(config["upload_delay_sec"])
	_http = HTTPRequest.new()
	_http.timeout = float(config["timeout_sec"])
	_http.max_redirects = 0
	add_child(_http)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_pump)
	add_child(_timer)
	_pump.call_deferred()


func queue_save(profile: Dictionary) -> void:
	if _timer == null:
		return
	_save_generation += 1
	_pending = profile.duplicate(true)
	_timer.start(_delay)


## 조회 결과를 앱에서 적용할 때까지 기기 사본을 올리지 않는다.
func finish_sync(profile_to_upload: Dictionary) -> void:
	_awaiting_choice = false
	_synced = true
	if profile_to_upload.is_empty():
		_pending.clear()
		_timer.stop()
	elif _pending != profile_to_upload:
		queue_save(profile_to_upload)
	elif _timer.is_stopped():
		_pump.call_deferred()


## 기기에서 명시적으로 초기화한 기록은 다시 받아오지 않는다.
func reset_local() -> void:
	if _timer == null:
		return
	_reset_generation += 1
	_pending.clear()
	_timer.stop()
	_settings.set_value("sync", "reset_pending", true)
	_settings.set_value("sync", "last_saved_at", 0)
	_settings.save(DEVICE_PATH)
	last_saved_at = 0
	status_changed.emit()


func _pump() -> void:
	if _working or _awaiting_choice:
		return
	_working = true
	var generation := _save_generation
	if not _synced:
		await _pull_profile()
	elif not _pending.is_empty():
		var snapshot := _pending
		_pending = {}
		await _upload(snapshot)
	_working = false
	# 요청 중에 새 저장의 타이머가 이미 끝났다면 이어서 그 사본만 보낸다.
	if not _awaiting_choice and (_synced or generation != _save_generation) and not _pending.is_empty() and _timer.is_stopped():
		_pump.call_deferred()


func _pull_profile() -> void:
	# 먼저 인증해야 조회 본문에 이 세션의 사용자 ID를 넣을 수 있다.
	var response := await _authorized(HTTPClient.METHOD_POST)
	if not _ok(response):
		return
	var data: Variant = response[1]
	if not data is Dictionary:
		_set_connected(false)
		return
	var objects: Variant = data.get("objects", [])
	if not objects is Array:
		_set_connected(false)
		return
	var remote := {}
	if not objects.is_empty() and not bool(_settings.get_value("sync", "reset_pending", false)):
		var object: Variant = objects[0]
		if object is Dictionary:
			var json := JSON.new()
			if json.parse(str(object.get("value", ""))) == OK and json.data is Dictionary:
				remote = json.data
		if not remote.get("nickname") is String or not remote.get("owned") is Dictionary or not remote.get("party") is Dictionary:
			_set_connected(false)
			return
		var update_time := str(object.get("update_time", "")).trim_suffix("Z").get_slice(".", 0)
		if not update_time.is_empty():
			_record_server_save(Time.get_unix_time_from_datetime_string(update_time))
	_awaiting_choice = true
	server_profile_received.emit(remote)


func _upload(profile: Dictionary) -> void:
	var generation := _reset_generation
	var response := await _authorized(HTTPClient.METHOD_PUT, {"objects": [{
		"collection": COLLECTION, "key": PROFILE_KEY, "value": JSON.stringify(profile),
		"permission_read": 1, "permission_write": 1,
	}]})
	if not _ok(response) or generation != _reset_generation:
		return
	_settings.set_value("sync", "reset_pending", false)
	_record_server_save(int(Time.get_unix_time_from_system()))


func _record_server_save(timestamp: int) -> void:
	last_saved_at = timestamp
	_settings.set_value("sync", "last_saved_at", last_saved_at)
	_settings.save(DEVICE_PATH)
	status_changed.emit()


func _authorized(method: HTTPClient.Method, content: Dictionary = {}) -> Array:
	for attempt in 2:
		if _token.is_empty() or _expires_at <= int(Time.get_unix_time_from_system()):
			if not await _login():
				return []
		var payload := content
		if method == HTTPClient.METHOD_POST:
			payload = {"object_ids": [{"collection": COLLECTION, "key": PROFILE_KEY, "user_id": _user_id}]}
		var response := await _request("/v2/storage", method, "Bearer " + _token, payload)
		if not response.is_empty() and int(response[0]) == 401:
			_token = ""
			continue
		_set_connected(_ok(response))
		return response
	_set_connected(false)
	return []


func _login() -> bool:
	var response := await _request("/v2/account/authenticate/device?create=true", HTTPClient.METHOD_POST,
		"Basic " + Marshalls.utf8_to_base64(_server_key + ":"), {"id": _device_id})
	if _ok(response) and response[1] is Dictionary:
		var token := str(response[1].get("token", ""))
		var parts := token.split(".")
		if parts.size() == 3:
			var encoded := parts[1].replace("-", "+").replace("_", "/")
			encoded += "=".repeat(posmod(-encoded.length(), 4))
			var claims := JSON.new()
			if claims.parse(Marshalls.base64_to_utf8(encoded)) == OK and claims.data is Dictionary:
				_user_id = str(claims.data.get("uid", ""))
				_expires_at = int(claims.data.get("exp", 0))
				if not _user_id.is_empty() and _expires_at > int(Time.get_unix_time_from_system()):
					_token = token
					return true
	_set_connected(false)
	return false


func _request(path: String, method: HTTPClient.Method, auth: String, payload: Dictionary) -> Array:
	var headers := PackedStringArray(["Authorization: " + auth, "Content-Type: application/json"])
	if _http.request(_url + path, headers, method, JSON.stringify(payload)) != OK:
		return []
	var result: Array = await _http.request_completed
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return []
	var body: PackedByteArray = result[3]
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(body.get_string_from_utf8()) == OK else null
	return [int(result[1]), parsed]


func _ok(response: Array) -> bool:
	return not response.is_empty() and int(response[0]) >= 200 and int(response[0]) < 300


func _set_connected(value: bool) -> void:
	if value != connected:
		connected = value
		status_changed.emit()
