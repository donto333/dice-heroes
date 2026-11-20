extends PanelContainer
## 갈림길 두 갈래의 생김새와 칸 수를 한눈에 보여 준다.

const Kit := preload("res://scripts/ui/kit.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const COLORS := [Color("ffcd78"), Color("87e8ff")]

signal chosen(index: int)

var _lanes: Array[PackedVector2Array] = []
var _joined := false


func setup(game) -> void:
	var shape: Dictionary = game.choice_routes()
	_joined = bool(shape["joined"])
	var paths: Array = shape["paths"]
	var origin := int(game.players[game.current]["pos"])
	add_theme_stylebox_override("panel", Kit.plate(Kit.Observatory.SURFACE if Kit.Observatory.active else Color("1a2861"), Kit.TRIM, 18.0, 16, false))
	var body := Kit.vbox(7)
	add_child(body)
	body.add_child(Kit.label("갈림길 · 남은 이동 %d칸" % int(game.pending_choice["steps"]), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var preview := Control.new()
	preview.custom_minimum_size.y = 96
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.draw.connect(_draw_routes.bind(preview))
	preview.resized.connect(preview.queue_redraw)
	body.add_child(preview)
	var choices := Kit.hbox(10)
	body.add_child(choices)
	for index in paths.size():
		var path: Array = paths[index]
		var points := PackedVector2Array([_position(game.node_of(origin))])
		for id in path:
			points.append(_position(game.node_of(id)))
		_lanes.append(points)
		var button := MenuArt.pill_button("", "gold" if index == 0 else "blue", "l")
		button.custom_minimum_size.y = 88
		button.pressed.connect(chosen.emit.bind(index))
		choices.add_child(Kit.expand(button))
		var text := Kit.vbox(0)
		text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		text.offset_left = 22
		text.offset_right = -22
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(text)
		var distance := "합류까지 %d칸" if _joined else "이 갈래 %d칸"
		text.add_child(Kit.label(distance % path.size(), 27, COLORS[index % COLORS.size()], HORIZONTAL_ALIGNMENT_CENTER))
		var name_label := Kit.para(game.choice_label(index), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(name_label)


func _position(tile: Dictionary) -> Vector2:
	return Vector2(float(tile.get("x", 0)), float(tile.get("y", 0)))


func _draw_routes(view: Control) -> void:
	var bounds := Rect2(_lanes[0][0], Vector2.ZERO)
	for lane in _lanes:
		for point in lane:
			bounds = bounds.expand(point)
	var room := view.size - Vector2(38, 20)
	var step := minf(room.x / maxf(1.0, bounds.size.x), room.y / maxf(1.0, bounds.size.y))
	var shift := view.size * 0.5 - bounds.get_center() * step
	for index in _lanes.size():
		var color: Color = COLORS[index % COLORS.size()]
		var points := PackedVector2Array()
		for point in _lanes[index]:
			points.append(shift + point * step)
		if points.size() > 1:
			view.draw_polyline(points, color, 3.0, true)
		for point in points:
			view.draw_circle(point, 4.0, color, true, -1.0, true)
	view.draw_circle(shift + _lanes[0][0] * step, 6.0, Color.WHITE, true, -1.0, true)
	if _joined:
		view.draw_circle(shift + _lanes[0][-1] * step, 6.0, Color.WHITE, true, -1.0, true)
