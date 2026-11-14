extends Control
## 판이 시작될 때 뜨는 'VS' 화면. 양쪽 파티 세 명씩이 마주 보고, 가운데에 맵 이름이 나온다.
## play()는 화면이 사라질 때까지 기다린다. 누르면 바로 넘어간다.

const Portrait := preload("res://scripts/ui/portrait.gd")

const SLOT_NAMES := ["ATTACK", "DEFENSE", "SUPPORT"]
const HOLD_TIME := 1.7

var _skipped := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_skipped = true


## sides: [{"name": 이름, "color": 색, "members": [캐릭터 3명], "levels": [레벨 3개]}, 같은 모양]
func play(sides: Array, map_text: String, goal_text: String) -> void:
	for child in get_children():
		child.queue_free()
	_skipped = false
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.1, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var panels: Array = []
	for index in 2:
		var panel := _side(sides[index], index == 1)
		add_child(panel)
		panel.anchor_left = 0.04 if index == 0 else 0.54
		panel.anchor_right = 0.46 if index == 0 else 0.96
		panel.anchor_top = 0.2
		panel.anchor_bottom = 0.8
		panels.append(panel)
	var middle := VBoxContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.anchor_left = 0.0
	middle.anchor_right = 1.0
	middle.anchor_top = 0.04
	middle.anchor_bottom = 0.19
	add_child(middle)
	middle.add_child(_text(map_text, 34, Color("ffcf4d"), 8))
	middle.add_child(_text(goal_text, 22, Color(1, 1, 1, 0.85), 4))
	var versus := _text("VS", 110, Color("ffcf4d"), 16)
	versus.anchor_left = 0.0
	versus.anchor_right = 1.0
	versus.anchor_top = 0.5
	versus.anchor_bottom = 0.5
	versus.offset_top = -80
	versus.offset_bottom = 80
	versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(versus)
	var skip := _text("화면을 누르면 넘어갑니다", 20, Color(1, 1, 1, 0.6), 4)
	skip.anchor_left = 0.0
	skip.anchor_right = 1.0
	skip.anchor_top = 0.86
	skip.anchor_bottom = 0.86
	add_child(skip)

	modulate.a = 1.0
	visible = true
	await get_tree().process_frame
	if not is_inside_tree():
		return
	# 양쪽에서 미끄러져 들어오고 VS가 커졌다 줄어든다.
	var slide := size.x * 0.5
	panels[0].position.x -= slide
	panels[1].position.x += slide
	versus.pivot_offset = versus.size * 0.5
	versus.scale = Vector2(3.0, 3.0)
	versus.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panels[0], "position:x", panels[0].position.x + slide, 0.35)
	tween.parallel().tween_property(panels[1], "position:x", panels[1].position.x - slide, 0.35)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(versus, "scale", Vector2.ONE, 0.2)
	tween.parallel().tween_property(versus, "modulate:a", 1.0, 0.12)
	var waited := 0.0
	while waited < HOLD_TIME + 0.55 and not _skipped and is_inside_tree():
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not is_inside_tree():
		return
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.22)
	await fade.finished
	visible = false


func _side(side: Dictionary, flip: bool) -> Control:
	var color: Color = side["color"]
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 0.95)
	style.border_color = color
	style.set_border_width_all(4)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(_text(str(side["name"]), 28, color, 6))
	var members: Array = side["members"]
	var levels: Array = side.get("levels", [])
	for index in members.size():
		var member: Dictionary = members[index]
		var face := Portrait.new()
		face.size_flags_vertical = Control.SIZE_EXPAND_FILL
		face.custom_minimum_size = Vector2(0, 120)
		face.border = color
		face.border_width = 3.0
		face.show_character(member, color.darkened(0.4))
		column.add_child(face)
		var level_text := "  Lv.%d" % int(levels[index]) if index < levels.size() else ""
		var caption := "%s  %s%s" % [SLOT_NAMES[index], member.get("name", ""), level_text]
		var line := _text(caption, 19, Color.WHITE, 4)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if flip else HORIZONTAL_ALIGNMENT_LEFT
		line.clip_text = true
		column.add_child(line)
	return panel


func _text(text: String, font_size: int, color: Color, outline: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
