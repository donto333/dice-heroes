extends Control
## 로비(홈). 위: 프로필 띠 / 랭크 카드 / 대표 영웅과 파티 / 대전 버튼 / 아래 메뉴.
## 들어올 때 오늘 출석 보상을 아직 안 받았으면 출석 창을 띄운다.

const GameData := preload("res://scripts/game_data.gd")
const ArtView := preload("res://scripts/ui/art_view.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const DiePreview := preload("res://scripts/ui/die_preview.gd")
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
	var column := Kit.screen_frame(self, 12, Kit.BG, 0.0)
	# 로비 그림 위에 보랏빛을 덮어 차분하고 고급스러운 분위기를 낸다.
	var lobby_art := Kit.backdrop(self, "ui/lobby_violet" if GameData.art("ui/lobby_violet") != null else "ui/lobby_bg", 1.0)
	move_child(lobby_art, 1)
	if GameData.art("ui/lobby_violet") == null:
		var tint := ColorRect.new()
		tint.color = Color(0.42, 0.3, 0.78, 0.5)
		tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tint)
		move_child(tint, 2)

	# 새 우편이 있으면 우편함에 넣는다.
	if Profile.deliver_mails(app.profile, app.data.get("mails", {})) > 0:
		app.save()
	var badges: Dictionary = app.badges()
	column.add_child(_top_strip())

	# 가로 로비: 왼쪽 세로 메뉴 → 큰 대표 영웅 카드 → 오른쪽에 배너·랭크·모드·게임 시작.
	var body := Kit.hbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	var rail := Kit.vbox(2)
	rail.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(rail)
	var rail_items := [
		["영웅", "heroes", bool(badges.get("heroes", false)), _on_tab.bind("heroes")],
		["상점", "shop", bool(badges.get("shop", false)), _on_tab.bind("shop")],
		["미션", "missions", bool(badges.get("missions", false)), _on_tab.bind("missions")],
		["패스", "pass", Profile.pass_claimable_count(app.profile, app.eco) > 0, _on_tab.bind("pass")],
		["설정", "settings", false, _on_tab.bind("settings")],
		["방법", "help", false, _on_help],
	]
	for spec in rail_items:
		var item := Kit.icon_shortcut(str(spec[0]), str(spec[1]), bool(spec[2]), 58.0)
		item.pressed.connect(spec[3])
		rail.add_child(item)

	body.add_child(_hero_card())

	var side := Kit.vbox(8)
	body.add_child(Kit.expand(side))
	side.add_child(_banner())
	# 오늘의 보상 줄: 빛나는 구슬 네 개(받을 것이 있으면 빨간 점). 모두의 마블의 보상 구슬 줄처럼.
	var orbs := Kit.panel(Color(0.2, 0.14, 0.52, 0.86), Color("b79cff"), 6)
	side.add_child(orbs)
	var orb_row := Kit.hbox(6)
	orbs.add_child(orb_row)
	var orb_title := Kit.label("오늘의\n보상", 20, Color("ffe37a"), HORIZONTAL_ALIGNMENT_CENTER)
	orb_title.custom_minimum_size = Vector2(84, 0)
	orb_title.add_theme_constant_override("outline_size", 6)
	orb_title.add_theme_color_override("font_outline_color", Color("2a0f5a"))
	orb_row.add_child(orb_title)
	var shortcuts := [
		["출석", "orb_gold", Profile.can_check_in(app.profile, app.today()), _on_attendance_shortcut],
		["룰렛", "orb_purple", Profile.can_spin_free(app.profile, app.eco), open_roulette],
		["할 일", "orb_green", _todo_left() > 0, open_todo],
		["우편", "orb_blue", Profile.unclaimed_mail_count(app.profile) > 0, open_mailbox],
	]
	for spec in shortcuts:
		var shortcut := Kit.icon_shortcut(str(spec[0]), str(spec[1]), bool(spec[2]), 56.0)
		shortcut.pressed.connect(spec[3])
		orb_row.add_child(Kit.expand(shortcut))
	side.add_child(_rank_card())

	var tier: Dictionary = Profile.tier_of(app.eco, int(app.profile["trophies"]))
	var streak := Profile.streak(app.profile)
	var rank_note := "%s · 트로피 %d" % [tier["name"], int(app.profile["trophies"])]
	if streak >= 2:
		rank_note = "%d연승 중! 트로피 %d" % [streak, int(app.profile["trophies"])]
	# 아래: 모드 타일 네 개(2×2)와 크게 '게임 시작'(랭크전)
	var bottom := Kit.hbox(10)
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(bottom)
	var modes := GridContainer.new()
	modes.columns = 2
	modes.add_theme_constant_override("h_separation", 8)
	modes.add_theme_constant_override("v_separation", 8)
	bottom.add_child(Kit.expand(modes, 1.0))
	var adventure := Kit.tile_button("모험", "goal", Color("e0532b"), "★ %d / %d" % [Profile.total_stars(app.profile), _max_stars()], 96.0, "ui/mode_adventure")
	adventure.pressed.connect(_on_adventure)
	var difficulty: Dictionary = Profile.ai_difficulty(app.eco, str(app.profile.get("ai_difficulty", "easy")))
	var practice := Kit.tile_button("AI전", "fate", Color("2fb457"), "최근 %s" % difficulty["name"], 96.0, "ui/mode_ai")
	practice.pressed.connect(_choose_difficulty)
	var friend := Kit.tile_button("친구", "pawn", Color("19a8c9"), "한 기기 2인", 96.0, "ui/mode_friend")
	friend.pressed.connect(_on_mode.bind("local"))
	var done := Profile.challenge_done(app.profile)
	var challenge := Kit.tile_button("도전", "ambush", Color("8a55e0") if not done else Color("6f9bd6"), "오늘 완료!" if done else "하루 한 번", 96.0, "ui/mode_challenge")
	challenge.pressed.connect(_on_mode.bind("challenge"))
	for tile in [adventure, practice, friend, challenge]:
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		modes.add_child(tile)
	var rank_button := Kit.icon_button("게임 시작", "swords", Color("ffb81f"), 56, 150, rank_note)
	rank_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rank_button.pressed.connect(_on_mode.bind("rank"))
	Kit.shimmer(rank_button)
	bottom.add_child(Kit.expand(rank_button, 1.1))

	_maybe_league_reward()
	_maybe_idle_reward()
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
	var card := Kit.panel(Color("3b2f9e"), tier_color, 10)
	var row := Kit.hbox(14)
	card.add_child(row)
	# 티어 문장 그림(assets/art/ui/tier_<순서>.jpg)
	var emblem := ArtView.new()
	emblem.show_art("ui/tier_%d" % Profile.tier_index(app.eco, trophies))
	var has_emblem: bool = emblem.has_art()
	if has_emblem:
		emblem.custom_minimum_size = Vector2(84, 84)
		emblem.focus_y = 0.5
		row.add_child(emblem)
	else:
		emblem.free()
	var badge := Kit.label(str(tier["name"]), 34, tier_color, HORIZONTAL_ALIGNMENT_CENTER)
	badge.custom_minimum_size = Vector2(120 if has_emblem else 150, 0)
	badge.add_theme_constant_override("outline_size", 6)
	badge.add_theme_color_override("font_outline_color", Color.BLACK)
	row.add_child(badge)
	var info := Kit.vbox(6)
	row.add_child(Kit.expand(info))
	var to_next := Profile.trophies_to_next(app.eco, trophies)
	var next_text := "최고 티어!" if to_next == 0 else "다음 티어까지 %d" % to_next
	var stats: Dictionary = profile["stats"]
	info.add_child(Kit.label("트로피 %d · %s · 리그 %d위" % [trophies, next_text, Profile.league_rank(profile, app.eco)], 20))
	var tiers: Array = app.eco.get("tiers", [])
	var index := Profile.tier_index(app.eco, trophies)
	var progress := 1.0
	if index + 1 < tiers.size():
		var low := int(tiers[index]["min"])
		var high := int(tiers[index + 1]["min"])
		progress = float(trophies - low) / float(max(high - low, 1))
	info.add_child(Kit.bar(progress, tier_color, 14))
	var side := Kit.label("전투력 %d\n%d승 %d패" % [Profile.my_power(profile, app.data["characters"], app.eco), int(stats["wins"]), int(stats["losses"])], 18, Kit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(side)
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
## 위 띠: 왼쪽에 얼굴·이름·레벨, 오른쪽에 골드·보석. 누르면 프로필.
func _top_strip() -> Control:
	var profile: Dictionary = app.profile
	var leader_id := str(profile.get("avatar", ""))
	if leader_id == "" or not Profile.owns(profile, leader_id):
		leader_id = str(profile["party"].get("attack", ""))
	var leader: Dictionary = app.character(leader_id)
	var row := Kit.hbox(10)
	row.custom_minimum_size = Vector2(0, 60)
	var who := Button.new()
	who.custom_minimum_size = Vector2(360, 60)
	for state in ["normal", "hover", "pressed"]:
		who.add_theme_stylebox_override(state, Kit.box(Color(0.1, 0.06, 0.3, 0.55), Color(1, 1, 1, 0.35), 2, 30, 4))
	who.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	who.pressed.connect(app.show_profile)
	row.add_child(who)
	var inner := Kit.hbox(10)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 6
	inner.offset_right = -14
	inner.offset_top = 4
	inner.offset_bottom = -4
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.add_child(inner)
	var face := Portrait.new()
	face.custom_minimum_size = Vector2(52, 52)
	face.border_width = 3.0
	face.border = Kit.GOLD
	face.show_character(leader, Kit.CATEGORY_COLORS.get(leader.get("category", ""), Kit.LINE))
	inner.add_child(face)
	var names := Kit.vbox(0)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(Kit.expand(names))
	var nick := Kit.label("Lv.%d %s" % [int(profile["level"]), str(profile["nickname"])], 22)
	nick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(nick)
	var tier: Dictionary = Profile.tier_of(app.eco, int(profile["trophies"]))
	var rank := Kit.label("%s · 리그 %d위" % [tier["name"], Profile.league_rank(profile, app.eco)], 16, Kit.GOLD)
	rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(rank)
	row.add_child(Kit.expand(Control.new()))
	for spec in [["gold", Kit.GOLD, int(profile["gold"])], ["gem", Kit.GEM, int(profile["gems"])]]:
		var capsule := PanelContainer.new()
		capsule.custom_minimum_size = Vector2(190, 44)
		capsule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tint: Color = spec[1]
		var style := Kit.box(Color(0.08, 0.04, 0.26, 0.7), tint.darkened(0.15), 2, 22, 4)
		style.content_margin_left = 6
		style.content_margin_right = 16
		capsule.add_theme_stylebox_override("panel", style)
		var chip := Kit.hbox(4)
		capsule.add_child(chip)
		chip.add_child(Kit.icon(str(spec[0]), 36.0))
		var amount := Kit.label(Kit.comma(int(spec[2])), 24, tint, HORIZONTAL_ALIGNMENT_RIGHT)
		chip.add_child(Kit.expand(amount))
		row.add_child(capsule)
	return row


## 큰 대표 영웅 카드: 장식 액자 안의 큰 그림, 등급과 이름, 아래에 영웅의 한마디. 누르면 영웅 화면.
func _hero_card() -> Control:
	var party: Dictionary = app.profile["party"]
	var leader_id := str(app.profile.get("avatar", ""))
	if leader_id == "" or not Profile.owns(app.profile, leader_id):
		leader_id = str(party.get("attack", ""))
	var leader: Dictionary = app.character(leader_id)
	var holder := Kit.vbox(6)
	holder.custom_minimum_size = Vector2(400, 0)
	var card := Button.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed", "focus"]:
		card.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	card.pressed.connect(_on_tab.bind("heroes"))
	holder.add_child(card)
	var fancy_path := "res://assets/ui_frames/lobby_frame.png"
	var has_fancy := ResourceLoader.exists(fancy_path)
	var big := Portrait.new()
	big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 장식 액자는 테가 두꺼워서 그림을 더 안쪽에 둔다.
	var inset := Vector2(16, 24)
	if has_fancy:
		# 장식 액자의 그림 창은 가로 14.5%~85.5%, 세로 15.5%~84.5% 자리에 있다.
		big.anchor_left = 0.14
		big.anchor_right = 0.86
		big.anchor_top = 0.15
		big.anchor_bottom = 0.85
		inset = Vector2.ZERO
	big.offset_left = inset.x
	big.offset_top = inset.y
	big.offset_right = -inset.x
	big.offset_bottom = -inset.y
	big.border_width = 0.0
	big.hd = true
	big.show_character(leader, Kit.CATEGORY_COLORS.get(leader.get("category", ""), Kit.LINE))
	card.add_child(big)
	# 등급 띠: 그림 위쪽에 등급 글자와 이름(모두의 마블의 S+ 띠처럼)
	var grade := int(leader.get("grade", 1))
	var plate := Kit.label("%s  %s" % [["B", "A", "S"][clampi(grade - 1, 0, 2)], leader.get("name", "")], 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	plate.add_theme_constant_override("outline_size", 8)
	plate.add_theme_color_override("font_outline_color", Color("2a0f5a"))
	plate.add_theme_stylebox_override("normal", Kit.box(Color(0.42, 0.2, 0.85, 0.9), Color.TRANSPARENT, 0, 0, 4))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.anchor_left = 0.14 if has_fancy else 0.0
	plate.anchor_right = 0.86 if has_fancy else 1.0
	plate.anchor_top = 0.15 if has_fancy else 0.0
	plate.anchor_bottom = 0.15 if has_fancy else 0.0
	plate.offset_left = inset.x
	plate.offset_right = -inset.x
	plate.offset_top = inset.y
	plate.offset_bottom = inset.y + 46
	card.add_child(plate)
	var frame_path := fancy_path if has_fancy else "res://assets/ui_frames/hero_frame.png"
	if ResourceLoader.exists(frame_path):
		var frame := TextureRect.new()
		frame.texture = load(frame_path)
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frame)
	else:
		big.border_width = 4.0
		big.border = Kit.GOLD
	# 대표 영웅의 한마디: 분류마다 말투가 다르고, 들어올 때마다 바뀐다.
	var lines: Array = GREETINGS.get(str(leader.get("category", "")), GREETINGS["영웅"])
	var greeting := Kit.para(str(lines[app.rng.randi_range(0, lines.size() - 1)]), 18, Color("3a1f7a"), HORIZONTAL_ALIGNMENT_CENTER)
	greeting.remove_theme_color_override("font_shadow_color")
	greeting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	greeting.add_theme_stylebox_override("normal", Kit.box(Color(1, 1, 1, 0.94), Color("b79cff"), 3, 18, 6))
	holder.add_child(greeting)
	return holder


## 소식 배너: 그림 위에 큰 글씨로 지금의 공지가 돌아가며 나온다. 누르면 공지 목록.
func _banner() -> Control:
	var band := Button.new()
	band.custom_minimum_size = Vector2(0, 120)
	var band_style := Kit.box(Color(0.5, 0.1, 0.12, 0.95), Color("ffcf4d"), 3, 18, 8)
	for state in ["normal", "hover", "pressed"]:
		band.add_theme_stylebox_override(state, band_style)
	band.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	band.pressed.connect(_on_notices)
	var art := ArtView.new()
	art.show_art("ui/banner_event")
	if art.has_art():
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 4
		art.offset_top = 4
		art.offset_right = -4
		art.offset_bottom = -4
		art.focus_y = 0.5
		art.corner_radius = 14.0
		band.add_child(art)
	else:
		art.free()
	_notice_label = Kit.label("", 26, Color("ffe37a"))
	_notice_label.add_theme_constant_override("outline_size", 8)
	_notice_label.add_theme_color_override("font_outline_color", Color("4a0a0a"))
	_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_label.max_lines_visible = 3
	_notice_label.clip_text = true
	_notice_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_notice_label.offset_left = 20
	_notice_label.offset_right = -150
	_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band.add_child(_notice_label)
	_show_notice()
	return band


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
		["길잡이 과제", str(Profile.guide_current(profile, app.data).get("text", "모두 끝냈어요")), Profile.guide_current(profile, app.data).is_empty(), _on_tab.bind("missions")],
		["출석 체크", "하루 한 번 출석 보상", not Profile.can_check_in(profile, app.today()), _on_attendance_shortcut],
		["무료 소환", "오늘 %d번 남음" % Profile.free_summons_left(profile, app.eco), Profile.free_summons_left(profile, app.eco) <= 0, _on_tab.bind("shop")],
		["행운의 룰렛", "하루 한 번 무료", not Profile.can_spin_free(profile, app.eco), open_roulette],
		["홀짝 게임", "오늘 %d번 남음" % Profile.odd_even_left(profile, app.eco), Profile.odd_even_left(profile, app.eco) <= 0, open_odd_even],
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
		if bool(item[2]) or str(item[0]) == "모험 소탕":
			continue
		# 길잡이 과제는 보상을 받을 수 있을 때만 센다(진행 중일 때는 점을 띄우지 않는다).
		if str(item[0]) == "길잡이 과제" and not Profile.guide_claimable(app.profile, app.data):
			continue
		left += 1
	return left


func open_todo() -> void:
	app.play("click")
	var body := Kit.vbox(8)
	var window: Control = null
	var rows: Array = []
	for item in _todo_items():
		var done := bool(item[2])
		var line := Kit.panel(Color("13458f") if not done else Color("0f3d85"), Kit.LINE, 10)
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
		list.append("이벤트 [%s] %s (%s까지)" % [event["name"], event["text"], str(event.get("end", "")).substr(5)] if event.has("end") else "이벤트 [%s] %s" % [event["name"], event["text"]])
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
		var card := Kit.panel(Color("13458f"), Kit.LINE if claimed else Kit.GOLD, 12)
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
	"연출 새 단장과 전체 화면: 불·얼음·번개·마법진·충격 섬광 같은 효과를 직접 그린 그림으로 바꿨어요. 말 발밑에는 마법진이 돌고, 스킬 컷인에는 속도선과 빛살이 달려요. 화면을 누르면 전체 화면이 되고(설정에서 끌 수 있어요), 가로 화면 전용이 됐어요.",
	"입체 주사위와 소환 연출: 주사위가 진짜 입체 주사위 모양으로 바뀌었어요. 소환할 때는 마법진이 돌고 등급 색의 빛기둥이 솟아요. 스킬 효과는 영웅 분류마다 달라요(불꽃·별빛·얼음·금빛).",
	"더 살아난 판: 성문·왕좌·감옥·수정 구슬 같은 입체 물건이 칸 위에 서고, 스킬을 쓰면 앞쪽 칸에 빛기둥이 차례로 솟아요. 전투는 주사위를 하나씩 던지며 점수가 올라가고, 로비에는 오늘의 보상 구슬 줄이 생겼어요.",
	"가로 화면 대개편: 게임이 가로 화면으로 바뀌었어요. 로비는 큰 영웅 카드와 장식 액자, 맵은 손으로 그린 풍경 위의 두꺼운 육각 칸, 영웅 세 명이 함께 걷고, 주사위와 전투가 판 위에서 바로 벌어져요. 글 상자는 금테 장식 판으로, 화면마다 분위기 색이 달라졌어요.",
	"살아난 맵: 적 69종이 꼬마 입체 모형으로 칸 위에 서 있고, 맵마다 탑·야자수·이글루·화산 같은 꾸밈 모형이 놓였어요. 전투 창에서는 모형끼리 부딪치며 불꽃이 튀어요.",
	"입체 판과 연출: 판이 비스듬히 누운 입체 블록으로 바뀌고, 영웅 44명이 꼬마 입체 모형으로 판 위를 걸어요. 져서 돌아갈 때는 휙 날아가고, 칸마다 소용돌이·반짝임·창살 같은 효과가 살아 움직여요. 주사위는 빛살과 함께 멈추고, 스킬 버튼은 쓸 수 있을 때 금빛으로 빛나요.",
	"화면 새 단장: 둥글고 굵은 글꼴, 반짝이는 입체 버튼, 그림 아이콘, 금테 영웅 카드 로비, 영웅 이름이 크게 나오는 VS 연출, 그림으로 바뀐 보드 판과 칸 아이콘, 선명해진 영웅 그림.",
	"그림 대개편: 타이틀·로비·화면 바탕, 모험 표지, 아이템 카드 20장, 적 69종 초상화, 티어 문장과 유물 그림이 생겼어요. 처음 실행하면 오프닝 영상이 나오고, 설정에서 다시 볼 수 있어요.",
	"파티 시너지: 세 명이 같은 분류면 '결속', 모두 다르면 '조화'. 상점은 탭 4개로 정리했고 보석 마일리지가 생겼어요.",
	"새 맵 '왕국의 성벽'(성벽형)이 생겼어요. 성벽의 톱니처럼 오르내리는 길이에요.",
	"원정 보상: 접속하지 않은 동안에도 골드가 쌓여요(최대 8시간). 홀짝 게임, 주간 리그 보상과 훈장, 관문 업적도 생겼어요.",
	"랭크전은 트로피 500부터 상대가 조금씩 강해져요. 전투 창에는 적 그림이 나와요.",
	"유물 상점: 파티에 하나 장착하면 공격 보너스나 게이지, 부적을 들고 시작해요. 수집 앨범(영웅 화면)과 주말 골드 1.3배도 생겼어요.",
	"관문과 골의 수호자가 더 강해졌어요: 관문지기 주사위 3·4·4개, 골의 수호자 5개.",
	"관문이 생겼어요: 맵마다 3곳, 지나가다가도 반드시 멈춰 관문지기와 싸워요. 이기면 카드를 받고 다음부터는 그냥 지나가요.",
	"화면을 새로 꾸몄어요: 밝은 하늘색 바탕에 통통한 버튼, 로비는 영웅을 크게 두고 모드 타일 4개와 큰 '랭크전 시작'으로 바꿨어요.",
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


## 접속하지 않은 동안 쌓인 원정 골드를 준다.
func _maybe_idle_reward() -> void:
	var now := int(Time.get_unix_time_from_system())
	var hours := float(now - int(app.profile.get("idle_at", now))) / 3600.0
	var gold := Profile.claim_idle(app.profile, app.eco, now)
	app.save()
	if gold > 0:
		app.toast("원정 보상: %.1f시간 동안 골드 %d을 모았어요!" % [minf(hours, float(app.eco["idle"]["max_hours"])), gold])


## 주가 바뀌었으면 지난주 연습 리그 보상을 준다.
func _maybe_league_reward() -> void:
	var result := Profile.settle_league(app.profile, app.eco, app.today())
	app.save()
	if result.is_empty():
		return
	var text := "지난주 연습 리그 %d위!\n보상: %s" % [int(result["rank"]), Kit.reward_line(result["reward"])]
	if bool(result["medal"]):
		text += "\n훈장도 1개 받았어요. (프로필에서 볼 수 있어요)"
	app.message("주간 리그 결과", text)


# ---------------------------------------------------------------- 홀짝 게임

var _odd_even_text: Label
var _odd_even_die: Control

func open_odd_even() -> void:
	app.play("click")
	var body := Kit.vbox(12)
	body.add_child(Kit.para("주사위 한 개를 굴려요. 홀일까요, 짝일까요?\n맞히면 %s, 틀려도 %s" % [Kit.reward_line(app.eco["odd_even"]["win"]), Kit.reward_line(app.eco["odd_even"]["lose"])], 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	_odd_even_die = DiePreview.new()
	_odd_even_die.skin = Profile.current_dice_skin(app.profile, app.eco)
	_odd_even_die.face = 6
	_odd_even_die.custom_minimum_size = Vector2(120, 120)
	_odd_even_die.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(_odd_even_die)
	_odd_even_text = Kit.label("오늘 %d번 남았어요." % Profile.odd_even_left(app.profile, app.eco), 24, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(_odd_even_text)
	var row := Kit.hbox(12)
	body.add_child(row)
	var odd := Kit.button("홀 (1·3·5)", Color("e0532b"), 28, 92)
	odd.pressed.connect(_on_odd_even.bind("odd"))
	row.add_child(Kit.expand(odd))
	var even := Kit.button("짝 (2·4·6)", Color("19a8c9"), 28, 92)
	even.pressed.connect(_on_odd_even.bind("even"))
	row.add_child(Kit.expand(even))
	app.dialog("홀짝 게임", body, [["닫기", Kit.PANEL_LIGHT, _close_roulette]], 620)


func _on_odd_even(guess: String) -> void:
	var result := Profile.play_odd_even(app.profile, app.eco, guess, app.rng)
	if result.is_empty():
		app.toast("오늘은 다 했어요. 내일 또 와요!")
		return
	app.save()
	app.play("win" if bool(result["won"]) else "dice")
	if is_instance_valid(_odd_even_die):
		_odd_even_die.face = int(result["roll"])
		_odd_even_die.queue_redraw()
	if is_instance_valid(_odd_even_text):
		_odd_even_text.text = "%d! %s  %s  (남은 횟수 %d)" % [int(result["roll"]), "맞혔어요!" if bool(result["won"]) else "아쉬워요.",
			Kit.reward_line(result["reward"]), Profile.odd_even_left(app.profile, app.eco)]


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
		var fill: Color = Kit.PANEL_LIGHT if now else (Color("13458f") if done else Kit.PANEL)
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
	app.dialog("출석 보상", body, [["받기", Color("f39a1c"), _claim_attendance]])


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
	var colors := [Color("2f8f4e"), Color("f39a1c"), Color("b8323a")]
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
