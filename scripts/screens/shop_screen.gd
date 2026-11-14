extends Control
## 상점: 영웅 소환(무료 1회·1회·10회)과 보석→골드 교환.
## 소환 확률과 보장은 data/economy.json, 규칙은 scripts/rules/profile.gd.
## 진짜 돈 결제는 아직 없다. 보석은 미션·출석·레벨업·첫 승리로 모은다.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const DiePreview := preload("res://scripts/ui/die_preview.gd")
const TopBar := preload("res://scripts/ui/top_bar.gd")
const BottomNav := preload("res://scripts/ui/bottom_nav.gd")

const BANNER := ["zeus", "lubu", "sejong", "nightingale"]

var app


func setup(main_app, _params: Dictionary) -> void:
	app = main_app
	var column := Kit.screen_frame(self, 16)
	var top := TopBar.new()
	column.add_child(top)
	top.setup(app)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := Kit.vbox(14)
	Kit.expand(body)
	scroll.add_child(body)
	body.add_child(_summon_panel())
	body.add_child(_deals_panel())
	body.add_child(_dice_panel())
	body.add_child(_exchange_panel())
	body.add_child(_gem_pack_panel())
	body.add_child(Kit.para("보석은 미션, 출석, 레벨업, 오늘 첫 승리로 모을 수 있어요.", 18, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var nav := BottomNav.new()
	column.add_child(nav)
	nav.setup("shop", app.badges())
	nav.tab_pressed.connect(_on_tab)


func _summon_panel() -> Control:
	var summon: Dictionary = app.eco.get("summon", {})
	var card := Kit.panel(Color("1f1838"), Kit.GOLD.darkened(0.3), 16)
	var column := Kit.vbox(12)
	card.add_child(column)
	column.add_child(Kit.title("영웅 소환", 44))
	var faces := Kit.hbox(8)
	column.add_child(faces)
	for id in BANNER:
		var face := Portrait.new()
		face.custom_minimum_size = Vector2(0, 230)
		var info: Dictionary = app.character(id)
		face.show_character(info, Kit.GRADE_COLORS[3])
		face.border = Kit.GOLD
		faces.add_child(Kit.expand(face))
	var rates: Dictionary = summon.get("rates", {})
	column.add_child(Kit.para("확률  ★★★ %s%%  ·  ★★ %s%%  ·  ★ %s%%" % [str(rates.get("3", 0)), str(rates.get("2", 0)), str(rates.get("1", 0))], 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var pity_left: int = int(summon.get("pity_3", 0)) - int(app.profile.get("pity", 0))
	column.add_child(Kit.para("10회 소환은 ★★ 이상 1명 보장  ·  ★★★ 확정까지 %d회" % max(pity_left, 1), 20, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(Kit.para("이미 가진 영웅이 나오면 강화 조각으로 바뀌어요.", 18, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var buttons := Kit.hbox(8)
	column.add_child(buttons)
	var free_left := Profile.free_summons_left(app.profile, app.eco)
	var free_button := Kit.button("무료 소환\n(오늘 %d회)" % free_left, Kit.GOOD, 22, 100)
	free_button.disabled = free_left <= 0
	free_button.pressed.connect(_on_free)
	buttons.add_child(Kit.expand(free_button))
	var one := Kit.button("1회\n%s" % Kit.money_text("gems", int(summon.get("cost_one", 100))), Kit.ACCENT, 22, 100)
	one.disabled = not Profile.can_pay(app.profile, "gems", int(summon.get("cost_one", 100)))
	one.pressed.connect(_on_paid.bind(1))
	buttons.add_child(Kit.expand(one))
	var ten := Kit.button("10회\n%s" % Kit.money_text("gems", int(summon.get("cost_ten", 900))), Color("c4861c"), 22, 100)
	ten.disabled = not Profile.can_pay(app.profile, "gems", int(summon.get("cost_ten", 900)))
	ten.pressed.connect(_on_paid.bind(10))
	buttons.add_child(Kit.expand(ten))
	return card


## 오늘의 특가: 가진 영웅의 강화 조각을 골드로. 매일 바뀐다.
func _deals_panel() -> Control:
	var card := Kit.panel(Color("1c2a24"), Color("3f8f5f"), 14)
	var column := Kit.vbox(10)
	card.add_child(column)
	var head := Kit.hbox(8)
	column.add_child(head)
	head.add_child(Kit.expand(Kit.label("오늘의 특가", 30, Kit.GOLD)))
	head.add_child(Kit.label("매일 자정에 바뀌어요", 17, Kit.MUTED))
	var deals := Profile.daily_deals(app.profile, app.data["characters"], app.eco, app.today())
	if deals.is_empty():
		column.add_child(Kit.para("강화할 영웅이 없어요. 모든 영웅이 최고 레벨이에요!", 19))
		return card
	var row := Kit.hbox(10)
	column.add_child(row)
	for index in deals.size():
		row.add_child(Kit.expand(_deal_cell(deals[index], index)))
	return card


func _deal_cell(deal: Dictionary, index: int) -> Control:
	var character: Dictionary = app.character(str(deal["id"]))
	var grade := int(deal["grade"])
	var cell := Kit.vbox(4)
	var face := Portrait.new()
	face.custom_minimum_size = Vector2(0, 150)
	face.border = Kit.GRADE_COLORS[grade]
	face.border_width = 3.0
	face.show_character(character, Kit.CATEGORY_COLORS.get(character.get("category", ""), Kit.LINE))
	face.dim = bool(deal["bought"])
	cell.add_child(face)
	cell.add_child(Kit.label("%s %s" % ["★".repeat(grade), character.get("name", "")], 18, Kit.GRADE_COLORS[grade], HORIZONTAL_ALIGNMENT_CENTER))
	var shards := int(app.profile["owned"][str(deal["id"])]["shards"])
	cell.add_child(Kit.label("조각 +%d  (지금 %d)" % [int(deal["shards"]), shards], 16, Kit.GEM, HORIZONTAL_ALIGNMENT_CENTER))
	var text: String = "구매 완료" if bool(deal["bought"]) else Kit.money_text("gold", int(deal["gold"]))
	var buy := Kit.button(text, Color("2f8f4e"), 20, 60)
	buy.disabled = bool(deal["bought"]) or not Profile.can_pay(app.profile, "gold", int(deal["gold"]))
	buy.pressed.connect(_on_deal.bind(index))
	cell.add_child(buy)
	return cell


func _on_deal(index: int) -> void:
	var deals := Profile.daily_deals(app.profile, app.data["characters"], app.eco, app.today())
	if Profile.buy_deal(app.profile, app.data["characters"], app.eco, app.today(), index):
		app.save()
		app.play("good")
		app.toast("%s 조각 +%d" % [app.character(str(deals[index]["id"]))["name"], int(deals[index]["shards"])])
		app.go("shop")


## 주사위 상점: 한 번 사면 계속 쓰는 꾸밈 주사위. 능력 차이는 없다.
func _dice_panel() -> Control:
	var card := Kit.panel(Color("241c34"), Color("7d4fc0"), 14)
	var column := Kit.vbox(10)
	card.add_child(column)
	var head := Kit.hbox(8)
	column.add_child(head)
	head.add_child(Kit.expand(Kit.label("주사위 상점", 30, Kit.GOLD)))
	head.add_child(Kit.label("모양만 달라요 · 한 번 사면 계속 써요", 17, Kit.MUTED))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	var using := str(Profile.current_dice_skin(app.profile, app.eco).get("id", "classic"))
	for skin in app.eco.get("dice_skins", []):
		var id := str(skin["id"])
		var cell := Kit.vbox(4)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var preview := DiePreview.new()
		preview.skin = skin
		preview.face = 6 if id == using else 5
		preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(preview)
		cell.add_child(Kit.label(str(skin["name"]).replace(" 주사위", ""), 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		var owned := Profile.owns_dice_skin(app.profile, id)
		var text := "사용 중" if id == using else ("쓰기" if owned else Kit.reward_line(skin.get("cost", {})))
		var button := Kit.button(text, Kit.PANEL_LIGHT if id == using else (Kit.ACCENT if owned else Color("7d4fc0")), 17, 54)
		button.disabled = id == using
		button.pressed.connect(_on_dice_skin.bind(id))
		cell.add_child(button)
		grid.add_child(cell)
	return card


func _on_dice_skin(id: String) -> void:
	if Profile.owns_dice_skin(app.profile, id):
		Profile.equip_dice_skin(app.profile, id)
		app.play("click")
	elif Profile.buy_dice_skin(app.profile, app.eco, id):
		app.play("win")
		app.toast("%s를 샀어요! 바로 쓸게요." % Profile.dice_skin(app.eco, id)["name"])
	else:
		app.toast("골드나 보석이 모자라요.")
		return
	app.save()
	app.go("shop")


## 보석 상품: 정식 버전에서 팔 구성을 미리 보여 준다. 아직 결제가 없어서 살 수 없다.
func _gem_pack_panel() -> Control:
	var table: Dictionary = app.eco.get("gem_packs", {})
	var card := Kit.panel(Color("1c2440"), Kit.GEM, 14)
	var column := Kit.vbox(10)
	card.add_child(column)
	var head := Kit.hbox(8)
	column.add_child(head)
	head.add_child(Kit.expand(Kit.label("보석 상점", 30, Kit.GOLD)))
	head.add_child(Kit.label("준비 중", 20, Color("ff9a6a")))
	column.add_child(Kit.para("정식 버전에서 열릴 상품이에요. 지금은 살 수 없고, 보석은 출석·미션·업적·패스·우편으로 모을 수 있어요.", 18, Kit.MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	for pack in table.get("packs", []):
		var cell := Kit.panel(Color("14182f"), Kit.LINE, 10)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var text := Kit.vbox(2)
		cell.add_child(text)
		text.add_child(Kit.label(str(pack["name"]), 22))
		text.add_child(Kit.label(Kit.money_text("gems", int(pack["gems"])), 22, Kit.GEM))
		text.add_child(Kit.label(str(pack.get("note", "")), 16, Kit.MUTED))
		var buy := Kit.button("준비 중", Kit.PANEL_LIGHT, 18, 50)
		buy.disabled = true
		text.add_child(buy)
		grid.add_child(cell)
	return card


func _exchange_panel() -> Control:
	var card := Kit.panel()
	var column := Kit.vbox(10)
	card.add_child(column)
	column.add_child(Kit.label("골드 교환", 30, Kit.GOLD))
	column.add_child(Kit.label("골드는 영웅 강화에 써요.", 18, Kit.MUTED))
	var offers: Array = app.eco.get("exchange", [])
	for index in offers.size():
		var offer: Dictionary = offers[index]
		var row := Kit.hbox(10)
		column.add_child(row)
		row.add_child(Kit.expand(Kit.label("%s  →  %s" % [Kit.money_text("gems", int(offer["gems"])), Kit.money_text("gold", int(offer["gold"]))], 26)))
		var buy := Kit.button("교환", Kit.ACCENT, 22, 64)
		buy.custom_minimum_size = Vector2(150, 64)
		buy.disabled = not Profile.can_pay(app.profile, "gems", int(offer["gems"]))
		buy.pressed.connect(_on_exchange.bind(index))
		row.add_child(buy)
	return card


func _on_free() -> void:
	if not Profile.use_free_summon(app.profile, app.eco):
		return
	_summon(1)


func _on_paid(count: int) -> void:
	var summon: Dictionary = app.eco.get("summon", {})
	var cost := int(summon.get("cost_ten" if count >= 10 else "cost_one", 100))
	if not Profile.pay(app.profile, "gems", cost):
		app.toast("보석이 모자라요.")
		return
	_summon(count)


func _summon(count: int) -> void:
	var results := Profile.summon(app.profile, app.data["characters"], app.eco, count, app.rng)
	app.save()
	# 결과를 바로 보여 주지 않고 잠깐 뜸을 들인다.
	await app.wait_loading("소환 중...", 0.9)
	app.play("reveal")
	app.go("shop")
	app.current_screen.show_results(results)


## 소환 결과를 카드로 하나씩 뒤집어 보여 준다.
func show_results(results: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 5 if results.size() > 4 else results.size()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var best := 1
	var cards: Array = []
	for entry in results:
		var grade := int(entry["grade"])
		best = max(best, grade)
		var character: Dictionary = app.character(str(entry["id"]))
		var cell := Kit.vbox(2)
		cell.custom_minimum_size = Vector2(112 if results.size() > 4 else 180, 0)
		var face := Portrait.new()
		face.custom_minimum_size = Vector2(0, 112 if results.size() > 4 else 180)
		face.border = Kit.GRADE_COLORS[grade]
		face.border_width = 4.0
		face.show_character(character, Kit.CATEGORY_COLORS.get(character.get("category", ""), Kit.LINE))
		cell.add_child(face)
		cell.add_child(Kit.label("★".repeat(grade), 16, Kit.GRADE_COLORS[grade], HORIZONTAL_ALIGNMENT_CENTER))
		cell.add_child(Kit.label(str(character.get("name", "")), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		var note: String = "NEW!" if bool(entry["new"]) else "조각 +%d" % int(entry["shards"])
		cell.add_child(Kit.label(note, 16, Kit.GOLD if bool(entry["new"]) else Kit.GEM, HORIZONTAL_ALIGNMENT_CENTER))
		cell.modulate.a = 0.0
		grid.add_child(cell)
		cards.append(cell)
	var body := Kit.vbox(10)
	var center := CenterContainer.new()
	center.add_child(grid)
	body.add_child(center)
	var title_text: String = "★★★ 등장!" if best >= 3 else "소환 결과"
	var window: Control = app.dialog(title_text, body, [["확인", Kit.ACCENT]], 680)
	var tween := window.create_tween()
	for cell in cards:
		tween.tween_property(cell, "modulate:a", 1.0, 0.12)
	if best >= 3:
		app.play("win")


func _on_exchange(index: int) -> void:
	if Profile.exchange(app.profile, app.eco, index):
		app.save()
		app.play("good")
		app.toast("골드로 바꿨어요.")
		app.go("shop")


func _on_tab(screen_name: String) -> void:
	if screen_name == "shop":
		return
	app.play("click")
	app.go(screen_name)
