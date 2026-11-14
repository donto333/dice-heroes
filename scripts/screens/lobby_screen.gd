extends Control
## 로비(홈). 위: 프로필 띠 / 랭크 카드 / 대표 영웅과 파티 / 대전 버튼 / 아래 메뉴.
## 들어올 때 오늘 출석 보상을 아직 안 받았으면 출석 창을 띄운다.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const TopBar := preload("res://scripts/ui/top_bar.gd")
const BottomNav := preload("res://scripts/ui/bottom_nav.gd")

const SLOT_NAMES := {"attack": "ATTACK", "defense": "DEFENSE", "support": "SUPPORT"}

var app


func setup(main_app, params: Dictionary) -> void:
	app = main_app
	var column := Kit.screen_frame(self, 16)
	var top := TopBar.new()
	column.add_child(top)
	top.setup(app)

	column.add_child(_rank_card())
	column.add_child(_showcase())

	var tier: Dictionary = Profile.tier_of(app.eco, int(app.profile["trophies"]))
	var rank_button := Kit.icon_button("랭크전", "battle", Color("e8890c"), 44, 124, "%s · 트로피 %d · 이기면 +30" % [tier["name"], int(app.profile["trophies"])])
	rank_button.pressed.connect(_on_mode.bind("rank"))
	column.add_child(rank_button)
	var modes := Kit.hbox(10)
	column.add_child(modes)
	var adventure := Kit.icon_button("모험", "goal", Color("c2413a"), 26, 100, "★ %d / %d" % [Profile.total_stars(app.profile), _max_stars()])
	adventure.pressed.connect(_on_adventure)
	modes.add_child(Kit.expand(adventure))
	var difficulty: Dictionary = Profile.ai_difficulty(app.eco, str(app.profile.get("ai_difficulty", "easy")))
	var practice := Kit.icon_button("AI전", "fate", Color("2f80ed"), 26, 100, "최근 %s" % difficulty["name"])
	practice.pressed.connect(_choose_difficulty)
	modes.add_child(Kit.expand(practice))
	var friend := Kit.icon_button("친구", "pawn", Color("2a9d5c"), 26, 100, "한 기기 2인")
	friend.pressed.connect(_on_mode.bind("local"))
	modes.add_child(Kit.expand(friend))
	var extra := Kit.hbox(10)
	column.add_child(extra)
	var online := Kit.button("온라인 대전 · 준비 중", Kit.PANEL_LIGHT, 20, 64)
	online.disabled = true
	extra.add_child(Kit.expand(online, 1.6))
	var help := Kit.icon_button("게임 방법", "hidden", Color("7d4fc0"), 22, 64)
	help.pressed.connect(_on_help)
	extra.add_child(Kit.expand(help))

	var nav := BottomNav.new()
	column.add_child(nav)
	nav.setup("lobby", app.badges())
	nav.tab_pressed.connect(_on_tab)

	if bool(params.get("welcome", false)):
		var text := Kit.para("%s님, 주사위 영웅전에 오신 것을 환영해요.\n\n영웅 12명이 함께합니다. 랭크전에서 트로피를 모으고, 상점에서 새 영웅을 소환해 보세요.\n처음이라면 게임 방법부터 보면 좋아요." % app.profile["nickname"], 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		app.dialog("환영합니다!", text, [["게임 방법 보기", Color("6f43a6"), _on_help], ["바로 시작", Kit.ACCENT, _maybe_attendance]])
	else:
		_maybe_attendance()


func _rank_card() -> Control:
	var profile: Dictionary = app.profile
	var trophies := int(profile["trophies"])
	var tier: Dictionary = Profile.tier_of(app.eco, trophies)
	var tier_color := Color(str(tier.get("color", "ffffff")))
	var card := Kit.panel(Color("1a1f40"), tier_color.darkened(0.3), 14)
	var row := Kit.hbox(14)
	card.add_child(row)
	var badge := Kit.label(str(tier["name"]), 34, tier_color, HORIZONTAL_ALIGNMENT_CENTER)
	badge.custom_minimum_size = Vector2(170, 0)
	badge.add_theme_constant_override("outline_size", 6)
	badge.add_theme_color_override("font_outline_color", Color.BLACK)
	row.add_child(badge)
	var info := Kit.vbox(6)
	row.add_child(Kit.expand(info))
	var to_next := Profile.trophies_to_next(app.eco, trophies)
	var next_text := "최고 티어!" if to_next == 0 else "다음 티어까지 %d" % to_next
	info.add_child(Kit.label("트로피 %d  ·  %s" % [trophies, next_text], 22))
	var tiers: Array = app.eco.get("tiers", [])
	var index := Profile.tier_index(app.eco, trophies)
	var progress := 1.0
	if index + 1 < tiers.size():
		var low := int(tiers[index]["min"])
		var high := int(tiers[index + 1]["min"])
		progress = float(trophies - low) / float(max(high - low, 1))
	info.add_child(Kit.bar(progress, tier_color, 16))
	var stats: Dictionary = profile["stats"]
	info.add_child(Kit.label("전적 %d승 %d패  ·  최고 트로피 %d" % [int(stats["wins"]), int(stats["losses"]), int(profile["best_trophies"])], 18, Kit.MUTED))
	return card


## 대표 영웅(ATTACK 자리)을 크게, 파티 세 명을 작게 보여 준다. 누르면 영웅 화면.
func _showcase() -> Control:
	var party: Dictionary = app.profile["party"]
	var button := Button.new()
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 360)
	button.add_theme_stylebox_override("normal", Kit.box(Color("0d1026"), Kit.LINE, 2, 16, 0))
	button.add_theme_stylebox_override("hover", Kit.box(Color("0d1026"), Kit.GOLD, 2, 16, 0))
	button.add_theme_stylebox_override("pressed", Kit.box(Color("0d1026"), Kit.GOLD, 2, 16, 0))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(_on_tab.bind("heroes"))
	var leader_id := str(app.profile.get("avatar", ""))
	if leader_id == "" or not Profile.owns(app.profile, leader_id):
		leader_id = str(party.get("attack", ""))
	var leader: Dictionary = app.character(leader_id)
	var big := Portrait.new()
	big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	big.border_width = 0.0
	big.show_character(leader, Kit.CATEGORY_COLORS.get(leader.get("category", ""), Kit.LINE))
	button.add_child(big)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(shade)
	# 아래쪽 띠: 파티 세 명
	var strip := PanelContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", Kit.box(Color(0.02, 0.03, 0.09, 0.82), Color.TRANSPARENT, 0, 0, 10))
	strip.anchor_left = 0.0
	strip.anchor_right = 1.0
	strip.anchor_top = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_top = -132
	button.add_child(strip)
	var row := Kit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(row)
	for slot in ["attack", "defense", "support"]:
		var member: Dictionary = app.character(str(party.get(slot, "")))
		var cell := Kit.hbox(8)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(Kit.expand(cell))
		var face := Portrait.new()
		face.custom_minimum_size = Vector2(96, 96)
		face.border_width = 2.0
		face.show_character(member, Kit.CATEGORY_COLORS.get(member.get("category", ""), Kit.LINE))
		cell.add_child(face)
		var text := Kit.label("%s\n%s\nLv.%d" % [SLOT_NAMES[slot], member.get("name", "-"), Profile.level_of(app.profile, str(party.get(slot, "")))], 17)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(text)
	var hint := Kit.label("눌러서 파티 바꾸기", 18, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_RIGHT)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.offset_top = 10
	hint.offset_right = -14
	hint.add_theme_constant_override("outline_size", 6)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_child(hint)
	# 모두의 마블식 오른쪽 바로가기: 출석 · 미션 · 특가
	var badges: Dictionary = app.badges()
	var shortcuts := VBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 10)
	shortcuts.anchor_left = 1.0
	shortcuts.anchor_right = 1.0
	shortcuts.offset_left = -102
	shortcuts.offset_right = -12
	shortcuts.offset_top = 46
	button.add_child(shortcuts)
	var attend := Kit.round_shortcut("출석", "treasure", Color("e0a21b"), Profile.can_check_in(app.profile, app.today()))
	attend.pressed.connect(_on_attendance_shortcut)
	shortcuts.add_child(attend)
	var missions := Kit.round_shortcut("미션", "checkpoint", Color("2f80ed"), bool(badges.get("missions", false)))
	missions.pressed.connect(_on_tab.bind("missions"))
	shortcuts.add_child(missions)
	var deals := Kit.round_shortcut("특가", "luck", Color("2a9d5c"), bool(badges.get("shop", false)))
	deals.pressed.connect(_on_tab.bind("shop"))
	shortcuts.add_child(deals)
	return button


func _max_stars() -> int:
	var count := 0
	for chapter in app.data.get("adventure", {}).get("chapters", []):
		count += chapter["stages"].size() * 3
	return count


func _on_attendance_shortcut() -> void:
	app.play("click")
	if Profile.can_check_in(app.profile, app.today()):
		_maybe_attendance()
	else:
		app.go("missions")


func _maybe_attendance() -> void:
	if not Profile.can_check_in(app.profile, app.today()):
		return
	var table: Array = app.eco.get("attendance", [])
	var today_index := Profile.attendance_day(app.profile, app.eco)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for day in table.size():
		var reward: Dictionary = table[day]
		var done := day < today_index
		var now := day == today_index
		var fill: Color = Kit.PANEL_LIGHT if now else (Color("14182f") if done else Kit.PANEL)
		var border: Color = Kit.GOLD if now else Kit.LINE
		var cell := Kit.label("%d일차\n%s%s" % [day + 1, Kit.reward_line(reward), "\n받음" if done else ""], 18,
			Kit.GOLD if now else (Kit.MUTED if done else Color.WHITE), HORIZONTAL_ALIGNMENT_CENTER)
		cell.custom_minimum_size = Vector2(140, 104)
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_theme_stylebox_override("normal", Kit.box(fill, border, 3 if now else 1, 12, 6))
		grid.add_child(cell)
	var body := Kit.vbox(12)
	body.add_child(Kit.para("매일 접속하면 보상을 받아요. 7일마다 다시 시작합니다.", 20, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var center := CenterContainer.new()
	center.add_child(grid)
	body.add_child(center)
	app.dialog("출석 보상", body, [["받기", Color("c4861c"), _claim_attendance]])


func _claim_attendance() -> void:
	var reward := Profile.check_in(app.profile, app.eco, app.today())
	if reward.is_empty():
		return
	app.save()
	app.play("win")
	app.toast("출석 보상: %s" % Kit.reward_line(reward))
	app.go("lobby")


func _on_adventure() -> void:
	app.play("click")
	app.go("adventure")


func _on_help() -> void:
	app.play("click")
	app.go("help", {"back": "lobby"})


## AI 연습전 난이도 고르기
func _choose_difficulty() -> void:
	app.play("click")
	var body := Kit.vbox(12)
	body.add_child(Kit.para("어려울수록 상대 영웅 레벨이 높고 조합을 잘 짜요. 보상도 많아져요.", 20, Kit.MUTED))
	var buttons: Array = []
	var colors := [Color("2f8f4e"), Color("c4861c"), Color("b8323a")]
	var list: Array = app.eco.get("ai_difficulty", [])
	for index in list.size():
		var entry: Dictionary = list[index]
		body.add_child(Kit.para("%s  ·  상대 레벨 %d  ·  보상 ×%s" % [entry["name"], int(entry["level"]), str(entry["reward_scale"])], 21))
		buttons.append([str(entry["name"]), colors[index % colors.size()], _start_ai.bind(str(entry["id"]))])
	buttons.append(["닫기", Kit.PANEL_LIGHT])
	app.dialog("AI 연습전 난이도", body, buttons, 660)


func _start_ai(id: String) -> void:
	app.profile["ai_difficulty"] = id
	app.save()
	app.start_mode("ai")


func _on_mode(mode: String) -> void:
	app.play("click")
	app.start_mode(mode)


func _on_tab(screen_name: String) -> void:
	if screen_name == "lobby":
		return
	app.play("click")
	app.go(screen_name)
