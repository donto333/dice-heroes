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
const BigDice := preload("res://scripts/ui/big_dice.gd")
const AimBar := preload("res://scripts/ui/aim_bar.gd")
const Cutin := preload("res://scripts/ui/cutin.gd")
## 턴 제한이 이만큼 남으면 턴 배너에 남은 턴을 보여 준다.
const LAST_TURNS_WARNING := 5
const VersusOverlay := preload("res://scripts/ui/versus_overlay.gd")

const AI_DELAY := 1.0
const LOG_LINES := 4
const MAX_RESULT_BLOCKS := 3

const SLOT_COLORS := {"attack": Color("b8352a"), "defense": Color("6f43a6"), "support": Color("27a35a")}
const CARD_COLOR := Color("a6781a")
const ROLL_COLOR := Color("2fb457")
const DISABLED_COLOR := Color("6f86a8")
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
var _ability_gauges: Dictionary = {}
var app
var _mode := "ai"
var _parties: Array = []
var _humans: Array = [true, false]
var _map_index := 0
var _stage_id := ""
var _player_cards: Array = []
var _hint_bubble: Control
var _big_dice: Control
var _result_scroll: ScrollContainer
var _speed_button: Button
var _aim_bar: Control
var _cutin: Control
## 상대가 이번 판에 쓰는 주사위 스킨 번호(보여 주기용, 판마다 바뀜)
var _rival_skin := 0
var _roll_down_at := 0.0
var _auto_button: Button
## 자동 진행: 켜면 내 차례도 AI가 대신 둔다(한 기기 2인 대전에서는 쓰지 않는다).
var _auto := false
var _versus: Control
var _reward_scale := 1.0
var _last_reward: Dictionary = {}
var _next_stage := ""
var _start_distance := 1
var _cards_used := 0
var _recorded := false
var _result_text := ""
## 이번 판 보상 줄. 결과 화면을 다시 열어도 같은 글을 보여 준다.
var _reward_lines := PackedStringArray()
var _banner: Control
var _result_overlay: Control
## 이번 판에서 내 전투 기록. [이긴 수, 진 수]
var _my_battles := [0, 0]
## 내 영웅 자리별 전투 승리 수 (결과 화면의 MVP)
var _slot_wins := {"attack": 0, "defense": 0, "support": 0}
var _abilities_used := 0
const SLOT_NAMES := {"attack": "ATTACK", "defense": "DEFENSE", "support": "SUPPORT"}
## 굴리기 버튼을 이만큼(초) 누르고 있으면 세기 막대가 나온다.
const HOLD_TO_AIM := 0.22
## 대전 중 한마디. AI는 전투가 끝난 뒤 가끔 대꾸한다.
const EMOTES := ["좋아요!", "ㅋㅋㅋ", "으악!", "잘했어요!", "봐주세요...", "가자!"]
const AI_HAPPY := ["ㅋㅋㅋ", "좋아요!", "가자!"]
const AI_SAD := ["으악!", "봐주세요...", "잘했어요!"]
var _board_area: Control
var _emote_panel: Control
var _fx_rng := RandomNumberGenerator.new()
var _best_roll := 0


func setup(main_app, params: Dictionary) -> void:
	app = main_app
	_data = app.data
	var boards: Array = app.data.get("boards", [])
	var map_index := int(params.get("map", 0))
	if map_index > 0 and map_index < boards.size():
		_data = app.data.duplicate()
		_data["board"] = boards[map_index]
	_map_index = map_index
	_mode = str(params.get("mode", "ai"))
	_stage_id = str(params.get("stage", ""))
	_reward_scale = float(params.get("reward_scale", 1.0))
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
	background.color = Color("1c5cb8")
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
	_status_label = _make_label(20)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_row.add_child(_status_label)
	_auto_button = Kit.button("자동 꺼짐", Color("6f9bd6"), 20, 56)
	_auto_button.custom_minimum_size = Vector2(110, 56)
	_auto_button.pressed.connect(_on_auto_pressed)
	status_row.add_child(_auto_button)
	_speed_button = Kit.button("", Color("27a35a"), 20, 56)
	_speed_button.custom_minimum_size = Vector2(110, 56)
	_speed_button.pressed.connect(_on_speed_pressed)
	status_row.add_child(_speed_button)
	_apply_speed()
	var quit_button := Kit.button("나가기", Color("e0532b"), 20, 56)
	quit_button.custom_minimum_size = Vector2(110, 56)
	quit_button.pressed.connect(_on_quit_pressed)
	status_row.add_child(quit_button)

	# 모두의 마블처럼 판이 화면 대부분을 차지하고,
	# 플레이어 정보판은 판 모서리(상대 왼쪽 위, 나 왼쪽 아래), 큰 주사위 버튼은 오른쪽 아래에 얹는다.
	var board_area := Control.new()
	board_area.custom_minimum_size = Vector2(0, 420)
	board_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_area.size_flags_stretch_ratio = 4.0
	column.add_child(board_area)
	_board_view = BoardView.new()
	_board_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_view.pad_top = 100.0
	_board_view.pad_bottom = 110.0
	_board_view.pad_left = 112.0
	board_area.add_child(_board_view)
	for index in 2:
		var card := _player_card(index)
		board_area.add_child(card)
		card.anchor_left = 0.0
		card.anchor_right = 0.56
		if index == 1:
			card.anchor_top = 0.0
			card.anchor_bottom = 0.0
			card.offset_top = 8
			card.offset_bottom = 92
		else:
			card.anchor_top = 1.0
			card.anchor_bottom = 1.0
			card.offset_top = -92
			card.offset_bottom = -8
		card.offset_left = 8
		card.offset_right = 0
		_ignore_mouse(card)

	_big_dice = BigDice.new()
	board_area.add_child(_big_dice)
	_board_area = board_area
	_build_emotes(board_area)

	_roll_button = _make_round_button()
	# 짧게 누르면 그냥 굴리고, 꾹 누르면 세기 막대가 나와 놓는 자리로 낮게·높게를 노린다(주사위 컨트롤).
	_roll_button.button_down.connect(_on_roll_down)
	_roll_button.button_up.connect(_on_roll_up)
	_aim_bar = AimBar.new()
	board_area.add_child(_aim_bar)
	_aim_bar.anchor_left = 1.0
	_aim_bar.anchor_right = 1.0
	_aim_bar.anchor_top = 1.0
	_aim_bar.anchor_bottom = 1.0
	_aim_bar.offset_left = -246
	_aim_bar.offset_right = -16
	_aim_bar.offset_top = -250
	_aim_bar.offset_bottom = -186
	board_area.add_child(_roll_button)
	_roll_button.anchor_left = 1.0
	_roll_button.anchor_right = 1.0
	_roll_button.anchor_top = 1.0
	_roll_button.anchor_bottom = 1.0
	_roll_button.offset_left = -172
	_roll_button.offset_right = -12
	_roll_button.offset_top = -172
	_roll_button.offset_bottom = -12

	var result_panel := PanelContainer.new()
	# 기록 칸은 높이를 고정한다. 내용이 넘치면 안에서 스크롤되어 판이 줄어들지 않는다.
	result_panel.custom_minimum_size = Vector2(0, 168)
	result_panel.add_theme_stylebox_override("panel", _box(Color("2a8be6"), Color("8fd0ff"), 2))
	column.add_child(result_panel)
	_result_scroll = ScrollContainer.new()
	_result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	result_panel.add_child(_result_scroll)
	_result_box = VBoxContainer.new()
	_result_box.add_theme_constant_override("separation", 6)
	_result_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_scroll.add_child(_result_box)

	var ability_row := HBoxContainer.new()
	ability_row.add_theme_constant_override("separation", 8)
	column.add_child(ability_row)
	for slot in Game.SLOTS:
		var button := _make_button(16, 142, SLOT_COLORS[slot])
		button.pressed.connect(_on_ability_pressed.bind(slot))
		# 쓸 수 있을 때: 금색 테두리 / 아직 못 쓸 때: 어두운 자리 색(글자는 잘 보이게)
		var ready_style := _chunky(_box(SLOT_COLORS[slot], Color("ffcf4d"), 4), 8)
		var off_style := _chunky(_box(SLOT_COLORS[slot].darkened(0.6), SLOT_COLORS[slot].darkened(0.75), 3), 5)
		# 아래쪽에 게이지 막대가 들어갈 자리를 비워 둔다.
		ready_style.content_margin_bottom = 26
		off_style.content_margin_bottom = 26
		button.add_theme_stylebox_override("normal", ready_style)
		button.add_theme_stylebox_override("disabled", off_style)
		button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.72))
		var gauge := Kit.bar(0.0, Color("ffcf4d"), 10)
		gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(gauge)
		gauge.anchor_left = 0.0
		gauge.anchor_right = 1.0
		gauge.anchor_top = 1.0
		gauge.anchor_bottom = 1.0
		gauge.offset_left = ABILITY_PORTRAIT_WIDTH + 14
		gauge.offset_right = -10
		gauge.offset_top = -24
		gauge.offset_bottom = -12
		_ability_gauges[slot] = gauge
		ability_row.add_child(button)
		_ability_buttons[slot] = button
		_ability_portraits[slot] = _add_side_portrait(button)

	# 아이템 카드는 판 왼쪽에 카드 모양으로 세워 둔다. 누르면 설명 창이 뜨고 거기서 쓴다.
	var card_column := VBoxContainer.new()
	card_column.add_theme_constant_override("separation", 8)
	card_column.alignment = BoxContainer.ALIGNMENT_CENTER
	board_area.add_child(card_column)
	card_column.anchor_left = 0.0
	card_column.anchor_right = 0.0
	card_column.anchor_top = 0.0
	card_column.anchor_bottom = 1.0
	card_column.offset_left = 8
	card_column.offset_right = 108
	card_column.offset_top = 100
	card_column.offset_bottom = -100
	card_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in Game.HAND_LIMIT:
		var button := _make_card_button()
		button.pressed.connect(_on_card_pressed.bind(index))
		card_column.add_child(button)
		_card_buttons.append(button)


	_log_label = _make_label(17)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 진행 기록은 두세 줄만. 남는 자리는 모두 보드에 준다.
	_log_label.custom_minimum_size = Vector2(0, 60)
	_log_label.size_flags_vertical = Control.SIZE_SHRINK_END
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
	_cutin = Cutin.new()
	add_child(_cutin)
	_versus = VersusOverlay.new()
	add_child(_versus)


## 플레이어 정보판 하나. _player_cards[index]에 부품을 담아 _refresh에서 고친다.
func _player_card(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var face := Portrait.new()
	face.custom_minimum_size = Vector2(64, 64)
	face.border_width = 2.0
	row.add_child(face)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_label := _make_label(18)
	name_label.add_theme_color_override("font_color", PLAYER_TEXT_COLORS[index])
	name_label.clip_text = true
	info.add_child(name_label)
	var bar := Kit.bar(0.0, PLAYER_TEXT_COLORS[index], 12)
	info.add_child(bar)
	var detail := _make_label(15)
	detail.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	detail.clip_text = true
	info.add_child(detail)
	_player_cards.append({"panel": panel, "face": face, "name": name_label, "bar": bar, "detail": detail})
	return panel


func _refresh_player_cards() -> void:
	for index in _player_cards.size():
		var parts: Dictionary = _player_cards[index]
		var player: Dictionary = game.players[index]
		var leader: Dictionary = game.char_of(index, "attack")
		parts["face"].show_character(leader, PLAYER_TEXT_COLORS[index])
		parts["name"].text = str(player["name"])
		var total := float(max(_start_distance, 1))
		parts["bar"].value = clampf(1.0 - float(game.distance_of(index)) / total, 0.0, 1.0)
		var flags: PackedStringArray = []
		if bool(player.get("cursed", false)):
			flags.append("저주")
		if int(player.get("skip", 0)) > 0:
			flags.append("쉬기")
		if bool(player.get("charm", false)):
			flags.append("부적")
		parts["detail"].text = "골까지 %d칸 · 카드 %d%s" % [game.distance_of(index), player["hand"].size(), ("  " + " ".join(flags)) if not flags.is_empty() else ""]
		var current: bool = game.current == index and game.winner < 0
		var edge: Color = PLAYER_TEXT_COLORS[index] if current else Color("8fd0ff")
		parts["panel"].add_theme_stylebox_override("panel", _box(Color("164c9e") if current else Color("2a8be6"), edge, 3 if current else 1))


## 칸 효과를 보드 위에 크게 띄운다. 좋은 일은 금색, 나쁜 일은 붉은색.
## 어빌리티·카드를 썼을 때: 쓴 사람의 말풍선과 가운데 알림. 내가 쓴 것은 말풍선만(이미 눌러서 알고 있으니 빠르게).
func _show_used(event: Dictionary, shout: String, title: String) -> void:
	var who := int(event["player"])
	_say(who, shout)
	if _humans[who]:
		return
	await _show_tile({"tile": "", "good": false, "text": "%s\n%s" % [title, event.get("text", "")], "small": true})


func _show_tile(event: Dictionary) -> void:
	# 결과 창이 떠 있으면 칸 알림을 띄우지 않는다(결과 창을 가리지 않게).
	if _result_overlay != null and _result_overlay.visible:
		return
	var good := bool(event.get("good", true))
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color := Color("ffcf4d") if good else Color("ff6b6b")
	panel.add_theme_stylebox_override("panel", _box(Color(0.04, 0.05, 0.12, 0.92), color, 4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var icon_name := str(event.get("tile", ""))
	if icon_name == "attr":
		icon_name = "attr_hero"
	var icon_path := "res://assets/icons/%s.png" % icon_name
	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(72, 72)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
	var text := _make_label(24 if bool(event.get("small", false)) else 34, str(event.get("text", "")))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if bool(event.get("small", false)):
		# 긴 설명은 여러 줄로 감는다.
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(480, 0)
	text.add_theme_color_override("font_color", color)
	text.add_theme_constant_override("outline_size", 8)
	text.add_theme_color_override("font_outline_color", Color.BLACK)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(text)
	add_child(panel)
	await get_tree().process_frame
	var board_rect := _board_view.get_global_rect()
	panel.size = panel.get_combined_minimum_size()
	panel.position = board_rect.get_center() - panel.size / 2.0 - global_position
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.6, 0.6)
	_play("good" if good else "bad")
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22)
	tween.tween_interval(0.75)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, 0.25)
	await tween.finished
	panel.queue_free()


# ---------------------------------------------------------------- 첫 판 안내

## 내 차례가 시작될 때 처음 한 번씩 알려 줄 것들.
func _turn_hints() -> void:
	if not _humans[game.current]:
		return
	if _hint("roll", "주사위 굴리기를 누르면 ATTACK 영웅의 이동 주사위만큼 걸어가요. 꾹 누르면 세기 막대가 나와서 낮게·높게를 노릴 수 있어요. 파란 테두리 초상화가 내 말이에요. 먼저 골(분홍 칸)의 수호자를 이기면 승리!"):
		return
	if not game.players[game.current]["hand"].is_empty() and _hint("card", "아이템 카드는 주사위를 굴리기 전에 눌러서 써요. 손에는 3장까지 들 수 있어요."):
		return
	for slot in Game.SLOTS:
		if game.can_use_ability(slot):
			_hint("ability", "어빌리티 게이지가 찼어요! 노란 테두리 버튼을 누르면 쓸 수 있어요. 한 턴에 하나만 쓸 수 있어요.")
			return


## 처음 보는 상황이면 말풍선을 띄우고 true. 이미 본 안내면 false.
func _hint(key: String, text: String) -> bool:
	if not app.has_profile():
		return false
	if not app.profile.has("tutorial"):
		app.profile["tutorial"] = {}
	if bool(app.profile["tutorial"].get(key, false)):
		return false
	app.profile["tutorial"][key] = true
	app.save()
	if _hint_bubble != null and is_instance_valid(_hint_bubble):
		_hint_bubble.queue_free()
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", _box(Color(0.1, 0.08, 0.02, 0.95), Color("ffcf4d"), 3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bubble.add_child(row)
	var label := _make_label(20, text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(420, 0)
	row.add_child(label)
	var ok := Kit.button("알겠어요", Color("f39a1c"), 20, 60)
	ok.custom_minimum_size = Vector2(130, 60)
	ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func(): bubble.queue_free())
	row.add_child(ok)
	add_child(bubble)
	bubble.anchor_left = 0.0
	bubble.anchor_right = 1.0
	# 판을 가리지 않게 아래쪽 결과 칸 자리에 띄운다.
	bubble.anchor_top = 0.74
	bubble.anchor_bottom = 0.74
	bubble.offset_left = 20
	bubble.offset_right = -20
	bubble.offset_top = 0
	_hint_bubble = bubble
	# 그냥 두어도 잠시 뒤 사라진다.
	get_tree().create_timer(12.0).timeout.connect(_close_hint_if.bind(bubble.get_instance_id()))
	return true


func _close_hint() -> void:
	if _hint_bubble != null and is_instance_valid(_hint_bubble):
		_hint_bubble.queue_free()
	_hint_bubble = null


## 이미 닫힌(지워진) 말풍선일 수 있으므로 번호로 견준다.
func _close_hint_if(bubble_id: int) -> void:
	if _hint_bubble != null and is_instance_valid(_hint_bubble) and _hint_bubble.get_instance_id() == bubble_id:
		_close_hint()


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
## 굴리는 쪽의 주사위 스킨. 나는 장착한 스킨, 상대(AI·친구)는 이번 판에 정해진 스킨.
func _dice_skin_of(who: int) -> Dictionary:
	if who == 0 and app.has_profile():
		return Profile.current_dice_skin(app.profile, app.eco)
	var skins: Array = app.eco.get("dice_skins", [])
	if skins.is_empty():
		return {}
	return skins[_rival_skin % skins.size()]


# ---------------------------------------------------------------- 자동 진행·진동

func _on_auto_pressed() -> void:
	if _is_local() or game == null or game.winner >= 0:
		return
	_auto = not _auto
	_play("click")
	_auto_button.text = "자동 켜짐" if _auto else "자동 꺼짐"
	Kit.paint(_auto_button, Color("f39a1c") if _auto else Color("6f9bd6"))
	# 내 차례에서 기다리던 중에 켰으면 이번 턴부터 바로 대신 둔다.
	if _auto and _waiting_for_player and not _choosing_path:
		_waiting_for_player = false
		_close_hint()
		_clear_results()
		_add_result_header("자동 진행", PLAYER_TEXT_COLORS[game.current])
		var playing = game
		var slot := AI.pick_ability(game)
		if slot != "":
			game.use_ability(slot)
		var card_index := AI.pick_card(game)
		if card_index >= 0:
			game.play_card(card_index)
		game.roll_move("high")
		var guard := 0
		while game.awaiting_choice() and guard < 10:
			game.choose_path(AI.choose(game))
			guard += 1
		game.end_turn()
		_refresh()
		await _present_events()
		if playing != game:
			return
		_refresh()
		_advance()


## 내 차례가 오면 짧게 진동한다(설정에서 끌 수 있다). 진동이 없는 기기에서는 아무 일도 없다.
func _buzz() -> void:
	if app.has_profile() and bool(app.profile["settings"].get("vibrate", true)) and not _is_local():
		Input.vibrate_handheld(40)


# ---------------------------------------------------------------- 빠르기

## 대전 연출 빠르기(1배·2배). 설정에 저장되고, 대전 화면을 나가면 1배로 돌아간다.
func _fast() -> bool:
	return app.has_profile() and bool(app.profile["settings"].get("fast", false))


func _apply_speed() -> void:
	Engine.time_scale = 2.0 if _fast() else 1.0
	_speed_button.text = "빠르기 ×2" if _fast() else "빠르기 ×1"
	Kit.paint(_speed_button, Color("f39a1c") if _fast() else Color("27a35a"))


func _on_speed_pressed() -> void:
	if not app.has_profile():
		return
	app.profile["settings"]["fast"] = not _fast()
	app.save()
	_play("click")
	_apply_speed()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# ---------------------------------------------------------------- 한마디 말풍선

## 판 오른쪽 가운데의 '말' 버튼과, 누르면 펼쳐지는 한마디 목록.
func _build_emotes(board_area: Control) -> void:
	var toggle := Kit.round_shortcut("한마디", "start", Color("7d4fc0"))
	toggle.custom_minimum_size = Vector2(76, 76)
	board_area.add_child(toggle)
	toggle.anchor_left = 1.0
	toggle.anchor_right = 1.0
	toggle.anchor_top = 0.5
	toggle.anchor_bottom = 0.5
	toggle.offset_left = -88
	toggle.offset_right = -12
	toggle.offset_top = -38
	toggle.offset_bottom = 38
	toggle.pressed.connect(_toggle_emotes)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.05, 0.06, 0.14, 0.92), Color("7d4fc0"), 3))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(grid)
	for text in EMOTES:
		var button := Kit.button(text, Color("5a3d99"), 20, 56)
		button.custom_minimum_size = Vector2(150, 56)
		button.pressed.connect(_on_emote.bind(text))
		grid.add_child(button)
	board_area.add_child(panel)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -430
	panel.offset_right = -98
	panel.offset_top = -110
	panel.offset_bottom = 110
	panel.visible = false
	_emote_panel = panel


func _toggle_emotes() -> void:
	_play("click")
	_emote_panel.visible = not _emote_panel.visible


func _on_emote(text: String) -> void:
	_emote_panel.visible = false
	_play("click")
	_say(_viewer(), text)


## 플레이어 정보판 옆에 잠깐 뜨는 말풍선. index 0은 아래(나), 1은 위(상대).
func _say(index: int, text: String) -> void:
	if _board_area == null or game == null:
		return
	var bubble := _make_label(26, text)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_theme_color_override("font_color", Color("1c5cb8"))
	var style := _box(Color.WHITE, PLAYER_TEXT_COLORS[index], 4)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(12)
	bubble.add_theme_stylebox_override("normal", style)
	_board_area.add_child(bubble)
	bubble.position = Vector2(118, 100 if index == 1 else _board_area.size.y - 160)
	bubble.pivot_offset = Vector2(0, 30)
	bubble.scale = Vector2(0.3, 0.3)
	var tween := bubble.create_tween()
	tween.tween_property(bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.7)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tween.tween_callback(bubble.queue_free)


## 전투가 끝난 뒤 AI가 가끔 한마디 한다. happy: AI에게 좋은 결과였는지.
func _ai_reacts(happy: bool) -> void:
	if _is_local() or game == null or _fx_rng.randf() > 0.45:
		return
	var lines: Array = AI_HAPPY if happy else AI_SAD
	_say(1, str(lines[_fx_rng.randi_range(0, lines.size() - 1)]))


## 판 위에 얹는 정보판은 판 끌기·칸 누르기를 막지 않게 한다.
func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


## 모두의 마블식 큰 동그란 주사위 버튼: 노란 몸통, 짙은 테두리, 두꺼운 아래 그림자.
func _make_round_button() -> Button:
	var button := Button.new()
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 28)
	var body := Color("ffc62b")
	var edge := Color("6b3b00")
	var normal := _round_box(body, edge, 10)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _round_box(body.lightened(0.15), edge, 10))
	button.add_theme_stylebox_override("pressed", _round_box(body.darkened(0.15), edge, 4))
	button.add_theme_stylebox_override("disabled", _round_box(Color("5a5f78"), Color("2a2d40"), 6))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color("4a2600"))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))
	button.add_theme_constant_override("outline_size", 6)
	button.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.85))
	return button


func _chunky(style: StyleBoxFlat, bottom: int) -> StyleBoxFlat:
	style.border_width_bottom = bottom
	style.set_corner_radius_all(16)
	return style


func _round_box(fill: Color, edge: Color, bottom: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(5)
	style.border_width_bottom = bottom
	style.set_corner_radius_all(80)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 5)
	style.set_content_margin_all(14)
	return style


## 카드 모양 버튼: 크림색 종이에 갈색 테두리, 위에 작은 띠.
func _make_card_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(100, 118)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 18)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("3a2408"))
	var paper := Color("f3e6c4")
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = paper if state == "normal" else (paper.lightened(0.3) if state == "hover" else paper.darkened(0.12))
		style.border_color = Color("7a4a12")
		style.set_border_width_all(3)
		style.border_width_top = 14
		style.border_width_bottom = 6
		style.set_corner_radius_all(10)
		style.set_content_margin_all(6)
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_size = 4
		style.shadow_offset = Vector2(0, 3)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _make_button(font_size: int, height: float, color: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_stylebox_override("normal", _chunky(_box(color, color.darkened(0.5), 3), 7))
	button.add_theme_stylebox_override("hover", _chunky(_box(color.lightened(0.12), color.darkened(0.5), 3), 7))
	button.add_theme_stylebox_override("pressed", _chunky(_box(color.darkened(0.2), color.darkened(0.5), 3), 3))
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
	# 내 파티(0번)에는 장착한 유물의 시작 보너스가 붙는다. 친구 대전은 공평하게 쓰지 않는다.
	if _mode != "local" and not _parties.is_empty():
		_parties[0]["relic"] = Profile.current_relic(app.profile, app.eco).get("effect", {})
	game.setup(_data, _parties)
	_start_distance = max(game.distance_of(0), 1)
	for index in 2:
		_board_view.piece_textures[index] = GameData.portrait(str(game.char_of(index, "attack").get("id", "")))
	game.take_events()
	_board_view.game = game
	_board_view.reset_pieces()
	_waiting_for_player = false
	_choosing_path = false
	_my_battles = [0, 0]
	_slot_wins = {"attack": 0, "defense": 0, "support": 0}
	_abilities_used = 0
	_best_roll = 0
	_cards_used = 0
	_recorded = false
	_reward_lines = PackedStringArray()
	_last_reward = {}
	_rival_skin = _fx_rng.randi_range(0, 99)
	_auto = false
	_auto_button.text = "자동 꺼짐"
	Kit.paint(_auto_button, Color("6f9bd6"))
	_auto_button.visible = not _is_local()
	_clear_results()
	_add_result_text("%s 파티: %s" % [game.players[1]["name"], _party_names(1)], PLAYER_TEXT_COLORS[1])
	_add_result_text("맵: %s(%s)  ·  골의 수호자: %s\n먼저 골(분홍 칸)의 수호자를 이기고 들어가면 승리!" % [game.board_name, game.board_shape, _goal_name()], Color.WHITE)
	_refresh()
	var playing = game
	await _versus.play([_versus_side(0), _versus_side(1)],
		"%s (%s)" % [game.board_name, game.board_shape], "%s\n골의 수호자: %s  ·  %d턴 제한" % [game.board_feature, _goal_name(), game.max_rounds], _mode == "rank")
	if playing != game or not is_inside_tree():
		return
	_advance()


## VS 화면에 보여 줄 한쪽 파티.
func _versus_side(index: int) -> Dictionary:
	var members: Array = []
	var levels: Array = []
	for slot in Game.SLOTS:
		members.append(game.char_of(index, slot))
		levels.append(int(game.players[index].get("levels", {}).get(slot, 1)))
	var party := {}
	var level_table := {}
	for slot_index in Game.SLOTS.size():
		party[Game.SLOTS[slot_index]] = str(members[slot_index].get("id", ""))
		level_table[Game.SLOTS[slot_index]] = int(levels[slot_index])
	return {"name": str(game.players[index]["name"]), "color": PLAYER_TEXT_COLORS[index], "members": members, "levels": levels,
		"power": Profile.party_power(_data["characters"], app.eco, party, level_table)}


## 사람이 입력할 차례가 될 때까지 게임을 진행한다.
func _advance() -> void:
	var playing = game
	while playing == game and game.winner < 0:
		await _wait_for_board()
		if playing != game:
			return
		_board_view.focus_on(game.current)
		# 턴 제한이 가까우면 남은 턴을 알려 준다(끝나면 골까지 남은 거리로 판정).
		var turns_left: int = game.max_rounds - int(game.round_number) + 1
		var small := "%d / %d턴" % [min(game.round_number, game.max_rounds), game.max_rounds]
		if turns_left <= LAST_TURNS_WARNING and turns_left >= 1:
			small = "마지막 턴!" if turns_left == 1 else "남은 턴 %d" % turns_left
		await _banner.play(small, _turn_title(game.current), PLAYER_TEXT_COLORS[game.current])
		if playing != game:
			return
		if _humans[game.current] and not _auto:
			if game.begin_turn():
				_waiting_for_player = true
				_refresh()
				_turn_hints()
				_buzz()
				return
			_add_result_text("%s: 이번 턴은 쉽니다." % game.players[game.current]["name"], PLAYER_TEXT_COLORS[game.current])
			game.end_turn()
		else:
			_refresh()
			await get_tree().create_timer(AI_DELAY * 0.4).timeout
			if playing != game:
				return
			_add_result_header("자동 진행" if _humans[game.current] else "AI 차례", PLAYER_TEXT_COLORS[game.current])
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


func _goal_name() -> String:
	for id in game.nodes:
		if game.nodes[id].get("type", "") == "goal":
			return str(game.nodes[id].get("name", "수호자"))
	return "수호자"


func _turn_title(index: int) -> String:
	if _is_local():
		return "%s 차례" % game.players[index]["name"]
	return "내 차례" if _humans[index] else "AI 차례"


func _wait_for_board() -> void:
	while _board_view.is_busy():
		await get_tree().process_frame


## 굴리기 버튼을 누르기 시작. 내 차례면 잠시 뒤 세기 막대가 나온다.
func _on_roll_down() -> void:
	_roll_down_at = Time.get_ticks_msec() / 1000.0
	if game == null or game.winner >= 0 or not _waiting_for_player:
		return
	await get_tree().create_timer(HOLD_TO_AIM).timeout
	# 아직 누르고 있을 때만 막대를 띄운다.
	if _roll_down_at > 0.0 and _waiting_for_player and is_instance_valid(_aim_bar):
		_aim_bar.start()


## 버튼에서 손을 뗌. 막대가 떠 있었으면 그 자리의 노림으로, 아니면 그냥 굴린다.
func _on_roll_up() -> void:
	_roll_down_at = 0.0
	var aim := ""
	if _aim_bar.visible:
		aim = _aim_bar.stop()
	_on_roll_pressed(aim)


func _on_roll_pressed(aim: String = "") -> void:
	_close_hint()
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
	game.roll_move(aim)
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
	if game.choice_kind() == "fight":
		_hint("fight", "상대 말을 지나칩니다! '싸운다'를 고르면 내 ATTACK과 상대 DEFENSE가 주사위로 겨뤄요. 이기면 상대가 거점으로 돌아가요.")
	else:
		_hint("fork", "갈림길이에요! 위쪽 갈래는 키퍼와 판정이 있어 위험하고, 아래쪽 갈래는 보물과 행운이 있는 안전한 길이에요.")
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
		if me == 0:
			_abilities_used += 1
		_add_result_text("어빌리티 [%s] 발동! %s" % [
			game.ability_of(me, slot)["name"], game.ability_of(me, slot)["text"]], SLOT_COLORS[slot].lightened(0.4))
		_play("reveal")
		_refresh()
		await _present_events()
		_refresh()


## 카드를 누르면 설명 창. 쓸 수 있을 때만 '사용' 버튼이 나온다.
func _on_card_pressed(index: int) -> void:
	var hand: Array = game.players[_viewer()]["hand"]
	if index >= hand.size():
		return
	var card: Dictionary = game.cards[hand[index]]
	_play("click")
	var body := Kit.vbox(10)
	body.add_child(Kit.para(str(card["text"]), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var usable: bool = _waiting_for_player and game.can_play_card(index)
	var buttons: Array = []
	if usable:
		buttons.append(["사용", Color("f39a1c"), _use_card.bind(index)])
	else:
		if not game.card_condition_met(card):
			# 조건이 붙은 카드(역전의 첫걸음): 지금 얼마나 뒤처져 있는지 알려 준다.
			var behind: int = game.behind_by(_viewer())
			var state := "지금 %d칸 뒤처져 있어요." % behind if behind > 0 else "지금은 뒤처져 있지 않아요."
			body.add_child(Kit.para("상대보다 %d칸 이상 뒤처졌을 때만 쓸 수 있어요. %s" % [int(card["effect"].get("gap", 10)), state], 18, Color("ff9a6a"), HORIZONTAL_ALIGNMENT_CENTER))
		else:
			body.add_child(Kit.para("카드는 내 차례에 주사위를 굴리기 전에 쓸 수 있어요.", 18, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	buttons.append(["닫기", Kit.PANEL_LIGHT])
	app.dialog("카드 · %s" % card["name"], body, buttons, 560)


func _use_card(index: int) -> void:
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
			"tile":
				await _show_tile(event)
			"ability":
				# 어빌리티는 영웅 그림 컷인으로 보여 준다(누가 쓰든).
				var caster := int(event["player"])
				_say(caster, "%s!" % event["name"])
				_play("good" if _humans[caster] else "bad")
				await _cutin.play(_character_named(str(event["hero"])), str(event["name"]), str(event.get("text", "")), PLAYER_TEXT_COLORS[caster])
			"card":
				await _show_used(event, "카드 %s!" % event["name"], "카드 · %s" % event["name"])
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
	if not event["rolls"].is_empty():
		# 판 가운데 큰 주사위 연출. 아래 결과 줄의 작은 주사위도 같이 구른다.
		_play("dice")
		var dice = row.get_meta("dice") if row.has_meta("dice") else null
		if dice != null:
			dice.roll_to(event["rolls"], BigDice.ROLL_TIME)
		var bonus_text := " (+%d)" % int(event["bonus"]) if int(event["bonus"]) > 0 else ""
		var caption := "%s 이동" % game.players[who]["name"]
		var aim_name := "낮게" if str(event.get("aim", "")) == "low" else "높게"
		if bool(event.get("controlled", false)):
			caption = "%s 주사위 컨트롤 성공! (%s)" % [game.players[who]["name"], aim_name]
		elif str(event.get("aim", "")) != "" and _humans[who]:
			caption = "%s 주사위 컨트롤 실패 (%s)" % [game.players[who]["name"], aim_name]
		if bool(event.get("catchup", false)):
			# 많이 뒤처진 쪽은 큰 눈이 잘 나온다는 것을 알려 준다.
			caption = "%s 따라잡기! 큰 눈이 잘 나와요" % game.players[who]["name"]
		_big_dice.skin = _dice_skin_of(who)
		var doubled := bool(event.get("double", false))
		await _big_dice.play(caption, event["rolls"], ("더블! %d칸!%s" if doubled else "%d칸!%s") % [int(event["total"]), bonus_text], PLAYER_TEXT_COLORS[who])
		if doubled:
			_say(who, "더블! 게이지 +%d%%" % game.double_gauge)
			_play("good" if _humans[who] else "bad")
		# 연출을 기다리는 사이에 결과 줄이 지워졌을 수 있다(다시 하기 등).
		if is_instance_valid(row):
			var end: Label = row.get_meta("tail")
			end.text = tail
		return
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
	var dice = row.get_meta("dice") if row.has_meta("dice") else null
	if dice != null:
		_play("dice")
		await dice.roll_to(rolls, 0.55)
	if not is_instance_valid(row):
		return
	var end: Label = row.get_meta("tail")
	end.text = tail


func _show_battle(event: Dictionary) -> void:
	_hint("battle", "전투! 양쪽이 주사위를 굴려 합이 큰 쪽이 이겨요. 지면 직전 거점(파란 깃발)으로 돌아가요. 이기면 카드를 받아요.")
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
		_ai_reacts(event["won"] if who == 0 else not event["won"])
		return
	var card_duel: bool = str(event.get("target", "")) == "card"
	var against_player: bool = str(event.get("target", "")) == "player" or card_duel
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
	if card_duel:
		# 역전의 첫걸음: 이기면 나는 앞으로, 상대는 뒤로. 지면 그대로(아무도 거점으로 가지 않는다).
		info["winner_text"] = "%s 역전! 5칸 앞으로, 상대는 5칸 뒤로" % game.players[who]["name"]
		info["loser_text"] = "%s 역전 실패... 그대로" % game.players[who]["name"]
	info["attacker_character"] = _character_named(str(event["attacker"]))
	info["defender_character"] = _character_named(str(event["defender"]))
	await _battle_overlay.play(event, info)
	_add_battle_result(event)
	_ai_reacts(not bool(info["good_for_me"]))


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
	_scroll_results_down.call_deferred()


## 새 기록이 보이도록 맨 아래로 내린다.
func _scroll_results_down() -> void:
	if _result_scroll == null:
		return
	await get_tree().process_frame
	if is_instance_valid(_result_scroll):
		_result_scroll.scroll_vertical = int(_result_scroll.get_v_scroll_bar().max_value)


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
		dice.die_size = 46.0
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
		var my_total := int(event["defense_total"]) if ambushed else int(event["attack_total"])
		_best_roll = max(_best_roll, my_total)
		if success:
			_slot_wins["defense" if ambushed else "attack"] += 1
	elif str(event.get("target", "")) in ["player", "card"] and not success:
		# 상대가 나를 공격했다가 진 것도 내 전투 승리
		_my_battles[0] += 1
		_slot_wins["defense"] += 1
		_best_roll = max(_best_roll, int(event["defense_total"]))
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
		subtitle = "%d턴이 끝나 골까지 남은 거리로 판정했습니다." % game.max_rounds
	var details := PackedStringArray([
		"진행한 턴: %d턴" % min(game.round_number, game.max_rounds),
		"골까지 남은 거리: %s %d칸 · %s %d칸" % [game.players[0]["name"], game.distance_of(0), game.players[1]["name"], game.distance_of(1)],
		"%s 파티: %s" % [game.players[0]["name"], _party_names(0)],
		"%s 파티: %s" % [game.players[1]["name"], _party_names(1)],
	])
	if not _is_local():
		details.insert(2, "내 전투: %d승 %d패  ·  최고 주사위 합 %d" % [_my_battles[0], _my_battles[1], _best_roll])
		details.insert(3, "카드 %d장 · 어빌리티 %d번 사용" % [_cards_used, _abilities_used])
	details.append_array(_record(outcome))
	var shown_outcome := outcome
	if _is_local() and outcome != "draw":
		shown_outcome = "win"
	# 칸 알림·말풍선이 결과 창을 가리지 않게 맨 앞으로
	_close_hint()
	move_child(_result_overlay, get_child_count() - 1)
	_result_overlay.show_result(shown_outcome, subtitle, details, _result_extras())


## 결과 화면의 MVP 영웅과 보상 칩.
func _result_extras() -> Dictionary:
	var extras := {}
	if not _is_local():
		var slot := _mvp_slot()
		var note := "전투 %d승" % int(_slot_wins[slot]) if slot != "" else "파티의 선봉"
		if slot == "":
			slot = "attack"
		extras["mvp"] = game.char_of(0, slot)
		extras["mvp_note"] = "%s · %s" % [SLOT_NAMES.get(slot, slot), note]
	var chips: Array = []
	if int(_last_reward.get("gold", 0)) > 0:
		chips.append([Kit.money_text("gold", int(_last_reward["gold"])), Kit.GOLD])
	if int(_last_reward.get("gems", 0)) > 0:
		chips.append([Kit.money_text("gems", int(_last_reward["gems"])), Kit.GEM])
	if int(_last_reward.get("exp", 0)) > 0:
		chips.append(["경험치 +%d" % int(_last_reward["exp"]), Color("7ee081")])
	if int(_last_reward.get("trophies", 0)) != 0:
		chips.append(["트로피 %+d" % int(_last_reward["trophies"]), Color("ff9a6a")])
	if int(_last_reward.get("pass_exp", 0)) > 0:
		chips.append(["패스 +%d" % int(_last_reward["pass_exp"]), Color("d08aff")])
	extras["chips"] = chips
	# 모험에서 이겼고 다음 스테이지가 있으면 오른쪽 버튼이 '다음 스테이지'가 된다.
	_next_stage = ""
	if _mode == "adventure" and game.winner == 0:
		_next_stage = Profile.next_stage_id(app.data.get("adventure", {}), _stage_id)
	if _next_stage != "":
		extras["again_text"] = "다음 스테이지"
	return extras


## 판 결과를 프로필에 기록하고 보상 줄을 돌려준다. 한 판에 한 번만.
func _record(outcome: String) -> PackedStringArray:
	var lines := PackedStringArray()
	if _recorded or not app.has_profile():
		return _reward_lines
	_recorded = true
	var missions_before := Profile.claimable_mission_count(app.profile, app.eco)
	var achievements_before := Profile.claimable_achievement_count(app.profile, app.data)
	var reward := Profile.record_match(app.profile, app.eco, _mode, outcome, {"battle_wins": _my_battles[0], "cards": _cards_used, "reward_scale": _reward_scale, "party": _my_party_ids(),
		"map": game.board_name, "turns": int(game.round_number),
		"event_gold_scale": Profile.event_scale(app.data.get("events", {}), app.today(), "match_gold_scale"),
		"event_pass_scale": Profile.event_scale(app.data.get("events", {}), app.today(), "pass_exp_scale")})
	_last_reward = reward
	if _mode == "adventure" and _stage_id != "":
		var result := Profile.record_adventure(app.profile, app.data.get("adventure", {}), _stage_id, outcome == "win", int(game.round_number), int(_my_battles[1]))
		if int(result["stars"]) > 0:
			lines.append("모험 %s  %s" % [_stage_id, "★".repeat(int(result["stars"])) + "☆".repeat(3 - int(result["stars"]))])
		if bool(result["first_clear"]):
			lines.append("첫 클리어 보상: %s" % Kit.reward_line(result["reward"]))
		elif int(result["reward"].get("gems", 0)) > 0:
			lines.append("별 3개 보상: %s" % Kit.reward_line(result["reward"]))
	app.save()
	if _mode == "rank":
		lines.append("트로피 %+d → %d (%s)" % [int(reward["trophies"]), int(app.profile["trophies"]), reward["tier_after"]])
		if str(reward["tier_before"]) != str(reward["tier_after"]):
			lines.append("티어 변경: %s → %s" % [reward["tier_before"], reward["tier_after"]])
	if int(reward.get("streak", 0)) >= 2:
		lines.append("%d연승! 연승 보너스 골드 +%d" % [int(reward["streak"]), int(reward.get("streak_gold", 0))])
	for event in Profile.active_events(app.data.get("events", {}), app.today()):
		lines.append("이벤트 적용: %s" % event["name"])
	if bool(reward["first_win"]):
		lines.append("오늘 첫 승리 보너스!")
	if int(reward["level_ups"]) > 0:
		lines.append("레벨 업! 플레이어 레벨 %d" % int(app.profile["level"]))
	# 이번 판으로 새로 받을 수 있게 된 미션·업적
	var new_missions := Profile.claimable_mission_count(app.profile, app.eco) - missions_before
	var new_achievements := Profile.claimable_achievement_count(app.profile, app.data) - achievements_before
	if new_missions > 0:
		lines.append("미션 %d개 완료! 미션 화면에서 보상을 받으세요." % new_missions)
	if new_achievements > 0:
		lines.append("업적 %d개 달성! 미션 화면에서 보상을 받으세요." % new_achievements)
	_reward_lines = lines
	return lines


func _on_retry_pressed() -> void:
	_play("click")
	if _is_local():
		app.go_loading("match", {"mode": _mode, "parties": _parties, "humans": _humans, "map": app.rng.randi_range(0, app.data["boards"].size() - 1)}, "대전 준비 중...", 0.8, true)
	elif _mode == "adventure":
		app.go("party", {"purpose": "match", "mode": "adventure", "stage": _next_stage if _next_stage != "" else _stage_id})
	else:
		app.start_mode(_mode)


func _on_change_party_pressed() -> void:
	_play("click")
	app.go_loading("adventure" if _mode == "adventure" else "lobby", {}, "돌아가는 중...", 0.5)


## 나가기. 랭크전에서 도중에 나가면 패배로 기록한다.
func _on_quit_pressed() -> void:
	_play("click")
	if game.winner >= 0:
		app.go_loading("lobby", {}, "돌아가는 중...", 0.5)
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
	# 판을 버리고 나갈 때는 바로 넘어간다(멈춘 판 화면을 기다리게 하지 않는다).
	app.go("lobby")


## 전투를 가장 많이 이긴 내 영웅 자리. 아무도 못 이겼으면 "".
func _mvp_slot() -> String:
	var best := ""
	var best_wins := 0
	for slot in Game.SLOTS:
		if int(_slot_wins[slot]) > best_wins:
			best_wins = int(_slot_wins[slot])
			best = slot
	return best


func _my_party_ids() -> Array:
	var ids: Array = []
	for slot in Game.SLOTS:
		ids.append(str(game.char_of(0, slot)["id"]))
	return ids


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
	_status_label.text = "%d/%d턴 · %s\n%s · 맵 속성: %s" % [
		min(game.round_number, game.max_rounds), game.max_rounds, turn_text, game.board_name, attr_text]
	_refresh_player_cards()
	_board_view.active_player = game.current if game.winner < 0 else -1

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
		_ability_gauges[slot].value = clampf(float(me["gauge"][slot]) / 100.0, 0.0, 1.0)
		var portrait = _ability_portraits[slot]
		portrait.show_character(character, SLOT_COLORS[slot])

	var hand: Array = me["hand"]
	for index in _card_buttons.size():
		var button: Button = _card_buttons[index]
		if index < hand.size():
			var card: Dictionary = game.cards[hand[index]]
			button.text = str(card["name"])
			button.visible = true
			# 지금 쓸 수 있는 카드는 또렷하게, 아니면 흐리게
			button.modulate = Color.WHITE if _waiting_for_player and game.can_play_card(index) else Color(0.75, 0.75, 0.8, 0.85)
		else:
			button.visible = false

	if game.winner >= 0:
		_roll_button.text = "결과\n보기"
		_roll_button.disabled = false
	elif _choosing_path:
		_roll_button.text = "길을\n고르세요"
		_roll_button.disabled = true
	elif _waiting_for_player:
		_roll_button.text = "주사위\n굴리기"
		_roll_button.disabled = false
	else:
		_roll_button.text = "AI\n차례" if not _humans[game.current] else "진행\n중..."
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
