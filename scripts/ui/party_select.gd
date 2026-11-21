extends Control
## 파티 고르기. 캐릭터 카드의 정보 창에서 적용하면 고른 자리에 앉힌다.
## 소환 포인트(★ 수) 합계가 한도(플레이어 레벨에 따라 5~8)를 넘으면 정할 수 없다.
## 파티 편성(영웅 화면)과 대전 직전 모두에서 쓴다. 보여 줄 캐릭터 목록과 글자는 setup()의 options로 바꾼다.
const KitStyle := preload("res://scripts/ui/kit.gd")
const GameRules := preload("res://scripts/rules/game.gd")
const GameDataLoader := preload("res://scripts/game_data.gd")
## data/rules.json의 synergy 표(파티를 고를 때 미리 보여 준다)
var _synergy_table: Dictionary = GameDataLoader.load_json("res://data/rules.json").get("synergy", {})
## 영웅 레벨(강화) 효과 표. 자동 추천과 자리 카드의 능력 줄에 쓴다.
var _level_battle: Array = GameDataLoader.load_json("res://data/rules.json").get("level_battle_bonus", [])
var _level_gauge: Array = GameDataLoader.load_json("res://data/rules.json").get("level_gauge_bonus", [])

signal confirmed(party: Dictionary)
signal cancelled
## 저장 칸에 지금 파티를 넣었을 때 (index: 0부터)
signal preset_saved(index: int, party: Dictionary)

const Portrait := preload("res://scripts/ui/portrait.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const HeroCardView := preload("res://scripts/ui/hero_card_view.gd")
## 분류 → 알약 색(영웅 화면과 같은 탭)
const CATEGORY_PILLS := {"": "blue", "영웅": "red", "위인": "blue", "신화": "purple", "근현대": "green"}
## 자리 → 자리 카드 틀 그림(assets/ui_menu/slot_*.png, 위 띠 빨강·파랑·초록)
const SLOT_FRAMES := {"attack": "slot_attack", "defense": "slot_defense", "support": "slot_support"}
const SLOTS := ["attack", "defense", "support"]
const SLOT_LABELS := {"attack": "ATTACK", "defense": "DEFENSE", "support": "SUPPORT"}
const SLOT_NAMES := {"attack": "공격", "defense": "방어", "support": "지원"}
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
var _app

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
var _grade_filter := 0
var _grade_buttons: Dictionary = {}
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
## 자동 추천 전략 고르기 창(누르면 뜸)
var _strategy_overlay: Control = null
var _rng := RandomNumberGenerator.new()

## 자동 추천 전략: [id, 이름, 설명]. 무게는 STRATEGY_WEIGHTS.
const STRATEGIES := [
	["balanced", "균형", "능력과 강화를 고루 따져요"],
	["attack", "공격형", "공격·이동이 센 영웅 위주"],
	["defense", "수비형", "방어가 단단한 영웅 위주"],
	["speed", "속도형", "이동 주사위가 많은 영웅 위주"],
	["skill", "스킬형", "지력이 높아 어빌리티를 자주 써요"],
	["bond", "결속", "세 명 모두 같은 분류 (시작 게이지 +15%)"],
	["harmony", "조화", "세 명 모두 다른 분류 (부적 1개)"],
	["random", "무작위", "한도 안에서 아무렇게나"],
]
## 전략마다 능력치에 곱하는 무게(공격·이동·방어·지력)
const STRATEGY_WEIGHTS := {
	"balanced": {"attack": 1.0, "move": 1.0, "defense": 1.0, "intellect": 1.0},
	"attack": {"attack": 1.7, "move": 1.2, "defense": 0.6, "intellect": 0.7},
	"defense": {"attack": 0.7, "move": 0.8, "defense": 1.8, "intellect": 0.9},
	"speed": {"attack": 0.9, "move": 2.4, "defense": 0.8, "intellect": 0.9},
	"skill": {"attack": 0.8, "move": 0.9, "defense": 0.8, "intellect": 1.9},
}


func setup(main_app, character_list: Array, ability_table: Dictionary, initial: Dictionary, options: Dictionary = {}) -> void:
	_app = main_app
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
	var info_style = MenuArt.style("friend_party/ability" if KitStyle.Observatory.active else "list_row", Vector4(22, 22, 22, 22), Vector4(16, 8, 16, 8))
	_info_label.add_theme_stylebox_override("normal", info_style if info_style != null else KitStyle.plate(Color(0.06, 0.08, 0.3, 0.72), Color("8fa6d8"), 14.0, 10, false))
	column.add_child(_info_label)

	# 분류 탭(영웅 화면과 같은 알약)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	right.add_child(tabs)
	for category in ["", "영웅", "위인", "신화", "근현대"]:
		var tab := _filter_button("전체" if category == "" else category, CATEGORY_COLORS.get(category, Color("2f74d6")))
		tab.pressed.connect(_on_filter_pressed.bind(category))
		tabs.add_child(tab)
		_filter_buttons[category] = tab

	var grades := HBoxContainer.new()
	grades.add_theme_constant_override("separation", 6)
	right.add_child(grades)
	for grade in [0, 3, 2, 1]:
		var tab := _filter_button("전체" if grade == 0 else "★".repeat(grade), KitStyle.PANEL_LIGHT)
		tab.pressed.connect(_on_grade_pressed.bind(grade))
		grades.add_child(tab)
		_grade_buttons[grade] = tab

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
		button.custom_minimum_size = Vector2(0, 242 if KitStyle.Observatory.active else 250)
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
	_start_button.set_meta("guide", "party_save")
	_start_button.size_flags_stretch_ratio = 1.6
	_start_button.pressed.connect(_on_start_pressed)
	bottom.add_child(_start_button)
	if KitStyle.Observatory.active:
		MenuArt.pill(_start_button, "gold")


func _capsule_label(capsule: Control) -> Label:
	var line: Node = capsule.get_child(0)
	return line.get_child(line.get_child_count() - 1) as Label


## 금테 자리 카드: 위 색 띠에 자리 이름, 가운데 초상화와 능력 한 줄, 아래 남색 띠에 ★이름.
func _slot_card(button: Button, slot: String) -> Dictionary:
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var portrait := Portrait.new()
	portrait.focus_y = 0.0
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 그림의 위 띠가 끝나는 자리부터 초상화를 그린다.
	portrait.anchor_top = 0.206
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
	var role := HeroCardView.band_label(SLOT_LABELS[slot], 16, 0.055 if KitStyle.Observatory.active else 0.02, 0.205 if KitStyle.Observatory.active else 0.19)
	button.add_child(role)
	# 능력 한 줄(2단계): 초상화 아래쪽에 어두운 띠를 깔고 그 위에 또렷하게.
	var stat := HeroCardView.band_label("", 18, 0.70, 0.81)
	stat.offset_left = 8
	stat.offset_right = -8
	stat.add_theme_color_override("font_color", GOLD)
	stat.add_theme_stylebox_override("normal", KitStyle.box(Color(0.0, 0.03, 0.14, 0.78), Color.TRANSPARENT, 0, 6, 0))
	button.add_child(stat)
	# 아래 남색 띠(그림의 세로 82~97%, 가로 양 끝 보석 안쪽)에 맞춰 ★이름을 놓는다.
	# 이름이 길면 글자를 줄여서라도 띠 안에 다 들어가게 한다.
	var plate := HeroCardView.nameplate(Vector2(0.08, 0.82), Vector2(0.92, 0.975))
	button.add_child(plate)
	var text := HeroCardView.band_label("", 16, 0.82, 0.975)
	text.anchor_left = 0.1
	text.anchor_right = 0.9
	text.offset_left = 0
	text.offset_right = 0
	button.add_child(text)
	return {"portrait": portrait, "text": text, "stat": stat, "frame": frame, "nameplate": plate}


## 편성 전용 선택 표시를 공용 영웅 카드 위에 얹는다.
func _hero_card(button: Button, character: Dictionary) -> Dictionary:
	var levels: Dictionary = _options.get("levels", {})
	var id: String = character["id"]
	var footer := ("Lv%d" % int(levels[id])) if levels.has(id) else ""
	var accent: Color = CATEGORY_COLORS.get(character["category"], Color("8fd0ff"))
	var parts := HeroCardView.mount(button, character, accent, footer)
	var check := KitStyle.icon("m_check", 34.0)
	check.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	check.offset_left = -46
	check.offset_right = -10
	check.offset_top = 14
	check.offset_bottom = 48
	if KitStyle.Observatory.active:
		check.offset_left = -36
		check.offset_right = -6
		check.offset_top = 1
		check.offset_bottom = 31
	check.visible = false
	button.add_child(check)
	parts["check"] = check
	return parts


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
	portrait.focus_y = 0.0
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


func _filter_button(text: String, color: Color) -> Button:
	var button := _plain_button(text, color)
	button.custom_minimum_size = Vector2(0, 50)
	button.add_theme_font_size_override("font_size", 18)
	return button


func _style_category_filter(button: Button, category: String) -> void:
	var plate := HeroCardView.category_plate(category)
	if plate == null:
		_style_filter_button(button, category == _filter,
			CATEGORY_PILLS.get(category, "blue"), CATEGORY_COLORS.get(category, Color("8fd0ff")))
		return

	var style := StyleBoxTexture.new()
	style.texture = plate
	style.modulate_color = Color.WHITE if category == _filter else Color(0.76, 0.76, 0.82)
	style.set_content_margin(SIDE_LEFT, 8)
	style.set_content_margin(SIDE_RIGHT, 8)
	var highlight := style.duplicate() as StyleBoxTexture
	highlight.modulate_color = Color(1.12, 1.12, 1.12)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", highlight)
	button.add_theme_stylebox_override("pressed", highlight)
	button.add_theme_stylebox_override("focus", highlight)


func _style_filter_button(button: Button, selected: bool, pill_color: String, fallback: Color) -> void:
	if selected:
		MenuArt.tab(button, true)
	elif not MenuArt.pill(button, pill_color):
		for state in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, _box(fallback.darkened(0.55), fallback.darkened(0.2), 2))
	# 긴 번역도 편성 판 너비 안에 들어가도록 알약의 글자 여백을 줄인다.
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state)
		if style is StyleBoxEmpty:
			style.content_margin_left = 8
			style.content_margin_right = 8


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
	return "%s %s%s\n%s · %s\n이동%d 공%d 방%d 지%d · 충전 속도 %d%%" % [
		"★".repeat(int(character["grade"])), character["name"], level_text,
		character["category"], ability.get("name", "-"),
		int(character["move"]), int(character["attack"]), int(character["defense"]), int(character["intellect"]),
		100 + int(character.get("charge", 0))]


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
	if category == _filter:
		return
	_filter = category
	_grade_filter = 0
	_refresh()


func _on_grade_pressed(grade: int) -> void:
	_grade_filter = grade
	_refresh()


func _on_character_pressed(id: String) -> void:
	var character := _character(id)
	if character.is_empty():
		return
	_show_info(id)
	var grade := int(character["grade"])
	var grade_color: Color = KitStyle.GRADE_COLORS[grade]
	var body := KitStyle.vbox(12)
	var row := KitStyle.hbox(16)
	body.add_child(row)

	var portrait := Portrait.new()
	portrait.custom_minimum_size = Vector2(236, 252)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.hd = true
	portrait.border = grade_color
	portrait.show_character(character, CATEGORY_COLORS.get(character["category"], KitStyle.LINE))
	row.add_child(portrait)

	var info := KitStyle.vbox(8)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(KitStyle.expand(info))
	var level := _level_of(character)
	info.add_child(KitStyle.para("%s  %s  Lv%d" % ["★".repeat(grade), character["category"], level], 24, grade_color))
	info.add_child(KitStyle.para("이동 %d · 공격 %d · 방어 %d · 지력 %d" % [
		int(character["move"]), int(character["attack"]), int(character["defense"]), int(character["intellect"])], 21, Color.WHITE))
	var battle_bonus := _from_table(_level_battle, level)
	var gauge_bonus := _from_table(_level_gauge, level)
	if battle_bonus > 0 or gauge_bonus > 0:
		info.add_child(KitStyle.para("전투 +%d · 스킬 충전 +%d%%" % [battle_bonus, gauge_bonus], 18, KitStyle.GOLD))
	var ability_id := str(character.get("ability", ""))
	var ability: Dictionary = abilities.get(ability_id, {})
	var skill := KitStyle.hbox(10)
	info.add_child(skill)
	var icon := GameDataLoader.ability_icon_rect(ability_id, 56.0)
	if icon != null:
		skill.add_child(icon)
	skill.add_child(KitStyle.expand(KitStyle.para("%s\n%s" % [ability.get("name", "-"), ability.get("text", "")], 20, Color.WHITE)))

	var target_slot := _active_slot
	body.add_child(KitStyle.para("이 무장으로 적용할까요? (자리: %s)" % SLOT_NAMES[target_slot], 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var apply: Array = ["이미 편성됨", KitStyle.DISABLED]
	if party[target_slot] != id:
		apply = ["적용", KitStyle.ACCENT, _apply_character.bind(id, target_slot)]
	_app.dialog(str(character["name"]), body, [apply, ["취소", KitStyle.PANEL_LIGHT]], 720)


func _apply_character(id: String, target_slot: String) -> void:
	# 이미 다른 자리에 있으면 그 자리와 맞바꾼다.
	for slot in SLOTS:
		if party[slot] == id and slot != target_slot:
			party[slot] = party[target_slot]
	party[target_slot] = id
	_active_slot = target_slot
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
	_open_strategies()


## 자동 추천 전략 고르기 창. 파티 고르기 칸 위에 어둡게 덮고 가운데에 버튼을 띄운다.
func _open_strategies() -> void:
	if is_instance_valid(_strategy_overlay):
		_strategy_overlay.queue_free()
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_strategy_overlay = overlay
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.12, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_strategies())
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("16306e")
	box.border_color = GOLD
	box.set_border_width_all(3)
	box.set_corner_radius_all(18)
	box.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := _label("어떤 전략으로 짤까요?", 24, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(_label("같은 전략을 다시 누르면 비슷하게 좋은 다른 조합을 보여 줘요.", 16, Color(1, 1, 1, 0.8)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	for entry in STRATEGIES:
		var color := Color("2fb457") if entry[0] == "balanced" else (Color("8a4fd0") if entry[0] in ["bond", "harmony"] else Color("2f74d6"))
		var button := _plain_button(str(entry[1]), color)
		button.custom_minimum_size = Vector2(250, 58)
		button.tooltip_text = str(entry[2])
		button.pressed.connect(_auto_pick.bind(str(entry[0])))
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		cell.add_child(button)
		var note := _label(str(entry[2]), 15, Color(1, 1, 1, 0.75))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.custom_minimum_size = Vector2(250, 0)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.add_child(note)
		grid.add_child(cell)
	var close := _plain_button("닫기", Color("2f74d6"))
	close.custom_minimum_size = Vector2(0, 52)
	close.pressed.connect(_close_strategies)
	column.add_child(close)


func _close_strategies() -> void:
	if is_instance_valid(_strategy_overlay):
		_strategy_overlay.queue_free()
	_strategy_overlay = null


## 전략에 맞춰 파티를 고른다. 가장 좋은 점수의 95% 안에 드는 조합 가운데 하나를 무작위로 골라
## 누를 때마다 다른 파티가 나올 수 있게 한다(지금 파티와 같은 것은 되도록 피함).
## 결속·조화는 분류 조건을 지키는 조합만, 무작위는 한도 안의 모든 조합에서 고른다.
func _auto_pick(strategy: String) -> void:
	_close_strategies()
	_rng.randomize()
	var weights: Dictionary = STRATEGY_WEIGHTS.get(strategy, STRATEGY_WEIGHTS["balanced"])
	var scores := {}
	for slot in SLOTS:
		var table := {}
		for character in characters:
			table[character["id"]] = _slot_score(character, slot, weights)
		scores[slot] = table
	var combos: Array = []
	var best_score := -1.0
	for a in characters:
		for d in characters:
			if d["id"] == a["id"]:
				continue
			if int(a["grade"]) + int(d["grade"]) + 1 > point_limit:
				continue
			for s in characters:
				if s["id"] == a["id"] or s["id"] == d["id"]:
					continue
				if int(a["grade"]) + int(d["grade"]) + int(s["grade"]) > point_limit:
					continue
				var same: bool = a["category"] == d["category"] and d["category"] == s["category"]
				var all_different: bool = a["category"] != d["category"] and d["category"] != s["category"] and a["category"] != s["category"]
				if strategy == "bond" and not same:
					continue
				if strategy == "harmony" and not all_different:
					continue
				var score := float(scores["attack"][a["id"]]) + float(scores["defense"][d["id"]]) + float(scores["support"][s["id"]])
				combos.append([score, {"attack": a["id"], "defense": d["id"], "support": s["id"]}])
				best_score = maxf(best_score, score)
	var name := _strategy_name(strategy)
	if combos.is_empty():
		if _info_label != null:
			_info_label.text = "%s: 가진 영웅으로는 조건에 맞는 파티를 짤 수 없어요." % name
		return
	var good: Array = []
	for combo in combos:
		if strategy == "random" or float(combo[0]) >= best_score * 0.95:
			good.append(combo[1])
	if good.size() > 1:
		good = good.filter(func(choice): return choice != party)
	party = good[_rng.randi_range(0, good.size() - 1)].duplicate()
	_refresh()
	if _info_label != null:
		_info_label.text = "자동 추천 · %s: %s" % [name, _strategy_note(strategy)]


func _strategy_name(strategy: String) -> String:
	for entry in STRATEGIES:
		if entry[0] == strategy:
			return str(entry[1])
	return strategy


func _strategy_note(strategy: String) -> String:
	for entry in STRATEGIES:
		if entry[0] == strategy:
			return str(entry[2])
	return ""


## 영웅 레벨(강화가 없으면 1).
func _level_of(character: Dictionary) -> int:
	return maxi(1, int(_options.get("levels", {}).get(str(character.get("id", "")), 1)))


func _from_table(table: Array, level: int) -> int:
	return int(table[clampi(level - 1, 0, table.size() - 1)]) if not table.is_empty() else 0


## 자리에 앉혔을 때의 점수. 능력치(주사위 1개 = 3.5점 정도)에 강화 효과를 같은 저울로 더한다.
## 전투 보너스 +1 = 합계 +1점. 스킬 충전 +x% = 그 자리 게이지가 x% 빨리 참(지력으로 환산해 더한다).
func _slot_score(character: Dictionary, slot: String, weights: Dictionary = {}) -> float:
	var w_attack := float(weights.get("attack", 1.0))
	var w_move := float(weights.get("move", 1.0))
	var w_defense := float(weights.get("defense", 1.0))
	var w_intellect := float(weights.get("intellect", 1.0))
	var level := _level_of(character)
	var battle := float(_from_table(_level_battle, level))
	# 영웅마다 다른 충전 속도(charge)도 같이 센다.
	var charge := (float(_from_table(_level_gauge, level)) + float(character.get("charge", 0))) / 100.0
	match slot:
		"attack":
			return float(character["attack"]) * 3.5 * 3.0 * w_attack + float(character["move"]) * 2.0 * 3.5 * w_move + battle * 3.0 + charge * 4.0
		"defense":
			return float(character["defense"]) * 3.5 * 3.0 * w_defense + battle * 3.0 + charge * 4.0
		_:
			var intellect := float(character["intellect"])
			return intellect * 2.0 * 3.5 * (1.0 + charge) * w_intellect + charge * 4.0


## 등급마다 점수가 높은 캐릭터 4명씩을 고른다.
func _top_by_grade(score_of: Callable) -> Array:
	var picked: Array = []
	for grade in [1, 2, 3]:
		var group: Array = []
		for character in characters:
			if int(character["grade"]) == grade:
				group.append(character)
		group.sort_custom(func(x, y): return float(score_of.call(x)) > float(score_of.call(y)))
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
		_style_category_filter(_filter_buttons[category], category)
	for grade in _grade_buttons:
		_style_filter_button(_grade_buttons[grade], grade == _grade_filter, "blue", KitStyle.PANEL_LIGHT)
	for slot in SLOTS:
		var button: Button = _slot_buttons[slot]
		var character := _character(party[slot])
		var stat: String = SLOT_STAT[slot]
		var parts: Dictionary = _slot_parts[slot]
		var fill: Color = Color("6f86a8") if character.is_empty() else CATEGORY_COLORS.get(character["category"], Color("8fd0ff"))
		parts["portrait"].show_character(character, fill)
		if parts.has("frame"):
			parts["nameplate"].texture = HeroCardView.category_plate(str(character.get("category", "")))
			# 금테 자리 카드: 고른 자리는 테가 밝게 빛난다.
			parts["text"].text = "비어 있음" if character.is_empty() else "%s %s" % ["★".repeat(int(character["grade"])), character["name"]]
			KitStyle.squeeze_text(parts["text"], 16, 11)
			parts["stat"].text = SLOT_HINTS[slot] if character.is_empty() else "%s %d" % [STAT_NAMES[stat], int(character[stat])]
			# 강화 효과도 함께: 공격·방어 자리는 전투 보너스(+n)를 붙인다.
			if not character.is_empty() and slot != "support":
				var bonus := _from_table(_level_battle, _level_of(character))
				if bonus > 0:
					parts["stat"].text += " +%d" % bonus
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
		button.visible = (_filter == "" or character["category"] == _filter) \
				and (_grade_filter == 0 or int(character["grade"]) == _grade_filter)
		var chosen := false
		for slot in SLOTS:
			if party[slot] == id:
				chosen = true
		var card_parts: Dictionary = _card_parts[id]
		if card_parts.has("frame"):
			# 고른 영웅은 금테가 밝아지고 체크 표시
			var frame: Control = card_parts["frame"]
			if KitStyle.Observatory.active:
				frame.set_meta("selected", chosen)
				frame.queue_redraw()
			else:
				frame.modulate = Color(1.35, 1.3, 1.0) if chosen else Color.WHITE
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
