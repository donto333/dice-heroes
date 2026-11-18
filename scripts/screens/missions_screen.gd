extends Control
## 미션 화면: 오늘의 도전, 7일 출석표와 오늘의 일일 미션. 다 깨면 모든 미션 완료 보상.
## 미션은 매일 자정(기기 날짜 기준)에 새로 시작한다.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const TopBar := preload("res://scripts/ui/top_bar.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const BottomNav := preload("res://scripts/ui/bottom_nav.gd")

var app


## 미션 탭: 오늘(길잡이·출석·일일 미션) / 업적
var _tab := "today"


func setup(main_app, _params: Dictionary) -> void:
	app = main_app
	_tab = str(_params.get("tab", "today"))
	# 시안식 틀: 왼쪽 세로 판에 오늘·업적, 오른쪽 큰 금테 판.
	var ready_achievements: int = Profile.claimable_achievement_count(app.profile, app.data)
	var rail := [["today", "오늘 미션", "missions"], ["achievements", "업적%s" % (" (%d)" % ready_achievements if ready_achievements > 0 else ""), "trophy"]]
	var done_count := 0
	var mission_list: Array = Profile.active_missions(app.profile, app.eco)
	for mission in mission_list:
		if Profile.mission_done(app.profile, mission):
			done_count += 1
	var summary := MenuArt.summary("missions", "오늘 완료 %d / %d" % [done_count, mission_list.size()], "자정에 새로 시작")
	var column := MenuArt.frame(self, app, "ui/bg_missions", rail, _tab, _on_mission_tab, summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := Kit.vbox(14)
	Kit.expand(body)
	scroll.add_child(body)
	var waiting := Profile.claimable_mission_count(app.profile, app.eco) + Profile.claimable_achievement_count(app.profile, app.data)
	if waiting > 0:
		# 금색 큰 버튼, 양끝에 선물 상자
		var all := MenuArt.pill_button("보상 %d개 모두 받기" % waiting, "gold", "l")
		all.custom_minimum_size = Vector2(0, 76)
		all.add_theme_font_size_override("font_size", 28)
		all.pressed.connect(_on_claim_everything.bind(all))
		for side in [0, 1]:
			var gift: TextureRect = Kit.icon("m_gift", 54.0)
			gift.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT if side == 0 else Control.PRESET_CENTER_RIGHT)
			gift.offset_top = -27
			gift.offset_bottom = 27
			gift.offset_left = 40 if side == 0 else -94
			gift.offset_right = 94 if side == 0 else -40
			all.add_child(gift)
		Kit.shimmer(all)
		body.add_child(all)
	if _tab == "achievements":
		body.add_child(_achievements_panel())
	else:
		# 오늘의 도전(2026-11-18 사용자 결정: 로비 '오늘의 도전'을 미션에 합침)
		body.add_child(_challenge_panel())
		if not Profile.guide_current(app.profile, app.data).is_empty():
			body.add_child(_guide_panel())
		body.add_child(_attendance_panel())
		body.add_child(_missions_panel())


## 오늘의 도전: 하루 한 번, 상대 영웅이 나보다 조금 강하다. 이기면 보상(economy.json rewards.challenge).
func _challenge_panel() -> Control:
	var group := Kit.vbox(8)
	group.add_child(MenuArt.section("오늘의 도전", "attend", "하루 한 번 · 매일 상대와 맵이 바뀌어요"))
	var done := Profile.challenge_done(app.profile)
	var win: Dictionary = app.eco.get("rewards", {}).get("challenge", {}).get("win", {})
	var button := MenuArt.pill_button("오늘 완료" if done else "도전하기", "gray" if done else "gold", "m")
	button.custom_minimum_size = Vector2(170, 56)
	button.disabled = done
	button.pressed.connect(_on_challenge)
	var note := "상대 영웅 Lv.%d · 이기면 %s" % [Profile.challenge_level(app.profile, app.eco), Kit.reward_line({"gold": int(win.get("gold", 0)), "gems": int(win.get("gems", 0))})]
	if done:
		note = "오늘의 도전을 이겼어요! 내일 또 와요."
	MenuArt.list_row(group, "flag", "오늘의 도전", note, button)
	return group


func _on_challenge() -> void:
	app.play("click")
	app.start_mode("challenge")


func _on_mission_tab(id: String) -> void:
	if id == _tab:
		return
	app.play("tab")
	app.go("missions", {"tab": id})


func _attendance_panel() -> Control:
	var group := Kit.vbox(8)
	group.add_child(MenuArt.section("출석 보상", "attend", "7일 동안 매일 받아요"))
	var table: Array = app.eco.get("attendance", [])
	var today_index := Profile.attendance_day(app.profile, app.eco)
	var can := Profile.can_check_in(app.profile, app.today())
	var row := Kit.hbox(8)
	group.add_child(row)
	for day in table.size():
		var done := day < today_index or (day == today_index and not can)
		var now := day == today_index and can
		# 7칸 금테 칸: 오늘 칸은 금빛, 받은 칸은 어둡고 오른쪽 위에 작은 도장(MenuArt.day_cell)
		var cell: PanelContainer = MenuArt.day_cell(day + 1, Kit.reward_line(table[day]), now, done)
		cell.custom_minimum_size = Vector2(0, 118)
		row.add_child(Kit.expand(cell))
	var claim := MenuArt.pill_button("오늘 출석 보상 받기" if can else "오늘 출석 완료 · 내일 또 오세요", "gold" if can else "gray", "l")
	claim.disabled = not can
	claim.pressed.connect(_on_check_in.bind(claim))
	group.add_child(claim)
	return group


func _missions_panel() -> Control:
	var group := Kit.vbox(8)
	group.add_child(MenuArt.section("오늘의 미션", "missions", "매일 새로 바뀌어요"))
	for mission in Profile.active_missions(app.profile, app.eco):
		group.add_child(_mission_row(mission))
	var all_reward: Dictionary = app.eco.get("missions_all_clear", {})
	var all_done := Profile.all_missions_done(app.profile, app.eco)
	var all_claimed := bool(app.profile["daily"].get("all_claimed", false))
	var button := MenuArt.pill_button("받음" if all_claimed else "받기", "gold" if all_done and not all_claimed else "gray", "m")
	button.custom_minimum_size = Vector2(130, 56)
	button.disabled = all_claimed or not all_done
	button.pressed.connect(_on_all_clear.bind(button))
	var words := MenuArt.list_row(group, "m_gift", "모든 미션 완료 보너스", "", _reward_and(all_reward, button))
	words.get_child(0).add_theme_color_override("font_color", Kit.GOLD)
	return group


## 보상 캡슐 + 버튼을 한 줄로(목록 줄 오른쪽에 붙인다).
func _reward_and(reward: Dictionary, button: Button) -> HBoxContainer:
	var side := Kit.hbox(8)
	side.add_child(MenuArt.reward_capsules(reward))
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	side.add_child(button)
	return side


## 업적: 받을 수 있는 것 → 진행 중 → 받은 것 순서로 보여 준다.
func _achievements_panel() -> Control:
	var group := Kit.vbox(8)
	var list: Array = app.data.get("achievements", {}).get("achievements", [])
	var claimed_count := 0
	for achievement in list:
		if Profile.achievement_claimed(app.profile, achievement):
			claimed_count += 1
	group.add_child(MenuArt.section("업적  %d / %d" % [claimed_count, list.size()], "trophy", "이루면 한 번씩 큰 보상"))
	# 맨 위 달성도 막대
	var rate := MenuArt.row(10)
	group.add_child(rate)
	var rate_line := Kit.hbox(10)
	rate.add_child(rate_line)
	rate_line.add_child(Kit.label("달성도", 20, Color.WHITE))
	var bar := Kit.bar(float(claimed_count) / float(maxi(list.size(), 1)), Kit.GOLD, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rate_line.add_child(Kit.expand(bar))
	rate_line.add_child(Kit.label("%d%%" % int(100.0 * claimed_count / maxi(list.size(), 1)), 20, Kit.GOLD))
	var ordered: Array = []
	for bucket_index in [0, 1, 2]:
		for achievement in list:
			var claimed := Profile.achievement_claimed(app.profile, achievement)
			var done := Profile.achievement_done(app.profile, app.data, achievement)
			var bucket: int = 2 if claimed else (0 if done else 1)
			if bucket == bucket_index:
				ordered.append(achievement)
	for achievement in ordered:
		group.add_child(_achievement_row(achievement))
	return group


## 초보자 길잡이: 순서대로 하나씩 하는 과제. 모두 끝내면 사라진다.
func _guide_panel() -> Control:
	var step: Dictionary = Profile.guide_current(app.profile, app.data)
	var total: int = (app.data.get("guide", {}).get("steps", []) as Array).size()
	var index := int(app.profile.get("guide_step", 0))
	var group := Kit.vbox(8)
	group.add_child(MenuArt.section("길잡이 과제  %d / %d" % [index + 1, total], "flag", "차례대로 하나씩"))
	var value: int = Profile.achievement_value(app.profile, app.data, str(step["stat"]))
	var goal := int(step["goal"])
	var done := value >= goal
	var button := MenuArt.pill_button("받기" if done else "진행 중", "gold" if done else "gray", "m")
	button.custom_minimum_size = Vector2(120, 56)
	button.disabled = not done
	button.pressed.connect(_on_guide.bind(button))
	var words := MenuArt.list_row(group, "m_castle", str(step["text"]), "", _reward_and(step["reward"], button))
	words.add_child(_progress(value, goal, done))
	return group


## 진행 막대 + 숫자 한 줄
func _progress(value: int, goal: int, done: bool) -> HBoxContainer:
	var line := Kit.hbox(8)
	var bar := Kit.bar(float(min(value, goal)) / float(max(goal, 1)), Kit.GOLD if done else Kit.GOOD, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(Kit.expand(bar))
	line.add_child(Kit.label("%d/%d" % [min(value, goal), goal], 18, Kit.MUTED))
	return line


func _on_guide(from: Control = null) -> void:
	var reward := Profile.claim_guide(app.profile, app.data)
	if reward.is_empty():
		return
	app.save()
	app.play("reward")
	app.toast("길잡이 보상: %s" % Kit.reward_line(reward))
	MenuArt.fly_reward(app, from, reward)
	app.go("missions", {"tab": _tab})


func _achievement_row(achievement: Dictionary) -> Control:
	var holder := Kit.vbox(0)
	var value: int = Profile.achievement_value(app.profile, app.data, str(achievement["stat"]))
	var goal := int(achievement["goal"])
	var claimed := Profile.achievement_claimed(app.profile, achievement)
	var done := value >= goal
	var button := MenuArt.pill_button("받음" if claimed else ("받기" if done else "진행 중"), "gold" if done and not claimed else "gray", "m")
	button.custom_minimum_size = Vector2(120, 56)
	button.disabled = claimed or not done
	button.pressed.connect(_on_achievement.bind(str(achievement["id"]), button))
	var words := MenuArt.list_row(holder, _achievement_icon(str(achievement["stat"])), str(achievement["text"]), "", _reward_and(achievement["reward"], button), claimed)
	words.add_child(_progress(value, goal, done))
	return holder


## 업적 종류(stat)별 메달 아이콘(assets/ui_icons/ach_*.png, GPT 그림 활용 기획 4단계). 그림이 없으면 트로피.
const ACHIEVEMENT_ICONS := {
	"wins": "ach_wins", "adventure_stars": "ach_adventure", "battle_wins_total": "ach_battle",
	"owned": "ach_heroes", "chapters_cleared": "ach_chapter", "best_trophies": "ach_trophy",
	"rank_wins": "ach_rank", "cards_total": "ach_cards", "summons_total": "ach_summon",
	"level": "ach_level", "gates_total": "ach_gate", "upgrades_total": "ach_upgrade",
	"max_level_heroes": "ach_upgrade",
}


func _achievement_icon(stat: String) -> String:
	var name := str(ACHIEVEMENT_ICONS.get(stat, "trophy"))
	return name if ResourceLoader.exists("res://assets/ui_icons/%s.png" % name) else "trophy"


func _on_achievement(id: String, from: Control = null) -> void:
	var reward := Profile.claim_achievement(app.profile, app.data, id)
	if reward.is_empty():
		return
	app.save()
	app.play("reward")
	app.toast("업적 보상: %s" % Kit.reward_line(reward))
	MenuArt.fly_reward(app, from, reward)
	app.go("missions", {"tab": _tab})


func _mission_row(mission: Dictionary) -> Control:
	var holder := Kit.vbox(0)
	var progress := Profile.mission_progress(app.profile, mission)
	var goal := int(mission["goal"])
	var claimed := Profile.mission_claimed(app.profile, mission)
	var done := Profile.mission_done(app.profile, mission)
	var button := MenuArt.pill_button("받음" if claimed else ("받기" if done else "진행 중"), "gold" if done and not claimed else "gray", "m")
	button.custom_minimum_size = Vector2(120, 56)
	button.disabled = claimed or not done
	button.pressed.connect(_on_claim.bind(str(mission["id"]), button))
	var words := MenuArt.list_row(holder, "check" if done else "missions", str(mission["text"]), "", _reward_and(mission["reward"], button), claimed)
	words.add_child(_progress(progress, goal, done))
	return holder


func _on_check_in(from: Control = null) -> void:
	var reward := Profile.check_in(app.profile, app.eco, app.today())
	if reward.is_empty():
		return
	app.save()
	app.play("stamp")
	app.toast("출석 보상: %s" % Kit.reward_line(reward))
	MenuArt.fly_reward(app, from, reward)
	app.go("missions", {"tab": _tab})


func _on_claim(id: String, from: Control = null) -> void:
	var reward := Profile.claim_mission(app.profile, app.eco, id)
	if reward.is_empty():
		return
	app.save()
	app.play("good")
	app.toast("미션 보상: %s" % Kit.reward_line(reward))
	MenuArt.fly_reward(app, from, reward)
	app.go("missions", {"tab": _tab})


func _on_all_clear(from: Control = null) -> void:
	var reward := Profile.claim_all_clear(app.profile, app.eco)
	if reward.is_empty():
		return
	app.save()
	app.play("reward")
	app.toast("모든 미션 완료! %s" % Kit.reward_line(reward))
	MenuArt.fly_reward(app, from, reward)
	app.go("missions", {"tab": _tab})


func _on_claim_everything(from: Control = null) -> void:
	var total := Profile.claim_everything(app.profile, app.eco, app.data)
	if int(total["count"]) == 0:
		return
	app.save()
	app.play("reward")
	app.toast("보상 %d개: %s" % [int(total["count"]), Kit.reward_line({"gold": int(total["gold"]), "gems": int(total["gems"])})])
	MenuArt.fly_reward(app, from, {"gold": int(total["gold"]), "gems": int(total["gems"])})
	app.go("missions", {"tab": _tab})


func _on_tab(screen_name: String) -> void:
	if screen_name == "missions":
		return
	app.play("click")
	app.go(screen_name)
