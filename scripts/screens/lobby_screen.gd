extends Control
## 로비(홈). 왼쪽: 대표 영웅 / 오른쪽: 기능 타일(랭크전·모험·대전 모드·영웅·상점·미션·패스) / 위: 프로필·시스템 버튼·재화 / 아래: 파티·오늘 할 일.
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
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const Game := preload("res://scripts/rules/game.gd")
const LOBBY_ART := "res://assets/ui_lobby/"
## 로비 그림이 화면보다 몇 배로 저장됐나의 거꾸로(2배 → 0.5)
const SLICE_SCALE := 0.5

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
var _hero_area: Control
var _tile_column: Control
var _task_bar: Control
var _spin_info: Label


func setup(main_app, params: Dictionary) -> void:
	app = main_app
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 알림 띠(toast.gd)는 화면 맨 아래 가운데, 아래 띠(높이 92) 바로 위에 뜬다.
	set_meta("toast_bottom", 100.0)
	# 새 로비(2026-11-16, 밝은 캐주얼 + 명일방주식 배치):
	# 왼쪽 절반은 대표 영웅, 오른쪽 절반은 큰 기능 타일 묶음, 위는 프로필·시스템 버튼·재화, 아래는 파티와 오늘 할 일.
	# 그림 부품은 assets/ui_lobby/(Codex 주문서 job16, tools/import_lobby.py). 그림이 없으면 단색 상자로 대신한다.
	_add_background()

	# 새 우편이 있으면 우편함에 넣는다.
	if Profile.deliver_mails(app.profile, app.data.get("mails", {})) > 0:
		app.save()
	var badges: Dictionary = app.badges()

	_add_hero_area()
	_add_top_bar()
	_add_tiles(badges)
	_add_bottom_dock()
	resized.connect(_relayout)
	_relayout()

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


## 화면 비율이 달라도(휴대폰 20:9, 태블릿 4:3) 타일이 옆으로 늘어나지 않게 오른쪽 기둥 너비를 정하고,
## 남는 자리는 왼쪽 영웅 그림이 쓴다. 오늘 할 일 바도 화면 너비에 맞춘다.
func _relayout() -> void:
	if _tile_column == null:
		return
	var width := clampf(size.x * 0.525, 520.0, 680.0)
	_tile_column.offset_left = -width - 16.0
	_hero_area.offset_right = -width - 28.0
	if _task_bar != null:
		_task_bar.custom_minimum_size.x = clampf(size.x - 520.0, 300.0, 640.0)


# ---------------------------------------------------------------- 그림 부품 도우미

## 로비 그림 부품(assets/ui_lobby/이름.png). 없으면 null.
func _lobby_tex(name: String) -> Texture2D:
	for ext in [".png", ".jpg"]:
		var path: String = LOBBY_ART + name + str(ext)
		if ResourceLoader.exists(path):
			return load(path)
	return null


## 꽉 차게 늘어나는 그림 한 장. 그림이 없으면 null.
func _picture(name: String, stretch: int = TextureRect.STRETCH_SCALE) -> TextureRect:
	var tex := _lobby_tex(name)
	if tex == null:
		return null
	var rect := TextureRect.new()
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = stretch
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## 모서리는 그대로 두고 가운데만 늘어나는 판(타일·띠). 그림이 없으면 단색 상자.
func _slice(name: String, margin: int, fallback: Color) -> Control:
	var tex := _lobby_tex(name)
	if tex == null:
		var panel := Panel.new()
		panel.add_theme_stylebox_override("panel", Kit.box(fallback, Color(1, 1, 1, 0.5), 3, 18, 0))
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return panel
	# 로비 그림은 화면 크기의 약 2배로 저장돼 있다. 조각 판을 그대로 쓰면 모서리가 2배로 커져서
	# 작은 띠(높이 < 모서리×2)에서는 그림이 밖으로 삐져나온다. 그래서 2배 크기 판을 0.5배로 줄여 그린다.
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var patch := NinePatchRect.new()
	patch.texture = tex
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	patch.patch_margin_left = margin
	patch.patch_margin_right = margin
	patch.patch_margin_top = margin
	patch.patch_margin_bottom = margin
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.scale = Vector2.ONE * SLICE_SCALE
	wrap.add_child(patch)
	wrap.resized.connect(func() -> void: patch.size = wrap.size / SLICE_SCALE)
	return wrap


## 그림 몸통을 가진 버튼. 몸통은 art(늘어나는 그림) 또는 slice(가운데만 늘어남). 누르면 살짝 줄어든다.
func _art_button(body: Control) -> Button:
	var button := Button.new()
	button.flat = true
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	if body != null:
		button.add_child(body)
	button.resized.connect(func() -> void: button.pivot_offset = button.size / 2.0)
	button.button_down.connect(func() -> void: button.scale = Vector2(0.96, 0.96))
	button.button_up.connect(func() -> void: button.scale = Vector2.ONE)
	return button


## 아이콘: ic_로 시작하면 로비 전용 그림, 아니면 게임 공용 아이콘.
func _lobby_icon(name: String, pixels: float) -> TextureRect:
	if name.begins_with("ic_") and _lobby_tex(name) != null:
		var rect := _picture(name, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
		rect.custom_minimum_size = Vector2(pixels, pixels)
		return rect
	var fallback := {"ic_ai": "fate", "ic_friend_match": "friend", "ic_challenge": "attend", "ic_heroes_helmet": "heroes",
		"ic_shop_stall": "shop", "ic_mission_board": "missions", "ic_pass_ticket": "pass", "ic_trophy": "trophy",
		"ic_notice": "chat", "ic_party": "friend"}
	return Kit.icon(str(fallback.get(name, name)), pixels)


## 테두리가 있는 굵은 글자.
func _bold(text: String, font_size: int, color: Color, outline: Color, outline_size: int = 6, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var result := Kit.label(text, font_size, color, align)
	result.add_theme_constant_override("outline_size", outline_size)
	result.add_theme_color_override("font_outline_color", outline)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


## 오른쪽 위 빨간 알림 점. text가 있으면 빨간 딱지에 글자.
func _red_badge(parent: Control, text: String = "") -> void:
	var badge := PanelContainer.new()
	var style := Kit.box(Color("e8413b"), Color.WHITE, 2, 12, 2)
	style.content_margin_left = 8 if text != "" else 0
	style.content_margin_right = 8 if text != "" else 0
	badge.add_theme_stylebox_override("panel", style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if text != "":
		var label := Kit.label(text, 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		label.remove_theme_color_override("font_shadow_color")
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(label)
	else:
		badge.custom_minimum_size = Vector2(18, 18)
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.offset_right = 6
	badge.offset_top = -8
	parent.add_child(badge)


func _anchor(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0


## 안쪽 여백을 둔 상자(버튼 안 글자 배치용). 마우스는 통과시킨다.
func _inner(parent: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(margin)
	return margin


func _leader() -> Dictionary:
	var leader_id := str(app.profile.get("avatar", ""))
	if leader_id == "" or not Profile.owns(app.profile, leader_id):
		leader_id = str(app.profile["party"].get("attack", ""))
	return app.character(leader_id)


# ---------------------------------------------------------------- 바탕

func _add_background() -> void:
	var sky := _picture("lobby_sky", TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	if sky == null:
		add_child(Kit.sky())
		return
	add_child(sky)
	# 바탕 위에 떠다니는 빛 알갱이
	var ambience := Kit.Ambience.new()
	ambience.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ambience.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ambience)


# ---------------------------------------------------------------- 왼쪽: 대표 영웅

func _add_hero_area() -> void:
	var leader := _leader()
	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(area, 0.0, 0.09, 1.0, 0.87)
	_hero_area = area
	add_child(area)

	# 영웅 그림: 가장자리가 하늘로 스며들게 흐리게 지운다.
	var art := TextureRect.new()
	art.texture = GameData.portrait_hd(str(leader.get("id", "")))
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 10
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade := ShaderMaterial.new()
	fade.shader = _edge_fade_shader()
	art.material = fade
	area.add_child(art)

	# 그림을 누르면 한마디 하고 영웅 화면으로
	var touch := _art_button(null)
	touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch.pressed.connect(app.say.bind(str(leader.get("id", "")), "idle"))
	touch.pressed.connect(_on_tab.bind("heroes"))
	area.add_child(touch)

	# 말풍선: 분류마다 말투가 다르고, 들어올 때마다 바뀐다.
	var lines: Array = GREETINGS.get(str(leader.get("category", "")), GREETINGS["영웅"])
	# 누르면 나오는 음성(idle)과 같은 말을 보여 준다. 대사표에 없으면 분류별 인사말을 쓴다.
	var spoken := str(GameData.load_json("res://data/voice_lines.json").get("heroes", {}).get(str(leader.get("id", "")), {}).get("lines", {}).get("idle", ""))
	if spoken != "":
		lines = [spoken]
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", Kit.box(Color(1, 1, 1, 0.96), Color("1a56b0"), 3, 22, 12))
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(bubble, 0.6, 0.06, 0.6, 0.06)
	bubble.custom_minimum_size = Vector2(210, 0)
	var said := Kit.para(str(lines[app.rng.randi_range(0, lines.size() - 1)]), 18, Color("12264d"), HORIZONTAL_ALIGNMENT_CENTER)
	said.remove_theme_color_override("font_shadow_color")
	said.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(said)
	area.add_child(bubble)

	# 이름표: 등급 별과 이름
	var tag := Kit.vbox(0)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(tag, 0.03, 1.0, 0.03, 1.0)
	tag.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tag.offset_top = -86
	var grade := int(leader.get("grade", 1))
	tag.add_child(_bold("★".repeat(grade) + "  " + str(leader.get("category", "")), 18, Kit.GOLD, Color("12264d"), 5))
	tag.add_child(_bold(str(leader.get("name", "")), 44, Color.WHITE, Color("12264d"), 9))
	area.add_child(tag)


func _edge_fade_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float fx = smoothstep(0.0, 0.24, UV.x) * smoothstep(0.0, 0.2, 1.0 - UV.x);
	float fy = smoothstep(0.0, 0.14, UV.y) * smoothstep(0.0, 0.3, 1.0 - UV.y);
	c.a *= fx * fy;
	COLOR = c * COLOR;
}
"""
	return shader


# ---------------------------------------------------------------- 위: 프로필 · 시스템 버튼 · 재화

func _add_top_bar() -> void:
	var profile: Dictionary = app.profile
	var bar := Kit.hbox(8)
	bar.anchor_right = 1.0
	bar.offset_left = 14
	bar.offset_right = -14
	bar.offset_top = 8
	bar.offset_bottom = 66
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	# 프로필 띠: 금테 레벨 메달 + 닉네임 + 티어. 누르면 프로필 창.
	# 띠 그림과 버튼의 가로세로 비율이 같아서(약 5.2:1) 조각내지 않고 통째로 늘린다(메달이 찌그러지지 않게).
	var profile_art := _picture("plate_profile")
	var who := _art_button(profile_art if profile_art != null else _slice("", 0, Color("1a3f8f")))
	who.custom_minimum_size = Vector2(290, 56)
	who.pressed.connect(app.show_profile)
	bar.add_child(who)
	var medal := _bold(str(int(profile["level"])), 24, Color.WHITE, Color("12264d"), 6, HORIZONTAL_ALIGNMENT_CENTER)
	medal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 메달 안쪽 둥근 판은 그림의 가로 3.7%~19.6%, 세로 9.2%~83.3% 자리에 있다(그림에서 잰 값).
	_anchor(medal, 0.037, 0.092, 0.196, 0.833)
	who.add_child(medal)
	# 닉네임과 등급 줄을 바짝 붙인다(등급 줄이 띠 아래 가장자리에 너무 붙지 않게).
	var names := Kit.vbox(-7)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(names, 0.0, 0.0, 1.0, 1.0)
	names.offset_left = 70
	names.offset_right = -16
	names.offset_top = 5
	names.offset_bottom = -9
	who.add_child(names)
	names.add_child(_bold(str(profile["nickname"]), 19, Color.WHITE, Color("0b1f4d"), 5))
	var tier: Dictionary = Profile.tier_of(app.eco, int(profile["trophies"]))
	names.add_child(_bold("%s · 리그 %d위" % [tier["name"], Profile.league_rank(profile, app.eco)], 13, Kit.GOLD, Color("0b1f4d"), 4))

	# 시스템 버튼: 아이콘 아래에 이름을 적는다(기준 그림처럼). 설정 · 공지 · 우편 · 출석 · 룰렛 · 리그 · 방법
	var system_buttons := [
		["설정", "settings", false, _on_tab.bind("settings")],
		["공지", "ic_notice", false, _on_notices],
		["우편", "mail", Profile.unclaimed_mail_count(profile) > 0, open_mailbox],
		["출석", "attend", Profile.can_check_in(profile, app.today()), _on_attendance_shortcut],
		["룰렛", "roulette", Profile.can_spin_free(profile, app.eco), open_roulette],
		["리그", "league", false, _on_league],
		["방법", "help", false, _on_help],
	]
	var divider := ColorRect.new()
	divider.color = Color(1, 1, 1, 0.45)
	divider.custom_minimum_size = Vector2(2, 40)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(divider)
	for spec in system_buttons:
		var button := _art_button(_slice("btn_sys", 24, Color("1a3f8f")))
		button.custom_minimum_size = Vector2(56, 56)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(spec[3])
		var glyph := _lobby_icon(str(spec[1]), 32.0)
		_anchor(glyph, 0.5, 0.0, 0.5, 0.0)
		glyph.offset_left = -16
		glyph.offset_right = 16
		glyph.offset_top = 4
		glyph.offset_bottom = 36
		button.add_child(glyph)
		var caption := _bold(str(spec[0]), 14, Color.WHITE, Color("0b1f4d"), 4, HORIZONTAL_ALIGNMENT_CENTER)
		_anchor(caption, 0.0, 1.0, 1.0, 1.0)
		caption.offset_top = -23
		caption.offset_bottom = -3
		button.add_child(caption)
		Kit.fit_text(caption, button, 4.0, 13, 9)
		if bool(spec[2]):
			_red_badge(button)
		bar.add_child(button)

	bar.add_child(Kit.expand(Control.new()))

	# 재화: 골드 · 보석. 메뉴 화면과 같은 캡슐(currency + 초록 더하기), 더하기는 상점으로.
	for spec in [["gold", Kit.GOLD, int(profile["gold"]), "grow"], ["gem", Kit.GEM, int(profile["gems"]), "gems"]]:
		var chip: Control = MenuArt.money_chip(str(spec[0]), int(spec[2]), spec[1], _on_shop_tab.bind(str(spec[3])))
		chip.custom_minimum_size = Vector2(212, 50)
		bar.add_child(chip)


func _on_shop_tab(tab: String) -> void:
	app.play("click")
	app.go("shop", {"tab": tab})


# ---------------------------------------------------------------- 오른쪽: 기능 타일

func _add_tiles(badges: Dictionary) -> void:
	var column := Kit.vbox(10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(column, 1.0, 0.115, 1.0, 0.855)
	column.offset_right = -16
	_tile_column = column
	add_child(column)

	# 1줄: 랭크전(가장 큼) + 모험
	var row1 := Kit.hbox(10)
	row1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row1.size_flags_stretch_ratio = 1.63
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row1)
	row1.add_child(_rank_tile())
	row1.add_child(_adventure_tile())

	# 2줄: 다른 대전 모드(흰 타일)
	var row2 := Kit.hbox(10)
	row2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row2)
	var difficulty: Dictionary = Profile.ai_difficulty(app.eco, str(app.profile.get("ai_difficulty", "easy")))
	var done := Profile.challenge_done(app.profile)
	var modes := [
		["AI전", "AI BATTLE", "ic_ai", "최근 %s" % difficulty["name"], false, _choose_difficulty],
		["친구 대전", "FRIEND MATCH", "ic_friend_match", "한 기기 2인", false, _on_mode.bind("local")],
		["오늘의 도전", "TODAY'S CHALLENGE", "ic_challenge", "오늘 완료!" if done else "하루 한 번", not done, _on_mode.bind("challenge")],
	]
	for spec in modes:
		row2.add_child(_white_tile(spec))

	# 3줄: 육성·운영(진파랑 타일)
	var row3 := Kit.hbox(10)
	row3.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row3)
	var free_summon := Profile.free_summons_left(app.profile, app.eco) > 0
	var menus := [
		["영웅", "HEROES", "ic_heroes_helmet", "" if not bool(badges.get("heroes", false)) else "dot", "heroes"],
		["상점", "SHOP", "ic_shop_stall", "무료 소환" if free_summon else ("dot" if bool(badges.get("shop", false)) else ""), "shop"],
		["미션", "MISSION", "ic_mission_board", "dot" if bool(badges.get("missions", false)) else "", "missions"],
		["시즌 패스", "SEASON PASS", "ic_pass_ticket", "dot" if Profile.pass_claimable_count(app.profile, app.eco) > 0 else "", "pass"],
	]
	for spec in menus:
		row3.add_child(_navy_tile(spec))


func _rank_tile() -> Button:
	var profile: Dictionary = app.profile
	var tile := _art_button(_picture("tile_rank"))
	if tile.get_child_count() == 0:
		tile.add_child(_slice("", 0, Kit.PRIMARY))
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_stretch_ratio = 1.6
	tile.pressed.connect(_on_mode.bind("rank"))
	Kit.shimmer(tile)
	var inner := _inner(tile, 22, 14, 22, 18)
	var stack := Kit.vbox(0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(stack)
	stack.add_child(_bold("RANK MATCH", 14, Color(1, 1, 1, 0.92), Color("a3480a"), 4))
	stack.add_child(_bold("랭크전", 50, Color.WHITE, Color("a3480a"), 10))
	var tier: Dictionary = Profile.tier_of(app.eco, int(profile["trophies"]))
	var streak := Profile.streak(profile)
	var note := "%s · 트로피 %s" % [tier["name"], Kit.comma(int(profile["trophies"]))]
	if streak >= 2:
		note = "%d연승 중! · 트로피 %s" % [streak, Kit.comma(int(profile["trophies"]))]
	stack.add_child(_bold(note, 18, Color("fff3c4"), Color("a3480a"), 5))
	stack.add_child(Kit.expand(Control.new()))
	# 진행 중 이벤트 띠(명일방주의 '작전' 버튼처럼 이벤트를 타일 안에 보여 준다)
	var events: Array = Profile.active_events(app.data.get("events", {}), app.today())
	var strip := Control.new()
	strip.custom_minimum_size = Vector2(0, 40)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 띠 그림은 왼쪽 빨간 딱지 자리가 넓어서 조각내지 않고 통째로 늘린다.
	var strip_art := _picture("strip_event")
	strip.add_child(strip_art if strip_art != null else _slice("", 0, Color("fff4dc")))
	stack.add_child(strip)
	var chip := _bold("EVENT" if not events.is_empty() else "GO", 14, Color.WHITE, Color("7a0f0f"), 3, HORIZONTAL_ALIGNMENT_CENTER)
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 띠 그림의 빨간 딱지 자리(가로 6.5~26%, 세로 19~76%)에 맞춘다.
	_anchor(chip, 0.065, 0.19, 0.26, 0.76)
	strip.add_child(chip)
	var event_text := str(events[0]["name"]) if not events.is_empty() else "지금 바로 대전 시작!"
	var line := Kit.label(event_text, 17, Color("b5450c"))
	line.remove_theme_color_override("font_shadow_color")
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.clip_text = true
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(line, 0.29, 0.0, 0.86, 1.0)
	strip.add_child(line)
	return tile


func _adventure_tile() -> Button:
	var tile := _art_button(_picture("tile_adventure"))
	if tile.get_child_count() == 0:
		tile.add_child(_slice("", 0, Kit.ACCENT))
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.pressed.connect(_on_adventure)
	var inner := _inner(tile, 16, 12, 16, 16)
	var stack := Kit.vbox(0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(stack)
	stack.add_child(_bold("모험", 40, Color.WHITE, Color("0f5a2c"), 9))
	stack.add_child(_bold("ADVENTURE", 13, Color.WHITE, Color("0f5a2c"), 4))
	stack.add_child(Kit.expand(Control.new()))
	var stars := Profile.total_stars(app.profile)
	var most := _max_stars()
	var ratio := float(stars) / float(max(most, 1))
	# 진행도 캡슐(기준 그림처럼 어두운 띠 안에 글자와 막대)
	var capsule := PanelContainer.new()
	var capsule_style := Kit.box(Color(0.02, 0.18, 0.08, 0.72), Color(1, 1, 1, 0.55), 2, 14, 6)
	capsule_style.content_margin_left = 10
	capsule_style.content_margin_right = 10
	capsule.add_theme_stylebox_override("panel", capsule_style)
	capsule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(capsule)
	var inside := Kit.vbox(3)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capsule.add_child(inside)
	var line := Kit.hbox(4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(line)
	line.add_child(_bold("★ %d / %d" % [stars, most], 15, Kit.GOLD, Color("0b2a14"), 4))
	line.add_child(Kit.expand(Control.new()))
	line.add_child(_bold("%d%%" % int(round(ratio * 100.0)), 15, Color.WHITE, Color("0b2a14"), 4))
	inside.add_child(Kit.bar(ratio, Kit.GOLD, 9))
	return tile


## 타일 오른쪽 아래 꺾쇠(>): 누르면 들어간다는 표시
func _chevron(parent: Control, color: Color, outline: Color) -> void:
	var mark := _bold(">", 22, color, outline, 4, HORIZONTAL_ALIGNMENT_RIGHT)
	_anchor(mark, 1.0, 1.0, 1.0, 1.0)
	mark.offset_left = -38
	mark.offset_right = -20
	mark.offset_top = -40
	mark.offset_bottom = -14
	parent.add_child(mark)


## spec: [이름, 영어, 아이콘, 설명, 빨간 점, 누르면]
func _white_tile(spec: Array) -> Button:
	var tile := _art_button(_slice("tile_white", 40, Color("f2f6ff")))
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.pressed.connect(spec[5])
	var inner := _inner(tile, 12, 8, 30, 10)
	var row := Kit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(row)
	var glyph := _lobby_icon(str(spec[2]), 62.0)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var text := Kit.vbox(-2)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Kit.expand(text))
	var title := Kit.label(str(spec[0]), 25, Color("12264d"))
	title.remove_theme_color_override("font_shadow_color")
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title)
	Kit.fit_text(title, tile, 84.0, 25)
	var english := Kit.label(str(spec[1]), 12, Color("4a6aa8"))
	english.remove_theme_color_override("font_shadow_color")
	english.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 영어 부제는 한국어 화면에서만(다른 언어는 제목과 겹친다).
	english.visible = Lang.current == "ko"
	text.add_child(english)
	var sub := Kit.label(str(spec[3]), 14, Color("c4421f") if bool(spec[4]) else Color("3d5585"))
	sub.remove_theme_color_override("font_shadow_color")
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(sub)
	_chevron(tile, Color("2b5fc4"), Color.WHITE)
	if bool(spec[4]):
		_red_badge(tile)
	return tile


## spec: [이름, 영어, 아이콘, 딱지("" 없음, "dot" 빨간 점, 그 밖은 글자), 화면 이름]
func _navy_tile(spec: Array) -> Button:
	var tile := _art_button(_slice("tile_navy", 34, Color("17398a")))
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.pressed.connect(_on_tab.bind(str(spec[4])))
	# 좌우 여백을 같게 해야 아이콘+글자 묶음이 가운데에 온다(> 표시는 아래쪽이라 글자와 겹치지 않는다).
	var inner := _inner(tile, 10, 8, 10, 10)
	var row := Kit.hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(row)
	var glyph := _lobby_icon(str(spec[2]), 46.0)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var text := Kit.vbox(-2)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var title := _bold(str(spec[0]), 22, Color.WHITE, Color("0b1f4d"), 5)
	text.add_child(title)
	# 글자 칸 = 타일 너비 - 좌우 여백(20) - 아이콘(46) - 틈(4) - 여유(4). 넘치면 묶음이 오른쪽으로 밀려났다.
	Kit.fit_text(title, tile, 74.0, 22)
	var english := Kit.label(str(spec[1]), 11, Color(1, 1, 1, 0.8))
	english.mouse_filter = Control.MOUSE_FILTER_IGNORE
	english.visible = Lang.current == "ko"
	text.add_child(english)
	_chevron(tile, Color.WHITE, Color("0b1f4d"))
	var mark := str(spec[3])
	if mark == "dot":
		_red_badge(tile)
	elif mark != "":
		_red_badge(tile, mark)
	return tile


# ---------------------------------------------------------------- 아래: 파티 · 오늘 할 일

func _add_bottom_dock() -> void:
	var dock := Control.new()
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(dock, 0.0, 1.0, 1.0, 1.0)
	dock.offset_top = -92
	add_child(dock)
	dock.add_child(_slice("dock_bottom", 40, Color(0.06, 0.15, 0.4, 0.92)))

	var row := Kit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(row, 0.0, 0.0, 1.0, 1.0)
	row.offset_left = 18
	row.offset_right = -18
	row.offset_top = 12
	row.offset_bottom = -8
	dock.add_child(row)

	# 출전 파티: 누르면 영웅 화면(파티 편성)
	var party_button := _art_button(null)
	party_button.custom_minimum_size = Vector2(440, 0)
	party_button.pressed.connect(_on_tab.bind("heroes"))
	row.add_child(party_button)
	var party_row := Kit.hbox(8)
	party_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	party_button.add_child(party_row)
	party_row.add_child(_lobby_icon("ic_party", 40.0))
	var title := Kit.vbox(-2)
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_row.add_child(title)
	title.add_child(_bold("내 파티", 20, Color.WHITE, Color("0b1f4d"), 4))
	var english := Kit.label("MY PARTY", 11, Color(1, 1, 1, 0.75))
	english.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(english)
	var party: Dictionary = app.profile["party"]
	var categories: Array = []
	for slot in ["attack", "defense", "support"]:
		var member: Dictionary = app.character(str(party.get(slot, "")))
		categories.append(str(member.get("category", "")))
		party_row.add_child(_framed_face(member))
	var synergy: Dictionary = Game.synergy_of(app.data.get("rules", {}).get("synergy", {}), categories)
	if not synergy.is_empty():
		var chip := PanelContainer.new()
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var chip_style := Kit.box(Kit.ACCENT, Color.WHITE, 2, 18, 6)
		chip_style.content_margin_left = 14
		chip_style.content_margin_right = 14
		chip.add_theme_stylebox_override("panel", chip_style)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(_bold(str(synergy.get("name", "")), 20, Color.WHITE, Color("0f5a2c"), 4))
		party_row.add_child(chip)

	row.add_child(Kit.expand(Control.new()))

	# 오늘 할 일 바: 남은 일 수와 진행 막대, 초록 '가기'
	var items := _todo_items()
	var finished := 0
	for item in items:
		if bool(item[2]):
			finished += 1
	# bar_task 그림은 가운데에 진행 막대 홈이 있어 글자와 겹치므로, 홈이 없는 재화 캡슐 그림을 쓴다.
	var task := _art_button(_slice("plate_currency", 40, Color("17398a")))
	task.custom_minimum_size = Vector2(600, 0)
	_task_bar = task
	task.pressed.connect(open_todo)
	row.add_child(task)
	var task_row := Kit.hbox(10)
	task_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(task_row, 0.0, 0.0, 1.0, 1.0)
	task_row.offset_left = 18
	task_row.offset_right = -10
	task_row.offset_top = 6
	task_row.offset_bottom = -6
	task.add_child(task_row)
	var todo_icon := Kit.icon("todo", 36.0)
	todo_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	task_row.add_child(todo_icon)
	var head := Kit.vbox(-2)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	task_row.add_child(head)
	head.add_child(_bold("오늘 할 일", 20, Color.WHITE, Color("0b1f4d"), 4))
	var sub := Kit.label("TODAY'S TASK", 11, Color(1, 1, 1, 0.75))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(sub)
	var progress := Kit.vbox(4)
	progress.alignment = BoxContainer.ALIGNMENT_CENTER
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	task_row.add_child(Kit.expand(progress))
	var left := _todo_left()
	progress.add_child(_bold("남은 일 %d개 · 완료 %d / %d" % [left, finished, items.size()], 16, Color.WHITE, Color("0b1f4d"), 4))
	progress.add_child(Kit.bar(float(finished) / float(max(items.size(), 1)), Kit.GOLD, 10))
	var go := Kit.button("가기", Kit.ACCENT, 22, 48)
	go.custom_minimum_size = Vector2(96, 48)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(open_todo)
	task_row.add_child(go)
	if left > 0:
		_red_badge(task)


## 액자에 넣은 작은 초상화: ★★★는 금테, 나머지는 은테(assets/ui_kit/slot_frame*). 아래에 별, 오른쪽 아래에 레벨.
func _framed_face(member: Dictionary) -> Control:
	var grade := int(member.get("grade", 1))
	var gold := grade >= 3
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(60, 72)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 액자 그림의 안쪽 창 자리(가로·세로 비율). slot_frame 155×170, slot_frame_gold 162×170.
	var window := Rect2(0.14, 0.2, 0.72, 0.64) if gold else Rect2(0.08, 0.17, 0.84, 0.74)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(box, 0.0, 0.0, 1.0, 0.0)
	box.offset_bottom = 62
	holder.add_child(box)
	var face := Portrait.new()
	face.border_width = 0.0
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.show_character(member, Kit.CATEGORY_COLORS.get(member.get("category", ""), Kit.LINE))
	_anchor(face, window.position.x, window.position.y, window.end.x, window.end.y)
	box.add_child(face)
	var frame_path := "res://assets/ui_kit/%s.png" % ("slot_frame_gold" if gold else "slot_frame")
	if ResourceLoader.exists(frame_path):
		var frame := TextureRect.new()
		frame.texture = load(frame_path)
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(frame)
	else:
		face.border_width = 3.0
		face.border = Kit.GRADE_COLORS.get(grade, Kit.GOLD)
	var id := str(member.get("id", ""))
	if id != "" and Profile.owns(app.profile, id):
		var level := _bold("Lv.%d" % Profile.level_of(app.profile, id), 11, Color.WHITE, Color("0b1f4d"), 3, HORIZONTAL_ALIGNMENT_RIGHT)
		_anchor(level, 0.0, 0.0, 1.0, 0.0)
		level.offset_top = 40
		level.offset_bottom = 54
		level.offset_right = -8
		box.add_child(level)
	var stars := _bold("★".repeat(grade), 12, Kit.GOLD, Color("3a2400"), 3, HORIZONTAL_ALIGNMENT_CENTER)
	_anchor(stars, 0.0, 1.0, 1.0, 1.0)
	stars.offset_top = -14
	holder.add_child(stars)
	return holder


func _on_league() -> void:
	app.play("click")
	app.show_league()


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
		var line := MenuArt.row(10)
		var row := Kit.hbox(10)
		line.add_child(row)
		var text := Kit.vbox(0)
		text.add_child(Kit.label(str(item[0]), 24, Color.WHITE if not done else Kit.MUTED))
		text.add_child(Kit.label(str(item[1]), 18, Kit.MUTED))
		row.add_child(Kit.expand(text))
		if done:
			var mark := Kit.hbox(4)
			mark.custom_minimum_size = Vector2(120, 0)
			mark.alignment = BoxContainer.ALIGNMENT_CENTER
			var check: TextureRect = Kit.icon("m_check", 34.0)
			check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			mark.add_child(check)
			mark.add_child(Kit.label("완료", 22, Color("6fd08c")))
			row.add_child(mark)
		else:
			var go := MenuArt.pill_button("가기", "green", "m")
			go.custom_minimum_size = Vector2(120, 56)
			go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
		# 목록 줄(남색 + 얇은 금테): 왼쪽 우편 아이콘 · 제목(24)·내용(20)·선물 캡슐 · 오른쪽 받기 알약
		var card := MenuArt.row(12)
		var row := Kit.hbox(12)
		card.add_child(row)
		var mail_icon: TextureRect = Kit.icon("mail", 52.0)
		mail_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if claimed:
			mail_icon.modulate = Color(0.6, 0.6, 0.7)
		row.add_child(mail_icon)
		var info := Kit.vbox(4)
		row.add_child(Kit.expand(info))
		info.add_child(Kit.label(str(entry["title"]), 24, Kit.MUTED if claimed else Color.WHITE))
		info.add_child(Kit.para(str(entry["text"]), 20, Kit.MUTED))
		info.add_child(MenuArt.reward_capsules(entry["reward"]))
		var take := MenuArt.pill_button("받음" if claimed else "받기", "gray" if claimed else "gold", "m")
		take.custom_minimum_size = Vector2(130, 56)
		take.disabled = claimed
		take.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		take.pressed.connect(_on_mail_claim.bind(str(entry["id"])))
		row.add_child(take)
		body.add_child(card)
	var buttons: Array = []
	if Profile.unclaimed_mail_count(app.profile) > 1:
		buttons.append(["모두 받기", Color("e8890c"), _on_mail_claim_all])
	buttons.append(["닫기", Kit.PANEL_LIGHT, _close_roulette])
	app.dialog("우편함", body, buttons, 720)


func _on_mail_claim(id: String) -> void:
	var reward := Profile.claim_mail(app.profile, id)
	if reward.is_empty():
		return
	app.save()
	app.play("reward")
	MenuArt.fly_reward(app, null, reward)
	_close_all_dialogs()
	app.go("lobby")
	app.toast("우편 선물: %s" % Kit.reward_line(reward))


func _on_mail_claim_all() -> void:
	var total := Profile.claim_all_mail(app.profile)
	if int(total["count"]) == 0:
		return
	app.save()
	app.play("win")
	MenuArt.fly_reward(app, null, {"gold": int(total["gold"]), "gems": int(total["gems"])})
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
	_spin_button = Kit.button("", Color("e8890c"), 28, 72)
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
	app.play("reward")
	app.toast("룰렛 보상: %s" % Kit.reward_line(result["reward"]))
	MenuArt.fly_reward(app, _spin_button, result["reward"])
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
	"새 소환 연출: 별빛 제단에 운명의 주사위가 내려와 파랑→보라→금으로 바뀌고, 카드가 뒤집혀요. ★★★는 등장 장면이 따로 나와요.",
	"파티 자동 추천이 강화를 따져요: 레벨이 높은 영웅을 더 잘 골라요. 자리 카드에 전투 보너스(+n)도 보여요.",
	"갈림길·싸울지 고르기와 안내 말풍선은 고를 때까지 사라지지 않아요.",
	"대전 알림이 더 오래 떠요: 칸 효과·스킬·말풍선·기록이 글 길이에 맞춰 충분히 보인 뒤 사라져요.",
	"영웅 강화 효과가 바뀌었어요: Lv1 스킬 충전↑, Lv2 전투 +1, Lv3 스킬 충전↑, Lv4 전투 +1, Lv5 전투 +2 (모두 쌓여요).",
	"로비 아래 메뉴(영웅·상점·미션·시즌 패스) 글자가 가운데로 정렬됐어요.",
	"긴 영웅 이름(아멜리아 에어하트 등)도 카드 안에 다 보여요: 글자를 줄이거나 자간을 좁혀요.",
	"파티 편성 카드: 아래 띠의 ★과 영웅 이름이 가려지지 않고 끝까지 보여요.",
	"화면 연출 새 단장: 메뉴 화면이 부드럽게 나타나고, 보상을 받으면 금화와 보석이 위쪽 재화 칸으로 날아가요. 알림은 내용을 가리지 않게 위 줄이나 화면 아래에 떠요.",
	"창과 결과 화면 새 단장: 창 글자가 커지고 버튼이 금테 알약으로 바뀌었어요. AI 난이도는 카드 3장, 룰렛은 금테 바퀴, 대전 결과는 MVP 카드와 보상 칸, 상대를 찾을 때는 금빛 주사위 문양이 돌아요.",
	"메뉴 화면 버튼을 금테 알약 하나로 맞추고, 상점·미션·설정·모험·패스·파티 화면 안쪽을 새 목록 줄로 바꿨어요.",
	"게임 방법·파티 편성 화면도 새 틀로 바뀌었어요.",
	"타이틀 화면 새 단장: 금빛 로고와 리본 부제가 생겼어요.",
	"메뉴 화면 틀을 바꿨어요: 왼쪽에 그 화면의 항목, 오른쪽에 큰 금테 판, 위에 홈 버튼과 제목 명판.",
	"메뉴 화면 새 단장: 왼쪽 메뉴·위 띠·재화 칸·영웅 카드가 금테 그림으로 바뀌었어요.",
	"언제나 가로 화면: 휴대폰을 세로로 들어도 게임이 스스로 돌아 가로로 보여요. \"돌려 주세요\" 안내는 없어졌어요.",
	"대전 화면 새 단장: 정보판·스킬 카드·카드 칸·턴 띠·버튼이 금테 그림으로 바뀌었어요.",
	"영웅 모형이 또렷해졌어요: 48명 모두 더 크고 선명한 그림으로 다시 찍었어요.",
	"영웅 48명이 모두 움직여요: 남은 38명도 3D 모델로 바뀌어 판 위에서 숨 쉬고 걸어요.",
	"갈림길 안개: 두 갈래 길의 칸은 안개에 가려 칸 종류와 적이 보이지 않아요. 말이 밟고 지나가면 걷혀요.",
	"대전이 가벼워졌어요: 판을 덜 자주 다시 그리고, 그래픽카드가 약한 기기를 위한 저사양 모드가 생겼어요(설정). 대전이 계속 버벅이면 저절로 켜져요.",
	"이순신도 3D 모델로 바뀌어 판 위에서 숨 쉬고 걸어요.",
	"움직이는 영웅 9명: 여포, 아테나, 주유, 최치원, 감녕, 최영, 도깨비, 해태, 이백이 3D 모델로 바뀌어 판 위에서 숨 쉬고 걸어요. 파티원 두 명도 함께 움직여요.",
	"소리가 더 풍성해졌어요: 칸마다 다른 효과음, \"전투!\" \"내 차례!\" 안내 음성, 적들의 목소리. 설정에서 효과음·음성·음악 크기를 따로 조절할 수 있어요.",
	"새 로비: 왼쪽에 대표 영웅, 오른쪽에 큰 타일(랭크전·모험·AI전·친구 대전·오늘의 도전·영웅·상점·미션·시즌 패스)로 로비를 새로 꾸몄어요. 진행 중 이벤트는 랭크전 타일 안에, 출전 파티와 오늘 할 일은 아래 띠에 보여요.",
	"배경음악이 7곡으로 늘었어요: 타이틀·로비·상점·대전·관문 전투·승리·패배. 화면마다 다른 곡이 나와요.",
	"영웅 48명이 말을 해요! 도감에서 누르거나 이동·공격·방어·스킬·승패 때 목소리가 나와요. 효과음도 새로 녹음했어요. (설정에서 끌 수 있어요)",
	"움직이는 영웅(시험): 여포가 3D 모델로 바뀌어 판 위에서 숨 쉬고 걸어 다녀요.",
	"UI 새 단장: 버튼, 창, 칸 테두리, 제목 리본, 메뉴 아이콘을 손으로 그린 그림으로 바꿨어요.",
	"스킬 설명 보기: 대전 중에 '스킬 설명' 버튼이나 아직 못 쓰는 스킬 버튼을 누르면 세 영웅의 스킬 설명을 볼 수 있어요.",
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
	# 칸은 모두 같은 크기, 줄마다 가운데 맞춤(7일이면 4칸 + 3칸).
	var grid := Kit.vbox(10)
	var row: HBoxContainer = null
	for day in table.size():
		if day % 4 == 0:
			row = Kit.hbox(10)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			grid.add_child(row)
		var reward: Dictionary = table[day]
		var done := day < today_index
		var now := day == today_index
		var cell: PanelContainer = MenuArt.day_cell(day + 1, Kit.reward_line(reward), now, done)
		cell.custom_minimum_size = Vector2(150, 116)
		cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(cell)
	var body := Kit.vbox(12)
	body.add_child(Kit.para("매일 접속하면 보상을 받아요. 7일마다 다시 시작합니다.", 20, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(grid)
	app.dialog("출석 보상", body, [["받기", Color("f39a1c"), _claim_attendance]])


func _claim_attendance() -> void:
	var reward := Profile.check_in(app.profile, app.eco, app.today())
	if reward.is_empty():
		return
	app.save()
	app.play("win")
	app.toast("출석 보상: %s" % Kit.reward_line(reward))
	MenuArt.fly_reward(app, null, reward)
	app.go("lobby")


func _on_adventure() -> void:
	app.play("click")
	app.go("adventure")


func _on_help() -> void:
	app.play("click")
	app.go("help", {"back": "lobby"})


## AI 연습전 난이도 고르기: 쉬움·보통·어려움을 가로 카드 3장(이름, 상대 레벨, 보상 배수)으로.
func _choose_difficulty() -> void:
	app.play("click")
	var body := Kit.vbox(14)
	body.add_child(Kit.para("어려울수록 상대 영웅 레벨이 높고 조합을 잘 짜요. 보상도 많아져요.", 20, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var cards := Kit.hbox(18)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(cards)
	var looks := [["green", Color("2f8f4e")], ["blue", Color("2f74d6")], ["red", Color("b8323a")]]
	var list: Array = app.eco.get("ai_difficulty", [])
	for index in list.size():
		var look: Array = looks[index % looks.size()]
		cards.add_child(_difficulty_card(list[index], str(look[0]), look[1]))
	app.dialog("AI 연습전 난이도", body, [["닫기", Kit.PANEL_LIGHT]], 700)


## 난이도 카드 한 장: 위 띠에 이름, 가운데 상대 레벨·보상 배수, 아래 시작 알약. 그림(ai_card_색)이 없으면 단색 판.
func _difficulty_card(entry: Dictionary, color_name: String, color: Color) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(196, 262)
	var art := MenuArt.tex("ai_card_" + color_name)
	if art != null:
		var back := TextureRect.new()
		back.texture = art
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_SCALE
		back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(back)
	else:
		var plain := Panel.new()
		plain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		plain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plain.add_theme_stylebox_override("panel", Kit.box(Color("13458f"), color, 4, 16, 6))
		card.add_child(plain)
	# 위 띠(그림 높이의 9%~18%)에 이름
	var name_label := _bold(str(entry["name"]), 24, Color.WHITE, color.darkened(0.55), 6, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_anchor(name_label, 0.0, 0.075, 1.0, 0.195)
	card.add_child(name_label)
	var middle := Kit.vbox(4)
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(middle, 0.06, 0.22, 0.94, 0.72)
	card.add_child(middle)
	var face: TextureRect = _lobby_icon("ic_ai", 56.0)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	middle.add_child(face)
	middle.add_child(_bold("상대 레벨 %d" % int(entry["level"]), 20, Color.WHITE, Color("0b1f4d"), 5, HORIZONTAL_ALIGNMENT_CENTER))
	middle.add_child(_bold("보상 ×%s" % str(entry["reward_scale"]), 20, Kit.GOLD, Color("3a2400"), 5, HORIZONTAL_ALIGNMENT_CENTER))
	var start := MenuArt.pill_button("시작", "green" if color_name == "green" else ("blue" if color_name == "blue" else "red"), "s")
	_anchor(start, 0.12, 0.74, 0.88, 0.74)
	start.offset_bottom = 46
	start.pressed.connect(func() -> void:
		_close_all_dialogs()
		_start_ai(str(entry["id"])))
	card.add_child(start)
	return card


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
