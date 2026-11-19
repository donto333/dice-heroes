extends Node
## 시즌 패스 판(2026-11-18 사용자 결정: 로비 타일 대신 상점 안의 '시즌 패스' 메뉴). 상점 화면에 붙여 build(app, 큰 판)으로 그린다. 판을 하고 미션을 깨면 패스 경험치가 쌓이고, 레벨마다 보상이 있다.
## 왼쪽은 누구나 받는 무료 보상, 오른쪽은 유료 줄(아직 결제가 없어 잠겨 있고 무엇이 있는지만 보여 준다).

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")

var app


func build(main_app, column: VBoxContainer) -> void:
	app = main_app
	var table: Dictionary = app.eco.get("pass", {})
	var levels: Array = table.get("levels", [])
	var level := Profile.pass_level(app.profile, app.eco)
	var per := int(table.get("exp_per_level", 100))

	# 위: 시즌 이름 + 패스 레벨 막대 + 보상 모두 받기
	var head := MenuArt.row(12)
	column.add_child(head)
	var head_column := Kit.vbox(6)
	head.add_child(head_column)
	var title_row := Kit.hbox(10)
	head_column.add_child(title_row)
	title_row.add_child(Kit.icon("pass", 48.0))
	title_row.add_child(Kit.expand(Kit.label(str(table.get("name", "시즌 패스")), 30, Kit.GOLD)))
	title_row.add_child(MenuArt.capsule("패스 레벨 %d / %d" % [level, levels.size()], "star", 20))
	var waiting := Profile.pass_claimable_count(app.profile, app.eco)
	if waiting > 0:
		var all := MenuArt.pill_button("보상 %d개 모두 받기" % waiting, "gold", "m")
		all.custom_minimum_size = Vector2(240, 56)
		all.pressed.connect(_on_claim_all.bind(all))
		Kit.shimmer(all)
		title_row.add_child(all)
	head_column.add_child(Kit.bar(Profile.pass_progress(app.profile, app.eco), Kit.GOLD, 16))
	var gains: Dictionary = table.get("exp", {})
	head_column.add_child(Kit.para("레벨마다 경험치 %d  ·  승리 +%d, 패배 +%d, 미션 보상 +%d" % [per, int(gains.get("win", 0)), int(gains.get("lose", 0)), int(gains.get("mission", 0))], 18, Kit.MUTED))

	var names := Kit.hbox(8)
	column.add_child(names)
	var level_head := Kit.label("레벨", 18, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	level_head.custom_minimum_size = Vector2(70, 0)
	names.add_child(level_head)
	names.add_child(Kit.expand(Kit.label("무료 보상", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)))
	names.add_child(Kit.expand(Kit.label("프리미엄 (준비 중)", 20, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := Kit.vbox(8)
	Kit.expand(body)
	scroll.add_child(body)
	for index in levels.size():
		body.add_child(_level_row(index + 1, levels[index], level))
	# 프리미엄 패스 혜택 설명(배수는 economy.json pass.premium_reward_scale)
	var scale := maxi(1, int(table.get("premium_reward_scale", 1)))
	column.add_child(Kit.para("프리미엄 패스 혜택: 오른쪽 줄 보상을 모두 받고, 판이 끝날 때 골드·경험치를 광고 없이 %d배로 받아요." % scale, 18, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	if Profile.pass_premium(app.profile):
		column.add_child(Kit.para("프리미엄 패스를 사용 중이에요.", 17, Kit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		column.add_child(Kit.para("프리미엄 패스는 아직 살 수 없어요. 정식 버전에서 열릴 예정이에요.", 17, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))


func _level_row(number: int, entry: Dictionary, level: int) -> Control:
	var reached := number <= level
	var claimed := Profile.pass_claimed(app.profile, number)
	var row := Kit.hbox(8)
	var badge := Kit.label(str(number), 28, Kit.GOLD if reached else Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	badge.custom_minimum_size = Vector2(70, 0)
	row.add_child(badge)
	# 무료 보상: 도달했으면 받기 버튼(알약)
	var free_text := Kit.reward_line(entry.get("free", {}))
	var free := MenuArt.pill_button("받음  %s" % free_text if claimed else ("받기  %s" % free_text if reached else free_text),
		"gold" if reached and not claimed else "blue", "m")
	free.custom_minimum_size = Vector2(0, 60)
	free.disabled = claimed or not reached
	free.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6) if claimed else Color(1, 1, 1, 0.9))
	free.pressed.connect(_on_claim.bind(number, free))
	row.add_child(Kit.expand(free))
	# 프리미엄 보상: 회색 금테 줄 + 자물쇠 + 준비 중(보여 주기만)
	row.add_child(Kit.expand(MenuArt.locked_row(Kit.reward_line(entry.get("premium", {})), "준비 중", 60.0)))
	return row


func _on_claim(number: int, from: Control = null) -> void:
	var reward := Profile.claim_pass(app.profile, app.eco, number)
	if reward.is_empty():
		return
	app.save()
	app.play("reward")
	app.toast("패스 보상: %s" % Kit.reward_line(reward))
	MenuArt.fly_reward(app, from, reward)
	app.go("shop", {"tab": "pass"})


func _on_claim_all(from: Control = null) -> void:
	var total := Profile.claim_all_pass(app.profile, app.eco)
	if int(total["count"]) == 0:
		return
	app.save()
	app.play("reward")
	app.toast("패스 보상 %d개: %s" % [int(total["count"]), Kit.reward_line({"gold": int(total["gold"]), "gems": int(total["gems"])})])
	MenuArt.fly_reward(app, from, {"gold": int(total["gold"]), "gems": int(total["gems"])})
	app.go("shop", {"tab": "pass"})
