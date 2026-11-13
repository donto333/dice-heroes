extends Control
## 대전 화면. 규칙은 scripts/rules/game.gd, 보상은 scripts/rules/profile.gd.
## setup()의 params: {"mode": "rank"|"ai"|"local", "parties": [파티1, 파티2], "humans": [true, false]}
## 친구 대전(local)은 두 사람이 한 기기를 번갈아 쓴다. 지금 차례인 사람의 어빌리티와 카드가 보인다.
##
## 화면 위에서부터: 상태 줄(나가기), 보드, 결과 패널(주사위·전투), 어빌리티, 카드, 굴리기 버튼, 진행 기록.

const Game := preload("res://scripts/rules/game.gd")
const AI := preload("res://scripts/rules/ai.gd")
const GameData := preload("res://scripts/game_data.gd")
const BoardView := preload("res://scripts/ui/board_view.gd")
const DiceView := preload("res://scripts/ui/dice_view.gd")
const BattleOverlay := preload("res://scripts/ui/battle_overlay.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")

const Profile := preload("res://scripts/rules/profile.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const ABILITY_PORTRAIT_WIDTH := 76.0
const TurnBanner := preload("res://scripts/ui/turn_banner.gd")
const ResultOverlay := preload("res://scripts/ui/result_overlay.gd")

const AI_DELAY := 1.0
const LOG_LINES := 4
const MAX_RESULT_BLOCKS := 3

const SLOT_COLORS := {"attack": Color("b8352a"), "defense": Color("6f43a6"), "support": Color("2a7d4f")}
const CARD_COLOR := Color("a6781a")
const ROLL_COLOR := Color("2f80ed")
const DISABLED_COLOR := Color("2a2f4a")
const PLAYER_TEXT_COLORS := [Color("4fc3f7"), Color("ff8a65")]

var game
var _data: Dictionary = {}
var _waiting_for_player := false
## 갈림길에서 내가 길을 골라야 하는 중인지
var _choosing_path := false

var _status_label: Label
var _board_view: Control
var _result_box: VBoxContainer
var _ability_buttons: Dictionary = {}
var _card_buttons: Array = []
var _roll_button: Button
var _log_label: Label
var _battle_overlay: Control
var _ability_portraits: Dictionary = {}
var app
var _mode := "ai"
var _parties: Array = []
var _humans: Array = [true, false]
var _cards_used := 0
var _recorded := false
var _result_text := ""
var _banner: Control
var _result_overlay: Control
## 이번 판에서 내 전투 기록. [이긴 수, 진 수]
var _my_battles := [0, 0]


func setup(main_app, params: Dictionary) -> void:
	app = main_app
	_data = app.data
	_mode = str(params.get("mode", "ai"))
	_parties = params.get("parties", [])
	_humans = params.get("humans", [true, false])
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_start_game()


func _play(sound: String) -> void:
	app.play(sound)


## 지금 화면에 어빌리티와 카드를 보여 줄 플레이어. 사람 차례면 그 사람, AI 차례면 첫 번째 사람.
func _viewer() -> int:
	if game != null and _humans[game.current]:
		return game.current
	return 0


func _is_local() -> bool:
	return _mode == "local"


# ---------------------------------------------------------------- 화면 구성

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("1b1f3b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	column.add_child(status_row)
	_status_label = _make_label(22)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(_status_label)
	var quit_button := Kit.button("나가기", Color("3a4466"), 20, 60)
	quit_button.custom_minimum_size = Vector2(120, 60)
	quit_button.pressed.connect(_on_quit_pressed)
	status_row.add_child(quit_button)

	_board_view = BoardView.new()
	_board_view.custom_minimum_size = Vector2(0, 300)
	_board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_view.size_flags_stretch_ratio = 3.0
	column.add_child(_board_view)

	var result_panel := PanelContainer.new()
	result_panel.custom_minimum_size = Vector2(0, 210)
	result_panel.add_theme_stylebox_override("panel", _box(Color("12152b"), Color("3a4466"), 2))
	column.add_child(result_panel)
	_result_box = VBoxContainer.new()
	_result_box.add_theme_constant_override("separation", 6)
	result_panel.add_child(_result_box)

	var ability_row := HBoxContainer.new()
	ability_row.add_theme_constant_override("separation", 8)
	column.add_child(ability_row)
	for slot in Game.SLOTS:
		var button := _make_button(15, 120, SLOT_COLORS[slot])
		button.pressed.connect(_on_ability_pressed.bind(slot))
		ability_row.add_child(button)
		_ability_buttons[slot] = button
		_ability_portraits[slot] = _add_side_portrait(button)

	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 8)
	column.add_child(card_row)
	for index in Game.HAND_LIMIT:
		var button := _make_button(18, 88, CARD_COLOR)
		button.pressed.connect(_on_card_pressed.bind(index))
		card_row.add_child(button)
		_card_buttons.append(button)

	_roll_button = _make_button(34, 100, ROLL_COLOR)
	_roll_button.pressed.connect(_on_roll_pressed)
	column.add_child(_roll_button)

	_log_label = _make_label(17)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.custom_minimum_size = Vector2(0, 90)
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.size_flags_stretch_ratio = 1.0
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_log_label.clip_text = true
	_log_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	column.add_child(_log_label)

	_board_view.stepped.connect(func(): _play("step"))
	_battle_overlay = BattleOverlay.new()
	_battle_overlay.sfx = app.sfx if app.sfx_on() else null
	add_child(_battle_overlay)
	_result_overlay = ResultOverlay.new()
	add_child(_result_overlay)
	_result_overlay.retry_pressed.connect(_on_retry_pressed)
	_result_overlay.change_party_pressed.connect(_on_change_party_pressed)
	_banner = TurnBanner.new()
	add_child(_banner)


func _make_label(font_size: int, text: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


## 버튼 왼쪽에 초상화를 붙이고, 글자가 초상화와 겹치지 않게 왼쪽 여백을 늘린다.
func _add_side_portrait(button: Button) -> Control:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
		box.content_margin_left = ABILITY_PORTRAIT_WIDTH + 12.0
		button.add_theme_stylebox_override(state, box)
	var portrait := Portrait.new()
	portrait.border_width = 2.0
	portrait.anchor_top = 0.0
	portrait.anchor_bottom = 1.0
	portrait.offset_left = 7.0
	portrait.offset_right = 7.0 + ABILITY_PORTRAIT_WIDTH
	portrait.offset_top = 7.0
	portrait.offset_bottom = -9.0
	button.add_child(portrait)
	return portrait


func _box(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(8)
	return box


## 켜진 버튼은 밝은 색, 꺼진 버튼은 어두운 회색으로 확실히 구분한다.
func _make_button(font_size: int, height: float, color: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_stylebox_override("normal", _box(color, color.lightened(0.35), 3))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.12), Color.WHITE, 3))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.25), Color.WHITE, 3))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", _box(DISABLED_COLOR, DISABLED_COLOR, 0))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	return button


# ---------------------------------------------------------------- 진행

func _start_game() -> void:
	game = Game.new()
	game.setup(_data, _parties)
	game.take_events()
	_board_view.game = game
	_board_view.reset_pieces()
	_waiting_for_player = false
	_choosing_path = false
	_my_battles = [0, 0]
	_cards_used = 0
	_recorded = false
	_clear_results()
	_add_result_text("%s 파티: %s" % [game.players[1]["name"], _party_names(1)], PLAYER_TEXT_COLORS[1])
	_add_result_text("먼저 골(분홍 칸)의 메두사를 이기고 들어가면 승리!\n갈림길에서는 갈 길을 직접 고릅니다.", Color.WHITE)
	_refresh()
	_advance()


## 사람이 입력할 차례가 될 때까지 게임을 진행한다.
func _advance() -> void:
	var playing = game
	while playing == game and game.winner < 0:
		await _wait_for_board()
		if playing != game:
			return
		await _banner.play("%d / %d턴" % [min(game.round_number, Game.MAX_ROUNDS), Game.MAX_ROUNDS],
			_turn_title(game.current), PLAYER_TEXT_COLORS[game.current])
		if playing != game:
			return
		if _humans[game.current]:
			if game.begin_turn():
				_waiting_for_player = true
				_refresh()
				return
			_add_result_text("%s: 이번 턴은 쉽니다." % game.players[game.current]["name"], PLAYER_TEXT_COLORS[game.current])
			game.end_turn()
		else:
			_refresh()
			await get_tree().create_timer(AI_DELAY * 0.4).timeout
			if playing != game:
				return
			_add_result_header("AI 차례", PLAYER_TEXT_COLORS[1])
			AI.take_turn(game)
			await _present_events()
			if playing != game:
				return
		_refresh()
	await _wait_for_board()
	if playing != game:
		return
	_waiting_for_player = false
	_show_game_over()
	_play("win" if game.winner == 0 or _is_local() else "lose")
	_refresh()


func _turn_title(index: int) -> String:
	if _is_local():
		return "%s 차례" % game.players[index]["name"]
	return "내 차례" if _humans[index] else "AI 차례"


func _wait_for_board() -> void:
	while _board_view.is_busy():
		await get_tree().process_frame


func _on_roll_pressed() -> void:
	if game.winner >= 0:
		_result_overlay.visible = true
		return
	if not _waiting_for_player:
		return
	_waiting_for_player = false
	_play("click")
	_refresh()
	_clear_results()
	_add_result_header(_turn_title(game.current), PLAYER_TEXT_COLORS[game.current])
	var playing = game
	game.roll_move()
	await _present_events()
	if playing != game:
		return
	_after_my_move()


## 내 이동이 끝났거나 멈췄을 때. 갈림길이면 길 고르기를 보여 주고, 아니면 턴을 넘긴다.
func _after_my_move() -> void:
	if game.awaiting_choice():
		_choosing_path = true
		_refresh()
		await _wait_for_board()
		_show_path_choice()
		return
	_choosing_path = false
	_board_view.highlight = []
	game.end_turn()
	_refresh()
	_advance()


func _show_path_choice() -> void:
	var options: Array = game.pending_choice["options"]
	var fighting: bool = game.choice_kind() == "fight"
	if fighting:
		_board_view.highlight = [int(game.players[game.current]["pos"])]
		_add_result_text("상대 말을 지나칩니다! 싸울까요? (남은 이동 %d칸)" % int(game.pending_choice["steps"]), Color("ff8a6a"))
	else:
		_board_view.highlight = options.duplicate()
		_add_result_text("갈림길! 갈 길을 고르세요. (남은 이동 %d칸)" % int(game.pending_choice["steps"]), Color("ffcf66"))
	_board_view.queue_redraw()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for index in options.size():
		var color := Color("1ba39c")
		if fighting:
			color = Color("c0392b") if index == 0 else Color("5d6d7e")
		var button := _make_button(18, 72, color)
		button.text = game.choice_label(index)
		button.pressed.connect(_on_path_chosen.bind(index))
		row.add_child(button)
	_result_box.add_child(row)
	_trim_results()


func _on_path_chosen(index: int) -> void:
	if not _choosing_path or not game.awaiting_choice():
		return
	_choosing_path = false
	_board_view.highlight = []
	_clear_results()
	_add_result_header(_turn_title(game.current), PLAYER_TEXT_COLORS[game.current])
	if game.choice_kind() == "fight":
		_add_result_text("싸웁니다!" if index == 0 else "그냥 지나갑니다.", Color.WHITE)
	else:
		_add_result_text("%s(으)로 갑니다." % game.choice_label(index), Color.WHITE)
	_play("click")
	var playing = game
	game.choose_path(index)
	_refresh()
	await _present_events()
	if playing != game:
		return
	_after_my_move()


func _on_ability_pressed(slot: String) -> void:
	var me := _viewer()
	if _waiting_for_player and game.use_ability(slot):
		_add_result_text("어빌리티 [%s] 발동! %s" % [
			game.ability_of(me, slot)["name"], game.ability_of(me, slot)["text"]], SLOT_COLORS[slot].lightened(0.4))
		_play("reveal")
		_refresh()
		await _present_events()
		_refresh()


func _on_card_pressed(index: int) -> void:
	if not _waiting_for_player:
		return
	var hand: Array = game.players[game.current]["hand"]
	if index >= hand.size():
		return
	var card: Dictionary = game.cards[hand[index]]
	if game.play_card(index):
		if game.current == 0:
			_cards_used += 1
		_add_result_text("카드 [%s] 사용! %s" % [card["name"], card["text"]], CARD_COLOR.lightened(0.4))
		_play("good")
		_refresh()
		await _present_events()
		_refresh()


# ---------------------------------------------------------------- 결과 패널

## 규칙 엔진의 사건을 꺼내 차례대로 연출한다.
## 주사위는 구르는 모습을 보여 준 뒤 멈추고, 말은 한 칸씩 걷고, 전투는 전투 화면을 띄운다.
## 모든 연출이 끝나야 돌아온다.
func _present_events() -> void:
	var playing = game
	var moves: Array = []
	for event in game.take_events():
		if playing != game:
			return
		if event["kind"] == "pos":
			moves.append(event)
			continue
		if not moves.is_empty():
			_board_view.push_moves(moves)
			moves = []
			await _wait_for_board()
		match event["kind"]:
			"move":
				await _show_move(event)
			"battle":
				await _show_battle(event)
			"fate":
				await _show_fate(event)
	if not moves.is_empty():
		_board_view.push_moves(moves)
		await _wait_for_board()


func _show_move(event: Dictionary) -> void:
	var who := int(event["player"])
	var tail := "→ %d칸" % int(event["total"])
	if event["rolls"].is_empty():
		tail = "%d칸 (고정)" % int(event["total"])
	if int(event["bonus"]) > 0:
		tail += " (속성 +%d)" % int(event["bonus"])
	var row := _dice_row("이동", event["rolls"], "", PLAYER_TEXT_COLORS[who])
	_result_box.add_child(row)
	_trim_results()
	await _roll_row(row, event["rolls"], tail)


func _show_fate(event: Dictionary) -> void:
	var who := int(event["player"])
	var row := _dice_row("판정", event["rolls"], "", PLAYER_TEXT_COLORS[who])
	_result_box.add_child(row)
	_trim_results()
	await _roll_row(row, event["rolls"], event["text"])
	_play("good" if event["text"] == "무사 통과" else "bad")


## 결과 줄의 주사위를 굴린 뒤 끝 글자를 보여 준다.
func _roll_row(row: HBoxContainer, rolls: Array, tail: String) -> void:
	var dice = row.get_meta("dice", null)
	if dice != null:
		_play("dice")
		await dice.roll_to(rolls, 0.55)
	var end: Label = row.get_meta("tail")
	end.text = tail


func _show_battle(event: Dictionary) -> void:
	await _wait_for_board()
	var who := int(event["player"])
	var other := 1 - who
	if str(event.get("target", "")) == "ambush":
		await _battle_overlay.play(event, {
			"attacker_side": "습격 · 몬스터",
			"defender_side": "방어 · %s" % game.players[who]["name"],
			"attacker_color": Color("ff6b6b"),
			"defender_color": PLAYER_TEXT_COLORS[who],
			"winner_text": "막지 못했다... 거점으로",
			"loser_text": "%s 방어 성공!" % game.players[who]["name"],
			"good_for_me": (not event["won"]) if (who == 0 or _is_local()) else event["won"],
			"defender_character": _character_named(str(event["defender"])),
		})
		_add_battle_result(event)
		return
	var against_player: bool = str(event.get("target", "")) == "player"
	var me_attacking := who == 0 or _is_local()
	var info := {
		"attacker_side": "공격 · %s" % game.players[who]["name"],
		"defender_side": "방어 · %s" % (game.players[other]["name"] if against_player else "키퍼"),
		"attacker_color": PLAYER_TEXT_COLORS[who],
		"defender_color": PLAYER_TEXT_COLORS[other] if against_player else Color("ffcf66"),
		"winner_text": "%s 승리!" % game.players[who]["name"],
		"loser_text": "%s 패배... 거점으로" % game.players[who]["name"],
	}
	if me_attacking:
		info["good_for_me"] = event["won"]
	elif against_player:
		info["good_for_me"] = not event["won"]
	else:
		info["good_for_me"] = not event["won"]
	info["attacker_character"] = _character_named(str(event["attacker"]))
	info["defender_character"] = _character_named(str(event["defender"]))
	await _battle_overlay.play(event, info)
	_add_battle_result(event)


## 전투 사건에는 이름만 있으므로 이름으로 캐릭터를 찾는다. 키퍼·몬스터면 빈 사전.
func _character_named(character_name: String) -> Dictionary:
	for character in _data["characters"]:
		if character["name"] == character_name:
			return character
	return {}


func _clear_results() -> void:
	for child in _result_box.get_children():
		child.queue_free()


func _trim_results() -> void:
	var children := _result_box.get_children().filter(func(node): return not node.is_queued_for_deletion())
	while children.size() > MAX_RESULT_BLOCKS + 2:
		children.pop_front().queue_free()


func _add_result_header(text: String, color: Color) -> void:
	var label := _make_label(22, text)
	label.add_theme_color_override("font_color", color)
	_result_box.add_child(label)
	_trim_results()


func _add_result_text(text: String, color: Color) -> void:
	var label := _make_label(20, text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	_result_box.add_child(label)
	_trim_results()


func _dice_row(caption: String, rolls: Array, tail: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var head := _make_label(20, caption)
	head.custom_minimum_size = Vector2(90, 0)
	head.add_theme_color_override("font_color", color)
	row.add_child(head)
	if not rolls.is_empty():
		var dice := DiceView.new()
		dice.die_size = 34.0
		dice.values = rolls
		dice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dice)
		row.set_meta("dice", dice)
	var end := _make_label(22, tail)
	end.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(end)
	row.set_meta("tail", end)
	return row


func _add_battle_result(event: Dictionary) -> void:
	var who := int(event["player"])
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	var title := _make_label(20, "전투! %s vs %s" % [event["attacker"], event["defender"]])
	title.add_theme_color_override("font_color", Color("ffcf66"))
	block.add_child(title)
	var ambushed: bool = str(event.get("target", "")) == "ambush"
	var attack_color: Color = Color(1, 1, 1, 0.8) if ambushed else PLAYER_TEXT_COLORS[who]
	var defense_color: Color = PLAYER_TEXT_COLORS[who] if ambushed else Color(1, 1, 1, 0.8)
	block.add_child(_dice_row("공격", event["attack_rolls"], "= %d" % int(event["attack_total"]), attack_color))
	block.add_child(_dice_row("방어", event["defense_rolls"], "= %d" % int(event["defense_total"]), defense_color))
	var verdict := "%s 승리!" % game.players[who]["name"]
	var verdict_color := Color("7ee081")
	var success: bool = event["won"]
	if ambushed:
		success = not event["won"]
		verdict = "%s 방어 성공!" % game.players[who]["name"]
	if who == 0:
		_my_battles[0 if success else 1] += 1
	elif str(event.get("target", "")) == "player" and not success:
		# 상대가 나를 공격했다가 진 것도 내 전투 승리
		_my_battles[0] += 1
	if not success:
		verdict = "%s 패배... 직전 거점으로" % game.players[who]["name"]
		verdict_color = Color("ff6b6b")
	var verdict_label := _make_label(22, verdict)
	verdict_label.add_theme_color_override("font_color", verdict_color)
	block.add_child(verdict_label)
	_result_box.add_child(block)
	_trim_results()


func _show_game_over() -> void:
	_clear_results()
	var text := "무승부!"
	var color := Color.WHITE
	var outcome := "draw"
	if _is_local():
		if game.winner == 0 or game.winner == 1:
			text = "%s 승리!" % game.players[game.winner]["name"]
			color = PLAYER_TEXT_COLORS[game.winner]
			outcome = "win" if game.winner == 0 else "lose"
	elif game.winner == 0:
		text = "승리! 골에 먼저 들어갔습니다."
		color = Color("7ee081")
		outcome = "win"
	elif game.winner == 1:
		text = "패배... AI가 먼저 들어갔습니다."
		color = Color("ff6b6b")
		outcome = "lose"
	_result_text = text
	var label := _make_label(34, text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	_result_box.add_child(label)

	var reached_goal := false
	if game.winner == 0 or game.winner == 1:
		reached_goal = game.node_of(int(game.players[game.winner]["pos"])).get("type", "") == "goal"
	var subtitle := text
	if not reached_goal:
		subtitle = "%d턴이 끝나 골까지 남은 거리로 판정했습니다." % Game.MAX_ROUNDS
	var details := PackedStringArray([
		"진행한 턴: %d턴" % min(game.round_number, Game.MAX_ROUNDS),
		"골까지 남은 거리: %s %d칸 · %s %d칸" % [game.players[0]["name"], game.distance_of(0), game.players[1]["name"], game.distance_of(1)],
		"%s 파티: %s" % [game.players[0]["name"], _party_names(0)],
		"%s 파티: %s" % [game.players[1]["name"], _party_names(1)],
	])
	if not _is_local():
		details.insert(2, "내 전투: %d승 %d패" % [_my_battles[0], _my_battles[1]])
	details.append_array(_record(outcome))
	var shown_outcome := outcome
	if _is_local() and outcome != "draw":
		shown_outcome = "win"
	_result_overlay.show_result(shown_outcome, subtitle, details)


## 판 결과를 프로필에 기록하고 보상 줄을 돌려준다. 한 판에 한 번만.
func _record(outcome: String) -> PackedStringArray:
	var lines := PackedStringArray()
	if _recorded or not app.has_profile():
		return lines
	_recorded = true
	var reward := Profile.record_match(app.profile, app.eco, _mode, outcome, {"battle_wins": _my_battles[0], "cards": _cards_used})
	app.save()
	lines.append("")
	lines.append("보상: %s  ·  경험치 +%d" % [Kit.reward_line(reward), int(reward["exp"])])
	if _mode == "rank":
		lines.append("트로피 %+d → %d (%s)" % [int(reward["trophies"]), int(app.profile["trophies"]), reward["tier_after"]])
		if str(reward["tier_before"]) != str(reward["tier_after"]):
			lines.append("티어 변경: %s → %s" % [reward["tier_before"], reward["tier_after"]])
	if bool(reward["first_win"]):
		lines.append("오늘 첫 승리 보너스!")
	if int(reward["level_ups"]) > 0:
		lines.append("레벨 업! 플레이어 레벨 %d" % int(app.profile["level"]))
	return lines


func _on_retry_pressed() -> void:
	_play("click")
	if _is_local():
		app.go("match", {"mode": _mode, "parties": _parties, "humans": _humans})
	else:
		app.start_mode(_mode)


func _on_change_party_pressed() -> void:
	_play("click")
	app.go("lobby")


## 나가기. 랭크전에서 도중에 나가면 패배로 기록한다.
func _on_quit_pressed() -> void:
	_play("click")
	if game.winner >= 0:
		app.go("lobby")
		return
	var text := "지금 나가면 이번 판은 기록되지 않아요."
	if _mode == "rank":
		text = "랭크전에서 나가면 패배로 기록되고 트로피가 줄어요."
	app.message("대전 나가기", text, "나가기", _confirm_quit)


func _confirm_quit() -> void:
	if _mode == "rank" and not _recorded:
		_recorded = true
		Profile.record_match(app.profile, app.eco, _mode, "lose", {"battle_wins": _my_battles[0], "cards": _cards_used})
		app.save()
	game = null
	app.go("lobby")


func _party_names(player_index: int) -> String:
	var names: PackedStringArray = []
	for slot in Game.SLOTS:
		names.append(game.char_of(player_index, slot)["name"])
	return " · ".join(names)


# ---------------------------------------------------------------- 표시

func _refresh() -> void:
	if game == null:
		return
	var viewer := _viewer()
	var me: Dictionary = game.players[viewer]
	var first: Dictionary = game.players[0]
	var second: Dictionary = game.players[1]
	var attr_text: String = game.map_attr if game.map_attr != "" else "없음"
	var turn_text := _turn_title(game.current)
	if game.winner == 2:
		turn_text = "무승부"
	elif game.winner >= 0:
		turn_text = "%s 승리!" % game.players[game.winner]["name"]
	_status_label.text = "%d/%d턴 · %s · 맵 속성: %s\n%s(파랑) %d칸%s · %s(주황) %d칸%s" % [
		min(game.round_number, Game.MAX_ROUNDS), Game.MAX_ROUNDS, turn_text, attr_text,
		first["name"], game.distance_of(0), _state_text(first), second["name"], game.distance_of(1), _state_text(second)]

	for slot in Game.SLOTS:
		var button: Button = _ability_buttons[slot]
		var character: Dictionary = game.char_of(viewer, slot)
		var ability: Dictionary = game.ability_of(viewer, slot)
		var is_ready: bool = _waiting_for_player and game.can_use_ability(slot)
		var gauge_text := "[사용 가능]" if is_ready else "%d%%" % int(me["gauge"][slot])
		button.text = "%s %s\n%s %s\n%s" % [
			Game.SLOT_LABELS[slot], character["name"],
			ability.get("name", "-"), gauge_text, ability.get("text", "")]
		button.disabled = not is_ready
		var portrait = _ability_portraits[slot]
		portrait.show_character(character, SLOT_COLORS[slot])

	var hand: Array = me["hand"]
	for index in _card_buttons.size():
		var button: Button = _card_buttons[index]
		if index < hand.size():
			var card: Dictionary = game.cards[hand[index]]
			button.text = "카드: %s\n%s" % [card["name"], card["text"]]
			button.disabled = not (_waiting_for_player and game.can_play_card(index))
		else:
			button.text = "(빈 카드 칸)"
			button.disabled = true

	if game.winner >= 0:
		_roll_button.text = "결과 보기"
		_roll_button.disabled = false
	elif _choosing_path:
		_roll_button.text = "위에서 갈 길을 고르세요"
		_roll_button.disabled = true
	elif _waiting_for_player:
		_roll_button.text = "주사위 굴리기"
		_roll_button.disabled = false
	else:
		_roll_button.text = "AI 차례..." if not _humans[game.current] else "진행 중..."
		_roll_button.disabled = true

	var lines: Array = game.messages.slice(max(0, game.messages.size() - LOG_LINES))
	_log_label.text = "\n".join(PackedStringArray(lines))
	_board_view.queue_redraw()


func _state_text(player: Dictionary) -> String:
	var parts: Array = []
	if player["cursed"]:
		parts.append("저주")
	if int(player["skip"]) > 0:
		parts.append("쉬기")
	if player["charm"]:
		parts.append("부적")
	if parts.is_empty():
		return ""
	return " (" + ", ".join(PackedStringArray(parts)) + ")"
