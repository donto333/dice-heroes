extends Control
## 화면 가운데 뜨는 창. 뒤를 어둡게 덮고, 제목·내용·버튼을 보여 준다.
## 쓰는 법: var d := Dialog.new(); parent.add_child(d); d.open("제목", 내용_컨트롤, [["확인", 색, 콜백], ...])
## 버튼을 누르면 콜백을 부르고 창이 닫힌다. 콜백이 없으면 그냥 닫힌다.

const Kit := preload("res://scripts/ui/kit.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")

signal closed

var _column: VBoxContainer
var _panel: PanelContainer


## 내용이 이보다 길면 창 안에서 끌어 내릴 수 있게 한다.
const BODY_MAX_HEIGHT := 400.0


func _ready() -> void:
	add_to_group("modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(title_text: String, body: Control, buttons: Array, width: float = 640.0) -> void:
	for child in get_children():
		child.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.16, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(width, 0)
	# 장식 창: 깊은 남보라 몸통에 금색 두 줄 테와 귀퉁이 보석
	var frame = Kit.plate(Color("243a9c"), Kit.TRIM, 28.0, 24)
	frame.trim_width = 5.0
	# 그림 창틀: 위·아래 가운데 장식이 달린 화려한 틀. 테가 두꺼워 여백을 넉넉히 둔다.
	frame.grand = true
	if Kit.UiSkin.has("win_navy"):
		frame.set_content_margin_all(30)
		frame.content_margin_top = 40
	_panel.add_theme_stylebox_override("panel", frame)
	center.add_child(_panel)
	_column = Kit.vbox(16)
	_panel.add_child(_column)
	if title_text != "":
		# 제목 리본
		_column.add_child(Kit.ribbon(title_text, 32))
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
			var color: Color = spec[1] if spec.size() > 1 else Kit.ACCENT
			var button := Kit.button(str(spec[0]), color, 26, 72)
			# UI 개편 2단계: 창 아래 버튼도 금테 알약(색으로 뜻을 나눔).
			MenuArt.pill(button, MenuArt.pill_name(color))
			Kit.expand(button)
			var callback: Callable = spec[2] if spec.size() > 2 else Callable()
			button.pressed.connect(_on_button.bind(callback))
			row.add_child(button)
	# 창 안의 광택 버튼도 같은 색의 금테 알약으로 맞춘다(그림이 없으면 그대로).
	MenuArt.skin_buttons(_column)
	# 창이 화면보다 크면(위·아래 장식 포함) 통째로 줄여서 버튼이 화면 밖으로 나가지 않게 한다.
	# 줄바꿈 글(Kit.para)은 창 너비가 정해지기 전에는 키가 아주 크게 잡혀서, 바로 재면 창이 쓸데없이
	# 작게 줄어든다(스킬 설명·환영 창 글자가 작아 보이던 까닭). 그래서 두 프레임 기다려 자리를 잡은 뒤 잰다.
	_panel.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(_panel):
		return
	var need: Vector2 = _panel.get_combined_minimum_size()
	# 세로로 든 화면에서는 틀이 돌아가 있으므로, 창 크기가 아니라 틀(부모)의 크기에 맞춘다.
	var holder := get_parent() as Control
	var room: Vector2 = (holder.size if holder != null else get_viewport_rect().size) - Vector2(40, 96)
	var fit := minf(1.0, minf(room.x / maxf(need.x, 1.0), room.y / maxf(need.y, 1.0)))
	_panel.pivot_offset = _panel.size * 0.5
	_panel.modulate.a = 1.0
	# 금테 창은 0.2초 동안 0.9배에서 1배로 커지며 뜬다(UI 개편 3단계). 자동 사진·저사양 모드에서는 곧바로 1배.
	if MenuArt.calm(holder):
		_panel.scale = Vector2.ONE * fit
		return
	_panel.scale = Vector2(0.9, 0.9) * fit
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "scale", Vector2.ONE * fit, 0.2)


func _on_button(callback: Callable) -> void:
	close()
	if callback.is_valid():
		callback.call()


func close() -> void:
	closed.emit()
	queue_free()
