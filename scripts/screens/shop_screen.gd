extends Control
## 상점: 영웅 소환(무료 1회·1회·10회)과 보석→골드 교환.
## 소환 확률과 보장은 data/economy.json, 규칙은 scripts/rules/profile.gd.
## 진짜 돈 결제는 아직 없다. 보석은 미션·출석·레벨업·첫 승리로 모은다.

const SummonShow := preload("res://scripts/ui/summon_show.gd")
const ArtView := preload("res://scripts/ui/art_view.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const DiePreview := preload("res://scripts/ui/die_preview.gd")
const TopBar := preload("res://scripts/ui/top_bar.gd")
const BottomNav := preload("res://scripts/ui/bottom_nav.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const OddsWindow := preload("res://scripts/ui/odds_window.gd")
const PurchaseWindows := preload("res://scripts/ui/purchase_windows.gd")
const AdPlayer := preload("res://scripts/ui/ad_player.gd")
const CardPanels := preload("res://scripts/ui/card_panels.gd")
const PassPanel := preload("res://scripts/ui/pass_panel.gd")

const TRAIL_ICONS := {"none": "close", "dust": "speed", "star": "star", "petal": "gift", "ice": "orb_blue", "ember": "orb_gold", "bolt": "bolt", "coin": "gold"}
const BANNER := ["zeus", "lubu", "sejong", "nightingale"]

var app


## 상점 탭: 소환(소환·특가) / 성장(유물·골드 교환) / 꾸미기(주사위) / 보석(마일리지·보석 상점)
const TABS := [["summon", "소환"], ["grow", "성장"], ["look", "꾸미기"], ["gems", "보석"]]
## 왼쪽 세로 판 항목: [id, 글자, 아이콘]
## 2026-11-18 사용자 결정: 영웅 소환 바로 아래에 카드 뽑기를 따로 둔다.
const RAIL := [["summon", "영웅 소환", "summon"], ["cards", "카드 뽑기", "card"], ["grow", "성장", "upgrade"], ["look", "꾸미기", "dice"], ["gems", "보석", "gem"], ["pass", "시즌 패스", "pass"]]
var _tab := "summon"


func setup(main_app, _params: Dictionary) -> void:
	app = main_app
	_tab = str(_params.get("tab", "summon"))
	# 시안식 틀: 왼쪽 세로 판에 상점 항목, 오른쪽 큰 금테 판.
	var summon_table: Dictionary = app.eco.get("summon", {})
	var pity_left: int = maxi(int(summon_table.get("pity_3", 0)) - int(app.profile.get("pity", 0)), 1)
	var summary := MenuArt.summary("summon", "무료 소환 %d회" % Profile.free_summons_left(app.profile, app.eco), "★★★ 확정까지 %d회" % pity_left)
	var card_panels: Node = null
	if _tab == "cards":
		card_panels = CardPanels.new()
		add_child(card_panels)
		card_panels.init(app, "shop", {"tab": "cards"})
		var card_pity_left: int = maxi(int(app.eco.get("card_gacha", {}).get("pity_3", 0)) - int(app.profile.get("card_pity", 0)), 1)
		summary = MenuArt.summary("card", "무료 뽑기 %d회" % Profile.free_card_draws_left(app.profile, app.eco), "★★★ 확정까지 %d회" % card_pity_left)
	var column := MenuArt.frame(self, app, "ui/bg_shop", RAIL, _tab, _on_shop_tab, summary)

	if _tab == "pass":
		# 시즌 패스(2026-11-18 사용자 결정: 상점 안 메뉴). 패스 판이 스스로 스크롤을 만든다.
		var pass_panel := PassPanel.new()
		add_child(pass_panel)
		pass_panel.build(app, column)
		MenuArt.skin_buttons(column)
		return
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
			body.add_child(_trail_panel())
		"gems":
			body.add_child(_mileage_panel())
			body.add_child(_gem_pack_panel())
		"cards":
			card_panels.build_gacha(body)
		_:
			body.add_child(_summon_panel())
			body.add_child(_gold_summon_panel())
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
	# 픽업 소환(2026-11-19): 이번 픽업 영웅을 크게, 다른 ★★★ 셋을 옆에.
	var date := str(app.profile.get("daily", {}).get("date", ""))
	var pickup := Profile.pickup_hero(app.eco, date)
	var pickup_info: Dictionary = app.character(pickup) if pickup != "" else {}
	column.add_child(Kit.title("픽업 소환" if pickup != "" else "영웅 소환", 40))
	var faces := Kit.hbox(8)
	column.add_child(faces)
	var shown: Array = [] if pickup == "" else [pickup]
	for id in BANNER:
		if shown.size() < 4 and not shown.has(id):
			shown.append(id)
	for id in shown:
		var face := Portrait.new()
		face.custom_minimum_size = Vector2(0, 150)
		face.hd = true
		var info: Dictionary = app.character(id)
		face.show_character(info, Kit.GRADE_COLORS[3])
		face.border = Kit.GOLD
		Kit.expand(face)
		if id == pickup:
			face.size_flags_stretch_ratio = 1.8
		faces.add_child(face)
	if pickup != "":
		var up_line := Kit.hbox(8)
		up_line.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_child(up_line)
		var share := int(summon.get("pickup", {}).get("share", 0))
		up_line.add_child(MenuArt.capsule("%s 확률 UP · ★★★의 %d%%" % [str(pickup_info.get("name", pickup)), share], "star", 20))
		up_line.add_child(MenuArt.capsule("%d일 남음" % Profile.pickup_days_left(app.eco, date), "", 20))
	var rates: Dictionary = summon.get("rates", {})
	var pity_left: int = int(summon.get("pity_3", 0)) - int(app.profile.get("pity", 0))
	# 확률·보장은 캡슐 두 개로
	var caps := Kit.hbox(8)
	caps.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(caps)
	caps.add_child(MenuArt.capsule("★★★ %s%%  ·  ★★ %s%%  ·  ★ %s%%" % [str(rates.get("3", 0)), str(rates.get("2", 0)), str(rates.get("1", 0))], "star", 18))
	caps.add_child(MenuArt.capsule("10회는 ★★ 이상 보장 · ★★★ 확정까지 %d회" % max(pity_left, 1), "", 18))
	caps.add_child(OddsWindow.button(app, "hero"))
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


## 골드 소환(2026-11-18 사용자 요청): ★·★★ 영웅만 나온다. ★★★ 보장 횟수는 세지 않는다.
func _gold_summon_panel() -> Control:
	var table: Dictionary = app.eco.get("summon", {}).get("gold", {})
	var group := Kit.vbox(8)
	var rates: Dictionary = table.get("rates", {})
	group.add_child(MenuArt.section("골드 소환", "gold", "★★ %d%% · ★ %d%%  (★★★ 없음)" % [int(rates.get("2", 0)), int(rates.get("1", 0))]))
	var line := MenuArt.row(12)
	group.add_child(line)
	var inside := Kit.hbox(10)
	line.add_child(inside)
	var words := Kit.vbox(2)
	words.add_child(Kit.label("★·★★ 영웅 소환", 24, Color.WHITE))
	words.add_child(Kit.para("골드로 소환해요. 10회는 ★★ 이상 1명 보장.", 17, Kit.MUTED))
	inside.add_child(Kit.expand(words))
	inside.add_child(OddsWindow.button(app, "hero_gold"))
	for count in [1, 10]:
		var cost := int(table.get("cost_ten" if count >= 10 else "cost_one", 1000))
		var button := MenuArt.pill_button("%d회  %s" % [count, Kit.comma(cost)], "green" if count == 1 else "gold", "m")
		button.custom_minimum_size = Vector2(200, 60)
		_money_icon(button, "gold")
		button.disabled = not Profile.can_pay(app.profile, "gold", cost)
		button.pressed.connect(_on_gold.bind(count))
		inside.add_child(button)
	return group


func _on_gold(count: int) -> void:
	var table: Dictionary = app.eco.get("summon", {}).get("gold", {})
	var cost := int(table.get("cost_ten" if count >= 10 else "cost_one", 1000))
	if not Profile.pay(app.profile, "gold", cost):
		app.play("denied")
		app.toast("골드가 모자라요.")
		return
	_summon(count, cost, true)


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


## 발끝 효과(2026-11-19, 유료 꾸미기): 내 말이 한 칸 뛸 때마다 발밑에 피어나는 효과.
func _trail_panel() -> Control:
	var group := Kit.vbox(8)
	group.add_child(MenuArt.section("발끝 효과", "star", "내 말이 뛸 때 발밑에 피어나요 · 능력치와는 상관없어요"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	group.add_child(grid)
	var using := str(app.profile.get("trail", "none"))
	if not Profile.owns_trail(app.profile, using):
		using = "none"
	for entry in app.eco.get("trails", []):
		var id := str(entry["id"])
		var card: PanelContainer = MenuArt.art_box("goods_card", 30.0, 12)
		if card == null:
			card = Kit.panel(Kit.INSET, Kit.LINE, 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cell := Kit.vbox(4)
		card.add_child(cell)
		var icon: Control = Kit.icon(TRAIL_ICONS.get(id, "star"), 56.0)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(icon)
		cell.add_child(Kit.label(str(entry["name"]), 20, Kit.GOLD if id == using else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		var cost: Dictionary = entry.get("cost", {})
		var paid_only := cost.has("paid_gems")
		cell.add_child(Kit.label("유료 보석 전용" if paid_only else " ", 14, Kit.GEM if paid_only else Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		var button: Button
		if id == using:
			button = MenuArt.pill_button("사용 중", "gray", "s")
			button.disabled = true
		elif Profile.owns_trail(app.profile, id):
			button = MenuArt.pill_button("쓰기", "green", "s")
		else:
			var currency := "gold"
			for key in ["paid_gems", "gems", "gold"]:
				if cost.has(key):
					currency = key
					break
			button = MenuArt.pill_button(Kit.comma(int(cost.get(currency, 0))), "purple" if paid_only else "gold", "s")
			_money_icon(button, "gold" if currency == "gold" else "gem")
		button.pressed.connect(_on_trail.bind(id))
		cell.add_child(button)
		grid.add_child(card)
	return group


func _on_trail(id: String) -> void:
	if Profile.owns_trail(app.profile, id):
		Profile.equip_trail(app.profile, id)
		app.play("click")
	elif Profile.buy_trail(app.profile, app.eco, id):
		app.play("purchase")
		app.toast("발끝 효과 '%s'를 샀어요! 바로 쓸게요." % Profile.trail(app.eco, id)["name"])
	else:
		app.play("denied")
		var cost: Dictionary = Profile.trail(app.eco, id).get("cost", {})
		app.toast("유료 보석이 모자라요." if cost.has("paid_gems") else "골드나 보석이 모자라요.")
		return
	app.save()
	app.go("shop", {"tab": _tab})


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
	var open := bool(table.get("open", false))
	var group := Kit.vbox(8)
	group.add_child(MenuArt.section("보석 상점", "gem", "" if open else "준비 중"))
	# 유료·무료 보석과 구매 내역(2026-11-19, 정식 출시 준비)
	var wallet := Kit.hbox(8)
	wallet.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_child(wallet)
	wallet.add_child(MenuArt.capsule("유료 보석 %s" % Kit.comma(Profile.paid_gems(app.profile)), "gem", 18))
	wallet.add_child(MenuArt.capsule("무료 보석 %s" % Kit.comma(Profile.free_gems(app.profile)), "gem", 18))
	var history := MenuArt.pill_button("구매 내역", "blue", "s")
	history.custom_minimum_size = Vector2(132, 40)
	history.pressed.connect(func() -> void: PurchaseWindows.history(app))
	wallet.add_child(history)
	# 보상형 광고: 보고 나면 보석(2026-11-19 사용자 결정 100개)
	var ad_gems := int((app.eco.get("ads", {}).get("placements", {}).get("gems", {}) as Dictionary).get("reward", {}).get("gems", 0))
	if ad_gems > 0:
		var ad_line := MenuArt.row(10)
		group.add_child(ad_line)
		var ad_row := Kit.hbox(10)
		ad_line.add_child(ad_row)
		ad_row.add_child(Kit.icon("gem", 44.0))
		var ad_words := Kit.vbox(2)
		ad_row.add_child(Kit.expand(ad_words))
		ad_words.add_child(Kit.label("광고 보고 보석 %d개" % ad_gems, 22, Color.WHITE))
		ad_words.add_child(Kit.label("오늘 %d번 남음" % Profile.ads_left(app.profile, app.eco, "gems"), 16, Kit.MUTED))
		var ad_button := MenuArt.pill_button("광고 보기", "purple", "m")
		ad_button.custom_minimum_size = Vector2(160, 52)
		ad_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ad_button.disabled = Profile.ads_left(app.profile, app.eco, "gems") <= 0
		ad_button.pressed.connect(_on_ad_gems.bind(ad_button))
		ad_row.add_child(ad_button)
	if not open:
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
		var contents := Profile.pack_contents(app.profile, app.eco, str(pack.get("id", "")))
		var amount := Kit.comma(int(contents["gems"]))
		if int(contents["bonus"]) > 0:
			amount += " + %s" % Kit.comma(int(contents["bonus"]))
		text.add_child(Kit.label(amount, 22, Kit.GEM))
		if str(pack.get("note", "")) != "":
			text.add_child(Kit.label(str(pack.get("note", "")), 16, Kit.MUTED))
		var buy := MenuArt.pill_button(PurchaseWindows.won(int(pack.get("price", 0))), "gold" if open else "blue", "s")
		var pack_id := str(pack.get("id", ""))
		buy.pressed.connect(func() -> void: PurchaseWindows.confirm(app, pack_id))
		text.add_child(buy)
		grid.add_child(cell)
	# 묶음 상품(스타터·성장·패스 프리미엄)은 아직 준비 중으로만 보여 준다.
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
		var price := int(bundle.get("price", 0))
		var soon := MenuArt.pill_button("%s · 준비 중" % PurchaseWindows.won(price) if price > 0 else "준비 중", "gray", "m")
		soon.custom_minimum_size = Vector2(180, 56)
		soon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		soon.disabled = true
		row.add_child(soon)
		group.add_child(line)
	return group


func _on_ad_gems(button: Button) -> void:
	if Profile.ads_left(app.profile, app.eco, "gems") <= 0:
		app.toast("오늘 볼 수 있는 광고를 다 봤어요.")
		return
	app.play("click")
	var host = app
	var ad := AdPlayer.new()
	host.add_child(ad)
	if not await ad.play(host):
		return
	var reward := Profile.watch_ad(host.profile, host.eco, "gems")
	host.save()
	if reward.is_empty():
		return
	host.play("reward")
	if is_instance_valid(button):
		MenuArt.fly_reward(host, button, reward)
	host.toast("광고 보상: %s" % Kit.reward_line(reward))
	host.go("shop", {"tab": "gems"})


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
	_summon(count, cost)


func _summon(count: int, again_cost: int = 0, gold: bool = false) -> void:
	var results := Profile.summon(app.profile, app.data["characters"], app.eco, count, app.rng, gold)
	app.save()
	# 결과는 이미 정해져 저장됐다. 소환 연출(제단 → 운명의 주사위 → 카드 뒤집기)로 보여 준다.
	# 연출이 끝나면 이 화면은 새로 그려지므로(app.go) 그 뒤에는 self를 쓰지 않는다.
	var host = app
	var tab := _tab
	var show := SummonShow.new()
	show.again_currency = "gold" if gold else "gems"
	host.add_child(show)
	var again: bool = await show.play(host, results, again_cost)
	host.go("shop", {"tab": tab})
	if again:
		if gold:
			host.current_screen._on_gold(count)
		else:
			host.current_screen._on_paid(count)


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
