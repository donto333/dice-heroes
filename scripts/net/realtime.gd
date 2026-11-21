extends Node
## 랭크전 한 판의 Nakama 웹소켓 연결. 화면은 수신 큐를 순서대로 처리한다.

signal match_started(start: Dictionary)

const GameData := preload("res://scripts/game_data.gd")
const PARTY := 1
const START := 2
const ACTION := 3
const ACTION_OK := 4
const TURN_END := 5
const RESULT := 6
const PING := 7
const ACTION_SECONDS := 45
const SEARCH_SECONDS := 60

var events: Array[Dictionary] = []
var connected := false
var searching := true
var seconds_left := ACTION_SECONDS
var _session: Callable
var _socket: WebSocketPeer
var _url := ""
var _version := ""
var _party := {}
var _trophies := 0
var _match_id := ""
var _ticket := ""
var _started := false
var _resuming := false
var _retry_at := 0
var _ping_at := 0
var _action_due := 0
var _connected_until := 0
var _replay_until := -1
var _fake := false
var _closing := false
var _close_at := 0


func start(session: Callable, version: String, party: Dictionary, trophies: int) -> void:
	_session = session
	_version = version
	_party = party
	_trophies = trophies
	var config := GameData.load_json("res://data/online.json")
	var scheme := "wss" if str(config["scheme"]) == "https" else "ws"
	_url = "%s://%s:%d/ws?format=json&token=" % [scheme, config["host"], int(config["port"])]
	_connect_socket()


func use_fake() -> void:
	_fake = true
	searching = false
	_started = true
	connected = true
	set_process(false)


func _connect_socket() -> void:
	_retry_at = Time.get_ticks_msec() + 3000
	_socket = WebSocketPeer.new()
	_socket.inbound_buffer_size = 512 * 1024
	_socket.connect_to_url(_url + str(_session.call()).uri_encode())


func _process(_delta: float) -> void:
	if _socket == null:
		return
	var now := Time.get_ticks_msec()
	_socket.poll()
	var state := _socket.get_ready_state()
	if _closing:
		if now >= _close_at or state == WebSocketPeer.STATE_CLOSED:
			_socket.close(1000)
			queue_free()
		return
	if _started and _connected_until > 0 and now >= _connected_until:
		events.append({"op": RESULT, "body": {"winner": -1, "reason": "connection_lost"}})
		_socket.close()
		set_process(false)
		return
	if state == WebSocketPeer.STATE_OPEN:
		if not connected:
			connected = true
			_ping_at = now + 15000
			if _match_id.is_empty():
				_envelope("matchmaker_add", {
					"query": "+properties.mode:rank +properties.version:" + _version,
					"min_count": 2, "max_count": 2,
					"string_properties": {"mode": "rank", "version": _version},
					"numeric_properties": {"trophies": _trophies},
				})
			else:
				_join_match()
		while _socket.get_available_packet_count() > 0:
			_receive(_socket.get_packet().get_string_from_utf8())
		if _started and now >= _ping_at:
			send_match(PING, {})
			_ping_at = now + 15000
	elif state == WebSocketPeer.STATE_CLOSED:
		if connected:
			connected = false
			_ticket = ""
			_resuming = _started
			if _connected_until == 0:
				_connected_until = now + 90000
			_retry_at = now + 3000
		if now >= _retry_at:
			_connect_socket()
	if _started:
		var left := maxi(0, ceili((_action_due - now) / 1000.0))
		if left != seconds_left:
			seconds_left = left


func _envelope(key: String, body: Dictionary) -> bool:
	return connected and _socket.send_text(JSON.stringify({key: body})) == OK


func _join_match() -> void:
	_envelope("match_join", {"match_id": _match_id, "metadata": {"version": _version}})


func send_match(opcode: int, body: Dictionary) -> bool:
	if _fake:
		return false
	return _envelope("match_data_send", {
		"match_id": _match_id, "op_code": opcode, "data": Marshalls.utf8_to_base64(JSON.stringify(body)),
	})


func ready_for_input() -> bool:
	return connected and not _resuming


func _receive(raw: String) -> void:
	var packet: Variant = JSON.parse_string(raw)
	if not packet is Dictionary:
		return
	if packet.has("matchmaker_ticket"):
		_ticket = str(packet["matchmaker_ticket"].get("ticket", ""))
	elif packet.has("matchmaker_matched") and searching:
		_match_id = str(packet["matchmaker_matched"].get("match_id", ""))
		if not _match_id.is_empty():
			_join_match()
	elif packet.has("match") and searching:
		send_match(PARTY, _party)
	elif packet.has("match_data"):
		var data: Dictionary = packet["match_data"]
		if str(data.get("match_id", "")) != _match_id:
			return
		var op := int(data.get("op_code", 0))
		var body: Variant = JSON.parse_string(Marshalls.base64_to_utf8(str(data.get("data", ""))))
		if not body is Dictionary:
			return
		if op == START:
			_set_clock(int(body.get("remaining_sec", ACTION_SECONDS)))
			searching = false
			_resuming = false
			_connected_until = 0
			_replay_until = int(body["seq"]) if _started else -1
			if not _started:
				_started = true
				match_started.emit(body)
			else:
				events.append({"op": START, "body": body})
		elif op in [ACTION_OK, TURN_END, RESULT]:
			if op != RESULT and (op == TURN_END or int(body["seq"]) > _replay_until):
				_set_clock(ACTION_SECONDS)
			events.append({"op": op, "body": body})
	elif packet.has("error") and _resuming:
		_socket.close()


func _set_clock(seconds: int) -> void:
	seconds_left = seconds
	_action_due = Time.get_ticks_msec() + 1000 * seconds


func close(leave: bool = false) -> void:
	if _closing:
		return
	if _socket == null or not connected:
		queue_free()
		return
	if not _match_id.is_empty() and (leave or searching):
		send_match(RESULT, {"reason": "leave"})
	elif searching and not _ticket.is_empty():
		_envelope("matchmaker_remove", {"ticket": _ticket})
	searching = false
	# 소켓을 폴링해 이탈/취소 패킷이 전송될 시간을 준다.
	_closing = true
	_close_at = Time.get_ticks_msec() + 500
	set_process(true)
