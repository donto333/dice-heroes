extends StyleBox
## 장식 판 상자: 글·설명이 들어가는 칸을 밋밋한 단색 상자 대신 고급스럽게 그린다.
## 그림자 → 짙은 바깥 테 → 위에서 아래로 번지는 몸통 → 위쪽 광택 → 금속 테(위는 밝고 아래는 어둡다)
## → 안쪽 가는 선 → 네 귀퉁이 보석 순서로 쌓는다. Kit.plate()와 Kit.panel()이 만든다.
## 여백은 StyleBox의 content_margin_* 값을 그대로 쓴다.

var fill := Color("1a56b0")
var trim := Color("f2c14e")
var radius := 20.0
var trim_width := 4.0
## 귀퉁이 보석을 그릴지(작은 칸은 끈다)
var gems := true
var gem_color := Color("7fe3ff")
var shadow := true
var _rim := StyleBoxFlat.new()


## 둥근 사각형의 테두리 점들(시계 방향). inset만큼 안쪽으로 들어간다.
static func outline(rect: Rect2, corner: float, inset: float) -> PackedVector2Array:
	var box := rect.grow(-inset)
	var r := clampf(corner - inset, 1.0, minf(box.size.x, box.size.y) * 0.5)
	var points := PackedVector2Array()
	var centers := [
		box.position + Vector2(box.size.x - r, r), box.position + Vector2(box.size.x - r, box.size.y - r),
		box.position + Vector2(r, box.size.y - r), box.position + Vector2(r, r)]
	var steps := 6
	for corner_index in 4:
		var start := -PI * 0.5 + corner_index * PI * 0.5
		var center: Vector2 = centers[corner_index]
		for step in steps + 1:
			var angle := start + PI * 0.5 * float(step) / float(steps)
			points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points


## 점의 높이에 따라 위 색에서 아래 색으로 번지는 색 배열
static func shade(points: PackedVector2Array, rect: Rect2, top: Color, bottom: Color) -> PackedColorArray:
	var colors := PackedColorArray()
	for point in points:
		colors.append(top.lerp(bottom, clampf((point.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 1.0)))
	return colors


func _draw(item: RID, rect: Rect2) -> void:
	if rect.size.x < 10.0 or rect.size.y < 10.0:
		return
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	# 1) 그림자와 짙은 바깥 테
	_rim.bg_color = Color(fill.r * 0.2, fill.g * 0.2, fill.b * 0.28, minf(fill.a + 0.2, 1.0))
	_rim.set_corner_radius_all(int(r))
	_rim.corner_detail = 8
	_rim.anti_aliasing_size = 1.2
	if shadow:
		_rim.shadow_color = Color(0, 0.02, 0.12, 0.42 * fill.a)
		_rim.shadow_size = 8
		_rim.shadow_offset = Vector2(0, 4)
	else:
		_rim.shadow_size = 0
	_rim.draw(item, rect)
	# 2) 몸통: 위는 밝고 아래는 짙게
	var body := outline(rect, r, 3.0)
	RenderingServer.canvas_item_add_polygon(item, body, shade(body, rect, fill.lightened(0.16), fill.darkened(0.3)))
	# 3) 위쪽 광택
	var gloss_rect := Rect2(rect.position, Vector2(rect.size.x, minf(rect.size.y * 0.45, 70.0)))
	var gloss := outline(gloss_rect, r, 5.0)
	RenderingServer.canvas_item_add_polygon(item, gloss, shade(gloss, gloss_rect, Color(1, 1, 1, 0.16 * fill.a), Color(1, 1, 1, 0.0)))
	# 4) 금속 테
	var ring := outline(rect, r, 3.0 + trim_width * 0.5)
	ring.append(ring[0])
	RenderingServer.canvas_item_add_polyline(item, ring, shade(ring, rect, trim.lightened(0.45), trim.darkened(0.4)), trim_width, true)
	# 5) 안쪽 가는 선(두 줄 테 느낌)
	if minf(rect.size.x, rect.size.y) >= 56.0:
		var line := outline(rect, r, 3.0 + trim_width + 4.0)
		line.append(line[0])
		var thin := Color(trim.r, trim.g, trim.b, 0.5)
		RenderingServer.canvas_item_add_polyline(item, line, PackedColorArray([thin]), 1.4, true)
	# 6) 네 귀퉁이 보석
	if gems and minf(rect.size.x, rect.size.y) >= 84.0:
		var reach := 3.0 + trim_width * 0.5 + r * 0.293
		for corner in [Vector2(reach, reach), Vector2(rect.size.x - reach, reach),
				Vector2(rect.size.x - reach, rect.size.y - reach), Vector2(reach, rect.size.y - reach)]:
			var spot: Vector2 = rect.position + corner
			_gem(item, spot, 7.5, Color(0.1, 0.06, 0.02))
			_gem(item, spot, 5.5, gem_color)
			_gem(item, spot + Vector2(-1.2, -1.2), 2.0, Color(1, 1, 1, 0.9))


func _gem(item: RID, center: Vector2, size: float, color: Color) -> void:
	RenderingServer.canvas_item_add_polygon(item, PackedVector2Array([
		center + Vector2(0, -size), center + Vector2(size, 0), center + Vector2(0, size), center + Vector2(-size, 0)]),
		PackedColorArray([color]))
