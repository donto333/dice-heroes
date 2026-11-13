extends RefCounted
## 화면들이 함께 쓰는 모양(색, 버튼, 글자, 상자). 모든 화면이 같은 느낌이 나도록 여기서만 정한다.

const BG := Color("12152b")
const PANEL := Color("1d2246")
const PANEL_LIGHT := Color("2a3164")
const LINE := Color("3a4466")
const TEXT := Color("ffffff")
const MUTED := Color(1, 1, 1, 0.65)
const GOLD := Color("ffcf4d")
const GEM := Color("6fd3ff")
const ACCENT := Color("2f80ed")
const GOOD := Color("4caf50")
const BAD := Color("e05555")
const DISABLED := Color("2a2f4a")
const CATEGORY_COLORS := {
	"영웅": Color("b8352a"),
	"위인": Color("2f6fb5"),
	"신화": Color("6f43a6"),
	"근현대": Color("2a7d4f"),
}
const GRADE_COLORS := {1: Color("9aa4b8"), 2: Color("6fd3ff"), 3: Color("ffcf4d")}
const GOLD_ICON := "●"
const GEM_ICON := "◆"


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


static func paint(target: Button, color: Color, border: Color = Color.TRANSPARENT) -> void:
	var edge: Color = color.lightened(0.35) if border == Color.TRANSPARENT else border
	var normal := box(color, edge, 2)
	normal.border_width_bottom = 6
	normal.border_color = edge
	target.add_theme_stylebox_override("normal", normal)
	var hover := box(color.lightened(0.1), Color.WHITE, 2)
	hover.border_width_bottom = 6
	target.add_theme_stylebox_override("hover", hover)
	var pressed := box(color.darkened(0.2), Color.WHITE, 2)
	pressed.border_width_top = 5
	target.add_theme_stylebox_override("pressed", pressed)
	target.add_theme_stylebox_override("disabled", box(DISABLED, DISABLED, 0))


static func panel(fill: Color = PANEL, border: Color = LINE, padding: int = 14) -> PanelContainer:
	var result := PanelContainer.new()
	result.add_theme_stylebox_override("panel", box(fill, border, 2, 14, padding))
	return result


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
	result.add_theme_stylebox_override("background", box(Color(0, 0, 0, 0.4), Color.TRANSPARENT, 0, 7, 0))
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
