extends PanelContainer
## 화면 아래 메뉴 띠: 홈, 영웅, 상점, 미션, 설정. 받을 보상이 있으면 빨간 점을 붙인다.

const Kit := preload("res://scripts/ui/kit.gd")

signal tab_pressed(screen_name: String)

const TABS := [
	["lobby", "홈"],
	["heroes", "영웅"],
	["shop", "상점"],
	["missions", "미션"],
	["settings", "설정"],
]

var _buttons: Dictionary = {}
var _dots: Dictionary = {}


func setup(active: String, badges: Dictionary) -> void:
	add_theme_stylebox_override("panel", Kit.box(Color("0d1026"), Kit.LINE, 2, 16, 6))
	var row := Kit.hbox(6)
	add_child(row)
	for spec in TABS:
		var screen_name: String = spec[0]
		var on := screen_name == active
		var button := Kit.button(spec[1], Kit.PANEL_LIGHT if on else Color("161a36"), 24, 78)
		if on:
			Kit.paint(button, Kit.PANEL_LIGHT, Kit.GOLD)
			button.add_theme_color_override("font_color", Kit.GOLD)
		Kit.expand(button)
		button.pressed.connect(_on_pressed.bind(screen_name))
		row.add_child(button)
		_buttons[screen_name] = button
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
