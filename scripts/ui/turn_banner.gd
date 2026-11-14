extends Control
## 턴이 바뀔 때 화면 가운데에 튀어나오는 글자. "내 차례! START!"처럼 누구 차례인지 알려 준다.
## play()는 글자가 나왔다 사라질 때까지 기다린다. 화면 입력은 막지 않는다.

const POP_TIME := 0.22
const HOLD_TIME := 0.5
const OUT_TIME := 0.16

var _box: VBoxContainer
var _small: Label
var _big: Label
var _start: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", -14)
	_box.anchor_left = 0.0
	_box.anchor_right = 1.0
	_box.anchor_top = 0.36
	_box.anchor_bottom = 0.36
	add_child(_box)
	_small = _label(26, 8)
	_box.add_child(_small)
	_big = _label(84, 20)
	_box.add_child(_big)
	_start = _label(64, 18)
	_start.text = "START!"
	_box.add_child(_start)


func _label(font_size: int, outline: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", Color("2a1200"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## 글자를 보여 준다. small은 위의 작은 글씨("3 / 50턴"), big은 큰 글씨("내 차례!").
func play(small: String, big: String, color: Color) -> void:
	_small.text = small
	_small.add_theme_color_override("font_color", Color.WHITE)
	_big.text = big + "!"
	_big.add_theme_color_override("font_color", color.lightened(0.25))
	_start.add_theme_color_override("font_color", Color("ffcf4d"))
	visible = true
	modulate.a = 0.0
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_box.pivot_offset = Vector2(size.x * 0.5, _box.size.y * 0.5)
	_box.rotation = -0.06
	_box.scale = Vector2(0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(_box, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 1.0, POP_TIME * 0.6)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(_box, "scale", Vector2(1.5, 1.5), OUT_TIME).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, OUT_TIME)
	await tween.finished
	visible = false
