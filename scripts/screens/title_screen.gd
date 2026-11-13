extends Control
## 타이틀 화면. 영웅 초상화가 천천히 흐르는 배경 위에 게임 이름과 "화면을 누르세요".
## 누르면 처음 온 사람은 로그인, 이미 프로필이 있으면 로비로 간다.

const Kit := preload("res://scripts/ui/kit.gd")
const GameData := preload("res://scripts/game_data.gd")

const FEATURED := ["lubu", "zeus", "sejong", "athena", "yisunsin", "wukong", "zhugeliang", "nightingale", "alexander", "dangun", "tesla", "mulan"]

var app
var _strip: Control
var _hint: Label
var _time := 0.0


func setup(main_app, _params: Dictionary) -> void:
	app = main_app
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("0a0c1c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# 초상화 두 줄이 서로 반대로 흐른다.
	_strip = Control.new()
	_strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_strip.draw.connect(_draw_strip)
	add_child(_strip)

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.1, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var column := Kit.vbox(18)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	column.add_child(Kit.spacer(0))
	var logo := Kit.title("주사위 영웅전", 96)
	logo.add_theme_constant_override("outline_size", 18)
	column.add_child(logo)
	column.add_child(Kit.label("영웅과 함께 굴리는 주사위 보드 RPG", 28, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
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
		_hint.modulate.a = 0.55 + 0.45 * sin(_time * 3.0)
	if _strip != null:
		_strip.queue_redraw()


func _draw_strip() -> void:
	var tile := 300.0
	var rows := [[0.08, 1.0], [0.42, -1.0], [0.76, 1.0]]
	for row_index in rows.size():
		var y: float = size.y * float(rows[row_index][0]) - tile * 0.5
		var direction: float = rows[row_index][1]
		var offset := fmod(_time * 30.0 * direction, tile)
		for i in range(-2, int(size.x / tile) + 3):
			var id: String = FEATURED[(i + row_index * 4 + 1200) % FEATURED.size()]
			var texture := GameData.portrait(id)
			if texture != null:
				_strip.draw_texture_rect(texture, Rect2(i * tile + offset, y, tile - 6, tile - 6), false, Color(1, 1, 1, 0.9))


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		app.play("click")
		if app.has_profile():
			app.go("lobby")
		else:
			app.go("login")
