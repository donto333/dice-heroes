extends Control
## 대전 화면. 규칙은 scripts/rules/game.gd, 보상은 scripts/rules/profile.gd.
## setup()의 params: {"mode": "rank"|"ai"|"local", "parties": [파티1, 파티2], "humans": [true, false]}
## 친구 대전(local)은 두 사람이 한 기기를 번갈아 쓴다. 지금 차례인 사람의 어빌리티와 카드가 보인다.
##
## 화면 위에서부터: 상태 줄(나가기), 보드, 결과 패널(주사위·전투), 어빌리티, 카드, 굴리기 버튼, 진행 기록.

const ArtView := preload("res://scripts/ui/art_view.gd")
const Game := preload("res://scripts/rules/game.gd")
const AI := preload("res://scripts/rules/ai.gd")
const GameData := preload("res://scripts/game_data.gd")
const BoardView := preload("res://scripts/ui/board_view.gd")
const ForkChoices := preload("res://scripts/ui/fork_choices.gd")
const DiceView := preload("res://scripts/ui/dice_view.gd")
const BattleOverlay := preload("res://scripts/ui/battle_overlay.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")

const Profile := preload("res://scripts/rules/profile.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const Sweep := preload("res://scripts/ui/sweep.gd")
const ABILITY_PORTRAIT_WIDTH := 76.0
## 대전 화면 그림 부품(ChatGPT가 그린 것, 2026-11-16). 없으면 예전 모양으로 그린다.
const MATCH_ART := "res://assets/ui_match/"
const FIGHT_CHOICE_ART := ["choice_fight", "choice_pass"]
const REFERENCE_HUD_ART := "res://assets/ui_observatory/ui_match/reference/"
const REFERENCE_SIZE := Vector2(1672, 941)
const REFERENCE_CARD_CELLS := [[0.112, 0.375], [0.399, 0.634], [0.657, 0.901]]
const SKILL_WIDTH := 181
const SKILL_ART := {"attack": "skill_red", "defense": "skill_purple", "support": "skill_green"}
## 카드 세 칸 틀(card_column.png)에서 칸마다 위·아래 비율.
const CARD_CELLS := [[0.062, 0.31], [0.372, 0.614], [0.679, 0.924]]
const PILL_OUTLINE := {"blue": Color("0b2f73"), "green": Color("0b4a1e"), "red": Color("6a1004")}
const TurnBanner := preload("res://scripts/ui/turn_banner.gd")
const AdPlayer := preload("res://scripts/ui/ad_player.gd")
const ResultOverlay := preload("res://scripts/ui/result_overlay.gd")
const BigDice := preload("res://scripts/ui/big_dice.gd")
const AimBar := preload("res://scripts/ui/aim_bar.gd")
const Cutin := preload("res://scripts/ui/cutin.gd")
## 이동할 때 음성이 나올 확률
const MOVE_VOICE_CHANCE := 0.4
var _voice_rng := RandomNumberGenerator.new()
## 따라잡기 안내는 한 판에 한 번만 한다.
var _catchup_announced := false
const Fx := preload("res://scripts/ui/fx.gd")
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
var _path_choices: Control

var _status_label: Label
## 오른쪽 위 버튼 줄(자동·빠르기·나가기)과, 그 줄 너비에 맞춰 오른쪽 여백을 정하는 가운데 위 부품들 [노드, 더 들일 여백]
var _status_row: HBoxContainer
var _top_center: Array = []
var _map_label: Label = null
var _board_view: Control
var _result_box: VBoxContainer
var _result_panel: PanelContainer
var _roll_art: TextureRect = null
var _roll_caption: Label = null
var _log_tween: Tween
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
## 길잡이 첫 판(2026-11-20): 카드→스킬→주사위를 차례로 강제 안내. -1이면 안내 없음.
var _tutorial := false
var _tut_step := -1
var _big_dice: Control
var _result_scroll: ScrollContainer
var _speed_button: Button
var _aim_bar: Control
var _cutin: Control
var _fx: Control
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
	_tutorial = bool(params.get("tutorial", false))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 알림 띠(toast.gd)는 화면 맨 아래 가운데, 아래 스킬 카드 줄(높이 약 112) 바로 위에 뜬다.
	set_meta("toast_bottom", 122.0)
	_build_ui()
	_start_game()


func _play(sound: String) -> void:
	app.play(sound)


## 판 위 말의 위치를 이 화면 좌표로.
func _piece_spot(player_index: int) -> Vector2:
	return Kit.spot_in(self, _board_view, _board_view.piece_point(player_index))


func _board_center() -> Vector2:
	return Kit.spot_in(self, _board_view, _board_view.size * 0.5)


## 말이 칸에 내려앉았다: 져서 날아온 것이면 쿵 소리와 흔들림.
func _on_piece_landed(player_index: int, flung: bool) -> void:
	if not flung:
		# 발끝 효과(2026-11-19, 꾸미기): 내 말(첫 번째 플레이어)이 한 칸 뛸 때마다 발밑에 작게 피어난다.
		if player_index == 0 and not _is_local() and app.has_profile():
			var trail := Profile.trail_fx(app.profile, app.eco)
			if trail != "":
				_fx.burst(_piece_spot(player_index) + Vector2(0, 36), trail, 6, 0.32)
		return
	_play("impact")
	_fx.burst(_piece_spot(player_index) + Vector2(0, 40), "impact", 14, 0.9)
	_fx.burst(_piece_spot(player_index) + Vector2(0, 50), "dust", 8, 0.9)
	_fx.shake(_board_view, 12.0, 0.3)


func _on_piece_flung(player_index: int) -> void:
	_play("fling")
	_fx.burst(_piece_spot(player_index), "impact", 12, 0.8)


## 지금 화면에 어빌리티와 카드를 보여 줄 플레이어. 사람 차례면 그 사람, AI 차례면 첫 번째 사람.
func _viewer() -> int:
	if game != null and _humans[game.current]:
		return game.current
	return 0


func _is_local() -> bool:
	return _mode == "local"


# ---------------------------------------------------------------- 화면 구성

## 시안 화면에서 잰 좌표를 실제 화면 크기에 비례해 적용한다.
func _hud_rect(control: Control, area: Rect2) -> void:
	var from := area.position / REFERENCE_SIZE
	var to := area.end / REFERENCE_SIZE
	control.set_anchor(SIDE_LEFT, from.x)
	control.set_anchor(SIDE_TOP, from.y)
	control.set_anchor(SIDE_RIGHT, to.x)
	control.set_anchor(SIDE_BOTTOM, to.y)
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0


func _build_ui() -> void:
	var reference_hud := Kit.Observatory.active
	var background := ColorRect.new()
	background.color = Color("1c5cb8")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	add_child(Kit.sky())

	# 가로 화면: 판이 화면 전체를 차지하고, 모든 정보는 판 위 모서리에 얹는다.
	var column := Control.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 6)
	if reference_hud:
		status_row.alignment = BoxContainer.ALIGNMENT_END
	_status_row = status_row
	_status_label = _make_label(18)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_constant_override("outline_size", 6)
	_status_label.add_theme_color_override("font_outline_color", Color(0, 0.05, 0.2))
	_auto_button = Kit.button("자동 꺼짐", Color("6f9bd6"), 18, 50)
	_auto_button.custom_minimum_size = Vector2(106, 44) if reference_hud else Vector2(110, 50)
	_auto_button.pressed.connect(_on_auto_pressed)
	_paint_pill(_auto_button, "blue", Color("6f9bd6"))
	status_row.add_child(_auto_button)
	_speed_button = Kit.button("", Color("27a35a"), 18, 50)
	_speed_button.custom_minimum_size = Vector2(142, 44) if reference_hud else Vector2(124, 50)
	_speed_button.pressed.connect(_on_speed_pressed)
	_pill_icon(_speed_button, "ic_fast")
	status_row.add_child(_speed_button)
	_apply_speed()
	var quit_button := Kit.button("나가기", Color("e0532b"), 18, 50)
	quit_button.custom_minimum_size = Vector2(118, 44) if reference_hud else Vector2(108, 50)
	quit_button.pressed.connect(_on_quit_pressed)
	_paint_pill(quit_button, "red", Color("e0532b"))
	_pill_icon(quit_button, "ic_exit")
	status_row.add_child(quit_button)

	# 모두의 마블처럼 판이 화면 대부분을 차지하고,
	# 플레이어 정보판은 판 모서리(상대 왼쪽 위, 나 왼쪽 아래), 큰 주사위 버튼은 오른쪽 아래에 얹는다.
	var board_area := Control.new()
	board_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_child(board_area)
	_board_view = BoardView.new()
	_board_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_view.pad_top = 110.0
	_board_view.pad_bottom = 140.0
	_board_view.pad_left = 132.0 if _match_tex("card_column") != null else 112.0
	board_area.add_child(_board_view)
	if reference_hud:
		_board_view.minimap_area = Rect2(Vector2(1496, 77) / REFERENCE_SIZE, Vector2(167, 99) / REFERENCE_SIZE)
		_board_view.minimap_frame = _match_tex("minimap_frame")
	for index in 2:
		var card: Control = _player_card(index)
		board_area.add_child(card)
		card.anchor_left = 0.0
		card.anchor_right = 0.0
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
		card.offset_right = 400
		if reference_hud:
			_hud_rect(card, Rect2(8, 8, 506, 105) if index == 1 else Rect2(8, 788, 483, 137))
		_ignore_mouse(card)

	_big_dice = BigDice.new()
	board_area.add_child(_big_dice)
	_board_area = board_area
	_build_emotes(board_area)

	_roll_button = _make_round_button()
	_roll_button.set_meta("guide", "roll")
	# 짧게 누르면 그냥 굴리고, 꾹 누르면 세기 막대가 나와 놓는 자리로 낮게·높게를 노린다(주사위 컨트롤).
	_roll_button.button_down.connect(_on_roll_down)
	_roll_button.button_up.connect(_on_roll_up)
	_aim_bar = AimBar.new()
	_aim_bar.started.connect(func(): _play("aim"))
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
	if reference_hud:
		_hud_rect(_roll_button, Rect2(1398, 665, 269, 266))
		_aim_bar.offset_top = -277
		_aim_bar.offset_bottom = -213

	# 위 가운데: 턴 정보 한 줄과 반투명 기록 칸. 오른쪽 위: 자동·빠르기·나가기.
	# 그림이 있으면 월계수 띠(턴 정보)와 그 아래 작은 캡슐(맵 이름·속성)로 나눈다.
	var banner: Control = _stretch("turn_banner") if reference_hud else _patch("turn_banner", Vector4(64, 0, 64, 0), 50.0 / 81.0)
	if banner != null:
		banner.show_behind_parent = false
		board_area.add_child(banner)
		banner.anchor_left = 0.0
		banner.anchor_right = 1.0
		banner.anchor_top = 0.0
		banner.anchor_bottom = 0.0
		banner.offset_left = 416
		banner.offset_right = -352
		_top_center.append([banner, 0.0])
		banner.offset_top = 4
		banner.offset_bottom = 54
		var capsule: Control = _stretch("map_capsule") if reference_hud else _patch("map_capsule", Vector4(34, 0, 34, 0), 30.0 / 50.0)
		capsule.show_behind_parent = false
		board_area.add_child(capsule)
		capsule.anchor_left = 0.0
		capsule.anchor_right = 1.0
		capsule.anchor_top = 0.0
		capsule.anchor_bottom = 0.0
		capsule.offset_left = 416 + 70
		capsule.offset_right = -352 - 70
		_top_center.append([capsule, 70.0])
		capsule.offset_top = 54
		capsule.offset_bottom = 84
		_map_label = _make_label(15)
		_map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_map_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_map_label.add_theme_constant_override("outline_size", 5)
		_map_label.add_theme_color_override("font_outline_color", Color(0, 0.05, 0.2))
		_map_label.add_theme_color_override("font_color", Color("ffe9a8"))
		_map_label.clip_text = true
		_map_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_map_label.offset_left = 22
		_map_label.offset_right = -22
		_map_label.offset_bottom = -2
		_map_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		capsule.add_child(_map_label)
		if reference_hud:
			_hud_rect(banner, Rect2(579, 3, 514, 67))
			_hud_rect(capsule, Rect2(642, 68, 392, 46))
			_map_label.add_theme_font_size_override("font_size", 16)
		_status_label.add_theme_font_size_override("font_size", 20)
	board_area.add_child(_status_label)
	_status_label.anchor_left = 0.0
	_status_label.anchor_right = 1.0
	_status_label.offset_left = 416 + (60 if banner != null else 0)
	_status_label.offset_right = -352 - (60 if banner != null else 0)
	_top_center.append([_status_label, 60.0 if banner != null else 0.0])
	_status_label.offset_top = 6
	_status_label.offset_bottom = 54 if banner == null else 50
	_status_label.clip_text = banner != null
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_area.add_child(status_row)
	status_row.anchor_left = 1.0
	status_row.anchor_right = 1.0
	# 글이 길어져도 오른쪽 끝(-8)은 그대로 두고 왼쪽으로 늘어난다(화면 밖으로 잘리지 않게).
	status_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	status_row.offset_left = -362
	status_row.offset_right = -8
	status_row.offset_top = 8
	status_row.offset_bottom = 58
	if reference_hud:
		_hud_rect(_status_label, Rect2(624, 10, 425, 55))
		_status_label.add_theme_font_size_override("font_size", 24)
		_hud_rect(status_row, Rect2(1160, 12, 503, 59))
	var result_panel := PanelContainer.new()
	# 기록 칸은 작고 반투명하게. 내용이 넘치면 안에서 스크롤된다.
	result_panel.add_theme_stylebox_override("panel", Kit.plate(Color(0.07, 0.1, 0.34, 0.8), Kit.TRIM, 16.0, 10, false))
	var frame_tex := _match_tex("minimap_frame", not reference_hud)
	if frame_tex != null:
		# 금테 남색 판(가운데만 늘어남). 판 아래가 살짝 비치게 조금 투명하게.
		var framed := StyleBoxTexture.new()
		framed.texture = frame_tex
		framed.set_texture_margin_all(26)
		framed.set_content_margin_all(14)
		framed.modulate_color = Color(1, 1, 1, 0.9)
		result_panel.add_theme_stylebox_override("panel", framed)
	board_area.add_child(result_panel)
	_result_panel = result_panel
	result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_panel.anchor_left = 0.0
	result_panel.anchor_right = 1.0
	result_panel.offset_left = 416
	result_panel.offset_right = -352
	_top_center.append([result_panel, 0.0])
	result_panel.offset_top = 56 if _map_label == null else 88
	result_panel.offset_bottom = 140 if _map_label == null else 168
	if reference_hud:
		_hud_rect(result_panel, Rect2(579, 118, 514, 96))
	_result_scroll = ScrollContainer.new()
	_result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	result_panel.add_child(_result_scroll)
	_result_box = VBoxContainer.new()
	_result_box.add_theme_constant_override("separation", 6)
	_result_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_scroll.add_child(_result_box)

	var ability_row := HBoxContainer.new()
	ability_row.add_theme_constant_override("separation", 8)
	board_area.add_child(ability_row)
	ability_row.anchor_left = 0.0
	ability_row.anchor_right = 1.0
	ability_row.anchor_top = 1.0
	ability_row.anchor_bottom = 1.0
	ability_row.anchor_left = 1.0
	var skill_art := _match_tex("skill_red") != null
	ability_row.offset_left = -190 - 3 * (SKILL_WIDTH + 8) - 76 if skill_art else -190 - 3 * 176 - 76
	ability_row.offset_right = -190
	ability_row.offset_top = -112
	ability_row.offset_bottom = -6
	if reference_hud:
		ability_row.add_theme_constant_override("separation", 8)
		_hud_rect(ability_row, Rect2(499, 786, 897, 138))
	# 스킬 설명 버튼: 언제든 세 영웅의 스킬 설명을 볼 수 있다.
	var info_button := Kit.button("스킬\n설명", Color("6f9bd6"), 17, 104)
	info_button.custom_minimum_size = Vector2(68, 104)
	info_button.pressed.connect(_show_skill_info.bind(""))
	var book := _stretch("info_book")
	if book != null:
		# 책 그림 버튼. 글자는 책 아래 빈 자리에 작게.
		_skin_button(info_button, book)
		info_button.text = ""
		var info_label := _art_label("설명", 15, Rect2(0.05, 0.6, 0.9, 0.3))
		info_button.add_child(info_label)
	ability_row.add_child(info_button)
	for slot in Game.SLOTS:
		if skill_art:
			var art_button := _make_skill_button(slot)
			art_button.pressed.connect(_on_ability_pressed.bind(slot))
			art_button.gui_input.connect(_on_ability_input.bind(slot))
			art_button.set_meta("guide", "skill_%s" % slot)
			if reference_hud:
				art_button.custom_minimum_size = Vector2.ZERO
				art_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ability_row.add_child(art_button)
			_ability_buttons[slot] = art_button
			continue
		var button := _make_button(16, 104, SLOT_COLORS[slot])
		button.pressed.connect(_on_ability_pressed.bind(slot))
		# 아직 못 쓰는(꺼진) 스킬 버튼을 눌러도 설명 창이 뜬다.
		button.gui_input.connect(_on_ability_input.bind(slot))
		# 광택 스킬 버튼: 못 쓸 때도 자리 색이 어둡게 남고, 쓸 수 있으면 금색 테가 빛나며 빛이 훑고 지나간다.
		Kit.paint(button, SLOT_COLORS[slot])
		var gloss = button.get_node("Gloss")
		gloss.keep_color = true
		gloss.alert = true
		Kit.shimmer(button, float(Game.SLOTS.find(slot)) * 0.4)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var space: StyleBox = button.get_theme_stylebox(state).duplicate()
			# 아래쪽에 게이지 막대가 들어갈 자리를 비워 둔다.
			space.content_margin_bottom = 30
			button.add_theme_stylebox_override(state, space)
		button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.78))
		var gauge := _make_skill_gauge(10.0)
		button.add_child(gauge)
		gauge.anchor_left = 0.0
		gauge.anchor_right = 1.0
		gauge.anchor_top = 1.0
		gauge.anchor_bottom = 1.0
		gauge.offset_left = ABILITY_PORTRAIT_WIDTH + 14
		gauge.offset_right = -10
		gauge.offset_top = -30
		gauge.offset_bottom = -18
		_ability_gauges[slot] = gauge
		button.set_meta("guide", "skill_%s" % slot)
		ability_row.add_child(button)
		_ability_buttons[slot] = button
		_ability_portraits[slot] = _add_side_portrait(button)

	# 아이템 카드는 판 왼쪽에 카드 모양으로 세워 둔다. 누르면 설명 창이 뜨고 거기서 쓴다.
	var column_art := _stretch("card_column")
	if column_art != null:
		# 금테 세 칸 틀. 카드는 칸 안에 하나씩 들어가고, 없는 칸은 빈 남색 칸으로 보인다.
		var frame := Control.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board_area.add_child(frame)
		frame.anchor_left = 0.0
		frame.anchor_right = 0.0
		frame.anchor_top = 0.5
		frame.anchor_bottom = 0.5
		frame.offset_left = 4
		frame.offset_right = 4 + 124
		frame.offset_top = -210
		frame.offset_bottom = 210
		if reference_hud:
			_hud_rect(frame, Rect2(9, 191, 154, 523))
		column_art.show_behind_parent = false
		frame.add_child(column_art)
		for index in Game.HAND_LIMIT:
			var cell: Array = REFERENCE_CARD_CELLS[index] if reference_hud else CARD_CELLS[index]
			var button := _make_card_button(true)
			button.anchor_left = 0.17 if reference_hud else 0.15
			button.anchor_right = 0.83 if reference_hud else 0.85
			button.anchor_top = cell[0]
			button.anchor_bottom = cell[1]
			button.offset_left = 0
			button.offset_right = 0
			button.offset_top = 0
			button.offset_bottom = 0
			button.pressed.connect(_on_card_pressed.bind(index))
			button.set_meta("guide", "card_%d" % index)
			frame.add_child(button)
			_card_buttons.append(button)
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
	card_column.visible = column_art == null
	for index in (Game.HAND_LIMIT if column_art == null else 0):
		var button := _make_card_button()
		button.pressed.connect(_on_card_pressed.bind(index))
		button.set_meta("guide", "card_%d" % index)
		card_column.add_child(button)
		_card_buttons.append(button)


	if reference_hud:
		var trim := _stretch("bottom_trim")
		if trim != null:
			trim.show_behind_parent = false
			board_area.add_child(trim)
			_hud_rect(trim, Rect2(7, 922, 1658, 12))

	_log_label = _make_label(17)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 진행 기록은 두세 줄만. 남는 자리는 모두 보드에 준다.
	_log_label.custom_minimum_size = Vector2(0, 60)
	_log_label.size_flags_vertical = Control.SIZE_SHRINK_END
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_log_label.clip_text = true
	_log_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	column.add_child(_log_label)
	# 진행 기록 글줄은 화면을 어수선하게 해서 숨긴다(판에 자리를 더 준다). 기록은 위의 결과 칸에 나온다.
	_log_label.visible = false

	_board_view.stepped.connect(func(): _play("step"))
	_battle_overlay = BattleOverlay.new()
	_battle_overlay.sfx = app.sfx if app.sfx_on() else null
	add_child(_battle_overlay)
	_result_overlay = ResultOverlay.new()
	add_child(_result_overlay)
	_result_overlay.retry_pressed.connect(_on_retry_pressed)
	_result_overlay.change_party_pressed.connect(_on_change_party_pressed)
	_result_overlay.ad_pressed.connect(_on_ad_gold)
	_banner = TurnBanner.new()
	add_child(_banner)
	_cutin = Cutin.new()
	add_child(_cutin)
	_versus = VersusOverlay.new()
	add_child(_versus)
	# 연출 층(번쩍임·알갱이·속도선). 자동 사진에서는 끈다.
	_fx = Fx.new()
	_fx.quiet = app.instant
	add_child(_fx)
	_board_view.landed.connect(_on_piece_landed)
	_board_view.flung_away.connect(_on_piece_flung)
	_fit_top_row()


## 오른쪽 위 버튼 줄이 1280 너비 안에 다 들어오게 줄 너비를 재고, 가운데 위 턴 띠·맵 캡슐·기록 칸의
## 오른쪽 여백을 그 줄 왼쪽 끝 + 12로 맞춰 서로 겹치지 않게 한다(글이 바뀌면 다시 잰다).
func _fit_top_row() -> void:
	if Kit.Observatory.active:
		return
	await get_tree().process_frame
	if not is_instance_valid(_status_row):
		return
	var width: float = _status_row.get_combined_minimum_size().x
	_status_row.offset_left = -8.0 - width
	var margin: float = width + 8.0 + 12.0
	for entry in _top_center:
		var node: Control = entry[0]
		if is_instance_valid(node):
			node.offset_right = -margin - float(entry[1])


## 플레이어 정보판 하나. _player_cards[index]에 부품을 담아 _refresh에서 고친다.
func _player_card(index: int) -> Control:
	var skin: Control = _stretch("player_panel" if index == 1 else "my_player_panel") if Kit.Observatory.active \
		else _patch("player_panel", Vector4(100, 0, 70, 0), 84.0 / 111.0)
	if skin != null:
		# 그림 정보판: 왼쪽 금테 칸에 대표 영웅, 오른쪽에 이름·진행 막대·남은 칸.
		var card := Control.new()
		card.add_child(skin)
		var face_art := Portrait.new()
		face_art.border_width = 0.0
		face_art.position = Vector2(17, 17)
		face_art.size = Vector2(50, 50)
		card.add_child(face_art)
		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation", 1)
		lines.alignment = BoxContainer.ALIGNMENT_CENTER
		lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lines.offset_left = 80
		lines.offset_right = -60
		lines.offset_top = 8
		lines.offset_bottom = -10
		if Kit.Observatory.active:
			face_art.position = Vector2(15, 15) if index == 1 else Vector2(22, 30)
			face_art.size = Vector2(54, 54)
			lines.offset_left = 86 if index == 1 else 91
			lines.offset_right = -54 if index == 1 else -32
			lines.offset_top = 14 if index == 0 else 5
		card.add_child(lines)
		var art_name := _make_label(20)
		art_name.add_theme_color_override("font_color", Color("fff0b0") if index == 1 and Kit.Observatory.active else PLAYER_TEXT_COLORS[index])
		art_name.add_theme_constant_override("outline_size", 5)
		art_name.add_theme_color_override("font_outline_color", Color(0, 0.05, 0.2))
		art_name.clip_text = true
		lines.add_child(art_name)
		var bar_color: Color = Color("ffe17a") if index == 1 and Kit.Observatory.active else PLAYER_TEXT_COLORS[index]
		var art_bar := Kit.bar(0.0, bar_color, 10)
		if Kit.Observatory.active and index == 1:
			# 상대 그림에 그려진 홈 안에 채워지는 부분만 얹는다.
			art_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
			_hud_player_progress(card, art_bar)
			var gap := Control.new()
			gap.custom_minimum_size.y = 10
			lines.add_child(gap)
		else:
			lines.add_child(art_bar)
		var art_detail := _make_label(16)
		art_detail.add_theme_color_override("font_color", Color(1, 1, 1, 0.88))
		art_detail.clip_text = true
		lines.add_child(art_detail)
		_player_cards.append({"panel": null, "skin": skin, "face": face_art, "name": art_name, "bar": art_bar, "detail": art_detail})
		return card
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
	var name_label := _make_label(20)
	name_label.add_theme_color_override("font_color", PLAYER_TEXT_COLORS[index])
	name_label.clip_text = true
	info.add_child(name_label)
	var bar := Kit.bar(0.0, PLAYER_TEXT_COLORS[index], 12)
	info.add_child(bar)
	var detail := _make_label(16)
	detail.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	detail.clip_text = true
	info.add_child(detail)
	_player_cards.append({"panel": panel, "face": face, "name": name_label, "bar": bar, "detail": detail})
	return panel


## 상대 정보판 그림에 포함된 진행 홈의 안쪽에 막대를 맞춘다.
func _hud_player_progress(card: Control, progress: ProgressBar) -> void:
	progress.custom_minimum_size.y = 0
	progress.anchor_left = 0.22
	progress.anchor_right = 0.91
	progress.anchor_top = 0.505
	progress.anchor_bottom = 0.606
	card.add_child(progress)


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
		if parts["panel"] == null:
			# 그림 정보판은 지금 차례인 쪽만 밝게, 아닌 쪽은 살짝 어둡게.
			parts["skin"].modulate = Color.WHITE if current or Kit.Observatory.active else Color(0.66, 0.7, 0.82)
			continue
		var edge: Color = PLAYER_TEXT_COLORS[index] if current else Color("8fd0ff")
		parts["panel"].add_theme_stylebox_override("panel", Kit.plate(Color("243a9c") if current else Color(0.1, 0.16, 0.42, 0.86), edge if current else Color("8fa6d8"), 16.0, 8, false))


## 칸 효과를 보드 위에 크게 띄운다. 좋은 일은 금색, 나쁜 일은 붉은색.
## 어빌리티·카드를 썼을 때: 쓴 사람의 말풍선과 가운데 알림. 내가 쓴 것은 말풍선만(이미 눌러서 알고 있으니 빠르게).
func _show_used(event: Dictionary, shout: String, title: String) -> void:
	var who := int(event["player"])
	_say(who, shout)
	if _humans[who]:
		return
	await _show_tile({"tile": "", "good": false, "text": "%s\n%s" % [title, event.get("text", "")], "small": true})


## 꺼진 스킬 버튼을 눌렀다 떼면 설명 창을 연다(켜진 버튼은 바로 스킬을 쓴다).
func _on_ability_input(event: InputEvent, slot: String) -> void:
	var button: Button = _ability_buttons[slot]
	if not button.disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_show_skill_info(slot)


## 세 영웅의 스킬 설명 창. focus 자리의 스킬은 금색 테로 강조한다.
func _show_skill_info(focus: String) -> void:
	if game == null:
		return
	_play("click")
	var viewer := _viewer()
	var me: Dictionary = game.players[viewer]
	var body := Kit.vbox(8)
	for slot in Game.SLOTS:
		var character: Dictionary = game.char_of(viewer, slot)
		var ability: Dictionary = game.ability_of(viewer, slot)
		var card := Kit.panel(SLOT_COLORS[slot].darkened(0.45), Kit.TRIM if slot == focus else SLOT_COLORS[slot].lightened(0.3), 8)
		body.add_child(card)
		var row := Kit.hbox(12)
		card.add_child(row)
		var face := Portrait.new()
		face.custom_minimum_size = Vector2(76, 76)
		face.border = SLOT_COLORS[slot].lightened(0.4)
		face.border_width = 3.0
		face.show_character(character, SLOT_COLORS[slot].darkened(0.3))
		row.add_child(face)
		var info_icon := GameData.ability_icon_rect(str(character.get("ability", "")), 64.0)
		if info_icon != null:
			row.add_child(info_icon)
		var words := Kit.vbox(2)
		row.add_child(Kit.expand(words))
		var head := Kit.hbox(8)
		words.add_child(head)
		head.add_child(Kit.label("%s · %s" % [Game.SLOT_LABELS[slot], character.get("name", "")], 18, Kit.MUTED))
		var is_ready: bool = _waiting_for_player and game.can_use_ability(slot)
		var gauge_label := Kit.label("사용 가능!" if is_ready else "게이지 %d%%" % int(me["gauge"][slot]), 18, Kit.GOLD if is_ready else Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		head.add_child(Kit.expand(gauge_label))
		words.add_child(Kit.label(str(ability.get("name", "-")), 26, Kit.GOLD))
		words.add_child(Kit.para(str(ability.get("text", "")), 20))
	body.add_child(Kit.para("게이지가 100%가 되면 내 차례에 버튼이 금빛으로 빛나고, 누르면 스킬을 써요.", 18, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	app.dialog("스킬 설명", body, [["닫기", Kit.PANEL_LIGHT]], 760)


## 스킬 알림 띠: 왼쪽에서 미끄러져 나와 영웅 얼굴·스킬 이름·한 줄 설명을 보여 주고 잠시 뒤 들어간다.
## 판 가운데를 가리지 않고 무슨 스킬이 발동됐는지 알려 준다(모두의 마블의 스킬 알림처럼).
func _notify(character: Dictionary, title: String, text: String, color: Color) -> void:
	if app.instant or _board_area == null:
		return
	var strip := PanelContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", Kit.plate(Color(0.08, 0.06, 0.26, 0.94), color.lightened(0.2), 18.0, 10, false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(row)
	var face := Portrait.new()
	face.custom_minimum_size = Vector2(64, 64)
	face.border = Color("ffcf4d")
	face.border_width = 3.0
	face.show_character(character, color.darkened(0.4))
	row.add_child(face)
	var notify_icon := GameData.ability_icon_rect(str(character.get("ability", "")), 54.0)
	if notify_icon != null:
		row.add_child(notify_icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var name_label := _make_label(22, "%s의 %s" % [character.get("name", ""), title])
	name_label.add_theme_color_override("font_color", Color("ffd45a"))
	words.add_child(name_label)
	var detail := _make_label(16, text)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(300, 0)
	words.add_child(detail)
	_board_area.add_child(strip)
	strip.size = strip.get_combined_minimum_size()
	strip.position = Vector2(-strip.size.x - 20.0, 150.0)
	var slide := strip.create_tween()
	slide.tween_property(strip, "position:x", 118.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slide.tween_interval(_read_time(text, 3.5, 6.0))
	slide.tween_property(strip, "position:x", -strip.size.x - 20.0, 0.25).set_ease(Tween.EASE_IN)
	slide.tween_callback(strip.queue_free)


## 카드 연출: 카드가 손(왼쪽 줄)에서 날아와 가운데서 커지며 번쩍이고, 쓴 사람의 말로 날아가 터진다.
## 안내 음성(announcer). delay초 뒤에 말한다.
func _announce(kind: String, delay: float = 0.0) -> void:
	if delay <= 0.0:
		app.say("announcer", kind)
	else:
		get_tree().create_timer(delay).timeout.connect(app.say.bind("announcer", kind))


## 전투 상대가 영웅이 아니면 그 적의 음성 이름(enemy_gate·enemy_boss·enemy_keeper·enemy_monster). 영웅이면 "".
func _enemy_voice(event: Dictionary) -> String:
	if str(event.get("target", "")) == "ambush":
		return "enemy_monster"
	if str(event.get("target", "")) != "keeper":
		return ""
	var enemy_name := str(event.get("defender", ""))
	if enemy_name == _goal_name():
		return "enemy_boss"
	return "enemy_gate" if enemy_name.begins_with("관문지기") else "enemy_keeper"


func _show_card(event: Dictionary) -> void:
	var who := int(event["player"])
	_say(who, "카드 %s!" % event["name"])
	if app.instant:
		return
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := _box(Color("f3e6c4"), Color("7a4a12"), 5)
	paper.set_corner_radius_all(18)
	paper.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", paper)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 6)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inside)
	var art := ArtView.new()
	art.show_art("cards/" + str(event.get("id", "")))
	art.custom_minimum_size = Vector2(260, 260)
	art.focus_y = 0.5
	inside.add_child(art)
	var name_label := _make_label(30, str(event["name"]))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color("3a2408"))
	inside.add_child(name_label)
	var note := _make_label(18, str(event.get("text", "")))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(260, 0)
	note.add_theme_color_override("font_color", Color("5a3a12"))
	inside.add_child(note)
	add_child(card)
	await get_tree().process_frame
	if not is_instance_valid(card):
		return
	card.size = card.get_combined_minimum_size()
	card.pivot_offset = card.size * 0.5
	var middle := _board_center() - card.size * 0.5
	var start := Vector2(-card.size.x * 0.4, middle.y) if who == _viewer() else Vector2(size.x, middle.y - 200.0)
	card.position = start
	card.scale = Vector2(0.25, 0.25)
	card.rotation = -0.5 if who == _viewer() else 0.5
	_play("card")
	var arrive := create_tween().set_parallel(true)
	arrive.tween_property(card, "position", middle, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	arrive.tween_property(card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	arrive.tween_property(card, "rotation", 0.0, 0.28)
	await arrive.finished
	_play("sparkle")
	_fx.flash(Color(1.0, 0.95, 0.7, 0.5), 0.3)
	_fx.burst(_board_center(), "spark", 22, 1.1)
	await get_tree().create_timer(0.75 if not _humans[who] else 0.5).timeout
	if not is_instance_valid(card):
		return
	_play("whoosh")
	var target := _piece_spot(who) - card.size * 0.5
	var leave := create_tween().set_parallel(true)
	leave.tween_property(card, "position", target, 0.25).set_ease(Tween.EASE_IN)
	leave.tween_property(card, "scale", Vector2(0.1, 0.1), 0.25).set_ease(Tween.EASE_IN)
	leave.tween_property(card, "modulate:a", 0.3, 0.25)
	await leave.finished
	if is_instance_valid(card):
		card.queue_free()
	_fx.burst(_piece_spot(who), "star", 16)


func _show_tile(event: Dictionary) -> void:
	# 결과 창이 떠 있으면 칸 알림을 띄우지 않는다(결과 창을 가리지 않게).
	if _result_overlay != null and _result_overlay.visible:
		return
	var good := bool(event.get("good", true))
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color := Color("ffcf4d") if good else Color("ff6b6b")
	panel.add_theme_stylebox_override("panel", Kit.plate(Color(0.12, 0.16, 0.5, 0.96), color, 20.0, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var icon_name := str(event.get("tile", ""))
	if icon_name == "attr":
		icon_name = "attr_hero"
	var glossy_name := str(BoardView.GLOSSY_ICONS.get(icon_name, icon_name))
	if ResourceLoader.exists("res://assets/ui_icons/%s.png" % glossy_name):
		row.add_child(Kit.icon(glossy_name, 84.0))
	elif ResourceLoader.exists("res://assets/icons/%s.png" % icon_name):
		row.add_child(Kit.icon(icon_name, 72.0))
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
	panel.size = panel.get_combined_minimum_size()
	panel.position = _board_center() - panel.size / 2.0
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.6, 0.6)
	# 칸 종류마다 소리가 다르다(없으면 좋음/나쁨 소리).
	var tile_sound := "tile_%s" % str(event.get("tile", ""))
	_play(tile_sound if app.sfx.has(tile_sound) else ("good" if good else "bad"))
	# 칸 효과 알갱이: 보물은 금화, 좋은 일은 반짝이, 나쁜 일은 보라 연기
	if event.has("player") and not bool(event.get("small", false)):
		var spot := _piece_spot(int(event["player"]))
		if str(event.get("tile", "")) == "treasure":
			_fx.burst(spot, "coin", 20)
		elif good:
			# 좋은 일: 전진·워프는 푸른 고리와 빛, 나머지는 금빛 반짝임
			_fx.burst(spot, "heal" if str(event.get("tile", "")) in ["forward", "warp", "checkpoint"] else "spark", 16)
		elif str(event.get("tile", "")) == "prison":
			_fx.burst(spot, "bolt", 14)
		else:
			_fx.burst(spot, "smoke", 14)
			_fx.shake(_board_view, 6.0, 0.2)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22)
	# 다 읽을 수 있게 글자 수에 맞춰 띄워 둔다(짧으면 1.8초, 긴 설명은 최대 4.5초).
	tween.tween_interval(_read_time(str(event.get("text", "")), 1.8, 4.5))
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, 0.25)
	await tween.finished
	panel.queue_free()


# ---------------------------------------------------------------- 첫 판 안내

## 내 차례가 시작될 때 처음 한 번씩 알려 줄 것들.
func _turn_hints() -> void:
	if not _humans[game.current]:
		return
	if _tut_step >= 0 and game.current == 0:
		_tutorial_point()
		return
	if _hint("roll", "주사위 굴리기를 누르면 ATTACK 영웅의 이동 주사위만큼 걸어가요. 꾹 누르면 세기 막대가 나와서 낮게·높게를 노릴 수 있어요. 파란 테두리 초상화가 내 말이에요. 먼저 골(분홍 칸)의 수호자를 이기면 승리!"):
		return
	if not game.players[game.current]["hand"].is_empty() and _hint("card", "아이템 카드는 주사위를 굴리기 전에 눌러서 써요. 손에는 3장까지 들 수 있어요."):
		return
	for slot in Game.SLOTS:
		if game.can_use_ability(slot):
			_hint("ability", "어빌리티 게이지가 찼어요! 노란 테두리 버튼을 누르면 쓸 수 있어요. 한 턴에 하나만 쓸 수 있어요.")
			return


## 길잡이 첫 판(2026-11-20): 손에 카드 한 장, ATTACK 게이지 가득. 카드·스킬·주사위 안내는 이미 본 것으로 둔다.
func _setup_tutorial() -> void:
	_tut_step = -1
	if not _tutorial or not _humans[0] or not app.has_profile():
		return
	var guide: Dictionary = app.data.get("guide", {}).get("tutorial", {})
	var card := str(guide.get("match_card", ""))
	if game.cards.has(card):
		game.players[0]["hand"] = [card]
	game.players[0]["gauge"]["attack"] = 100
	# 첫 판 한정 행운: 컴퓨터가 앞서 있으면 내 주사위만 큰 눈이 잘 나온다.
	game.lucky_player = 0
	if not app.profile.has("tutorial"):
		app.profile["tutorial"] = {}
	for key in ["roll", "card", "ability"]:
		app.profile["tutorial"][key] = true
	_tut_step = 0


func _tutorial_steps() -> Array:
	return app.data.get("guide", {}).get("tutorial", {}).get("match_steps", [])


## 지금 단계의 버튼을 가리킨다. 못 하는 단계(카드가 없거나 스킬을 못 씀)는 건너뛴다.
func _tutorial_point() -> void:
	var steps := _tutorial_steps()
	while _tut_step >= 0 and _tut_step < steps.size():
		var spec: Dictionary = steps[_tut_step]
		var id := str(spec.get("id", ""))
		if id == "card" and game.players[0]["hand"].is_empty():
			_tut_step += 1
		elif id == "skill" and not game.can_use_ability("attack"):
			_tut_step += 1
		else:
			app.guide_point(spec)
			return
	_tut_step = -1
	app.guide_point({})


## 길잡이 단계의 일을 했으면 다음 단계로.
func _tutorial_next(kind: String) -> void:
	if _tut_step < 0:
		return
	var steps := _tutorial_steps()
	if _tut_step < steps.size() and str(steps[_tut_step].get("id", "")) == kind:
		_tut_step += 1
		if kind == "roll":
			_tut_step = -1
			app.guide_point({})
		else:
			_tutorial_point()


## 처음 보는 상황이면 말풍선을 띄우고 true. 이미 본 안내면 false.
func _hint(key: String, text: String) -> bool:
	if not app.has_profile():
		return false
	# 판이 끝나 결과 창이 떠 있으면 안내를 띄우지 않는다.
	if _result_overlay != null and _result_overlay.visible:
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
	# UI 개편 3단계: 판 가운데를 가리지 않게 아래 스킬 카드 줄 바로 위에, 낮고 넓게 띄운다.
	var plate = Kit.plate(Color(0.12, 0.16, 0.5, 0.97), Kit.TRIM, 18.0, 10)
	plate.content_margin_left = 18
	plate.content_margin_right = 12
	bubble.add_theme_stylebox_override("panel", plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bubble.add_child(row)
	var label := _make_label(18, text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("line_spacing", -2)
	row.add_child(label)
	var ok := MenuArt.pill_button("알겠어요", "green", "s")
	ok.custom_minimum_size = Vector2(124, 46)
	ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func(): bubble.queue_free())
	row.add_child(ok)
	add_child(bubble)
	# 전투·결과 같은 큰 연출 층보다 아래에 둔다(결과 창 위에 안내가 겹치지 않게).
	if _battle_overlay != null and is_instance_valid(_battle_overlay):
		move_child(bubble, _battle_overlay.get_index())
	bubble.anchor_left = 0.0
	bubble.anchor_right = 1.0
	bubble.anchor_top = 1.0
	bubble.anchor_bottom = 1.0
	bubble.offset_left = 410
	bubble.offset_right = -180
	# 아래 스킬 카드 줄(높이 112) 바로 위에 붙이고, 내용만큼 위로 자란다.
	bubble.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bubble.offset_bottom = -118
	bubble.offset_top = -118
	_hint_bubble = bubble
	# '알겠어요'를 누를 때까지 그대로 둔다(저절로 사라지지 않는다).
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
		var box: StyleBox = button.get_theme_stylebox(state).duplicate()
		box.content_margin_left = ABILITY_PORTRAIT_WIDTH + 14.0
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
	box.set_corner_radius_all(16)
	box.set_content_margin_all(8)
	box.anti_aliasing_size = 1.2
	if border_width > 0:
		box.border_width_bottom = border_width + 2
		box.shadow_color = Color(0, 0.04, 0.16, 0.35)
		box.shadow_size = 5
		box.shadow_offset = Vector2(0, 3)
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
	_paint_pill(_auto_button, "green" if _auto else "blue", Color("f39a1c") if _auto else Color("6f9bd6"))
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
	_paint_pill(_speed_button, "green" if _fast() else "blue", Color("f39a1c") if _fast() else Color("27a35a"))


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
	var toggle: Button
	var orb := _stretch("round_purple")
	if orb == null:
		toggle = Kit.round_shortcut("한마디", "chat", Color("7d4fc0"))
	else:
		# 보라 구슬 버튼에 말풍선 그림.
		toggle = Button.new()
		toggle.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for state in ["normal", "hover", "pressed", "disabled"]:
			toggle.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_skin_button(toggle, orb)
		var bubble_icon: TextureRect = null if Kit.Observatory.active else _stretch("ic_chat", TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		if bubble_icon != null:
			bubble_icon.show_behind_parent = false
			bubble_icon.anchor_left = 0.24
			bubble_icon.anchor_right = 0.76
			bubble_icon.anchor_top = 0.16
			bubble_icon.anchor_bottom = 0.64
			bubble_icon.offset_left = 0
			bubble_icon.offset_right = 0
			bubble_icon.offset_top = 0
			bubble_icon.offset_bottom = 0
			toggle.add_child(bubble_icon)
		toggle.add_child(_art_label("한마디", 14, Rect2(0.0, 0.6, 1.0, 0.3)))
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
	if Kit.Observatory.active:
		_hud_rect(toggle, Rect2(1558, 422, 100, 101))
	toggle.pressed.connect(_toggle_emotes)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Kit.plate(Color(0.12, 0.16, 0.5, 0.96), Kit.TRIM, 18.0, 12))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(grid)
	for text in EMOTES:
		# 한마디 버튼: 보라 금테 알약(특별)
		var button := MenuArt.pill_button(text, "purple", "m")
		button.custom_minimum_size = Vector2(150, 56)
		button.add_theme_font_size_override("font_size", 20)
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


## 알림을 읽는 데 필요한 시간(초): 기본 shortest초에 글자당 0.06초를 더하고 longest초에서 멈춘다.
func _read_time(text: String, shortest: float, longest: float) -> float:
	return clampf(shortest + 0.06 * maxf(0.0, float(text.length()) - 8.0), shortest, longest)


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
	tween.tween_interval(_read_time(text, 2.4, 4.0))
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
	# 크고 둥근 노란 광택 버튼
	Kit.paint(button, Color("ffc62b"), Color("6b3b00"))
	var gloss = button.get_node("Gloss")
	gloss.radius = 80.0
	gloss.depth = 10.0
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color("4a2600"))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))
	button.add_theme_constant_override("outline_size", 6)
	button.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.85))
	var crystal: Texture2D = _match_tex("roll_crystal")
	if crystal == null:
		crystal = GameData.object("roll_button")
	if crystal != null:
		# 원작처럼 판 위에 놓인 입체 굴리기 버튼. 상태 글자는 버튼 아래 작은 띠에 따로 쓴다.
		gloss.visible = false
		_roll_art = TextureRect.new()
		_roll_art.texture = crystal
		_roll_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_roll_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_roll_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_roll_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_roll_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_roll_art.offset_bottom = 0 if Kit.Observatory.active else -22
		button.add_child(_roll_art)
		_roll_caption = _make_label(18)
		_roll_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_roll_caption.add_theme_constant_override("outline_size", 7)
		_roll_caption.add_theme_color_override("font_outline_color", Color("0a1a4a"))
		_roll_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_roll_caption.anchor_left = 0.0
		_roll_caption.anchor_right = 1.0
		_roll_caption.anchor_top = 1.0
		_roll_caption.anchor_bottom = 1.0
		_roll_caption.offset_top = -30
		_roll_caption.offset_bottom = 0
		if Kit.Observatory.active:
			_roll_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_roll_caption.anchor_top = 0.67
			_roll_caption.anchor_bottom = 0.84
			_roll_caption.offset_top = 0
			_roll_caption.add_theme_font_size_override("font_size", 22)
		button.add_child(_roll_caption)
		# 누르거나 꺼지면 수정 그림도 따라 바뀐다.
		button.draw.connect(func() -> void:
			var down := button.get_draw_mode() == BaseButton.DRAW_PRESSED or button.get_draw_mode() == BaseButton.DRAW_HOVER_PRESSED
			_roll_art.modulate = Color(0.5, 0.52, 0.62) if button.disabled else Color.WHITE
			_roll_art.offset_top = 8.0 if down else 0.0)
	return button


## 굴리기 버튼의 상태 글자. 입체 버튼 그림을 쓸 때는 버튼 아래 작은 띠에 한 줄로 쓴다.
func _set_roll_text(text: String) -> void:
	if _roll_caption != null:
		_roll_caption.text = text.replace("\n", " ")
	else:
		_roll_button.text = text


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
func _make_card_button(framed: bool = false) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(100, 118) if not framed else Vector2.ZERO
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
	# 카드 그림(assets/art/cards/<카드 id>.jpg)과 그 아래 이름 띠. 그림이 없으면 글자만 보인다.
	var art := ArtView.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 4
	art.offset_right = -4
	art.offset_top = 15
	art.offset_bottom = -34
	art.focus_y = 0.5
	button.add_child(art)
	var name_label := Label.new()
	name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_top = -34
	name_label.offset_bottom = -6
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color("3a2408"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(name_label)
	button.set_meta("art", art)
	button.set_meta("name_label", name_label)
	if framed:
		# 금테 칸 안에 들어가는 카드: 종이 상자 없이 그림을 칸에 꽉 채우고 이름은 흰 글자로.
		for state in ["normal", "hover", "pressed", "disabled"]:
			var clear := StyleBoxFlat.new()
			clear.bg_color = Color(1, 1, 1, 0.0) if state != "hover" else Color(1, 1, 1, 0.12)
			clear.set_corner_radius_all(6)
			clear.set_content_margin_all(4)
			button.add_theme_stylebox_override(state, clear)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, Color.WHITE)
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_constant_override("outline_size", 5)
		button.add_theme_color_override("font_outline_color", Color(0, 0.05, 0.2))
		art.offset_left = 2
		art.offset_right = -2
		art.offset_top = 2
		art.offset_bottom = -2
		name_label.offset_top = -24
		name_label.offset_bottom = -2
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.add_theme_constant_override("outline_size", 5)
		name_label.add_theme_color_override("font_outline_color", Color(0, 0.05, 0.2))
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


# ---------------------------------------------------------------- 그림 부품

func _match_tex(name: String, use_reference: bool = true) -> Texture2D:
	if use_reference and Kit.Observatory.active:
		var reference_path := REFERENCE_HUD_ART + name + ".png"
		if ResourceLoader.exists(reference_path):
			return load(reference_path)
	var themed := Kit.Observatory.texture("ui_match", name)
	if themed != null:
		return themed
	var path: String = MATCH_ART + name + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return null


## 가운데만 늘어나는 그림 판(모서리·끝 장식은 그대로). 그림을 scale_by배로 줄여 그려서
## 판 높이에 그림 높이를 맞춘다. margins는 그림 픽셀로 (왼쪽, 위, 오른쪽, 아래). 그림이 없으면 null.
func _patch(name: String, margins: Vector4, scale_by: float) -> Control:
	var tex := _match_tex(name)
	if tex == null:
		return null
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var patch := NinePatchRect.new()
	patch.texture = tex
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	patch.patch_margin_left = int(margins.x)
	patch.patch_margin_top = int(margins.y)
	patch.patch_margin_right = int(margins.z)
	patch.patch_margin_bottom = int(margins.w)
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.scale = Vector2.ONE * scale_by
	wrap.add_child(patch)
	wrap.resized.connect(func() -> void: patch.size = wrap.size / scale_by)
	return wrap


## 그림 한 장을 꽉 채워 깐다(기본은 비율 무시). 그림이 없으면 null.
func _stretch(name: String, mode: int = TextureRect.STRETCH_SCALE) -> TextureRect:
	var tex := _match_tex(name)
	if tex == null:
		return null
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = mode
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.show_behind_parent = true
	return rect


## 버튼 몸통을 그림으로 바꾼다. 광택 몸통은 숨기고, 눌림·꺼짐·올림은 그림 밝기로 보인다.
func _skin_button(button: Button, body: Control) -> void:
	var gloss = button.get_node_or_null("Gloss")
	if gloss != null:
		gloss.visible = false
	body.show_behind_parent = true
	button.add_child(body)
	button.move_child(body, 0)
	button.set_meta("skin", body)
	button.draw.connect(func() -> void:
		var mode := button.get_draw_mode()
		var tint := Color.WHITE
		if button.disabled and not (Kit.Observatory.active and button.has_meta("title")):
			tint = Color(0.55, 0.57, 0.68)
		elif mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED:
			tint = Color(0.82, 0.82, 0.86)
		elif mode == BaseButton.DRAW_HOVER:
			tint = Color(1.12, 1.12, 1.12)
		var skin: Control = button.get_meta("skin")
		skin.modulate = tint)


## 그림 버튼 위의 글자. area는 버튼 크기에 대한 비율(x, y, 너비, 높이).
func _art_label(text: String, font_size: int, area: Rect2) -> Label:
	var label := _make_label(font_size, text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0, 0.05, 0.2))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = area.position.x
	label.anchor_right = area.position.x + area.size.x
	label.anchor_top = area.position.y
	label.anchor_bottom = area.position.y + area.size.y
	label.offset_left = 0
	label.offset_right = 0
	label.offset_top = 0
	label.offset_bottom = 0
	return label


## 알약 모양 그림 버튼(파랑·초록·빨강). 그림이 없으면 예전 광택 버튼 색으로 칠한다.
func _paint_pill(button: Button, kind: String, fallback: Color) -> void:
	var tex := _match_tex("btn_" + kind)
	if tex == null:
		Kit.paint(button, fallback)
		return
	if not button.has_meta("skin"):
		var pill: Control = _stretch("btn_" + kind) if Kit.Observatory.active else _patch("btn_" + kind, Vector4(52, 0, 52, 0), button.custom_minimum_size.y / 104.0)
		_skin_button(button, pill)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var space := StyleBoxEmpty.new()
			space.set_content_margin_all(8)
			# 2026-11-19 새 알약 그림: 양 끝 보석(높이의 약 0.4배)에 글자·아이콘이 닿지 않게 띄운다.
			var side := 9.0 if Kit.Observatory.active else maxf(14.0, button.custom_minimum_size.y * 0.42)
			space.content_margin_left = side
			space.content_margin_right = side
			space.content_margin_bottom = 10 if state != "pressed" else 8
			button.add_theme_stylebox_override(state, space)
	var holder: Control = button.get_meta("skin")
	if holder is TextureRect:
		holder.texture = tex
	else:
		var patch := holder.get_child(0) as NinePatchRect
		patch.texture = tex
	button.add_theme_constant_override("outline_size", 6)
	button.add_theme_color_override("font_outline_color", PILL_OUTLINE.get(kind, Color(0, 0, 0)))


## 알약 버튼 글자 앞에 작은 그림 아이콘.
func _pill_icon(button: Button, icon_name: String) -> void:
	var tex := _match_tex(icon_name)
	if tex == null:
		return
	button.icon = tex
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", 24)
	button.add_theme_constant_override("h_separation", 4)


## 그림 스킬 카드 버튼(빨강 공격·보라 방어·초록 지력). 위 띠에 스킬 이름, 왼쪽 칸에 영웅,
## 오른쪽에 자리 이름·게이지 글자, 아래 홈에 게이지 막대.
func _make_skill_button(slot: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(SKILL_WIDTH, 104)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_skin_button(button, _stretch(SKILL_ART[slot]))
	# 글자: 스킬 이름 17, 자리 이름·게이지 숫자 16(넘치면 잘라 낸다).
	var title := _art_label("", 17, Rect2(0.15, 0.18, 0.70, 0.25) if Kit.Observatory.active else Rect2(0.13, 0.0, 0.74, 0.25))
	title.clip_text = true
	button.add_child(title)
	var body := _art_label("", 16, Rect2(0.39, 0.34, 0.55, 0.22) if Kit.Observatory.active else Rect2(0.38, 0.29, 0.58, 0.46))
	body.add_theme_constant_override("line_spacing", -4)
	body.clip_text = true
	button.add_child(body)
	if Kit.Observatory.active:
		var status := _art_label("", 16, Rect2(0.39, 0.485, 0.55, 0.23))
		# 역할과 충전 상태의 글자 크기를 유지하고 외곽선이 닿지 않도록 한다.
		body.add_theme_constant_override("outline_size", 2)
		status.add_theme_constant_override("outline_size", 2)
		status.clip_text = true
		button.add_child(status)
		button.set_meta("gauge_status", status)
	var portrait := Portrait.new()
	portrait.border_width = 0.0
	if Kit.Observatory.active:
		# 금테를 덮지 않도록 그림 칸의 안쪽과 둥근 모서리에 맞춘다.
		var window := Panel.new()
		window.mouse_filter = Control.MOUSE_FILTER_IGNORE
		window.anchor_left = 0.076
		window.anchor_right = 0.293
		window.anchor_top = 0.285
		window.anchor_bottom = 0.815
		window.add_theme_stylebox_override("panel", Kit.box(Color.WHITE, Color.TRANSPARENT, 0, 4, 0))
		window.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		button.add_child(window)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		window.add_child(portrait)
	else:
		portrait.anchor_left = 0.1
		portrait.anchor_right = 0.348
		portrait.anchor_top = 0.35
		portrait.anchor_bottom = 0.8
		button.add_child(portrait)
	# 어빌리티 아이콘: 초상화 오른쪽 아래 귀퉁이에 작은 메달로 겹친다.
	var badge := TextureRect.new()
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.anchor_left = 0.25
	badge.anchor_right = 0.25
	badge.anchor_top = 0.58
	badge.anchor_bottom = 0.58
	badge.offset_right = 34
	badge.offset_bottom = 34
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge)
	button.set_meta("badge", badge)
	var gauge := _make_skill_gauge(8.0)
	gauge.anchor_left = 0.445
	gauge.anchor_right = 0.9
	gauge.anchor_top = 0.758
	gauge.anchor_bottom = 0.82
	if Kit.Observatory.active:
		gauge.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		# 세 스킬 그림에 공통으로 들어 있는 게이지 홈의 안쪽 경계.
		gauge.anchor_left = 0.345
		gauge.anchor_right = 0.913
		gauge.anchor_top = 0.683
		gauge.anchor_bottom = 0.804
	button.add_child(gauge)
	if Kit.Observatory.active:
		button.move_child(gauge, badge.get_index())
	Kit.shimmer(button, float(Game.SLOTS.find(slot)) * 0.4)
	button.set_meta("title", title)
	button.set_meta("body", body)
	_ability_gauges[slot] = gauge
	_ability_portraits[slot] = portrait
	return button


func _make_skill_gauge(height: float) -> ProgressBar:
	var gauge := Kit.bar(0.0, Kit.GOLD, height)
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.add_theme_stylebox_override("fill", Kit.box(Kit.GOLD, Color.TRANSPARENT, 0, 6, 0))
	var shine := Sweep.new()
	shine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shine.hide()
	shine.process_mode = Node.PROCESS_MODE_DISABLED
	gauge.add_child(shine)
	return gauge


func _refresh_skill_gauge(gauge: ProgressBar, charge: int, animate: bool) -> void:
	gauge.value = clampf(charge / 100.0, 0.0, 1.0)
	var fill: StyleBoxFlat = gauge.get_theme_stylebox("fill")
	if charge >= 100:
		fill.bg_color = Color("ffdb71")
	elif charge >= 67:
		fill.bg_color = Color("56e58c")
	elif charge >= 34:
		fill.bg_color = Color("49c8fa")
	else:
		fill.bg_color = Color("ff9454")
	# 사용 가능 여부와 별도로 충전 완료를 막대 안에서 보여 준다.
	var shine: Sweep = gauge.get_node("Sweep")
	var show_shine := charge >= 100 and animate
	if shine.visible != show_shine:
		shine.visible = show_shine
		shine.process_mode = Node.PROCESS_MODE_INHERIT if show_shine else Node.PROCESS_MODE_DISABLED
		if show_shine:
			shine.restart()


# ---------------------------------------------------------------- 진행

func _start_game() -> void:
	_hide_path_choices()
	game = Game.new()
	# 내 파티(0번)에는 장착한 유물의 시작 보너스가 붙는다. 친구 대전은 공평하게 쓰지 않는다.
	if _mode != "local" and not _parties.is_empty():
		_parties[0]["relic"] = Profile.current_relic(app.profile, app.eco).get("effect", {})
		# 내 카드 덱: 판에서는 덱에 넣은 카드만 뽑힌다. 상대(AI)는 모든 카드에서 뽑는다.
		_parties[0]["deck"] = Profile.battle_deck(app.profile, _data.get("cards", {}), app.eco)
	# 랭크전은 트로피가 높을수록 상대가 강해진다.
	if _mode == "rank" and _parties.size() > 1:
		_parties[1]["relic"] = Profile.rank_boost(app.eco, int(app.profile.get("trophies", 0)))
	game.setup(_data, _parties)
	_setup_tutorial()
	_start_distance = max(game.distance_of(0), 1)
	for index in 2:
		_board_view.piece_textures[index] = GameData.portrait(str(game.char_of(index, "attack").get("id", "")))
		_board_view.piece_standees[index] = GameData.standee(str(game.char_of(index, "attack").get("id", "")))
		_board_view.piece_anims[index] = GameData.standee_anims(str(game.char_of(index, "attack").get("id", "")))
		_board_view.party_anims[index] = [
			GameData.standee_anims(str(game.char_of(index, "defense").get("id", ""))),
			GameData.standee_anims(str(game.char_of(index, "support").get("id", "")))]
		_board_view.party_standees[index] = [
			GameData.standee(str(game.char_of(index, "defense").get("id", ""))),
			GameData.standee(str(game.char_of(index, "support").get("id", "")))]
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
	_paint_pill(_auto_button, "blue", Color("6f9bd6"))
	_auto_button.visible = not _is_local()
	_clear_results()
	_add_result_text("%s 파티: %s" % [game.players[1]["name"], _party_names(1)], PLAYER_TEXT_COLORS[1])
	_add_result_text("맵: %s(%s)  ·  골의 수호자: %s\n먼저 골(분홍 칸)의 수호자를 이기고 들어가면 승리!" % [game.board_name, game.board_shape, _goal_name()], Color.WHITE)
	_refresh()
	var playing = game
	_play("versus")
	_announce("start", 0.8)
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
	var bonus_parts: Array = []
	var categories: Array = []
	for member in members:
		categories.append(str(member.get("category", "")))
	var synergy: Dictionary = Game.synergy_of(_data.get("rules", {}).get("synergy", {}), categories)
	if not synergy.is_empty():
		bonus_parts.append("시너지 %s" % synergy.get("name", ""))
	if not (game.players[index].get("relic", {}) as Dictionary).is_empty():
		bonus_parts.append("유물" if index == 0 else "강화")
	return {"name": str(game.players[index]["name"]), "color": PLAYER_TEXT_COLORS[index], "members": members, "levels": levels,
		"power": Profile.party_power(_data["characters"], app.eco, party, level_table), "bonus": " · ".join(PackedStringArray(bonus_parts))}


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
		_play("banner")
		if turns_left == 1:
			_announce("last_turn")
		elif _is_local() or game.current == 0:
			_announce("turn")
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
	var happy: bool = game.winner == 0 or _is_local()
	# 배경음악이 켜져 있으면 승리·패배 곡이 나오므로 효과음은 음악을 껐을 때만 낸다.
	if not app.bgm_on():
		_play("fanfare" if happy else "defeat")
	if happy:
		_fx.flash(Color(1.0, 0.95, 0.6, 0.6), 0.5)
		_fx.shower("petal", 70)
		_fx.rays(true, size * Vector2(0.5, 0.36), Color(1.0, 0.9, 0.4, 0.16))
		move_child(_fx, get_child_count() - 1)
	else:
		_fx.flash(Color(0.1, 0.0, 0.2, 0.6), 0.8)
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
	_tutorial_next("roll")
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
	if game.choice_kind() != "fight":
		_hint("fork", "갈림길이에요! 지도와 칸 수를 비교하고 갈 길을 골라요. 지도에서 길과 버튼은 같은 색이에요.")
		_board_view.highlight = game.pending_choice["options"].duplicate()
		_board_view.queue_redraw()
		_result_panel.modulate.a = 0.0
		var choices := ForkChoices.new()
		choices.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		choices.offset_left = -340
		choices.offset_right = 340
		choices.offset_top = 98
		choices.chosen.connect(_on_path_chosen)
		choices.setup(game)
		_board_area.add_child(choices)
		_path_choices = choices
		return
	_hint("fight", "상대 말을 지나칩니다! '싸운다'를 고르면 내 ATTACK과 상대 DEFENSE가 주사위로 겨뤄요. 이기면 상대가 거점으로 돌아가요.")
	_board_view.highlight = [int(game.players[game.current]["pos"])]
	_add_result_text("상대 말을 지나칩니다! 싸울까요? (남은 이동 %d칸)" % int(game.pending_choice["steps"]), Color("ff8a6a"))
	_board_view.queue_redraw()
	_show_fight_choices()


## 상대를 만났을 때 두 버튼을 판 위에 배치한다. 글자는 현재 언어로 표시한다.
func _show_fight_choices() -> void:
	var row := Kit.hbox(16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in FIGHT_CHOICE_ART.size():
		var button := _fight_choice_button(game.choice_label(index), index)
		button.pressed.connect(_on_path_chosen.bind(index))
		row.add_child(Kit.expand(button))
	_board_area.add_child(row)
	_hud_rect(row, Rect2(514, 204, 714, 122))
	_path_choices = row
	_result_panel.hide()


func _fight_choice_button(caption: String, index: int) -> Button:
	var art := _stretch(FIGHT_CHOICE_ART[index])
	if art == null:
		return MenuArt.pill_button(caption, "red" if index == 0 else "blue", "l")
	var button := Button.new()
	button.accessibility_name = Lang.t(caption)
	var space := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, space)
	_skin_button(button, art)
	var label := _art_label(caption, 29, Rect2(0.43, 0.0, 0.50, 1.0))
	label.add_theme_color_override("font_color", Color("fff5db"))
	label.clip_text = true
	button.add_child(label)
	Kit.squeeze_text(label, 29, 18)
	return button


func _on_path_chosen(index: int) -> void:
	if not _choosing_path or not game.awaiting_choice():
		return
	_choosing_path = false
	_hide_path_choices()
	_board_view.highlight = []
	_clear_results()
	_flash_log()
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


func _hide_path_choices() -> void:
	if is_instance_valid(_path_choices):
		_path_choices.hide()
		_path_choices.queue_free()
		_path_choices = null
	_result_panel.show()


func _on_ability_pressed(slot: String) -> void:
	var me := _viewer()
	if _waiting_for_player and game.use_ability(slot):
		if me == 0:
			_abilities_used += 1
			_tutorial_next("skill")
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
	var picture := ArtView.new()
	picture.show_art("cards/" + str(hand[index]))
	if picture.has_art():
		picture.custom_minimum_size = Vector2(0, 260)
		picture.focus_y = 0.5
		body.add_child(picture)
	else:
		picture.free()
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
			_tutorial_next("card")
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
			"warden":
				# 분신 문지기가 서거나(마법진 빛) 무너진다(연기).
				var spot := Kit.spot_in(self, _board_view, _board_view.tile_point(int(event["pos"])))
				if bool(event.get("gone", false)):
					_fx.burst(spot, "smoke", 18, 0.9)
				else:
					_play("summon_3")
					_fx.burst(spot, "star", 24, 1.0)
					_fx.burst(spot, "spark", 14, 0.8)
					_say(int(event["player"]), "문지기 소환!")
					await get_tree().create_timer(0.0 if app.instant else 0.6).timeout
			"stand_ground":
				# 거점 복귀를 막은 어빌리티(버티기). 말 위에 방패 빛을 띄운다.
				var holder := int(event["player"])
				_say(holder, "버텼다!")
				_fx.burst(_piece_spot(holder), "heal", 22, 1.0)
			"ability":
				# 어빌리티는 영웅 그림 컷인으로 보여 준다(누가 쓰든).
				var caster := int(event["player"])
				_say(caster, "%s!" % event["name"])
				_play("skill")
				app.say(str(_character_named(str(event["hero"])).get("id", "")), "skill")
				_fx.flash(Color(1, 1, 1, 0.7), 0.25)
				_fx.speed_lines(_board_center(), PLAYER_TEXT_COLORS[caster].lightened(0.4), 1.1)
				# 영웅 분류마다 효과가 다르다: 영웅은 불꽃, 위인은 별빛, 신화는 얼음 결정, 근현대는 금빛.
				var hero_kind := str(_character_named(str(event["hero"])).get("category", ""))
				var spark_kind: String = {"영웅": "ember", "위인": "star", "신화": "ice", "근현대": "spark"}.get(hero_kind, "ember")
				var wave_tint: Color = {"영웅": Color("ff8a3a"), "위인": Color("7fd0ff"), "신화": Color("c9a0ff"), "근현대": Color("8dffb0")}.get(hero_kind, Color.WHITE)
				_fx.burst(_piece_spot(caster), spark_kind, 34, 1.3)
				_board_view.wave(caster, wave_tint)
				_notify(_character_named(str(event["hero"])), str(event["name"]), str(event.get("text", "")), PLAYER_TEXT_COLORS[caster])
				await _cutin.play(_character_named(str(event["hero"])), str(event["name"]), str(event.get("text", "")), PLAYER_TEXT_COLORS[caster])
			"card":
				await _show_card(event)
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
	# 이동 음성: 내 ATTACK 영웅이 가끔 한마디(매번 하면 시끄럽다).
	if (who == 0 or _is_local()) and _voice_rng.randf() < MOVE_VOICE_CHANCE:
		app.say(str(game.char_of(who, "attack").get("id", "")), "move")
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
		if bool(event.get("catchup", false)) and not _catchup_announced:
			_catchup_announced = true
			_announce("catchup")
		if bool(event.get("catchup", false)):
			# 많이 뒤처진 쪽은 큰 눈이 잘 나온다는 것을 알려 준다.
			caption = "%s 따라잡기! 큰 눈이 잘 나와요" % game.players[who]["name"]
		_big_dice.skin = _dice_skin_of(who)
		var doubled := bool(event.get("double", false))
		await _big_dice.play(caption, event["rolls"], ("더블! %d칸!%s" if doubled else "%d칸!%s") % [int(event["total"]), bonus_text], PLAYER_TEXT_COLORS[who])
		_fx.pop_text(_board_center() - Vector2(0, 40), "%d" % int(event["total"]), PLAYER_TEXT_COLORS[who].lightened(0.3), 150)
		_fx.burst(_board_center() - Vector2(0, 40), "spark", 16)
		if doubled:
			_say(who, "더블! 게이지 +%d%%" % game.double_gauge)
			_play("double")
			_announce("double")
			_fx.flash(Color(1.0, 0.9, 0.4, 0.45), 0.35)
			_fx.burst(_board_center() - Vector2(0, 40), "star", 24, 1.3)
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


## 관문지기·골의 수호자와 싸우는 동안에는 전투 곡을 틀고, 끝나면 대전 곡으로 돌아온다.
func _show_battle(event: Dictionary) -> void:
	var defender := str(event.get("defender", ""))
	var boss := str(event.get("target", "")) == "keeper" and (defender.begins_with("관문지기") or defender == _goal_name())
	if boss:
		app.music.play_track("boss")
	# 적(영웅이 아닌 상대)은 등장할 때와 끝났을 때 한마디 한다.
	var foe := _enemy_voice(event)
	_announce("gate" if boss else "battle")
	if foe != "":
		get_tree().create_timer(1.0).timeout.connect(app.say.bind(foe, "appear"))
	await _show_battle_inner(event)
	# 내 쪽에서 본 승패 소리. 습격은 막는 쪽이 플레이어다.
	var player_won: bool = (not bool(event["won"])) if str(event.get("target", "")) == "ambush" else bool(event["won"])
	var mine: bool = _is_local() or int(event["player"]) == 0
	if boss and player_won:
		_play("goal" if defender == _goal_name() else "gate_open")
	else:
		_play("battle_win" if player_won == mine else "battle_lose")
	if foe != "":
		app.say(foe, "lose" if player_won else "win")
	if boss and game.winner < 0:
		app.music.play_track("match")


func _show_battle_inner(event: Dictionary) -> void:
	_hint("battle", "전투! 양쪽이 주사위를 굴려 합이 큰 쪽이 이겨요. 지면 직전 거점(파란 깃발)으로 돌아가요. 이기면 카드를 받아요.")
	await _wait_for_board()
	var who := int(event["player"])
	var other := 1 - who
	# 전투 음성: 공격하는 영웅이 먼저 외치고, 조금 뒤 막는 영웅이 받아친다(영웅이 아니면 소리 없음).
	app.say(str(_character_named(str(event.get("attacker", ""))).get("id", "")), "attack")
	var defender_id := str(_character_named(str(event.get("defender", ""))).get("id", ""))
	if defender_id != "":
		get_tree().create_timer(0.9).timeout.connect(app.say.bind(defender_id, "defend"))
	if str(event.get("target", "")) == "ambush":
		_hide_log()
		await _battle_overlay.play(event, {
			"boss_name": _goal_name(),
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
	var warden_duel: bool = str(event.get("target", "")) == "warden"
	var card_duel: bool = str(event.get("target", "")) == "card"
	var against_player: bool = str(event.get("target", "")) == "player" or card_duel
	var me_attacking := who == 0 or _is_local()
	var info := {
		"attacker_side": "공격 · %s" % game.players[who]["name"],
		"defender_side": "방어 · %s" % (game.players[other]["name"] if against_player else ("관문지기" if str(event["defender"]).begins_with("관문지기") else ("골의 수호자" if str(event["defender"]) == _goal_name() else "키퍼"))),
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
	if warden_duel:
		# 분신 문지기: 상대가 세운 내 앞 문지기(상대 ATTACK 영웅의 분신)
		info["defender_side"] = "문지기 · %s" % game.players[other]["name"]
		info["defender_color"] = PLAYER_TEXT_COLORS[other]
		info["winner_text"] = "%s 승리! 문지기가 사라졌다" % game.players[who]["name"]
	if card_duel:
		# 역전의 첫걸음: 이기면 나는 앞으로, 상대는 뒤로. 지면 그대로(아무도 거점으로 가지 않는다).
		info["winner_text"] = "%s 역전! 5칸 앞으로, 상대는 5칸 뒤로" % game.players[who]["name"]
		info["loser_text"] = "%s 역전 실패... 그대로" % game.players[who]["name"]
	info["boss_name"] = _goal_name()
	info["attacker_character"] = _character_named(str(event["attacker"]))
	info["defender_character"] = _character_named(str(event["defender"]))
	_hide_log()
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


## 기록 칸은 새 소식이 있을 때만 또렷해지고, 잠시 뒤 흐려져 판을 가리지 않는다.
func _flash_log() -> void:
	if _result_panel == null:
		return
	if _log_tween != null and _log_tween.is_valid():
		_log_tween.kill()
	_result_panel.modulate.a = 1.0
	# 갈림길·싸울지 같은 선택지가 떠 있으면 고를 때까지 흐려지지 않는다.
	if _choosing_path:
		return
	_log_tween = _result_panel.create_tween()
	_log_tween.tween_interval(5.0)
	_log_tween.tween_property(_result_panel, "modulate:a", 0.0, 0.8)


## 전투처럼 화면 가운데를 쓰는 연출 동안은 기록 칸을 바로 숨긴다.
func _hide_log() -> void:
	if _log_tween != null and _log_tween.is_valid():
		_log_tween.kill()
	if _result_panel != null and not _choosing_path:
		_result_panel.modulate.a = 0.0


func _trim_results() -> void:
	_flash_log()
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
	# 처음 안내 상자가 결과 창을 가리지 않게 닫는다.
	_close_hint()
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
	# 결과 곡: 이기면(친구 대전은 누가 이기든) 승리 곡, 지면 패배 곡.
	if outcome != "draw":
		app.music.play_track("victory" if (_is_local() or outcome == "win") else "defeat")
	# 결과 음성: 내 ATTACK 영웅(친구 대전은 이긴 쪽)이 한마디.
	if outcome != "draw":
		var speaker := int(game.winner) if _is_local() else 0
		app.say(str(game.char_of(speaker, "attack").get("id", "")), "win" if (_is_local() or outcome == "win") else "lose")
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
	if not _is_local():
		details.append("뚫은 관문: %d / %d" % [(game.gates_cleared[0] as Dictionary).size(), _gate_count()])
	var record_lines := _record(outcome)
	details.append_array(record_lines)
	var shown_outcome := outcome
	if _is_local() and outcome != "draw":
		shown_outcome = "win"
	# 결과 화면(UI 개편 2단계): 결과 줄 · 알림 띠 · 파티 이름 · 보상 칸으로 나눠 보낸다.
	var extras := _result_extras()
	var rows: Array = [
		["hourglass", "진행한 턴", "%d턴" % min(game.round_number, game.max_rounds)],
		["flag", "골까지 남은 거리", "%s %d칸 · %s %d칸" % [game.players[0]["name"], game.distance_of(0), game.players[1]["name"], game.distance_of(1)]],
	]
	var notes: Array = []
	if _is_local():
		rows.append(["swords", "%s 파티" % game.players[0]["name"], _party_names(0)])
		rows.append(["swords", "%s 파티" % game.players[1]["name"], _party_names(1)])
	else:
		rows.append(["sword", "내 전투", "%d승 %d패 · 최고 합 %d" % [_my_battles[0], _my_battles[1], _best_roll]])
		rows.append(["t_gate", "뚫은 관문", "%d / %d" % [(game.gates_cleared[0] as Dictionary).size(), _gate_count()]])
		rows.append(["card", "카드 · 어빌리티", "카드 %d장 · %d번 사용" % [_cards_used, _abilities_used]])
		if _mode == "rank" and _last_reward.has("trophies"):
			rows.append(["trophy", "트로피", "%+d → %d (%s)" % [int(_last_reward["trophies"]), int(app.profile["trophies"]), str(_last_reward.get("tier_after", ""))]])
		extras["parties"] = ["내 파티: %s" % _party_names(0), "상대 파티: %s" % _party_names(1)]
	for line in record_lines:
		# 트로피 줄은 결과 줄에 이미 있으니 띠에서는 뺀다.
		if _mode == "rank" and str(line).begins_with("트로피 "):
			continue
		notes.append(str(line))
	extras["rows"] = rows
	extras["notes"] = notes
	# 보상형 광고: 이번 판 골드를 한 번 더(2026-11-19). 프리미엄 시즌 패스가 있으면 이미 광고 없이 2배라 버튼을 띄우지 않는다.
	if not _is_local() and app.has_profile() and not Profile.pass_premium(app.profile) and int(_last_reward.get("gold", 0)) > 0 and Profile.ads_left(app.profile, app.eco, "gold_double") > 0:
		extras["ad_text"] = "광고 보고 골드 +%s" % Kit.comma(int(_last_reward["gold"]))
	# 칸 알림·말풍선이 결과 창을 가리지 않게 맨 앞으로
	_close_hint()
	move_child(_result_overlay, get_child_count() - 1)
	_result_overlay.show_result(shown_outcome, subtitle, details, extras)


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
	# 얻은 보상 칸: [아이콘, 글]
	var rewards: Array = []
	if int(_last_reward.get("gold", 0)) > 0:
		rewards.append(["gold", "+%s" % Kit.comma(int(_last_reward["gold"]))])
	if int(_last_reward.get("gems", 0)) > 0:
		rewards.append(["gem", "+%s" % Kit.comma(int(_last_reward["gems"]))])
	if int(_last_reward.get("exp", 0)) > 0:
		rewards.append(["upgrade", "경험 +%d" % int(_last_reward["exp"])])
	if int(_last_reward.get("trophies", 0)) != 0:
		rewards.append(["trophy", "%+d" % int(_last_reward["trophies"])])
	if int(_last_reward.get("pass_exp", 0)) > 0:
		rewards.append(["pass", "패스 +%d" % int(_last_reward["pass_exp"])])
	extras["rewards"] = rewards
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
		"map": game.board_name, "turns": int(game.round_number), "gates": (game.gates_cleared[0] as Dictionary).size(),
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
	# 길잡이: 첫 판을 끝냈다(이기든 지든).
	app.tutorial_event("match_end")
	if _mode == "rank":
		lines.append("트로피 %+d → %d (%s)" % [int(reward["trophies"]), int(app.profile["trophies"]), reward["tier_after"]])
		if str(reward["tier_before"]) != str(reward["tier_after"]):
			lines.append("티어 변경: %s → %s" % [reward["tier_before"], reward["tier_after"]])
	if int(reward.get("streak", 0)) >= 2:
		lines.append("%d연승! 연승 보너스 골드 +%d" % [int(reward["streak"]), int(reward.get("streak_gold", 0))])
	for event in Profile.active_events(app.data.get("events", {}), app.today()):
		lines.append("이벤트 적용: %s" % event["name"])
	if int(reward.get("pass_double", 0)) > 1:
		lines.append("시즌 패스 혜택: 보상 %d배 (광고 없이)" % int(reward["pass_double"]))
	if bool(reward["first_win"]):
		lines.append("오늘 첫 승리 보너스!")
	if int(reward["level_ups"]) > 0:
		lines.append("레벨 업! 플레이어 레벨 %d" % int(app.profile["level"]))
		var level_now := int(app.profile["level"])
		if Game.point_limit_at(app.data["rules"], level_now) > Game.point_limit_at(app.data["rules"], level_now - int(reward["level_ups"])):
			lines.append("소환 포인트 한도가 %d로 늘었어요!" % Game.point_limit_at(app.data["rules"], level_now))
	# 이번 판으로 새로 받을 수 있게 된 미션·업적
	var new_missions := Profile.claimable_mission_count(app.profile, app.eco) - missions_before
	var new_achievements := Profile.claimable_achievement_count(app.profile, app.data) - achievements_before
	if new_missions > 0:
		lines.append("미션 %d개 완료! 미션 화면에서 보상을 받으세요." % new_missions)
	if new_achievements > 0:
		lines.append("업적 %d개 달성! 미션 화면에서 보상을 받으세요." % new_achievements)
	_reward_lines = lines
	return lines


func _on_ad_gold() -> void:
	var gold := int(_last_reward.get("gold", 0))
	if gold <= 0 or Profile.ads_left(app.profile, app.eco, "gold_double") <= 0:
		return
	_play("click")
	var ad := AdPlayer.new()
	app.add_child(ad)
	if not await ad.play(app):
		return
	if not is_inside_tree():
		return
	var reward := Profile.watch_ad(app.profile, app.eco, "gold_double", {"gold": gold})
	app.save()
	if reward.is_empty():
		return
	_play("reward")
	_result_overlay.ad_done("골드 +%s 받았어요" % Kit.comma(gold))
	app.toast("광고 보상: %s" % Kit.reward_line(reward))


func _on_retry_pressed() -> void:
	_play("click")
	if _is_local():
		app.go_loading("match", {"mode": _mode, "parties": _parties, "humans": _humans, "map": app.rng.randi_range(0, app.data["boards"].size() - 1)}, "대전 준비 중...", 0.8, true)
	elif _mode == "adventure":
		app.start_mode("adventure", {"stage": _next_stage if _next_stage != "" else _stage_id})
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
	if _map_label != null:
		_status_label.text = "%d/%d턴 · %s" % [min(game.round_number, game.max_rounds), game.max_rounds, turn_text]
		_map_label.text = "%s · 맵 속성: %s" % [game.board_name, attr_text]
	else:
		_status_label.text = "%d/%d턴 · %s\n%s · 맵 속성: %s" % [
			min(game.round_number, game.max_rounds), game.max_rounds, turn_text, game.board_name, attr_text]
	_refresh_player_cards()
	_board_view.active_player = game.current if game.winner < 0 else -1

	var animate_gauges := not MenuArt.calm(app)
	for slot in Game.SLOTS:
		var button: Button = _ability_buttons[slot]
		var character: Dictionary = game.char_of(viewer, slot)
		var ability: Dictionary = game.ability_of(viewer, slot)
		var is_ready: bool = _waiting_for_player and game.can_use_ability(slot)
		var charge := int(me["gauge"][slot])
		var gauge_text := "[사용 가능]" if is_ready else "%d%%" % charge
		# 버튼에는 이름과 게이지만. 설명은 버튼을 길게 눌러 보는 대신 쓸 때 알림으로 나온다.
		if button.has_meta("title"):
			# 그림 스킬 카드: 위 띠에 스킬 이름, 오른쪽 칸에 자리 이름과 게이지.
			button.get_meta("title").text = str(ability.get("name", "-"))
			if button.has_meta("gauge_status"):
				button.get_meta("body").text = Game.SLOT_LABELS[slot]
				var status: Label = button.get_meta("gauge_status")
				status.text = gauge_text
				status.add_theme_color_override("font_color", Color("ffe4a0") if is_ready else Color.WHITE)
			else:
				button.get_meta("body").text = "%s\n%s" % [Game.SLOT_LABELS[slot], gauge_text]
		else:
			button.text = "%s\n%s\n%s" % [Game.SLOT_LABELS[slot], ability.get("name", "-"), gauge_text]
		button.tooltip_text = str(ability.get("text", ""))
		button.disabled = not is_ready
		_refresh_skill_gauge(_ability_gauges[slot], charge, animate_gauges)
		var portrait = _ability_portraits[slot]
		portrait.show_character(character, SLOT_COLORS[slot])
		if button.has_meta("badge"):
			button.get_meta("badge").texture = GameData.ability_icon(str(character.get("ability", "")))

	var hand: Array = me["hand"]
	for index in _card_buttons.size():
		var button: Button = _card_buttons[index]
		if index < hand.size():
			var card: Dictionary = game.cards[hand[index]]
			var art = button.get_meta("art")
			art.show_art("cards/" + str(hand[index]))
			var painted: bool = art.has_art()
			button.text = "" if painted else str(card["name"])
			button.get_meta("name_label").text = str(card["name"]) if painted else ""
			button.visible = true
			# 지금 쓸 수 있는 카드는 또렷하게, 아니면 흐리게
			button.modulate = Color.WHITE if _waiting_for_player and game.can_play_card(index) else Color(0.75, 0.75, 0.8, 0.85)
		else:
			button.visible = false

	if game.winner >= 0:
		_set_roll_text("결과\n보기")
		_roll_button.disabled = false
	elif _choosing_path:
		_set_roll_text("길을\n고르세요")
		_roll_button.disabled = true
	elif _waiting_for_player:
		_set_roll_text("주사위\n굴리기")
		_roll_button.disabled = false
	else:
		_set_roll_text("AI\n차례" if not _humans[game.current] else "진행\n중...")
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



## 이 맵의 관문 수
func _gate_count() -> int:
	var count := 0
	for id in game.nodes:
		if str(game.nodes[id].get("type", "")) == "gate":
			count += 1
	return count
