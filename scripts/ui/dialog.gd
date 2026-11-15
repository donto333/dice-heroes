extends Control
## 화면 가운데 뜨는 창. 뒤를 어둡게 덮고, 제목·내용·버튼을 보여 준다.
## 쓰는 법: var d := Dialog.new(); parent.add_child(d); d.open("제목", 내용_컨트롤, [["확인", 색, 콜백], ...])
## 버튼을 누르면 콜백을 부르고 창이 닫힌다. 콜백이 없으면 그냥 닫힌다.

const Kit := preload("res://scripts/ui/kit.gd")

signal closed

var _column: VBoxContainer
var _panel: PanelContainer


## 내용이 이보다 길면 창 안에서 끌어 내릴 수 있게 한다.
const BODY_MAX_HEIGHT := 860.0


func _ready() -> void:
	add_to_group("modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(title_text: String, body: Control, buttons: Array, width: float = 640.0) -> void:
	for child in get_children():
		child.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.1, 0.28, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(width, 0)
	var frame := Kit.box(Color("1f66c8"), Color.WHITE, 5, 32, 22)
	frame.border_width_bottom = 9
	frame.anti_aliasing_size = 1.2
	frame.shadow_color = Color(0, 0.05, 0.2, 0.55)
	frame.shadow_size = 14
	frame.shadow_offset = Vector2(0, 7)
	_panel.add_theme_stylebox_override("panel", frame)
	Kit.sheen(_panel, 26, 0.08)
	center.add_child(_panel)
	_column = Kit.vbox(16)
	_panel.add_child(_column)
	if title_text != "":
		# 제목 띠: 짙은 남색 알약 위에 금색 글자
		var ribbon := PanelContainer.new()
		var band := Kit.box(Color("0c2f6e"), Color("ffd45a"), 3, 26, 8)
		band.border_width_bottom = 5
		ribbon.add_theme_stylebox_override("panel", band)
		ribbon.add_child(Kit.title(title_text, 36))
		_column.add_child(ribbon)
	if body != null:
		if body.get_combined_minimum_size().y > BODY_MAX_HEIGHT:
			# 긴 내용: 창 안에서 끌어 내린다.
			var scroll := ScrollContainer.new()
			scroll.custom_minimum_size = Vector2(0, BODY_MAX_HEIGHT)
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(body)
			_column.add_child(scroll)
		else:
			_column.add_child(body)
	if not buttons.is_empty():
		var row := Kit.hbox(10)
		_column.add_child(row)
		for spec in buttons:
			var button := Kit.button(str(spec[0]), spec[1] if spec.size() > 1 else Kit.ACCENT, 26, 84)
			Kit.expand(button)
			var callback: Callable = spec[2] if spec.size() > 2 else Callable()
			button.pressed.connect(_on_button.bind(callback))
			row.add_child(button)
	_panel.pivot_offset = Vector2(width * 0.5, 120)
	_panel.scale = Vector2(0.85, 0.85)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.22)


func _on_button(callback: Callable) -> void:
	close()
	if callback.is_valid():
		callback.call()


func close() -> void:
	closed.emit()
	queue_free()
