extends Control
## 한 판이 끝났을 때 보여 주는 결과 화면.
## 승패, 걸린 턴, 전투 기록, 두 파티를 보여 주고 "다시 하기"와 "파티 바꾸기"를 고르게 한다.

signal retry_pressed
## 왼쪽 버튼(로비로)
signal change_party_pressed

const Kit := preload("res://scripts/ui/kit.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const Confetti := preload("res://scripts/ui/confetti.gd")
const ArtView := preload("res://scripts/ui/art_view.gd")

const GOLD := Color("ffcf4d")
const WIN_COLOR := Color("7ee081")
const LOSE_COLOR := Color("ff6b6b")

var _title: Label
var _subtitle: Label
var _details: Label
var _panel: PanelContainer
var _confetti: Control
var _again: Button
var _mvp_row: HBoxContainer
var _mvp_face: Control
var _mvp_name: Label
var _mvp_note: Label
var _chips: HFlowContainer
## 승리·패배 그림(assets/art/ui/victory.jpg, defeat.jpg)
var _banner: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.1, 0.28, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_confetti = Confetti.new()
	add_child(_confetti)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(820, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("1f66c8")
	box.border_color = Color.WHITE
	box.set_border_width_all(5)
	box.shadow_color = Color(0, 0.05, 0.2, 0.5)
	box.shadow_size = 12
	box.set_corner_radius_all(30)
	box.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", box)
	center.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_panel.add_child(column)

	_banner = ArtView.new()
	_banner.custom_minimum_size = Vector2(0, 110)
	_banner.focus_y = 0.45
	_banner.fade_bottom = 0.35
	_banner.visible = false
	column.add_child(_banner)
	_title = _label(60)
	_title.add_theme_constant_override("outline_size", 12)
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	column.add_child(_title)
	_subtitle = _label(26)
	column.add_child(_subtitle)

	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.15)
	line.custom_minimum_size = Vector2(0, 2)
	column.add_child(line)

	# MVP 영웅: 큰 초상화와 이름
	_mvp_row = HBoxContainer.new()
	_mvp_row.add_theme_constant_override("separation", 16)
	_mvp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_mvp_row)
	_mvp_face = Portrait.new()
	_mvp_face.custom_minimum_size = Vector2(104, 104)
	_mvp_face.border = GOLD
	_mvp_face.border_width = 4.0
	_mvp_row.add_child(_mvp_face)
	var mvp_text := VBoxContainer.new()
	mvp_text.alignment = BoxContainer.ALIGNMENT_CENTER
	mvp_text.add_theme_constant_override("separation", 2)
	_mvp_row.add_child(mvp_text)
	var ribbon := Kit.label(" MVP ", 26, Color("3a2408"))
	ribbon.add_theme_stylebox_override("normal", Kit.box(GOLD, Color("7a4a12"), 3, 10, 6))
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mvp_text.add_child(ribbon)
	_mvp_name = Kit.label("", 34)
	mvp_text.add_child(_mvp_name)
	_mvp_note = Kit.label("", 20, Color(1, 1, 1, 0.8))
	mvp_text.add_child(_mvp_note)

	# 받은 보상 칩
	_chips = HFlowContainer.new()
	_chips.alignment = FlowContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override("h_separation", 10)
	_chips.add_theme_constant_override("v_separation", 8)
	column.add_child(_chips)

	_details = _label(20)
	_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_details.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_details.add_theme_constant_override("line_spacing", 6)
	column.add_child(_details)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var change := Kit.button("로비로", Color("6f9bd6"), 28, 92)
	change.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	change.pressed.connect(_on_change_pressed)
	buttons.add_child(change)
	var again := Kit.button("다시 하기", Color("e8890c"), 30, 92)
	_again = again
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	button.custom_minimum_size = Vector2(0, 70)
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
## extras: {"mvp": 캐릭터, "mvp_note": "ATTACK · 전투 3승", "chips": [["● 150", 색], ...]} (없어도 됨)
func show_result(outcome: String, subtitle: String, details: PackedStringArray, extras: Dictionary = {}) -> void:
	_again.text = str(extras.get("again_text", "다시 하기"))
	var mvp: Dictionary = extras.get("mvp", {})
	_mvp_row.visible = not mvp.is_empty()
	if not mvp.is_empty():
		_mvp_face.show_character(mvp, Color("8fd0ff"))
		_mvp_name.text = str(mvp.get("name", ""))
		_mvp_note.text = str(extras.get("mvp_note", ""))
	for child in _chips.get_children():
		child.queue_free()
	for chip in extras.get("chips", []):
		var color: Color = chip[1]
		var label := Kit.label(" %s " % chip[0], 24, Color.WHITE)
		label.add_theme_constant_override("outline_size", 5)
		label.add_theme_color_override("font_outline_color", color.darkened(0.7))
		label.add_theme_stylebox_override("normal", Kit.box(color.darkened(0.45), color, 3, 22, 8))
		_chips.add_child(label)
	_chips.visible = not extras.get("chips", []).is_empty()
	if outcome == "win":
		_confetti.start()
	else:
		_confetti.stop()
	_banner.show_art("ui/defeat" if outcome == "lose" else "ui/victory")
	_banner.visible = _banner.has_art()
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
	_confetti.stop()
	visible = false
	change_party_pressed.emit()


func _on_again_pressed() -> void:
	_confetti.stop()
	visible = false
	retry_pressed.emit()
