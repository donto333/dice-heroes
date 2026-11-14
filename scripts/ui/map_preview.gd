extends Control
## 맵 전체 모양을 작은 점으로 그린다. 모험 화면에서 장마다 어떤 모양의 맵인지 보여 준다.

const BoardView := preload("res://scripts/ui/board_view.gd")

var board: Dictionary = {}


func show_board(data: Dictionary) -> void:
	board = data
	queue_redraw()


func _draw() -> void:
	var nodes: Array = board.get("nodes", [])
	if nodes.is_empty():
		return
	var max_x := 0
	var max_y := 0
	for node in nodes:
		max_x = max(max_x, int(node["x"]))
		max_y = max(max_y, int(node["y"]))
	var dot: float = min(size.x / float(max_x + 1), size.y / float(max_y + 1))
	var origin := (size - Vector2(max_x + 1, max_y + 1) * dot) / 2.0
	var by_id := {}
	for node in nodes:
		by_id[int(node["id"])] = node
	var theme: Dictionary = board.get("theme", {})
	var line := Color(str(theme.get("line", "ffffff")))
	line.a = 0.5
	for node in nodes:
		for next_id in node["next"]:
			var other: Dictionary = by_id.get(int(next_id), {})
			if other.is_empty():
				continue
			draw_line(origin + (Vector2(int(node["x"]), int(node["y"])) + Vector2(0.5, 0.5)) * dot,
				origin + (Vector2(int(other["x"]), int(other["y"])) + Vector2(0.5, 0.5)) * dot, line, max(1.0, dot * 0.2))
	for node in nodes:
		var color: Color = BoardView.TILE_COLORS.get(node["type"], Color("3a4466"))
		var spot := origin + Vector2(int(node["x"]), int(node["y"])) * dot
		var inset: float = max(0.5, dot * 0.15)
		draw_rect(Rect2(spot + Vector2(inset, inset), Vector2(dot - inset * 2.0, dot - inset * 2.0)), color)
