extends Control
## 모험 모드: 8장 × 스테이지 3개. 장마다 맵 하나와 적 파티가 정해져 있다.
## 스테이지는 앞 스테이지를 깨야 열리고, 이기면 별(최대 3개)과 첫 클리어 보상을 받는다.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const TopBar := preload("res://scripts/ui/top_bar.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const MapPreview := preload("res://scripts/ui/map_preview.gd")
const ArtView := preload("res://scripts/ui/art_view.gd")

var app


var _chapter := ""


func setup(main_app, _params: Dictionary) -> void:
	app = main_app
	var adventure: Dictionary = app.data.get("adventure", {})
	var chapters: Array = adventure.get("chapters", [])
	# 고른 장: 받은 값이 없으면 열린 장 중 아직 별을 다 못 모은 첫 장(없으면 마지막으로 열린 장).
	_chapter = str(_params.get("chapter", ""))
	if _chapter == "":
		for chapter in chapters:
			if not _chapter_open(chapter, adventure):
				break
			_chapter = str(chapter["id"])
			if _chapter_stars(chapter) < chapter["stages"].size() * 3:
				break
	if _chapter == "" and not chapters.is_empty():
		_chapter = str(chapters[0]["id"])
	# 시안식 틀: 왼쪽 세로 판에 장 목록(깬 장은 별, 잠긴 장은 자물쇠), 오른쪽 큰 판에는 고른 장만.
	var rail: Array = []
	for chapter in chapters:
		var open := _chapter_open(chapter, adventure)
		var icon_name := "m_lock" if not open else ("star" if _chapter_stars(chapter) > 0 else "m_castle")
		rail.append([str(chapter["id"]), str(chapter["name"]), icon_name])
	var column := MenuArt.frame(self, app, "ui/bg_adventure", rail, _chapter, _on_chapter)
	var stage_count := Profile.all_stages(adventure).size()
	var header := Kit.hbox(10)
	column.add_child(header)
	header.add_child(Kit.expand(Kit.label("장을 골라 스테이지에 도전하세요", 20, Color.WHITE)))
	header.add_child(MenuArt.capsule("%d / %d" % [Profile.total_stars(app.profile), stage_count * 3], "star", 20))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := Kit.vbox(12)
	Kit.expand(body)
	scroll.add_child(body)
	for chapter in chapters:
		if str(chapter["id"]) == _chapter:
			body.add_child(_chapter_card(chapter, adventure))


func _chapter_open(chapter: Dictionary, adventure: Dictionary) -> bool:
	return Profile.stage_unlocked(app.profile, adventure, str(chapter["stages"][0]["id"]))


func _chapter_stars(chapter: Dictionary) -> int:
	var total := 0
	for stage in chapter["stages"]:
		total += Profile.stage_stars(app.profile, str(stage["id"]))
	return total


func _on_chapter(id: String) -> void:
	if id == _chapter:
		return
	app.play("tab")
	app.go("adventure", {"chapter": id})


func _chapter_card(chapter: Dictionary, adventure: Dictionary) -> Control:
	var board: Dictionary = app.data["boards"][int(chapter["map"])]
	var open := _chapter_open(chapter, adventure)
	var column := Kit.vbox(10)
	# 장 그림 띠(assets/art/chapters/<장 id>.jpg). 잠긴 장은 어둡게.
	var cover := _cover(str(chapter["id"]), 200.0)
	if cover != null:
		cover.modulate = Color.WHITE if open else Color(0.35, 0.35, 0.42)
		column.add_child(cover)
	var line := MenuArt.row(12)
	column.add_child(line)
	var head := Kit.hbox(14)
	line.add_child(head)
	var preview := MapPreview.new()
	preview.custom_minimum_size = Vector2(180, 116)
	preview.show_board(board)
	preview.modulate = Color.WHITE if open else Color(0.4, 0.4, 0.45)
	head.add_child(preview)
	var info := Kit.vbox(4)
	head.add_child(Kit.expand(info))
	var title_row := Kit.hbox(8)
	info.add_child(title_row)
	title_row.add_child(Kit.expand(Kit.label(str(chapter["name"]), 30, Kit.GOLD if open else Kit.MUTED)))
	title_row.add_child(MenuArt.capsule("%d / %d" % [_chapter_stars(chapter), chapter["stages"].size() * 3], "star", 18))
	info.add_child(Kit.label("%s · 수호자 %s" % [board.get("shape", ""), _goal_name(board)], 20, Color.WHITE if open else Kit.MUTED))
	info.add_child(Kit.para(str(chapter["intro"]) if open else "앞 장을 끝내면 열려요.", 18, Kit.MUTED))
	var stages := Kit.hbox(10)
	column.add_child(stages)
	var next_found := false
	for stage in chapter["stages"]:
		var id := str(stage["id"])
		var is_next := not next_found and Profile.stage_unlocked(app.profile, adventure, id) and Profile.stage_stars(app.profile, id) == 0
		if is_next:
			next_found = true
		stages.add_child(Kit.expand(_stage_button(stage, adventure, is_next)))
	return column


## 스테이지 버튼: 깬 것 초록 + 별, 다음 것 금색, 잠긴 것 회색 + 자물쇠.
func _stage_button(stage: Dictionary, adventure: Dictionary, is_next: bool) -> Button:
	var id := str(stage["id"])
	var unlocked := Profile.stage_unlocked(app.profile, adventure, id)
	var stars := Profile.stage_stars(app.profile, id)
	var star_text := "★".repeat(stars) + "☆".repeat(3 - stars)
	var label := "%s%s  %s\n%s" % [id, "  보스" if bool(stage.get("boss", false)) else "", stage["name"], star_text if unlocked else "잠김"]
	var color_name := "gray"
	if unlocked:
		color_name = "gold" if is_next else ("green" if stars > 0 else "blue")
	var button := MenuArt.pill_button(label, color_name, "l")
	button.custom_minimum_size = Vector2(0, 104)
	button.add_theme_font_size_override("font_size", 22)
	button.disabled = not unlocked
	if not unlocked:
		var lock: TextureRect = Kit.icon("m_lock", 30.0)
		button.icon = lock.texture
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 30)
	button.pressed.connect(_on_stage.bind(id))
	if is_next:
		Kit.shimmer(button)
	return button


## 장 표지 그림 칸. 그림이 없으면 null.
func _cover(chapter_id: String, height: float) -> Control:
	var view := ArtView.new()
	view.show_art("chapters/" + chapter_id)
	if not view.has_art():
		view.free()
		return null
	view.custom_minimum_size = Vector2(0, height)
	view.focus_y = 0.5
	return view


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
	var cover := _cover(str(found.get("chapter", {}).get("id", "")), 190.0)
	if cover != null:
		body.add_child(cover)
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
		elif Profile.sweep_buys_left(app.profile, app.eco) > 0:
			buttons.append(["소탕 +1 (보석 %d)" % int(app.eco["sweep"]["extra_cost_gems"]), Color("8a55e0"), _buy_sweep.bind(id)])
	buttons.append(["닫기", Kit.PANEL_LIGHT])
	MenuArt.skin_buttons(app.dialog("", body, buttons, 660))


## 보석으로 소탕 횟수를 하나 사고 바로 소탕한다.
func _buy_sweep(id: String) -> void:
	if not Profile.buy_sweep(app.profile, app.eco):
		app.play("denied")
		app.toast("보석이 모자라요.")
		return
	_sweep(id)


func _sweep(id: String) -> void:
	var reward := Profile.sweep(app.profile, app.eco, id, {
		"event_gold_scale": Profile.event_scale(app.data.get("events", {}), app.today(), "match_gold_scale"),
		"event_pass_scale": Profile.event_scale(app.data.get("events", {}), app.today(), "pass_exp_scale")})
	if reward.is_empty():
		app.toast("지금은 소탕할 수 없어요.")
		return
	app.save()
	app.play("reward")
	MenuArt.fly_reward(app, null, reward)
	app.go("adventure", {"chapter": _chapter})
	app.toast("소탕 완료: %s · 경험치 +%d" % [Kit.reward_line(reward), int(reward["exp"])])


func _start_stage(id: String) -> void:
	app.start_mode("adventure", {"stage": id})
