extends Control
## 제목 리본: 양 끝이 제비 꼬리처럼 갈라진 깃발 띠 위에 금색 글자. 창 제목, 구역 제목에 쓴다.
## 단색 알약 상자 대신 써서 화면이 덜 밋밋해 보이게 한다.

const OrnateBox := preload("res://scripts/ui/ornate_box.gd")
const UiSkin := preload("res://scripts/ui/skin.gd")

var color := Color("7a2fd0")
var _label: Label


func _init(text: String = "", font_size: int = 34, band: Color = Color("7a2fd0")) -> void:
	color = band
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", Color("ffe9a0"))
	_label.add_theme_constant_override("outline_size", 8)
	_label.add_theme_color_override("font_outline_color", band.darkened(0.7))
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_bottom = -6
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	custom_minimum_size = Vector2(0, font_size + 30.0)
	resized.connect(queue_redraw)


func set_text(text: String) -> void:
	_label.text = text


func _draw() -> void:
	if size.x < 60.0:
		return
	var tone: String = {"gold": "gold", "red": "gold", "blue": "blue", "teal": "blue", "green": "blue"}.get(UiSkin.tone(color), "violet")
	var art: Texture2D = UiSkin.tex("ribbon_" + tone)
	if art != null:
		UiSkin.draw_bar(get_canvas_item(), art, Rect2(0, -8, size.x, size.y + 12), 0.9, Color.WHITE, 0.34)
		return
	var tail := minf(34.0, size.x * 0.08)
	var band_height := size.y - 8.0
	var fold := 10.0
	# 뒤로 접힌 꼬리(짙은 색): 양 끝이 V자로 파였다.
	for side in [-1.0, 1.0]:
		var edge: float = 0.0 if side < 0.0 else size.x
		var inner: float = edge - side * (tail + 14.0)
		var notch: float = edge - side * 12.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(inner, fold), Vector2(edge, fold), Vector2(notch, fold + band_height * 0.5),
			Vector2(edge, fold + band_height), Vector2(inner, fold + band_height)]), color.darkened(0.45))
		# 접힌 자리의 그늘 세모
		draw_colored_polygon(PackedVector2Array([
			Vector2(edge - side * tail, band_height), Vector2(inner, band_height), Vector2(inner, fold + band_height)]),
			color.darkened(0.7))
	# 앞 띠: 위는 밝고 아래는 짙게
	var body := PackedVector2Array([Vector2(tail, 0), Vector2(size.x - tail, 0), Vector2(size.x - tail, band_height), Vector2(tail, band_height)])
	var top := color.lightened(0.22)
	var bottom := color.darkened(0.25)
	draw_polygon(body, PackedColorArray([top, top, bottom, bottom]))
	draw_rect(Rect2(tail, 0, size.x - tail * 2.0, band_height * 0.42), Color(1, 1, 1, 0.12))
	# 금색 두 줄
	var gold := Color("ffd45a")
	draw_line(Vector2(tail, 4.0), Vector2(size.x - tail, 4.0), gold, 2.5)
	draw_line(Vector2(tail, band_height - 4.0), Vector2(size.x - tail, band_height - 4.0), gold.darkened(0.25), 2.5)
	# 양옆 금색 마름모 장식
	for side in [-1.0, 1.0]:
		var spot := Vector2(size.x * 0.5 + side * (size.x * 0.5 - tail - 18.0), band_height * 0.5)
		draw_colored_polygon(PackedVector2Array([spot + Vector2(0, -7), spot + Vector2(7, 0), spot + Vector2(0, 7), spot + Vector2(-7, 0)]), gold)
