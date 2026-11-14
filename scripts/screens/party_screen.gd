extends Control
## 파티 고르기 화면을 감싼다. 쓰임새(purpose)에 따라 글자와 다음 화면이 다르다.
##   edit  : 영웅 화면의 파티 편성. 가진 영웅만 고를 수 있고, 정하면 저장.
##   match : 대전 직전. 랭크전·AI 연습은 가진 영웅만, 친구 대전은 두 사람 모두 48명 전부에서 고른다.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const PartySelect := preload("res://scripts/ui/party_select.gd")
const AI := preload("res://scripts/rules/ai.gd")
const Game := preload("res://scripts/rules/game.gd")
const MapPreview := preload("res://scripts/ui/map_preview.gd")

const MODE_TITLES := {"rank": "랭크전", "ai": "AI 연습전", "local": "친구 대전", "adventure": "모험", "challenge": "오늘의 도전"}

var app
var _params: Dictionary = {}
var _map_window: Control
var _pending: Dictionary = {}


func setup(main_app, params: Dictionary) -> void:
	app = main_app
	_params = params
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var purpose := str(params.get("purpose", "edit"))
	var mode := str(params.get("mode", ""))
	var player := int(params.get("player", 1))
	var select := PartySelect.new()
	add_child(select)
	var characters: Array = app.owned_characters()
	var initial: Dictionary = app.profile["party"]
	var options := {"cancel_text": "뒤로", "levels": app.owned_levels()}
	if purpose == "edit":
		options["title"] = "파티 편성"
		options["subtitle"] = "가진 영웅 %d명 중에서 골라요. 소환 포인트(★ 합계)는 %d까지." % [characters.size(), Game.POINT_LIMIT]
		options["confirm_text"] = "저장"
	elif mode == "local":
		characters = app.data["characters"]
		options["levels"] = {}
		options["title"] = "친구 대전 · 플레이어 %d" % player
		options["subtitle"] = "플레이어 %d가 파티를 고르세요. 친구 대전은 48명 모두 쓸 수 있어요." % player
		options["confirm_text"] = "다음" if player == 1 else "대전 시작"
		if player == 2:
			initial = {"attack": "", "defense": "", "support": ""}
	else:
		options["title"] = "%s · 파티 확인" % MODE_TITLES.get(mode, "대전")
		options["subtitle"] = "이대로 시작하거나 바꿔도 돼요. 바꾼 파티는 저장돼요."
		options["confirm_text"] = "대전 시작"
	select.setup(characters, app.data["abilities"], initial, options)
	select.confirmed.connect(_on_confirmed)
	select.cancelled.connect(_on_cancelled)


func _on_confirmed(party: Dictionary) -> void:
	var purpose := str(_params.get("purpose", "edit"))
	var mode := str(_params.get("mode", ""))
	app.play("good")
	if purpose == "edit":
		if Profile.party_ok(app.profile, app.data["characters"], party, Game.POINT_LIMIT):
			app.profile["party"] = party.duplicate()
			app.save()
			app.toast("파티를 저장했어요.")
		app.go("heroes")
		return
	if mode == "local":
		if int(_params.get("player", 1)) == 1:
			app.go("party", {"purpose": "match", "mode": "local", "player": 2, "first": party})
			return
		var first: Dictionary = _params.get("first", {}).duplicate()
		first["name"] = "플레이어 1"
		var second := party.duplicate()
		second["name"] = "플레이어 2"
		_pick_map({"mode": "local", "parties": [first, second], "humans": [true, true]})
		return
	if not Profile.party_ok(app.profile, app.data["characters"], party, Game.POINT_LIMIT):
		app.toast("가진 영웅으로만 파티를 짤 수 있어요.")
		return
	app.profile["party"] = party.duplicate()
	app.save()
	var mine := Profile.battle_party(app.profile, party, "나")
	if mode == "adventure":
		var found := Profile.find_stage(app.data.get("adventure", {}), str(_params.get("stage", "")))
		if found.is_empty():
			app.go("adventure")
			return
		var stage: Dictionary = found["stage"]
		var enemy: Dictionary = stage["enemy"].duplicate()
		enemy["name"] = str(stage["name"])
		var level := int(stage["ai_level"])
		enemy["levels"] = {"attack": level, "defense": level, "support": level}
		app.go_loading("match", {"mode": "adventure", "stage": str(stage["id"]), "parties": [mine, enemy], "humans": [true, false], "map": int(found["chapter"]["map"])}, "대전 준비 중...", 1.0, true)
		return
	if mode == "challenge":
		# 상대 파티와 맵은 날짜로 정해져 하루 동안 같다.
		var day_rng := RandomNumberGenerator.new()
		day_rng.seed = Profile.challenge_seed(app.profile)
		var challenger: Dictionary = AI.pick_party(app.data["characters"], Game.POINT_LIMIT, day_rng)
		challenger["name"] = "오늘의 도전자"
		var challenge_level := Profile.challenge_level(app.profile, app.eco)
		challenger["levels"] = {"attack": challenge_level, "defense": challenge_level, "support": challenge_level}
		app.go_loading("match", {"mode": "challenge", "parties": [mine, challenger], "humans": [true, false],
			"map": day_rng.randi_range(0, app.data["boards"].size() - 1)}, "대전 준비 중...", 1.0, true)
		return
	var theirs: Dictionary = AI.pick_party(app.data["characters"], Game.POINT_LIMIT, app.rng)
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
		var difficulty: Dictionary = Profile.ai_difficulty(app.eco, str(app.profile.get("ai_difficulty", "easy")))
		ai_level = int(difficulty["level"])
		scale = float(difficulty["reward_scale"])
		if not bool(difficulty["smart"]):
			# 쉬움: 조합을 따지지 않은 아무 파티
			theirs = AI.pick_party(app.data["characters"], Game.POINT_LIMIT, app.rng, 1)
		theirs["name"] = "AI(%s)" % difficulty["name"]
	theirs["levels"] = {"attack": ai_level, "defense": ai_level, "support": ai_level}
	var start := {"mode": mode, "parties": [mine, theirs], "humans": [true, false], "reward_scale": scale}
	if mode == "ai":
		_pick_map(start)
		return
	start["map"] = _random_map()
	app.go_loading("match", start, "대전 준비 중...", 1.0, true)


## AI 연습전·친구 대전은 시작하기 전에 맵을 고른다. (랭크전은 늘 무작위, 모험은 장마다 정해짐)
func _pick_map(start: Dictionary) -> void:
	_pending = start
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.add_child(_map_cell(-1, "무작위", "어떤 맵이 나올까?", {}))
	var boards: Array = app.data["boards"]
	for index in boards.size():
		var board: Dictionary = boards[index]
		grid.add_child(_map_cell(index, str(board.get("name", "맵")), str(board.get("shape", "")), board))
	var body := Kit.vbox(8)
	body.add_child(Kit.para("싸울 맵을 고르세요.", 20, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(grid)
	_map_window = app.dialog("맵 고르기", body, [["취소", Kit.PANEL_LIGHT]], 680)


func _map_cell(index: int, title: String, note: String, board: Dictionary) -> Control:
	var theme: Dictionary = board.get("theme", {})
	var fill := Color(str(theme.get("bg", "2a3164")))
	var button := Button.new()
	button.custom_minimum_size = Vector2(204, 176)
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
	var name_label := Kit.label(title, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	var note_label := Kit.label(note, 15, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(note_label)
	return button


func _on_map_picked(index: int) -> void:
	app.play("good")
	if _map_window != null and is_instance_valid(_map_window):
		_map_window.close()
	_pending["map"] = index if index >= 0 else _random_map()
	app.go_loading("match", _pending, "대전 준비 중...", 1.0, true)


func _random_map() -> int:
	return app.rng.randi_range(0, app.data["boards"].size() - 1)


func _on_cancelled() -> void:
	app.play("click")
	if str(_params.get("purpose", "edit")) == "edit":
		app.go("heroes")
	elif str(_params.get("mode", "")) == "adventure":
		app.go("adventure")
	else:
		app.go("lobby")
