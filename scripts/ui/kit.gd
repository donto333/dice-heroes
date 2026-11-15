extends RefCounted
## 화면들이 함께 쓰는 모양(색, 버튼, 글자, 상자). 모든 화면이 같은 느낌이 나도록 여기서만 정한다.

## 2026-11 리뉴얼: 밝고 통통한 캐주얼(하늘색 바탕, 파란 판, 흰 글자, 노랑·주황·초록 버튼).
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
const GOLD_ICON := "●"
## 글꼴(한글 부분집합)에 마름모 기호가 없어서 웹에서 깨진다. 글자로 쓴다.
const GEM_ICON := "보석"


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
	return result


## 여러 줄로 감기는 글. 긴 설명은 이것을 써야 화면 밖으로 넘치지 않는다.
static func para(text: String, font_size: int = 20, color: Color = MUTED, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var result := label(text, font_size, color, align)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size = Vector2(80, 0)
	return result


static func title(text: String, font_size: int = 44) -> Label:
	var result := label(text, font_size, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	result.add_theme_constant_override("outline_size", 10)
	result.add_theme_color_override("font_outline_color", Color("4a2f00"))
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
	result.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	paint(result, color)
	result.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return result


## 모두의 마블식 통통한 버튼: 둥근 모서리, 짙은 테두리, 두꺼운 아래 두께, 그림자, 글자 외곽선.
static func paint(target: Button, color: Color, border: Color = Color.TRANSPARENT) -> void:
	var edge: Color = color.darkened(0.55) if border == Color.TRANSPARENT else border
	target.add_theme_stylebox_override("normal", _chunky(color, edge, 8))
	target.add_theme_stylebox_override("hover", _chunky(color.lightened(0.12), edge, 8))
	var pressed := _chunky(color.darkened(0.15), edge, 3)
	pressed.content_margin_top += 5
	target.add_theme_stylebox_override("pressed", pressed)
	var off := _chunky(DISABLED, DISABLED.darkened(0.4), 5)
	off.shadow_size = 0
	target.add_theme_stylebox_override("disabled", off)
	target.add_theme_constant_override("outline_size", 5)
	target.add_theme_color_override("font_outline_color", color.darkened(0.6))


static func _chunky(fill: Color, edge: Color, bottom: int) -> StyleBoxFlat:
	var style := box(fill, edge, 3, 24)
	style.border_width_bottom = bottom
	style.shadow_color = Color(0, 0.05, 0.2, 0.4)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 3)
	return style


static func panel(fill: Color = PANEL, border: Color = LINE, padding: int = 14) -> PanelContainer:
	var result := PanelContainer.new()
	var style := box(fill, border, 3, 22, padding)
	style.shadow_color = Color(0, 0.05, 0.2, 0.35)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	result.add_theme_stylebox_override("panel", style)
	return result


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
static func screen_frame(parent: Control, margin: int = 18, color: Color = BG) -> VBoxContainer:
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
	var column := vbox(12)
	frame.add_child(column)
	return column


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


## 도트 아이콘(assets/icons/이름.png)을 정수 배로 또렷하게 키워 보여 준다.
static func icon(name: String, pixels: float = 54.0) -> TextureRect:
	var rect := TextureRect.new()
	var path := "res://assets/icons/%s.png" % name
	if ResourceLoader.exists(path):
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


## 동그란 바로가기 버튼(아이콘 + 아래 글자). badge가 true면 오른쪽 위 빨간 점.
static func round_shortcut(text: String, icon_name: String, color: Color, badge: bool = false) -> Button:
	var result := Button.new()
	result.custom_minimum_size = Vector2(88, 88)
	var normal := box(color, color.darkened(0.55), 3, 44, 6)
	normal.border_width_bottom = 7
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 5
	normal.shadow_offset = Vector2(0, 3)
	result.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = color.lightened(0.12)
	result.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = color.darkened(0.15)
	pressed.border_width_bottom = 3
	result.add_theme_stylebox_override("pressed", pressed)
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
