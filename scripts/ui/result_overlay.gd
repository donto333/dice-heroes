extends Control
## 한 판이 끝났을 때 보여 주는 결과 화면.
## 승패, 걸린 턴, 전투 기록, 두 파티를 보여 주고 "다시 하기"와 "파티 바꾸기"를 고르게 한다.

signal retry_pressed
## 왼쪽 버튼(로비로)
signal change_party_pressed

const GOLD := Color("ffcf4d")
const WIN_COLOR := Color("7ee081")
const LOSE_COLOR := Color("ff6b6b")

var _title: Label
var _subtitle: Label
var _details: Label
var _panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(620, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("161a36")
	box.border_color = GOLD.darkened(0.2)
	box.set_border_width_all(4)
	box.set_corner_radius_all(16)
	box.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", box)
	center.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_panel.add_child(column)

	_title = _label(84)
	_title.add_theme_constant_override("outline_size", 12)
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	column.add_child(_title)
	_subtitle = _label(26)
	column.add_child(_subtitle)

	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.15)
	line.custom_minimum_size = Vector2(0, 2)
	column.add_child(line)

	_details = _label(22)
	_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_details.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_details.add_theme_constant_override("line_spacing", 6)
	column.add_child(_details)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var change := _button("로비로", Color("3a4466"))
	change.pressed.connect(_on_change_pressed)
	buttons.add_child(change)
	var again := _button("다시 하기", Color("2f80ed"))
	again.size_flags_stretch_ratio = 1.5
	again.pressed.connect(_on_again_pressed)
	buttons.add_child(again)


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 90)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color if state == "normal" else (color.lightened(0.15) if state == "hover" else color.darkened(0.2))
		box.border_color = color.lightened(0.35)
		box.set_border_width_all(2)
		box.set_corner_radius_all(10)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


## 결과를 보여 준다. outcome은 "win", "lose", "draw".
## details는 아래에 줄마다 보여 줄 글이다.
func show_result(outcome: String, subtitle: String, details: PackedStringArray) -> void:
	match outcome:
		"win":
			_title.text = "승리!"
			_title.add_theme_color_override("font_color", WIN_COLOR)
		"lose":
			_title.text = "패배"
			_title.add_theme_color_override("font_color", LOSE_COLOR)
		_:
			_title.text = "무승부"
			_title.add_theme_color_override("font_color", GOLD)
	_subtitle.text = subtitle
	_details.text = "\n".join(details)
	visible = true
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.8, 0.8)
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.35)
	tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.25)


func _on_change_pressed() -> void:
	visible = false
	change_party_pressed.emit()


func _on_again_pressed() -> void:
	visible = false
	retry_pressed.emit()
