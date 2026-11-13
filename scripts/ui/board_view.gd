extends Control
## 보드를 그리는 화면 요소. 프로토타입이라 그림 대신 색 칸과 글자로 그린다.
## 칸은 한 줄에 COLUMNS개씩, 줄마다 방향을 바꿔 가며(뱀 모양) 놓는다.

const COLUMNS := 7
const TILE_GAP := 6.0

const TILE_COLORS := {
	"start": Color("5c6b8a"),
	"normal": Color("3a4466"),
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
const ATTR_COLORS := {
	"영웅": Color("c0392b"),
	"위인": Color("2f6fb5"),
	"신화": Color("7d4bb3"),
	"근현대": Color("2e8b57"),
}
const TILE_LABELS := {
	"start": "출발",
	"normal": "",
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

var game = null


func _draw() -> void:
	if game == null or game.board.is_empty():
		return
	var font := get_theme_default_font()
	var count: int = game.board.size()
	var rows: int = int(ceil(float(count) / COLUMNS))
	var cell: float = min(size.x / COLUMNS, size.y / rows)
	var origin := Vector2((size.x - cell * COLUMNS) / 2.0, (size.y - cell * rows) / 2.0)
	var small: int = int(clamp(cell * 0.20, 10.0, 22.0))
	var big: int = int(clamp(cell * 0.26, 12.0, 28.0))

	for index in count:
		var tile: Dictionary = game.board[index]
		var rect := Rect2(_cell_origin(index, origin, cell) + Vector2(TILE_GAP, TILE_GAP) / 2.0,
			Vector2(cell - TILE_GAP, cell - TILE_GAP))
		var color: Color = TILE_COLORS.get(tile["type"], Color("3a4466"))
		var label: String = TILE_LABELS.get(tile["type"], "")
		if tile["type"] == "attr":
			color = ATTR_COLORS.get(tile["attr"], color)
			label = tile["attr"]
		draw_rect(rect, color)
		draw_string(font, rect.position + Vector2(4, small + 2), str(index),
			HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(1, 1, 1, 0.7))
		if label != "":
			draw_string(font, rect.position + Vector2(0, rect.size.y * 0.62), label,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, big, Color.WHITE)

	# 말. 같은 칸에 있으면 좌우로 나눠 그린다.
	for player_index in game.players.size():
		var pos := int(game.players[player_index]["pos"])
		var center := _cell_origin(pos, origin, cell) + Vector2(cell, cell) / 2.0
		center.x += (player_index * 2 - 1) * cell * 0.20
		center.y += cell * 0.22
		draw_circle(center, cell * 0.17, Color.BLACK)
		draw_circle(center, cell * 0.14, PLAYER_COLORS[player_index])


func _cell_origin(index: int, origin: Vector2, cell: float) -> Vector2:
	var row := index / COLUMNS
	var column := index % COLUMNS
	if row % 2 == 1:
		column = COLUMNS - 1 - column
	return origin + Vector2(column * cell, row * cell)
