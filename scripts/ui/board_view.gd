extends Control
## 보드를 그리는 화면 요소. 프로토타입이라 그림 대신 색 칸과 글자로 그린다.
## 칸의 자리는 board.json의 x, y 좌표를 따르고, 이어진 칸 사이에는 선을 긋는다.
## 말은 규칙 엔진이 보낸 "pos" 사건을 받아 한 칸씩 걸어간다.

const TILE_GAP := 8.0
const STEP_TIME := 0.17
const PAUSE_TIME := 0.35

const TILE_COLORS := {
	"start": Color("5c6b8a"),
	"normal": Color("b59a5c"),
	"fork": Color("8a6fd0"),
	"treasure": Color("c9a227"),
	"battle": Color("d9702b"),
	"ambush": Color("a8323e"),
	"forward": Color("7cb342"),
	"warp": Color("1ba39c"),
	"luck": Color("e6c84a"),
	"curse": Color("5b2a86"),
	"prison": Color("777777"),
	"fate": Color("222222"),
	"checkpoint": Color("4aa3df"),
	"goal": Color("e85d9a"),
}
const HIDDEN_COLOR := Color("4b4f6b")
const ATTR_COLORS := {
	"영웅": Color("c0392b"),
	"위인": Color("2f6fb5"),
	"신화": Color("7d4bb3"),
	"근현대": Color("2e8b57"),
}
const TILE_LABELS := {
	"start": "출발",
	"normal": "",
	"fork": "갈림길",
	"treasure": "보물",
	"battle": "전투",
	"ambush": "습격",
	"forward": "전진",
	"warp": "워프",
	"luck": "행운",
	"curse": "저주",
	"prison": "감옥",
	"fate": "판정",
	"checkpoint": "거점",
	"goal": "골",
}
const PLAYER_COLORS := [Color("4fc3f7"), Color("ff7043")]
const ICON_NAMES := {
	"start": "start", "fork": "fork", "treasure": "treasure", "battle": "battle", "ambush": "ambush",
	"forward": "forward", "warp": "warp", "luck": "luck", "curse": "curse",
	"prison": "prison", "fate": "fate", "checkpoint": "checkpoint", "goal": "goal",
}
const ATTR_ICONS := {"영웅": "attr_hero", "위인": "attr_great", "신화": "attr_myth", "근현대": "attr_modern"}

var _icons: Dictionary = {}
var _styles: Dictionary = {}

signal stepped

var game = null
## 화면에 그려지는 말의 위치(칸 id). 규칙상 위치를 따라 한 칸씩 움직인다.
var shown_pos: Array = [0, 0]
## 갈림길에서 고를 수 있는 칸. 테두리로 강조한다.
var highlight: Array = []
var _queue: Array = []
var _timer := 0.0

## 큰 맵은 화면에 다 안 들어가므로 칸 크기를 MIN_CELL로 두고 카메라로 일부만 보여 준다.
const MIN_CELL := 84.0
const CAMERA_SPEED := 6.0
const MINIMAP_WIDTH := 110.0
## 카메라가 보고 있는 맵 위의 점(맵 좌표, 픽셀)
var _camera := Vector2.ZERO
var _camera_target := Vector2.ZERO
var _camera_ready := false
## 손가락으로 끌어서 보고 있는 중이면 true. 다음 움직임이 시작되면 다시 말을 따라간다.
var _manual := false
var _dragging := false
## 카메라가 따라갈 말
var focus_player := 0
## 말로 그릴 영웅 초상화(플레이어마다). 없으면 기본 말 아이콘.
var piece_textures: Array = [null, null]
## 지금 차례인 말은 살짝 통통 튄다.
var active_player := -1
var _anim_time := 0.0
## 통통 튀는 이동: 말마다 {"from": 칸 id, "t": 0~1}. 없으면 멈춰 있는 것.
var _hops: Dictionary = {}
## 말이 내려앉은 칸에서 퍼지는 고리: [{"id": 칸, "t": 0~1, "color": 색}]
var _rings: Array = []
## 지형 바탕과 꾸밈 그림(assets/terrain). 맵 테마가 바뀌면 다시 읽는다.
var _terrain_name := ""
var _terrain: Texture2D = null
var _deco: Texture2D = null
var _occupied: Dictionary = {}
const TERRAIN_SCALE := 4.0
const HEX_SQUASH := 0.84
const HEX_DEPTH := 0.13
## 판 위에 얹힌 것(정보판, 주사위 버튼)이 가리는 위·아래 높이(픽셀)
var pad_top := 0.0
var pad_bottom := 0.0
var pad_left := 0.0
const HOP_HEIGHT := 0.42


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 지형 바탕을 이어 붙여 그리려면 반복이 켜져 있어야 한다.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# 카메라로 보는 큰 맵이 판 밖으로 삐져나오지 않게 자른다.
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	for icon_name in ["start", "fork", "treasure", "battle", "ambush", "forward", "warp", "luck", "curse", "prison",
			"fate", "checkpoint", "goal", "hidden", "pawn", "attr_hero", "attr_great", "attr_myth", "attr_modern"]:
		var path := "res://assets/icons/%s.png" % icon_name
		if ResourceLoader.exists(path):
			_icons[icon_name] = load(path)


## 칸 바탕: 둥근 모서리에 아래쪽이 어두운 입체 테두리.
func _tile_style(color: Color) -> StyleBoxFlat:
	var key := color.to_html()
	if _styles.has(key):
		return _styles[key]
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(6)
	box.border_color = color.darkened(0.45)
	box.border_width_bottom = 4
	box.border_width_left = 1
	box.border_width_right = 1
	box.border_width_top = 1
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 2
	box.shadow_offset = Vector2(0, 2)
	_styles[key] = box
	return box


func reset_pieces() -> void:
	_queue.clear()
	_timer = 0.0
	_manual = false
	_camera_ready = false
	highlight = []
	_hops = {}
	_rings = []
	shown_pos = [0, 0]
	if game != null:
		for index in game.players.size():
			shown_pos[index] = int(game.players[index]["pos"])
	queue_redraw()


## [{"player": 0, "to": 칸 id}, ...] 순서대로 한 칸씩 움직인다.
func push_moves(moves: Array) -> void:
	_queue.append_array(moves)


## 이 말이 이어서 더 움직일 칸 수(지금 뛰는 칸 포함). 다른 말의 움직임이 끼어들면 거기까지만 센다.
func _steps_left(player_index: int) -> int:
	var count := 1 if _hops.has(player_index) else 0
	for move in _queue:
		if int(move["player"]) != player_index:
			break
		count += 1
	return count if count > 1 else 0


func is_busy() -> bool:
	return not _queue.is_empty() or not _hops.is_empty()


## 카메라를 이 말에게 맞춘다(턴이 시작될 때 부른다).
func focus_on(player_index: int) -> void:
	focus_player = player_index
	_manual = false


func _process(delta: float) -> void:
	_update_camera(delta)
	_anim_time += delta
	if active_player >= 0:
		queue_redraw()
	for player_index in _hops.keys():
		var hop: Dictionary = _hops[player_index]
		hop["t"] = float(hop["t"]) + delta / (STEP_TIME * 0.92)
		if float(hop["t"]) >= 1.0:
			_hops.erase(player_index)
			# 이어서 뛸 칸이 없으면(도착) 고리를 퍼뜨린다.
			if _queue.is_empty() or int(_queue[0]["player"]) != int(player_index):
				_rings.append({"id": int(shown_pos[player_index]), "t": 0.0, "color": PLAYER_COLORS[player_index]})
		queue_redraw()
	if not _rings.is_empty():
		for ring in _rings:
			ring["t"] = float(ring["t"]) + delta / 0.5
		_rings = _rings.filter(func(ring): return float(ring["t"]) < 1.0)
		queue_redraw()
	if _queue.is_empty():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var move: Dictionary = _queue.pop_front()
	_hops[int(move["player"])] = {"from": int(shown_pos[int(move["player"])]), "t": 0.0}
	shown_pos[int(move["player"])] = int(move["to"])
	focus_player = int(move["player"])
	_manual = false
	stepped.emit()
	_timer = STEP_TIME
	# 다음 움직임이 다른 말이면 잠깐 쉬어서 누가 움직이는지 보이게 한다.
	if _queue.is_empty() or int(_queue[0]["player"]) != int(move["player"]):
		_timer = PAUSE_TIME
	queue_redraw()


func _grid_size() -> Vector2i:
	var max_x := 0
	var max_y := 0
	for id in game.nodes:
		max_x = max(max_x, int(game.nodes[id].get("x", 0)))
		max_y = max(max_y, int(game.nodes[id].get("y", 0)))
	return Vector2i(max_x + 1, max_y + 1)


## 맵 전체가 들어가면 화면에 맞추고, 안 들어가면 칸 크기를 고정하고 카메라 위치에 맞춰 그린다.
func _layout() -> Dictionary:
	var grid := _grid_size()
	var fit: float = min(size.x / grid.x, size.y / grid.y)
	if fit >= MIN_CELL:
		var origin := Vector2((size.x - fit * grid.x) / 2.0, (size.y - fit * grid.y) / 2.0)
		return {"cell": fit, "origin": origin, "camera": false}
	var cell := MIN_CELL
	var world := Vector2(grid.x, grid.y) * cell
	var view_origin := size / 2.0 - _clamped_camera(world)
	# 맵이 화면보다 좁은 쪽은 가운데에 둔다.
	if world.x <= size.x:
		view_origin.x = (size.x - world.x) / 2.0
	if world.y <= size.y:
		view_origin.y = (size.y - world.y) / 2.0
	return {"cell": cell, "origin": view_origin, "camera": true, "world": world}


func _clamped_camera(world: Vector2) -> Vector2:
	var half := size / 2.0
	# 위아래 여백만큼 맵 밖까지 밀 수 있게 해서, 가장자리 칸이 판 위에 얹힌 정보판에 가려지지 않게 한다.
	return Vector2(clampf(_camera.x, half.x - pad_left, max(half.x - pad_left, world.x - half.x)),
		clampf(_camera.y, half.y - pad_top, max(half.y - pad_top, world.y - half.y + pad_bottom)))


## 카메라가 따라갈 말의 맵 위 위치(픽셀)
func _focus_point() -> Vector2:
	var id := int(shown_pos[clampi(focus_player, 0, shown_pos.size() - 1)])
	if not game.nodes.has(id):
		return Vector2.ZERO
	var node: Dictionary = game.nodes[id]
	return Vector2(int(node.get("x", 0)) + 0.5, int(node.get("y", 0)) + 0.5) * MIN_CELL


func _update_camera(delta: float) -> void:
	if game == null or game.nodes.is_empty():
		return
	var grid := _grid_size()
	if min(size.x / grid.x, size.y / grid.y) >= MIN_CELL:
		return
	if not _manual:
		_camera_target = _focus_point()
	if not _camera_ready:
		_camera = _camera_target
		_camera_ready = true
		queue_redraw()
		return
	var world := Vector2(grid.x, grid.y) * MIN_CELL
	_camera = _clamped_camera(world)
	if _camera.distance_to(_camera_target) > 0.5 and not _dragging:
		_camera = _camera.lerp(_camera_target, clampf(delta * CAMERA_SPEED, 0.0, 1.0))
		queue_redraw()


## 손가락(마우스)으로 끌면 맵을 둘러본다.
func _gui_input(event: InputEvent) -> void:
	if game == null:
		return
	var grid := _grid_size()
	if min(size.x / grid.x, size.y / grid.y) >= MIN_CELL:
		return
	var world := Vector2(grid.x, grid.y) * MIN_CELL
	if event is InputEventScreenDrag:
		_drag_by(event.relative, world)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_drag_by(event.relative, world)
	elif event is InputEventMouseButton or event is InputEventScreenTouch:
		_dragging = event.is_pressed()


func _drag_by(relative: Vector2, world: Vector2) -> void:
	_manual = true
	_dragging = true
	_camera = _clamped_camera(world) - relative
	_camera = _clamped_camera(world)
	_camera_target = _camera
	queue_redraw()


func _load_terrain(name: String) -> void:
	if name == _terrain_name:
		return
	_terrain_name = name
	_terrain = null
	_deco = null
	if name == "":
		return
	var ground := "res://assets/terrain/%s.png" % name
	if ResourceLoader.exists(ground):
		_terrain = load(ground)
	var sheet := "res://assets/terrain/%s_deco.png" % name
	if ResourceLoader.exists(sheet):
		_deco = load(sheet)
	_occupied = {}
	for id in game.nodes:
		_occupied[Vector2i(int(game.nodes[id].get("x", 0)), int(game.nodes[id].get("y", 0)))] = true


## 칸이 없는 빈 자리에 나무·집·바위 같은 꾸밈 그림을 흩어 놓는다. 자리와 종류는 좌표로 정해져 늘 같다.
func _draw_decorations(layout: Dictionary) -> void:
	if _deco == null:
		return
	var cell: float = layout["cell"]
	var origin: Vector2 = layout["origin"]
	var count: int = max(1, int(_deco.get_width() / 32.0))
	var first := Vector2i(floori(-origin.x / cell) - 1, floori(-origin.y / cell) - 1)
	var last := Vector2i(floori((size.x - origin.x) / cell) + 1, floori((size.y - origin.y) / cell) + 1)
	for gy in range(first.y, last.y + 1):
		for gx in range(first.x, last.x + 1):
			if _occupied.has(Vector2i(gx, gy)):
				continue
			var seed_value: int = absi((gx * 73856093) ^ (gy * 19349663) ^ 0x5bd1e995)
			if seed_value % 100 >= 46:
				continue
			var kind: int = (seed_value / 100) % count
			var jitter := Vector2(((seed_value / 1000) % 21 - 10) / 60.0, ((seed_value / 30000) % 21 - 10) / 60.0)
			var side := cell * (0.78 + ((seed_value / 7) % 20) / 100.0)
			var spot := origin + (Vector2(gx, gy) + Vector2(0.5, 0.5) + jitter) * cell
			draw_texture_rect_region(_deco, Rect2(spot - Vector2(side, side) / 2.0, Vector2(side, side)), Rect2(kind * 32, 0, 32, 32))


## 두께가 있는 육각형 칸. 옆면(어두운 색)을 먼저 그리고 그 위에 윗면을 얹는다.
func _draw_hex(center: Vector2, half: Vector2, cell: float, color: Color, lit: bool) -> void:
	var rx := half.x * 1.06
	var ry := half.y * HEX_SQUASH
	var depth := cell * HEX_DEPTH
	var top := PackedVector2Array()
	var low := PackedVector2Array()
	for corner in 6:
		var a := TAU * corner / 6.0
		var point := center + Vector2(cos(a) * rx, sin(a) * ry) - Vector2(0, depth * 0.5)
		top.append(point)
		low.append(point + Vector2(0, depth))
	var side := color.darkened(0.5)
	# 바닥 그림자
	var shade := PackedVector2Array()
	for point in low:
		shade.append(point + Vector2(0, depth * 0.55))
	draw_colored_polygon(shade, Color(0, 0, 0, 0.3))
	draw_colored_polygon(low, side)
	draw_rect(Rect2(Vector2(center.x - rx, top[0].y), Vector2(rx * 2.0, depth)), side)
	draw_colored_polygon(top, color)
	# 윗면 안쪽의 밝은 테
	var inner := PackedVector2Array()
	for point in top:
		inner.append(top_center(top) + (point - top_center(top)) * 0.86)
	inner.append(inner[0])
	draw_polyline(inner, color.lightened(0.35), 2.0)
	var outline := PackedVector2Array(top)
	outline.append(top[0])
	draw_polyline(outline, Color.WHITE if lit else color.darkened(0.6), 5.0 if lit else 2.5)


func top_center(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point in points:
		sum += point
	return sum / float(points.size())


func _center(id: int, layout: Dictionary) -> Vector2:
	var node: Dictionary = game.nodes[id]
	var cell: float = layout["cell"]
	return layout["origin"] + Vector2(int(node.get("x", 0)) + 0.5, int(node.get("y", 0)) + 0.5) * cell


func _draw() -> void:
	if game == null or game.nodes.is_empty():
		return
	var font := get_theme_default_font()
	var layout := _layout()
	var cell: float = layout["cell"]
	var small: int = int(clamp(cell * 0.18, 9.0, 20.0))

	# 맵마다 다른 바탕: 지형 그림이 있으면 이어 붙여 깔고, 없으면 바탕색.
	var theme: Dictionary = game.board_theme
	_load_terrain(str(theme.get("terrain", "")))
	if theme.has("bg"):
		draw_rect(Rect2(Vector2.ZERO, size), Color(str(theme["bg"])))
	var origin: Vector2 = layout["origin"]
	if _terrain != null:
		var scale_px := cell / 21.0 if not bool(layout.get("camera", false)) else TERRAIN_SCALE
		draw_texture_rect_region(_terrain, Rect2(Vector2.ZERO, size), Rect2(-origin / scale_px, size / scale_px))
		_draw_decorations(layout)
	# 칸 사이 연결선은 흙길처럼: 어두운 테 위에 밝은 길
	var road := Color(str(theme.get("line", "ffffff")))
	for pass_index in 2:
		var road_color := Color(0, 0, 0, 0.28) if pass_index == 0 else Color(road.r, road.g, road.b, 0.55)
		var road_width: float = cell * (0.30 if pass_index == 0 else 0.20)
		for id in game.nodes:
			for next_id in game.nodes[id]["next"]:
				if game.nodes.has(next_id):
					draw_line(_center(id, layout), _center(next_id, layout), road_color, road_width)

	var view := Rect2(Vector2(-cell, -cell), size + Vector2(cell, cell) * 2.0)
	for id in game.nodes:
		var tile: Dictionary = game.nodes[id]
		var half := Vector2(cell - TILE_GAP, cell - TILE_GAP) / 2.0
		var rect := Rect2(_center(id, layout) - half, half * 2.0)
		if not view.intersects(rect):
			continue
		var color: Color = TILE_COLORS.get(tile["type"], Color("3a4466"))
		var label: String = TILE_LABELS.get(tile["type"], "")
		var icon_name: String = ICON_NAMES.get(tile["type"], "")
		if tile["type"] == "attr":
			color = ATTR_COLORS.get(tile["attr"], color)
			label = tile["attr"]
			icon_name = ATTR_ICONS.get(tile["attr"], "")
		if game.is_hidden(id):
			color = HIDDEN_COLOR
			label = ""
			icon_name = "hidden"
		_draw_hex(rect.get_center(), half, cell, color, id in highlight)
		if _icons.has(icon_name):
			var icon_size := rect.size.x * 0.52
			var icon_rect := Rect2(rect.position + Vector2((rect.size.x - icon_size) / 2.0, rect.size.y * 0.09),
				Vector2(icon_size, icon_size))
			draw_texture_rect(_icons[icon_name], icon_rect, false)
		if label != "":
			draw_string_outline(font, rect.position + Vector2(0, rect.size.y * 0.76), label,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, small, 4, Color(0, 0, 0, 0.8))
			draw_string(font, rect.position + Vector2(0, rect.size.y * 0.76), label,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, small, Color.WHITE)

	# 골 칸은 반짝이는 테와 수호자 이름으로 눈에 띄게
	for id in game.nodes:
		if game.nodes[id].get("type", "") != "goal":
			continue
		var goal_center := _center(id, layout)
		if not view.has_point(goal_center):
			continue
		var pulse := 0.5 + 0.5 * sin(_anim_time * 3.0)
		draw_set_transform(goal_center - Vector2(0, cell * HEX_DEPTH * 0.5), 0.0, Vector2(1.0, HEX_SQUASH))
		draw_arc(Vector2.ZERO, cell * (0.56 + pulse * 0.06), 0.0, TAU, 40, Color(1.0, 0.85, 0.3, 0.9 - pulse * 0.4), 5.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var boss := "수호자 %s" % str(game.nodes[id].get("name", ""))
		var boss_size := int(cell * 0.2)
		var boss_pos := goal_center + Vector2(-cell * 1.5, -cell * 0.62)
		draw_string_outline(font, boss_pos, boss, HORIZONTAL_ALIGNMENT_CENTER, cell * 3.0, boss_size, 6, Color.BLACK)
		draw_string(font, boss_pos, boss, HORIZONTAL_ALIGNMENT_CENTER, cell * 3.0, boss_size, Color("ffcf4d"))
	# 내려앉은 칸에서 퍼지는 고리
	for ring in _rings:
		if not game.nodes.has(int(ring["id"])):
			continue
		var ring_t := float(ring["t"])
		var ring_color: Color = ring["color"]
		ring_color.a = 1.0 - ring_t
		draw_set_transform(_center(int(ring["id"]), layout) - Vector2(0, cell * HEX_DEPTH * 0.5), 0.0, Vector2(1.0, HEX_SQUASH))
		draw_arc(Vector2.ZERO, cell * (0.35 + ring_t * 0.55), 0.0, TAU, 36, ring_color, 6.0 * (1.0 - ring_t) + 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 말. 같은 칸에 있으면 좌우로 나눠 그린다.
	for player_index in shown_pos.size():
		var id := int(shown_pos[player_index])
		if not game.nodes.has(id):
			continue
		var center := _center(id, layout)
		var lift := 0.0
		if _hops.has(player_index) and game.nodes.has(int(_hops[player_index]["from"])):
			# 앞 칸에서 이 칸으로 포물선을 그리며 뛴다.
			var t := clampf(float(_hops[player_index]["t"]), 0.0, 1.0)
			center = _center(int(_hops[player_index]["from"]), layout).lerp(center, t)
			lift = sin(t * PI) * cell * HOP_HEIGHT
		center.x += (player_index * 2 - 1) * cell * 0.22
		center.y += cell * 0.06
		var pawn_size := cell * 0.62
		var pawn_rect := Rect2(center - Vector2(pawn_size, pawn_size) / 2.0, Vector2(pawn_size, pawn_size))
		var face: Texture2D = piece_textures[player_index] if player_index < piece_textures.size() else null
		if face != null:
			var piece := cell * 0.7
			var bob := 0.0
			if player_index == active_player and _queue.is_empty():
				bob = -abs(sin(_anim_time * 4.0)) * cell * 0.08
			var player_color: Color = PLAYER_COLORS[player_index]
			var radius := cell * 0.34
			var foot := center + Vector2(0, cell * 0.16)
			var head := foot + Vector2(0, bob - lift - cell * 0.52)
			var piece_rect := Rect2(head - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
			# 그림자(높이 뛸수록 작고 옅게)
			var shade := 1.0 - lift / (cell * HOP_HEIGHT) * 0.45 if lift > 0.0 else 1.0
			draw_set_transform(foot, 0.0, Vector2(1.0, 0.42))
			draw_circle(Vector2.ZERO, cell * 0.27 * shade, Color(0, 0, 0, 0.38 * shade))
			draw_set_transform(Vector2(foot.x, foot.y + bob - lift), 0.0, Vector2(1.0, 0.42))
			# 받침대
			draw_circle(Vector2(0, cell * 0.05), cell * 0.2, player_color.darkened(0.45))
			draw_circle(Vector2.ZERO, cell * 0.2, player_color)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# 받침대와 초상화를 잇는 목
			var base_top := Vector2(foot.x, foot.y + bob - lift)
			draw_colored_polygon(PackedVector2Array([base_top + Vector2(-cell * 0.1, 0), base_top + Vector2(cell * 0.1, 0),
				head + Vector2(cell * 0.14, radius * 0.6), head + Vector2(-cell * 0.14, radius * 0.6)]), player_color.darkened(0.2))
			# 둥근 초상화: 색 테 → 그림 → 흰 테(내 차례일 때)
			draw_circle(head, radius + 5.0, player_color.darkened(0.45))
			draw_circle(head, radius + 3.0, Color.WHITE if player_index == active_player else player_color)
			var size_px := face.get_size()
			var side: float = min(size_px.x, size_px.y) * 0.78
			var src := Rect2((size_px.x - side) / 2.0, 0.0, side, side)
			var ring_points := PackedVector2Array()
			var ring_uvs := PackedVector2Array()
			for corner in 28:
				var a := TAU * corner / 28.0
				var unit := Vector2(cos(a), sin(a))
				ring_points.append(head + unit * radius)
				ring_uvs.append((src.position + (unit * 0.5 + Vector2(0.5, 0.5)) * src.size) / size_px)
			draw_colored_polygon(ring_points, Color.WHITE, ring_uvs, face)
			# 이동 중이면 남은 칸 수를 말 위에 보여 준다.
			var left := _steps_left(player_index)
			if left > 0:
				var bubble_center := Vector2(piece_rect.get_center().x, piece_rect.position.y - cell * 0.2)
				draw_circle(bubble_center, cell * 0.19, Color("ffcf4d"))
				draw_arc(bubble_center, cell * 0.19, 0.0, TAU, 24, Color("4a2600"), 2.5)
				var count_size := int(cell * 0.26)
				draw_string(font, bubble_center + Vector2(-cell * 0.19, count_size * 0.36), str(left),
					HORIZONTAL_ALIGNMENT_CENTER, cell * 0.38, count_size, Color("4a2600"))
			continue
		if _icons.has("pawn"):
			draw_texture_rect(_icons["pawn"], pawn_rect, false, PLAYER_COLORS[player_index])
		else:
			draw_circle(center, cell * 0.14, PLAYER_COLORS[player_index])
	if bool(layout.get("camera", false)):
		_draw_minimap(layout)


## 오른쪽 위의 작은 전체 지도: 칸은 점, 말은 색 점, 지금 보이는 곳은 흰 네모.
func _draw_minimap(layout: Dictionary) -> void:
	var grid := _grid_size()
	# 아주 긴 맵(직선형)은 작은 지도를 가로로 더 길게 쓴다.
	var dot: float = min(MINIMAP_WIDTH * 2.6 / grid.x, MINIMAP_WIDTH / grid.y)
	var map_size := Vector2(grid.x, grid.y) * dot
	var corner := Vector2(size.x - map_size.x - 10.0, 10.0)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0, 0, 0, 0.45)
	panel.set_corner_radius_all(8)
	draw_style_box(panel, Rect2(corner - Vector2(6, 6), map_size + Vector2(12, 12)))
	for id in game.nodes:
		var tile: Dictionary = game.nodes[id]
		var color: Color = TILE_COLORS.get(tile["type"], Color("3a4466"))
		if tile["type"] == "attr":
			color = ATTR_COLORS.get(tile["attr"], color)
		if game.is_hidden(id):
			color = HIDDEN_COLOR
		var spot := corner + Vector2(int(tile.get("x", 0)), int(tile.get("y", 0))) * dot
		color.a = 0.7
		var dot_size: float = max(dot - 1.0, 2.5)
		color.a = 0.9
		draw_rect(Rect2(spot, Vector2(dot_size, dot_size)), color)
	for player_index in shown_pos.size():
		var id := int(shown_pos[player_index])
		if game.nodes.has(id):
			var node: Dictionary = game.nodes[id]
			var center := corner + (Vector2(int(node.get("x", 0)), int(node.get("y", 0))) + Vector2(0.5, 0.5)) * dot
			draw_circle(center, max(3.0, dot * 0.45), PLAYER_COLORS[player_index])
			draw_arc(center, max(3.0, dot * 0.45), 0.0, TAU, 12, Color.BLACK, 1.0)
	var cell: float = layout["cell"]
	var shown := Rect2(-layout["origin"] / cell * dot, size / cell * dot)
	shown.position += corner
	draw_rect(shown.intersection(Rect2(corner, map_size)), Color.WHITE, false, 1.5)
