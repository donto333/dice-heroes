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
## 화려한 창틀(위·아래 가운데 장식)을 쓸지. 가운데 뜨는 창(dialog)만 켠다. 나머지 판은 얇은 금테 카드 틀.
var grand := false
var _rim := StyleBoxFlat.new()
const UiSkin := preload("res://scripts/ui/skin.gd")
const Observatory := preload("res://scripts/ui/observatory_theme.gd")
const DIALOG_GLASS := preload("res://assets/ui_observatory/ui_menu/friend_party/board.png")
const INSET_GLASS := preload("res://assets/ui_observatory/ui_menu/friend_party/ability.png")


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
	if Observatory.active:
		var glass: Texture2D = DIALOG_GLASS if grand else INSET_GLASS
		var edge := 32 if grand else 22
		var factor := minf(1.0 if grand else 0.75, minf(rect.size.x, rect.size.y) / (edge * 2.0))
		UiSkin.draw_grid(item, glass, rect, [0, edge, glass.get_width() - edge, glass.get_width()], [false, true, false],
			[0, edge, glass.get_height() - edge, glass.get_height()], [false, true, false], factor, Color(1.0, 1.0, 1.0, fill.a))
		return
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	if _draw_skin(item, rect, r):
		return
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


## 그림 틀(assets/ui_kit)로 그린다. 그림이 없으면 false(예전 도형 그리기로).
## 큰 판은 장식 창틀(win_), 작은 칸은 얇은 카드 테(card_)를 쓴다. 금색 테가 아니면 은색 틀에 테 색을 입힌다.
func _draw_skin(item: RID, rect: Rect2, r: float) -> bool:
	var small := minf(rect.size.x, rect.size.y)
	var golden := trim.s > 0.35 and trim.h > 0.07 and trim.h < 0.19
	var big := grand and small >= 150.0 and rect.size.x >= 260.0
	var name := ("win_navy" if golden else "win_violet") if big else ("card_navy" if golden else "card_violet")
	if not UiSkin.has(name) or UiSkin.meta(name).is_empty():
		return false
	var scale := clampf(small / 420.0, 0.42, 0.8) if big else clampf(small / 170.0, 0.3, 0.8)
	var edge := UiSkin.border(name) * scale
	# 1) 그림자
	if shadow:
		_rim.bg_color = Color(0, 0, 0, 0.0)
		_rim.draw_center = false
		_rim.set_corner_radius_all(int(r))
		_rim.shadow_color = Color(0, 0.02, 0.12, 0.4 * fill.a)
		_rim.shadow_size = 9
		_rim.shadow_offset = Vector2(0, 5)
		_rim.draw(item, rect.grow(-2.0))
	# 2) 몸통: 위는 밝고 아래는 짙게 + 위쪽 광택
	var corner := maxf(r, edge * 1.6)
	var body := outline(rect, corner, edge * 0.5)
	RenderingServer.canvas_item_add_polygon(item, body, shade(body, rect, fill.lightened(0.14), fill.darkened(0.3)))
	var gloss_rect := Rect2(rect.position, Vector2(rect.size.x, minf(rect.size.y * 0.45, 70.0)))
	var gloss := outline(gloss_rect, corner, edge * 0.5 + 2.0)
	RenderingServer.canvas_item_add_polygon(item, gloss, shade(gloss, gloss_rect, Color(1, 1, 1, 0.13 * fill.a), Color(1, 1, 1, 0.0)))
	# 3) 그림 틀
	var tint := Color(1, 1, 1, minf(fill.a + 0.35, 1.0))
	if not golden:
		var metal := trim.lightened(0.25)
		tint = Color(metal.r, metal.g, metal.b, tint.a)
	UiSkin.draw_frame(item, name, rect, scale, 0.46 if big else 0.0, tint)
	return true
