extends Control
## 어빌리티 컷인: 영웅 그림과 기술 이름이 띠와 함께 화면을 가로질러 나왔다 사라진다.
## play()는 끝날 때까지 기다린다. 화면 입력은 막지 않는다.

const Portrait := preload("res://scripts/ui/portrait.gd")

const IN_TIME := 0.2
const HOLD_TIME := 0.75
const OUT_TIME := 0.18

var _band: Panel
var _style: StyleBoxFlat
var _face: Control
var _title: Label
var _note: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_band = Panel.new()
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.04, 0.16, 0.42, 0.96)
	_style.border_width_top = 8
	_style.border_width_bottom = 8
	_style.shadow_color = Color(0, 0, 0, 0.5)
	_style.shadow_size = 14
	_band.add_theme_stylebox_override("panel", _style)
	# 화면보다 넓은 띠를 살짝 기울여 가로지르게 한다.
	_band.anchor_left = -0.08
	_band.anchor_right = 1.08
	_band.rotation = deg_to_rad(-4.0)
	_band.anchor_top = 0.34
	_band.anchor_bottom = 0.34
	_band.offset_bottom = 210
	add_child(_band)
	_face = Portrait.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.border_width = 5.0
	_face.hd = true
	_face.position = Vector2(60, -44)
	_face.size = Vector2(260, 298)
	_band.add_child(_face)
	_title = _label(56, 14)
	_title.position = Vector2(340, 34)
	_band.add_child(_title)
	_note = _label(22, 6)
	_note.position = Vector2(342, 116)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(410, 0)
	_note.size = Vector2(410, 80)
	_band.add_child(_note)


func _label(font_size: int, outline: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## character: 기술을 쓰는 영웅, title: 기술 이름, note: 설명 한 줄, color: 쓰는 쪽 색
func play(character: Dictionary, title: String, note: String, color: Color) -> void:
	_style.border_color = color
	_face.border = color
	_face.show_character(character, color.darkened(0.5))
	_title.text = title
	_title.add_theme_color_override("font_color", Color("ffcf4d"))
	_note.text = note
	modulate.a = 0.0
	visible = true
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var rest := _band.position.x
	_band.position.x = rest - size.x * 0.6
	var tween := create_tween()
	tween.tween_property(_band, "position:x", rest, IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 1.0, IN_TIME * 0.7)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(_band, "position:x", rest + size.x * 0.4, OUT_TIME).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, OUT_TIME)
	await tween.finished
	_band.position.x = rest
	visible = false
