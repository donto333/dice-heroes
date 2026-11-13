extends Control
## 턴이 바뀔 때 화면 가운데를 가로지르는 띠. "3턴 · 내 차례"처럼 누구 차례인지 알려 준다.
## play()는 띠가 들어왔다 나갈 때까지 기다린다. 화면 입력은 막지 않는다.

const SLIDE_TIME := 0.22
const HOLD_TIME := 0.55

var _band: PanelContainer
var _small: Label
var _big: Label
var _style: StyleBoxFlat


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_band = PanelContainer.new()
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.05, 0.06, 0.14, 0.92)
	_style.border_width_top = 4
	_style.border_width_bottom = 4
	_style.set_content_margin_all(14)
	_band.add_theme_stylebox_override("panel", _style)
	add_child(_band)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	_band.add_child(column)
	_small = _label(24)
	column.add_child(_small)
	_big = _label(64)
	_big.add_theme_constant_override("outline_size", 10)
	_big.add_theme_color_override("font_outline_color", Color.BLACK)
	column.add_child(_big)


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## 띠를 보여 준다. small은 위의 작은 글씨, big은 큰 글씨.
func play(small: String, big: String, color: Color) -> void:
	_small.text = small
	_small.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_big.text = big
	_big.add_theme_color_override("font_color", color)
	_style.border_color = color
	visible = true
	await get_tree().process_frame
	var width := size.x
	var band_height := _band.get_combined_minimum_size().y
	_band.size = Vector2(width, band_height)
	var y := size.y * 0.42 - band_height * 0.5
	_band.position = Vector2(-width, y)
	_band.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_band, "position:x", 0.0, SLIDE_TIME)
	tween.parallel().tween_property(_band, "modulate:a", 1.0, SLIDE_TIME)
	tween.tween_interval(HOLD_TIME)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(_band, "position:x", width, SLIDE_TIME)
	tween.parallel().tween_property(_band, "modulate:a", 0.0, SLIDE_TIME)
	await tween.finished
	visible = false
