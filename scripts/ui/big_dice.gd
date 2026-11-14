extends Control
## 판 가운데에 크게 뜨는 주사위 연출(모두의 마블처럼 큰 주사위가 통통 튀다 멈춘다).
## 보여 주기만 한다. 실제 눈은 규칙 코드(scripts/rules/game.gd)가 이미 정한 값을 받는다.
## play()는 연출이 끝날 때까지 기다린다. 화면 입력은 막지 않는다.

const DiceView := preload("res://scripts/ui/dice_view.gd")

const ROLL_TIME := 0.7
const HOLD_TIME := 0.55
const FADE_TIME := 0.2

var _panel: PanelContainer
var _style: StyleBoxFlat
var _dice: Control
var _caption: Label
var _total: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.04, 0.05, 0.12, 0.88)
	_style.set_border_width_all(4)
	_style.set_corner_radius_all(26)
	_style.set_content_margin_all(22)
	_style.shadow_color = Color(0, 0, 0, 0.5)
	_style.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", _style)
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	_caption = _label(24)
	column.add_child(_caption)
	_dice = DiceView.new()
	_dice.die_size = 104.0
	_dice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dice.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_dice)
	_total = _label(54)
	_total.add_theme_constant_override("outline_size", 10)
	_total.add_theme_color_override("font_outline_color", Color.BLACK)
	column.add_child(_total)


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## caption: 위의 작은 글씨("내 이동"), rolls: 주사위 눈들, result: 멈춘 뒤 큰 글씨("6칸!").
func play(caption: String, rolls: Array, result: String, color: Color) -> void:
	if rolls.is_empty():
		return
	_caption.text = caption
	_caption.add_theme_color_override("font_color", color)
	_total.text = " "
	_total.add_theme_color_override("font_color", Color("ffcf4d"))
	_style.border_color = color
	_dice.values = rolls
	modulate.a = 1.0
	visible = true
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.5, 0.5)
	var pop := create_tween()
	pop.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _dice.roll_to(rolls, ROLL_TIME)
	if not is_inside_tree():
		return
	_total.text = result
	var bump := create_tween()
	bump.tween_property(_panel, "scale", Vector2(1.12, 1.12), 0.09)
	bump.tween_property(_panel, "scale", Vector2.ONE, 0.12)
	await get_tree().create_timer(HOLD_TIME).timeout
	if not is_inside_tree():
		return
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	await fade.finished
	visible = false
