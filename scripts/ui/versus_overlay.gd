extends Control
## 판이 시작될 때 뜨는 'VS' 화면. 양쪽 파티 세 명씩이 마주 보고, 가운데에 맵 이름이 나온다.
## play()는 화면이 사라질 때까지 기다린다. 누르면 바로 넘어간다.

const Portrait := preload("res://scripts/ui/portrait.gd")
const GameData := preload("res://scripts/game_data.gd")
const WaitBackdrop := preload("res://scripts/ui/wait_backdrop.gd")
const LoadingOverlay := preload("res://scripts/ui/loading_overlay.gd")

const HOLD_TIME := 2.4
## 대전 시작 때 영웅이 하는 한마디(분류마다 말투가 다르다)
const QUOTES := {
	"영웅": ["내 창끝을 피할 수 있겠느냐!", "물러서지 않는다. 덤벼라!", "승부는 이미 정해졌다."],
	"위인": ["계산은 이미 끝났습니다.", "지혜가 힘을 이기는 법이지요.", "한 수 가르쳐 드리지요."],
	"신화": ["하늘의 뜻을 거스르지 마라.", "천 년을 기다린 승부다.", "신의 주사위는 정해져 있다."],
	"근현대": ["새 시대의 방식으로 가 보죠!", "불가능은 없습니다. 출발!", "세상은 도전하는 자의 것!"],
}

var _skipped := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_skipped = true


## sides: [{"name": 이름, "color": 색, "members": [캐릭터 3명], "levels": [레벨 3개]}, 같은 모양]
## searching이 true면(랭크전) 먼저 "상대를 찾는 중..."을 잠깐 보여 준다.
func play(sides: Array, map_text: String, goal_text: String, searching: bool = false) -> void:
	for child in get_children():
		child.queue_free()
	_skipped = false
	if searching:
		await _search()
		if not is_inside_tree():
			return
		for child in get_children():
			child.queue_free()
		_skipped = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.06, 0.18, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	# 가로 화면: 왼쪽 절반은 나, 오른쪽 절반은 상대. 대표(ATTACK) 영웅 그림을 크게 깔고 이름·별명·한마디를 기울여 얹는다.
	var panels: Array = []
	for index in 2:
		var panel := _side(sides[index], index == 1)
		add_child(panel)
		panel.anchor_left = 0.0 if index == 0 else 0.5
		panel.anchor_right = 0.5 if index == 0 else 1.0
		panel.anchor_top = 0.0
		panel.anchor_bottom = 1.0
		panels.append(panel)
	# 가운데를 가로지르는 금색 사선 띠
	var slash := ColorRect.new()
	slash.color = Color("ffcf4d")
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash.anchor_left = 0.5
	slash.anchor_right = 0.5
	slash.anchor_top = -0.2
	slash.anchor_bottom = 1.2
	slash.offset_left = -8
	slash.offset_right = 8
	slash.rotation = deg_to_rad(7.0)
	add_child(slash)
	var middle := VBoxContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.anchor_left = 0.0
	middle.anchor_right = 1.0
	middle.anchor_top = 0.0
	middle.anchor_bottom = 0.12
	add_child(middle)
	middle.add_child(_text(map_text, 34, Color("ffcf4d"), 8))
	middle.add_child(_text(goal_text.replace("\n", "  ·  "), 17, Color(1, 1, 1, 0.85), 4))
	var versus := _text("VS", 150, Color("ffcf4d"), 24)
	versus.add_theme_color_override("font_outline_color", Color("7a1010"))
	versus.anchor_left = 0.0
	versus.anchor_right = 1.0
	versus.anchor_top = 0.5
	versus.anchor_bottom = 0.5
	versus.offset_top = -100
	versus.offset_bottom = 100
	versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var vs_logo: Texture2D = GameData.logo("vs")
	if vs_logo != null:
		versus.text = " "
		var picture := TextureRect.new()
		picture.texture = vs_logo
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		versus.add_child(picture)
	add_child(versus)
	var skip := _text("화면을 누르면 넘어갑니다", 20, Color(1, 1, 1, 0.6), 4)
	skip.anchor_left = 0.0
	skip.anchor_right = 1.0
	skip.anchor_top = 0.93
	skip.anchor_bottom = 0.93
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
	slash.pivot_offset = slash.size * 0.5
	versus.rotation = deg_to_rad(-8.0)
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


## 상대를 찾는 연출(UI 개편 2단계): 대전 준비와 같은 바탕 그림 + 가운데 돌아가는 금테 주사위 문양
## + 점이 하나씩 늘어나는 글자 + 아래 도움말 한 줄. 누르면 넘어간다.
func _search() -> void:
	var backdrop = WaitBackdrop.new()
	add_child(backdrop)
	var label := _text("상대를 찾는 중", 40, Color("ffcf4d"), 10)
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 0.46
	label.anchor_bottom = 0.46
	label.offset_top = 100
	label.offset_bottom = 156
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	var tips: Array = LoadingOverlay.TIPS
	var tip := _text("도움말 · %s" % str(tips[randi() % tips.size()]), 22, Color(1, 1, 1, 0.9), 6)
	tip.anchor_left = 0.08
	tip.anchor_right = 0.92
	tip.anchor_top = 0.82
	tip.anchor_bottom = 0.82
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(tip)
	modulate.a = 1.0
	visible = true
	var waited := 0.0
	while waited < 1.3 and not _skipped and is_inside_tree():
		label.text = "상대를 찾는 중" + ".".repeat(int(waited / 0.3) % 4)
		await get_tree().process_frame
		waited += get_process_delta_time()
	if is_inside_tree():
		label.text = "상대를 찾았어요!"
		await get_tree().create_timer(0.35).timeout


## 한쪽 절반: 대표 영웅의 큰 그림 위에 기울인 이름·별명, 구석에 파티 세 명과 전투력.
## flip이 true면(위쪽, 상대) 글자를 오른쪽에 붙인다.
func _side(side: Dictionary, flip: bool) -> Control:
	var color: Color = side["color"]
	var members: Array = side["members"]
	var levels: Array = side.get("levels", [])
	var leader: Dictionary = members[0] if not members.is_empty() else {}
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	var art := Portrait.new()
	art.hd = true
	art.border_width = 0.0
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.show_character(leader, color.darkened(0.4))
	panel.add_child(art)
	# 글자가 잘 보이게 쪽 색으로 살짝 덮는다.
	var tint := ColorRect.new()
	tint.color = Color(color.r * 0.25, color.g * 0.25, color.b * 0.3, 0.38)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(tint)

	# 기울인 큰 이름과 별명
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", -6)
	words.anchor_left = 0.04
	words.anchor_right = 0.96
	words.anchor_top = 0.5
	words.anchor_bottom = 0.5
	words.offset_bottom = 230
	words.rotation = deg_to_rad(-6.0)
	panel.add_child(words)
	var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT if flip else HORIZONTAL_ALIGNMENT_LEFT
	var hero := _text(str(leader.get("name", "")), 92, Color.WHITE, 20)
	hero.horizontal_alignment = align
	hero.add_theme_color_override("font_outline_color", color.darkened(0.7))
	words.add_child(hero)
	var motto := _text(str(leader.get("title", "")), 32, Color("ffe27a"), 10)
	motto.horizontal_alignment = align
	words.add_child(motto)
	# 영웅의 한마디(분류마다 말투가 다르다): 어두운 띠 위에 흰 글자
	var lines: Array = QUOTES.get(str(leader.get("category", "")), QUOTES["영웅"])
	var quote := _text(str(lines[absi(hash(str(leader.get("id", "")))) % lines.size()]), 26, Color.WHITE, 6)
	quote.horizontal_alignment = align
	var band := StyleBoxFlat.new()
	band.bg_color = Color(0, 0, 0, 0.55)
	band.content_margin_left = 16
	band.content_margin_right = 16
	band.content_margin_top = 6
	band.content_margin_bottom = 8
	band.skew = Vector2(0.25, 0.0)
	quote.add_theme_stylebox_override("normal", band)
	words.add_child(Control.new())
	words.add_child(quote)

	# 쪽 이름과 전투력 알약
	var tag_text := str(side["name"])
	if side.has("power"):
		tag_text += "  ·  전투력 %d" % int(side["power"])
	var tag := _text(tag_text, 24, Color.WHITE, 6)
	var pill := StyleBoxFlat.new()
	pill.bg_color = color.darkened(0.25)
	pill.border_color = Color.WHITE
	pill.set_border_width_all(3)
	pill.set_corner_radius_all(22)
	pill.content_margin_left = 18
	pill.content_margin_right = 18
	pill.content_margin_top = 6
	pill.content_margin_bottom = 6
	tag.add_theme_stylebox_override("normal", pill)
	tag.anchor_left = 0.0 if not flip else 1.0
	tag.anchor_right = 0.0 if not flip else 1.0
	tag.anchor_top = 0.0
	tag.anchor_bottom = 0.0
	tag.grow_horizontal = Control.GROW_DIRECTION_END if not flip else Control.GROW_DIRECTION_BEGIN
	tag.grow_vertical = Control.GROW_DIRECTION_END
	tag.offset_left = 14 if not flip else -14
	tag.offset_right = 14 if not flip else -14
	tag.offset_top = 96
	tag.offset_bottom = 96
	panel.add_child(tag)

	# 파티 세 명: 글자 반대쪽 구석에 작은 얼굴
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	row.anchor_left = 0.0 if not flip else 1.0
	row.anchor_right = 0.0 if not flip else 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.grow_horizontal = Control.GROW_DIRECTION_END if not flip else Control.GROW_DIRECTION_BEGIN
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_left = 14 if not flip else -14
	row.offset_right = 14 if not flip else -14
	row.offset_top = -36
	row.offset_bottom = -36
	panel.add_child(row)
	for index in members.size():
		var member: Dictionary = members[index]
		var cell := VBoxContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_theme_constant_override("separation", 0)
		var face := Portrait.new()
		face.custom_minimum_size = Vector2(92, 92)
		face.border = color.lightened(0.3)
		face.border_width = 3.0
		face.show_character(member, color.darkened(0.4))
		cell.add_child(face)
		var level_text := " Lv.%d" % int(levels[index]) if index < levels.size() else ""
		cell.add_child(_text("%s%s" % [member.get("name", ""), level_text], 15, Color.WHITE, 4))
		row.add_child(cell)
	if str(side.get("bonus", "")) != "":
		var bonus := _text(str(side["bonus"]), 18, Color("b6ffd0"), 5)
		bonus.anchor_left = 0.0
		bonus.anchor_right = 1.0
		bonus.anchor_top = 0.0
		bonus.anchor_bottom = 0.0
		bonus.grow_vertical = Control.GROW_DIRECTION_END
		bonus.offset_top = 146
		bonus.offset_bottom = 146
		panel.add_child(bonus)
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
