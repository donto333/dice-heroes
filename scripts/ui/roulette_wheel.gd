extends Control
## 행운의 룰렛 바퀴. 칸을 부채꼴로 그리고, spin_to()로 정해진 칸이 위쪽 화살표에 오도록 돌린다.
## 어느 칸이 걸릴지는 규칙 코드(Profile.spin_roulette)가 정하고, 여기서는 보여 주기만 한다.

const SPIN_TIME := 3.2
const TURNS := 5

## [{"text": 글자, "color": 색}, ...]
var slots: Array = []:
	set(value):
		slots = value
		queue_redraw()
var angle := 0.0:
	set(value):
		angle = value
		queue_redraw()
var _spinning := false
## UI 개편 2단계: 금테 바퀴·빨간 화살표·가운데 금 단추 그림(assets/ui_menu/roulette_*). 없으면 도형으로 그린다.
var _ring: Texture2D = null
var _arrow: Texture2D = null
var _hub: Texture2D = null

const ART := "res://assets/ui_menu/"
## 바퀴 그림 안쪽 구멍 반지름 / 바깥 반지름(그림에서 잰 값). 칸은 이보다 조금 크게 그려 금테 밑으로 들어가게 한다.
const RING_HOLE := 0.77


func _ready() -> void:
	custom_minimum_size = Vector2(400, 410)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring = _load("roulette_ring")
	_arrow = _load("roulette_arrow")
	_hub = _load("roulette_hub")


func _load(name: String) -> Texture2D:
	var path := ART + name + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return null


func is_spinning() -> bool:
	return _spinning


## index번 칸이 화살표(위쪽)에 멈추도록 돌린다. 멈출 때까지 기다린다.
func spin_to(index: int) -> void:
	if slots.is_empty():
		return
	_spinning = true
	var step := TAU / slots.size()
	# 칸 가운데가 위(-90도)에 오는 각도
	var rest := -PI / 2.0 - (index + 0.5) * step
	var target := rest
	while target < angle + TAU * TURNS:
		target += TAU
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "angle", target, SPIN_TIME)
	await tween.finished
	angle = fposmod(angle, TAU)
	_spinning = false


func _draw() -> void:
	if slots.is_empty():
		return
	var center := Vector2(size.x / 2.0, size.y / 2.0 + 10.0)
	var radius: float = min(size.x, size.y - 30.0) / 2.0 - 8.0
	var step := TAU / slots.size()
	var font := get_theme_default_font()
	if _ring != null:
		_draw_art(center, radius, step, font)
		return
	# 바깥 테
	draw_circle(center + Vector2(0, 6), radius + 12.0, Color(0, 0, 0, 0.4))
	draw_circle(center, radius + 12.0, Color("6b3b00"))
	draw_circle(center, radius + 6.0, Color("ffc62b"))
	for index in slots.size():
		var from := angle + index * step
		var points := PackedVector2Array([center])
		for part in 13:
			var a := from + step * part / 12.0
			points.append(center + Vector2(cos(a), sin(a)) * radius)
		var color: Color = slots[index]["color"]
		draw_colored_polygon(points, color)
		draw_line(center, center + Vector2(cos(from), sin(from)) * radius, Color(1, 1, 1, 0.7), 2.0)
		# 글자는 칸 가운데 방향으로 눕혀 쓴다.
		var mid := from + step / 2.0
		draw_set_transform(center, mid, Vector2.ONE)
		var text := str(slots[index]["text"])
		var font_size := 24
		var width := radius * 0.62
		draw_string_outline(font, Vector2(radius * 0.34, font_size * 0.36), tr(text), HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 6, Color(0, 0, 0, 0.75))
		draw_string(font, Vector2(radius * 0.34, font_size * 0.36), tr(text), HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 테두리 전구
	for bulb in 16:
		var a := angle * 0.0 + TAU * bulb / 16.0
		draw_circle(center + Vector2(cos(a), sin(a)) * (radius + 9.0), 4.0, Color.WHITE if bulb % 2 == 0 else Color("ff6b6b"))
	# 가운데 단추
	draw_circle(center, radius * 0.16, Color("6b3b00"))
	draw_circle(center, radius * 0.12, Color("ffc62b"))
	# 위쪽 화살표
	var tip := center + Vector2(0, -radius + 14.0)
	var arrow := PackedVector2Array([tip, tip + Vector2(-20, -42), tip + Vector2(20, -42)])
	draw_colored_polygon(arrow, Color("e0342b"))
	draw_polyline(PackedVector2Array([tip, tip + Vector2(-20, -42), tip + Vector2(20, -42), tip]), Color.WHITE, 3.0)


## 그림 바퀴: 칸(색·글자)은 코드가 그리고, 그 위에 금테 바퀴·가운데 단추·위 화살표 그림을 덮는다.
func _draw_art(center: Vector2, radius: float, step: float, font: Font) -> void:
	var outer := radius + 14.0
	var wedge := outer * (RING_HOLE + 0.04)
	for index in slots.size():
		var from := angle + index * step
		var points := PackedVector2Array([center])
		for part in 13:
			var a := from + step * part / 12.0
			points.append(center + Vector2(cos(a), sin(a)) * wedge)
		var color: Color = slots[index]["color"]
		draw_colored_polygon(points, color)
		# 칸 안쪽이 살짝 밝게: 바깥쪽 절반에 옅은 흰 띠
		draw_line(center, center + Vector2(cos(from), sin(from)) * wedge, Color(1, 0.92, 0.6, 0.85), 3.0)
		var mid := from + step / 2.0
		draw_set_transform(center, mid, Vector2.ONE)
		var text := tr(str(slots[index]["text"]))
		var font_size := 24
		var inner := outer * RING_HOLE
		var width := inner * 0.66
		var spot := Vector2(inner * 0.27, font_size * 0.36)
		draw_string_outline(font, spot, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 6, Color(0, 0, 0, 0.75))
		draw_string(font, spot, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_texture_rect(_ring, Rect2(center - Vector2(outer, outer), Vector2(outer, outer) * 2.0), false)
	if _hub != null:
		var hub := outer * 0.19
		draw_texture_rect(_hub, Rect2(center - Vector2(hub, hub), Vector2(hub, hub) * 2.0), false)
	else:
		draw_circle(center, radius * 0.16, Color("6b3b00"))
		draw_circle(center, radius * 0.12, Color("ffc62b"))
	if _arrow != null:
		var arrow_size := Vector2(outer * 0.27, outer * 0.27 * _arrow.get_height() / maxf(_arrow.get_width(), 1.0))
		var tip_y := center.y - outer * 0.68
		draw_texture_rect(_arrow, Rect2(Vector2(center.x - arrow_size.x / 2.0, tip_y - arrow_size.y), arrow_size), false)
