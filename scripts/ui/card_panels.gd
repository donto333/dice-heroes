extends Node
## 카드 덱·카드 뽑기 판(2026-11-18). 화면에 붙여 쓰는 도우미:
## 영웅 화면의 '카드 덱'(build_deck)과 상점 영웅 소환 탭 아래의 '카드 뽑기'(build_gacha)가 함께 쓴다.
## 카드는 등급(★ 일반 · ★★ 희귀 · ★★★ 전설)이 있고, 판에서는 덱에 넣은 카드만 뽑힌다.
## 규칙은 scripts/rules/profile.gd(draw_cards·toggle_deck·deck_error), 수치는 economy.json의 card_gacha·card_deck.
## 쓰는 법: var panels := CardPanels.new(); add_child(panels); panels.init(app, "heroes", {"view": "cards"})
## 덱을 고치거나 뽑기가 끝나면 back_screen(back_params)으로 다시 그린다.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const ArtView := preload("res://scripts/ui/art_view.gd")

const GRADE_NAMES := {1: "일반", 2: "희귀", 3: "전설"}
## 등급별 카드 바탕색
const GRADE_FILLS := {1: Color("2a4a7a"), 2: Color("1f5f8f"), 3: Color("6a3fa8")}
## 뽑기 판에 보여 줄 전설 카드
const SHOWCASE := ["war_god", "silence_bell", "spirit_drain", "iron_will"]

var app
var back_screen := "heroes"
var back_params: Dictionary = {}
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

func build_deck(column: VBoxContainer) -> void:
	var cards := _cards()
	var rule: Dictionary = app.eco.get("card_deck", {})
	# 덱이 망가져 있으면(예전 저장) 처음 덱으로 맞춘다.
	var deck: Array = Profile.battle_deck(app.profile, cards, app.eco)
	var legends := 0
	for id in deck:
		if Profile.card_grade(cards, str(id)) >= 3:
			legends += 1

	var head := Kit.hbox(10)
	column.add_child(head)
	head.add_child(Kit.label("내 덱 %d / %d" % [deck.size(), int(rule.get("size", 10))], 28, Kit.GOLD))
	var hint := Kit.para("카드를 누르면 덱에 넣거나 빼요. 판에서는 덱에 넣은 카드만 나와요.", 15, Kit.MUTED)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(Kit.expand(hint))
	head.add_child(MenuArt.capsule("★★★ %d / %d장" % [legends, int(rule.get("max_grade3", 2))], "", 18))
	head.add_child(MenuArt.capsule("최소 %d장" % int(rule.get("min", 6)), "", 18))

	# 덱에 든 카드: 작은 이름표 10칸(빈칸은 흐리게)
	var strip := GridContainer.new()
	strip.columns = 5
	strip.add_theme_constant_override("h_separation", 6)
	strip.add_theme_constant_override("v_separation", 6)
	column.add_child(strip)
	for index in int(rule.get("size", 10)):
		strip.add_child(_deck_chip(str(deck[index]) if index < deck.size() else ""))

	var filters := Kit.hbox(6)
	column.add_child(filters)
	for spec in [[0, "전체"], [3, "★★★ 전설"], [2, "★★ 희귀"], [1, "★ 일반"]]:
		var tab := Kit.button(str(spec[1]), Kit.PANEL, 17, 40)
		MenuArt.tab(tab, int(spec[0]) == _filter)
		tab.pressed.connect(_on_filter.bind(int(spec[0])))
		filters.add_child(Kit.expand(tab))

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
	# 높은 등급부터, 가진 카드부터
	var ids: Array = cards.keys()
	var rank := func(id) -> int:
		if deck.has(id):
			return 0
		return 1 if Profile.owns_card(app.profile, str(id)) else 2
	ids.sort_custom(func(a, b) -> bool:
		var ra: int = rank.call(a)
		var rb: int = rank.call(b)
		if ra != rb:
			return ra < rb
		return Profile.card_grade(cards, str(a)) > Profile.card_grade(cards, str(b)))
	for id in ids:
		if _filter != 0 and Profile.card_grade(cards, str(id)) != _filter:
			continue
		var tile := card_tile(cards, str(id), Profile.owns_card(app.profile, str(id)), deck.has(id), 210.0)
		tile.pressed.connect(_on_card.bind(str(id)))
		grid.add_child(tile)


func _deck_chip(id: String) -> Control:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(0, 32)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if id == "":
		chip.add_theme_stylebox_override("panel", Kit.box(Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.15), 2, 10, 4))
		chip.add_child(Kit.label("빈칸", 16, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		return chip
	var cards := _cards()
	var grade := Profile.card_grade(cards, id)
	chip.add_theme_stylebox_override("panel", Kit.box(GRADE_FILLS[grade], Kit.GRADE_COLORS[grade], 2, 10, 4))
	var text := Kit.label("%s %s" % ["★".repeat(grade), str(cards[id]["name"])], 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	text.clip_text = true
	chip.add_child(text)
	return chip


## 카드 한 장 모양(카드 덱 화면과 뽑기 결과가 함께 씀): 그림(없으면 등급색 바탕), 등급 별, 이름, 효과.
## owned가 false면 어둡게, in_deck이면 초록 띠 '덱'.
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
	body.add_theme_stylebox_override("panel", Kit.box(GRADE_FILLS[grade], border, 4 if in_deck else 3, 14, 6))
	tile.add_child(body)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(column)
	var picture := ArtView.new()
	picture.show_art("cards/" + id)
	picture.custom_minimum_size = Vector2(0, height * (0.42 if show_text else 0.6))
	picture.focus_y = 0.5
	picture.corner_radius = 8.0
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not picture.has_art():
		# 그림이 아직 없는 카드: 등급색 판 위에 카드 아이콘
		picture.free()
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(0, height * (0.42 if show_text else 0.6))
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var back := PanelContainer.new()
		back.add_theme_stylebox_override("panel", Kit.box(Kit.GRADE_COLORS[grade].darkened(0.45), Kit.GRADE_COLORS[grade], 2, 8, 6))
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.add_child(Kit.icon("card", height * 0.3))
		holder.add_child(back)
		column.add_child(holder)
	else:
		column.add_child(picture)
	var stars := Kit.label("★".repeat(grade) + "  " + str(GRADE_NAMES[grade]), 15, Kit.GRADE_COLORS[grade], HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(stars)
	var name_label := Kit.label(str(card.get("name", id)), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.clip_text = true
	column.add_child(name_label)
	var text := Kit.para(str(card.get("text", "")), 14, Color(0.9, 0.93, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.visible = show_text
	column.add_child(text)
	for child in [stars, name_label, text]:
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if in_deck:
		var mark := Kit.label("덱", 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", Kit.box(Color("2fa85a"), Color.WHITE, 2, 10, 2))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(mark)
		badge.custom_minimum_size = Vector2(44, 26)
		badge.position = Vector2(6, 6)
		tile.add_child(badge)
	if not owned:
		body.modulate = Color(0.45, 0.45, 0.5, 1.0)
		# 자물쇠는 그림 자리 한가운데(글자를 가리지 않게)
		var lock_holder := CenterContainer.new()
		lock_holder.anchor_right = 1.0
		lock_holder.offset_top = 6.0
		lock_holder.offset_bottom = 6.0 + height * 0.42
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
	var problem := Profile.toggle_deck(app.profile, _cards(), app.eco, id)
	if problem != "":
		app.play("denied")
		app.toast(problem)
		return
	app.save()
	app.play("click" if was_in else "good")
	_back({"grade": _filter})


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
	body.add_child(_gold_panel())
	body.add_child(Kit.para("뽑은 카드는 영웅 메뉴의 '카드 덱'에서 덱에 넣어야 판에 나와요.", 17, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))


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
	_pull(1)


func _on_paid_draw(count: int) -> void:
	var table: Dictionary = app.eco.get("card_gacha", {})
	var cost := int(table.get("cost_ten" if count >= 10 else "cost_one", 30))
	if not Profile.pay(app.profile, "gems", cost):
		app.play("denied")
		app.toast("보석이 모자라요.")
		return
	_pull(count)


## 결과는 뽑는 순간 정해져 저장된다. 창에 카드를 한 장씩 뒤집듯 보여 준다.
func _pull(count: int, gold: bool = false) -> void:
	var cards := _cards()
	var results := Profile.draw_cards(app.profile, cards, app.eco, count, app.rng, gold)
	app.save()
	var best := 1
	var refund := 0
	for entry in results:
		best = maxi(best, int(entry["grade"]))
		refund += int(entry["gold"])
	app.play("summon_%d" % best)
	var body := Kit.vbox(10)
	var grid := GridContainer.new()
	grid.columns = mini(5, maxi(results.size(), 1))
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	var tiles: Array = []
	for entry in results:
		var holder := Kit.vbox(4)
		holder.custom_minimum_size = Vector2(150, 0)
		var tile := card_tile(cards, str(entry["id"]), true, false, 160.0, false)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tile)
		var note := "NEW!" if bool(entry["new"]) else "+%s" % Kit.money_text("gold", int(entry["gold"]))
		holder.add_child(Kit.label(note, 18, Kit.GOLD if bool(entry["new"]) else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		grid.add_child(holder)
		tiles.append(holder)
	if refund > 0:
		body.add_child(Kit.para("겹친 카드는 골드로 바뀌었어요: %s" % Kit.money_text("gold", refund), 18, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var host = app
	var screen_name := back_screen
	var params := back_params.duplicate()
	host.dialog("카드 뽑기 결과", body, [["확인", Kit.PRIMARY, func() -> void: host.go(screen_name, params)]], 900.0 if results.size() > 1 else 420.0)
	# 한 장씩 차례로 나타나게(자동 사진·저사양 모드면 곧바로)
	if MenuArt.calm(app):
		return
	for index in tiles.size():
		var holder: Control = tiles[index]
		holder.modulate.a = 0.0
		var tween := holder.create_tween()
		tween.tween_interval(0.25 + 0.08 * index)
		tween.tween_property(holder, "modulate:a", 1.0, 0.2)
