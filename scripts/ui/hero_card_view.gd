extends RefCounted
## 편성과 영웅 목록이 공유하는 금테 영웅 카드.

const KitStyle := preload("res://scripts/ui/kit.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const GOLD := Color("ffcf4d")

const CATEGORY_PLATES := {
	"영웅": "category_plate_hero",
	"위인": "category_plate_great",
	"신화": "category_plate_myth",
	"근현대": "category_plate_modern",
}
## 초상화가 창 너비의 64%를 차지하고 나머지는 능력치가 쓴다.
const HERO_WINDOW_X := Vector2(0.092, 0.91)
const HERO_STAT_SPLIT := 0.616
const HERO_WINDOW_BOTTOM := 0.61
const CLASSIC_HERO_WINDOW_TOP := 0.15



## 금테 영웅 카드: 창 안에 왼쪽 초상화·오른쪽 능력치, 아래 두 띠에 이름과 ★·레벨.
static func mount(button: Button, character: Dictionary, accent: Color, footer: String) -> Dictionary:
	var observatory := KitStyle.Observatory.active
	var window_top: float = 0.084 if observatory else CLASSIC_HERO_WINDOW_TOP
	var photo_bottom := 0.64 if observatory else HERO_WINDOW_BOTTOM
	var name_bottom := 0.792 if observatory else 0.774
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("0f3d85") if state != "hover" else Color("1a4fa0")
		fill.set_corner_radius_all(10)
		fill.expand_margin_left = -6
		fill.expand_margin_right = -6
		fill.expand_margin_top = -10
		fill.expand_margin_bottom = -8
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new() if observatory else fill)
	var portrait := Portrait.new()
	portrait.focus_y = 0.0
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 머리가 금테와 위쪽 보석에 가리지 않도록 틀의 투명한 창에서 시작한다.
	portrait.anchor_left = 0.054 if observatory else HERO_WINDOW_X.x
	portrait.anchor_right = HERO_STAT_SPLIT
	portrait.anchor_top = window_top
	portrait.anchor_bottom = photo_bottom
	portrait.border_width = 0.0
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.show_character(character, accent)
	button.add_child(portrait)
	var stat_size := 17 if button.custom_minimum_size.y >= 250.0 else 15
	button.add_child(_hero_stats(character, window_top, stat_size, photo_bottom, 0.948 if observatory else HERO_WINDOW_X.y))
	var frame := _hero_frame(observatory)
	button.add_child(frame)
	# 기존 능력치 자리 전체를 이름에 쓰고 긴 번역은 칸 너비에 맞춘다.
	var plate := nameplate(Vector2(0.044 if observatory else HERO_WINDOW_X.x, photo_bottom), Vector2(0.956 if observatory else HERO_WINDOW_X.y, name_bottom))
	plate.texture = category_plate(str(character["category"]))
	button.add_child(plate)
	var name_label := band_label(str(character["name"]), 22, photo_bottom, name_bottom)
	name_label.offset_left = 0
	name_label.offset_right = 0
	name_label.anchor_left = 0.1
	name_label.anchor_right = 0.9
	button.add_child(name_label)
	KitStyle.squeeze_text(name_label, 22, 10)
	var band := Vector2(0.792, 0.918) if observatory else MenuArt.HERO_NAME_BAND
	var grade_text := "★".repeat(int(character["grade"]))
	if footer != "":
		grade_text += "  " + footer
	var grade := band_label(grade_text, 22, band.x, band.y)
	grade.add_theme_color_override("font_color", GOLD)
	button.add_child(grade)
	KitStyle.squeeze_text(grade, 22, 13)
	return {"portrait": portrait, "frame": frame}



## 초상화와 능력치 위에 창이 뚫린 테를 얹고 선택 상태를 반영한다.
static func _hero_frame(observatory: bool) -> Control:
	var frame := Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var normal := MenuArt.tex("friend_party/hero_frame" if observatory else "hero_card")
	frame.draw.connect(func() -> void:
		var glow := Color(1.18, 1.1, 1.0) if observatory and frame.get_meta("selected", false) else Color.WHITE
		frame.draw_texture_rect(normal, Rect2(Vector2.ZERO, frame.size), false, glow))
	frame.resized.connect(frame.queue_redraw)
	return frame


## 좁은 칸에서도 다섯 능력치가 한 줄씩 읽히도록 오른쪽에 배치한다.
static func _hero_stats(character: Dictionary, window_top: float, font_size: int, bottom: float, right: float) -> Control:
	var panel := Panel.new()
	panel.name = "HeroStats"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = HERO_STAT_SPLIT
	panel.anchor_right = right
	panel.anchor_top = window_top
	panel.anchor_bottom = bottom
	panel.add_theme_stylebox_override("panel", KitStyle.box(Color("142345"), Color("465984"), 1, 0, 0))
	var values := ["이동 %d" % int(character["move"]), "공 %d" % int(character["attack"]),
		"방 %d" % int(character["defense"]), "지 %d" % int(character["intellect"]),
		"충 %d" % (100 + int(character.get("charge", 0)))]
	for index in values.size():
		var label := band_label(values[index], font_size, float(index) / values.size(), float(index + 1) / values.size())
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.offset_left = 5
		label.offset_right = -4
		panel.add_child(label)
		KitStyle.squeeze_text(label, font_size, 11)
	return panel


## 카드 안 가로 띠 글자(위·아래 비율 사이에 가운데 정렬).
static func band_label(text: String, font_size: int, top: float, bottom: float) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
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


static func category_plate(category: String) -> Texture2D:
	var asset: String = CATEGORY_PLATES.get(category, "")
	return MenuArt.tex(asset) if asset != "" else null


static func nameplate(start: Vector2, end: Vector2) -> TextureRect:
	var plate := TextureRect.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.anchor_left = start.x
	plate.anchor_top = start.y
	plate.anchor_right = end.x
	plate.anchor_bottom = end.y
	return plate
