extends RefCounted
## 화면들이 함께 쓰는 모양(색, 버튼, 글자, 상자). 모든 화면이 같은 느낌이 나도록 여기서만 정한다.

## 2026-11 리뉴얼: 밝고 통통한 캐주얼(하늘색 바탕, 파란 판, 흰 글자, 노랑·주황·초록 버튼).
const ArtView := preload("res://scripts/ui/art_view.gd")
const Gloss := preload("res://scripts/ui/gloss.gd")
const Ambience := preload("res://scripts/ui/ambience.gd")
const Sweep := preload("res://scripts/ui/sweep.gd")
const OrnateBox := preload("res://scripts/ui/ornate_box.gd")
const Ribbon := preload("res://scripts/ui/ribbon.gd")
const UiSkin := preload("res://scripts/ui/skin.gd")
const SkinBar := preload("res://scripts/ui/skin_bar.gd")
## 판 테두리의 금색
const TRIM := Color("f2c14e")
const BG := Color("2a8be6")
## 바탕은 위가 밝고 아래가 짙은 하늘색으로 번진다(sky()).
const BG_TOP := Color("58b8ff")
const BG_BOTTOM := Color("1560c0")
const PANEL := Color("1a56b0")
const PANEL_LIGHT := Color("4f8fe6")
const LINE := Color("8fd0ff")
const TEXT := Color("ffffff")
const MUTED := Color(1, 1, 1, 0.84)
## 줄·칸처럼 판 안에 들어가는 짙은 바탕
const INSET := Color("13458f")
## 가장 중요한 버튼(받기·출전·시작)
const PRIMARY := Color("f39a1c")
const GOLD := Color("ffcf4d")
const GEM := Color("6fd3ff")
const ACCENT := Color("2fb457")
const GOOD := Color("4caf50")
const BAD := Color("e05555")
const DISABLED := Color("6f86a8")
const CATEGORY_COLORS := {
	"영웅": Color("b8352a"),
	"위인": Color("2f6fb5"),
	"신화": Color("6f43a6"),
	"근현대": Color("2a7d4f"),
}
const GRADE_COLORS := {1: Color("9aa4b8"), 2: Color("6fd3ff"), 3: Color("ffcf4d")}
## 광택 아이콘이 없을 때 대신 쓸 도트 아이콘 이름
const ICON_FALLBACK := {"pass": "goal", "todo": "start", "help": "hidden", "attend": "treasure", "missions": "checkpoint",
	"roulette": "fate", "deals": "luck", "swords": "battle", "chat": "start", "adventure": "goal", "friend": "pawn"}
## 골드는 금화 그림 글자(main.gd의 _coin_font가 글꼴에 넣음). 금화 그림이 없으면 "골드" 글자로.
const GOLD_CODE := 0xE000
static var GOLD_ICON := String.chr(GOLD_CODE) if ResourceLoader.exists("res://assets/ui_icons/gold.png") else "골드"
## 글꼴(한글 부분집합)에 마름모 기호가 없어서 웹에서 깨진다. 글자로 쓴다.
const GEM_CODE := 0xE001
static var GEM_ICON := String.chr(GEM_CODE) if ResourceLoader.exists("res://assets/ui_icons/gem.png") else "보석"


static func box(fill: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 12, padding: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style


static func label(text: String, font_size: int = 22, color: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var result := Label.new()
	result.text = text
	result.horizontal_alignment = align
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	# 밝은 바탕에서도 또렷하게: 옅은 그림자
	result.add_theme_color_override("font_shadow_color", Color(0, 0.08, 0.25, 0.45))
	result.add_theme_constant_override("shadow_offset_x", 0)
	result.add_theme_constant_override("shadow_offset_y", 2)
	# 큰 금색 글자는 시안처럼 금색 그라데이션 제목으로(text_style.gd).
	if color == GOLD and font_size >= 28:
		TextStyle.gold(result, 8)
	return result


## 여러 줄로 감기는 글. 긴 설명은 이것을 써야 화면 밖으로 넘치지 않는다.
static func para(text: String, font_size: int = 20, color: Color = MUTED, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var result := label(text, font_size, color, align)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size = Vector2(80, 0)
	return result


static func title(text: String, font_size: int = 44) -> Label:
	var result := label(text, font_size, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	TextStyle.gold(result, 10)
	return result


## 색이 칠해진 버튼. 꺼지면 어두운 회색이 된다.
static func button(text: String, color: Color = ACCENT, font_size: int = 26, height: float = 84.0) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(0, height)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", TEXT)
	result.add_theme_color_override("font_hover_color", TEXT)
	result.add_theme_color_override("font_pressed_color", TEXT)
	result.add_theme_color_override("font_focus_color", TEXT)
	result.add_theme_color_override("font_disabled_color", Color("e3ebf7"))
	paint(result, color)
	result.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return result


## 모두의 마블식 통통한 버튼: 둥근 모서리, 짙은 테두리, 두꺼운 아래 두께, 그림자, 글자 외곽선.
static func paint(target: Button, color: Color, border: Color = Color.TRANSPARENT) -> void:
	var edge: Color = color.darkened(0.6) if border == Color.TRANSPARENT else border
	# 버튼 자체의 상자는 비우고(여백만 남김) 뒤에 붙인 광택 몸통(gloss.gd)이 모양을 그린다.
	for state in ["normal", "hover", "pressed", "disabled"]:
		var space := StyleBoxEmpty.new()
		space.set_content_margin_all(10)
		space.content_margin_bottom = 16
		if state == "pressed":
			space.content_margin_top = 15
			space.content_margin_bottom = 11
		target.add_theme_stylebox_override(state, space)
	var gloss = target.get_node_or_null("Gloss")
	if gloss == null:
		gloss = Gloss.new()
		target.add_child(gloss)
		target.move_child(gloss, 0)
	gloss.paint(color, edge)
	TextStyle.menu(target, color.darkened(0.65), 6)


static func _chunky(fill: Color, edge: Color, bottom: int) -> StyleBoxFlat:
	var style := box(fill, edge, 3, 24)
	style.border_width_bottom = bottom
	style.shadow_color = Color(0, 0.05, 0.2, 0.4)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 3)
	return style


## 지금 화면의 판 기본색. 화면마다 분위기가 다르도록 main.gd가 화면을 바꿀 때 정한다.
static var panel_tint := PANEL


static func panel(fill: Color = PANEL, border: Color = LINE, padding: int = 14) -> PanelContainer:
	var result := PanelContainer.new()
	if fill == PANEL:
		fill = panel_tint
	# 기본 하늘색 테는 금색 장식 테로 바꾼다. 따로 색을 준 판은 그 색 금속 테가 된다.
	result.add_theme_stylebox_override("panel", plate(fill, TRIM if border == LINE else border, 20.0, padding + 4))
	return result


## 장식 판 상자(그림자, 번지는 몸통, 금속 테, 안쪽 선, 귀퉁이 보석). 글·설명 칸, 창, 말풍선에 쓴다.
static func plate(fill: Color = PANEL, trim: Color = TRIM, radius: float = 20.0, padding: int = 16, gems: bool = true) -> StyleBox:
	var style := OrnateBox.new()
	style.fill = fill
	style.trim = trim
	style.radius = radius
	style.gems = gems
	style.set_content_margin_all(padding)
	return style


## 제목 리본(양 끝이 갈라진 깃발 띠).
static func ribbon(text: String, font_size: int = 34, color: Color = Color("7a2fd0")) -> Control:
	return Ribbon.new(text, font_size, color)


## 판 위쪽에 옅은 밝은 면을 얹어 볼록한 유리판처럼 보이게 한다(판 바탕 위, 내용 아래에 그려진다).
static func sheen(target: Control, corner: int = 19, strength: float = 0.1) -> void:
	target.draw.connect(func() -> void:
		var height := minf(target.size.y * 0.5, 64.0)
		if target.size.x < 24.0 or height < 12.0:
			return
		var light := StyleBoxFlat.new()
		light.bg_color = Color(1, 1, 1, strength)
		light.set_corner_radius_all(corner)
		light.anti_aliasing_size = 1.2
		target.draw_style_box(light, Rect2(4, 4, target.size.x - 8, height)))


## 하늘색으로 번지는 바탕 그림(화면 전체를 덮는다).
static func sky() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, BG_TOP)
	gradient.set_color(1, BG_BOTTOM)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 8
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func vbox(separation: int = 10) -> VBoxContainer:
	var result := VBoxContainer.new()
	result.add_theme_constant_override("separation", separation)
	return result


static func hbox(separation: int = 10) -> HBoxContainer:
	var result := HBoxContainer.new()
	result.add_theme_constant_override("separation", separation)
	return result


static func expand(control: Control, ratio: float = 1.0) -> Control:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_stretch_ratio = ratio
	return control


static func spacer(height: float = 0.0, grow: bool = true) -> Control:
	var result := Control.new()
	result.custom_minimum_size = Vector2(0, height)
	if grow:
		result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return result


## 화면 전체를 덮는 배경과, 여백을 둔 세로 상자를 만들어 붙이고 세로 상자를 돌려준다.
## 가로 화면: 왼쪽에 세로 메뉴가 들어갈 자리("Dock")를 두고 그 오른쪽에 내용 기둥을 둔다.
## 아래 메뉴(bottom_nav.gd)는 스스로 이 자리로 옮겨 가 세로 메뉴가 된다.
## max_width가 0보다 크면 내용 기둥을 그 너비로 가운데에 둔다.
static func screen_frame(parent: Control, margin: int = 18, color: Color = BG, max_width: float = 0.0) -> VBoxContainer:
	parent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if color == BG:
		parent.add_child(sky())
	else:
		var background := ColorRect.new()
		background.color = color
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(background)
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, margin)
	parent.add_child(frame)
	var dock := hbox(12)
	dock.name = "Dock"
	frame.add_child(dock)
	var column := vbox(10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if max_width > 0.0:
		column.custom_minimum_size = Vector2(max_width, 0)
		column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	dock.add_child(column)
	return column


## 화면 바탕에 일러스트를 깐다(하늘색 바탕 위). 그림이 없으면 아무것도 하지 않는다.
## 화면 위아래의 글자·버튼이 잘 보이도록 위아래를 살짝 어둡게 한다.
static func backdrop(parent: Control, art_name: String, strength: float = 1.0) -> Control:
	var view := ArtView.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.show_art(art_name)
	view.drift = true
	view.drift_speed = 0.6
	# 가로 화면에서는 바탕 그림을 더 또렷하게 보여 화면마다 분위기가 달라지게 한다.
	view.modulate.a = lerpf(strength, 1.0, 0.7)
	view.fade_top = 0.18
	view.fade_bottom = 0.25
	parent.add_child(view)
	# 바탕 위에 떠다니는 빛 알갱이와 빛줄기
	view.add_child(Ambience.new())
	return view


## 큰 버튼 위를 몇 초마다 훑고 지나가는 빛을 붙인다. 가장 눈에 띄어야 하는 버튼에만 쓴다.
static func shimmer(target: Button, delay: float = 0.0) -> void:
	if target.has_node("Sweep"):
		return
	var sweep := Sweep.new()
	sweep.offset = delay
	target.add_child(sweep)


## 버튼 안쪽에 일러스트를 깔고, 글자가 잘 보이게 아래쪽을 어둡게 한다. 그림이 있으면 true.
static func button_art(target: Button, art_name: String, inset: float = 6.0) -> bool:
	var view := ArtView.new()
	view.show_art(art_name)
	if not view.has_art():
		view.free()
		return false
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.offset_left = inset
	view.offset_top = inset
	view.offset_right = -inset
	view.offset_bottom = -inset - 4.0
	view.focus_y = 0.5
	view.fade_bottom = 0.6
	view.shade = Color(0, 0, 0, 0.08)
	target.add_child(view)
	target.move_child(view, 0)
	return true


## 가로로 꽉 차는 진행 막대. value는 0~1.
static func bar(value: float, color: Color, height: float = 14.0) -> ProgressBar:
	var result := ProgressBar.new()
	result.min_value = 0.0
	result.max_value = 1.0
	result.value = clampf(value, 0.0, 1.0)
	result.show_percentage = false
	result.custom_minimum_size = Vector2(0, height)
	result.add_theme_stylebox_override("background", box(Color(0, 0.1, 0.3, 0.55), Color.TRANSPARENT, 0, 7, 0))
	result.add_theme_stylebox_override("fill", box(color, Color.TRANSPARENT, 0, 7, 0))
	# 그림 막대: 금빛/푸른빛 광택 막대 그림이 있으면 채움을 그림으로 그린다.
	var tone: String = UiSkin.tone(color)
	var art := "bar_fill_gold" if tone in ["gold", "red"] else ("bar_fill_blue" if tone in ["blue", "teal"] else "")
	if art != "" and UiSkin.has(art):
		var fill := SkinBar.new()
		fill.art = art
		result.add_theme_stylebox_override("fill", fill)
	return result


static func money_text(currency: String, amount: int) -> String:
	return "%s %s" % [GOLD_ICON if currency == "gold" else GEM_ICON, comma(amount)]


static func comma(value: int) -> String:
	var text := str(abs(value))
	var out := ""
	while text.length() > 3:
		out = "," + text.right(3) + out
		text = text.left(text.length() - 3)
	return ("-" if value < 0 else "") + text + out


static func reward_line(reward: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(reward.get("gold", 0)) != 0:
		parts.append(money_text("gold", int(reward["gold"])))
	if int(reward.get("gems", 0)) != 0:
		parts.append(money_text("gems", int(reward["gems"])))
	return "  ".join(parts)


## 아이콘. 광택 그림 아이콘(assets/ui_icons/이름.png)이 있으면 그것을, 없으면 도트 아이콘(assets/icons)을 쓴다.
static func icon(name: String, pixels: float = 54.0) -> TextureRect:
	var rect := TextureRect.new()
	var glossy := "res://assets/ui_icons/%s.png" % name
	var path := "res://assets/icons/%s.png" % str(ICON_FALLBACK.get(name, name))
	if ResourceLoader.exists(glossy):
		rect.texture = load(glossy)
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	elif ResourceLoader.exists(path):
		rect.texture = load(path)
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(pixels, pixels)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## 모두의 마블식 큰 버튼: 왼쪽에 아이콘, 오른쪽에 굵은 제목과 작은 설명.
static func icon_button(text: String, icon_name: String, color: Color, font_size: int = 28, height: float = 96.0, sub: String = "") -> Button:
	var result := button("", color, font_size, height)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -4
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)
	row.add_child(icon(icon_name, minf(height - 30.0, 72.0)))
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var main := label(text, font_size)
	main.add_theme_constant_override("outline_size", 7)
	main.add_theme_color_override("font_outline_color", color.darkened(0.6))
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(main)
	if sub != "":
		var small := label(sub, maxi(17, int(font_size * 0.5)), Color(1, 1, 1, 0.9))
		small.add_theme_constant_override("outline_size", 4)
		small.add_theme_color_override("font_outline_color", color.darkened(0.6))
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(small)
	return result


## 네모 타일 버튼: 위에 아이콘, 아래에 이름과 작은 설명. 로비의 모드 고르기에 쓴다.
static func tile_button(text: String, icon_name: String, color: Color, sub: String = "", height: float = 150.0, art_name: String = "") -> Button:
	var result := button("", color, 26, height)
	var painted := art_name != "" and button_art(result, art_name)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 8
	column.offset_bottom = -14
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_child(column)
	if painted:
		# 그림이 있으면 아이콘 대신 그림이 보이도록 글자를 아래로 내린다.
		column.alignment = BoxContainer.ALIGNMENT_END
	else:
		var picture := icon(icon_name, 60.0)
		picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(picture)
	var main := label(text, 26, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	main.add_theme_constant_override("outline_size", 7)
	main.add_theme_color_override("font_outline_color", color.darkened(0.6))
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(main)
	if sub != "":
		var small := label(sub, 16, Color(1, 1, 1, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
		small.add_theme_constant_override("outline_size", 4)
		small.add_theme_color_override("font_outline_color", color.darkened(0.6))
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(small)
	# 큰 타일 버튼은 저마다 다른 때에 빛이 훑고 지나간다.
	shimmer(result, float(text.length() % 5) * 0.6)
	return result


## 몸통 없는 아이콘 바로가기(그림 아이콘 + 아래 글자). 누르면 살짝 줄었다 튄다. badge가 true면 빨간 점.
static func icon_shortcut(text: String, icon_name: String, badge: bool = false, pixels: float = 62.0) -> Button:
	var result := Button.new()
	result.custom_minimum_size = Vector2(pixels + 10.0, pixels + 28.0)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		result.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_child(column)
	var picture := icon(icon_name, pixels)
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(picture)
	var caption := label(text, 17, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	caption.add_theme_constant_override("outline_size", 6)
	caption.add_theme_color_override("font_outline_color", Color("0c2f6e"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption)
	if badge:
		var dot := Panel.new()
		dot.add_theme_stylebox_override("panel", box(Color("ff3b3b"), Color.WHITE, 2, 10, 0))
		dot.anchor_left = 1.0
		dot.anchor_right = 1.0
		dot.offset_left = -24
		dot.offset_right = -4
		dot.offset_top = 0
		dot.offset_bottom = 20
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		result.add_child(dot)
	result.button_down.connect(func() -> void:
		result.pivot_offset = result.size * 0.5
		result.create_tween().tween_property(result, "scale", Vector2(0.88, 0.88), 0.05))
	result.button_up.connect(func() -> void:
		var tween := result.create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(result, "scale", Vector2.ONE, 0.2))
	return result


## 동그란 바로가기 버튼(아이콘 + 아래 글자). badge가 true면 오른쪽 위 빨간 점.
static func round_shortcut(text: String, icon_name: String, color: Color, badge: bool = false) -> Button:
	var result := Button.new()
	result.custom_minimum_size = Vector2(88, 88)
	paint(result, color)
	result.get_node("Gloss").radius = 44.0
	result.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 6
	column.offset_bottom = -8
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_child(column)
	var picture := icon(icon_name, 40.0)
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(picture)
	var caption := label(text, 16, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	caption.add_theme_constant_override("outline_size", 4)
	caption.add_theme_color_override("font_outline_color", color.darkened(0.6))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption)
	if badge:
		var dot := Panel.new()
		dot.add_theme_stylebox_override("panel", box(Color("ff3b3b"), Color.WHITE, 2, 10, 0))
		dot.custom_minimum_size = Vector2(20, 20)
		dot.position = Vector2(66, 2)
		dot.size = Vector2(20, 20)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		result.add_child(dot)
	return result


## other 안의 점(point)을 home 안의 좌표로 바꾼다. 화면이 돌아가 있어도 맞게 나온다
## (global_position끼리 빼면 돌린 화면에서 방향이 틀어진다).
static func spot_in(home: CanvasItem, other: CanvasItem, point: Vector2) -> Vector2:
	return home.get_global_transform().affine_inverse() * (other.get_global_transform() * point)


## 번역된 글이 칸(holder)보다 넓으면 글자 크기를 줄여 맞춘다(영어·베트남어는 한국어보다 길다).
## reserve: holder 안에서 글 말고 다른 것(아이콘·여백)이 차지하는 너비.
static func fit_text(label: Label, holder: Control, reserve: float, base_size: int, min_size: int = 12) -> void:
	var fit := func() -> void:
		var room := holder.size.x - reserve
		if room <= 0.0:
			return
		var font := label.get_theme_font("font")
		var shown := label.tr(label.text)
		var size := base_size
		while size > min_size and font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room:
			size -= 1
		label.add_theme_font_size_override("font_size", size)
	holder.resized.connect(fit)


## 긴 글자를 칸 너비에 맞춘다: 먼저 글자를 smallest까지 줄이고, 그래도 넘치면 자간을 좁힌다.
## 칸 크기가 바뀔 때마다 다시 맞추도록 resized에도 걸어 둔다(처음 한 번만 걸린다).
static func squeeze_text(label: Label, largest: int, smallest: int) -> void:
	if not label.has_meta("fit_hooked"):
		label.set_meta("fit_hooked", true)
		# 글자 크기를 바꾸면 높이가 바뀌어 resized가 다시 오므로, 너비가 바뀔 때만 다시 맞춘다(무한 반복 방지).
		label.resized.connect(func() -> void:
			if absf(float(label.get_meta("fit_width", -1.0)) - label.size.x) < 0.5:
				return
			label.set_meta("fit_width", label.size.x)
			_refit(label, largest, smallest))
	label.set_meta("fit_width", label.size.x)
	_refit(label, largest, smallest)


static func _refit(label: Label, largest: int, smallest: int) -> void:
	var room := label.size.x - 4.0
	label.add_theme_font_size_override("font_size", largest)
	if label.has_meta("fit_base_font"):
		label.add_theme_font_override("font", label.get_meta("fit_base_font"))
		label.remove_meta("fit_base_font")
	var font := label.get_theme_font("font")
	var shown := label.tr(label.text)
	if font == null or room <= 0.0 or shown == "":
		return
	var font_size := largest
	while font_size > smallest and font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)
	var width := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if width <= room:
		return
	# 가장 작게 해도 넘치면 글자 사이를 좁힌다(글자당 최대 4픽셀).
	var count: int = maxi(shown.length() - 1, 1)
	var squeeze: int = mini(int(ceil((width - room) / float(count))), 4)
	var tight := FontVariation.new()
	tight.base_font = font
	tight.spacing_glyph = -squeeze
	label.set_meta("fit_base_font", font)
	label.add_theme_font_override("font", tight)
