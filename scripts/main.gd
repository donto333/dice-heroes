extends Control
## 2단계(규칙 프로토타입) 화면. 사람 대 AI로 한 판을 끝까지 할 수 있다.
## 그림은 아직 없고 색 칸과 글자만 쓴다. 규칙은 scripts/rules/game.gd에 있다.
##
## 화면 위에서부터: 상태 줄, 보드, 결과 패널(주사위·전투), 어빌리티, 카드, 굴리기 버튼, 진행 기록.

const Game := preload("res://scripts/rules/game.gd")
const AI := preload("res://scripts/rules/ai.gd")
const GameData := preload("res://scripts/game_data.gd")
const BoardView := preload("res://scripts/ui/board_view.gd")
const DiceView := preload("res://scripts/ui/dice_view.gd")

## 프로토타입 고정 파티. 둘 다 소환 포인트 6이다. 파티 고르기 화면은 6단계에서 만든다.
const PARTIES := [
	{"name": "나", "attack": "lubu", "defense": "athena", "support": "choichiwon"},
	{"name": "AI", "attack": "machao", "defense": "zeus", "support": "houdini"},
]
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

var _status_label: Label
var _board_view: Control
var _result_box: VBoxContainer
var _ability_buttons: Dictionary = {}
var _card_buttons: Array = []
var _roll_button: Button
var _log_label: Label


func _ready() -> void:
	_data = GameData.load_all()
	_build_ui()
	_start_game()


# ---------------------------------------------------------------- 화면 구성

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("1b1f3b")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	_status_label = _make_label(24)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status_label)

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
		var button := _make_button(18, 100, SLOT_COLORS[slot])
		button.pressed.connect(_on_ability_pressed.bind(slot))
		ability_row.add_child(button)
		_ability_buttons[slot] = button

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


func _make_label(font_size: int, text: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


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
	game.setup(_data, PARTIES)
	game.take_events()
	_board_view.game = game
	_board_view.reset_pieces()
	_waiting_for_player = false
	_clear_results()
	_add_result_text("주사위 굴리기를 눌러 시작하세요.\n먼저 40번 칸의 메두사를 이기고 들어가면 승리!", Color.WHITE)
	_advance()


## 사람이 입력할 차례가 될 때까지 게임을 진행한다.
func _advance() -> void:
	var playing = game
	while playing == game and game.winner < 0:
		await _wait_for_board()
		if playing != game:
			return
		if game.current == 0:
			if game.begin_turn():
				_waiting_for_player = true
				_refresh()
				return
			_add_result_text("나: 이번 턴은 쉽니다.", PLAYER_TEXT_COLORS[0])
			game.end_turn()
		else:
			_refresh()
			await get_tree().create_timer(AI_DELAY).timeout
			if playing != game:
				return
			_add_result_header("AI 차례", PLAYER_TEXT_COLORS[1])
			AI.take_turn(game)
			_consume_events()
		_refresh()
	await _wait_for_board()
	_waiting_for_player = false
	_show_game_over()
	_refresh()


func _wait_for_board() -> void:
	while _board_view.is_busy():
		await get_tree().process_frame


func _on_roll_pressed() -> void:
	if game.winner >= 0:
		_start_game()
		return
	if not _waiting_for_player:
		return
	_waiting_for_player = false
	_clear_results()
	_add_result_header("내 차례", PLAYER_TEXT_COLORS[0])
	game.roll_move()
	_consume_events()
	game.end_turn()
	_refresh()
	_advance()


func _on_ability_pressed(slot: String) -> void:
	if _waiting_for_player and game.use_ability(slot):
		_add_result_text("어빌리티 [%s] 발동! %s" % [
			game.ability_of(0, slot)["name"], game.ability_of(0, slot)["text"]], SLOT_COLORS[slot].lightened(0.4))
		_consume_events()
		_refresh()


func _on_card_pressed(index: int) -> void:
	if not _waiting_for_player:
		return
	var hand: Array = game.players[0]["hand"]
	if index >= hand.size():
		return
	var card: Dictionary = game.cards[hand[index]]
	if game.play_card(index):
		_add_result_text("카드 [%s] 사용! %s" % [card["name"], card["text"]], CARD_COLOR.lightened(0.4))
		_consume_events()
		_refresh()


# ---------------------------------------------------------------- 결과 패널

## 규칙 엔진의 사건을 꺼내, 말 이동은 보드로 보내고 주사위·전투는 결과 패널에 그린다.
func _consume_events() -> void:
	var moves: Array = []
	for event in game.take_events():
		match event["kind"]:
			"pos":
				moves.append(event)
			"move":
				_add_move_result(event)
			"battle":
				_add_battle_result(event)
			"fate":
				_add_fate_result(event)
	_board_view.push_moves(moves)


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
	var end := _make_label(22, tail)
	end.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(end)
	return row


func _add_move_result(event: Dictionary) -> void:
	var who := int(event["player"])
	var tail := "→ %d칸" % int(event["total"])
	if event["rolls"].is_empty():
		tail = "%d칸 (고정)" % int(event["total"])
	if int(event["bonus"]) > 0:
		tail += " (속성 +%d)" % int(event["bonus"])
	_result_box.add_child(_dice_row("이동", event["rolls"], tail, PLAYER_TEXT_COLORS[who]))
	_trim_results()


func _add_battle_result(event: Dictionary) -> void:
	var who := int(event["player"])
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	var title := _make_label(20, "전투! %s vs %s" % [event["attacker"], event["defender"]])
	title.add_theme_color_override("font_color", Color("ffcf66"))
	block.add_child(title)
	block.add_child(_dice_row("공격", event["attack_rolls"], "= %d" % int(event["attack_total"]), PLAYER_TEXT_COLORS[who]))
	block.add_child(_dice_row("방어", event["defense_rolls"], "= %d" % int(event["defense_total"]), Color(1, 1, 1, 0.8)))
	var verdict := "%s 승리!" % game.players[who]["name"]
	var verdict_color := Color("7ee081")
	if not event["won"]:
		verdict = "%s 패배... 직전 거점으로" % game.players[who]["name"]
		verdict_color = Color("ff6b6b")
	var verdict_label := _make_label(22, verdict)
	verdict_label.add_theme_color_override("font_color", verdict_color)
	block.add_child(verdict_label)
	_result_box.add_child(block)
	_trim_results()


func _add_fate_result(event: Dictionary) -> void:
	var who := int(event["player"])
	_result_box.add_child(_dice_row("판정", event["rolls"], event["text"], PLAYER_TEXT_COLORS[who]))
	_trim_results()


func _show_game_over() -> void:
	_clear_results()
	var text := "무승부!"
	var color := Color.WHITE
	if game.winner == 0:
		text = "승리! 골에 먼저 들어갔습니다."
		color = Color("7ee081")
	elif game.winner == 1:
		text = "패배... AI가 먼저 들어갔습니다."
		color = Color("ff6b6b")
	var label := _make_label(34, text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	_result_box.add_child(label)


# ---------------------------------------------------------------- 표시

func _refresh() -> void:
	var me: Dictionary = game.players[0]
	var ai: Dictionary = game.players[1]
	var attr_text: String = game.map_attr if game.map_attr != "" else "없음"
	var turn_text := "AI 차례"
	if game.winner == 2:
		turn_text = "무승부"
	elif game.winner >= 0:
		turn_text = "%s 승리!" % game.players[game.winner]["name"]
	elif _waiting_for_player:
		turn_text = "내 차례"
	_status_label.text = "%d/%d턴 · %s · 맵 속성: %s\n나(파랑) %d번 칸%s  ·  AI(주황) %d번 칸%s" % [
		min(game.round_number, Game.MAX_ROUNDS), Game.MAX_ROUNDS, turn_text, attr_text,
		int(me["pos"]), _state_text(me), int(ai["pos"]), _state_text(ai)]

	for slot in Game.SLOTS:
		var button: Button = _ability_buttons[slot]
		var character: Dictionary = game.char_of(0, slot)
		var ability: Dictionary = game.ability_of(0, slot)
		var is_ready: bool = _waiting_for_player and game.can_use_ability(slot)
		var gauge_text := "[사용 가능]" if is_ready else "%d%%" % int(me["gauge"][slot])
		button.text = "%s %s\n%s %s\n%s" % [
			Game.SLOT_LABELS[slot], character["name"],
			ability.get("name", "-"), gauge_text, ability.get("text", "")]
		button.disabled = not is_ready

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
		_roll_button.text = "새 게임"
		_roll_button.disabled = false
	elif _waiting_for_player:
		_roll_button.text = "주사위 굴리기"
		_roll_button.disabled = false
	else:
		_roll_button.text = "AI가 진행 중..."
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
