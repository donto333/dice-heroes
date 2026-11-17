extends RefCounted
## 메뉴 화면 공통 그림 부품(ChatGPT가 그린 것, 2026-11-17) `assets/ui_menu/`.
## 왼쪽 세로 메뉴 판·버튼, 위 띠, 제목 명판, 재화 캡슐, 더하기 버튼, 영웅 카드 테두리, 목록 줄, 탭, 큰 판.
## 그림이 없으면 null을 돌려주고, 부르는 쪽은 예전 모양으로 그린다.

const Kit := preload("res://scripts/ui/kit.gd")

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
static func frame(screen: Control, app, backdrop_art: String, tabs: Array, active: String, on_tab: Callable) -> VBoxContainer:
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(Kit.sky())
	if backdrop_art != "":
		Kit.backdrop(screen, backdrop_art, 1.0)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.03, 0.14, 0.38)
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
	var home := Button.new()
	home.custom_minimum_size = Vector2(72, 64)
	home.tooltip_text = "로비로"
	if not skin_button(home, "menu_off", Vector4(30, 26, 30, 26), Vector4(4, 4, 4, 4)):
		Kit.paint(home, Kit.PANEL_LIGHT)
	var home_icon: TextureRect = Kit.icon("home", 40.0)
	home_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	home_icon.offset_left = 18
	home_icon.offset_right = -18
	home_icon.offset_top = 8
	home_icon.offset_bottom = -10
	home_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	home_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	home_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.add_child(home_icon)
	home.pressed.connect(func() -> void:
		app.play("click")
		app.go("lobby"))
	head.add_child(home)
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
			list.add_child(_rail_button(entry, str(entry[0]) == active, on_tab))
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
	if not skin_button(button, "menu_on" if on else "menu_off", Vector4(30, 26, 30, 26), Vector4(16, 4, 12, 6)):
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


## 위 줄 재화 캡슐(아이콘 + 오른쪽 정렬 숫자).
static func _money_chip(icon_name: String, amount: int, color: Color) -> Control:
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
	return capsule
