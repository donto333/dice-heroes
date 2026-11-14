extends Control
## 보드를 그리는 화면 요소. 프로토타입이라 그림 대신 색 칸과 글자로 그린다.
## 칸의 자리는 board.json의 x, y 좌표를 따르고, 이어진 칸 사이에는 선을 긋는다.
## 말은 규칙 엔진이 보낸 "pos" 사건을 받아 한 칸씩 걸어간다.

const TILE_GAP := 8.0
const STEP_TIME := 0.09
const PAUSE_TIME := 0.35

const TILE_COLORS := {
	"start": Color("5c6b8a"),
	"normal": Color("3a4466"),
	"fork": Color("3a4466"),
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


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	shown_pos = [0, 0]
	if game != null:
		for index in game.players.size():
			shown_pos[index] = int(game.players[index]["pos"])
	queue_redraw()


## [{"player": 0, "to": 칸 id}, ...] 순서대로 한 칸씩 움직인다.
func push_moves(moves: Array) -> void:
	_queue.append_array(moves)


func is_busy() -> bool:
	return not _queue.is_empty()


## 카메라를 이 말에게 맞춘다(턴이 시작될 때 부른다).
func focus_on(player_index: int) -> void:
	focus_player = player_index
	_manual = false


func _process(delta: float) -> void:
	_update_camera(delta)
	_anim_time += delta
	if active_player >= 0:
		queue_redraw()
	if _queue.is_empty():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var move: Dictionary = _queue.pop_front()
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
	return Vector2(clampf(_camera.x, half.x, max(half.x, world.x - half.x)), clampf(_camera.y, half.y, max(half.y, world.y - half.y)))


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

	# 맵마다 다른 바탕색
	var theme: Dictionary = game.board_theme
	var line_color := Color(1, 1, 1, 0.25)
	if theme.has("bg"):
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(str(theme["bg"]))
		bg.set_corner_radius_all(14)
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
	if theme.has("line"):
		line_color = Color(str(theme["line"]))
		line_color.a = 0.35
	# 칸 사이 연결선
	for id in game.nodes:
		for next_id in game.nodes[id]["next"]:
			if game.nodes.has(next_id):
				draw_line(_center(id, layout), _center(next_id, layout), line_color, max(3.0, cell * 0.08))

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
		draw_style_box(_tile_style(color), rect)
		if id in highlight:
			draw_rect(rect.grow(3.0), Color.WHITE, false, 4.0)
		if _icons.has(icon_name):
			var icon_size := rect.size.x * 0.62
			var icon_rect := Rect2(rect.position + Vector2((rect.size.x - icon_size) / 2.0, rect.size.y * 0.10),
				Vector2(icon_size, icon_size))
			draw_texture_rect(_icons[icon_name], icon_rect, false)
		draw_string(font, rect.position + Vector2(3, small), str(id),
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(small * 0.8), Color(1, 1, 1, 0.55))
		if label != "":
			draw_string_outline(font, rect.position + Vector2(0, rect.size.y - 6), label,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, small, 4, Color(0, 0, 0, 0.8))
			draw_string(font, rect.position + Vector2(0, rect.size.y - 6), label,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, small, Color.WHITE)

	# 말. 같은 칸에 있으면 좌우로 나눠 그린다.
	for player_index in shown_pos.size():
		var id := int(shown_pos[player_index])
		if not game.nodes.has(id):
			continue
		var center := _center(id, layout)
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
			var piece_rect := Rect2(center - Vector2(piece, piece) / 2.0 + Vector2(0, bob - cell * 0.08), Vector2(piece, piece))
			# 그림자
			draw_circle(center + Vector2(0, piece * 0.42), piece * 0.32, Color(0, 0, 0, 0.35))
			var frame := StyleBoxFlat.new()
			frame.bg_color = PLAYER_COLORS[player_index]
			frame.set_corner_radius_all(int(piece * 0.18))
			draw_style_box(frame, piece_rect.grow(4.0))
			var size_px := face.get_size()
			var side: float = min(size_px.x, size_px.y) * 0.78
			var src := Rect2((size_px.x - side) / 2.0, 0.0, side, side)
			draw_texture_rect_region(face, piece_rect, src)
			var ring := StyleBoxFlat.new()
			ring.draw_center = false
			ring.border_color = Color.WHITE if player_index == active_player else PLAYER_COLORS[player_index].darkened(0.3)
			ring.set_border_width_all(3)
			ring.set_corner_radius_all(int(piece * 0.18))
			draw_style_box(ring, piece_rect.grow(4.0))
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
	var dot: float = min(MINIMAP_WIDTH * 1.8 / grid.x, MINIMAP_WIDTH / grid.y)
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
		draw_rect(Rect2(spot + Vector2(1, 1), Vector2(dot - 2, dot - 2)), color)
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
