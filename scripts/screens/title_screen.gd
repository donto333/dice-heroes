extends Control
## 타이틀 화면. 영웅 초상화가 천천히 흐르는 배경 위에 게임 이름과 "화면을 누르세요".
## 누르면 처음 온 사람은 로그인, 이미 프로필이 있으면 로비로 간다.

const Kit := preload("res://scripts/ui/kit.gd")
const GameData := preload("res://scripts/game_data.gd")

const FEATURED := ["lubu", "zeus", "sejong", "athena", "yisunsin", "wukong", "zhugeliang", "nightingale", "alexander", "dangun", "tesla", "mulan"]

var app
const PIPS := {
	5: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	6: [Vector2(0.27, 0.25), Vector2(0.73, 0.25), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.75), Vector2(0.73, 0.75)],
}
var _strip: Control
var _emblem: Control
var _hint: Label
var _time := 0.0


func setup(main_app, _params: Dictionary) -> void:
	app = main_app
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Color("0f3d85")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 배경이 터치를 가로채면 화면을 눌러도 넘어가지 않는다. 터치는 이 화면(self)이 받는다.
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# 초상화 두 줄이 서로 반대로 흐른다.
	_strip = Control.new()
	_strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_strip.draw.connect(_draw_strip)
	add_child(_strip)

	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.25, 0.6, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var column := Kit.vbox(18)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	column.add_child(Kit.spacer(0))
	_emblem = Control.new()
	_emblem.custom_minimum_size = Vector2(0, 170)
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emblem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_emblem.draw.connect(_draw_emblem)
	column.add_child(_emblem)
	# 제목 뒤의 어두운 띠: 그림 위에서도 글자가 또렷하게
	var band := PanelContainer.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band_style := Kit.box(Color(0.06, 0.3, 0.7, 0.9), Kit.GOLD, 0, 0, 18)
	band_style.border_width_top = 4
	band_style.border_width_bottom = 4
	band.add_theme_stylebox_override("panel", band_style)
	column.add_child(band)
	var band_text := Kit.vbox(6)
	band_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(band_text)
	var logo := Kit.title("주사위 영웅전", 104)
	logo.add_theme_constant_override("outline_size", 20)
	band_text.add_child(logo)
	band_text.add_child(Kit.label("영웅과 함께 굴리는 주사위 보드 RPG", 28, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(Kit.spacer(0))
	_hint = Kit.label("화면을 누르세요", 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	column.add_child(_hint)
	column.add_child(Kit.spacer(80, false))
	column.add_child(Kit.label("버전 %s" % app.VERSION, 18, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(Kit.spacer(24, false))


func _process(delta: float) -> void:
	_time += delta
	if _hint != null:
		# 처음 잠깐은 불러오는 중. 다 되면 "화면을 누르세요"가 깜빡인다.
		if _loaded():
			_hint.text = "화면을 누르세요"
			_hint.modulate.a = 0.55 + 0.45 * sin(_time * 3.0)
		else:
			_hint.text = "불러오는 중... %d%%" % int(clampf(_time / LOAD_TIME, 0.0, 1.0) * 100.0)
			_hint.modulate.a = 1.0
	if _strip != null:
		_strip.queue_redraw()
	if _emblem != null:
		_emblem.queue_redraw()


## 화면 전체를 초상화 줄로 채운다. 줄마다 반대 방향으로 천천히 흐른다.
func _draw_strip() -> void:
	var tile := 260.0
	var row_count := int(size.y / tile) + 2
	for row_index in row_count:
		var y: float = row_index * tile - 30.0
		var direction := 1.0 if row_index % 2 == 0 else -1.0
		var offset := fmod(_time * 26.0 * direction, tile)
		for i in range(-2, int(size.x / tile) + 3):
			var id: String = FEATURED[(i + row_index * 5 + 1200) % FEATURED.size()]
			var texture := GameData.portrait(id)
			if texture != null:
				var size_px := texture.get_size()
				var side: float = min(size_px.x, size_px.y)
				var src := Rect2((size_px.x - side) / 2.0, 0.0, side, side)
				_strip.draw_texture_rect_region(texture, Rect2(i * tile + offset, y, tile - 6, tile - 6), src, Color(1, 1, 1, 0.9))


## 제목 위의 큰 주사위 두 개. 살짝 기울어 통통 튄다.
func _draw_emblem() -> void:
	var center := Vector2(_emblem.size.x * 0.5, _emblem.size.y * 0.5)
	var faces := [[5, -0.22, Vector2(-70, 0)], [6, 0.18, Vector2(70, 10)]]
	for index in faces.size():
		var hop := absf(sin(_time * 2.4 + index * 1.3)) * 14.0
		_emblem.draw_set_transform(center + faces[index][2] - Vector2(0, hop), faces[index][1], Vector2.ONE)
		var body := StyleBoxFlat.new()
		body.bg_color = Color("f8f4ea")
		body.set_corner_radius_all(20)
		body.border_color = Color("8a8474")
		body.set_border_width_all(4)
		body.border_width_bottom = 12
		body.shadow_color = Color(0, 0, 0, 0.5)
		body.shadow_size = 10
		_emblem.draw_style_box(body, Rect2(-60, -60, 120, 120))
		for pip in PIPS[faces[index][0]]:
			_emblem.draw_circle(Vector2(-60, -64) + pip * 120.0, 11.0, Color("1c5cb8"))
	_emblem.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 화면 어디를 눌러도 넘어가도록, 다른 상자보다 먼저 입력을 받는다(_input).
var _leaving := false
## 게임을 켠 직후 잠깐 보여 주는 불러오기 시간(초)
const LOAD_TIME := 1.1


func _loaded() -> bool:
	return app.instant or _time >= LOAD_TIME


func _input(event: InputEvent) -> void:
	if _leaving or not is_visible_in_tree() or not _loaded():
		return
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		_leaving = true
		get_viewport().set_input_as_handled()
		app.play("click")
		if app.has_profile():
			app.go_loading("lobby", {}, "접속 중...", 0.9, true)
		else:
			app.go_loading("login", {}, "불러오는 중...", 0.6)
