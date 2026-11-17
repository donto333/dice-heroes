extends RefCounted
## 메뉴 화면 공통 그림 부품(ChatGPT가 그린 것, 2026-11-17) `assets/ui_menu/`.
## 왼쪽 세로 메뉴 판·버튼, 위 띠, 제목 명판, 재화 캡슐, 더하기 버튼, 영웅 카드 테두리, 목록 줄, 탭, 큰 판.
## 그림이 없으면 null을 돌려주고, 부르는 쪽은 예전 모양으로 그린다.
## UI 개편 1단계(2026-11-17, docs/UI개편기획.md): 금테 알약 버튼(pill), 구역 머리띠(section), 목록 줄(row),
## 요약 카드(summary), 보상 캡슐(capsule), 잠긴 줄(locked_row), 탭(tab), 동그란 홈 버튼을 더했다.

const Kit := preload("res://scripts/ui/kit.gd")
const PillSkin := preload("res://scripts/ui/pill_skin.gd")

const ART := "res://assets/ui_menu/"

## 화면 이름 → [제목, 아이콘]. 위 띠 왼쪽 제목 명판에 쓴다.
const TITLES := {
	"heroes": ["영웅", "heroes"],
	"shop": ["상점", "shop"],
	"missions": ["미션", "missions"],
	"settings": ["설정", "settings"],
	"adventure": ["모험", "adventure"],
	"pass": ["시즌 패스", "pass"],
	"help": ["게임 방법", "help"],
	"party": ["파티 편성", "swords"],
}


static func tex(name: String) -> Texture2D:
	var path: String = ART + name + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return null


## 가운데만 늘어나는 그림 상자(StyleBoxTexture). margins는 그림 픽셀(왼, 위, 오른, 아래),
## content는 글자·내용이 들어갈 안쪽 여백(왼, 위, 오른, 아래).
static func style(name: String, margins: Vector4, content: Vector4) -> StyleBoxTexture:
	var texture := tex(name)
	if texture == null:
		return null
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = margins.x
	box.texture_margin_top = margins.y
	box.texture_margin_right = margins.z
	box.texture_margin_bottom = margins.w
	box.content_margin_left = content.x
	box.content_margin_top = content.y
	box.content_margin_right = content.z
	box.content_margin_bottom = content.w
	return box


## 버튼의 네 상태를 그림 상자로 바꾼다. 광택 몸통(Gloss)은 숨긴다. 그림이 없으면 false.
static func skin_button(button: Button, name: String, margins: Vector4, content: Vector4) -> bool:
	var normal := style(name, margins, content)
	if normal == null:
		return false
	var gloss = button.get_node_or_null("Gloss")
	if gloss != null:
		gloss.visible = false
	var hover := normal.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.12, 1.12, 1.12)
	var pressed := normal.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color(0.82, 0.82, 0.86)
	var disabled := normal.duplicate() as StyleBoxTexture
	disabled.modulate_color = Color(0.55, 0.57, 0.68)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return true


## 판 위 왼쪽에 올리는 제목 명판: 동그란 금테 자리에 아이콘, 오른쪽에 제목 글자. 그림이 없으면 null.
static func title_plate(text: String, icon: Texture2D) -> Control:
	var texture := tex("title_plate")
	if texture == null:
		return null
	var plate := Control.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.custom_minimum_size = Vector2(196, 64)
	var back := NinePatchRect.new()
	back.texture = texture
	back.patch_margin_left = 66
	back.patch_margin_right = 26
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(back)
	if icon != null:
		var picture := TextureRect.new()
		picture.texture = icon
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.position = Vector2(12, 12)
		picture.size = Vector2(40, 40)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(picture)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color.WHITE)
	TextStyle.menu(label, Color(0, 0.05, 0.2), 7)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 70
	label.offset_right = -16
	label.offset_bottom = -2
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(label)
	return plate


# ---------------------------------------------------------------- 시안식 화면 틀

## 시안식 메뉴 화면 틀을 만든다(2026-11-17 사용자 결정: 이동 메뉴는 홈 버튼 하나).
## 위: 홈 버튼 · 제목 명판 · (빈칸) · 골드·보석 캡슐
## 아래: 왼쪽 세로 판에 이 화면 안의 항목(tabs: [[id, 글자, 아이콘], ...]), 오른쪽 큰 금테 판.
## 큰 판 안쪽 세로 상자를 돌려준다. 항목을 누르면 on_tab(id)를 부른다. 항목이 없으면 세로 판도 없다.
## summary: 왼쪽 판 항목 아래 빈 곳에 넣을 요약 카드(summary()로 만든 것). 없으면 null.
static func frame(screen: Control, app, backdrop_art: String, tabs: Array, active: String, on_tab: Callable, summary_card: Control = null) -> VBoxContainer:
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(Kit.sky())
	if backdrop_art != "":
		Kit.backdrop(screen, backdrop_art, 1.0)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.03, 0.14, 0.3)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	screen.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)

	# 위 줄
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.custom_minimum_size = Vector2(0, 70)
	outer.add_child(head)
	head.add_child(_home_button(app))
	var spec: Array = TITLES.get(str(app.current_name), ["", ""])
	var plate := title_plate(str(spec[0]), Kit.icon(str(spec[1]), 40.0).texture)
	if plate != null:
		plate.custom_minimum_size = Vector2(300, 70)
		head.add_child(plate)
	else:
		head.add_child(Kit.label(str(spec[0]), 32))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	head.add_child(_money_chip("gold", int(app.profile.get("gold", 0)), Kit.GOLD))
	head.add_child(_money_chip("gem", int(app.profile.get("gems", 0)), Kit.GEM))

	# 본문: 왼쪽 항목 판 + 오른쪽 큰 판
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	if not tabs.is_empty():
		var rail := PanelContainer.new()
		rail.custom_minimum_size = Vector2(238, 0)
		var rail_style = style("rail_panel", Vector4(24, 34, 24, 34), Vector4(12, 18, 12, 18))
		rail.add_theme_stylebox_override("panel", rail_style if rail_style != null else Kit.plate(Color("17357f"), Kit.TRIM, 20.0, 12, false))
		body.add_child(rail)
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 10)
		rail.add_child(list)
		for entry in tabs:
			var item := _rail_button(entry, str(entry[0]) == active, on_tab)
			if tabs.size() > 5:
				# 항목이 많으면(모험 장 목록 등) 낮고 작은 글자로 다 들어가게 한다.
				list.add_theme_constant_override("separation", 6)
				item.custom_minimum_size = Vector2(0, 50)
				item.add_theme_font_size_override("font_size", 19)
				item.add_theme_constant_override("icon_max_width", 32)
				item.add_theme_constant_override("h_separation", 6)
				item.clip_text = true
			list.add_child(item)
		if summary_card != null:
			list.add_child(Kit.spacer())
			list.add_child(summary_card)
	var board := PanelContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var board_style = style("content_panel", Vector4(30, 30, 30, 30), Vector4(24, 22, 24, 22))
	board.add_theme_stylebox_override("panel", board_style if board_style != null else Kit.plate(Color("17357f"), Kit.TRIM, 20.0, 18, true))
	body.add_child(board)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	board.add_child(content)
	return content


## 세로 판의 항목 버튼: 고른 것은 금색, 나머지는 파란 알약. 왼쪽에 아이콘, 오른쪽에 글자.
static func _rail_button(entry: Array, on: bool, on_tab: Callable) -> Button:
	var button := Button.new()
	button.text = str(entry[1])
	button.custom_minimum_size = Vector2(0, 76)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 26)
	var art := tex("menu_on" if on else "menu_off")
	if art != null:
		# 높이가 달라도 금 장식이 찌그러지지 않게 높이에 맞춰 줄여 그린다(pill_skin.gd).
		var skin := PillSkin.new()
		skin.texture = art
		skin.cap = 0.47
		button.add_child(skin)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var space := StyleBoxEmpty.new()
			space.content_margin_left = 16
			space.content_margin_right = 12
			space.content_margin_top = 4
			space.content_margin_bottom = 6
			button.add_theme_stylebox_override(state, space)
	else:
		Kit.paint(button, Color("ffc62b") if on else Color("2f74d6"))
	var ink := Color("5a3200") if on else Color.WHITE
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	if on:
		button.add_theme_constant_override("outline_size", 0)
	else:
		TextStyle.menu(button, Color(0, 0.05, 0.25), 7)
	if entry.size() > 2:
		var picture: TextureRect = Kit.icon(str(entry[2]), 46.0)
		if picture.texture != null:
			button.icon = picture.texture
			button.expand_icon = false
			button.add_theme_constant_override("icon_max_width", 46)
			button.add_theme_constant_override("h_separation", 10)
	button.pressed.connect(func() -> void: on_tab.call(str(entry[0])))
	return button


## 위 줄 재화 캡슐(아이콘 + 오른쪽 정렬 숫자). on_plus가 있으면 오른쪽 초록 더하기를 누를 수 있다(로비에서 상점으로).
static func money_chip(icon_name: String, amount: int, color: Color, on_plus: Callable = Callable()) -> Control:
	return _money_chip(icon_name, amount, color, on_plus)


static func _money_chip(icon_name: String, amount: int, color: Color, on_plus: Callable = Callable()) -> Control:
	var capsule := PanelContainer.new()
	capsule.custom_minimum_size = Vector2(230, 50)
	capsule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var art = style("currency", Vector4(24, 0, 24, 0), Vector4(8, 2, 6, 2))
	capsule.add_theme_stylebox_override("panel", art if art != null else Kit.box(Color(0, 0.06, 0.22, 0.72), color.darkened(0.2), 2, 20, 4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	capsule.add_child(row)
	row.add_child(Kit.icon(icon_name, 34.0))
	var label: Label = Kit.label(Kit.comma(amount), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	TextStyle.number(label, 5)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var plus := tex("plus_btn")
	if plus != null:
		# 시안처럼 오른쪽 끝에 초록 더하기(꾸밈).
		var mark := TextureRect.new()
		mark.texture = plus
		mark.custom_minimum_size = Vector2(42, 34)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mark)
		if on_plus.is_valid():
			var press := Button.new()
			press.flat = true
			press.focus_mode = Control.FOCUS_NONE
			press.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				press.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			press.pressed.connect(on_plus)
			mark.mouse_filter = Control.MOUSE_FILTER_STOP
			mark.add_child(press)
	elif on_plus.is_valid():
		var plus_button := Kit.button("+", Kit.ACCENT, 22, 34)
		plus_button.custom_minimum_size = Vector2(38, 34)
		plus_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus_button.pressed.connect(on_plus)
		row.add_child(plus_button)
	return capsule


## 위 줄 왼쪽 동그란 홈 버튼(파란 구슬 금테 + 흰 집, home_btn). 그림이 없으면 예전 모양.
static func _home_button(app) -> Button:
	var home := Button.new()
	home.custom_minimum_size = Vector2(70, 70)
	home.tooltip_text = "로비로"
	home.pressed.connect(func() -> void:
		app.play("click")
		app.go("lobby"))
	var round_tex := tex("home_btn")
	if round_tex != null:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			home.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var skin := PillSkin.new()
		skin.texture = round_tex
		skin.cap = 0.5
		home.add_child(skin)
		return home
	if not skin_button(home, "menu_off", Vector4(30, 26, 30, 26), Vector4(4, 4, 4, 4)):
		Kit.paint(home, Kit.PANEL_LIGHT)
	var home_icon: TextureRect = Kit.icon("home", 40.0)
	home_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	home_icon.offset_left = 18
	home_icon.offset_right = -18
	home_icon.offset_top = 8
	home_icon.offset_bottom = -10
	home_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.add_child(home_icon)
	return home


# ---------------------------------------------------------------- 금테 알약 버튼(1단계)

## 알약 색 이름 → 글자 외곽선 색. gold=가장 중요한 것, green=가기·확인·켜짐, blue=보조, red=나가기·삭제,
## gray=못 누름·꺼짐, purple=특별.
const PILL_EDGES := {
	"gold": Color("7a3a00"), "green": Color("0c4a1c"), "blue": Color("0a2a6a"),
	"red": Color("5a0a0a"), "gray": Color("2a2f3a"), "purple": Color("3a0a6a"),
	"tab_on": Color("5a3200"), "tab_off": Color("0a2a6a"),
}
## 크기 세 가지: [높이, 글자]
const PILL_SIZES := {"l": [72.0, 26], "m": [56.0, 22], "s": [44.0, 18]}


## 버튼에 금테 알약 몸통을 입힌다(가운데만 늘어남, 눌림·꺼짐 표시 포함). 광택 몸통(Gloss)은 숨긴다.
## color_name: gold·green·blue·red·gray·purple 또는 tab_on·tab_off. 그림이 없으면 false(예전 모양 그대로).
static func pill(button: Button, color_name: String) -> bool:
	var picture := tex("pill_" + color_name)
	if picture == null:
		picture = tex(color_name)
	if picture == null:
		return false
	var gloss = button.get_node_or_null("Gloss")
	if gloss != null:
		gloss.visible = false
	var skin = button.get_node_or_null("Pill")
	if skin == null:
		skin = PillSkin.new()
		button.add_child(skin)
		button.move_child(skin, 0)
	skin.texture = picture
	skin.off_texture = null if color_name.begins_with("tab_") else tex("pill_gray")
	skin.cap = 0.5
	skin.queue_redraw()
	var height := maxf(button.custom_minimum_size.y, 40.0)
	var side := clampf(height * 0.36, 14.0, 34.0)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var space := StyleBoxEmpty.new()
		space.content_margin_left = side
		space.content_margin_right = side
		space.content_margin_top = 4
		space.content_margin_bottom = 7
		if state == "pressed":
			space.content_margin_top = 6
			space.content_margin_bottom = 5
		button.add_theme_stylebox_override(state, space)
	var edge: Color = PILL_EDGES.get(color_name, Color(0, 0.05, 0.2))
	var ink := Color("5a3200") if color_name == "tab_on" else Color.WHITE
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override("font_disabled_color", Color("e6e9f0"))
	if color_name == "tab_on":
		button.add_theme_constant_override("outline_size", 0)
		button.add_theme_constant_override("shadow_outline_size", 0)
		button.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.0))
	else:
		TextStyle.menu(button, edge, 6)
	return true


## 새 알약 버튼. size는 "l"(72)·"m"(56)·"s"(44). 그림이 없으면 Kit.button 모양.
static func pill_button(text: String, color_name: String, size: String = "m") -> Button:
	var spec: Array = PILL_SIZES.get(size, PILL_SIZES["m"])
	var result: Button = Kit.button(text, _fallback_color(color_name), int(spec[1]), float(spec[0]))
	pill(result, color_name)
	return result


## 탭 알약: 고른 것은 노란 tab_on, 나머지는 파란 tab_off.
static func tab(target: Button, on: bool) -> void:
	if not pill(target, "tab_on" if on else "tab_off"):
		Kit.paint(target, Color("ffc62b") if on else Color("2f74d6"))


static func _fallback_color(color_name: String) -> Color:
	match color_name:
		"gold":
			return Kit.PRIMARY
		"green":
			return Kit.ACCENT
		"red":
			return Kit.BAD
		"gray":
			return Kit.DISABLED
		"purple":
			return Color("7d4fc0")
	return Kit.PANEL_LIGHT


## 칠한 색으로 알약 색 이름을 고른다(Kit.button에 준 색을 그대로 옮길 때).
static func pill_name(color: Color) -> String:
	if color.s < 0.4:
		return "gray"
	var hue := color.h
	if hue < 0.04 or hue > 0.93:
		return "red"
	if hue < 0.17:
		return "gold"
	if hue < 0.47:
		return "green"
	if hue < 0.74:
		return "blue"
	return "purple"


## root 아래에서 광택 몸통(Gloss)으로 그린 버튼을 모두 같은 색의 금테 알약으로 바꾼다.
## 이미 알약이거나 메타 "keep_look"이 있는 버튼은 건너뛴다.
static func skin_buttons(root: Node) -> void:
	for child in root.get_children():
		if child is Button and not child.has_meta("keep_look") and child.get_node_or_null("Pill") == null:
			var gloss = child.get_node_or_null("Gloss")
			if gloss != null and gloss.visible:
				pill(child, pill_name(gloss.color))
		skin_buttons(child)


# ---------------------------------------------------------------- 큰 판 안쪽(1단계)

## 구역 머리띠: 왼쪽 동그란 금테 자리에 아이콘, 금색 제목, 오른쪽 작은 설명. 그림이 없으면 글자 줄.
static func section(title: String, icon_name: String = "", note: String = "") -> Control:
	var band := tex("section_head")
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 64)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if band != null:
		holder.resized.connect(holder.queue_redraw)
		holder.draw.connect(func() -> void:
			PillSkin.draw_slices(holder, band, Rect2(Vector2.ZERO, holder.size), 1.08, Color.WHITE, 0.5))
	var strip := HBoxContainer.new()
	strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strip.offset_left = 8 if band != null else 0
	strip.offset_right = -30 if band != null else 0
	strip.add_theme_constant_override("separation", 12)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(strip)
	var picture: TextureRect = Kit.icon(icon_name if icon_name != "" else "star", 44.0)
	picture.custom_minimum_size = Vector2(50, 46)
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strip.add_child(picture)
	var label: Label = Kit.label(title, 26, Kit.GOLD)
	TextStyle.gold(label, 7)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	strip.add_child(label)
	if note != "":
		var small: Label = Kit.label(note, 16, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)
		small.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		small.size_flags_vertical = Control.SIZE_FILL
		strip.add_child(small)
	return holder


## 목록 줄 판(남색 + 얇은 금테, list_row). 안에 HBox 등을 넣어 쓴다. 그림이 없으면 Kit.panel.
static func row(padding: int = 12) -> PanelContainer:
	var line := PanelContainer.new()
	var art = style("list_row", Vector4(22, 22, 22, 22), Vector4(padding + 8, padding, padding + 8, padding))
	line.add_theme_stylebox_override("panel", art if art != null else Kit.plate(Color("13458f"), Kit.TRIM, 16.0, padding, false))
	return line


## 목록 줄 한 개를 한 번에: 왼쪽 아이콘(48) · 제목(24)·설명(18) · 오른쪽 덧붙일 것(extra, 없으면 null).
## 제목·설명 세로 상자를 돌려준다(진행 막대 등을 더 넣을 수 있게). 줄은 parent에 붙는다.
static func list_row(parent: Control, icon_name: String, title: String, note: String = "", extra: Control = null, dim: bool = false) -> VBoxContainer:
	var line := row(10)
	parent.add_child(line)
	var inside := HBoxContainer.new()
	inside.add_theme_constant_override("separation", 12)
	line.add_child(inside)
	if icon_name != "":
		var picture: TextureRect = Kit.icon(icon_name, 48.0)
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if dim:
			picture.modulate = Color(0.6, 0.6, 0.7)
		inside.add_child(picture)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	inside.add_child(words)
	words.add_child(Kit.para(title, 24, Kit.MUTED if dim else Color.WHITE))
	if note != "":
		words.add_child(Kit.para(note, 18, Kit.MUTED))
	if extra != null:
		extra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inside.add_child(extra)
	return words


## 보상 캡슐: 작은 어두운 알약에 아이콘과 글. 그림이 없으면 단색 캡슐.
static func capsule(text: String, icon_name: String = "", font_size: int = 18) -> Control:
	var art := tex("reward_capsule")
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(0, 38)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var space := StyleBoxEmpty.new()
	space.content_margin_left = 16
	space.content_margin_right = 16
	space.content_margin_top = 2
	space.content_margin_bottom = 3
	if art != null:
		box.add_theme_stylebox_override("panel", space)
		box.resized.connect(box.queue_redraw)
		box.draw.connect(func() -> void:
			PillSkin.draw_slices(box, art, Rect2(Vector2.ZERO, box.size), 0.5))
	else:
		box.add_theme_stylebox_override("panel", Kit.box(Color(0.02, 0.08, 0.25, 0.85), Kit.TRIM, 2, 18, 6))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(line)
	if icon_name != "":
		line.add_child(Kit.icon(icon_name, 26.0))
	var label: Label = Kit.label(text, font_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	TextStyle.number(label, 4)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(label)
	return box


## 보상 글(Kit.reward_line과 같은 내용)을 골드·보석 아이콘 캡슐 줄로.
static func reward_capsules(reward: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	if int(reward.get("gold", 0)) > 0:
		line.add_child(capsule(Kit.comma(int(reward["gold"])), "gold"))
	if int(reward.get("gems", 0)) > 0:
		line.add_child(capsule(Kit.comma(int(reward["gems"])), "gem"))
	var rest: Dictionary = reward.duplicate()
	rest.erase("gold")
	rest.erase("gems")
	if not rest.is_empty():
		var other := Kit.reward_line(rest)
		if other != "":
			line.add_child(capsule(other))
	return line


## 왼쪽 세로 판 아래 요약 카드: 작은 금테 판에 아이콘 + 두 줄 글. 그림이 없으면 Kit.plate.
## extra: 두 줄 글 아래에 덧붙일 것(작은 초상화 줄 등).
static func summary(icon_name: String, first: String, second: String = "", extra: Control = null) -> PanelContainer:
	var card := PanelContainer.new()
	var art = style("summary_card", Vector4(30, 30, 30, 30), Vector4(24, 16, 20, 16))
	card.add_theme_stylebox_override("panel", art if art != null else Kit.plate(Color("13458f"), Kit.TRIM, 14.0, 12, false))
	# 위: 아이콘 + 첫 줄, 아래: 둘째 줄(판 너비 전체), 그 아래 덧붙일 것
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 2)
	card.add_child(words)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	words.add_child(top)
	if icon_name != "":
		var picture: TextureRect = Kit.icon(icon_name, 34.0)
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(picture)
	var head: Label = Kit.para(first, 18, Color.WHITE)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(head)
	if second != "":
		words.add_child(Kit.para(second, 16, Kit.GOLD))
	if extra != null:
		words.add_child(extra)
	return card


## 잠긴 줄(회색 판 + 금테, 왼쪽 동그란 자리에 자물쇠). 프리미엄 보상처럼 볼 수만 있는 것. 그림이 없으면 회색 판.
static func locked_row(text: String, note: String = "준비 중", height: float = 60.0) -> Control:
	var art := tex("locked_row")
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, height)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if art != null:
		holder.resized.connect(holder.queue_redraw)
		holder.draw.connect(func() -> void:
			PillSkin.draw_slices(holder, art, Rect2(Vector2.ZERO, holder.size), 1.1, Color.WHITE, 0.5))
	else:
		var back := Panel.new()
		back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.add_theme_stylebox_override("panel", Kit.box(Color("5d6578"), Kit.TRIM, 2, 20, 4))
		holder.add_child(back)
	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = height * 0.18
	line.offset_right = -height * 0.5
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(line)
	var lock: TextureRect = Kit.icon("m_lock", height * 0.62)
	lock.custom_minimum_size = Vector2(height * 0.75, height * 0.62)
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(lock)
	var label: Label = Kit.label(text, 18, Color("eef1f7"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	line.add_child(label)
	if note != "":
		var small: Label = Kit.label(note, 16, Color("ffd9a0"), HORIZONTAL_ALIGNMENT_RIGHT)
		small.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		small.size_flags_vertical = Control.SIZE_FILL
		line.add_child(small)
	return holder


## 그림 상자(그림 한 장을 가운데만 늘려 깐 판). 출석 칸·보상 칸·주사위 카드 틀에 쓴다. 그림이 없으면 null.
static func art_box(name: String, corner: float, padding: int = 8) -> PanelContainer:
	var art = style(name, Vector4(corner, corner, corner, corner), Vector4(padding, padding, padding, padding))
	if art == null:
		return null
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", art)
	return box


## 출석 칸 한 개(UI 개편 2단계): 금테 칸(오늘은 금빛, 받은 칸은 어둡게) 안에 위쪽 "N일"과 그 오른쪽 작은 도장,
## 아래에 보상 글. 도장이 보상 글을 가리지 않게 모서리에 작게 찍는다. 그림이 없으면 단색 칸.
static func day_cell(day_number: int, reward_text: String, now: bool, done: bool) -> PanelContainer:
	var cell: PanelContainer = art_box("day_today" if now else ("day_done" if done else "day_cell"), 26.0, 6)
	if cell == null:
		cell = PanelContainer.new()
		cell.add_theme_stylebox_override("panel", Kit.box(Kit.PANEL_LIGHT if now else (Color("13458f") if done else Kit.PANEL), Kit.GOLD, 2, 10, 4))
	else:
		# 칸 위 가운데 보석 장식 아래로 글자를 내린다.
		var art_style := cell.get_theme_stylebox("panel") as StyleBoxTexture
		if art_style != null:
			art_style.content_margin_top = 16
			art_style.content_margin_left = 10
			art_style.content_margin_right = 8
	var ink: Color = Color("5a3200") if now else (Kit.MUTED if done else Color.WHITE)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 0)
	top.custom_minimum_size = Vector2(0, 30)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	var day_label: Label = Kit.label("%d일" % day_number, 18, ink, HORIZONTAL_ALIGNMENT_LEFT if done else HORIZONTAL_ALIGNMENT_CENTER)
	day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(day_label)
	if done:
		var stamp: TextureRect = Kit.icon("check", 30.0)
		var stamp_tex := tex("stamp")
		if stamp_tex != null:
			stamp.texture = stamp_tex
		stamp.custom_minimum_size = Vector2(30, 30)
		stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(stamp)
	var reward: Label = Kit.label(reward_text.replace("  ", "\n"), 18, ink, HORIZONTAL_ALIGNMENT_CENTER)
	reward.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(reward)
	for label in [day_label, reward]:
		if now:
			label.add_theme_constant_override("outline_size", 0)
			label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0))
		else:
			TextStyle.menu(label, Color(0, 0.05, 0.2), 4)
	return cell


## 결과 줄(UI 개편 2단계, result_row): 왼쪽 동그란 금테 자리에 아이콘, 이름(왼쪽), 값(오른쪽, 금색).
## 그림이 없으면 단색 줄.
static func result_row(icon_name: String, title: String, value: String, height: float = 58.0) -> Control:
	var art := tex("result_row")
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, height)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if art != null:
		holder.resized.connect(holder.queue_redraw)
		holder.draw.connect(func() -> void:
			PillSkin.draw_slices(holder, art, Rect2(Vector2.ZERO, holder.size), 0.95, Color.WHITE, 0.3))
	else:
		var back := Panel.new()
		back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.add_theme_stylebox_override("panel", Kit.box(Color("13458f"), Kit.TRIM, 2, int(height / 2.0), 4))
		holder.add_child(back)
	var picture: TextureRect = Kit.icon(icon_name if icon_name != "" else "star", height * 0.62)
	picture.position = Vector2(height * 0.19, height * 0.19)
	picture.size = Vector2(height * 0.62, height * 0.62)
	holder.add_child(picture)
	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = height * 1.12
	line.offset_right = -height * 0.42
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(line)
	var name_label: Label = Kit.label(title, 20, Color.WHITE)
	TextStyle.menu(name_label, Color(0, 0.05, 0.2), 5)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_vertical = Control.SIZE_FILL
	line.add_child(name_label)
	var value_label: Label = Kit.label(value, 21, Kit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	TextStyle.number(value_label, 5)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.size_flags_vertical = Control.SIZE_FILL
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.clip_text = true
	line.add_child(value_label)
	return holder


## 얻은 보상 칸(reward_cell): 금테 정사각 칸에 큰 아이콘과 아래 숫자. 그림이 없으면 단색 칸.
static func reward_cell(icon_name: String, text: String, side: float = 96.0) -> Control:
	var cell: PanelContainer = art_box("reward_cell", 30.0, 6)
	if cell == null:
		cell = PanelContainer.new()
		cell.add_theme_stylebox_override("panel", Kit.box(Color("13458f"), Kit.TRIM, 3, 12, 6))
	cell.custom_minimum_size = Vector2(side, side)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(column)
	var picture: TextureRect = Kit.icon(icon_name, side * 0.48)
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(picture)
	var label: Label = Kit.label(text, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	TextStyle.number(label, 5)
	column.add_child(label)
	return cell
