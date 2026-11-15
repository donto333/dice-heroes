extends PanelContainer
## 화면 아래 메뉴 띠: 홈, 영웅, 상점, 미션, 설정. 탭마다 그림 아이콘과 이름이 있고,
## 지금 화면의 탭은 노랗게 솟아 보인다. 받을 보상이 있으면 빨간 점을 붙인다.

const Kit := preload("res://scripts/ui/kit.gd")

signal tab_pressed(screen_name: String)

## [화면 이름, 글자, 아이콘]
const TABS := [
	["lobby", "홈", "home"],
	["heroes", "영웅", "heroes"],
	["shop", "상점", "shop"],
	["missions", "미션", "missions"],
	["settings", "설정", "settings"],
]

var _buttons: Dictionary = {}
var _dots: Dictionary = {}


func setup(active: String, badges: Dictionary) -> void:
	var frame := Kit.box(Color("0f3d85"), Kit.LINE, 3, 28, 8)
	frame.border_width_bottom = 5
	frame.shadow_color = Color(0, 0.05, 0.2, 0.4)
	frame.shadow_size = 6
	frame.shadow_offset = Vector2(0, 3)
	add_theme_stylebox_override("panel", frame)
	var row := Kit.hbox(6)
	add_child(row)
	for spec in TABS:
		var screen_name: String = spec[0]
		var on := screen_name == active
		var color := Color("ffc62b") if on else Color("2f74d6")
		var button := Kit.button("", color, 20, 104)
		Kit.expand(button)
		button.pressed.connect(_on_pressed.bind(screen_name))
		row.add_child(button)
		_buttons[screen_name] = button
		# 아이콘 위, 이름 아래
		var column := VBoxContainer.new()
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.offset_top = 2
		column.offset_bottom = -16
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", -8)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(column)
		var picture := Kit.icon(str(spec[2]), 50.0 if on else 44.0)
		picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(picture)
		var caption := Kit.label(str(spec[1]), 21 if on else 19, Color("5a3200") if on else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		if not on:
			caption.add_theme_constant_override("outline_size", 5)
			caption.add_theme_color_override("font_outline_color", color.darkened(0.65))
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(caption)
		var dot := Panel.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_theme_stylebox_override("panel", Kit.box(Kit.BAD, Color.WHITE, 2, 10, 0))
		dot.custom_minimum_size = Vector2(20, 20)
		dot.size = Vector2(20, 20)
		dot.anchor_left = 1.0
		dot.anchor_right = 1.0
		dot.offset_left = -26
		dot.offset_right = -6
		dot.offset_top = 6
		dot.offset_bottom = 26
		dot.visible = bool(badges.get(screen_name, false))
		button.add_child(dot)
		_dots[screen_name] = dot


func _on_pressed(screen_name: String) -> void:
	tab_pressed.emit(screen_name)
