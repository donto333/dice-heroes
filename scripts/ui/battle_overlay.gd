extends Control
## 전투 화면. 전투가 일어나면 보드 위에 덮어서 양쪽 주사위를 굴리고 결과를 보여 준다.
## play()가 끝날 때까지 기다렸다가 다음 연출로 넘어간다. 화면을 누르면 빨리 넘긴다.

const ArtView := preload("res://scripts/ui/art_view.gd")
const DiceView := preload("res://scripts/ui/dice_view.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const BoardView := preload("res://scripts/ui/board_view.gd")
const Game := preload("res://scripts/rules/game.gd")
const GameData := preload("res://scripts/game_data.gd")
const Fx := preload("res://scripts/ui/fx.gd")
const Kit := preload("res://scripts/ui/kit.gd")

const GOLD := Color("ffcf4d")
const WIN_COLOR := Color("7ee081")
const LOSE_COLOR := Color("ff6b6b")
const ROLL_TIME := 0.9
const HOLD_TIME := 1.6
## 움직이는 모형(assets/standees_anim, 6칸×2줄 12장): 가만히는 첫 장면에 숨쉬기만, 베기는 0.6초에 12장.
const ANIM_FRAMES := 12
const ANIM_COLUMNS := 6
const SLASH_TIME := 0.6
## 한 칸에서 모형이 있는 부분만 잘라 보여 준다(발은 칸의 81.25% 높이).
const ANIM_CROP := Rect2(0.1, 0.06, 0.8, 0.8)

var sfx: Node = null

var _title: Label
var _sides: Array = []
var _verdict: Label
var _hint: Label
var _skip := false
## 쪽마다 움직이는 모형 상태: {"sheets": {종류: 그림}, "kind": 지금 동작, "time": 동작 시작부터 흐른 시간}
var _anim_sides: Array = [{}, {}]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.1, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 원작처럼 창 없이 판 위에서 바로 싸운다(뒤의 판은 어둡게만 한다).
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)

	_title = _label("BATTLE", 50, GOLD)
	_title.add_theme_constant_override("outline_size", 10)
	_title.add_theme_color_override("font_outline_color", Color("5a3a00"))
	var battle_logo: Texture2D = GameData.logo("battle")
	if battle_logo != null:
		# 입체 로고가 있으면 글자는 비우고 그 자리에 그림을 얹는다.
		_title.text = " "
		_title.custom_minimum_size = Vector2(0, 96)
		_title.add_child(_picture(battle_logo))
	column.add_child(_title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	for side in 2:
		var side_box := VBoxContainer.new()
		side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side_box.add_theme_constant_override("separation", 2)
		side_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var role := _label("", 22, Color.WHITE)
		var portrait_holder := CenterContainer.new()
		portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var portrait := Portrait.new()
		portrait.custom_minimum_size = Vector2(150, 150)
		portrait_holder.add_child(portrait)
		# 입체 모형이 있으면 초상화 대신 모형이 결투장에 선다.
		var figure := TextureRect.new()
		figure.custom_minimum_size = Vector2(190, 190)
		figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		figure.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
		figure.visible = false
		# 받침대는 모형보다 먼저 넣어 모형 발밑에 깔리게 한다.
		var pedestal := Control.new()
		pedestal.custom_minimum_size = Vector2(190, 190)
		pedestal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pedestal.draw.connect(_draw_pedestal.bind(pedestal))
		pedestal.visible = false
		portrait_holder.add_child(pedestal)
		portrait_holder.add_child(figure)
		# 승패가 갈리면 그림 위에 도장처럼 찍히는 글자
		var stamp := _label("", 58, WIN_COLOR)
		stamp.add_theme_constant_override("outline_size", 14)
		stamp.add_theme_color_override("font_outline_color", Color.BLACK)
		stamp.visible = false
		portrait_holder.add_child(stamp)
		var who := _label("", 30, Color.WHITE)
		var total := _label("00", 60, Color.WHITE)
		total.add_theme_constant_override("outline_size", 8)
		total.add_theme_color_override("font_outline_color", Color.BLACK)
		var dice_holder := CenterContainer.new()
		dice_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dice := DiceView.new()
		dice.die_size = 40.0
		dice_holder.add_child(dice)
		var bonus := _label("", 20, GOLD)
		side_box.add_child(role)
		side_box.add_child(portrait_holder)
		side_box.add_child(who)
		side_box.add_child(total)
		side_box.add_child(dice_holder)
		side_box.add_child(bonus)
		row.add_child(side_box)
		_sides.append({"role": role, "portrait": portrait, "who": who, "total": total, "dice": dice, "bonus": bonus, "stamp": stamp, "figure": figure, "pedestal": pedestal})
		if side == 0:
			var versus := _label("VS", 48, LOSE_COLOR)
			versus.add_theme_constant_override("outline_size", 8)
			versus.add_theme_color_override("font_outline_color", Color.BLACK)
			var vs_logo: Texture2D = GameData.logo("vs")
			if vs_logo != null:
				versus.text = " "
				versus.custom_minimum_size = Vector2(130, 110)
				versus.add_child(_picture(vs_logo))
			versus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(versus)

	_verdict = _label("", 36, Color.WHITE)
	_verdict.add_theme_constant_override("outline_size", 8)
	_verdict.add_theme_color_override("font_outline_color", Color.BLACK)
	column.add_child(_verdict)
	_hint = _label("화면을 누르면 넘어갑니다", 18, Color(1, 1, 1, 0.45))
	column.add_child(_hint)


func _process(delta: float) -> void:
	if not visible:
		return
	for index in _anim_sides.size():
		var state: Dictionary = _anim_sides[index]
		if state.is_empty():
			continue
		state["time"] = float(state["time"]) + delta
		var kind := str(state["kind"])
		var frame := 0
		var sheets: Dictionary = state["sheets"]
		if kind == "slash":
			var slash_count := GameData.anim_frame_count(sheets.get("slash"))
			frame = int(float(state["time"]) / SLASH_TIME * slash_count)
			if frame >= slash_count:
				# 한 번 베고 나면 가만히로 돌아간다.
				state["kind"] = "idle"
				state["time"] = 0.0
				kind = "idle"
				frame = 0
		var figure: TextureRect = _sides[index]["figure"]
		if kind != "slash" and GameData.live_idle(sheets.get("idle")):
			# 클링 영상으로 만든 대기 그림은 그대로 돌려 숨 쉬고 옷자락이 흔들리게 한다.
			frame = GameData.idle_frame(sheets.get("idle"), float(state["time"]))
			figure.scale = Vector2.ONE
		elif kind != "slash":
			# 서 있을 때는 첫 장면에 멈추고 숨쉬기만 한다(트리포 대기 동작은 고개를 두리번거려 목이 흔들려 보였다).
			frame = 0
			var wave := sin(float(state["time"]) * 2.2 + index * 1.7)
			figure.pivot_offset = Vector2(figure.size.x * 0.5, figure.size.y * 0.94)
			figure.scale = Vector2(1.0 - 0.008 * wave, 1.0 + 0.02 * wave)
		else:
			figure.scale = Vector2.ONE
		_set_anim_frame(index, kind, frame)


## 움직이는 모형의 한 장면을 보여 준다.
func _set_anim_frame(index: int, kind: String, frame: int) -> void:
	var state: Dictionary = _anim_sides[index]
	var sheets: Dictionary = state["sheets"]
	var sheet: Texture2D = sheets.get(kind, sheets.get("idle"))
	var figure: TextureRect = _sides[index]["figure"]
	var atlas := figure.texture as AtlasTexture
	if atlas == null or sheet == null:
		return
	atlas.atlas = sheet
	var sheet_size := sheet.get_size()
	var one_row := sheet_size.x >= sheet_size.y * float(ANIM_FRAMES) - 0.5
	var cell := sheet_size.y if one_row else sheet_size.x / float(ANIM_COLUMNS)
	var origin := Vector2((frame % ANIM_COLUMNS) * cell, floorf(float(frame) / float(ANIM_COLUMNS)) * cell)
	if one_row:
		origin = Vector2(frame * cell, 0)
	atlas.region = Rect2(origin + ANIM_CROP.position * cell, ANIM_CROP.size * cell)


## 공격(베기) 동작을 한 번 한다. 동작 그림이 없으면 아무것도 안 한다.
func _swing(index: int) -> void:
	var state: Dictionary = _anim_sides[index]
	if state.is_empty() or not (state["sheets"] as Dictionary).has("slash"):
		return
	state["kind"] = "slash"
	state["time"] = 0.0


## 글자 칸을 꽉 채우는 로고 그림
func _picture(texture: Texture2D) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return picture


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_skip = true
	elif event is InputEventScreenTouch and event.pressed:
		_skip = true


## battle: 규칙 엔진의 "battle" 사건. info: 화면에 보일 이름과 색.
## {"attacker_side": "공격 · 나", "defender_side": "방어 · 키퍼", "attacker_color": Color, "defender_color": Color,
##  "winner_text": "나 승리!", "loser_text": "나 패배...",
##  "attacker_character": {캐릭터}, "defender_character": {캐릭터}}  (몬스터·키퍼는 빈 사전)
## 골의 수호자 이름(보스 그림을 쓴다). info["boss_name"]으로 받는다.
var _boss_name := ""


func play(battle: Dictionary, info: Dictionary) -> void:
	_boss_name = str(info.get("boss_name", ""))
	_skip = false
	var attack_rolls: Array = battle["attack_rolls"]
	var defense_rolls: Array = battle["defense_rolls"]
	var attack_total := int(battle["attack_total"])
	var defense_total := int(battle["defense_total"])
	var attack_bonus := attack_total - _sum(attack_rolls)
	var defense_bonus := defense_total - _sum(defense_rolls)

	var left: Dictionary = _sides[0]
	var right: Dictionary = _sides[1]
	left["role"].text = info.get("attacker_side", "공격")
	left["role"].add_theme_color_override("font_color", info.get("attacker_color", Color.WHITE))
	left["who"].text = battle["attacker"]
	_show_portrait(left, info.get("attacker_character", {}), str(battle["attacker"]), info.get("attacker_color", Color.WHITE))
	right["role"].text = info.get("defender_side", "방어")
	right["role"].add_theme_color_override("font_color", info.get("defender_color", Color.WHITE))
	right["who"].text = battle["defender"]
	_show_portrait(right, info.get("defender_character", {}), str(battle["defender"]), info.get("defender_color", Color.WHITE))
	for side in _sides:
		side["total"].text = "00"
		side["stamp"].visible = false
		side["total"].add_theme_color_override("font_color", Color.WHITE)
		side["bonus"].text = ""
	left["dice"].die_size = _die_size(attack_rolls.size())
	right["dice"].die_size = _die_size(defense_rolls.size())
	# 굴리기 전에 공격 쪽 예상 승률을 보여 준다(판정이 나면 승패 글자로 바뀐다).
	var chance := Game.win_chance(attack_rolls.size(), defense_rolls.size(), attack_bonus, defense_bonus)
	_verdict.text = "공격 승률 약 %d%%" % int(round(chance * 100.0))
	_verdict.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))

	visible = true
	modulate = Color(1, 1, 1, 0)
	_title.scale = Vector2(1.6, 1.6)
	_title.pivot_offset = _title.size / 2.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	tween.tween_property(_title, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_play_sound("hit")
	await tween.finished

	# 공격 쪽이 먼저 굴리고 점수가 올라간 뒤, 방어 쪽이 굴린다. 누르면 빨리 넘어간다.
	left["dice"].values = _blank(attack_rolls.size())
	right["dice"].values = _blank(defense_rolls.size())
	await _roll_side(left, attack_rolls, attack_total, attack_bonus)
	await _roll_side(right, defense_rolls, defense_total, defense_bonus)

	var won: bool = battle["won"]
	await _clash(_actor(left), _actor(right), won)
	var winner_side: Dictionary = left if won else right
	var loser_side: Dictionary = right if won else left
	winner_side["total"].add_theme_color_override("font_color", WIN_COLOR)
	loser_side["portrait"].dim = true
	loser_side["portrait"].queue_redraw()
	loser_side["figure"].modulate = Color(0.45, 0.45, 0.55)
	winner_side["portrait"].border = WIN_COLOR
	winner_side["portrait"].queue_redraw()
	loser_side["total"].add_theme_color_override("font_color", LOSE_COLOR)
	_stamp(winner_side, "WIN", WIN_COLOR, -0.14)
	_stamp(loser_side, "LOSE", LOSE_COLOR, 0.14)
	_verdict.text = info.get("winner_text", "승리!") if won else info.get("loser_text", "패배...")
	_verdict.add_theme_color_override("font_color", WIN_COLOR if info.get("good_for_me", won) else LOSE_COLOR)
	_play_sound("good" if info.get("good_for_me", won) else "bad")

	var waited := 0.0
	_skip = false
	while waited < HOLD_TIME and not _skip:
		await get_tree().process_frame
		waited += get_process_delta_time()

	var fade := create_tween()
	fade.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.15)
	await fade.finished
	visible = false


## 충돌 연출: 두 초상화가 가운데로 돌진해 부딪치고 화면이 번쩍인다. 진 쪽은 뒤로 밀려 기울어진다.
func _clash(left_face: Control, right_face: Control, attacker_won: bool) -> void:
	if _skip:
		return
	var left_home := left_face.position
	var right_home := right_face.position
	# 움직이는 모형이면 두 쪽이 함께 칼을 휘두르고, 칼이 내려오는 순간(12장 중 5장째쯤)에 부딪친다.
	# 트리포 웹 모형의 베기(chop)는 몸을 깊이 숙이는 장면이 있어, 그때 번쩍임이 덮이게 맞춘다.
	if not _anim_sides[0].is_empty() or not _anim_sides[1].is_empty():
		_swing(0)
		_swing(1)
		await get_tree().create_timer(SLASH_TIME * 0.17).timeout
	var dash := create_tween().set_parallel(true)
	dash.tween_property(left_face, "position:x", left_home.x + 90.0, 0.12).set_ease(Tween.EASE_IN)
	dash.tween_property(right_face, "position:x", right_home.x - 90.0, 0.12).set_ease(Tween.EASE_IN)
	await dash.finished
	_play_sound("impact")
	var white := ColorRect.new()
	white.color = Color(1, 1, 1, 0.85)
	white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(white)
	var fade := white.create_tween()
	fade.tween_property(white, "color:a", 0.0, 0.3)
	fade.tween_callback(white.queue_free)
	_spark_at((Kit.spot_in(self, left_face, left_face.size * 0.5) + Kit.spot_in(self, right_face, right_face.size * 0.5)) * 0.5)
	# 창 전체가 덜컹
	var home := position
	var rattle := create_tween()
	for index in 5:
		rattle.tween_property(self, "position", home + Vector2(18.0 if index % 2 == 0 else -18.0, 8.0 if index % 3 == 0 else -6.0) * (1.0 - index / 5.0), 0.04)
	rattle.tween_property(self, "position", home, 0.04)
	var loser: Control = right_face if attacker_won else left_face
	var push := 70.0 if attacker_won else -70.0
	loser.pivot_offset = loser.size * 0.5
	var back := create_tween().set_parallel(true)
	back.tween_property(left_face, "position:x", left_home.x + (0.0 if attacker_won else push), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	back.tween_property(right_face, "position:x", right_home.x + (push if attacker_won else 0.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	back.tween_property(loser, "rotation", 0.22 if attacker_won else -0.22, 0.2)
	await back.finished
	# 다음 전투를 위해 제자리로
	await get_tree().create_timer(0.05).timeout
	_restore_later(left_face, left_home, right_face, right_home)


## 부딪친 자리에서 충격 섬광·엇갈린 칼자국·충격 고리 그림이 겹쳐 터진다(더하기 섞기로 빛난다).
## 효과 그림이 없으면 뾰족한 별 도형으로 대신한다.
func _spark_at(spot: Vector2) -> void:
	var layers := [["impact_burst", 520.0, 0.36, 0.5], ["slash_cross", 460.0, 0.32, -0.3], ["ring_shock", 560.0, 0.45, 0.0], ["flare_star", 420.0, 0.3, 0.8]]
	var drew := false
	for layer in layers:
		var texture: Texture2D = Fx.tex(str(layer[0]))
		if texture == null:
			continue
		drew = true
		var sprite := TextureRect.new()
		sprite.texture = texture
		sprite.material = Fx.additive()
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var reach := float(layer[1])
		sprite.size = Vector2(reach, reach)
		sprite.position = spot - sprite.size * 0.5
		sprite.pivot_offset = sprite.size * 0.5
		sprite.scale = Vector2(0.3, 0.3)
		add_child(sprite)
		var seconds := float(layer[2])
		var pop := sprite.create_tween().set_parallel(true)
		pop.tween_property(sprite, "scale", Vector2(1.25, 1.25), seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		pop.tween_property(sprite, "rotation", float(layer[3]), seconds)
		pop.tween_property(sprite, "modulate:a", 0.0, seconds * 0.6).set_delay(seconds * 0.4)
		pop.chain().tween_callback(sprite.queue_free)
	if drew:
		return
	for index in 2:
		var star := Polygon2D.new()
		var points := PackedVector2Array()
		var spikes := 8
		var reach := 120.0 if index == 0 else 80.0
		for corner in spikes * 2:
			var angle := TAU * corner / float(spikes * 2)
			points.append(Vector2(cos(angle), sin(angle)) * (reach if corner % 2 == 0 else reach * 0.36))
		star.polygon = points
		star.color = Color("ff9a2a") if index == 0 else Color("fff6c0")
		star.position = spot
		star.scale = Vector2(0.2, 0.2)
		star.rotation = index * 0.4
		add_child(star)
		var burst := star.create_tween().set_parallel(true)
		burst.tween_property(star, "scale", Vector2(1.5, 1.5), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		burst.tween_property(star, "rotation", star.rotation + 0.9, 0.3)
		burst.tween_property(star, "modulate:a", 0.0, 0.3).set_delay(0.12)
		burst.chain().tween_callback(star.queue_free)


## 전투 창이 닫힌 뒤 초상화를 제자리·바른 각도로 돌려놓는다.
func _restore_later(left_face: Control, left_home: Vector2, right_face: Control, right_home: Vector2) -> void:
	while visible and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	left_face.position = left_home
	right_face.position = right_home
	left_face.rotation = 0.0
	right_face.rotation = 0.0


func _blank(count: int) -> Array:
	var values: Array = []
	for i in count:
		values.append(1)
	return values


## 한쪽 주사위를 하나씩 던진다. 하나가 멈출 때마다 점수가 그만큼 올라가며 통 튄다(원작의 박자).
func _roll_side(side: Dictionary, rolls: Array, total: int, bonus: int) -> void:
	var shown: Array = _blank(rolls.size())
	var running := 0
	for index in rolls.size():
		_play_sound("dice")
		# 아직 안 던진 주사위는 그대로 두고 이번 것만 굴린다.
		var spin_time := 0.1 if _skip else 0.26
		var elapsed := 0.0
		while elapsed < spin_time and is_inside_tree():
			shown[index] = 1 + (randi() % 6)
			side["dice"].values = shown.duplicate()
			await get_tree().create_timer(0.05).timeout
			elapsed += 0.05
		shown[index] = int(rolls[index])
		side["dice"].values = shown.duplicate()
		running += int(rolls[index])
		side["total"].text = "%02d" % running
		side["total"].pivot_offset = side["total"].size / 2.0
		var tick := create_tween()
		tick.tween_property(side["total"], "scale", Vector2(1.22, 1.22), 0.05)
		tick.tween_property(side["total"], "scale", Vector2.ONE, 0.09)
		_play_sound("land")
		if not _skip:
			await get_tree().create_timer(0.12).timeout
	if bonus != 0:
		side["bonus"].text = "보너스 %+d" % bonus
		side["total"].text = "%02d" % total
	side["total"].pivot_offset = side["total"].size / 2.0
	var bump := create_tween()
	bump.tween_property(side["total"], "scale", Vector2(1.35, 1.35), 0.08)
	bump.tween_property(side["total"], "scale", Vector2.ONE, 0.14)
	await bump.finished


## 그림 위에 WIN·LOSE를 크게 찍는다.
func _stamp(side: Dictionary, text: String, color: Color, tilt: float) -> void:
	var stamp: Label = side["stamp"]
	stamp.text = text
	stamp.add_theme_color_override("font_color", color)
	for old in stamp.get_children():
		old.queue_free()
	var stamp_logo: Texture2D = GameData.logo(text.to_lower())
	if stamp_logo != null:
		stamp.text = " "
		stamp.custom_minimum_size = Vector2(210, 110)
		stamp.add_child(_picture(stamp_logo))
	stamp.visible = true
	stamp.pivot_offset = stamp.size / 2.0
	stamp.rotation = tilt
	stamp.scale = Vector2(2.6, 2.6)
	stamp.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(stamp, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(stamp, "modulate:a", 1.0, 0.1)


## 모형 발밑의 돌 받침대(납작한 원기둥)와 그림자.
func _draw_pedestal(figure: Control) -> void:
	var stone: Texture2D = GameData.object("pedestal_green" if figure == _sides[0]["pedestal"] else "pedestal_red") if not _sides.is_empty() else null
	if stone != null:
		var stone_wide := figure.size.x * 1.15
		var stone_tall := stone_wide * float(stone.get_height()) / float(stone.get_width())
		figure.draw_texture_rect(stone, Rect2((figure.size.x - stone_wide) * 0.5, figure.size.y - stone_tall * 0.52, stone_wide, stone_tall), false)
		return
	var foot := Vector2(figure.size.x * 0.5, figure.size.y - 6.0)
	var wide := figure.size.x * 0.46
	figure.draw_set_transform(foot + Vector2(0, 16), 0.0, Vector2(1.0, 0.3))
	figure.draw_circle(Vector2.ZERO, wide * 1.12, Color(0, 0, 0, 0.4))
	figure.draw_circle(Vector2.ZERO, wide, Color("3c4a3a"))
	figure.draw_set_transform(foot, 0.0, Vector2(1.0, 0.3))
	figure.draw_circle(Vector2.ZERO, wide, Color("7d9a6a"))
	figure.draw_arc(Vector2.ZERO, wide * 0.82, 0.0, TAU, 36, Color("c9e0a8"), 4.0)
	figure.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 이 쪽에서 움직이는 그림(모형이 있으면 모형, 없으면 초상화)
func _actor(side: Dictionary) -> Control:
	return side["figure"] if side["figure"].visible else side["portrait"]


func _show_portrait(side: Dictionary, character: Dictionary, fallback_name: String, color: Color) -> void:
	var portrait = side["portrait"]
	var figure: TextureRect = side["figure"]
	var model: Texture2D = GameData.enemy_standee(fallback_name) if character.is_empty() else GameData.standee(str(character.get("id", "")))
	var index := _sides.find(side)
	if index >= 0:
		_anim_sides[index] = {}
	var sheets: Dictionary = {} if character.is_empty() else GameData.standee_anims(str(character.get("id", "")))
	if sheets.has("idle") and index >= 0:
		# 3D 모형을 찍은 움직이는 그림: 가만히 서 있다가 부딪칠 때 벤다.
		var atlas := AtlasTexture.new()
		atlas.atlas = sheets["idle"]
		model = atlas
		_anim_sides[index] = {"sheets": sheets, "kind": "idle", "time": randf() * 1.0}
	figure.texture = model
	if index >= 0 and not _anim_sides[index].is_empty():
		_set_anim_frame(index, "idle", 0)
	figure.visible = model != null
	side["pedestal"].visible = model != null
	figure.modulate = Color.WHITE
	# 영웅 모형은 오른쪽을, 적 모형은 왼쪽을 본다. 서로 마주 보게 뒤집는다.
	var on_right: bool = side == _sides[1]
	figure.flip_h = on_right != character.is_empty()
	portrait.visible = model == null
	portrait.dim = false
	portrait.border = color
	if character.is_empty():
		var kind: int = BoardView.MONSTER_BOSS if fallback_name == _boss_name else BoardView.monster_kind("battle", fallback_name)
		portrait.show_monster(kind, fallback_name, Color("7a3a3a"))
	else:
		portrait.show_character(character, color.darkened(0.3))


func _die_size(count: int) -> float:
	return clamp(250.0 / max(count, 1) - 6.0, 26.0, 44.0)


func _sum(values: Array) -> int:
	var total := 0
	for value in values:
		total += int(value)
	return total


func _play_sound(sound_name: String) -> void:
	if sfx != null:
		sfx.play(sound_name)
