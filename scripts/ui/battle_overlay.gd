extends Control
## 전투 화면. 전투가 일어나면 보드 위에 덮어서 양쪽 주사위를 굴리고 결과를 보여 준다.
## play()가 끝날 때까지 기다렸다가 다음 연출로 넘어간다. 화면을 누르면 빨리 넘긴다.

const ArtView := preload("res://scripts/ui/art_view.gd")
const DiceView := preload("res://scripts/ui/dice_view.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const BoardView := preload("res://scripts/ui/board_view.gd")
const Game := preload("res://scripts/rules/game.gd")

const GOLD := Color("ffcf4d")
const WIN_COLOR := Color("7ee081")
const LOSE_COLOR := Color("ff6b6b")
const ROLL_TIME := 0.9
const HOLD_TIME := 1.6

var sfx: Node = null

var _title: Label
var _sides: Array = []
var _verdict: Label
var _hint: Label
var _skip := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.1, 0.28, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(660, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color("1f66c8")
	box.border_color = Color.WHITE
	box.set_border_width_all(5)
	box.shadow_color = Color(0, 0.05, 0.2, 0.5)
	box.shadow_size = 12
	box.set_corner_radius_all(30)
	box.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)

	# 결투장 바탕 그림(assets/art/ui/battle_bg.jpg). 글자가 잘 보이게 어둡게 덮는다.
	var arena := ArtView.new()
	arena.show_art("ui/battle_bg")
	arena.focus_y = 0.5
	arena.shade = Color(0.02, 0.1, 0.3, 0.45)
	panel.add_child(arena)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)

	_title = _label("BATTLE", 64, GOLD)
	_title.add_theme_constant_override("outline_size", 10)
	_title.add_theme_color_override("font_outline_color", Color("5a3a00"))
	column.add_child(_title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	for side in 2:
		var side_box := VBoxContainer.new()
		side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side_box.add_theme_constant_override("separation", 6)
		side_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var role := _label("", 22, Color.WHITE)
		var portrait_holder := CenterContainer.new()
		portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var portrait := Portrait.new()
		portrait.custom_minimum_size = Vector2(170, 170)
		portrait_holder.add_child(portrait)
		# 승패가 갈리면 그림 위에 도장처럼 찍히는 글자
		var stamp := _label("", 58, WIN_COLOR)
		stamp.add_theme_constant_override("outline_size", 14)
		stamp.add_theme_color_override("font_outline_color", Color.BLACK)
		stamp.visible = false
		portrait_holder.add_child(stamp)
		var who := _label("", 30, Color.WHITE)
		var total := _label("00", 76, Color.WHITE)
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
		_sides.append({"role": role, "portrait": portrait, "who": who, "total": total, "dice": dice, "bonus": bonus, "stamp": stamp})
		if side == 0:
			var versus := _label("VS", 48, LOSE_COLOR)
			versus.add_theme_constant_override("outline_size", 8)
			versus.add_theme_color_override("font_outline_color", Color.BLACK)
			versus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(versus)

	_verdict = _label("", 44, Color.WHITE)
	_verdict.add_theme_constant_override("outline_size", 8)
	_verdict.add_theme_color_override("font_outline_color", Color.BLACK)
	column.add_child(_verdict)
	_hint = _label("화면을 누르면 넘어갑니다", 18, Color(1, 1, 1, 0.45))
	column.add_child(_hint)


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
	var winner_side: Dictionary = left if won else right
	var loser_side: Dictionary = right if won else left
	winner_side["total"].add_theme_color_override("font_color", WIN_COLOR)
	loser_side["portrait"].dim = true
	loser_side["portrait"].queue_redraw()
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


func _blank(count: int) -> Array:
	var values: Array = []
	for i in count:
		values.append(1)
	return values


## 한쪽 주사위를 굴리고 합계를 0부터 세어 올린다.
func _roll_side(side: Dictionary, rolls: Array, total: int, bonus: int) -> void:
	_play_sound("dice")
	await side["dice"].roll_to(rolls, 0.25 if _skip else ROLL_TIME * 0.75)
	var steps := 4 if _skip else 10
	for step in steps + 1:
		side["total"].text = "%02d" % int(round(total * step / float(steps)))
		await get_tree().create_timer(0.03).timeout
	if bonus != 0:
		side["bonus"].text = "보너스 %+d" % bonus
	side["total"].pivot_offset = side["total"].size / 2.0
	var bump := create_tween()
	bump.tween_property(side["total"], "scale", Vector2(1.25, 1.25), 0.08)
	bump.tween_property(side["total"], "scale", Vector2.ONE, 0.12)
	await bump.finished


## 그림 위에 WIN·LOSE를 크게 찍는다.
func _stamp(side: Dictionary, text: String, color: Color, tilt: float) -> void:
	var stamp: Label = side["stamp"]
	stamp.text = text
	stamp.add_theme_color_override("font_color", color)
	stamp.visible = true
	stamp.pivot_offset = stamp.size / 2.0
	stamp.rotation = tilt
	stamp.scale = Vector2(2.6, 2.6)
	stamp.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(stamp, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(stamp, "modulate:a", 1.0, 0.1)


func _show_portrait(side: Dictionary, character: Dictionary, fallback_name: String, color: Color) -> void:
	var portrait = side["portrait"]
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
