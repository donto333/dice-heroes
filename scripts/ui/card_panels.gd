extends Node
## 카드 덱·카드 뽑기 판(2026-11-18). 화면에 붙여 쓰는 도우미:
## 영웅 화면의 '카드 목록'(build_list)·'카드 편성'(build_deck)과 상점의 '카드 뽑기'(build_gacha)가 함께 쓴다.
## 카드는 등급(★ 일반 · ★★ 희귀 · ★★★ 전설)이 있고, 판에서는 덱에 넣은 카드만 뽑힌다.
## 규칙은 scripts/rules/profile.gd(draw_cards·toggle_deck·deck_error), 수치는 economy.json의 card_gacha·card_deck.
## 쓰는 법: var panels := CardPanels.new(); add_child(panels); panels.init(app, "heroes", {"view": "cards"})
## 덱을 고치거나 뽑기가 끝나면 back_screen(back_params)으로 다시 그린다.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const OddsWindow := preload("res://scripts/ui/odds_window.gd")
const AdPlayer := preload("res://scripts/ui/ad_player.gd")
const ArtView := preload("res://scripts/ui/art_view.gd")
const SummonShow := preload("res://scripts/ui/summon_show.gd")
const UiSkin := preload("res://scripts/ui/skin.gd")

const GRADE_NAMES := {1: "일반", 2: "희귀", 3: "전설"}
## 등급별 카드 바탕색
const GRADE_FILLS := {1: Color("2a4a7a"), 2: Color("1f5f8f"), 3: Color("6a3fa8")}
## 카드 편성 칸 크기: 덱 줄의 카드, 보유 카드 칸 높이
const DECK_TILE := Vector2(96, 76)
const OWNED_TILE_HEIGHT := 146.0
## 원본 줄 높이 150px에서 잰 양 끝 장식 폭과 위·아래 테두리 두께의 비율.
const DECK_ROW_CAPS := {1: 44.0 / 150.0, 2: 80.0 / 150.0, 3: 92.0 / 150.0}
const DECK_ROW_EDGES := {1: 13.0 / 150.0, 2: 20.0 / 150.0, 3: 25.0 / 150.0}
## 뽑기 판에 보여 줄 전설 카드
const SHOWCASE := ["war_god", "silence_bell", "spirit_drain", "iron_will"]

var app
var back_screen := "heroes"
var back_params: Dictionary = {}
var _free_pull := false
var _filter := 0


func init(main_app, screen_name: String, params: Dictionary) -> void:
	app = main_app
	back_screen = screen_name
	back_params = params.duplicate()
	_filter = int(params.get("grade", 0))


## 카드 수·무료 뽑기 요약(왼쪽 판 아래 요약 카드용)
func summary_text() -> Array:
	var owned: int = (app.profile.get("cards", []) as Array).size()
	return ["카드 %d / %d" % [owned, _cards().size()], "무료 뽑기 %d회" % Profile.free_card_draws_left(app.profile, app.eco)]


func _cards() -> Dictionary:
	return app.data.get("cards", {})


# ---------------------------------------------------------------- 덱

## 카드 목록(영웅 메뉴 '카드 목록'): 58종 전부, 가진 카드는 또렷하게, 없는 카드는 자물쇠. 덱에 든 카드는 '덱' 표시.
func build_list(column: VBoxContainer) -> void:
	var cards := _cards()
	var deck: Array = Profile.battle_deck(app.profile, cards, app.eco)
	var owned: int = (app.profile.get("cards", []) as Array).size()
	var head := Kit.hbox(10)
	column.add_child(head)
	head.add_child(Kit.label("카드 목록 %d / %d" % [owned, cards.size()], 28, Kit.GOLD))
	var hint := Kit.para("카드는 상점의 '카드 뽑기'에서 모아요. 덱은 '카드 편성'에서 짜요.", 15, Kit.MUTED)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(Kit.expand(hint))
	column.add_child(_filter_tabs())
	var grid := _scroll_grid(column)
	var ids: Array = cards.keys()
	ids.sort_custom(func(a, b) -> bool:
		var oa := Profile.owns_card(app.profile, str(a))
		var ob := Profile.owns_card(app.profile, str(b))
		if oa != ob:
			return oa
		return Profile.card_grade(cards, str(a)) > Profile.card_grade(cards, str(b)))
	for id in ids:
		if _filter != 0 and Profile.card_grade(cards, str(id)) != _filter:
			continue
		var tile := card_tile(cards, str(id), Profile.owns_card(app.profile, str(id)), deck.has(id), 220.0)
		tile.pressed.connect(_on_list_card.bind(str(id)))
		grid.add_child(tile)


## 카드 편성(2026-11-18 사용자 결정 배치): 위 제목 줄, 왼쪽은 등급별 덱 줄 세 개(전설 3 · 희귀 5 · 일반 7, 줄마다 옆으로 스크롤),
## 오른쪽은 '보유 카드'(2칸 세로 스크롤, 등급 거름). 덱에 없는 카드는 정보를 보고 적용하며, 덱에 든 카드는 바로 뺀다.
func build_deck(column: VBoxContainer) -> void:
	var cards := _cards()
	var rule: Dictionary = app.eco.get("card_deck", {})
	var per_grade: Dictionary = rule.get("per_grade", {})
	# 덱이 망가져 있으면(예전 저장) 처음 덱으로 맞춘다.
	var deck: Array = Profile.battle_deck(app.profile, cards, app.eco)

	var head := Kit.hbox(10)
	column.add_child(head)
	head.add_child(Kit.label("카드 편성 %d / %d" % [deck.size(), int(rule.get("size", 15))], 28, Kit.GOLD))
	var hint := Kit.para("보유 카드는 정보를 확인하고 넣어요. 덱에 든 카드를 누르면 빼요.", 15, Kit.MUTED)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(Kit.expand(hint))
	head.add_child(MenuArt.capsule("최소 %d장" % int(rule.get("min", 6)), "", 18))

	var body := Kit.hbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	# 왼쪽: 등급별 덱 줄
	var left := Kit.vbox(4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.75
	body.add_child(left)
	for grade in [3, 2, 1]:
		var mine: Array = []
		for id in deck:
			if Profile.card_grade(cards, str(id)) == grade:
				mine.append(str(id))
		var limit := int(per_grade.get(str(grade), 0))
		left.add_child(Kit.label("%s %d / %d" % [str(GRADE_NAMES[grade]), mine.size(), limit], 20, Kit.GRADE_COLORS[grade]))
		var row := _deck_row(left, grade)
		for index in limit:
			if index < mine.size():
				var tile := card_tile(cards, mine[index], true, false, DECK_TILE.y, false)
				tile.custom_minimum_size = DECK_TILE
				tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				tile.pressed.connect(_on_card.bind(mine[index]))
				row.add_child(tile)
			else:
				row.add_child(_empty_slot(grade))

	# 오른쪽: 보유 카드
	var right := Kit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var owned_ids: Array = []
	for id in cards:
		if Profile.owns_card(app.profile, str(id)):
			owned_ids.append(id)
	right.add_child(Kit.label("보유 카드 %d / %d" % [owned_ids.size(), cards.size()], 20, Kit.GOLD))
	var filters := Kit.hbox(4)
	right.add_child(filters)
	for spec in [[0, "전체"], [3, "★★★"], [2, "★★"], [1, "★"]]:
		var tab := Kit.button(str(spec[1]), Kit.PANEL, 15, 36)
		MenuArt.tab(tab, int(spec[0]) == _filter)
		tab.pressed.connect(_on_filter.bind(int(spec[0])))
		filters.add_child(Kit.expand(tab))
	var owned_frame := PanelContainer.new()
	owned_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 모서리 장식 아래와 금테 안쪽에 카드 두 줄과 스크롤 막대를 둔다.
	var owned_art := MenuArt.style("deck_owned_frame", Vector4(80, 78, 80, 78), Vector4(30, 54, 30, 54))
	owned_frame.add_theme_stylebox_override("panel", owned_art if owned_art != null else Kit.box(Color(0, 0, 0, 0.22), Kit.GOLD.darkened(0.4), 2, 12, 6))
	right.add_child(owned_frame)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	scroll.add_theme_constant_override("scrollbar_h_separation", 8)
	owned_frame.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	# 덱에 없는 카드부터, 높은 등급부터
	owned_ids.sort_custom(func(a, b) -> bool:
		var da := deck.has(a)
		var db := deck.has(b)
		if da != db:
			return db
		return Profile.card_grade(cards, str(a)) > Profile.card_grade(cards, str(b)))
	for id in owned_ids:
		if _filter != 0 and Profile.card_grade(cards, str(id)) != _filter:
			continue
		var tile := card_tile(cards, str(id), true, deck.has(id), OWNED_TILE_HEIGHT, false)
		tile.pressed.connect(_on_card.bind(str(id)))
		grid.add_child(tile)


func _deck_row(parent: VBoxContainer, grade: int) -> HBoxContainer:
	var frame := PanelContainer.new()
	parent.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	const SCROLL_GAP := 4
	scroll.add_theme_constant_override("scrollbar_v_separation", SCROLL_GAP)
	frame.add_child(scroll)
	var scroll_space := scroll.get_h_scroll_bar().get_minimum_size().y + SCROLL_GAP
	scroll.custom_minimum_size.y = DECK_TILE.y + scroll_space
	var art := MenuArt.tex("deck_row_frame_%d" % grade)
	if art != null:
		# 양 끝은 줄 높이에 맞춰 그린다. 카드 영역도 같은 비율로 장식 안쪽에서 시작한다.
		# 위에도 스크롤 막대 자리만큼 여백을 주어 카드 자체를 가운데에 놓는다.
		var edge_ratio: float = DECK_ROW_EDGES[grade]
		var edge := ceilf((DECK_TILE.y + 2.0 * scroll_space) * edge_ratio / (1.0 - 2.0 * edge_ratio))
		var row_height := DECK_TILE.y + 2.0 * (edge + scroll_space)
		var cap: float = DECK_ROW_CAPS[grade]
		var side := ceilf(row_height * cap) + 4.0
		var inset := StyleBoxEmpty.new()
		inset.set_content_margin(SIDE_LEFT, side)
		inset.set_content_margin(SIDE_RIGHT, side)
		inset.set_content_margin(SIDE_TOP, edge + scroll_space)
		inset.set_content_margin(SIDE_BOTTOM, edge)
		frame.add_theme_stylebox_override("panel", inset)
		frame.draw.connect(func() -> void:
			UiSkin.draw_bar(frame.get_canvas_item(), art, Rect2(Vector2.ZERO, frame.size), cap))
		frame.resized.connect(frame.queue_redraw)
	else:
		frame.add_theme_stylebox_override("panel", Kit.box(Color(0, 0, 0, 0.22), Kit.GRADE_COLORS[grade].darkened(0.35), 2, 12, 6))
	var row := Kit.hbox(6)
	scroll.add_child(row)
	return row


## 비어 있는 덱 자리(등급색 점선 느낌의 흐린 칸)
func _empty_slot(grade: int) -> Control:
	# 빈 카드 자리 그림(assets/ui_menu/deck_slot_empty_N.png)이 있으면 그것만 보여 준다.
	var art := MenuArt.tex("deck_slot_empty_%d" % grade)
	if art != null:
		var picture := TextureRect.new()
		picture.texture = art
		picture.custom_minimum_size = DECK_TILE
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		return picture
	var slot := PanelContainer.new()
	slot.custom_minimum_size = DECK_TILE
	slot.add_theme_stylebox_override("panel", Kit.box(Color(1, 1, 1, 0.05), Kit.GRADE_COLORS[grade].darkened(0.3), 2, 12, 4))
	var inside := Kit.vbox(2)
	inside.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(inside)
	inside.add_child(Kit.label("★".repeat(grade), 16, Kit.GRADE_COLORS[grade].darkened(0.2), HORIZONTAL_ALIGNMENT_CENTER))
	inside.add_child(Kit.label("빈칸", 16, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	return slot


func _filter_tabs() -> Control:
	var filters := Kit.hbox(6)
	for spec in [[0, "전체"], [3, "★★★ 전설"], [2, "★★ 희귀"], [1, "★ 일반"]]:
		var tab := Kit.button(str(spec[1]), Kit.PANEL, 17, 40)
		MenuArt.tab(tab, int(spec[0]) == _filter)
		tab.pressed.connect(_on_filter.bind(int(spec[0])))
		filters.add_child(Kit.expand(tab))
	return filters


func _scroll_grid(column: VBoxContainer) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	return grid


## 카드 한 장(2026-11-18 사용자 결정 A안 '그림 가득'): 그림이 칸을 가득 채우고, 왼쪽 위에 별 딱지,
## 아래에 어두운 반투명 띠 위 이름. 테두리는 등급색(덱에 든 카드는 초록). show_text면 그림 아래에 설명.
static func card_tile(cards: Dictionary, id: String, owned: bool, in_deck: bool, height: float = 236.0, show_text: bool = true) -> Button:
	var card: Dictionary = cards.get(id, {})
	var grade := Profile.card_grade(cards, id)
	var tile := Button.new()
	tile.flat = true
	tile.focus_mode = Control.FOCUS_NONE
	tile.custom_minimum_size = Vector2(0, height)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := PanelContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border: Color = Color("5fe08a") if in_deck else Kit.GRADE_COLORS[grade]
	body.add_theme_stylebox_override("panel", Kit.box(GRADE_FILLS[grade], border, 4 if in_deck else 3, 12, 3))
	tile.add_child(body)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(column)
	var small := height < 150.0
	# 그림 칸: 설명이 없으면 칸 전체, 있으면 위쪽 62%
	var art_box := Control.new()
	art_box.clip_contents = true
	art_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_box.custom_minimum_size = Vector2(0, height * 0.62 if show_text else 0.0)
	art_box.size_flags_vertical = Control.SIZE_FILL if show_text else Control.SIZE_EXPAND_FILL
	column.add_child(art_box)
	var picture := ArtView.new()
	picture.show_art("cards/" + id)
	picture.focus_y = 0.45
	picture.corner_radius = 9.0
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if picture.has_art():
		art_box.add_child(picture)
	else:
		# 그림이 아직 없는 카드: 등급색 판 위에 카드 아이콘
		picture.free()
		var plain := PanelContainer.new()
		plain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		plain.add_theme_stylebox_override("panel", Kit.box(Kit.GRADE_COLORS[grade].darkened(0.5), Color.TRANSPARENT, 0, 9, 4))
		plain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(Kit.icon("card", height * 0.28))
		plain.add_child(center)
		art_box.add_child(plain)
	# 아래 이름 띠: 어두운 반투명 띠 위 흰 글자
	var name_size := 16 if small else 20
	var banner := PanelContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banner_style := Kit.box(Color(0.02, 0.03, 0.12, 0.74), Color.TRANSPARENT, 0, 0, 2)
	banner_style.corner_radius_bottom_left = 9
	banner_style.corner_radius_bottom_right = 9
	banner.add_theme_stylebox_override("panel", banner_style)
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.anchor_top = 1.0
	banner.anchor_bottom = 1.0
	banner.offset_top = -(name_size + 12)
	art_box.add_child(banner)
	var name_label := Kit.label(str(card.get("name", id)), name_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.clip_text = true
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(name_label)
	# 왼쪽 위 별 딱지
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", Kit.box(Color(0.02, 0.03, 0.12, 0.78), Kit.GRADE_COLORS[grade].darkened(0.1), 1, 9, 2))
	badge.position = Vector2(4, 4)
	var stars := Kit.label("★".repeat(grade), 12 if small else 15, Kit.GRADE_COLORS[grade], HORIZONTAL_ALIGNMENT_CENTER)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(stars)
	art_box.add_child(badge)
	var text := Kit.para(str(card.get("text", "")), 14, Color(0.9, 0.93, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.visible = show_text
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(text)
	# 칸이 좁으면 이름을 칸 너비에 맞춰 줄인다(잘려 보이지 않게).
	Kit.squeeze_text(name_label, name_size, 9)
	if in_deck:
		# 덱 표시는 오른쪽 위(왼쪽 위는 별 딱지)
		var mark := Kit.label("덱", 13 if small else 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		var deck_badge := PanelContainer.new()
		deck_badge.add_theme_stylebox_override("panel", Kit.box(Color("2fa85a"), Color.WHITE, 2, 10, 2))
		deck_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deck_badge.add_child(mark)
		deck_badge.custom_minimum_size = Vector2(36 if small else 44, 22 if small else 26)
		deck_badge.anchor_left = 1.0
		deck_badge.anchor_right = 1.0
		deck_badge.offset_left = -(42 if small else 50)
		deck_badge.offset_right = -6
		deck_badge.offset_top = 6
		tile.add_child(deck_badge)
	if not owned:
		body.modulate = Color(0.45, 0.45, 0.5, 1.0)
		# 자물쇠는 그림 자리 한가운데
		var lock_holder := CenterContainer.new()
		lock_holder.anchor_right = 1.0
		lock_holder.offset_top = 6.0
		lock_holder.offset_bottom = 6.0 + height * (0.6 if show_text else 0.8)
		lock_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_holder.add_child(Kit.icon("m_lock", 44.0))
		tile.add_child(lock_holder)
	return tile


func _on_card(id: String) -> void:
	if not Profile.owns_card(app.profile, id):
		app.play("denied")
		app.toast("아직 없는 카드예요. 카드 뽑기에서 얻을 수 있어요.")
		return
	var was_in: bool = (app.profile.get("deck", []) as Array).has(id)
	if was_in:
		_toggle_card(id, true)
		return

	var cards := _cards()
	var card: Dictionary = cards[id]
	var body := Kit.vbox(12)
	var row := Kit.hbox(16)
	body.add_child(row)
	var picture := card_tile(cards, id, true, false, 252.0, false)
	picture.custom_minimum_size.x = 188
	picture.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)

	var info := Kit.vbox(10)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(Kit.expand(info))
	var grade := Profile.card_grade(cards, id)
	info.add_child(Kit.label("★".repeat(grade), 24, Kit.GRADE_COLORS[grade]))
	info.add_child(Kit.para(str(card.get("text", "")), 22, Color.WHITE))
	body.add_child(Kit.para("이 카드로 적용할까요?", 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	app.dialog(str(card["name"]), body, [["적용", Kit.ACCENT, _toggle_card.bind(id, false)], ["취소", Kit.PANEL_LIGHT]], 660)


func _toggle_card(id: String, was_in: bool) -> void:
	# 창을 연 뒤 덱이 바뀌었으면, 적용이 카드 빼기로 뒤집히지 않게 한다.
	var deck: Array = app.profile.get("deck", [])
	if deck.has(id) != was_in:
		return
	var problem := Profile.toggle_deck(app.profile, _cards(), app.eco, id)
	if problem != "":
		app.play("denied")
		app.toast(problem)
		return
	app.save()
	app.play("click" if was_in else "good")
	_back({"grade": _filter})


## 카드 목록에서 누르면: 없는 카드는 얻는 곳 안내, 가진 카드는 편성 안내.
func _on_list_card(id: String) -> void:
	if not Profile.owns_card(app.profile, id):
		app.play("denied")
		app.toast("아직 없는 카드예요. 상점의 '카드 뽑기'에서 얻을 수 있어요.")
		return
	app.play("click")
	app.toast("[%s] %s" % [str(_cards()[id]["name"]), str(_cards()[id].get("text", ""))])


func _on_filter(grade: int) -> void:
	if grade == _filter:
		return
	app.play("tab")
	_back({"grade": grade})


## 원래 화면을 다시 그린다(덱을 고친 뒤·뽑기가 끝난 뒤).
func _back(extra: Dictionary = {}) -> void:
	var params := back_params.duplicate()
	params.merge(extra, true)
	app.go(back_screen, params)


# ---------------------------------------------------------------- 뽑기

## body: 이미 스크롤 안에 있는 세로 줄(상점 소환 탭). 보석 뽑기 판 + 골드 뽑기 줄 + 안내 글을 붙인다.
func build_gacha(body: VBoxContainer) -> void:
	var table: Dictionary = app.eco.get("card_gacha", {})
	var cards := _cards()
	var panel := Kit.panel(Color("4a2a9a"), Kit.GOLD, 16)
	body.add_child(panel)
	var inner := Kit.vbox(12)
	panel.add_child(inner)
	inner.add_child(Kit.title("카드 뽑기", 40))
	var faces := Kit.hbox(8)
	inner.add_child(faces)
	for id in SHOWCASE:
		if cards.has(id):
			var tile := card_tile(cards, id, true, false, 220.0)
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			faces.add_child(tile)
	var rates: Dictionary = table.get("rates", {})
	var pity_left: int = maxi(int(table.get("pity_3", 0)) - int(app.profile.get("card_pity", 0)), 1)
	var caps := Kit.hbox(8)
	caps.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(caps)
	caps.add_child(MenuArt.capsule("★★★ %d%%  ·  ★★ %d%%  ·  ★ %d%%" % [int(rates.get("3", 0)), int(rates.get("2", 0)), int(rates.get("1", 0))], "", 18))
	caps.add_child(MenuArt.capsule("10회는 ★★ 이상 보장 · ★★★ 확정까지 %d회" % pity_left, "", 18))
	caps.add_child(OddsWindow.button(app, "card"))
	var dupe: Dictionary = table.get("dupe_gold", {})
	inner.add_child(Kit.para("이미 가진 카드가 나오면 골드로 바뀌어요. (★ %s · ★★ %s · ★★★ %s)" % [Kit.money_text("gold", int(dupe.get("1", 0))), Kit.money_text("gold", int(dupe.get("2", 0))), Kit.money_text("gold", int(dupe.get("3", 0)))], 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var buttons := Kit.hbox(10)
	inner.add_child(buttons)
	var free_left := Profile.free_card_draws_left(app.profile, app.eco)
	var free_button := MenuArt.pill_button("무료 뽑기 (오늘 %d회)" % free_left, "green", "l")
	free_button.disabled = free_left <= 0
	free_button.pressed.connect(_on_free_draw)
	buttons.add_child(Kit.expand(free_button))
	var one := MenuArt.pill_button("1회  %s" % Kit.money_text("gems", int(table.get("cost_one", 30))), "blue", "l")
	one.disabled = not Profile.can_pay(app.profile, "gems", int(table.get("cost_one", 30)))
	one.pressed.connect(_on_paid_draw.bind(1))
	buttons.add_child(Kit.expand(one))
	var ten := MenuArt.pill_button("10회  %s" % Kit.money_text("gems", int(table.get("cost_ten", 270))), "gold", "l")
	ten.disabled = not Profile.can_pay(app.profile, "gems", int(table.get("cost_ten", 270)))
	ten.pressed.connect(_on_paid_draw.bind(10))
	buttons.add_child(Kit.expand(ten))
	Kit.shimmer(ten)
	# 보상형 광고: 무료 뽑기 한 번 더(2026-11-19)
	var ad_left := Profile.ads_left(app.profile, app.eco, "card_draw")
	var ad_button := MenuArt.pill_button("광고 보고 무료 뽑기 (오늘 %d회)" % ad_left, "purple", "m")
	ad_button.disabled = ad_left <= 0
	ad_button.pressed.connect(_on_ad_draw)
	inner.add_child(ad_button)
	body.add_child(_gold_panel())
	body.add_child(Kit.para("뽑은 카드는 영웅 메뉴의 '카드 편성'에서 넣어야 판에 나와요.", 17, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))


## 골드 카드 뽑기(2026-11-18 사용자 요청): ★·★★ 카드만 나온다. ★★★ 보장 횟수는 세지 않는다.
func _gold_panel() -> Control:
	var table: Dictionary = app.eco.get("card_gacha", {}).get("gold", {})
	var rates: Dictionary = table.get("rates", {})
	var group := Kit.vbox(8)
	group.add_child(MenuArt.section("골드 뽑기", "gold", "★★ %d%% · ★ %d%%  (★★★ 없음)" % [int(rates.get("2", 0)), int(rates.get("1", 0))]))
	var line := MenuArt.row(12)
	group.add_child(line)
	var inside := Kit.hbox(10)
	line.add_child(inside)
	var words := Kit.vbox(2)
	words.add_child(Kit.label("★·★★ 카드 뽑기", 24, Color.WHITE))
	words.add_child(Kit.para("골드로 뽑아요. 10회는 ★★ 이상 1장 보장.", 17, Kit.MUTED))
	inside.add_child(Kit.expand(words))
	inside.add_child(OddsWindow.button(app, "card_gold"))
	for count in [1, 10]:
		var cost := int(table.get("cost_ten" if count >= 10 else "cost_one", 500))
		var button := MenuArt.pill_button("%d회  %s" % [count, Kit.money_text("gold", cost)], "green" if count == 1 else "gold", "m")
		button.custom_minimum_size = Vector2(200, 60)
		button.disabled = not Profile.can_pay(app.profile, "gold", cost)
		button.pressed.connect(_on_gold_draw.bind(count))
		inside.add_child(button)
	return group


func _on_gold_draw(count: int) -> void:
	var table: Dictionary = app.eco.get("card_gacha", {}).get("gold", {})
	var cost := int(table.get("cost_ten" if count >= 10 else "cost_one", 500))
	if not Profile.pay(app.profile, "gold", cost):
		app.play("denied")
		app.toast("골드가 모자라요.")
		return
	_pull(count, true)


func _on_free_draw() -> void:
	if not Profile.use_free_card_draw(app.profile, app.eco):
		return
	_free_pull = true
	_pull(1)


func _on_ad_draw() -> void:
	if Profile.ads_left(app.profile, app.eco, "card_draw") <= 0:
		return
	app.play("click")
	var ad := AdPlayer.new()
	app.add_child(ad)
	if not await ad.play(app):
		return
	if Profile.ads_left(app.profile, app.eco, "card_draw") <= 0:
		return
	Profile.watch_ad(app.profile, app.eco, "card_draw")
	_free_pull = true
	_pull(1)


func _on_paid_draw(count: int) -> void:
	var table: Dictionary = app.eco.get("card_gacha", {})
	var cost := int(table.get("cost_ten" if count >= 10 else "cost_one", 30))
	if not Profile.pay(app.profile, "gems", cost):
		app.play("denied")
		app.toast("보석이 모자라요.")
		return
	_pull(count)


## 결과는 뽑는 순간 정해져 저장된다. 소환과 같은 연출(제단 → 운명의 주사위 → 카드 뒤집기, ★★★는 전설 카드 등장 컷)로 보여 준다.
## 연출이 끝나면 화면을 새로 그리므로(app.go) 그 뒤에는 self를 쓰지 않는다.
func _pull(count: int, gold: bool = false) -> void:
	var results := Profile.draw_cards(app.profile, _cards(), app.eco, count, app.rng, gold)
	app.save()
	var table: Dictionary = app.eco.get("card_gacha", {})
	if gold:
		table = table.get("gold", {})
	var key := "cost_ten" if count >= 10 else "cost_one"
	var again_cost := int(table.get(key, 0))
	var currency := "gold" if gold else "gems"
	# 무료 뽑기 뒤나, 한 번 더 할 돈이 없으면 '한 번 더' 버튼을 감춘다.
	if _free_pull or not Profile.can_pay(app.profile, currency, again_cost):
		again_cost = 0
	_free_pull = false
	var host = app
	var screen_name := back_screen
	var params := back_params.duplicate()
	var show := SummonShow.new()
	show.kind = "card"
	show.again_currency = currency
	host.add_child(show)
	var again: bool = await show.play(host, results, again_cost)
	host.go(screen_name, params)
	if again:
		var panels = find_in(host.current_screen)
		if panels != null:
			if gold:
				panels._on_gold_draw(count)
			else:
				panels._on_paid_draw(count)


## 화면 안에 붙어 있는 카드 도우미(CardPanels)를 찾는다.
static func find_in(node: Node) -> Node:
	for child in node.get_children():
		if child.has_method("build_gacha"):
			return child
		var deeper = find_in(child)
		if deeper != null:
			return deeper
	return null
