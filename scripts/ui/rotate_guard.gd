extends Control
## 세로로 들면 화면을 덮고 "가로로 돌려 주세요"를 보여 준다. 이 게임은 가로 화면 전용이다.
## 화면 너비가 높이보다 좁을 때만 보이고, 가로로 돌리면 바로 사라진다.

var _time := 0.0
var _label: Label


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_label = Label.new()
	_label.text = "기기를 가로로 돌려 주세요"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 64)
	_label.add_theme_color_override("font_color", Color("ffe37a"))
	_label.add_theme_constant_override("outline_size", 12)
	_label.add_theme_color_override("font_outline_color", Color("2a0f5a"))
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	_label.anchor_top = 0.62
	_label.anchor_bottom = 0.62
	_label.offset_bottom = 90
	add_child(_label)


func _process(delta: float) -> void:
	var view := get_viewport_rect().size
	var upright := view.x < view.y * 0.95
	if upright != visible:
		visible = upright
	if visible:
		_time += delta
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.04, 0.2))
	# 휴대폰 그림이 세로에서 가로로 돌아가는 것을 되풀이한다.
	var center := size * Vector2(0.5, 0.4)
	var long := minf(size.x, size.y) * 0.34
	var phase := fposmod(_time, 2.4) / 2.4
	var turn := -PI * 0.5 * smoothstep(0.15, 0.6, phase)
	draw_set_transform(center, turn, Vector2.ONE)
	var body := StyleBoxFlat.new()
	body.bg_color = Color("f2c14e")
	body.set_corner_radius_all(int(long * 0.12))
	draw_style_box(body, Rect2(-long * 0.3, -long * 0.5, long * 0.6, long))
	var glass := StyleBoxFlat.new()
	glass.bg_color = Color("243a9c")
	glass.set_corner_radius_all(int(long * 0.06))
	draw_style_box(glass, Rect2(-long * 0.25, -long * 0.42, long * 0.5, long * 0.84))
	draw_circle(Vector2(0, long * 0.46), long * 0.02, Color("243a9c"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
