extends Control
## 잠깐 떴다 사라지는 알림 띠(UI 개편 3단계). 입력은 막지 않는다. 사라지는 시간은 예전과 같다(0.15초 나타남 · 1.6초 · 0.4초 사라짐).
## 금테 남색 캡슐(assets/ui_menu/reward_capsule.png, 없으면 단색 캡슐)에 글자 20.
## 뜨는 자리(내용을 가리지 않게):
##  - 창(dialog.gd)이 떠 있으면 창 아래쪽 바깥
##  - 메뉴 틀 화면(MenuArt.frame)이면 위 줄의 빈칸(제목 명판과 재화 칸 사이, 화면 메타 "toast_spot")
##  - 그 밖(로비·대전 등)은 화면 맨 아래 가운데. 화면 메타 "toast_bottom"(아래에서 띄울 거리)으로 아래 띠 위에 올린다.

const Kit := preload("res://scripts/ui/kit.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const PillSkin := preload("res://scripts/ui/pill_skin.gd")
const Dialog := preload("res://scripts/ui/dialog.gd")

const FONT_SIZE := 20
const MIN_FONT_SIZE := 15
const HEIGHT := 46.0
const SIDE := 26.0

var _label: Label
var _back: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_text(message: String) -> void:
	modulate.a = 0.0
	_back = Control.new()
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_back)
	var art := MenuArt.tex("reward_capsule")
	if art != null:
		_back.resized.connect(_back.queue_redraw)
		_back.draw.connect(func() -> void:
			PillSkin.draw_slices(_back, art, Rect2(Vector2.ZERO, _back.size), 0.5))
	else:
		var plain := Panel.new()
		plain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		plain.add_theme_stylebox_override("panel", Kit.box(Color(0.05, 0.1, 0.32, 0.96), Kit.TRIM, 3, 23, 4))
		_back.add_child(plain)
	_label = Label.new()
	_label.text = message
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0, 0.04, 0.18, 0.95))
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = SIDE
	_label.offset_right = -SIDE
	_label.offset_top = 2
	_label.offset_bottom = -4
	add_child(_label)
	# 창은 두 프레임 뒤에 크기를 잡으므로(dialog.gd) 그다음에 자리를 정한다.
	for _frame in 3:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	_place()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


## 글 너비에 맞춰 캡슐 크기와 자리를 정한다. 칸보다 길면 글자를 줄이고, 그래도 길면 두 줄로 감는다.
func _place() -> void:
	var app := get_parent() as Control
	if app == null:
		return
	var area: Vector2 = app.size
	var room := minf(area.x * 0.62, 720.0)
	var center := Vector2(area.x * 0.5, 0.0)
	var max_height := 96.0
	var spot := _top_spot(app)
	var window := _open_window(app)
	if window != null:
		var bottom: Vector2 = Kit.spot_in(app, window, Vector2(window.size.x * 0.5, window.size.y))
		center = Vector2(bottom.x, bottom.y + 30.0)
	elif spot != null:
		var left: Vector2 = Kit.spot_in(app, spot, Vector2.ZERO)
		var right: Vector2 = Kit.spot_in(app, spot, spot.size)
		room = maxf(right.x - left.x - 8.0, 200.0)
		center = (left + right) * 0.5
		max_height = maxf(right.y - left.y, HEIGHT)
	else:
		var gap := 24.0
		var screen = app.get("current_screen")
		if is_instance_valid(screen) and screen is Control and screen.has_meta("toast_bottom"):
			gap = float(screen.get_meta("toast_bottom"))
		center = Vector2(area.x * 0.5, area.y - gap)
	# 한 줄로 들어가는 가장 큰 글자를 찾는다.
	var font := _label.get_theme_font("font")
	var shown := tr(_label.text)
	var font_size := FONT_SIZE
	var width := font.get_multiline_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	while width + SIDE * 2.0 > room and font_size > MIN_FONT_SIZE:
		font_size -= 1
		width = font.get_multiline_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_label.add_theme_font_size_override("font_size", font_size)
	var box := Vector2(minf(width + SIDE * 2.0 + 6.0, room), HEIGHT)
	var lines := shown.count("\n") + 1
	if width + SIDE * 2.0 > room:
		# 그래도 길면 두 줄로 감는다.
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lines = maxi(lines, 2)
	if lines > 1:
		box.y = minf(HEIGHT + float(lines - 1) * (font_size + 6.0), max_height)
	size = box
	if window != null:
		position = Vector2(center.x - box.x * 0.5, minf(center.y, area.y - box.y - 6.0))
	elif spot != null:
		position = center - box * 0.5
	else:
		position = Vector2(center.x - box.x * 0.5, center.y - box.y)
	position.x = clampf(position.x, 6.0, maxf(area.x - box.x - 6.0, 6.0))


## 메뉴 틀 화면의 위 줄 빈칸. 없으면 null.
func _top_spot(app: Control) -> Control:
	var screen = app.get("current_screen")
	if not is_instance_valid(screen) or not (screen is Control) or not screen.has_meta("toast_spot"):
		return null
	var spot = screen.get_meta("toast_spot")
	if is_instance_valid(spot) and spot is Control and spot.is_inside_tree() and spot.size.x > 120.0:
		return spot
	return null


## 지금 떠 있는(닫히는 중이 아닌) 맨 위 창의 몸통 판. 없으면 null.
func _open_window(app: Control) -> Control:
	var found: Control = null
	for child in app.get_children():
		if child.get_script() == Dialog and not child.is_queued_for_deletion() and child.visible:
			var panel = child.get("_panel")
			if is_instance_valid(panel) and panel is Control:
				found = panel
	return found
