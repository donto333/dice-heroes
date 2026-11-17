extends Control
## 상점: 영웅 소환(무료 1회·1회·10회)과 보석→골드 교환.
## 소환 확률과 보장은 data/economy.json, 규칙은 scripts/rules/profile.gd.
## 진짜 돈 결제는 아직 없다. 보석은 미션·출석·레벨업·첫 승리로 모은다.

const SummonFx := preload("res://scripts/ui/summon_fx.gd")
const ArtView := preload("res://scripts/ui/art_view.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const DiePreview := preload("res://scripts/ui/die_preview.gd")
const TopBar := preload("res://scripts/ui/top_bar.gd")
const BottomNav := preload("res://scripts/ui/bottom_nav.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")

const BANNER := ["zeus", "lubu", "sejong", "nightingale"]

var app


## 상점 탭: 소환(소환·특가) / 성장(유물·골드 교환) / 꾸미기(주사위) / 보석(마일리지·보석 상점)
const TABS := [["summon", "소환"], ["grow", "성장"], ["look", "꾸미기"], ["gems", "보석"]]
## 왼쪽 세로 판 항목: [id, 글자, 아이콘]
const RAIL := [["summon", "영웅 소환", "summon"], ["grow", "성장", "upgrade"], ["look", "주사위", "dice"], ["gems", "보석", "gem"]]
var _tab := "summon"


func setup(main_app, _params: Dictionary) -> void:
	app = main_app
	_tab = str(_params.get("tab", "summon"))
	# 시안식 틀: 왼쪽 세로 판에 상점 항목, 오른쪽 큰 금테 판.
	var summon_table: Dictionary = app.eco.get("summon", {})
	var pity_left: int = maxi(int(summon_table.get("pity_3", 0)) - int(app.profile.get("pity", 0)), 1)
	var summary := MenuArt.summary("summon", "무료 소환 %d회" % Profile.free_summons_left(app.profile, app.eco), "★★★ 확정까지 %d회" % pity_left)
	var column := MenuArt.frame(self, app, "ui/bg_shop", RAIL, _tab, _on_shop_tab, summary)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := Kit.vbox(14)
	Kit.expand(body)
	scroll.add_child(body)
	match _tab:
		"grow":
			body.add_child(_relic_panel())
			body.add_child(_exchange_panel())
		"look":
			body.add_child(_dice_panel())
		"gems":
			body.add_child(_mileage_panel())
			body.add_child(_gem_pack_panel())
		_:
			body.add_child(_summon_panel())
			body.add_child(_deals_panel())
	body.add_child(Kit.para("보석은 미션, 출석, 레벨업, 오늘 첫 승리로 모을 수 있어요.", 18, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	# 남은 버튼도 모두 금테 알약으로(UI 개편 1단계)
	MenuArt.skin_buttons(body)


func _summon_panel() -> Control:
	var summon: Dictionary = app.eco.get("summon", {})
	var card := Kit.panel(Color("5b35c0"), Kit.GOLD, 16)
	# 소환진 그림(assets/art/ui/summon.jpg)을 판 바탕에 깐다.
	var circle := ArtView.new()
	circle.show_art("ui/summon")
	circle.drift = true
	circle.focus_y = 0.55
	circle.shade = Color(0.15, 0.05, 0.35, 0.45)
	card.add_child(circle)
	var column := Kit.vbox(12)
	card.add_child(column)
	column.add_child(Kit.title("영웅 소환", 40))
	var faces := Kit.hbox(8)
	column.add_child(faces)
	for id in BANNER:
		var face := Portrait.new()
		face.custom_minimum_size = Vector2(0, 150)
		face.hd = true
		var info: Dictionary = app.character(id)
		face.show_character(info, Kit.GRADE_COLORS[3])
		face.border = Kit.GOLD
		faces.add_child(Kit.expand(face))
	var rates: Dictionary = summon.get("rates", {})
	var pity_left: int = int(summon.get("pity_3", 0)) - int(app.profile.get("pity", 0))
	# 확률·보장은 캡슐 두 개로
	var caps := Kit.hbox(8)
	caps.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(caps)
	caps.add_child(MenuArt.capsule("★★★ %s%%  ·  ★★ %s%%  ·  ★ %s%%" % [str(rates.get("3", 0)), str(rates.get("2", 0)), str(rates.get("1", 0))], "star", 18))
	caps.add_child(MenuArt.capsule("10회는 ★★ 이상 보장 · ★★★ 확정까지 %d회" % max(pity_left, 1), "", 18))
	column.add_child(Kit.para("이미 가진 영웅이 나오면 강화 조각으로 바뀌어요.", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var buttons := Kit.hbox(10)
	column.add_child(buttons)
	var free_left := Profile.free_summons_left(app.profile, app.eco)
	var free_button := MenuArt.pill_button("무료 소환 (오늘 %d회)" % free_left, "green", "l")
	free_button.disabled = free_left <= 0
	free_button.pressed.connect(_on_free)
	buttons.add_child(Kit.expand(free_button))
	var one := MenuArt.pill_button("1회  %s" % Kit.comma(int(summon.get("cost_one", 100))), "blue", "l")
	_gem_icon(one)
	one.disabled = not Profile.can_pay(app.profile, "gems", int(summon.get("cost_one", 100)))
	one.pressed.connect(_on_paid.bind(1))
	buttons.add_child(Kit.expand(one))
	var ten := MenuArt.pill_button("10회  %s" % Kit.comma(int(summon.get("cost_ten", 900))), "gold", "l")
	_gem_icon(ten)
	ten.disabled = not Profile.can_pay(app.profile, "gems", int(summon.get("cost_ten", 900)))
	ten.pressed.connect(_on_paid.bind(10))
	buttons.add_child(Kit.expand(ten))
	Kit.shimmer(ten)
	return card


## 오늘의 특가: 가진 영웅의 강화 조각을 골드로. 매일 바뀐다.
func _deals_panel() -> Control:
	var group := Kit.vbox(8)
	group.add_child(MenuArt.section("오늘의 특가", "deals", "매일 자정에 바뀌어요"))
	var deals := Profile.daily_deals(app.profile, app.data["characters"], app.eco, app.today())
	if deals.is_empty():
		MenuArt.list_row(group, "check", "강화할 영웅이 없어요", "모든 영웅이 최고 레벨이에요!")
		return group
	var line := MenuArt.row(12)
	group.add_child(line)
	var cells := Kit.hbox(10)
	line.add_child(cells)
	for index in deals.size():
		cells.add_child(Kit.expand(_deal_cell(deals[index], index)))
	return group


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
	var text: String = "구매 완료" if bool(deal["bought"]) else Kit.comma(int(deal["gold"]))
	var buy := MenuArt.pill_button(text, "green", "m")
	if not bool(deal["bought"]):
		_money_icon(buy, "gold")
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
		app.go("shop", {"tab": _tab})


## 보석 마일리지: 보석을 쓴 만큼 쌓여 단계 보상을 준다.
func _mileage_panel() -> Control:
	var group := Kit.vbox(8)
	var steps: Array = app.eco["mileage"]["steps"]
	var rewards: Array = app.eco["mileage"]["rewards"]
	var spent := int(app.profile.get("gems_spent", 0))
	var claimed: Array = app.profile.get("mileage_claimed", [])
	group.add_child(MenuArt.section("보석 마일리지", "gem", "쓴 보석 %s" % Kit.comma(spent)))
	var line := MenuArt.row(12)
	group.add_child(line)
	var column := Kit.vbox(8)
	line.add_child(column)
	column.add_child(Kit.bar(float(mini(spent, int(steps[steps.size() - 1]))) / float(int(steps[steps.size() - 1])), Kit.GEM, 12))
	var marks := Kit.hbox(6)
	column.add_child(marks)
	for index in steps.size():
		var got := claimed.has(index)
		marks.add_child(Kit.expand(Kit.label("%d\n%s%s" % [int(steps[index]), Kit.reward_line(rewards[index]), "\n(받음)" if got else ""], 16, Kit.MUTED if got else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)))
	var ready: Array = Profile.mileage_claimable(app.profile, app.eco)
	var button := MenuArt.pill_button("보상 %d개 받기" % ready.size() if not ready.is_empty() else "보석을 쓰면 쌓여요", "gold" if not ready.is_empty() else "gray", "m")
	button.disabled = ready.is_empty()
	button.pressed.connect(_on_mileage)
	column.add_child(button)
	return group


func _on_mileage() -> void:
	var reward := Profile.claim_mileage(app.profile, app.eco)
	if reward.is_empty():
		return
	app.save()
	app.play("purchase")
	MenuArt.fly_reward(app, null, reward)
	app.go("shop", {"tab": _tab})
	app.toast("마일리지 보상: %s" % Kit.reward_line(reward))


## 유물 상점: 파티에 하나만 장착하는 시작 보너스.
func _relic_panel() -> Control:
	var group := Kit.vbox(8)
	group.add_child(MenuArt.section("유물 상점", "relic", "하나만 장착 · 판을 시작할 때 효과"))
	var using := str(Profile.current_relic(app.profile, app.eco).get("id", ""))
	for item in app.eco.get("relics", []):
		var id := str(item["id"])
		var line := MenuArt.row(10)
		var row := Kit.hbox(12)
		line.add_child(row)
		var picture := ArtView.new()
		picture.show_art("relics/" + id)
		if picture.has_art():
			picture.custom_minimum_size = Vector2(64, 64)
			picture.focus_y = 0.5
			row.add_child(picture)
		else:
			picture.free()
			row.add_child(Kit.icon("relic", 48.0))
		var words := Kit.vbox(0)
		words.add_child(Kit.label(str(item["name"]) + ("  (장착 중)" if id == using else ""), 24, Kit.GOLD if id == using else Color.WHITE))
		words.add_child(Kit.para(str(item["text"]), 18, Kit.MUTED))
		row.add_child(Kit.expand(words))
		var owned := Profile.owns_relic(app.profile, id)
		var button: Button
		if id == using:
			button = MenuArt.pill_button("벗기", "blue", "m")
		elif owned:
			button = MenuArt.pill_button("장착", "green", "m")
		else:
			var cost: Dictionary = item.get("cost", {})
			var currency := "gems" if int(cost.get("gems", 0)) > 0 else "gold"
			button = MenuArt.pill_button(Kit.comma(int(cost.get(currency, 0))), "gold", "m")
			_money_icon(button, "gem" if currency == "gems" else "gold")
		button.custom_minimum_size = Vector2(160, 56)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_on_relic.bind(id))
		row.add_child(button)
		group.add_child(line)
	return group


func _on_relic(id: String) -> void:
	if Profile.owns_relic(app.profile, id):
		Profile.equip_relic(app.profile, id)
		app.play("click")
	elif Profile.buy_relic(app.profile, app.eco, id):
		app.play("purchase")
		app.toast("%s을(를) 샀어요! 바로 장착했어요." % Profile.relic(app.eco, id)["name"])
	else:
		app.play("denied")
		app.toast("골드나 보석이 모자라요.")
		return
	app.save()
	app.go("shop", {"tab": _tab})


## 주사위 상점: 한 번 사면 계속 쓰는 꾸밈 주사위. 능력 차이는 없다.
func _dice_panel() -> Control:
	var group := Kit.vbox(8)
	group.add_child(MenuArt.section("주사위 상점", "dice", "모양만 달라요 · 한 번 사면 계속 써요"))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	group.add_child(grid)
	var using := str(Profile.current_dice_skin(app.profile, app.eco).get("id", "classic"))
	for skin in app.eco.get("dice_skins", []):
		var id := str(skin["id"])
		# 금테 작은 카드(주사위 그림 + 이름 + 가격 알약)
		var card: PanelContainer = MenuArt.art_box("goods_card", 30.0, 12)
		if card == null:
			card = Kit.panel(Kit.INSET, Kit.LINE, 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cell := Kit.vbox(4)
		card.add_child(cell)
		var preview := DiePreview.new()
		preview.skin = skin
		preview.face = 6 if id == using else 5
		preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(preview)
		var name_label := Kit.label(str(skin["name"]).replace(" 주사위", ""), 18, Kit.GOLD if id == using else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		name_label.clip_text = true
		cell.add_child(name_label)
		var owned := Profile.owns_dice_skin(app.profile, id)
		var button: Button
		if id == using:
			button = MenuArt.pill_button("사용 중", "gray", "s")
			button.disabled = true
		elif owned:
			button = MenuArt.pill_button("쓰기", "green", "s")
		else:
			var cost: Dictionary = skin.get("cost", {})
			var currency := "gems" if int(cost.get("gems", 0)) > 0 else "gold"
			button = MenuArt.pill_button(Kit.comma(int(cost.get(currency, 0))), "gold", "s")
			_money_icon(button, "gem" if currency == "gems" else "gold")
		button.pressed.connect(_on_dice_skin.bind(id))
		cell.add_child(button)
		grid.add_child(card)
	return group


func _on_dice_skin(id: String) -> void:
	if Profile.owns_dice_skin(app.profile, id):
		Profile.equip_dice_skin(app.profile, id)
		app.play("click")
	elif Profile.buy_dice_skin(app.profile, app.eco, id):
		app.play("purchase")
		app.toast("%s를 샀어요! 바로 쓸게요." % Profile.dice_skin(app.eco, id)["name"])
	else:
		app.play("denied")
		app.toast("골드나 보석이 모자라요.")
		return
	app.save()
	app.go("shop", {"tab": _tab})


## 보석 상품: 정식 버전에서 팔 구성을 미리 보여 준다. 아직 결제가 없어서 살 수 없다.
func _gem_pack_panel() -> Control:
	var table: Dictionary = app.eco.get("gem_packs", {})
	var group := Kit.vbox(8)
	group.add_child(MenuArt.section("보석 상점", "gem", "준비 중"))
	group.add_child(Kit.para("정식 버전에서 열릴 상품이에요. 지금은 살 수 없고, 보석은 출석·미션·업적·패스·우편으로 모을 수 있어요.", 18, Kit.MUTED))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	group.add_child(grid)
	for pack in table.get("packs", []):
		var cell := MenuArt.row(10)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var line := Kit.hbox(8)
		cell.add_child(line)
		line.add_child(Kit.icon("gem", 44.0))
		var text := Kit.vbox(2)
		line.add_child(Kit.expand(text))
		text.add_child(Kit.label(str(pack["name"]), 22))
		text.add_child(Kit.label(Kit.comma(int(pack["gems"])), 22, Kit.GEM))
		if str(pack.get("note", "")) != "":
			text.add_child(Kit.label(str(pack.get("note", "")), 16, Kit.MUTED))
		var buy := MenuArt.pill_button("준비 중", "gray", "s")
		buy.disabled = true
		text.add_child(buy)
		grid.add_child(cell)
	# 묶음 상품(스타터·성장·패스 프리미엄) 설계도 함께 보여 준다.
	for bundle in table.get("bundles", []):
		var line := MenuArt.row(10)
		var row := Kit.hbox(10)
		line.add_child(row)
		row.add_child(Kit.icon("gift", 48.0))
		var words := Kit.vbox(2)
		words.add_child(Kit.label(str(bundle["name"]), 24, Kit.GOLD))
		words.add_child(Kit.para(str(bundle.get("text", "")), 18, Color.WHITE))
		if str(bundle.get("note", "")) != "":
			words.add_child(Kit.label(str(bundle.get("note", "")), 16, Kit.MUTED))
		row.add_child(Kit.expand(words))
		var soon := MenuArt.pill_button("준비 중", "gray", "m")
		soon.custom_minimum_size = Vector2(130, 56)
		soon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		soon.disabled = true
		row.add_child(soon)
		group.add_child(line)
	return group


func _exchange_panel() -> Control:
	var group := Kit.vbox(8)
	group.add_child(MenuArt.section("골드 교환", "gold", "골드는 영웅 강화에 써요"))
	var offers: Array = app.eco.get("exchange", [])
	for index in offers.size():
		var offer: Dictionary = offers[index]
		var buy := MenuArt.pill_button(Kit.comma(int(offer["gems"])), "green", "m")
		_money_icon(buy, "gem")
		buy.custom_minimum_size = Vector2(160, 56)
		buy.disabled = not Profile.can_pay(app.profile, "gems", int(offer["gems"]))
		buy.pressed.connect(_on_exchange.bind(index))
		MenuArt.list_row(group, "gold", "골드 %s" % Kit.comma(int(offer["gold"])), "보석 %s개로 바꿔요" % Kit.comma(int(offer["gems"])), buy)
	return group


## 가격 버튼 왼쪽에 골드·보석 아이콘을 붙인다.
func _money_icon(button: Button, icon_name: String) -> void:
	var picture: TextureRect = Kit.icon(icon_name, 28.0)
	if picture.texture == null:
		return
	button.icon = picture.texture
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", 28)
	button.add_theme_constant_override("h_separation", 6)


func _gem_icon(button: Button) -> void:
	_money_icon(button, "gem")


func _on_free() -> void:
	if not Profile.use_free_summon(app.profile, app.eco):
		return
	_summon(1)


func _on_paid(count: int) -> void:
	var summon: Dictionary = app.eco.get("summon", {})
	var cost := int(summon.get("cost_ten" if count >= 10 else "cost_one", 100))
	if not Profile.pay(app.profile, "gems", cost):
		app.play("denied")
		app.toast("보석이 모자라요.")
		return
	_summon(count)


func _summon(count: int) -> void:
	var results := Profile.summon(app.profile, app.data["characters"], app.eco, count, app.rng)
	app.save()
	# 결과를 바로 보여 주지 않고 소환 연출(마법진과 빛기둥)을 먼저 보여 준다.
	var best_grade := 1
	for entry in results:
		best_grade = maxi(best_grade, int(entry["grade"]))
	if app.instant:
		await app.wait_loading("소환 중...", 0.9)
	else:
		var ritual := SummonFx.new()
		app.add_child(ritual)
		app.play("skill")
		await ritual.play(best_grade)
	app.play("summon_%d" % clampi(best_grade, 1, 3))
	app.go("shop", {"tab": _tab})
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
		face.hd = results.size() <= 4
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
	# 카드가 하나씩 통 튀어나온다.
	var tween := window.create_tween()
	for cell in cards:
		cell.pivot_offset = cell.custom_minimum_size * 0.5
		cell.scale = Vector2(0.4, 0.4)
		tween.tween_property(cell, "modulate:a", 1.0, 0.08)
		tween.parallel().tween_property(cell, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if best >= 3:
		app.play("purchase")


func _on_exchange(index: int) -> void:
	if Profile.exchange(app.profile, app.eco, index):
		app.save()
		app.play("good")
		app.toast("골드로 바꿨어요.")
		app.go("shop", {"tab": _tab})


func _on_shop_tab(id: String) -> void:
	if id == _tab:
		return
	app.play("tab")
	app.go("shop", {"tab": id})


func _on_tab(screen_name: String) -> void:
	if screen_name == "shop":
		return
	app.play("click")
	app.go(screen_name)
