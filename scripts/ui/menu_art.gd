extends RefCounted
## 메뉴 화면 공통 그림 부품(ChatGPT가 그린 것, 2026-11-17) `assets/ui_menu/`.
## 왼쪽 세로 메뉴 판·버튼, 위 띠, 제목 명판, 재화 캡슐, 더하기 버튼, 영웅 카드 테두리, 목록 줄, 탭, 큰 판.
## 그림이 없으면 null을 돌려주고, 부르는 쪽은 예전 모양으로 그린다.

const ART := "res://assets/ui_menu/"

## 화면 이름 → [제목, 아이콘]. 위 띠 왼쪽 제목 명판에 쓴다.
const TITLES := {
	"heroes": ["영웅", "heroes"],
	"shop": ["상점", "shop"],
	"missions": ["미션", "missions"],
	"settings": ["설정", "settings"],
	"adventure": ["모험", "adventure"],
	"pass": ["시즌 패스", "pass"],
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
	label.add_theme_font_size_override("font_size", 25)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0.05, 0.2))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 70
	label.offset_right = -16
	label.offset_bottom = -2
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(label)
	return plate
