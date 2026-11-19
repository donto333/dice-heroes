extends RefCounted
## 확률 보기 창(2026-11-19, 정식 출시 준비). 영웅 소환·골드 소환·카드 뽑기·골드 카드 뽑기·행운의 룰렛의
## 등급별 확률, 하나하나의 확률, 보장 규칙을 보여 준다. 숫자는 규칙 코드 `Profile.odds_table`이 economy.json에서 계산한다.
## 쓰는 법: OddsWindow.open(app, "hero")   (kind: hero·hero_gold·card·card_gold·roulette)

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")

const TITLES := {
	"hero": "영웅 모집 확률",
	"hero_gold": "골드 소환 확률",
	"card": "카드 뽑기 확률",
	"card_gold": "골드 카드 뽑기 확률",
	"roulette": "행운의 룰렛 확률",
}
const GRADE_NAMES := {3: "전설", 2: "희귀", 1: "일반"}


## 화면의 '확률 보기' 작은 버튼. 누르면 창이 뜬다.
static func button(app, kind: String) -> Button:
	var pill := MenuArt.pill_button("확률 보기", "gray", "s")
	pill.custom_minimum_size = Vector2(132, 40)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.pressed.connect(func() -> void: open(app, kind))
	return pill


static func open(app, kind: String) -> Control:
	app.play("click")
	var table: Dictionary = Profile.odds_table(kind, app.data.get("characters", []), app.data.get("cards", {}), app.eco, str(app.profile.get("daily", {}).get("date", "")))
	var body := Kit.vbox(12)
	if kind == "roulette":
		_roulette_rows(body, table)
	else:
		_gacha_rows(body, table, kind)
	body.add_child(Kit.para(_notes(app, kind, table), 17, Kit.MUTED))
	var window: Control = app.dialog(str(TITLES.get(kind, "확률 보기")), body, [["닫기", Kit.PANEL_LIGHT]], 860)
	app.set_meta("odds_window", window)
	return window


## 소수점 셋째 자리까지, 뒤의 0은 지운다(6.000 → 6, 0.375 → 0.375).
static func percent(rate: float) -> String:
	var text := "%.3f" % rate
	while text.ends_with("0"):
		text = text.left(text.length() - 1)
	if text.ends_with("."):
		text = text.left(text.length() - 1)
	return text + "%"


static func _gacha_rows(body: VBoxContainer, table: Dictionary, kind: String) -> void:
	var summary := Kit.hbox(8)
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(summary)
	for group in table.get("groups", []):
		var grade := int(group["grade"])
		summary.add_child(MenuArt.capsule("%s %s" % ["★".repeat(grade), percent(float(group["rate"]))], "", 20))
	for group in table.get("groups", []):
		var grade := int(group["grade"])
		var color: Color = Kit.GRADE_COLORS[grade]
		var items: Array = group.get("items", [])
		var box := MenuArt.row(10)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(box)
		var column := Kit.vbox(6)
		box.add_child(column)
		var head := Kit.hbox(8)
		column.add_child(head)
		head.add_child(Kit.label("%s %s" % ["★".repeat(grade), GRADE_NAMES.get(grade, "")], 22, color))
		var each_rate := percent(float(items[-1]["rate"]) if not items.is_empty() else 0.0)
		var each := ("%d장 · 한 장당 %s" if kind.begins_with("card") else "%d명 · 한 명당 %s") % [items.size(), each_rate]
		if not items.is_empty() and bool(items[0].get("pickup", false)):
			each = "%d명 · 픽업 %s, 나머지 한 명당 %s" % [items.size(), percent(float(items[0]["rate"])), each_rate]
		head.add_child(Kit.expand(Kit.label(each, 18, Kit.MUTED)))
		head.add_child(Kit.label(percent(float(group["rate"])), 22, Kit.GOLD))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 4)
		column.add_child(grid)
		for item in items:
			var cell := Kit.hbox(6)
			cell.custom_minimum_size = Vector2(250, 0)
			var is_pickup := bool(item.get("pickup", false))
			var name_label := Kit.label(("UP " if is_pickup else "") + str(item["name"]), 17, Kit.GOLD if is_pickup else Color.WHITE)
			name_label.clip_text = true
			cell.add_child(Kit.expand(name_label))
			cell.add_child(Kit.label(percent(float(item["rate"])), 16, Kit.MUTED))
			grid.add_child(cell)


static func _roulette_rows(body: VBoxContainer, table: Dictionary) -> void:
	var groups: Array = table.get("groups", [])
	if groups.is_empty():
		return
	for item in groups[0].get("items", []):
		var line := MenuArt.row(10)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(line)
		var inside := Kit.hbox(8)
		line.add_child(inside)
		inside.add_child(Kit.expand(Kit.label(Kit.reward_line(item["reward"]), 20, Color.WHITE)))
		inside.add_child(Kit.label(percent(float(item["rate"])), 20, Kit.GOLD))


static func _notes(app, kind: String, table: Dictionary) -> String:
	var lines: PackedStringArray = []
	if kind == "roulette":
		var roulette: Dictionary = app.eco.get("roulette", {})
		lines.append("· 하루 %d번은 무료, 그 뒤에는 보석 %d개로 %d번 더 돌릴 수 있어요." % [int(roulette.get("free_per_day", 1)), int(roulette.get("extra_cost_gems", 0)), int(roulette.get("max_extra", 0))])
		lines.append("· 칸마다 나올 확률이 위와 같고, 돌릴 때마다 새로 정해져요.")
		return "\n".join(lines)
	lines.append("· 같은 등급 안에서는 모두 같은 확률이에요.")
	if kind.ends_with("_gold"):
		lines.append("· 골드로는 ★★★가 나오지 않고, ★★★ 확정 횟수도 세지 않아요.")
	var pickup := str(table.get("pickup", ""))
	if pickup != "":
		var info: Dictionary = app.character(pickup)
		lines.append("· 픽업 영웅: %s (%d일 남음). ★★★가 나오면 %d%%는 이 영웅, 나머지는 다른 ★★★예요." % [str(info.get("name", pickup)), Profile.pickup_days_left(app.eco, str(app.profile.get("daily", {}).get("date", ""))), int(table.get("pickup_share", 0))])
		lines.append("· ★★★ 확정으로 나오는 영웅은 언제나 픽업 영웅이에요.")
	if bool(table.get("guarantee_two", false)):
		lines.append("· 10회 뽑기에서 앞의 9번에 ★★ 이상이 없으면 마지막 한 번은 ★★ 이상이 나와요.")
	var pity := int(table.get("pity_3", 0))
	if pity > 0:
		var done := int(app.profile.get("card_pity" if kind == "card" else "pity", 0))
		lines.append("· %d번째까지 ★★★가 안 나오면 %d번째는 ★★★가 확정이에요. 지금까지 %d번 쌓였어요." % [pity - 1, pity, done])
	if kind.begins_with("card"):
		lines.append("· 이미 가진 카드가 나오면 골드로 바뀌어요.")
	else:
		lines.append("· 이미 가진 영웅이 나오면 강화 조각으로 바뀌어요.")
	lines.append("· 무료 뽑기도 같은 확률이에요.")
	return "\n".join(lines)
