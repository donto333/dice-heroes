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
	"start": "start", "fork": "fork", "treasure": "treasure", "battle": "battle",
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


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for icon_name in ["start", "fork", "treasure", "battle", "forward", "warp", "luck", "curse", "prison",
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


func _process(delta: float) -> void:
	if _queue.is_empty():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var move: Dictionary = _queue.pop_front()
	shown_pos[int(move["player"])] = int(move["to"])
	stepped.emit()
	_timer = STEP_TIME
	# 다음 움직임이 다른 말이면 잠깐 쉬어서 누가 움직이는지 보이게 한다.
	if _queue.is_empty() or int(_queue[0]["player"]) != int(move["player"]):
		_timer = PAUSE_TIME
	queue_redraw()


func _layout() -> Dictionary:
	var max_x := 0
	var max_y := 0
	for id in game.nodes:
		max_x = max(max_x, int(game.nodes[id].get("x", 0)))
		max_y = max(max_y, int(game.nodes[id].get("y", 0)))
	var columns := max_x + 1
	var rows := max_y + 1
	var cell: float = min(size.x / columns, size.y / rows)
	var origin := Vector2((size.x - cell * columns) / 2.0, (size.y - cell * rows) / 2.0)
	return {"cell": cell, "origin": origin}


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

	# 칸 사이 연결선
	for id in game.nodes:
		for next_id in game.nodes[id]["next"]:
			if game.nodes.has(next_id):
				draw_line(_center(id, layout), _center(next_id, layout), Color(1, 1, 1, 0.25), max(3.0, cell * 0.08))

	for id in game.nodes:
		var tile: Dictionary = game.nodes[id]
		var half := Vector2(cell - TILE_GAP, cell - TILE_GAP) / 2.0
		var rect := Rect2(_center(id, layout) - half, half * 2.0)
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
		if _icons.has("pawn"):
			draw_texture_rect(_icons["pawn"], pawn_rect, false, PLAYER_COLORS[player_index])
		else:
			draw_circle(center, cell * 0.14, PLAYER_COLORS[player_index])
