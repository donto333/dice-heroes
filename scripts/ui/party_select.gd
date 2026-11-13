extends Control
## 시작 화면 겸 파티 고르기. 캐릭터 카드를 눌러 ATTACK / DEFENSE / SUPPORT 자리에 앉힌다.
## 소환 포인트(★ 수) 합계가 6을 넘으면 시작할 수 없다.

signal confirmed(party: Dictionary)

const SLOTS := ["attack", "defense", "support"]
const SLOT_LABELS := {"attack": "ATTACK", "defense": "DEFENSE", "support": "SUPPORT"}
const SLOT_HINTS := {"attack": "이동 · 공격", "defense": "방어", "support": "지력 · 게이지"}
const SLOT_STAT := {"attack": "attack", "defense": "defense", "support": "intellect"}
const STAT_NAMES := {"attack": "공격", "defense": "방어", "intellect": "지력"}
const CATEGORY_COLORS := {
	"영웅": Color("b8352a"),
	"위인": Color("2f6fb5"),
	"신화": Color("6f43a6"),
	"근현대": Color("2a7d4f"),
}
const POINT_LIMIT := 6
const GOLD := Color("ffcf4d")

var characters: Array = []
var abilities: Dictionary = {}
var party := {"attack": "", "defense": "", "support": ""}

var _active_slot := "attack"
var _slot_buttons: Dictionary = {}
var _card_buttons: Dictionary = {}
var _points_label: Label
var _start_button: Button
var _styles: Dictionary = {}
var _filter := ""
var _filter_buttons: Dictionary = {}
var _info_label: Label


func setup(character_list: Array, ability_table: Dictionary, initial: Dictionary) -> void:
	characters = character_list
	abilities = ability_table
	for slot in SLOTS:
		party[slot] = initial.get(slot, "")
	_build()
	_refresh()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.color = Color("12152b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := _label("주사위 영웅전", 60, GOLD)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color("5a3a00"))
	column.add_child(title)
	column.add_child(_label("파티를 꾸리세요. 자리를 누른 뒤 아래 캐릭터를 고르면 그 자리에 앉습니다.", 19, Color(1, 1, 1, 0.75)))

	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 8)
	column.add_child(slot_row)
	for slot in SLOTS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 132)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(_on_slot_pressed.bind(slot))
		slot_row.add_child(button)
		_slot_buttons[slot] = button

	_points_label = _label("", 24, Color.WHITE)
	column.add_child(_points_label)

	# 고른 캐릭터의 어빌리티 설명
	_info_label = _label("캐릭터를 누르면 어빌리티 설명이 여기 나옵니다.", 19, Color(1, 1, 1, 0.8))
	_info_label.custom_minimum_size = Vector2(0, 56)
	column.add_child(_info_label)

	# 분류 탭
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	for category in ["", "영웅", "위인", "신화", "근현대"]:
		var tab := Button.new()
		tab.text = "전체" if category == "" else category
		tab.custom_minimum_size = Vector2(0, 56)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 20)
		tab.add_theme_color_override("font_color", Color.WHITE)
		tab.add_theme_color_override("font_hover_color", Color.WHITE)
		tab.add_theme_color_override("font_pressed_color", Color.WHITE)
		tab.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		tab.pressed.connect(_on_filter_pressed.bind(category))
		tabs.add_child(tab)
		_filter_buttons[category] = tab

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for character in characters:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 150)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.text = _card_text(character)
		button.pressed.connect(_on_character_pressed.bind(character["id"]))
		grid.add_child(button)
		_card_buttons[character["id"]] = button

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	column.add_child(bottom)
	var auto_button := _plain_button("자동 추천", Color("3a4466"))
	auto_button.pressed.connect(_on_auto_pressed)
	bottom.add_child(auto_button)
	_start_button = _plain_button("게임 시작", Color("2f80ed"))
	_start_button.size_flags_stretch_ratio = 2.0
	_start_button.pressed.connect(_on_start_pressed)
	bottom.add_child(_start_button)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var key := "%s/%s/%d" % [fill.to_html(), border.to_html(), width]
	if _styles.has(key):
		return _styles[key]
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.border_width_bottom = width + 3
	box.set_corner_radius_all(10)
	box.set_content_margin_all(8)
	_styles[key] = box
	return box


func _plain_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 96)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	button.add_theme_stylebox_override("normal", _box(color, color.lightened(0.35), 2))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.12), Color.WHITE, 2))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.25), Color.WHITE, 2))
	button.add_theme_stylebox_override("disabled", _box(Color("2a2f4a"), Color("2a2f4a"), 0))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _character(id: String) -> Dictionary:
	for character in characters:
		if character["id"] == id:
			return character
	return {}


func _card_text(character: Dictionary) -> String:
	var ability: Dictionary = abilities.get(character.get("ability", ""), {})
	return "%s %s\n%s · %s\n이동%d 공%d 방%d 지%d" % [
		"★".repeat(int(character["grade"])), character["name"],
		character["category"], ability.get("name", "-"),
		int(character["move"]), int(character["attack"]), int(character["defense"]), int(character["intellect"])]


func points() -> int:
	var total := 0
	for slot in SLOTS:
		var character := _character(party[slot])
		if not character.is_empty():
			total += int(character["grade"])
	return total


func can_start() -> bool:
	for slot in SLOTS:
		if party[slot] == "":
			return false
	return points() <= POINT_LIMIT


func _on_slot_pressed(slot: String) -> void:
	_active_slot = slot
	_refresh()


func _on_filter_pressed(category: String) -> void:
	_filter = category
	_refresh()


func _on_character_pressed(id: String) -> void:
	_show_info(id)
	# 이미 다른 자리에 있으면 그 자리와 맞바꾼다.
	for slot in SLOTS:
		if party[slot] == id and slot != _active_slot:
			party[slot] = party[_active_slot]
	party[_active_slot] = id
	# 다음 빈 자리로 넘어간다.
	for slot in SLOTS:
		if party[slot] == "":
			_active_slot = slot
			break
	_refresh()


func _show_info(id: String) -> void:
	var character := _character(id)
	if character.is_empty() or _info_label == null:
		return
	var ability: Dictionary = abilities.get(character.get("ability", ""), {})
	_info_label.text = "%s %s · %s  [%s] %s" % [
		"★".repeat(int(character["grade"])), character["name"], character["category"],
		ability.get("name", "-"), ability.get("text", "")]


## 포인트 6 안에서 자리마다 필요한 능력이 높은 조합을 고른다.
func _on_auto_pressed() -> void:
	# 자리마다 점수가 높은 후보를 등급별로 몇 명만 남겨서 조합을 찾는다. 모두 맞춰 보면 느리다.
	var pools := {
		"attack": _top_by_grade(func(c): return int(c["attack"]) * 3 + int(c["move"]) * 2),
		"defense": _top_by_grade(func(c): return int(c["defense"]) * 3),
		"support": _top_by_grade(func(c): return int(c["intellect"]) * 2),
	}
	var best_score := -1
	var best := {}
	for a in pools["attack"]:
		for d in pools["defense"]:
			for s in pools["support"]:
				if a["id"] == d["id"] or a["id"] == s["id"] or d["id"] == s["id"]:
					continue
				if int(a["grade"]) + int(d["grade"]) + int(s["grade"]) > POINT_LIMIT:
					continue
				var score := int(a["attack"]) * 3 + int(a["move"]) * 2 + int(d["defense"]) * 3 + int(s["intellect"]) * 2
				if score > best_score:
					best_score = score
					best = {"attack": a["id"], "defense": d["id"], "support": s["id"]}
	if not best.is_empty():
		party = best
	_refresh()


## 등급마다 점수가 높은 캐릭터 4명씩을 고른다.
func _top_by_grade(score_of: Callable) -> Array:
	var picked: Array = []
	for grade in [1, 2, 3]:
		var group: Array = []
		for character in characters:
			if int(character["grade"]) == grade:
				group.append(character)
		group.sort_custom(func(x, y): return int(score_of.call(x)) > int(score_of.call(y)))
		picked.append_array(group.slice(0, 4))
	return picked


func _on_start_pressed() -> void:
	if can_start():
		confirmed.emit(party.duplicate())


func _refresh() -> void:
	if _points_label == null:
		return
	for category in _filter_buttons:
		var tab: Button = _filter_buttons[category]
		var tab_color: Color = CATEGORY_COLORS.get(category, Color("3a4466"))
		var on: bool = category == _filter
		var tab_fill: Color = tab_color if on else tab_color.darkened(0.55)
		var tab_border: Color = Color.WHITE if on else tab_color.darkened(0.2)
		for state in ["normal", "hover", "pressed"]:
			tab.add_theme_stylebox_override(state, _box(tab_fill, tab_border, 2))
	for id in _card_buttons:
		var card: Button = _card_buttons[id]
		card.visible = _filter == "" or _character(id).get("category", "") == _filter
	for slot in SLOTS:
		var button: Button = _slot_buttons[slot]
		var character := _character(party[slot])
		var stat: String = SLOT_STAT[slot]
		if character.is_empty():
			button.text = "%s\n(%s)\n비어 있음" % [SLOT_LABELS[slot], SLOT_HINTS[slot]]
		else:
			button.text = "%s\n%s %s\n%s %d" % [
				SLOT_LABELS[slot], "★".repeat(int(character["grade"])), character["name"],
				STAT_NAMES[stat], int(character[stat])]
		var fill: Color = Color("2a2f4a") if character.is_empty() else CATEGORY_COLORS.get(character["category"], Color("3a4466"))
		var border: Color = Color.WHITE if slot == _active_slot else fill.lightened(0.3)
		var width := 4 if slot == _active_slot else 2
		for state in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, _box(fill, border, width))

	for id in _card_buttons:
		var button: Button = _card_buttons[id]
		var character := _character(id)
		var fill: Color = CATEGORY_COLORS.get(character["category"], Color("3a4466"))
		var chosen := false
		for slot in SLOTS:
			if party[slot] == id:
				chosen = true
		if chosen:
			fill = fill.darkened(0.45)
		var border := GOLD if chosen else fill.lightened(0.3)
		for state in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, _box(fill if state != "hover" else fill.lightened(0.1), border, 2))

	var total := points()
	_points_label.text = "소환 포인트 %d / %d" % [total, POINT_LIMIT]
	_points_label.add_theme_color_override("font_color", Color("ff6b6b") if total > POINT_LIMIT else Color.WHITE)
	if total > POINT_LIMIT:
		_points_label.text += "  (★가 너무 많아요)"
	_start_button.disabled = not can_start()
