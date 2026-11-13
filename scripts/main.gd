extends Control
## 2단계(규칙 프로토타입) 화면. 사람 대 AI로 한 판을 끝까지 할 수 있다.
## 그림은 아직 없고 색 칸과 글자만 쓴다. 규칙은 scripts/rules/game.gd에 있다.

const Game := preload("res://scripts/rules/game.gd")
const AI := preload("res://scripts/rules/ai.gd")
const GameData := preload("res://scripts/game_data.gd")
const BoardView := preload("res://scripts/ui/board_view.gd")

## 프로토타입 고정 파티. 둘 다 소환 포인트 6이다. 파티 고르기 화면은 6단계에서 만든다.
const PARTIES := [
	{"name": "나", "attack": "lubu", "defense": "athena", "support": "choichiwon"},
	{"name": "AI", "attack": "machao", "defense": "zeus", "support": "houdini"},
]
const AI_DELAY := 0.8
const LOG_LINES := 9

var game
var _data: Dictionary = {}
var _waiting_for_player := false

var _status_label: Label
var _board_view: Control
var _ability_buttons: Dictionary = {}
var _card_buttons: Array = []
var _roll_button: Button
var _restart_button: Button
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
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	_status_label = _make_label(24)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status_label)

	_board_view = BoardView.new()
	_board_view.custom_minimum_size = Vector2(0, 520)
	_board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_board_view)

	column.add_child(_make_label(20, "어빌리티 (게이지 100%에서 사용, 턴당 1회)"))
	var ability_row := HBoxContainer.new()
	ability_row.add_theme_constant_override("separation", 8)
	column.add_child(ability_row)
	for slot in Game.SLOTS:
		var button := _make_button(18, 92)
		button.pressed.connect(_on_ability_pressed.bind(slot))
		ability_row.add_child(button)
		_ability_buttons[slot] = button

	column.add_child(_make_label(20, "아이템 카드 (턴당 1장)"))
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 8)
	column.add_child(card_row)
	for index in Game.HAND_LIMIT:
		var button := _make_button(18, 92)
		button.pressed.connect(_on_card_pressed.bind(index))
		card_row.add_child(button)
		_card_buttons.append(button)

	_roll_button = _make_button(32, 96)
	_roll_button.text = "주사위 굴리기"
	_roll_button.pressed.connect(_on_roll_pressed)
	column.add_child(_roll_button)

	_restart_button = _make_button(28, 80)
	_restart_button.text = "새 게임"
	_restart_button.pressed.connect(_start_game)
	column.add_child(_restart_button)

	_log_label = _make_label(18)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.custom_minimum_size = Vector2(0, 250)
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_log_label.clip_text = true
	column.add_child(_log_label)


func _make_label(font_size: int, text: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_button(font_size: int, height: float) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", font_size)
	return button


# ---------------------------------------------------------------- 진행

func _start_game() -> void:
	game = Game.new()
	game.setup(_data, PARTIES)
	_board_view.game = game
	_waiting_for_player = false
	_advance()


## 사람이 입력할 차례가 될 때까지 게임을 진행한다.
func _advance() -> void:
	var playing = game
	while playing == game and game.winner < 0:
		if game.current == 0:
			if game.begin_turn():
				_waiting_for_player = true
				_refresh()
				return
			game.end_turn()
		else:
			_refresh()
			await get_tree().create_timer(AI_DELAY).timeout
			if playing != game:
				return
			AI.take_turn(game)
		_refresh()
	_waiting_for_player = false
	_refresh()


func _on_roll_pressed() -> void:
	if not _waiting_for_player:
		return
	_waiting_for_player = false
	game.roll_move()
	game.end_turn()
	_refresh()
	_advance()


func _on_ability_pressed(slot: String) -> void:
	if _waiting_for_player and game.use_ability(slot):
		_refresh()


func _on_card_pressed(index: int) -> void:
	if _waiting_for_player and game.play_card(index):
		_refresh()


# ---------------------------------------------------------------- 표시

func _refresh() -> void:
	var me: Dictionary = game.players[0]
	var ai: Dictionary = game.players[1]
	var attr_text: String = game.map_attr if game.map_attr != "" else "없음"
	var turn_text := "게임 종료"
	if game.winner == 2:
		turn_text = "무승부"
	elif game.winner >= 0:
		turn_text = "%s 승리!" % game.players[game.winner]["name"]
	elif _waiting_for_player:
		turn_text = "내 차례"
	else:
		turn_text = "AI 차례"
	_status_label.text = "%d/%d턴 · %s · 맵 속성: %s\n나(파랑) %d번 칸%s  ·  AI(주황) %d번 칸%s" % [
		min(game.round_number, Game.MAX_ROUNDS), Game.MAX_ROUNDS, turn_text, attr_text,
		int(me["pos"]), _state_text(me), int(ai["pos"]), _state_text(ai)]

	for slot in Game.SLOTS:
		var button: Button = _ability_buttons[slot]
		var character: Dictionary = game.char_of(0, slot)
		var ability: Dictionary = game.ability_of(0, slot)
		button.text = "%s %s\n[%s] %d%%\n%s" % [
			Game.SLOT_LABELS[slot], character["name"],
			ability.get("name", "-"), int(me["gauge"][slot]), ability.get("text", "")]
		button.disabled = not (_waiting_for_player and game.can_use_ability(slot))

	var hand: Array = me["hand"]
	for index in _card_buttons.size():
		var button: Button = _card_buttons[index]
		if index < hand.size():
			var card: Dictionary = game.cards[hand[index]]
			button.text = "%s\n%s" % [card["name"], card["text"]]
			button.disabled = not (_waiting_for_player and game.can_play_card(index))
		else:
			button.text = "(빈 칸)"
			button.disabled = true

	_roll_button.disabled = not _waiting_for_player
	_restart_button.visible = game.winner >= 0

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
