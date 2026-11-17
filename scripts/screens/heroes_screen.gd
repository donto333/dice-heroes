extends Control
## 영웅 화면: 지금 파티, 파티 편성 버튼, 영웅 도감(48명). 영웅을 누르면 정보와 강화 창이 뜬다.
## 가지지 않은 영웅은 어둡게 보이고, 상점에서 소환하면 얻는다.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const TopBar := preload("res://scripts/ui/top_bar.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const BottomNav := preload("res://scripts/ui/bottom_nav.gd")

## 분류 → 알약 색
const CATEGORY_PILLS := {"": "blue", "영웅": "red", "위인": "blue", "신화": "purple", "근현대": "green"}
const STAT_NAMES := [["move", "이동"], ["attack", "공격"], ["defense", "방어"], ["intellect", "지력"]]

var app
var _filter := ""
var _owned_only := false
var _grid: GridContainer
var _tabs: Dictionary = {}
var _owned_button: Button
var _count_label: Label


func setup(main_app, params: Dictionary) -> void:
	app = main_app
	_filter = str(params.get("filter", ""))
	# 시안식 틀: 왼쪽 세로 판에 영웅 목록·앨범·파티 편성, 오른쪽 큰 금테 판.
	var rail := [["list", "영웅 목록", "heroes"], ["album", "영웅 앨범", "album"], ["party", "파티 편성", "swords"]]
	var column := MenuArt.frame(self, app, "ui/bg_heroes", rail, "list", _on_rail, _summary_card())

	var header := Kit.hbox(10)
	column.add_child(header)
	_count_label = Kit.label("", 28, Kit.GOLD)
	header.add_child(Kit.expand(_count_label))
	var all_up := MenuArt.pill_button("일괄 강화", "green", "m")
	all_up.custom_minimum_size = Vector2(150, 52)
	all_up.disabled = not bool(app.badges().get("heroes", false))
	all_up.pressed.connect(_upgrade_all)
	header.add_child(all_up)
	_owned_button = MenuArt.pill_button("보유만 보기", "blue", "m")
	_owned_button.custom_minimum_size = Vector2(190, 52)
	_owned_button.pressed.connect(_on_owned_toggle)
	header.add_child(_owned_button)

	var tabs := Kit.hbox(6)
	column.add_child(tabs)
	for category in ["", "영웅", "위인", "신화", "근현대"]:
		var tab := Kit.button("전체" if category == "" else category, Kit.PANEL, 20, 50)
		tab.pressed.connect(_on_filter.bind(category))
		tabs.add_child(Kit.expand(tab))
		_tabs[category] = tab

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)

	_rebuild()


func _rebuild() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var owned_count := 0
	for character in app.data["characters"]:
		if Profile.owns(app.profile, str(character["id"])):
			owned_count += 1
	_count_label.text = "영웅 도감 %d / %d" % [owned_count, app.data["characters"].size()]
	_owned_button.text = "보유만 보기"
	_owned_button.icon = Kit.icon("m_check", 30.0).texture if _owned_only else null
	_owned_button.expand_icon = false
	_owned_button.add_theme_constant_override("icon_max_width", 30)
	for category in _tabs:
		# 고른 분류는 노란 알약(tab_on), 나머지는 분류 색 알약.
		var tab: Button = _tabs[category]
		if category == _filter:
			MenuArt.tab(tab, true)
		elif not MenuArt.pill(tab, CATEGORY_PILLS.get(category, "blue")):
			Kit.paint(tab, Kit.CATEGORY_COLORS.get(category, Kit.PANEL_LIGHT), Color.WHITE)
	# 가진 영웅 먼저, 그 안에서는 등급이 높은 순, 같으면 레벨이 높은 순
	var shown: Array = []
	for character in app.data["characters"]:
		var id := str(character["id"])
		var owned := Profile.owns(app.profile, id)
		if _filter != "" and character["category"] != _filter:
			continue
		if _owned_only and not owned:
			continue
		var level := Profile.level_of(app.profile, id) if owned else 0
		shown.append({"character": character, "owned": owned, "key": (100000 if owned else 0) + int(character["grade"]) * 1000 + level * 100 - shown.size()})
	shown.sort_custom(func(a, b): return int(a["key"]) > int(b["key"]))
	for entry in shown:
		_grid.add_child(_card(entry["character"], entry["owned"]))


func _card(character: Dictionary, owned: bool) -> Control:
	var id := str(character["id"])
	var grade := int(character["grade"])
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 220)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var edge: Color = Kit.GRADE_COLORS[grade] if owned else Kit.LINE
	button.add_theme_stylebox_override("normal", Kit.box(Color("0f3d85"), edge, 3, 12, 0))
	button.add_theme_stylebox_override("hover", Kit.box(Color("0f3d85"), Color.WHITE, 3, 12, 0))
	button.add_theme_stylebox_override("pressed", Kit.box(Color("0f3d85"), Color.WHITE, 3, 12, 0))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(_on_hero.bind(id))
	var frame_tex := MenuArt.tex("hero_card")
	var frame: TextureRect = null
	if frame_tex != null:
		# 금테 카드 틀(위 보석 장식). 등급 색 테두리 대신 틀을 덮고, 없는 영웅은 어둡게.
		for state in ["normal", "hover", "pressed"]:
			var fill := Kit.box(Color("0f3d85") if state != "hover" else Color("1a4fa0"), Color.TRANSPARENT, 0, 10, 0)
			# 바탕 칠은 틀 안쪽에만(틀 위 투명한 여백으로 남색이 비치지 않게)
			fill.expand_margin_left = -10
			fill.expand_margin_right = -10
			fill.expand_margin_top = -20
			fill.expand_margin_bottom = -10
			button.add_theme_stylebox_override(state, fill)
		frame = TextureRect.new()
		frame.texture = frame_tex
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.modulate = Color.WHITE if owned else Color(0.6, 0.62, 0.72)
	var column := Kit.vbox(2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if frame != null:
		# 초상화·별 줄은 틀의 안쪽 창(그림에서 잰 자리: 가로 9.2%~89.8%, 세로 14.8%~77.7%)에만 둔다.
		# 틀은 그 위에 덮어 모서리 장식이 그림을 가리게 한다(전에는 그림이 틀 위로 삐져나왔다).
		column.anchor_left = 0.092
		column.anchor_right = 0.898
		column.anchor_top = 0.148
		column.anchor_bottom = 0.777
		column.offset_left = 0
		column.offset_right = 0
		column.offset_top = 0
		column.offset_bottom = 0
		column.add_theme_constant_override("separation", 0)
	else:
		column.offset_left = 4
		column.offset_right = -4
		column.offset_top = 4
		column.offset_bottom = -4
	button.add_child(column)
	var face := Portrait.new()
	face.custom_minimum_size = Vector2(0, 138 if frame_tex == null else 60)
	if frame_tex != null:
		face.size_flags_vertical = Control.SIZE_EXPAND_FILL
	face.border_width = 0.0
	face.show_character(character, Kit.CATEGORY_COLORS.get(character["category"], Kit.LINE))
	face.locked = not owned
	column.add_child(face)
	# 별·레벨 줄(2단계: 18, 흰 글자 + 굵은 외곽선, 어두운 띠 위에 올려 또렷하게)
	var stars := Kit.label("★".repeat(grade), 18, Kit.GRADE_COLORS[grade].lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER)
	stars.add_theme_constant_override("outline_size", 6)
	stars.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.12))
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption: String = "%s\nLv.%d" % [character["name"], Profile.level_of(app.profile, id)] if owned else "%s\n미보유" % character["name"]
	var star_band := PanelContainer.new()
	star_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_band.add_theme_stylebox_override("panel", Kit.box(Color(0.0, 0.03, 0.14, 0.72), Color.TRANSPARENT, 0, 8, 1))
	var star_line := Kit.hbox(6)
	star_line.alignment = BoxContainer.ALIGNMENT_CENTER
	star_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_band.add_child(star_line)
	star_line.add_child(stars)
	if frame_tex != null:
		# 금테 카드: 아래 이름 띠에는 이름만, 레벨은 별 줄에 함께.
		var level := Kit.label(("Lv.%d" % Profile.level_of(app.profile, id)) if owned else "미보유", 18, Color.WHITE if owned else Color("d8dce8"))
		level.add_theme_constant_override("outline_size", 6)
		level.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.12))
		level.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star_line.add_child(level)
		caption = str(character["name"])
	column.add_child(star_band)
	if frame != null:
		button.add_child(frame)
	var text := Kit.label(caption, 18, Color.WHITE if owned else Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	text.clip_text = true
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if frame_tex != null:
		# 금테 카드: 이름은 틀 아래쪽 남색 이름 칸(그림 높이의 78.5%~91%) 안 가운데에 둔다.
		# 세로 상자 맨 아래에 두면 아래 금테에 걸려 글자 아래가 잘려 보였다.
		text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		text.anchor_left = 0.1
		text.anchor_right = 0.9
		text.anchor_top = 0.785
		text.anchor_bottom = 0.91
		text.offset_left = 0
		text.offset_right = 0
		text.offset_top = 0
		text.offset_bottom = 0
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_child(text)
	else:
		column.add_child(text)
	if not owned:
		# 없는 영웅: 어둡게 + 가운데 자물쇠
		var lock: TextureRect = Kit.icon("m_lock", 44.0)
		lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		lock.position = Vector2(0, 0)
		lock.offset_left = -22
		lock.offset_right = 22
		lock.offset_top = 56
		lock.offset_bottom = 100
		button.add_child(lock)
	if owned and Profile.can_upgrade(app.profile, app.eco, id):
		var up := Kit.label("강화!", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		up.mouse_filter = Control.MOUSE_FILTER_IGNORE
		up.add_theme_stylebox_override("normal", Kit.box(Kit.BAD, Color.WHITE, 1, 8, 2))
		up.position = Vector2(6, 6)
		button.add_child(up)
	return button


func _on_hero(id: String) -> void:
	app.play("click")
	app.say(id, "select")
	show_hero(id)


## 영웅 정보 창. 가지고 있으면 강화 버튼이 있다.
func show_hero(id: String) -> void:
	var character: Dictionary = app.character(id)
	var owned := Profile.owns(app.profile, id)
	var ability: Dictionary = app.ability(str(character.get("ability", "")))
	var body := Kit.vbox(10)
	var top := Kit.hbox(14)
	body.add_child(top)
	var face := Portrait.new()
	face.custom_minimum_size = Vector2(280, 280)
	face.hd = true
	face.border = Kit.GRADE_COLORS.get(int(character.get("grade", 1)), Kit.LINE)
	face.border_width = 5.0
	face.show_character(character, Kit.CATEGORY_COLORS.get(character["category"], Kit.LINE))
	face.locked = not owned
	top.add_child(face)
	var info := Kit.vbox(6)
	top.add_child(Kit.expand(info))
	var grade := int(character["grade"])
	info.add_child(Kit.label("★".repeat(grade) + "  " + str(character["category"]), 24, Kit.GRADE_COLORS[grade]))
	info.add_child(Kit.label(str(character["name"]), 34))
	if character.has("title"):
		info.add_child(Kit.label("「%s」" % character["title"], 18, Kit.GOLD))
	for pair in STAT_NAMES:
		var stat_row := Kit.hbox(8)
		stat_row.add_child(Kit.label(pair[1], 20, Kit.MUTED))
		var value := int(character[pair[0]])
		var limit := 2 if pair[0] == "move" else 5
		var bar := Kit.bar(float(value) / float(limit), Kit.CATEGORY_COLORS.get(character["category"], Kit.ACCENT), 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stat_row.add_child(Kit.expand(bar))
		stat_row.add_child(Kit.label(str(value), 20))
		stat_row.add_child(Kit.icon("dice", 24.0))
		info.add_child(stat_row)
	var ability_box := Kit.panel(Color("13458f"), Kit.LINE, 12)
	var ability_text := Kit.label("어빌리티 [%s]%s\n%s" % [ability.get("name", "-"), "  (★★★ 전용)" if str(character.get("ability", "")).begins_with("unique_") else "", ability.get("text", "")], 21)
	ability_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ability_box.add_child(ability_text)
	body.add_child(ability_box)
	if character.has("bio"):
		body.add_child(Kit.para(str(character["bio"]), 18, Kit.MUTED))
	var record: Dictionary = Profile.hero_record(app.profile, id)
	if int(record["played"]) > 0:
		body.add_child(Kit.para("이 영웅 전적: %d판 %d승 (승률 %d%%)" % [int(record["played"]), int(record["wins"]), int(100.0 * int(record["wins"]) / int(record["played"]))], 18))
	var buttons: Array = []
	if owned:
		var level := Profile.level_of(app.profile, id)
		var shards := int(app.profile["owned"][id]["shards"])
		var cost := Profile.upgrade_cost(app.profile, app.eco, id)
		var bonus_table: Array = app.data["rules"].get("level_battle_bonus", [])
		var bonus: int = int(bonus_table[clampi(level - 1, 0, bonus_table.size() - 1)]) if not bonus_table.is_empty() else 0
		body.add_child(Kit.para("레벨 %d / %d   ·   전투 합계 보너스 +%d" % [level, int(app.eco["upgrade"]["max_level"]), bonus], 22, Kit.GOLD))
		if not bonus_table.is_empty() and level < bonus_table.size():
			body.add_child(Kit.para("다음 레벨 보너스 +%d  (전투에서 주사위 합에 더해져요)" % int(bonus_table[level]), 18, Kit.MUTED))
		if cost.is_empty():
			body.add_child(Kit.label("최고 레벨입니다.", 20, Kit.MUTED))
			# 더 쓸 데가 없는 조각은 골드로 판다.
			if shards > 0:
				var price := shards * int(app.eco["upgrade"].get("shard_sell_gold", 0))
				body.add_child(Kit.para("남는 조각 %d개를 %s에 팔 수 있어요." % [shards, Kit.money_text("gold", price)], 20))
				buttons.append(["조각 팔기", Color("27a35a"), _sell_shards.bind(id)])
		else:
			var need := int(cost["shards"])
			body.add_child(Kit.para("조각 %d / %d  ·  강화 비용 %s" % [shards, need, Kit.money_text("gold", int(cost["gold"]))], 20))
			body.add_child(Kit.bar(float(shards) / float(max(need, 1)), Kit.GEM, 16))
			body.add_child(Kit.para("조각은 같은 영웅을 또 소환하면 얻어요.", 18, Kit.MUTED))
			var can := Profile.can_upgrade(app.profile, app.eco, id)
			buttons.append(["강화하기" if can else "강화 불가", Color("f39a1c") if can else Kit.DISABLED, _upgrade.bind(id) if can else Callable()])
		if str(app.profile.get("avatar", "")) != id:
			buttons.append(["대표로", Kit.ACCENT, _set_avatar.bind(id)])
	else:
		body.add_child(Kit.para("아직 없는 영웅이에요. 상점에서 소환하면 얻을 수 있어요.", 20, Kit.MUTED))
		buttons.append(["상점으로", Color("f39a1c"), func(): app.go("shop")])
	buttons.append(["닫기", Kit.PANEL_LIGHT])
	MenuArt.skin_buttons(app.dialog("", body, buttons, 660))


func _sell_shards(id: String) -> void:
	var sold := Profile.sell_shards(app.profile, app.eco, id)
	if sold <= 0:
		return
	app.save()
	app.play("good")
	app.toast("조각 %d개를 팔았어요." % sold)
	app.go("heroes", {"filter": _filter})


## 위쪽 막대에 보이는 대표 영웅을 바꾼다.
func _set_avatar(id: String) -> void:
	app.profile["avatar"] = id
	app.save()
	app.toast("%s(을)를 대표 영웅으로 정했어요." % app.character(id)["name"])
	app.go("heroes", {"filter": _filter})


func _upgrade(id: String) -> void:
	if Profile.upgrade(app.profile, app.eco, id):
		app.save()
		app.play("upgrade")
		app.toast("%s 레벨 %d!" % [app.character(id)["name"], Profile.level_of(app.profile, id)])
		app.go("heroes", {"filter": _filter})
		app.current_screen.show_hero(id)


## 수집 앨범: 분류마다 모은 수와 단계 보상
## 수집 앨범 창(UI 개편 2단계: 너비 780, 본문 18~24, 받기는 금테 알약). 분류 4개를 2×2 카드로.
func _open_album() -> void:
	app.play("click")
	var body := Kit.vbox(10)
	body.add_child(Kit.para("분류마다 영웅을 모으면 보상을 받아요.", 20, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var steps: Array = app.eco["album"]["steps"]
	var rewards: Array = app.eco["album"]["rewards"]
	var characters: Array = app.data["characters"]
	var window: Control = null
	var claims: Array = []
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)
	var attr_icons := {"영웅": "attr_hero", "위인": "attr_great", "신화": "attr_myth", "근현대": "attr_modern"}
	for category in ["영웅", "위인", "신화", "근현대"]:
		var owned := Profile.album_count(app.profile, characters, category)
		var goal := int(steps[steps.size() - 1])
		var color: Color = Kit.CATEGORY_COLORS.get(category, Kit.LINE)
		var card := MenuArt.row(10)
		card.custom_minimum_size = Vector2(344, 0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var column := Kit.vbox(6)
		card.add_child(column)
		var top := Kit.hbox(8)
		column.add_child(top)
		var mark: TextureRect = Kit.icon(str(attr_icons.get(category, "heroes")), 40.0)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(mark)
		top.add_child(Kit.label(category, 24, Color.WHITE))
		var count := Kit.label("%d / %d" % [owned, goal], 22, Kit.GOLD)
		TextStyle.number(count, 5)
		top.add_child(Kit.expand(count))
		var ready: Array = Profile.album_claimable(app.profile, app.eco, characters, category)
		var claim := MenuArt.pill_button("받기" if not ready.is_empty() else "모으는 중", "gold" if not ready.is_empty() else "gray", "s")
		claim.custom_minimum_size = Vector2(112, 44)
		claim.disabled = ready.is_empty()
		claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		claims.append([claim, category])
		top.add_child(claim)
		column.add_child(Kit.bar(float(owned) / float(goal), color, 12))
		var marks := GridContainer.new()
		marks.columns = 2
		marks.add_theme_constant_override("h_separation", 6)
		marks.add_theme_constant_override("v_separation", 4)
		column.add_child(marks)
		for index in steps.size():
			var got := Profile.album_claimed(app.profile, category, index)
			var step := Kit.hbox(4)
			step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var tick: TextureRect = Kit.icon("m_check" if got else "star", 22.0)
			tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if not got and owned < int(steps[index]):
				tick.modulate = Color(0.6, 0.65, 0.8)
			step.add_child(tick)
			step.add_child(Kit.label("%d명 %s" % [int(steps[index]), Kit.reward_line(rewards[index])], 18, Kit.MUTED if got else Kit.GOLD))
			marks.add_child(step)
		grid.add_child(card)
	window = app.dialog("수집 앨범", body, [["닫기", Kit.PANEL_LIGHT]], 780)
	for pair in claims:
		(pair[0] as Button).pressed.connect(_claim_album.bind(str(pair[1]), window.get_instance_id()))


func _claim_album(category: String, window_id: int) -> void:
	var reward := Profile.claim_album(app.profile, app.eco, app.data["characters"], category)
	if reward.is_empty():
		return
	app.save()
	app.play("upgrade")
	var window := instance_from_id(window_id)
	if is_instance_valid(window):
		window.call("close")
	MenuArt.fly_reward(app, null, reward)
	app.go("heroes", {"filter": _filter})
	app.toast("앨범 보상: %s" % Kit.reward_line(reward))


## 강화할 수 있는 영웅을 한꺼번에 올린다(파티원 먼저).
func _upgrade_all() -> void:
	var count := Profile.upgrade_all(app.profile, app.eco)
	if count <= 0:
		app.toast("지금 강화할 수 있는 영웅이 없어요.")
		return
	app.save()
	app.play("upgrade")
	app.go("heroes", {"filter": _filter})
	app.toast("영웅을 %d번 강화했어요!" % count)


func _on_edit_party() -> void:
	app.play("click")
	app.go("party", {"purpose": "edit"})


func _on_filter(category: String) -> void:
	app.play("click")
	_filter = category
	_rebuild()


func _on_owned_toggle() -> void:
	app.play("click")
	_owned_only = not _owned_only
	_rebuild()


## 왼쪽 세로 판: 영웅 목록은 지금 화면, 앨범은 창, 파티 편성은 파티 화면.
func _on_rail(id: String) -> void:
	match id:
		"album":
			_open_album()
		"party":
			_on_edit_party()


func _on_tab(screen_name: String) -> void:
	if screen_name == "heroes":
		return
	app.play("click")
	app.go(screen_name)


## 왼쪽 판 아래 요약 카드: 모은 영웅 수와 출전 파티 작은 초상화 3개.
func _summary_card() -> Control:
	var owned_count := 0
	for character in app.data["characters"]:
		if Profile.owns(app.profile, str(character["id"])):
			owned_count += 1
	var faces := Kit.hbox(4)
	for slot in ["attack", "defense", "support"]:
		var character: Dictionary = app.character(str(app.profile.get("party", {}).get(slot, "")))
		var face := Portrait.new()
		face.custom_minimum_size = Vector2(44, 44)
		face.border_width = 2.0
		face.show_character(character, Kit.CATEGORY_COLORS.get(character.get("category", ""), Kit.LINE))
		faces.add_child(face)
	return MenuArt.summary("heroes", "영웅 %d / %d" % [owned_count, app.data["characters"].size()], "출전 파티", faces)
