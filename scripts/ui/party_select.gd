extends Control
## 파티 고르기. 캐릭터 카드를 눌러 ATTACK / DEFENSE / SUPPORT 자리에 앉힌다.
## 소환 포인트(★ 수) 합계가 한도(플레이어 레벨에 따라 5~8)를 넘으면 정할 수 없다.
## 파티 편성(영웅 화면)과 대전 직전 모두에서 쓴다. 보여 줄 캐릭터 목록과 글자는 setup()의 options로 바꾼다.
const KitStyle := preload("res://scripts/ui/kit.gd")
const GameRules := preload("res://scripts/rules/game.gd")
const GameDataLoader := preload("res://scripts/game_data.gd")
## data/rules.json의 synergy 표(파티를 고를 때 미리 보여 준다)
var _synergy_table: Dictionary = GameDataLoader.load_json("res://data/rules.json").get("synergy", {})

signal confirmed(party: Dictionary)
signal cancelled
## 저장 칸에 지금 파티를 넣었을 때 (index: 0부터)
signal preset_saved(index: int, party: Dictionary)

const Portrait := preload("res://scripts/ui/portrait.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
## 분류 → 알약 색(영웅 화면과 같은 탭)
const CATEGORY_PILLS := {"": "blue", "영웅": "red", "위인": "blue", "신화": "purple", "근현대": "green"}
## 자리 → 자리 카드 틀 그림(assets/ui_menu/slot_*.png, 위 띠 빨강·보라·초록)
const SLOT_FRAMES := {"attack": "slot_attack", "defense": "slot_defense", "support": "slot_support"}

const SLOTS := ["attack", "defense", "support"]
const SLOT_LABELS := {"attack": "ATTACK", "defense": "DEFENSE", "support": "SUPPORT"}
const SLOT_HINTS := {"attack": "이동 · 공격", "defense": "방어", "support": "지력 · 게이지"}
const SLOT_STAT := {"attack": "attack", "defense": "defense", "support": "intellect"}
const STAT_NAMES := {"attack": "공격", "defense": "방어", "intellect": "지력"}
const CATEGORY_COLORS := {
	"영웅": Color("b8352a"),
	"위인": Color("2f6fb5"),
	"신화": Color("6f43a6"),
	"근현대": Color("27a35a"),
}
## 소환 포인트 한도. options["point_limit"]로 받는다(플레이어 레벨에 따라 5~8).
var point_limit := 6
const GOLD := Color("ffcf4d")

var characters: Array = []
var abilities: Dictionary = {}
var party := {"attack": "", "defense": "", "support": ""}

var _active_slot := "attack"
var _slot_buttons: Dictionary = {}
var _card_buttons: Dictionary = {}
## 버튼마다 안에 넣은 초상화와 글자 {"portrait": Control, "text": Label}
var _slot_parts: Dictionary = {}
var _card_parts: Dictionary = {}
var _points_label: Label
var _start_button: Button
var _styles: Dictionary = {}
var _filter := ""
var _filter_buttons: Dictionary = {}
var _info_label: Label
var _synergy_label: Label
## 그림 부품(assets/ui_menu)이 있으면 금테 카드·알약으로 그린다(UI 개편 1단계).
var _art := false
## {"title", "subtitle", "confirm_text", "cancel_text", "levels": {id: 레벨}}
var _options: Dictionary = {}
## 저장 칸(파티 3개까지). options["presets"]가 있을 때만 보인다.
var _presets: Array = []
var _preset_buttons: Array = []
var _save_button: Button
var _saving := false


func setup(character_list: Array, ability_table: Dictionary, initial: Dictionary, options: Dictionary = {}) -> void:
	characters = character_list
	abilities = ability_table
	_options = options
	point_limit = int(options.get("point_limit", point_limit))
	for slot in SLOTS:
		party[slot] = initial.get(slot, "")
	_build()
	_refresh()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# framed: 시안식 메뉴 틀(MenuArt.frame)의 큰 판 안에 들어갈 때는 바탕과 큰 여백 없이 그린다.
	var framed := bool(_options.get("framed", false))
	if not framed:
		var background := ColorRect.new()
		background.color = Color("2a8be6")
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(background)
		KitStyle.backdrop(self, "ui/bg_party", 0.5)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 0 if framed else 18)
	add_child(margin)

	# 가로 화면: 왼쪽(42%)에 내 파티 세 자리와 버튼, 오른쪽(58%)에 영웅 목록.
	_art = MenuArt.tex("slot_attack") != null and MenuArt.tex("hero_card") != null
	var halves := HBoxContainer.new()
	halves.add_theme_constant_override("separation", 16)
	margin.add_child(halves)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 42.0
	column.custom_minimum_size = Vector2(380 if framed else 520, 0)
	halves.add_child(column)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 58.0
	halves.add_child(right)

	var title := _label(str(_options.get("title", "파티 편성")), 28 if framed else 38, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	TextStyle.gold(title, 8)
	column.add_child(title)
	var subtitle := _label(str(_options.get("subtitle", "자리를 누른 뒤 아래 영웅을 고르면 그 자리에 앉습니다.")), 16 if framed else 19, Color(1, 1, 1, 0.85))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(subtitle)

	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 8)
	column.add_child(slot_row)
	for slot in SLOTS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 186 if framed else 216)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(_on_slot_pressed.bind(slot))
		slot_row.add_child(button)
		_slot_buttons[slot] = button
		_slot_parts[slot] = _slot_card(button, slot) if _art else _fill_card(button, 86.0 if framed else 112.0, 16)

	# 소환 포인트와 시너지: 캡슐 두 개
	var caps := HBoxContainer.new()
	caps.add_theme_constant_override("separation", 6)
	column.add_child(caps)
	var point_cap: Control = MenuArt.capsule("", "star", 18)
	caps.add_child(point_cap)
	_points_label = _capsule_label(point_cap)
	var synergy_cap: Control = MenuArt.capsule("", "", 16)
	synergy_cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caps.add_child(synergy_cap)
	_synergy_label = _capsule_label(synergy_cap)
	_synergy_label.clip_text = true
	_synergy_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 저장 칸: 자주 쓰는 파티를 넣어 두고 한 번에 불러온다.
	_preset_buttons = []
	_presets = (_options.get("presets", []) as Array).duplicate(true)
	if _options.has("presets"):
		var preset_row := HBoxContainer.new()
		preset_row.add_theme_constant_override("separation", 6)
		column.add_child(preset_row)
		_save_button = _plain_button("칸에 저장", Color("7a5a1c"))
		_save_button.custom_minimum_size = Vector2(124, 50)
		_save_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_save_button.add_theme_font_size_override("font_size", 18)
		_save_button.pressed.connect(_on_save_mode_pressed)
		preset_row.add_child(_save_button)
		for index in 3:
			var preset := _plain_button("", Color("2f74d6"))
			preset.custom_minimum_size = Vector2(0, 50)
			preset.add_theme_font_size_override("font_size", 16)
			preset.clip_text = true
			preset.pressed.connect(_on_preset_pressed.bind(index))
			preset_row.add_child(preset)
			_preset_buttons.append(preset)

	# 고른 캐릭터의 어빌리티 설명
	_info_label = _label("캐릭터를 누르면 어빌리티 설명이 여기 나옵니다.", 18, Color(1, 1, 1, 0.9))
	_info_label.custom_minimum_size = Vector2(0, 44 if framed else 56)
	_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var info_style = MenuArt.style("list_row", Vector4(22, 22, 22, 22), Vector4(16, 8, 16, 8))
	_info_label.add_theme_stylebox_override("normal", info_style if info_style != null else KitStyle.plate(Color(0.06, 0.08, 0.3, 0.72), Color("8fa6d8"), 14.0, 10, false))
	column.add_child(_info_label)

	# 분류 탭(영웅 화면과 같은 알약)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	right.add_child(tabs)
	for category in ["", "영웅", "위인", "신화", "근현대"]:
		var tab := _plain_button("전체" if category == "" else category, CATEGORY_COLORS.get(category, Color("2f74d6")))
		tab.custom_minimum_size = Vector2(0, 50)
		tab.add_theme_font_size_override("font_size", 20)
		tab.pressed.connect(_on_filter_pressed.bind(category))
		tabs.add_child(tab)
		_filter_buttons[category] = tab

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3 if bool(_options.get("framed", false)) and bool(_options.get("narrow", false)) else 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for character in characters:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 250)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(_on_character_pressed.bind(character["id"]))
		grid.add_child(button)
		_card_buttons[character["id"]] = button
		var parts := _hero_card(button, character) if _art else _fill_card(button, 138.0, 16)
		if not _art:
			parts["text"].text = _card_text(character)
		parts["portrait"].show_character(character, CATEGORY_COLORS.get(character["category"], Color("8fd0ff")))
		_card_parts[character["id"]] = parts

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	column.add_child(bottom)
	if str(_options.get("cancel_text", "")) != "":
		var back_button := _plain_button(str(_options["cancel_text"]), Color("2f74d6"))
		back_button.pressed.connect(_on_cancel_pressed)
		bottom.add_child(back_button)
	var auto_button := _plain_button("자동 추천", Color("2f74d6"))
	auto_button.pressed.connect(_on_auto_pressed)
	bottom.add_child(auto_button)
	_start_button = _plain_button(str(_options.get("confirm_text", "결정")), Color("2fb457"))
	_start_button.size_flags_stretch_ratio = 1.6
	_start_button.pressed.connect(_on_start_pressed)
	bottom.add_child(_start_button)


func _capsule_label(capsule: Control) -> Label:
	var line: Node = capsule.get_child(0)
	return line.get_child(line.get_child_count() - 1) as Label


## 금테 자리 카드: 위 색 띠에 자리 이름, 가운데 초상화와 능력 한 줄, 아래 남색 띠에 ★이름.
func _slot_card(button: Button, slot: String) -> Dictionary:
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var portrait := Portrait.new()
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.anchor_top = 0.14
	portrait.anchor_bottom = 0.85
	portrait.offset_left = 8
	portrait.offset_right = -8
	portrait.offset_top = 0
	portrait.offset_bottom = 0
	portrait.border_width = 0.0
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(portrait)
	var frame := TextureRect.new()
	frame.texture = MenuArt.tex(SLOT_FRAMES[slot])
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(frame)
	var role := _band_label(SLOT_LABELS[slot], 16, 0.0, 0.15)
	button.add_child(role)
	# 능력 한 줄(2단계): 초상화 아래쪽에 어두운 띠를 깔고 그 위에 또렷하게.
	var stat := _band_label("", 18, 0.74, 0.85)
	stat.offset_left = 8
	stat.offset_right = -8
	stat.add_theme_color_override("font_color", GOLD)
	stat.add_theme_stylebox_override("normal", KitStyle.box(Color(0.0, 0.03, 0.14, 0.78), Color.TRANSPARENT, 0, 6, 0))
	button.add_child(stat)
	var text := _band_label("", 16, 0.85, 1.0)
	button.add_child(text)
	return {"portrait": portrait, "text": text, "stat": stat, "frame": frame}


## 금테 영웅 카드(영웅 화면과 같은 hero_card 틀): 초상화, ★·레벨, 능력 줄, 아래 띠에 이름.
func _hero_card(button: Button, character: Dictionary) -> Dictionary:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("0f3d85") if state != "hover" else Color("1a4fa0")
		fill.set_corner_radius_all(10)
		fill.expand_margin_left = -6
		fill.expand_margin_right = -6
		fill.expand_margin_top = -10
		fill.expand_margin_bottom = -8
		button.add_theme_stylebox_override(state, fill)
	var portrait := Portrait.new()
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.anchor_bottom = 0.6
	portrait.offset_left = 10
	portrait.offset_right = -10
	portrait.offset_top = 16
	portrait.offset_bottom = 0
	portrait.border_width = 0.0
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(portrait)
	var frame := TextureRect.new()
	frame.texture = MenuArt.tex("hero_card")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(frame)
	var levels: Dictionary = _options.get("levels", {})
	var grade_text := "★".repeat(int(character["grade"]))
	if levels.has(character["id"]):
		grade_text += "  Lv%d" % int(levels[character["id"]])
	var grade := _band_label(grade_text, 16, 0.6, 0.7)
	grade.add_theme_color_override("font_color", GOLD)
	button.add_child(grade)
	var stats := _band_label("이동%d 공%d 방%d 지%d" % [int(character["move"]), int(character["attack"]), int(character["defense"]), int(character["intellect"])], 16, 0.7, 0.81)
	button.add_child(stats)
	var name_label := _band_label(str(character["name"]), 18, 0.82, 0.95)
	button.add_child(name_label)
	# 분류는 왼쪽 위 작은 동그란 표식으로만
	var dot := Panel.new()
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = CATEGORY_COLORS.get(character["category"], Color("8fd0ff"))
	dot_style.border_color = Color.WHITE
	dot_style.set_border_width_all(2)
	dot_style.set_corner_radius_all(9)
	dot.add_theme_stylebox_override("panel", dot_style)
	dot.position = Vector2(12, 18)
	dot.size = Vector2(18, 18)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(dot)
	var check := KitStyle.icon("m_check", 34.0)
	check.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	check.offset_left = -46
	check.offset_right = -10
	check.offset_top = 14
	check.offset_bottom = 48
	check.visible = false
	button.add_child(check)
	return {"portrait": portrait, "text": name_label, "frame": frame, "check": check}


## 카드 안 가로 띠 글자(위·아래 비율 사이에 가운데 정렬).
func _band_label(text: String, font_size: int, top: float, bottom: float) -> Label:
	var label := _label(text, font_size, Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.anchor_top = top
	label.anchor_bottom = bottom
	label.offset_left = 10
	label.offset_right = -10
	label.offset_top = 0
	label.offset_bottom = 0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TextStyle.menu(label, Color(0, 0.05, 0.2), 5)
	return label


## 버튼 안을 위쪽 초상화 + 아래쪽 글자로 채운다. 버튼 자체 글자는 쓰지 않는다.
func _fill_card(button: Button, portrait_height: float, font_size: int) -> Dictionary:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 7)
	margin.add_theme_constant_override("margin_bottom", 10)
	button.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	var portrait := Portrait.new()
	portrait.custom_minimum_size = Vector2(0, portrait_height)
	portrait.border_width = 2.0
	column.add_child(portrait)
	var text := _label("", font_size, Color.WHITE)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(text)
	return {"portrait": portrait, "text": text}


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
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("e3ebf7"))
	# 다른 화면과 같은 통통한 버튼 모양. 그림 부품이 있으면 금테 알약.
	KitStyle.paint(button, color)
	MenuArt.pill(button, MenuArt.pill_name(color))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _character(id: String) -> Dictionary:
	for character in characters:
		if character["id"] == id:
			return character
	return {}


func _card_text(character: Dictionary) -> String:
	var ability: Dictionary = abilities.get(character.get("ability", ""), {})
	var levels: Dictionary = _options.get("levels", {})
	var level_text := ""
	if levels.has(character["id"]):
		level_text = " Lv%d" % int(levels[character["id"]])
	return "%s %s%s\n%s · %s\n이동%d 공%d 방%d 지%d" % [
		"★".repeat(int(character["grade"])), character["name"], level_text,
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
	return points() <= point_limit


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
				if int(a["grade"]) + int(d["grade"]) + int(s["grade"]) > point_limit:
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


# ---------------------------------------------------------------- 저장 칸

func _preset_at(index: int) -> Dictionary:
	if index < _presets.size() and typeof(_presets[index]) == TYPE_DICTIONARY:
		return _presets[index]
	return {}


## 저장 칸의 영웅을 지금도 모두 쓸 수 있는지(가진 영웅 목록에 있는지)
func _preset_usable(preset: Dictionary) -> bool:
	for slot in SLOTS:
		if _character(str(preset.get(slot, ""))).is_empty():
			return false
	return true


func _on_save_mode_pressed() -> void:
	if not can_start():
		_info_label.text = "세 자리를 모두 채우고 포인트 제한을 지켜야 저장할 수 있어요."
		return
	_saving = not _saving
	_info_label.text = "저장할 칸을 누르세요." if _saving else "저장을 그만뒀어요."
	_refresh()


func _on_preset_pressed(index: int) -> void:
	if _saving:
		_saving = false
		while _presets.size() <= index:
			_presets.append({})
		_presets[index] = party.duplicate()
		preset_saved.emit(index, party.duplicate())
		_info_label.text = "%d번 칸에 저장했어요." % (index + 1)
		_refresh()
		return
	var preset := _preset_at(index)
	if preset.is_empty():
		_info_label.text = "%d번 칸은 비어 있어요. '칸에 저장'을 누른 뒤 이 칸을 누르면 지금 파티가 들어가요." % (index + 1)
		return
	if not _preset_usable(preset):
		_info_label.text = "%d번 칸에 지금 쓸 수 없는 영웅이 있어요." % (index + 1)
		return
	for slot in SLOTS:
		party[slot] = str(preset[slot])
	_info_label.text = "%d번 칸의 파티를 불러왔어요." % (index + 1)
	_refresh()


func _on_cancel_pressed() -> void:
	cancelled.emit()


func _on_start_pressed() -> void:
	if can_start():
		confirmed.emit(party.duplicate())


func _refresh() -> void:
	if _points_label == null:
		return
	for category in _filter_buttons:
		var tab: Button = _filter_buttons[category]
		var on: bool = category == _filter
		if on:
			MenuArt.tab(tab, true)
		elif not MenuArt.pill(tab, CATEGORY_PILLS.get(category, "blue")):
			var tab_color: Color = CATEGORY_COLORS.get(category, Color("8fd0ff"))
			for state in ["normal", "hover", "pressed"]:
				tab.add_theme_stylebox_override(state, _box(tab_color.darkened(0.55), tab_color.darkened(0.2), 2))
	for id in _card_buttons:
		var card: Button = _card_buttons[id]
		card.visible = _filter == "" or _character(id).get("category", "") == _filter
	for slot in SLOTS:
		var button: Button = _slot_buttons[slot]
		var character := _character(party[slot])
		var stat: String = SLOT_STAT[slot]
		var parts: Dictionary = _slot_parts[slot]
		var fill: Color = Color("6f86a8") if character.is_empty() else CATEGORY_COLORS.get(character["category"], Color("8fd0ff"))
		parts["portrait"].show_character(character, fill)
		if parts.has("frame"):
			# 금테 자리 카드: 고른 자리는 테가 밝게 빛난다.
			parts["text"].text = "비어 있음" if character.is_empty() else "%s %s" % ["★".repeat(int(character["grade"])), character["name"]]
			parts["stat"].text = SLOT_HINTS[slot] if character.is_empty() else "%s %d" % [STAT_NAMES[stat], int(character[stat])]
			parts["frame"].modulate = Color(1.3, 1.25, 1.0) if slot == _active_slot else Color(0.82, 0.82, 0.9)
			button.pivot_offset = button.size * 0.5
			continue
		if character.is_empty():
			parts["text"].text = "%s\n(%s)\n비어 있음" % [SLOT_LABELS[slot], SLOT_HINTS[slot]]
		else:
			parts["text"].text = "%s\n%s %s\n%s %d" % [
				SLOT_LABELS[slot], "★".repeat(int(character["grade"])), character["name"],
				STAT_NAMES[stat], int(character[stat])]
		var border: Color = Color.WHITE if slot == _active_slot else fill.lightened(0.3)
		var width := 4 if slot == _active_slot else 2
		for state in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, _box(fill, border, width))

	for id in _card_buttons:
		var button: Button = _card_buttons[id]
		var character := _character(id)
		var chosen := false
		for slot in SLOTS:
			if party[slot] == id:
				chosen = true
		var card_parts: Dictionary = _card_parts[id]
		if card_parts.has("frame"):
			# 고른 영웅은 금테가 밝아지고 체크 표시
			card_parts["frame"].modulate = Color(1.35, 1.3, 1.0) if chosen else Color.WHITE
			card_parts["check"].visible = chosen
			continue
		var fill: Color = CATEGORY_COLORS.get(character["category"], Color("8fd0ff"))
		card_parts["portrait"].dim = chosen
		card_parts["portrait"].queue_redraw()
		if chosen:
			fill = fill.darkened(0.45)
		var border := GOLD if chosen else fill.lightened(0.3)
		for state in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, _box(fill if state != "hover" else fill.lightened(0.1), border, 2))

	for index in _preset_buttons.size():
		var preset_button: Button = _preset_buttons[index]
		var preset := _preset_at(index)
		var names: Array = []
		for slot in SLOTS:
			var member := _character(str(preset.get(slot, "")))
			if not member.is_empty():
				names.append(str(member["name"]))
		# 버튼이 좁아서 짧게: 채운 칸은 첫 영웅 이름 + 외, 빈 칸은 "빈 칸"
		preset_button.text = "%d번 %s 외" % [index + 1, names[0]] if names.size() == 3 else "%d번 빈 칸" % (index + 1)
		preset_button.tooltip_text = "%d번  %s" % [index + 1, " · ".join(names)] if names.size() == 3 else preset_button.text
		var preset_color := "gold" if _saving else ("green" if names.size() == 3 else "blue")
		if not MenuArt.pill(preset_button, preset_color):
			var preset_fill := Color("f39a1c") if _saving else (Color("19a8c9") if names.size() == 3 else Color("2f74d6"))
			for state in ["normal", "hover", "pressed"]:
				preset_button.add_theme_stylebox_override(state, _box(preset_fill, GOLD if _saving else preset_fill.lightened(0.3), 2))
	if _save_button != null:
		_save_button.text = "칸 고르기..." if _saving else "칸에 저장"
		MenuArt.pill(_save_button, "gold" if _saving else "purple")

	var total := points()
	_points_label.text = "소환 포인트 %d / %d" % [total, point_limit]
	_points_label.add_theme_color_override("font_color", Color("ff6b6b") if total > point_limit else Color.WHITE)
	if total > point_limit:
		_synergy_label.text = "★가 너무 많아요"
		_synergy_label.add_theme_color_override("font_color", Color("ff9a8a"))
	else:
		# 시너지: 세 명이 같은 분류면 결속, 모두 다르면 조화
		var categories: Array = []
		for slot in SLOTS:
			categories.append(str(_character(party[slot]).get("category", "")))
		var bonus: Dictionary = GameRules.synergy_of(_synergy_table, categories)
		_synergy_label.text = "시너지: %s" % ("%s (%s)" % [bonus.get("name", ""), bonus.get("text", "")] if not bonus.is_empty() else "없음")
		_synergy_label.add_theme_color_override("font_color", GOLD if not bonus.is_empty() else Color.WHITE)
	_synergy_label.tooltip_text = _synergy_label.text
	_start_button.disabled = not can_start()
