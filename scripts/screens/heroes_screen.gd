extends Control
## 영웅 화면: 지금 파티, 파티 편성 버튼, 영웅 도감(48명). 영웅을 누르면 정보와 강화 창이 뜬다.
## 가지지 않은 영웅은 어둡게 보이고, 상점에서 소환하면 얻는다.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const TopBar := preload("res://scripts/ui/top_bar.gd")
const BottomNav := preload("res://scripts/ui/bottom_nav.gd")

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
	var column := Kit.screen_frame(self, 16)
	var top := TopBar.new()
	column.add_child(top)
	top.setup(app)

	var party_row := Kit.hbox(10)
	column.add_child(party_row)
	for slot in ["attack", "defense", "support"]:
		var id := str(app.profile["party"].get(slot, ""))
		var face := Portrait.new()
		face.custom_minimum_size = Vector2(110, 110)
		var info: Dictionary = app.character(id)
		face.show_character(info, Kit.CATEGORY_COLORS.get(info.get("category", ""), Kit.LINE))
		party_row.add_child(face)
	var edit := Kit.button("파티 편성", Color("c4861c"), 28, 110)
	edit.pressed.connect(_on_edit_party)
	party_row.add_child(Kit.expand(edit))

	var header := Kit.hbox(10)
	column.add_child(header)
	_count_label = Kit.label("", 26, Kit.GOLD)
	header.add_child(Kit.expand(_count_label))
	_owned_button = Kit.button("", Kit.PANEL_LIGHT, 20, 56)
	_owned_button.custom_minimum_size = Vector2(190, 56)
	_owned_button.pressed.connect(_on_owned_toggle)
	header.add_child(_owned_button)

	var tabs := Kit.hbox(6)
	column.add_child(tabs)
	for category in ["", "영웅", "위인", "신화", "근현대"]:
		var tab := Kit.button("전체" if category == "" else category, Kit.PANEL, 20, 56)
		tab.pressed.connect(_on_filter.bind(category))
		tabs.add_child(Kit.expand(tab))
		_tabs[category] = tab

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)

	var nav := BottomNav.new()
	column.add_child(nav)
	nav.setup("heroes", app.badges())
	nav.tab_pressed.connect(_on_tab)
	_rebuild()


func _rebuild() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var owned_count := 0
	for character in app.data["characters"]:
		if Profile.owns(app.profile, str(character["id"])):
			owned_count += 1
	_count_label.text = "영웅 도감 %d / %d" % [owned_count, app.data["characters"].size()]
	_owned_button.text = "보유만 보기 ✓" if _owned_only else "보유만 보기"
	for category in _tabs:
		var on: bool = category == _filter
		var color: Color = Kit.CATEGORY_COLORS.get(category, Kit.PANEL_LIGHT)
		Kit.paint(_tabs[category], color if on else color.darkened(0.55), Color.WHITE if on else color.darkened(0.2))
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
	button.add_theme_stylebox_override("normal", Kit.box(Color("0d1026"), edge, 3, 12, 0))
	button.add_theme_stylebox_override("hover", Kit.box(Color("0d1026"), Color.WHITE, 3, 12, 0))
	button.add_theme_stylebox_override("pressed", Kit.box(Color("0d1026"), Color.WHITE, 3, 12, 0))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(_on_hero.bind(id))
	var column := Kit.vbox(2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 4
	column.offset_right = -4
	column.offset_top = 4
	column.offset_bottom = -4
	button.add_child(column)
	var face := Portrait.new()
	face.custom_minimum_size = Vector2(0, 138)
	face.border_width = 0.0
	face.show_character(character, Kit.CATEGORY_COLORS.get(character["category"], Kit.LINE))
	face.locked = not owned
	column.add_child(face)
	var stars := Kit.label("★".repeat(grade), 16, Kit.GRADE_COLORS[grade], HORIZONTAL_ALIGNMENT_CENTER)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stars)
	var caption: String = "%s\nLv.%d" % [character["name"], Profile.level_of(app.profile, id)] if owned else "%s\n미보유" % character["name"]
	var text := Kit.label(caption, 16, Color.WHITE if owned else Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(text)
	if owned and Profile.can_upgrade(app.profile, app.eco, id):
		var up := Kit.label("강화!", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		up.mouse_filter = Control.MOUSE_FILTER_IGNORE
		up.add_theme_stylebox_override("normal", Kit.box(Kit.BAD, Color.WHITE, 1, 8, 2))
		up.position = Vector2(6, 6)
		button.add_child(up)
	return button


func _on_hero(id: String) -> void:
	app.play("click")
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
	face.custom_minimum_size = Vector2(240, 240)
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
		info.add_child(stat_row)
	var ability_box := Kit.panel(Color("14182f"), Kit.LINE, 12)
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
		else:
			var need := int(cost["shards"])
			body.add_child(Kit.para("조각 %d / %d  ·  강화 비용 %s" % [shards, need, Kit.money_text("gold", int(cost["gold"]))], 20))
			body.add_child(Kit.bar(float(shards) / float(max(need, 1)), Kit.GEM, 16))
			body.add_child(Kit.para("조각은 같은 영웅을 또 소환하면 얻어요.", 18, Kit.MUTED))
			var can := Profile.can_upgrade(app.profile, app.eco, id)
			buttons.append(["강화하기" if can else "강화 불가", Color("c4861c") if can else Kit.DISABLED, _upgrade.bind(id) if can else Callable()])
		if str(app.profile.get("avatar", "")) != id:
			buttons.append(["대표로", Kit.ACCENT, _set_avatar.bind(id)])
	else:
		body.add_child(Kit.para("아직 없는 영웅이에요. 상점에서 소환하면 얻을 수 있어요.", 20, Kit.MUTED))
		buttons.append(["상점으로", Color("c4861c"), func(): app.go("shop")])
	buttons.append(["닫기", Kit.PANEL_LIGHT])
	app.dialog("", body, buttons, 660)


## 위쪽 막대에 보이는 대표 영웅을 바꾼다.
func _set_avatar(id: String) -> void:
	app.profile["avatar"] = id
	app.save()
	app.toast("%s(을)를 대표 영웅으로 정했어요." % app.character(id)["name"])
	app.go("heroes", {"filter": _filter})


func _upgrade(id: String) -> void:
	if Profile.upgrade(app.profile, app.eco, id):
		app.save()
		app.play("win")
		app.toast("%s 레벨 %d!" % [app.character(id)["name"], Profile.level_of(app.profile, id)])
		app.go("heroes", {"filter": _filter})
		app.current_screen.show_hero(id)


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


func _on_tab(screen_name: String) -> void:
	if screen_name == "heroes":
		return
	app.play("click")
	app.go(screen_name)
