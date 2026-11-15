extends Control
## 미션 화면: 7일 출석표와 오늘의 일일 미션. 다 깨면 모든 미션 완료 보상.
## 미션은 매일 자정(기기 날짜 기준)에 새로 시작한다.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const TopBar := preload("res://scripts/ui/top_bar.gd")
const BottomNav := preload("res://scripts/ui/bottom_nav.gd")

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
	var waiting := Profile.claimable_mission_count(app.profile, app.eco) + Profile.claimable_achievement_count(app.profile, app.data)
	if waiting > 0:
		var all := Kit.button("보상 %d개 모두 받기" % waiting, Color("e8890c"), 28, 84)
		all.pressed.connect(_on_claim_everything)
		body.add_child(all)
	if not Profile.guide_current(app.profile, app.data).is_empty():
		body.add_child(_guide_panel())
	body.add_child(_attendance_panel())
	body.add_child(_missions_panel())
	body.add_child(_achievements_panel())
	var nav := BottomNav.new()
	column.add_child(nav)
	nav.setup("missions", app.badges())
	nav.tab_pressed.connect(_on_tab)


func _attendance_panel() -> Control:
	var card := Kit.panel()
	var column := Kit.vbox(10)
	card.add_child(column)
	column.add_child(Kit.label("출석 보상", 30, Kit.GOLD))
	var table: Array = app.eco.get("attendance", [])
	var today_index := Profile.attendance_day(app.profile, app.eco)
	var can := Profile.can_check_in(app.profile, app.today())
	var row := Kit.hbox(6)
	column.add_child(row)
	for day in table.size():
		var done := day < today_index or (day == today_index and not can)
		var now := day == today_index and can
		var fill: Color = Kit.PANEL_LIGHT if now else (Color("13458f") if done else Kit.PANEL)
		var cell := Kit.label("%d일\n%s%s" % [day + 1, Kit.reward_line(table[day]).replace("  ", "\n"), "\n✓" if done else ""], 15,
			Kit.GOLD if now else (Kit.MUTED if done else Color.WHITE), HORIZONTAL_ALIGNMENT_CENTER)
		cell.custom_minimum_size = Vector2(0, 110)
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_theme_stylebox_override("normal", Kit.box(fill, Kit.GOLD if now else Kit.LINE, 3 if now else 1, 10, 4))
		row.add_child(Kit.expand(cell))
	var claim := Kit.button("오늘 출석 보상 받기" if can else "오늘 출석 완료 · 내일 또 오세요", Color("f39a1c"), 24, 76)
	claim.disabled = not can
	claim.pressed.connect(_on_check_in)
	column.add_child(claim)
	return card


func _missions_panel() -> Control:
	var card := Kit.panel()
	var column := Kit.vbox(10)
	card.add_child(column)
	column.add_child(Kit.label("오늘의 미션", 30, Kit.GOLD))
	column.add_child(Kit.label("매일 새로 바뀌어요.", 18, Kit.MUTED))
	for mission in Profile.active_missions(app.profile, app.eco):
		column.add_child(_mission_row(mission))
	var all_reward: Dictionary = app.eco.get("missions_all_clear", {})
	var all_done := Profile.all_missions_done(app.profile, app.eco)
	var all_claimed := bool(app.profile["daily"].get("all_claimed", false))
	var all_row := Kit.hbox(10)
	column.add_child(all_row)
	all_row.add_child(Kit.expand(Kit.para("모든 미션 완료 보너스  %s" % Kit.reward_line(all_reward), 22, Kit.GOLD)))
	var button := Kit.button("받음" if all_claimed else "받기", Color("f39a1c"), 22, 64)
	button.custom_minimum_size = Vector2(130, 64)
	button.disabled = all_claimed or not all_done
	button.pressed.connect(_on_all_clear)
	all_row.add_child(button)
	return card


## 업적: 받을 수 있는 것 → 진행 중 → 받은 것 순서로 보여 준다.
func _achievements_panel() -> Control:
	var card := Kit.panel()
	var column := Kit.vbox(10)
	card.add_child(column)
	var list: Array = app.data.get("achievements", {}).get("achievements", [])
	var claimed_count := 0
	for achievement in list:
		if Profile.achievement_claimed(app.profile, achievement):
			claimed_count += 1
	column.add_child(Kit.label("업적  %d / %d" % [claimed_count, list.size()], 30, Kit.GOLD))
	var ordered: Array = []
	for group in [0, 1, 2]:
		for achievement in list:
			var claimed := Profile.achievement_claimed(app.profile, achievement)
			var done := Profile.achievement_done(app.profile, app.data, achievement)
			var bucket: int = 2 if claimed else (0 if done else 1)
			if bucket == group:
				ordered.append(achievement)
	for achievement in ordered:
		column.add_child(_achievement_row(achievement))
	return card


## 초보자 길잡이: 순서대로 하나씩 하는 과제. 모두 끝내면 사라진다.
func _guide_panel() -> Control:
	var step: Dictionary = Profile.guide_current(app.profile, app.data)
	var total: int = (app.data.get("guide", {}).get("steps", []) as Array).size()
	var index := int(app.profile.get("guide_step", 0))
	var card := Kit.panel(Color("1e9a5a"), Color("b6ffd0"), 14)
	var column := Kit.vbox(8)
	card.add_child(column)
	column.add_child(Kit.label("길잡이 과제  %d / %d" % [index + 1, total], 30, Color("eaffef")))
	var row := Kit.hbox(10)
	column.add_child(row)
	var info := Kit.vbox(4)
	row.add_child(Kit.expand(info))
	var value: int = Profile.achievement_value(app.profile, app.data, str(step["stat"]))
	var goal := int(step["goal"])
	var done := value >= goal
	info.add_child(Kit.label(str(step["text"]), 23))
	var line := Kit.hbox(8)
	info.add_child(line)
	var bar := Kit.bar(float(min(value, goal)) / float(max(goal, 1)), Kit.GOLD if done else Color("6fd08c"), 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(Kit.expand(bar))
	line.add_child(Kit.label("%d/%d" % [min(value, goal), goal], 16, Kit.MUTED))
	info.add_child(Kit.label("보상 %s" % Kit.reward_line(step["reward"]), 16, Kit.GOLD))
	var button := Kit.button("받기" if done else "진행 중", Color("f39a1c") if done else Kit.PANEL_LIGHT, 20, 60)
	button.custom_minimum_size = Vector2(120, 60)
	button.disabled = not done
	button.pressed.connect(_on_guide)
	row.add_child(button)
	return card


func _on_guide() -> void:
	var reward := Profile.claim_guide(app.profile, app.data)
	if reward.is_empty():
		return
	app.save()
	app.play("win")
	app.toast("길잡이 보상: %s" % Kit.reward_line(reward))
	app.go("missions")


func _achievement_row(achievement: Dictionary) -> Control:
	var box := Kit.panel(Color("13458f"), Kit.LINE, 10)
	var row := Kit.hbox(10)
	box.add_child(row)
	var info := Kit.vbox(4)
	row.add_child(Kit.expand(info))
	var value: int = Profile.achievement_value(app.profile, app.data, str(achievement["stat"]))
	var goal := int(achievement["goal"])
	var claimed := Profile.achievement_claimed(app.profile, achievement)
	var done := value >= goal
	info.add_child(Kit.label(str(achievement["text"]), 21, Kit.MUTED if claimed else Color.WHITE))
	var line := Kit.hbox(8)
	info.add_child(line)
	var bar := Kit.bar(float(min(value, goal)) / float(max(goal, 1)), Kit.GOLD if done else Kit.ACCENT, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(Kit.expand(bar))
	line.add_child(Kit.label("%d/%d" % [min(value, goal), goal], 16, Kit.MUTED))
	info.add_child(Kit.label("보상 %s" % Kit.reward_line(achievement["reward"]), 16, Kit.GOLD))
	var button := Kit.button("받음" if claimed else ("받기" if done else "진행 중"), Color("f39a1c") if done and not claimed else Kit.PANEL_LIGHT, 20, 60)
	button.custom_minimum_size = Vector2(120, 60)
	button.disabled = claimed or not done
	button.pressed.connect(_on_achievement.bind(str(achievement["id"])))
	row.add_child(button)
	return box


func _on_achievement(id: String) -> void:
	var reward := Profile.claim_achievement(app.profile, app.data, id)
	if reward.is_empty():
		return
	app.save()
	app.play("win")
	app.toast("업적 보상: %s" % Kit.reward_line(reward))
	app.go("missions")


func _mission_row(mission: Dictionary) -> Control:
	var box := Kit.panel(Color("13458f"), Kit.LINE, 12)
	var row := Kit.hbox(10)
	box.add_child(row)
	var info := Kit.vbox(6)
	row.add_child(Kit.expand(info))
	var progress := Profile.mission_progress(app.profile, mission)
	var goal := int(mission["goal"])
	info.add_child(Kit.label(str(mission["text"]), 22))
	var line := Kit.hbox(8)
	info.add_child(line)
	var bar := Kit.bar(float(progress) / float(max(goal, 1)), Kit.GOOD, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(Kit.expand(bar))
	line.add_child(Kit.label("%d/%d" % [progress, goal], 18, Kit.MUTED))
	info.add_child(Kit.label("보상 %s" % Kit.reward_line(mission["reward"]), 18, Kit.GOLD))
	var claimed := Profile.mission_claimed(app.profile, mission)
	var done := Profile.mission_done(app.profile, mission)
	var button := Kit.button("받음" if claimed else ("받기" if done else "진행 중"), Kit.GOOD if done and not claimed else Kit.PANEL_LIGHT, 22, 64)
	button.custom_minimum_size = Vector2(130, 64)
	button.disabled = claimed or not done
	button.pressed.connect(_on_claim.bind(str(mission["id"])))
	row.add_child(button)
	return box


func _on_check_in() -> void:
	var reward := Profile.check_in(app.profile, app.eco, app.today())
	if reward.is_empty():
		return
	app.save()
	app.play("win")
	app.toast("출석 보상: %s" % Kit.reward_line(reward))
	app.go("missions")


func _on_claim(id: String) -> void:
	var reward := Profile.claim_mission(app.profile, app.eco, id)
	if reward.is_empty():
		return
	app.save()
	app.play("good")
	app.toast("미션 보상: %s" % Kit.reward_line(reward))
	app.go("missions")


func _on_all_clear() -> void:
	var reward := Profile.claim_all_clear(app.profile, app.eco)
	if reward.is_empty():
		return
	app.save()
	app.play("win")
	app.toast("모든 미션 완료! %s" % Kit.reward_line(reward))
	app.go("missions")


func _on_claim_everything() -> void:
	var total := Profile.claim_everything(app.profile, app.eco, app.data)
	if int(total["count"]) == 0:
		return
	app.save()
	app.play("win")
	app.toast("보상 %d개: %s" % [int(total["count"]), Kit.reward_line({"gold": int(total["gold"]), "gems": int(total["gems"])})])
	app.go("missions")


func _on_tab(screen_name: String) -> void:
	if screen_name == "missions":
		return
	app.play("click")
	app.go(screen_name)
