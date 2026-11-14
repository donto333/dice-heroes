extends Control
## 로비(홈). 위: 프로필 띠 / 랭크 카드 / 대표 영웅과 파티 / 대전 버튼 / 아래 메뉴.
## 들어올 때 오늘 출석 보상을 아직 안 받았으면 출석 창을 띄운다.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const TopBar := preload("res://scripts/ui/top_bar.gd")
const BottomNav := preload("res://scripts/ui/bottom_nav.gd")
const RouletteWheel := preload("res://scripts/ui/roulette_wheel.gd")

const SLOT_NAMES := {"attack": "ATTACK", "defense": "DEFENSE", "support": "SUPPORT"}

var app
var _wheel: Control
var _notice_label: Label
var _notice_index := 0
var _notice_time := 0.0
const NOTICE_SECONDS := 4.0
## 로비에서 대표 영웅이 건네는 말(분류별)
const GREETINGS := {
	"영웅": ["오늘도 한판 붙어 볼까!", "선봉은 내게 맡겨라.", "주사위는 던져졌다. 가자!", "이길 준비는 됐겠지?"],
	"위인": ["좋은 수가 떠올랐어요.", "서두르지 말고 한 칸씩 가 봅시다.", "오늘은 어떤 길을 고를까요?", "지혜로운 한 수를 기대할게요."],
	"신화": ["내가 지키는 한 걱정 마라.", "하늘의 뜻이 우리와 함께하길.", "오래 기다렸다. 시작하자.", "오늘의 운은 우리 편이다."],
	"근현대": ["새로운 길을 찾아 떠나 볼까요?", "한 걸음 더 멀리 가 봅시다!", "오늘은 느낌이 좋아요.", "출발 준비 끝났어요!"],
}
var _spin_button: Button
var _spin_info: Label


func setup(main_app, params: Dictionary) -> void:
	app = main_app
	var column := Kit.screen_frame(self, 16)
	var top := TopBar.new()
	column.add_child(top)
	top.setup(app)

	# 새 우편이 있으면 우편함에 넣는다.
	if Profile.deliver_mails(app.profile, app.data.get("mails", {})) > 0:
		app.save()
	column.add_child(_rank_card())
	column.add_child(_showcase())

	var tier: Dictionary = Profile.tier_of(app.eco, int(app.profile["trophies"]))
	var streak := Profile.streak(app.profile)
	var rank_note := "%s · 트로피 %d · 이기면 +30" % [tier["name"], int(app.profile["trophies"])]
	if streak >= 2:
		rank_note = "%d연승 중! 이기면 골드 보너스 · 트로피 %d" % [streak, int(app.profile["trophies"])]
	var rank_button := Kit.icon_button("랭크전", "battle", Color("e8890c"), 44, 124, rank_note)
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
	var done := Profile.challenge_done(app.profile)
	var challenge := Kit.icon_button("오늘의 도전", "ambush", Color("b8323a") if not done else Color("4a5580"), 24, 76,
		"오늘 완료!" if done else "하루 한 번 · 이기면 보석 30")
	challenge.pressed.connect(_on_mode.bind("challenge"))
	extra.add_child(Kit.expand(challenge, 1.6))
	var help := Kit.icon_button("게임 방법", "hidden", Color("7d4fc0"), 22, 76)
	help.pressed.connect(_on_help)
	extra.add_child(Kit.expand(help))

	column.add_child(Kit.label("온라인 대전은 준비 중이에요", 16, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var nav := BottomNav.new()
	column.add_child(nav)
	nav.setup("lobby", app.badges())
	nav.tab_pressed.connect(_on_tab)

	if bool(params.get("welcome", false)):
		# 처음 온 사람은 새 소식을 따로 띄우지 않는다.
		app.profile["seen_version"] = app.VERSION
		app.save()
		var text := Kit.para("%s님, 주사위 영웅전에 오신 것을 환영해요.\n\n영웅 12명이 함께합니다. 랭크전에서 트로피를 모으고, 상점에서 새 영웅을 소환해 보세요.\n처음이라면 게임 방법부터 보면 좋아요." % app.profile["nickname"], 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		app.dialog("환영합니다!", text, [["게임 방법 보기", Color("6f43a6"), _on_help], ["바로 시작", Kit.ACCENT, _maybe_attendance]])
	else:
		_maybe_news()


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
	info.add_child(Kit.label("전투력 %d  ·  %d승 %d패  ·  리그 %d위  ·  눌러서 순위표" % [Profile.my_power(profile, app.data["characters"], app.eco), int(stats["wins"]), int(stats["losses"]), Profile.league_rank(profile, app.eco)], 18, Kit.MUTED))
	# 카드를 누르면 순위표
	var open := Button.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		open.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	open.pressed.connect(_on_league)
	card.add_child(open)
	return card


func _on_league() -> void:
	app.play("click")
	app.show_league()


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
	# 대표 영웅의 한마디: 분류마다 말투가 다르고, 들어올 때마다 바뀐다.
	var lines: Array = GREETINGS.get(str(leader.get("category", "")), GREETINGS["영웅"])
	var greeting := Kit.label(str(lines[app.rng.randi_range(0, lines.size() - 1)]), 20, Color("1b1f3b"))
	greeting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	greeting.add_theme_stylebox_override("normal", Kit.box(Color(1, 1, 1, 0.94), Kit.GOLD, 3, 16, 10))
	greeting.anchor_top = 1.0
	greeting.anchor_bottom = 1.0
	greeting.offset_left = 110
	greeting.offset_top = -196
	greeting.offset_bottom = -150
	button.add_child(greeting)
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
	# 그림 위쪽의 공지 줄: 소식이 몇 초마다 바뀐다. 누르면 전체 공지를 본다.
	var band := Button.new()
	band.add_theme_stylebox_override("normal", Kit.box(Color(0.02, 0.03, 0.09, 0.72), Color.TRANSPARENT, 0, 0, 0))
	band.add_theme_stylebox_override("hover", Kit.box(Color(0.06, 0.08, 0.18, 0.8), Color.TRANSPARENT, 0, 0, 0))
	band.add_theme_stylebox_override("pressed", Kit.box(Color(0.06, 0.08, 0.18, 0.8), Color.TRANSPARENT, 0, 0, 0))
	band.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.offset_bottom = 36
	band.pressed.connect(_on_notices)
	button.add_child(band)
	_notice_label = Kit.label("", 18, Color(1, 1, 1, 0.95))
	_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_label.clip_text = true
	_notice_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_notice_label.offset_left = 12
	_notice_label.offset_right = -12
	_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band.add_child(_notice_label)
	_show_notice()
	# 왼쪽 위: 우편함 (안 받은 우편이 있으면 빨간 점)
	var mail := Kit.round_shortcut("우편", "mail", Color("3a8fd0"), Profile.unclaimed_mail_count(app.profile) > 0)
	mail.pressed.connect(open_mailbox)
	button.add_child(mail)
	mail.position = Vector2(12, 40)
	mail.size = Vector2(88, 88)
	var season := Kit.round_shortcut("패스", "goal", Color("c4861c"), Profile.pass_claimable_count(app.profile, app.eco) > 0)
	season.pressed.connect(_on_tab.bind("pass"))
	button.add_child(season)
	season.position = Vector2(12, 134)
	season.size = Vector2(88, 88)
	# 오늘 할 일: 남은 것이 있으면 빨간 점
	var todo := Kit.round_shortcut("할 일", "start", Color("7a4fd0"), _todo_left() > 0)
	todo.pressed.connect(open_todo)
	button.add_child(todo)
	todo.position = Vector2(12, 228)
	todo.size = Vector2(88, 88)
	# 모두의 마블식 오른쪽 바로가기: 출석 · 미션 · 특가
	var badges: Dictionary = app.badges()
	var shortcuts := VBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 6)
	shortcuts.anchor_left = 1.0
	shortcuts.anchor_right = 1.0
	shortcuts.offset_left = -102
	shortcuts.offset_right = -12
	shortcuts.offset_top = 40
	button.add_child(shortcuts)
	var attend := Kit.round_shortcut("출석", "treasure", Color("e0a21b"), Profile.can_check_in(app.profile, app.today()))
	attend.pressed.connect(_on_attendance_shortcut)
	shortcuts.add_child(attend)
	var missions := Kit.round_shortcut("미션", "checkpoint", Color("2f80ed"), bool(badges.get("missions", false)))
	missions.pressed.connect(_on_tab.bind("missions"))
	shortcuts.add_child(missions)
	var roulette := Kit.round_shortcut("룰렛", "fate", Color("c2413a"), Profile.can_spin_free(app.profile, app.eco))
	roulette.pressed.connect(open_roulette)
	shortcuts.add_child(roulette)
	var deals := Kit.round_shortcut("특가", "luck", Color("2a9d5c"), bool(badges.get("shop", false)))
	deals.pressed.connect(_on_tab.bind("shop"))
	shortcuts.add_child(deals)
	return button


# ---------------------------------------------------------------- 오늘 할 일

## 오늘 할 일 목록. 각 줄은 [이름, 설명, 끝났나, 누르면 할 일].
func _todo_items() -> Array:
	var profile: Dictionary = app.profile
	var missions: Array = Profile.active_missions(profile, app.eco)
	var missions_done := 0
	for mission in missions:
		if Profile.mission_progress(profile, mission) >= int(mission["goal"]):
			missions_done += 1
	var sweeps := Profile.sweeps_left(profile, app.eco)
	return [
		["길잡이 과제", str(Profile.guide_current(profile, app.data).get("text", "모두 끝냈어요")), not Profile.guide_claimable(profile, app.data), _on_tab.bind("missions")],
		["출석 체크", "하루 한 번 출석 보상", not Profile.can_check_in(profile, app.today()), _on_attendance_shortcut],
		["무료 소환", "오늘 %d번 남음" % Profile.free_summons_left(profile, app.eco), Profile.free_summons_left(profile, app.eco) <= 0, _on_tab.bind("shop")],
		["행운의 룰렛", "하루 한 번 무료", not Profile.can_spin_free(profile, app.eco), open_roulette],
		["오늘의 도전", "이기면 보석", Profile.challenge_done(profile), _on_mode.bind("challenge")],
		["일일 미션", "%d / %d 달성" % [missions_done, missions.size()], missions_done >= missions.size() and Profile.claimable_mission_count(profile, app.eco) == 0, _on_tab.bind("missions")],
		["우편함", "안 받은 우편 %d통" % Profile.unclaimed_mail_count(profile), Profile.unclaimed_mail_count(profile) == 0, open_mailbox],
		["시즌 패스", "받을 보상 %d개" % Profile.pass_claimable_count(profile, app.eco), Profile.pass_claimable_count(profile, app.eco) == 0, _on_tab.bind("pass")],
		["모험 소탕", "오늘 %d번 남음 (별 3개로 깬 곳만)" % sweeps, sweeps <= 0 or Profile.three_star_count(profile) == 0, _on_mode.bind("adventure")],
	]


func _todo_left() -> int:
	var left := 0
	for item in _todo_items():
		# 소탕은 별 3개 스테이지가 있어야 할 수 있어서 빨간 점에는 넣지 않는다.
		if not bool(item[2]) and str(item[0]) != "모험 소탕":
			left += 1
	return left


func open_todo() -> void:
	app.play("click")
	var body := Kit.vbox(8)
	var window: Control = null
	var rows: Array = []
	for item in _todo_items():
		var done := bool(item[2])
		var line := Kit.panel(Color("14182f") if not done else Color("10131f"), Kit.LINE, 10)
		var row := Kit.hbox(10)
		line.add_child(row)
		var text := Kit.vbox(0)
		text.add_child(Kit.label(str(item[0]), 24, Color.WHITE if not done else Kit.MUTED))
		text.add_child(Kit.label(str(item[1]), 17, Kit.MUTED))
		row.add_child(Kit.expand(text))
		if done:
			var mark := Kit.label("완료", 22, Color("6fd08c"), HORIZONTAL_ALIGNMENT_CENTER)
			mark.custom_minimum_size = Vector2(120, 0)
			row.add_child(mark)
		else:
			var go := Kit.button("가기", Kit.ACCENT, 22, 56)
			go.custom_minimum_size = Vector2(120, 56)
			rows.append([go, item[3]])
			row.add_child(go)
		body.add_child(line)
	window = app.dialog("오늘 할 일", body, [["닫기", Kit.PANEL_LIGHT]], 640)
	for pair in rows:
		(pair[0] as Button).pressed.connect(_todo_go.bind(window.get_instance_id(), pair[1]))


func _todo_go(window_id: int, action: Callable) -> void:
	var window := instance_from_id(window_id)
	if is_instance_valid(window):
		window.call("close")
	action.call()


# ---------------------------------------------------------------- 공지 줄

## 공지 줄에 흐르는 글: 열려 있는 이벤트가 먼저, 그다음 일반 공지.
func _notices() -> Array:
	var list: Array = []
	for event in Profile.active_events(app.data.get("events", {}), app.today()):
		list.append("이벤트 [%s] %s (%s까지)" % [event["name"], event["text"], str(event["end"]).substr(5)])
	list.append_array(app.data.get("notices", {}).get("notices", []))
	return list


func _show_notice() -> void:
	var list := _notices()
	if _notice_label == null or list.is_empty():
		return
	_notice_label.text = "공지 · %s" % str(list[_notice_index % list.size()])


func _process(delta: float) -> void:
	_notice_time += delta
	if _notice_time >= NOTICE_SECONDS:
		_notice_time = 0.0
		_notice_index += 1
		_show_notice()


func _on_notices() -> void:
	app.play("click")
	var body := Kit.vbox(8)
	for line in _notices():
		body.add_child(Kit.para("· " + str(line), 21, Color.WHITE))
	app.dialog("공지", body, [["닫기", Kit.PANEL_LIGHT]], 640)


# ---------------------------------------------------------------- 우편함

func open_mailbox() -> void:
	app.play("click")
	var body := Kit.vbox(10)
	var mails: Array = app.profile.get("mail", [])
	if mails.is_empty():
		body.add_child(Kit.para("받은 우편이 없어요.", 22, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	# 새 우편이 위로 오게 거꾸로 보여 준다.
	for index in range(mails.size() - 1, -1, -1):
		var entry: Dictionary = mails[index]
		var claimed := bool(entry.get("claimed", false))
		var card := Kit.panel(Color("14182f"), Kit.LINE if claimed else Kit.GOLD, 12)
		var row := Kit.hbox(10)
		card.add_child(row)
		var info := Kit.vbox(4)
		row.add_child(Kit.expand(info))
		info.add_child(Kit.label(str(entry["title"]), 24, Kit.MUTED if claimed else Color.WHITE))
		info.add_child(Kit.para(str(entry["text"]), 18, Kit.MUTED))
		info.add_child(Kit.label("선물 %s" % Kit.reward_line(entry["reward"]), 20, Kit.GOLD))
		var take := Kit.button("받음" if claimed else "받기", Kit.PANEL_LIGHT if claimed else Color("e8890c"), 22, 64)
		take.custom_minimum_size = Vector2(120, 64)
		take.disabled = claimed
		take.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		take.pressed.connect(_on_mail_claim.bind(str(entry["id"])))
		row.add_child(take)
		body.add_child(card)
	var buttons: Array = []
	if Profile.unclaimed_mail_count(app.profile) > 1:
		buttons.append(["모두 받기", Color("e8890c"), _on_mail_claim_all])
	buttons.append(["닫기", Kit.PANEL_LIGHT, _close_roulette])
	app.dialog("우편함", body, buttons, 660)


func _on_mail_claim(id: String) -> void:
	var reward := Profile.claim_mail(app.profile, id)
	if reward.is_empty():
		return
	app.save()
	app.play("win")
	_close_all_dialogs()
	app.go("lobby")
	app.toast("우편 선물: %s" % Kit.reward_line(reward))


func _on_mail_claim_all() -> void:
	var total := Profile.claim_all_mail(app.profile)
	if int(total["count"]) == 0:
		return
	app.save()
	app.play("win")
	app.go("lobby")
	app.toast("우편 선물 %d개: %s" % [int(total["count"]), Kit.reward_line({"gold": int(total["gold"]), "gems": int(total["gems"])})])


## 창 안의 버튼으로 화면을 바꿀 때, 떠 있는 창을 먼저 닫는다.
func _close_all_dialogs() -> void:
	for child in app.get_children():
		if child.has_method("close") and child.has_signal("closed"):
			child.close()


# ---------------------------------------------------------------- 행운의 룰렛

func open_roulette() -> void:
	app.play("click")
	var body := Kit.vbox(10)
	_wheel = RouletteWheel.new()
	var slots: Array = []
	for slot in app.eco.get("roulette", {}).get("slots", []):
		var reward: Dictionary = slot["reward"]
		var text: String = "보석 %d" % int(reward["gems"]) if reward.has("gems") else "골드 %d" % int(reward.get("gold", 0))
		slots.append({"text": text, "color": Color(str(slot.get("color", "3a6fd8")))})
	_wheel.slots = slots
	var center := CenterContainer.new()
	center.add_child(_wheel)
	body.add_child(center)
	_spin_info = Kit.para("", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(_spin_info)
	_spin_button = Kit.button("", Color("e8890c"), 30, 92)
	_spin_button.pressed.connect(_on_spin)
	body.add_child(_spin_button)
	_refresh_roulette()
	app.dialog("행운의 룰렛", body, [["닫기", Kit.PANEL_LIGHT, _close_roulette]], 660)


func _refresh_roulette() -> void:
	var table: Dictionary = app.eco.get("roulette", {})
	var cost := Profile.roulette_cost(app.profile, app.eco)
	var limit := int(table.get("free_per_day", 1)) + int(table.get("max_extra", 0))
	_spin_info.text = "오늘 %d / %d번 돌렸어요. 하루 한 번은 무료!" % [Profile.roulette_spins(app.profile), limit]
	if cost < 0:
		_spin_button.text = "오늘은 다 돌렸어요"
		_spin_button.disabled = true
	elif cost == 0:
		_spin_button.text = "무료로 돌리기"
		_spin_button.disabled = false
	else:
		_spin_button.text = "돌리기  %s" % Kit.money_text("gems", cost)
		_spin_button.disabled = not Profile.can_pay(app.profile, "gems", cost)


func _on_spin() -> void:
	if _wheel.is_spinning():
		return
	var result := Profile.spin_roulette(app.profile, app.eco, app.rng)
	if result.is_empty():
		app.toast("지금은 돌릴 수 없어요.")
		return
	app.save()
	app.play("dice")
	_spin_button.disabled = true
	_spin_button.text = "돌아가는 중..."
	await _wheel.spin_to(int(result["index"]))
	if not is_inside_tree():
		return
	app.play("win")
	app.toast("룰렛 보상: %s" % Kit.reward_line(result["reward"]))
	_refresh_roulette()


## 닫으면 위쪽 재화 표시와 빨간 점이 바뀌도록 로비를 다시 그린다.
func _close_roulette() -> void:
	app.go("lobby")


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


## 새 버전을 처음 켰으면 새 소식을 보여 주고, 그다음 출석 창으로 넘어간다.
const NEWS := [
	"길잡이 과제 8단계: 미션 화면 맨 위에서 순서대로 따라 하며 보상을 받아요.",
	"오늘 할 일: 로비 왼쪽 '할 일'에서 오늘 남은 것을 한눈에 보고 바로 가요.",
	"전투 창에 공격 쪽 예상 승률이 나와요. 영웅 화면에 일괄 강화, 맵 고르기에 맵별 내 전적이 생겼어요.",
	"더블: 이동 주사위 두 개가 같은 눈이면 어빌리티 게이지가 12% 더 차요.",
	"어빌리티를 쓰면 영웅이 화면을 가로지르는 컷인이 나와요.",
	"모험 소탕: 별 3개로 깬 곳은 대전 없이 보상을 받아요(하루 5번).",
	"시즌 패스, 주사위 상점(모양 8종), 쿠폰, 기기 옮기기 코드, 파티 저장 칸 3개가 생겼어요.",
	"연승 보너스, 전투력 표시, 남는 조각 팔기, 프로필의 최근 전적이 생겼어요.",
	"거점·습격·골 칸 위에 적이 서 있어요. 기간 이벤트는 로비 공지 띠에서 확인하세요.",
	"주사위 컨트롤: 굴리기 버튼을 꾹 눌러 낮게·높게를 노려 보세요. 자동 진행 버튼과 내 차례 진동도 생겼어요.",
	"따라잡기: 상대보다 10칸 이상 뒤처지면 이동 주사위에서 큰 눈이 더 잘 나와요.",
	"새 카드 '역전의 첫걸음': 10칸 이상 뒤처졌을 때 상대와 전투, 이기면 나는 5칸 앞으로 상대는 5칸 뒤로! ('뒤바뀐 운명' 카드는 없어졌어요)",
	"우편함이 생겼어요. 테스트 선물 보석 1만 개를 받아 가세요.",
	"보드가 지형 위의 육각 칸으로 바뀌었어요. 맵마다 풍경이 달라요.",
	"주사위가 판 위를 굴러가고, 말이 통통 뛰어가요.",
	"전투는 공격 → 방어 순서로 굴리고 WIN·LOSE가 찍혀요.",
	"모험 모드 24판, 업적 28개, 행운의 룰렛, 오늘의 특가가 생겼어요.",
	"하루 한 번 '오늘의 도전'에서 강한 상대를 이기면 보석을 받아요.",
	"일일 미션이 12종 중 매일 6개씩 바뀌어 나와요.",
	"AI 연습전은 난이도와 맵을 고를 수 있고, 대전 빠르기 ×2와 한마디 말풍선을 쓸 수 있어요.",
	"내 정보를 누르면 프로필, 랭크 카드를 누르면 순위표가 나와요.",
]


func _maybe_news() -> void:
	if str(app.profile.get("seen_version", "")) == app.VERSION:
		_maybe_attendance()
		return
	app.profile["seen_version"] = app.VERSION
	app.save()
	var body := Kit.vbox(8)
	for line in NEWS:
		body.add_child(Kit.para("· " + line, 21, Color.WHITE))
	app.dialog("새 소식 · 버전 %s" % app.VERSION, body, [["확인", Kit.ACCENT, _maybe_attendance]], 640)


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
