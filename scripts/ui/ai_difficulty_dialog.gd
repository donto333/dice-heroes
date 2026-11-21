extends Control
## 별의 관측소 AI 난이도 창. 시안의 좌표를 기준으로 개별 그림과 실제 데이터를 겹친다.

const Kit := preload("res://scripts/ui/kit.gd")
const ART := "res://assets/ui_observatory/ai_difficulty/"
const ROBOT := preload("res://assets/ui_lobby/ic_ai.png")
const FRAME_SIZE := Vector2(916, 680)
const ACCENTS := [Color("193d31"), Color("192e58"), Color("572a20")]

signal closed

var _frame: Control


func _ready() -> void:
	add_to_group("modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_fit)


func open(entries: Array, on_start: Callable) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.035, 0.026, 0.09, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_frame = Control.new()
	_frame.name = "DifficultyFrame"
	_frame.size = FRAME_SIZE
	add_child(_frame)
	_art(_frame, "frame", Rect2(Vector2.ZERO, FRAME_SIZE))
	_art(_frame, "title", Rect2(193, 23, 528, 81))
	_label(_frame, "AI 연습전 난이도", Rect2(266, 34, 382, 54), 40)
	_label(_frame, "어려울수록 상대 영웅 레벨이 높고 조합을 잘 짜요. 보상도 많아져요.",
		Rect2(45, 117, 826, 49), 28)

	for index in entries.size():
		_add_card(entries[index], index, on_start)
	var dismiss := _button(_frame, "close", "닫기", Rect2(72, 555, 771, 90), 40)
	dismiss.pressed.connect(close)
	var shortcut := _button(_frame, "cross", "", Rect2(823, 36, 56, 56), 0)
	shortcut.tooltip_text = "닫기"
	shortcut.pressed.connect(close)
	_fit()


func _add_card(entry: Dictionary, index: int, on_start: Callable) -> void:
	var tone: String = ["easy", "normal", "hard"][index]
	var card := Control.new()
	card.position = Vector2(51 + 279 * index, 183)
	card.size = Vector2(255, 345)
	_frame.add_child(card)
	_art(card, tone + "_card", Rect2(Vector2.ZERO, card.size))
	_label(card, str(entry["name"]), Rect2(22, 18, 211, 51), 38, Color.WHITE, ACCENTS[index])
	_art(card, "robot", Rect2(86, 80, 83, 73))
	_label(card, "상대 레벨 %d" % int(entry["level"]), Rect2(9, 157, 237, 44), 29)
	_label(card, "보상 ×%s" % str(entry["reward_scale"]),
		Rect2(9, 201, 237, 45), 30, Color("ffd34f"), Color("3a2400"))
	var start := _button(card, tone + "_start", "시작", Rect2(23, 254, 210, 65), 31)
	start.pressed.connect(func() -> void:
		close()
		on_start.call(str(entry["id"])))


func _fit() -> void:
	if _frame == null:
		return
	var factor := minf(size.x / 1672.0, size.y / 940.0)
	_frame.scale = Vector2.ONE * factor
	_frame.position = (size - FRAME_SIZE * factor) * 0.5


func _art(parent: Control, piece: String, bounds: Rect2) -> void:
	var texture := TextureRect.new()
	texture.name = piece
	texture.texture = ROBOT if piece == "robot" else load(ART + piece + ".webp") as Texture2D
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.position = bounds.position
	texture.size = bounds.size
	parent.add_child(texture)


func _label(parent: Control, value: String, bounds: Rect2, font_size: int,
		color: Color = Color.WHITE, outline: Color = Color("14162f")) -> void:
	var label := Kit.label(value, font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", 5)
	label.position = bounds.position
	label.size = bounds.size
	parent.add_child(label)
	Kit.squeeze_text(label, font_size, roundi(font_size * 0.67))


func _button(parent: Control, piece: String, caption: String, bounds: Rect2, font_size: int) -> Button:
	var button := Button.new()
	button.position = bounds.position
	button.size = bounds.size
	button.accessibility_name = caption if caption != "" else "닫기"
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	parent.add_child(button)
	_art(button, piece, Rect2(Vector2.ZERO, bounds.size))
	if caption != "":
		_label(button, caption, Rect2(Vector2.ZERO, bounds.size), font_size)
	return button


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()
