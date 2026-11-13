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
	body.add_child(_attendance_panel())
	body.add_child(_missions_panel())
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
		var fill: Color = Kit.PANEL_LIGHT if now else (Color("14182f") if done else Color("232955"))
		var cell := Kit.label("%d일\n%s%s" % [day + 1, Kit.reward_line(table[day]).replace("  ", "\n"), "\n✓" if done else ""], 15,
			Kit.GOLD if now else (Kit.MUTED if done else Color.WHITE), HORIZONTAL_ALIGNMENT_CENTER)
		cell.custom_minimum_size = Vector2(0, 110)
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_theme_stylebox_override("normal", Kit.box(fill, Kit.GOLD if now else Kit.LINE, 3 if now else 1, 10, 4))
		row.add_child(Kit.expand(cell))
	var claim := Kit.button("오늘 출석 보상 받기" if can else "오늘 출석 완료 · 내일 또 오세요", Color("c4861c"), 24, 76)
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
	for mission in app.eco.get("missions", []):
		column.add_child(_mission_row(mission))
	var all_reward: Dictionary = app.eco.get("missions_all_clear", {})
	var all_done := Profile.all_missions_done(app.profile, app.eco)
	var all_claimed := bool(app.profile["daily"].get("all_claimed", false))
	var all_row := Kit.hbox(10)
	column.add_child(all_row)
	all_row.add_child(Kit.expand(Kit.para("모든 미션 완료 보너스  %s" % Kit.reward_line(all_reward), 22, Kit.GOLD)))
	var button := Kit.button("받음" if all_claimed else "받기", Color("c4861c"), 22, 64)
	button.custom_minimum_size = Vector2(130, 64)
	button.disabled = all_claimed or not all_done
	button.pressed.connect(_on_all_clear)
	all_row.add_child(button)
	return card


func _mission_row(mission: Dictionary) -> Control:
	var box := Kit.panel(Color("14182f"), Kit.LINE, 12)
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


func _on_tab(screen_name: String) -> void:
	if screen_name == "missions":
		return
	app.play("click")
	app.go(screen_name)
