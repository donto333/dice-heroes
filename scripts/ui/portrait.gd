extends Control
## 캐릭터 초상화 칸.
## 그림(assets/portraits/<id>.jpg)이 있으면 칸 크기에 맞게 잘라 그리고,
## 아직 그림이 없는 캐릭터는 분류 색 바탕에 이름 첫 글자를 크게 그린다.
## 버튼 안에 넣어도 누르기를 막지 않도록 마우스 입력은 무시한다.

const GameData := preload("res://scripts/game_data.gd")

var texture: Texture2D = null
var fill := Color("3a4466")
var border := Color(1, 1, 1, 0.55)
var border_width := 3.0
var letter := ""
## 골라 둔 카드처럼 어둡게 보일 때
var dim := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 일러스트는 도트가 아니므로 부드럽게 줄인다. (프로젝트 기본값은 도트용 nearest)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	clip_contents = true
	resized.connect(queue_redraw)


## character: data/characters.json의 캐릭터 한 명. 비어 있으면 빈 칸으로 그린다.
func show_character(character: Dictionary, color: Color) -> void:
	fill = color
	if character.is_empty():
		texture = null
		letter = ""
	else:
		texture = GameData.portrait(str(character.get("id", "")))
		letter = str(character.get("name", "")).left(1)
	queue_redraw()


## 몬스터나 키퍼처럼 캐릭터가 아닌 상대. 그림 없이 글자만 그린다.
func show_text(text: String, color: Color) -> void:
	fill = color
	texture = null
	letter = text.left(1)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if size.x <= 1.0 or size.y <= 1.0:
		return
	draw_rect(rect, fill.darkened(0.35))
	if texture != null:
		draw_texture_rect_region(texture, rect, _crop(texture.get_size()))
	elif letter != "":
		# 위쪽이 밝은 바탕에 첫 글자
		draw_rect(Rect2(0, 0, size.x, size.y * 0.5), fill.darkened(0.15))
		var font := get_theme_default_font()
		var font_size := int(min(size.x, size.y) * 0.5)
		var baseline := size.y * 0.5 + font_size * 0.36
		draw_string(font, Vector2(0, baseline), letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size,
				Color(1, 1, 1, 0.85))
	if dim:
		draw_rect(rect, Color(0, 0, 0, 0.5))
	if border_width > 0.0:
		draw_rect(rect.grow(-border_width / 2.0), border, false, border_width)


## 칸 비율에 맞게 그림의 가운데를 잘라 낸다. 가로로 긴 칸이면 얼굴이 남도록 위쪽을 쓴다.
func _crop(texture_size: Vector2) -> Rect2:
	var ratio := size.x / size.y
	if ratio >= texture_size.x / texture_size.y:
		var height := texture_size.x / ratio
		return Rect2(0, (texture_size.y - height) * 0.2, texture_size.x, height)
	var width := texture_size.y * ratio
	return Rect2((texture_size.x - width) / 2.0, 0, width, texture_size.y)
