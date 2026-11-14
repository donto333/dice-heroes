extends RefCounted
## 프로필 창과 연습 리그 순위표의 내용을 만든다. (창 자체는 app.dialog가 띄운다)

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")


## 내 프로필: 대표 영웅, 티어, 전적, 수집, 가장 많이 쓴 영웅.
static func profile_body(app) -> Control:
	var profile: Dictionary = app.profile
	var body := Kit.vbox(12)
	var head := Kit.hbox(16)
	body.add_child(head)
	var leader_id := str(profile.get("avatar", ""))
	if leader_id == "" or not Profile.owns(profile, leader_id):
		leader_id = str(profile["party"].get("attack", ""))
	var face := Portrait.new()
	face.custom_minimum_size = Vector2(170, 170)
	face.border = Kit.GOLD
	face.border_width = 4.0
	face.show_character(app.character(leader_id), Kit.LINE)
	head.add_child(face)
	var tier: Dictionary = Profile.tier_of(app.eco, int(profile["trophies"]))
	var info := Kit.vbox(4)
	head.add_child(Kit.expand(info))
	info.add_child(Kit.label(str(profile["nickname"]), 36))
	info.add_child(Kit.label("플레이어 레벨 %d" % int(profile["level"]), 22, Kit.GOLD))
	info.add_child(Kit.label("%s  ·  트로피 %d" % [tier["name"], int(profile["trophies"])], 24, Color(str(tier.get("color", "ffffff")))))
	info.add_child(Kit.label("연습 리그 %d위" % Profile.league_rank(profile, app.eco), 20, Kit.MUTED))

	var stats: Dictionary = profile["stats"]
	var played := int(stats["played"])
	var rate := int(100.0 * int(stats["wins"]) / played) if played > 0 else 0
	var achievements: Array = app.data.get("achievements", {}).get("achievements", [])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for pair in [
		["전적", "%d판 %d승 %d패" % [played, int(stats["wins"]), int(stats["losses"])]],
		["승률", "%d%%" % rate],
		["랭크전 승리", "%d번" % int(stats["rank_wins"])],
		["최고 트로피", str(int(profile["best_trophies"]))],
		["영웅", "%d / %d명" % [profile["owned"].size(), app.data["characters"].size()]],
		["모험 별", "★ %d" % Profile.total_stars(profile)],
		["전투 승리", "%d번" % int(stats.get("battle_wins_total", 0))],
		["업적", "%d / %d" % [profile.get("achievements", []).size(), achievements.size()]],
	]:
		var cell := Kit.panel(Color("14182f"), Kit.LINE, 10)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var column := Kit.vbox(2)
		cell.add_child(column)
		column.add_child(Kit.label(pair[0], 17, Kit.MUTED))
		column.add_child(Kit.label(pair[1], 24))
		grid.add_child(cell)

	var favorite := Profile.favorite_hero(profile)
	if favorite != "":
		var record: Dictionary = Profile.hero_record(profile, favorite)
		var row := Kit.hbox(12)
		body.add_child(row)
		var small := Portrait.new()
		small.custom_minimum_size = Vector2(84, 84)
		small.show_character(app.character(favorite), Kit.LINE)
		row.add_child(small)
		row.add_child(Kit.expand(Kit.para("가장 많이 함께한 영웅\n%s  ·  %d판 %d승" % [app.character(favorite).get("name", ""), int(record["played"]), int(record["wins"])], 22, Color.WHITE)))
	return body


## 연습 리그 순위표. 내 줄은 금색으로.
static func league_body(app) -> Control:
	var body := Kit.vbox(8)
	body.add_child(Kit.para("온라인 대전이 열리기 전까지는 AI 상대들과 겨루는 연습 리그예요. 랭크전에서 트로피를 모아 순위를 올려 보세요.", 18, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 620)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list := Kit.vbox(6)
	Kit.expand(list)
	scroll.add_child(list)
	var rows := Profile.league_table(app.profile, app.eco)
	for index in rows.size():
		var entry: Dictionary = rows[index]
		var mine := bool(entry["me"])
		var tier: Dictionary = Profile.tier_of(app.eco, int(entry["trophies"]))
		var line := Kit.panel(Color("3a2f0c") if mine else Color("14182f"), Kit.GOLD if mine else Kit.LINE, 10)
		var row := Kit.hbox(10)
		line.add_child(row)
		var rank := Kit.label("%d" % (index + 1), 26, Kit.GOLD if index < 3 else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		rank.custom_minimum_size = Vector2(56, 0)
		row.add_child(rank)
		row.add_child(Kit.expand(Kit.label(str(entry["name"]) + ("  (나)" if mine else ""), 24, Kit.GOLD if mine else Color.WHITE)))
		row.add_child(Kit.label(str(tier["name"]), 20, Color(str(tier.get("color", "ffffff")))))
		var trophies := Kit.label("%d" % int(entry["trophies"]), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		trophies.custom_minimum_size = Vector2(90, 0)
		row.add_child(trophies)
		list.add_child(line)
	return body
