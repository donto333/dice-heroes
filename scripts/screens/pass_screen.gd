extends Control
## 시즌 패스 화면. 판을 하고 미션을 깨면 패스 경험치가 쌓이고, 레벨마다 보상이 있다.
## 왼쪽은 누구나 받는 무료 보상, 오른쪽은 유료 줄(아직 결제가 없어 잠겨 있고 무엇이 있는지만 보여 준다).

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const TopBar := preload("res://scripts/ui/top_bar.gd")

var app


func setup(main_app, _params: Dictionary) -> void:
	app = main_app
	var column := Kit.screen_frame(self, 16)
	move_child(Kit.backdrop(self, "ui/bg_missions", 0.5), 1)
	var top := TopBar.new()
	column.add_child(top)
	top.setup(app)
	var table: Dictionary = app.eco.get("pass", {})
	var levels: Array = table.get("levels", [])
	var level := Profile.pass_level(app.profile, app.eco)
	var per := int(table.get("exp_per_level", 100))

	var head := Kit.panel(Color("6a3fd0"), Kit.GOLD, 14)
	column.add_child(head)
	var head_column := Kit.vbox(6)
	head.add_child(head_column)
	var title_row := Kit.hbox(10)
	head_column.add_child(title_row)
	title_row.add_child(Kit.expand(Kit.label(str(table.get("name", "시즌 패스")), 32, Kit.GOLD)))
	title_row.add_child(Kit.label("패스 레벨 %d / %d" % [level, levels.size()], 24))
	head_column.add_child(Kit.bar(Profile.pass_progress(app.profile, app.eco), Kit.GOLD, 16))
	var gains: Dictionary = table.get("exp", {})
	head_column.add_child(Kit.para("레벨마다 경험치 %d  ·  승리 +%d, 패배 +%d, 미션 보상 +%d" % [per, int(gains.get("win", 0)), int(gains.get("lose", 0)), int(gains.get("mission", 0))], 18, Kit.MUTED))
	var waiting := Profile.pass_claimable_count(app.profile, app.eco)
	if waiting > 0:
		var all := Kit.button("보상 %d개 모두 받기" % waiting, Color("e8890c"), 26, 76)
		all.pressed.connect(_on_claim_all)
		head_column.add_child(all)

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
	column.add_child(Kit.para("프리미엄 패스는 아직 살 수 없어요. 정식 버전에서 열릴 예정이에요.", 17, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var back := Kit.button("로비로", Kit.PANEL_LIGHT, 26, 80)
	back.pressed.connect(_on_back)
	column.add_child(back)


func _level_row(number: int, entry: Dictionary, level: int) -> Control:
	var reached := number <= level
	var claimed := Profile.pass_claimed(app.profile, number)
	var row := Kit.hbox(8)
	var badge := Kit.label(str(number), 28, Kit.GOLD if reached else Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	badge.custom_minimum_size = Vector2(70, 0)
	row.add_child(badge)
	# 무료 보상: 도달했으면 받기 버튼
	var free_text := Kit.reward_line(entry.get("free", {}))
	var free := Kit.button("받음  %s" % free_text if claimed else ("받기  %s" % free_text if reached else free_text),
		Kit.PANEL_LIGHT if claimed or not reached else Color("2f8f4e"), 21, 66)
	free.disabled = claimed or not reached
	free.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45) if claimed else Color(1, 1, 1, 0.78))
	free.pressed.connect(_on_claim.bind(number))
	row.add_child(Kit.expand(free))
	# 프리미엄 보상: 보여 주기만 한다.
	var premium := Kit.button("잠김  %s" % Kit.reward_line(entry.get("premium", {})), Color("5a4a1c"), 21, 66)
	premium.disabled = true
	premium.add_theme_color_override("font_disabled_color", Color("fff1c2"))
	premium.add_theme_constant_override("outline_size", 0)
	premium.add_theme_stylebox_override("disabled", Kit.box(Color("8f7b3c"), Color("d9b85a"), 2, 16, 8))
	row.add_child(Kit.expand(premium))
	return row


func _on_claim(number: int) -> void:
	var reward := Profile.claim_pass(app.profile, app.eco, number)
	if reward.is_empty():
		return
	app.save()
	app.play("win")
	app.toast("패스 보상: %s" % Kit.reward_line(reward))
	app.go("pass")


func _on_claim_all() -> void:
	var total := Profile.claim_all_pass(app.profile, app.eco)
	if int(total["count"]) == 0:
		return
	app.save()
	app.play("win")
	app.toast("패스 보상 %d개: %s" % [int(total["count"]), Kit.reward_line({"gold": int(total["gold"]), "gems": int(total["gems"])})])
	app.go("pass")


func _on_back() -> void:
	app.play("click")
	app.go("lobby")
