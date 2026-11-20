extends Node
## 대전 시작 도우미(2026-11-18 사용자 결정).
## 랭크전·AI 연습전·모험·오늘의 도전을 누르면 파티 고르기 화면 대신
## '파티 편성 + 카드 편성'을 한눈에 보여 주는 창을 띄우고, 확인을 누르면 바로 대전을 시작한다.
## 편성을 바꾸고 싶으면 로비의 '편성' 메뉴에서 바꾼다.
## 친구 대전은 두 사람이 48명 중에서 고르므로 예전처럼 파티 화면을 쓰고, 맵 고르기만 여기를 쓴다.
## 쓰는 법: MatchLauncher.ask(app, "rank", {}) / 맵 고르기만: launcher.pick_map(start)

const Kit := preload("res://scripts/ui/kit.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const AI := preload("res://scripts/rules/ai.gd")
const Game := preload("res://scripts/rules/game.gd")
const MapPreview := preload("res://scripts/ui/map_preview.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const ArtView := preload("res://scripts/ui/art_view.gd")
const CardPanels := preload("res://scripts/ui/card_panels.gd")
const ObservatoryPopups := preload("res://scripts/ui/observatory_popups.gd")
const CARD_FAN := preload("res://assets/ui_observatory/card_fan.png")

const MODE_TITLES := {"rank": "랭크전", "ai": "AI 연습전", "local": "친구 대전", "adventure": "모험", "challenge": "오늘의 도전"}
const SLOTS := [["attack", "ATTACK"], ["defense", "DEFENSE"], ["support", "SUPPORT"]]

var app
var mode := ""
var params: Dictionary = {}
var _window: Control
var _map_window: Control
var _pending: Dictionary = {}


## 시작 확인 창을 띄운다. 도우미 노드는 app에 붙고, 할 일을 마치면 스스로 사라진다.
static func ask(main_app, start_mode: String, start_params: Dictionary = {}) -> Node:
	var launcher = load("res://scripts/ui/match_launcher.gd").new()
	main_app.add_child(launcher)
	launcher.app = main_app
	launcher.mode = start_mode
	launcher.params = start_params
	main_app.set_meta("match_launcher", launcher)
	if not bool(start_params.get("tutorial", false)):
		launcher._open()
	return launcher


## 맵 고르기만 쓰는 도우미(친구 대전).
static func for_map(main_app) -> Node:
	var launcher = load("res://scripts/ui/match_launcher.gd").new()
	main_app.add_child(launcher)
	launcher.app = main_app
	return launcher


func _open() -> void:
	var title := "%s 시작" % MODE_TITLES.get(mode, "대전")
	if mode == "adventure":
		var found := Profile.find_stage(app.data.get("adventure", {}), str(params.get("stage", "")))
		if not found.is_empty():
			title = "%s 시작" % str(found["stage"].get("name", "모험"))
	var action := Kit.PRIMARY if Kit.Observatory.active else Kit.ACCENT
	var buttons := [["확인", action, confirm], ["취소", Kit.PANEL_LIGHT, cancel]]
	if Kit.Observatory.active:
		buttons.reverse()
	_window = app.dialog(title, _body(), buttons, 1038 if Kit.Observatory.active else 1000, "match" if Kit.Observatory.active else "")


func _body() -> Control:
	var body := Kit.vbox(10)
	var columns := Kit.hbox(18)
	body.add_child(columns)
	if Kit.Observatory.active:
		var party_panel := MenuArt.row(14)
		var deck_panel := MenuArt.row(14)
		columns.add_child(Kit.expand(party_panel))
		party_panel.add_child(_party_column())
		var arrow := Kit.label("»", 36, Kit.Observatory.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		columns.add_child(arrow)
		columns.add_child(Kit.expand(deck_panel))
		deck_panel.add_child(_deck_column())
		body.add_child(Kit.para("편성은 로비의 '편성' 메뉴에서 바꿀 수 있어요.", 16, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		return body
	columns.add_child(_party_column())
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.18)
	line.custom_minimum_size = Vector2(2, 0)
	columns.add_child(line)
	columns.add_child(Kit.expand(_deck_column()))
	body.add_child(Kit.para("편성은 로비의 '편성' 메뉴에서 바꿀 수 있어요.", 16, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	return body


# ---------------------------------------------------------------- 파티 편성 쪽

func _party_column() -> Control:
	var column := Kit.vbox(8)
	column.custom_minimum_size = Vector2(300, 0)
	var party: Dictionary = app.profile["party"]
	var limit: int = app.point_limit()
	var total := 0
	var categories: Array = []
	for slot in SLOTS:
		var member: Dictionary = app.character(str(party.get(slot[0], "")))
		total += int(member.get("grade", 0))
		categories.append(str(member.get("category", "")))
	if Kit.Observatory.active:
		column.add_child(Kit.label("파티 편성", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		var members := Kit.hbox(7)
		column.add_child(members)
		for slot in SLOTS:
			var member: Dictionary = app.character(str(party.get(slot[0], "")))
			members.add_child(Kit.expand(_observatory_member(slot[1], member)))
		column.add_child(Kit.para("소환 포인트 %d / %d" % [total, limit], 16, Kit.Observatory.MUTED))
	else:
		column.add_child(Kit.label("파티 편성 · 소환 포인트 %d / %d" % [total, limit], 20, Kit.GOLD))
		for slot in SLOTS:
			column.add_child(_member_row(slot[1], app.character(str(party.get(slot[0], "")))))
	var notes: Array = []
	var synergy: Dictionary = Game.synergy_of(app.data.get("rules", {}).get("synergy", {}), categories)
	if not synergy.is_empty():
		notes.append("시너지: %s" % str(synergy.get("name", "")))
	var relic: Dictionary = Profile.current_relic(app.profile, app.eco)
	notes.append("유물: %s" % (str(relic["name"]) if not relic.is_empty() else "없음"))
	column.add_child(Kit.para("\n".join(notes), 16, Kit.MUTED))
	return column


func _observatory_member(slot_name: String, member: Dictionary) -> Control:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(95, 226)
	tile.add_theme_stylebox_override("panel", Kit.box(Kit.Observatory.NIGHT, Kit.Observatory.EDGE, 1, 10, 4))
	var column := Kit.vbox(2)
	tile.add_child(column)
	var role := Kit.label(slot_name, 13, Kit.Observatory.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(role)
	var face := Portrait.new()
	face.custom_minimum_size.y = 133
	face.focus_y = 0.17
	face.border_width = 0.0
	face.show_character(member, Kit.Observatory.SURFACE)
	column.add_child(face)
	var grade := int(member.get("grade", 0))
	column.add_child(Kit.label("★".repeat(grade), 15, Kit.Observatory.AMBER, HORIZONTAL_ALIGNMENT_CENTER))
	var name_label := Kit.label(str(member.get("name", "비어 있음")), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.clip_text = true
	Kit.fit_text(name_label, tile, 10, 18)
	column.add_child(name_label)
	if not member.is_empty():
		column.add_child(Kit.label("Lv.%d" % maxi(1, Profile.level_of(app.profile, str(member["id"]))), 13, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	return tile


func _member_row(slot_name: String, member: Dictionary) -> Control:
	var row := Kit.hbox(10)
	var grade := int(member.get("grade", 1))
	var face := Portrait.new()
	face.custom_minimum_size = Vector2(64, 64)
	face.border = Kit.GRADE_COLORS.get(grade, Kit.GOLD)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if member.is_empty():
		face.show_text("?", Kit.LINE)
	else:
		face.show_character(member, Kit.CATEGORY_COLORS.get(member.get("category", ""), Kit.LINE))
	row.add_child(face)
	var text := Kit.vbox(0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(Kit.expand(text))
	text.add_child(Kit.label(slot_name, 13, Kit.MUTED))
	text.add_child(Kit.label(str(member.get("name", "비어 있음")), 20, Color.WHITE))
	if not member.is_empty():
		var id := str(member.get("id", ""))
		text.add_child(Kit.label("%s  Lv.%d" % ["★".repeat(grade), max(1, Profile.level_of(app.profile, id))], 14, Kit.GRADE_COLORS.get(grade, Kit.GOLD)))
	return row


# ---------------------------------------------------------------- 카드 편성 쪽

func _deck_column() -> Control:
	var column := Kit.vbox(6)
	var cards: Dictionary = app.data.get("cards", {})
	var deck: Array = app.profile.get("deck", [])
	var size := int(app.eco.get("card_deck", {}).get("size", 15))
	var broken := Profile.deck_error(app.profile, cards, app.eco, deck) != ""
	if broken:
		deck = app.eco.get("start", {}).get("deck", [])
	column.add_child(Kit.label("카드 편성 %d / %d" % [deck.size(), size], 23 if Kit.Observatory.active else 20,
		Color.WHITE if Kit.Observatory.active else Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER if Kit.Observatory.active else HORIZONTAL_ALIGNMENT_LEFT))
	if broken:
		column.add_child(Kit.para("카드 편성이 맞지 않아 기본 덱으로 시작해요.", 15, Color("ffb3a3")))
	var per_grade: Dictionary = app.eco.get("card_deck", {}).get("per_grade", {})
	if Kit.Observatory.active:
		var overview := Kit.hbox(8)
		overview.custom_minimum_size.y = 224
		column.add_child(overview)
		var rows := Kit.vbox(9)
		rows.alignment = BoxContainer.ALIGNMENT_CENTER
		overview.add_child(Kit.expand(rows))
		var fan := ObservatoryPopups.picture(CARD_FAN)
		fan.custom_minimum_size = Vector2(160, 224)
		overview.add_child(fan)
		for grade in [3, 2, 1]:
			var ids := deck.filter(func(id): return Profile.card_grade(cards, str(id)) == grade)
			var label := "%s   %d / %d" % ["★".repeat(grade), ids.size(), int(per_grade.get(str(grade), 0))]
			var grade_button := MenuArt.pill_button(label, ["purple", "blue", "gold"][grade - 1], "m")
			grade_button.pressed.connect(_show_deck_grade.bind(grade, cards, ids))
			rows.add_child(grade_button)
		return column
	var height := 64.0 if Kit.Observatory.active else 78.0
	for grade in [3, 2, 1]:
		var ids: Array = []
		for id in deck:
			if Profile.card_grade(cards, str(id)) == grade:
				ids.append(str(id))
		column.add_child(Kit.label("%s %d / %d" % [CardPanels.GRADE_NAMES[grade], ids.size(), int(per_grade.get(str(grade), 0))], 14, Kit.GRADE_COLORS[grade]))
		var row := Kit.hbox(6)
		row.custom_minimum_size = Vector2(0, height)
		for id in ids:
			row.add_child(_mini_card(cards, id, height))
		if ids.is_empty():
			row.add_child(Kit.label("없음", 14, Kit.MUTED))
		column.add_child(row)
	return column


func _show_deck_grade(grade: int, cards: Dictionary, ids: Array) -> void:
	var body := Kit.hbox(8)
	for id in ids:
		body.add_child(_mini_card(cards, str(id), 92))
	if ids.is_empty():
		body.add_child(Kit.label("없음", 20, Kit.MUTED))
	app.dialog("%s" % CardPanels.GRADE_NAMES[grade], body, [["닫기", Kit.PANEL_LIGHT]], 720)


## 작은 카드: 카드 편성과 같은 모양(그림 가득·별 딱지·이름 띠)을 작게.
func _mini_card(cards: Dictionary, id: String, height: float) -> Control:
	var tile := CardPanels.card_tile(cards, id, true, false, height, false)
	tile.custom_minimum_size = Vector2(70, height)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tile.tooltip_text = str(cards.get(id, {}).get("text", ""))
	return tile


# ---------------------------------------------------------------- 시작

func cancel() -> void:
	app.play("click")
	_finish()


func _finish() -> void:
	if app != null and app.has_meta("match_launcher") and app.get_meta("match_launcher") == self:
		app.remove_meta("match_launcher")
	queue_free()


## 확인: 저장된 파티·덱으로 대전을 시작한다.
func confirm() -> void:
	if _window != null and is_instance_valid(_window):
		_window.close()
	var limit: int = app.point_limit()
	var party: Dictionary = app.profile["party"]
	if not bool(params.get("tutorial", false)) and not Profile.party_ok(app.profile, app.data["characters"], party, limit):
		app.play("denied")
		app.toast("소환 포인트 %d 안에서 파티를 먼저 짜 주세요." % limit)
		app.go("party", {"purpose": "edit"})
		_finish()
		return
	app.play("good")
	var mine := Profile.battle_party(app.profile, party, "나")
	if mode == "adventure":
		var found := Profile.find_stage(app.data.get("adventure", {}), str(params.get("stage", "")))
		if found.is_empty():
			app.go("adventure")
			_finish()
			return
		var stage: Dictionary = found["stage"]
		var enemy: Dictionary = stage["enemy"].duplicate()
		enemy["name"] = str(stage["name"])
		var level := int(stage["ai_level"])
		enemy["levels"] = {"attack": level, "defense": level, "support": level}
		_go({"mode": "adventure", "stage": str(stage["id"]), "parties": [mine, enemy], "humans": [true, false], "map": int(found["chapter"]["map"])})
		return
	if mode == "challenge":
		# 상대 파티와 맵은 날짜로 정해져 하루 동안 같다.
		var day_rng := RandomNumberGenerator.new()
		day_rng.seed = Profile.challenge_seed(app.profile)
		var challenger: Dictionary = AI.pick_party(app.data["characters"], limit, day_rng)
		challenger["name"] = "오늘의 도전자"
		var challenge_level := Profile.challenge_level(app.profile, app.eco)
		challenger["levels"] = {"attack": challenge_level, "defense": challenge_level, "support": challenge_level}
		_go({"mode": "challenge", "parties": [mine, challenger], "humans": [true, false],
			"map": day_rng.randi_range(0, app.data["boards"].size() - 1)})
		return
	var theirs: Dictionary = AI.pick_party(app.data["characters"], limit, app.rng)
	theirs["name"] = "AI"
	var ai_level := 1
	if mode == "rank":
		ai_level = Profile.rank_ai_level(app.eco, int(app.profile["trophies"]))
		var names: Array = app.eco.get("ai_names", [])
		if not names.is_empty():
			var tier: Dictionary = Profile.tier_of(app.eco, int(app.profile["trophies"]))
			theirs["name"] = "%s(%s)" % [names[app.rng.randi_range(0, names.size() - 1)], tier["name"]]
	var scale := 1.0
	if mode == "ai":
		var difficulty: Dictionary = Profile.ai_difficulty(app.eco, "easy" if bool(params.get("tutorial", false)) else str(app.profile.get("ai_difficulty", "easy")))
		ai_level = int(difficulty["level"])
		scale = float(difficulty["reward_scale"])
		if not bool(difficulty["smart"]):
			# 쉬움: 조합을 따지지 않은 아무 파티
			theirs = AI.pick_party(app.data["characters"], limit, app.rng, 1)
		theirs["name"] = "AI(%s)" % difficulty["name"]
	theirs["levels"] = {"attack": ai_level, "defense": ai_level, "support": ai_level}
	var start := {"mode": mode, "parties": [mine, theirs], "humans": [true, false], "reward_scale": scale}
	if mode == "ai" and bool(params.get("tutorial", false)):
		# 길잡이 첫 판: 정해진 맵에서 곧바로. 파티도 정해 둔 것(내 쪽 ★★★·★★★·★★ 최대 강화, 컴퓨터 ★★·★★·★).
		var tutorial: Dictionary = app.data.get("guide", {}).get("tutorial", {})
		if not (tutorial.get("player_party", {}) as Dictionary).is_empty():
			var player_party: Dictionary = (tutorial["player_party"] as Dictionary).duplicate()
			var player_level := int(tutorial.get("player_level", 1))
			player_party["name"] = str(mine.get("name", app.profile.get("nickname", "")))
			player_party["levels"] = {"attack": player_level, "defense": player_level, "support": player_level}
			start["parties"][0] = player_party
		if not (tutorial.get("ai_party", {}) as Dictionary).is_empty():
			var ai_party: Dictionary = (tutorial["ai_party"] as Dictionary).duplicate()
			var tutorial_ai_level := int(tutorial.get("ai_level", 1))
			ai_party["name"] = str(theirs.get("name", "AI"))
			ai_party["levels"] = {"attack": tutorial_ai_level, "defense": tutorial_ai_level, "support": tutorial_ai_level}
			start["parties"][1] = ai_party
		start["map"] = clampi(int(app.data.get("guide", {}).get("tutorial", {}).get("map", 0)), 0, app.data["boards"].size() - 1)
		start["tutorial"] = true
		_go(start)
		return
	if mode == "ai":
		pick_map(start)
		return
	if mode == "rank":
		app.tutorial_event("rank")
	start["map"] = _random_map()
	_go(start)


func _go(start: Dictionary) -> void:
	app.go_loading("match", start, "대전 준비 중...", 1.0, true)
	_finish()


# ---------------------------------------------------------------- 맵 고르기

## AI 연습전·친구 대전은 시작하기 전에 맵을 고른다. (랭크전은 늘 무작위, 모험은 장마다 정해짐)
func pick_map(start: Dictionary) -> void:
	_pending = start
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.add_child(_map_cell(-1, "무작위", "어떤 맵이 나올까?", {}))
	var boards: Array = app.data["boards"]
	for index in boards.size():
		var board: Dictionary = boards[index]
		var note := str(board.get("feature", ""))
		var record: Dictionary = Profile.map_record(app.profile, str(board.get("name", "")))
		if int(record["played"]) > 0:
			note = "내 전적 %d판 %d승" % [int(record["played"]), int(record["wins"])]
		grid.add_child(_map_cell(index, "%s (%s)" % [board.get("name", "맵"), board.get("shape", "")], note, board))
	var body := Kit.vbox(8)
	body.add_child(Kit.para("싸울 맵을 고르세요.", 20, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(grid)
	_map_window = app.dialog("맵 고르기", body, [["취소", Kit.PANEL_LIGHT, cancel]], 780)


func _map_cell(index: int, title: String, note: String, board: Dictionary) -> Control:
	var theme: Dictionary = board.get("theme", {})
	var fill := Color(str(theme.get("bg", "2a3164")))
	var button := Button.new()
	button.custom_minimum_size = Vector2(232, 196)
	for state in ["normal", "hover", "pressed"]:
		var style := Kit.box(fill if state == "normal" else fill.lightened(0.15), Kit.GOLD if state != "normal" else fill.lightened(0.4), 3, 14, 6)
		style.border_width_bottom = 7
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(_on_map_picked.bind(index))
	var column := Kit.vbox(2)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 8
	column.offset_right = -8
	column.offset_top = 8
	column.offset_bottom = -12
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	if board.is_empty():
		var mark := Kit.label("?", 70, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		mark.size_flags_vertical = Control.SIZE_EXPAND_FILL
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(mark)
	else:
		var preview := MapPreview.new()
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.show_board(board)
		column.add_child(preview)
	var name_label := Kit.label(title, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.clip_text = true
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	var note_label := Kit.para(note, 16, Color(1, 1, 1, 0.88), HORIZONTAL_ALIGNMENT_CENTER)
	note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(note_label)
	return button


func _on_map_picked(index: int) -> void:
	app.play("good")
	if _map_window != null and is_instance_valid(_map_window):
		_map_window.close()
	_pending["map"] = index if index >= 0 else _random_map()
	_go(_pending)


func _random_map() -> int:
	return app.rng.randi_range(0, app.data["boards"].size() - 1)
