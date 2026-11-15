extends Control
## 모험 모드: 8장 × 스테이지 3개. 장마다 맵 하나와 적 파티가 정해져 있다.
## 스테이지는 앞 스테이지를 깨야 열리고, 이기면 별(최대 3개)과 첫 클리어 보상을 받는다.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const TopBar := preload("res://scripts/ui/top_bar.gd")
const MapPreview := preload("res://scripts/ui/map_preview.gd")

var app


func setup(main_app, _params: Dictionary) -> void:
	app = main_app
	var column := Kit.screen_frame(self, 16)
	var top := TopBar.new()
	column.add_child(top)
	top.setup(app)
	var adventure: Dictionary = app.data.get("adventure", {})
	var stage_count := Profile.all_stages(adventure).size()
	var header := Kit.hbox(10)
	column.add_child(header)
	header.add_child(Kit.expand(Kit.title("모험", 44)))
	header.add_child(Kit.label("★ %d / %d" % [Profile.total_stars(app.profile), stage_count * 3], 28, Kit.GOLD))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := Kit.vbox(14)
	Kit.expand(body)
	scroll.add_child(body)
	for chapter in adventure.get("chapters", []):
		body.add_child(_chapter_card(chapter, adventure))

	var back := Kit.button("로비로", Kit.PANEL_LIGHT, 26, 80)
	back.pressed.connect(func(): app.go("lobby"))
	column.add_child(back)


func _chapter_card(chapter: Dictionary, adventure: Dictionary) -> Control:
	var board: Dictionary = app.data["boards"][int(chapter["map"])]
	var theme_color := Color(str(board.get("theme", {}).get("bg", "1d2246")))
	var first_stage := str(chapter["stages"][0]["id"])
	var open := Profile.stage_unlocked(app.profile, adventure, first_stage)
	var card := Kit.panel(theme_color.darkened(0.05) if open else Color("13458f"), theme_color.lightened(0.3) if open else Kit.LINE, 14)
	var column := Kit.vbox(10)
	card.add_child(column)
	var head := Kit.hbox(12)
	column.add_child(head)
	var preview := MapPreview.new()
	preview.custom_minimum_size = Vector2(170, 110)
	preview.show_board(board)
	preview.modulate = Color.WHITE if open else Color(0.4, 0.4, 0.45)
	head.add_child(preview)
	var info := Kit.vbox(4)
	head.add_child(Kit.expand(info))
	info.add_child(Kit.label(str(chapter["name"]), 30, Kit.GOLD if open else Kit.MUTED))
	info.add_child(Kit.label("%s · 수호자 %s" % [board.get("shape", ""), _goal_name(board)], 18, Color.WHITE if open else Kit.MUTED))
	info.add_child(Kit.para(str(chapter["intro"]) if open else "앞 장을 끝내면 열려요.", 18, Kit.MUTED))
	var stages := Kit.hbox(8)
	column.add_child(stages)
	for stage in chapter["stages"]:
		stages.add_child(Kit.expand(_stage_button(stage, adventure)))
	return card


func _stage_button(stage: Dictionary, adventure: Dictionary) -> Button:
	var id := str(stage["id"])
	var unlocked := Profile.stage_unlocked(app.profile, adventure, id)
	var stars := Profile.stage_stars(app.profile, id)
	var star_text := "★".repeat(stars) + "☆".repeat(3 - stars)
	var label := "%s%s\n%s\n%s" % [id, "  보스" if bool(stage.get("boss", false)) else "", stage["name"], star_text if unlocked else "잠김"]
	var color: Color = Color("8a2b2b") if bool(stage.get("boss", false)) else Kit.ACCENT
	var button := Kit.button(label, color if unlocked else Kit.DISABLED, 18, 110)
	button.disabled = not unlocked
	button.pressed.connect(_on_stage.bind(id))
	return button


func _goal_name(board: Dictionary) -> String:
	for node in board.get("nodes", []):
		if node.get("type", "") == "goal":
			return str(node.get("name", "수호자"))
	return "수호자"


func _on_stage(id: String) -> void:
	app.play("click")
	var adventure: Dictionary = app.data.get("adventure", {})
	var found := Profile.find_stage(adventure, id)
	var stage: Dictionary = found["stage"]
	var body := Kit.vbox(12)
	body.add_child(Kit.label("%s  %s" % [id, stage["name"]], 30, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	if str(stage.get("story", "")) != "":
		body.add_child(Kit.para(str(stage["story"]), 20, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER))
	var faces := Kit.hbox(8)
	body.add_child(faces)
	for slot in ["attack", "defense", "support"]:
		var character: Dictionary = app.character(str(stage["enemy"][slot]))
		var cell := Kit.vbox(4)
		var face := Portrait.new()
		face.custom_minimum_size = Vector2(0, 150)
		face.show_character(character, Kit.CATEGORY_COLORS.get(character.get("category", ""), Kit.LINE))
		cell.add_child(face)
		cell.add_child(Kit.label("%s Lv.%d" % [character.get("name", ""), int(stage["ai_level"])], 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		faces.add_child(Kit.expand(cell))
	var turns := int(adventure.get("star_rules", {}).get("turns", 24))
	body.add_child(Kit.para("별 조건  ★ 이기기  ★ %d턴 안에 이기기  ★ 전투에서 한 번도 지지 않기" % turns, 20, Color.WHITE))
	var reward: Dictionary = stage.get("reward", {})
	var cleared := Profile.stage_stars(app.profile, id) > 0
	body.add_child(Kit.para("첫 클리어 보상  %s%s  ·  처음 별 3개 보석 %d" % [Kit.reward_line(reward), "  (받음)" if cleared else "", int(adventure.get("three_star_gems", 0))], 20, Kit.GOLD))
	var buttons: Array = [["출전", Color("f39a1c"), _start_stage.bind(id)]]
	# 별 3개로 깬 곳은 대전 없이 보상만 받을 수 있다(하루 횟수 제한).
	if Profile.stage_stars(app.profile, id) >= 3:
		var left := Profile.sweeps_left(app.profile, app.eco)
		body.add_child(Kit.para("소탕: 별 3개로 깬 곳은 대전 없이 승리 보상을 받아요. 오늘 %d번 남았어요." % left, 18, Kit.MUTED))
		if left > 0:
			buttons.append(["소탕 (%d)" % left, Color("27a35a"), _sweep.bind(id)])
	buttons.append(["닫기", Kit.PANEL_LIGHT])
	app.dialog("", body, buttons, 660)


func _sweep(id: String) -> void:
	var reward := Profile.sweep(app.profile, app.eco, id, {
		"event_gold_scale": Profile.event_scale(app.data.get("events", {}), app.today(), "match_gold_scale"),
		"event_pass_scale": Profile.event_scale(app.data.get("events", {}), app.today(), "pass_exp_scale")})
	if reward.is_empty():
		app.toast("지금은 소탕할 수 없어요.")
		return
	app.save()
	app.play("win")
	app.go("adventure")
	app.toast("소탕 완료: %s · 경험치 +%d" % [Kit.reward_line(reward), int(reward["exp"])])


func _start_stage(id: String) -> void:
	app.go("party", {"purpose": "match", "mode": "adventure", "stage": id})
