extends Control
## 캐릭터 초상화 칸.
## 그림(assets/portraits/<id>.jpg)이 있으면 칸 크기에 맞게 잘라 그리고,
## 아직 그림이 없는 캐릭터는 분류 색 바탕에 이름 첫 글자를 크게 그린다.
## 버튼 안에 넣어도 누르기를 막지 않도록 마우스 입력은 무시한다.

const GameData := preload("res://scripts/game_data.gd")

var texture: Texture2D = null
## 크게 보여 주는 칸이면 true로 둔다(고해상도 그림을 쓴다). show_character() 전에 정한다.
var hd := false
var fill := Color("3a4466")
var border := Color(1, 1, 1, 0.55)
var border_width := 3.0
var letter := ""
## 0 이상이면 적 그림 시트(assets/terrain/monsters.png)의 그 번째 그림을 그린다.
var monster := -1
static var _monster_sheet: Texture2D = null
## 골라 둔 카드처럼 어둡게 보일 때
var dim := false
## 아직 가지지 않은 영웅. 흑백에 가깝게 아주 어둡게 그린다.
var locked := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 일러스트는 도트가 아니므로 부드럽게 줄인다. (프로젝트 기본값은 도트용 nearest)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	clip_contents = true
	resized.connect(queue_redraw)


## character: data/characters.json의 캐릭터 한 명. 비어 있으면 빈 칸으로 그린다.
func show_character(character: Dictionary, color: Color) -> void:
	monster = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fill = color
	if character.is_empty():
		texture = null
		letter = ""
	else:
		var id := str(character.get("id", ""))
		texture = GameData.portrait_hd(id) if hd else GameData.portrait(id)
		letter = str(character.get("name", "")).left(1)
	queue_redraw()


## 키퍼·몬스터: 보드에 서 있는 것과 같은 적 그림을 크게 보여 준다. 그림이 없으면 글자.
func show_monster(kind: int, text: String, color: Color) -> void:
	show_text(text, color)
	# 그려 둔 적 초상화가 있으면 그것을 쓴다. 없으면 보드의 도트 적 그림.
	var painted := GameData.enemy_portrait(text)
	if painted != null:
		texture = painted
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		queue_redraw()
		return
	if _monster_sheet == null and ResourceLoader.exists("res://assets/terrain/monsters.png"):
		_monster_sheet = load("res://assets/terrain/monsters.png")
	monster = kind if _monster_sheet != null else -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if monster >= 0 else CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()


## 몬스터나 키퍼처럼 캐릭터가 아닌 상대. 그림 없이 글자만 그린다.
func show_text(text: String, color: Color) -> void:
	fill = color
	texture = null
	monster = -1
	letter = text.left(1)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if size.x <= 1.0 or size.y <= 1.0:
		return
	draw_rect(rect, fill.darkened(0.35))
	if texture != null:
		var tint := Color(0.32, 0.33, 0.4) if locked else Color.WHITE
		draw_texture_rect_region(texture, rect, _crop(texture.get_size()), tint)
	elif monster >= 0 and _monster_sheet != null:
		# 도트 그림이라 흐려지지 않게 그대로 키운다.
		draw_rect(Rect2(0, 0, size.x, size.y * 0.62), fill.lightened(0.12))
		var side: float = min(size.x, size.y) * 0.86
		draw_texture_rect_region(_monster_sheet, Rect2((size.x - side) / 2.0, size.y - side - size.y * 0.04, side, side), Rect2(monster * 32, 0, 32, 32))
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
