extends Control
## 상점: 영웅 소환(무료 1회·1회·10회)과 보석→골드 교환.
## 소환 확률과 보장은 data/economy.json, 규칙은 scripts/rules/profile.gd.
## 진짜 돈 결제는 아직 없다. 보석은 미션·출석·레벨업·첫 승리로 모은다.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
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
	body.add_child(_exchange_panel())
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
