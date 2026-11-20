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
const Kit := preload("res://scripts/ui/kit.gd")
const Observatory := preload("res://scripts/ui/observatory_theme.gd")
const GOLD_ICON := preload("res://assets/ui_icons/gold.png")
const GEM_ICON := preload("res://assets/ui_icons/gem.png")
## 바퀴 그림 안쪽 구멍 반지름 / 바깥 반지름(그림에서 잰 값). 칸은 이보다 조금 크게 그려 금테 밑으로 들어가게 한다.
const RING_HOLE := 0.77


func _ready() -> void:
	custom_minimum_size = Vector2(535, 524) if Observatory.active else Vector2(380, 380)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring = _load("roulette_ring")
	_arrow = _load("roulette_arrow")
	_hub = _load("roulette_hub")
	if Observatory.active and not slots.is_empty():
		angle = -PI / 2.0 - PI / slots.size()


func _load(name: String) -> Texture2D:
	var observatory := Observatory.texture("ui_menu", name)
	if observatory != null:
		return observatory
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
	if Observatory.active and _ring != null and _hub != null and _arrow != null:
		_draw_observatory(center, (minf(size.x, size.y) - 26.0) / 2.0, step, font)
		return
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
		_draw_label(center, from + step / 2.0, radius * 0.62, radius * 0.6, tr(str(slots[index]["text"])), font)
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
	var inner := outer * RING_HOLE
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
		_draw_label(center, from + step / 2.0, inner * 0.6, inner * 0.62, tr(str(slots[index]["text"])), font)
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


func _draw_observatory(center: Vector2, outer: float, step: float, font: Font) -> void:
	var wedge := outer * 0.964
	draw_circle(center, outer - 3.0, Color("1e1a36"), true, -1, true)
	for index in slots.size():
		var from := angle + index * step
		var points := PackedVector2Array([center])
		var colors := PackedColorArray([Color("a084a8")])
		var base := Color("504060") if index % 2 == 0 else Color("242d52")
		for part in 13:
			var a := from + step * part / 12.0
			points.append(center + Vector2.from_angle(a) * wedge)
			colors.append(base)
		draw_polygon(points, colors)
		draw_line(center, center + Vector2.from_angle(from) * wedge, Color("b69cb6"), 1.5, true)
		var mid := from + step * 0.5
		var reward: Dictionary = slots[index].get("reward", {})
		if reward.is_empty():
			_draw_label(center, mid, outer * 0.68, 93, tr(str(slots[index]["text"])), font)
			continue
		var gem := reward.has("gems")
		var spot := center + Vector2.from_angle(mid) * (outer * 0.68)
		draw_texture_rect(GEM_ICON if gem else GOLD_ICON, Rect2(spot - Vector2(27, 35), Vector2(54, 54)), false)
		var amount := Kit.comma(int(reward.get("gems" if gem else "gold", 0)))
		_draw_label(center + Vector2(0, 23), mid, outer * 0.68, 94, amount, font)
	draw_texture_rect(_ring, Rect2(center - Vector2.ONE * outer, Vector2.ONE * outer * 2.0), false)
	var hub := outer * 0.215
	draw_texture_rect(_hub, Rect2(center - Vector2.ONE * hub, Vector2.ONE * hub * 2.0), false)
	var arrow := Vector2(48, 50)
	draw_texture_rect(_arrow, Rect2(center + Vector2(-arrow.x * 0.5, -outer - 4), arrow), false)


## 칸 글자: 칸 가운데(반지름 at 자리)에 바로 선 두 줄 글자(종류 위, 수량 아래)로 쓴다.
## 눕혀 쓰면 위·아래·왼쪽 칸 글자가 세로나 거꾸로 보여서 바꿨다(2026-11-20 사용자 요청).
func _draw_label(center: Vector2, mid: float, at: float, width: float, text: String, font: Font) -> void:
	var parts := text.split(" ", false, 1)
	var top := parts[0] if parts.size() > 1 else ""
	var big := parts[1] if parts.size() > 1 else text
	var spot := center + Vector2(cos(mid), sin(mid)) * at
	var box := minf(width, 96.0)
	var big_size := 26
	while big_size > 14 and font.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, big_size).x > box:
		big_size -= 1
	var small_size := 17
	while small_size > 11 and font.get_string_size(top, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size).x > box:
		small_size -= 1
	var left := spot.x - box / 2.0
	if top != "":
		var y1 := spot.y - 4.0
		draw_string_outline(font, Vector2(left, y1), top, HORIZONTAL_ALIGNMENT_CENTER, box, small_size, 5, Color(0, 0, 0, 0.75))
		draw_string(font, Vector2(left, y1), top, HORIZONTAL_ALIGNMENT_CENTER, box, small_size, Color(1, 0.95, 0.75))
		var y2 := spot.y + big_size * 0.85
		draw_string_outline(font, Vector2(left, y2), big, HORIZONTAL_ALIGNMENT_CENTER, box, big_size, 6, Color(0, 0, 0, 0.75))
		draw_string(font, Vector2(left, y2), big, HORIZONTAL_ALIGNMENT_CENTER, box, big_size, Color.WHITE)
	else:
		var y := spot.y + big_size * 0.36
		draw_string_outline(font, Vector2(left, y), big, HORIZONTAL_ALIGNMENT_CENTER, box, big_size, 6, Color(0, 0, 0, 0.75))
		draw_string(font, Vector2(left, y), big, HORIZONTAL_ALIGNMENT_CENTER, box, big_size, Color.WHITE)
