extends Control
## 버튼의 입체 광택 몸통. 버튼의 맨 뒤에 붙어서(show_behind_parent) 글자·그림 아래에 그려진다.
## 짙은 테두리 → 두께(아래로 보이는 테두리) → 몸통 → 위쪽 밝은 면 → 흰 광택 띠 순서로 쌓아 사탕 같은 느낌을 낸다.
## 누르면 몸통이 아래로 내려가고, 꺼지면 회색이 된다. 색은 Kit.paint()가 정한다.

const DISABLED := Color("7d8fa9")
const UiSkin := preload("res://scripts/ui/skin.gd")

var color := Color("2fb457")
var edge := Color("0e4a22")
## 모서리 둥글기. 0이면 높이에 맞춰 정한다.
var radius := 0.0
## 아래로 보이는 두께
var depth := 7.0
## 광택 띠를 그릴지(아주 작은 버튼은 끈다)
var shine := true
## 꺼져 있어도 회색으로 바꾸지 않고 제 색을 어둡게만 한다(스킬 버튼처럼 늘 색이 보여야 할 때).
var keep_color := false
## 켜져 있을 때 금색 테가 숨 쉬듯 빛난다("지금 쓸 수 있어요").
var alert := false
var _button: BaseButton
var _time := 0.0


func _init() -> void:
	name = "Gloss"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _ready() -> void:
	_button = get_parent() as BaseButton
	if _button != null:
		# 버튼 상태(누름·올림·꺼짐)가 바뀌면 버튼이 다시 그려지므로 그때 함께 다시 그린다.
		_button.draw.connect(queue_redraw)
		_button.button_down.connect(_on_down)
		_button.button_up.connect(_on_up)


func _process(delta: float) -> void:
	if alert and _button != null and not _button.disabled:
		_time += delta
		queue_redraw()


func paint(fill: Color, rim: Color) -> void:
	color = fill
	edge = rim
	queue_redraw()


## 누르는 순간 살짝 줄었다가 통 튀어 돌아온다.
func _on_down() -> void:
	if _button == null or _button.disabled:
		return
	_button.pivot_offset = _button.size * 0.5
	var tween := _button.create_tween()
	tween.tween_property(_button, "scale", Vector2(0.95, 0.95), 0.05)


func _on_up() -> void:
	if _button == null:
		return
	_button.pivot_offset = _button.size * 0.5
	var tween := _button.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_button, "scale", Vector2.ONE, 0.18)


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var off := false
	var down := false
	var over := false
	if _button != null:
		var mode := _button.get_draw_mode()
		off = _button.disabled
		down = not off and (mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED)
		over = mode == BaseButton.DRAW_HOVER
	var fill := DISABLED if off else color
	var rim := DISABLED.darkened(0.45) if off else edge
	if off and keep_color:
		fill = color.darkened(0.42)
		rim = edge
	if over:
		fill = fill.lightened(0.08)
	var r := radius if radius > 0.0 else minf(22.0, size.y * 0.5)
	if _draw_skin(off, down, over, r):
		return
	var thick := 2.0 if down else (4.0 if off else depth)
	var sink := depth - thick if not off else 0.0

	# 1) 그림자와 짙은 테두리(두께 포함)
	var base := StyleBoxFlat.new()
	base.bg_color = rim
	base.set_corner_radius_all(int(r))
	base.corner_detail = 16 if r > 30.0 else 8
	base.anti_aliasing_size = 1.2
	if not off:
		base.shadow_color = Color(0, 0.04, 0.16, 0.38)
		base.shadow_size = 5
		base.shadow_offset = Vector2(0, 3)
	draw_style_box(base, Rect2(0, sink, size.x, size.y - sink))

	# 2) 몸통
	var body := Rect2(3, 3 + sink, size.x - 6, size.y - 6 - thick - sink)
	if body.size.y < 6.0:
		return
	var inner := maxf(r - 3.0, 2.0)
	var face := StyleBoxFlat.new()
	face.bg_color = fill.darkened(0.1)
	face.set_corner_radius_all(int(inner))
	face.anti_aliasing_size = 1.2
	draw_style_box(face, body)

	if r >= minf(size.x, size.y) * 0.45:
		# 동그란 버튼: 두 면으로 나누지 않고 밝은 몸통 위에 타원 광택만 얹는다.
		face.bg_color = fill
		face.corner_detail = 16
		draw_style_box(face, body)
		if shine and not off:
			var oval := StyleBoxFlat.new()
			oval.bg_color = Color(1, 1, 1, 0.32)
			oval.set_corner_radius_all(int(body.size.y * 0.2))
			oval.corner_detail = 12
			oval.anti_aliasing_size = 1.2
			draw_style_box(oval, Rect2(body.position.x + body.size.x * 0.2, body.position.y + body.size.y * 0.07, body.size.x * 0.6, body.size.y * 0.3))
		return

	# 3) 위쪽 밝은 면: 아래 18%만 짙은 색이 남아 볼록해 보인다.
	var light := StyleBoxFlat.new()
	light.bg_color = fill
	light.set_corner_radius_all(int(inner))
	light.anti_aliasing_size = 1.2
	draw_style_box(light, Rect2(body.position, Vector2(body.size.x, body.size.y * 0.82)))
	var top := StyleBoxFlat.new()
	top.bg_color = fill.lightened(0.16)
	top.set_corner_radius_all(int(inner))
	top.anti_aliasing_size = 1.2
	draw_style_box(top, Rect2(body.position, Vector2(body.size.x, body.size.y * 0.5)))

	# 4) 흰 광택 띠
	if shine and not off and body.size.y >= 34.0:
		var band_height := clampf(body.size.y * 0.24, 8.0, 18.0)
		var pad := minf(inner * 0.55, 12.0)
		var gleam := StyleBoxFlat.new()
		gleam.bg_color = Color(1, 1, 1, 0.3)
		gleam.set_corner_radius_all(int(band_height * 0.5))
		gleam.anti_aliasing_size = 1.2
		draw_style_box(gleam, Rect2(body.position.x + pad, body.position.y + 4.0, body.size.x - pad * 2.0, band_height))

	# 5) 몸통 안쪽의 얇은 밝은 선
	var line := StyleBoxFlat.new()
	line.draw_center = false
	line.border_color = Color(1, 1, 1, 0.22)
	line.set_border_width_all(2)
	line.set_corner_radius_all(int(inner))
	line.anti_aliasing_size = 1.2
	draw_style_box(line, body)

	# 6) 쓸 수 있을 때 숨 쉬는 금색 테
	if alert and not off:
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		var halo := StyleBoxFlat.new()
		halo.draw_center = false
		halo.border_color = Color(1.0, 0.86, 0.3, 0.55 + pulse * 0.45)
		halo.set_border_width_all(int(4.0 + pulse * 2.0))
		halo.set_corner_radius_all(int(r + 4.0))
		halo.anti_aliasing_size = 1.2
		draw_style_box(halo, Rect2(-3, sink - 3, size.x + 6, size.y - sink + 6))


## 그림 버튼(assets/ui_kit)으로 그린다. 그림이 없으면 false(예전 도형 그리기로).
## 길쭉하면 btn_색, 정사각형에 가까우면 sq_색, 동그란 버튼이면 round_색 그림을 쓴다.
func _draw_skin(off: bool, down: bool, over: bool, r: float) -> bool:
	var tone := "gray" if (off and not keep_color) else UiSkin.tone(color)
	var aspect := size.x / maxf(size.y, 1.0)
	var family := "btn"
	if r >= minf(size.x, size.y) * 0.45 and aspect < 1.35:
		family = "round"
	elif aspect < 2.7:
		# 짧은 버튼은 양 끝 장식이 글자를 가리므로 장식 없는 네모 그림을 쓴다.
		family = "sq"
	var texture: Texture2D = UiSkin.tex("%s_%s" % [family, tone])
	if texture == null and family == "round":
		texture = UiSkin.tex("round_blue")
	if texture == null and family == "sq":
		texture = UiSkin.tex("sq_blue")
	if texture == null and family == "btn":
		texture = UiSkin.tex("btn_blue")
	if texture == null:
		# 맞는 모양의 그림이 없으면 예전 도형 버튼으로 그린다(긴 버튼 그림을 억지로 구기지 않는다).
		return false
	# 가장 중요한 큰 금색 버튼(게임 시작 등)은 날개 장식이 달린 특별한 그림을 쓴다.
	var fancy := family == "btn" and tone == "gold" and size.y >= 92.0 and aspect >= 2.2 and UiSkin.has("btn_start")
	if fancy:
		texture = UiSkin.tex("btn_start")
	var tint := Color.WHITE
	if off and keep_color:
		tint = Color(0.55, 0.55, 0.6)
	elif off:
		tint = Color(0.86, 0.86, 0.9, 0.92)
	elif down:
		tint = Color(0.82, 0.82, 0.86)
	elif over:
		tint = Color(1.1, 1.1, 1.1)
	var sink := 2.0 if down else 0.0
	var dest := Rect2(-2.0, -2.0 + sink, size.x + 4.0, size.y + 4.0)
	var item := get_canvas_item()
	if family == "btn":
		UiSkin.draw_bar(item, texture, dest.grow(3.0) if fancy else dest, 0.82, tint, 0.2 if fancy else 0.0)
	else:
		# 네모·동그라미: 귀퉁이는 그대로 두고 가운데만 늘린다(가로세로 비율이 달라도 테가 찌그러지지 않게).
		var width := float(texture.get_width())
		var height := float(texture.get_height())
		var cut := minf(width, height) * 0.36
		var ratio := minf(dest.size.x / width, dest.size.y / height)
		UiSkin.draw_grid(item, texture, dest, [0.0, cut, width - cut, width], [false, true, false],
			[0.0, cut, height - cut, height], [false, true, false], ratio, tint)
	if alert and not off:
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		var halo := StyleBoxFlat.new()
		halo.draw_center = false
		halo.border_color = Color(1.0, 0.92, 0.45, 0.5 + pulse * 0.5)
		halo.set_border_width_all(int(4.0 + pulse * 2.0))
		halo.set_corner_radius_all(int(minf(size.y * 0.5, r + 8.0)))
		halo.anti_aliasing_size = 1.2
		draw_style_box(halo, Rect2(-5, sink - 5, size.x + 10, size.y + 10))
	return true
