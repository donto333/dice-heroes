extends Control
## 일러스트 한 장을 칸에 꽉 차게(비율 유지, 넘치는 쪽은 잘라서) 그린다.
## drift를 켜면 천천히 확대·이동해서 살아 있는 느낌을 준다(오프닝, 타이틀, 로딩).
## 그림 파일이 없으면 아무것도 그리지 않으므로, 그림이 없어도 기존 화면 모양이 그대로 남는다.
## 버튼 안에 넣어도 누르기를 막지 않도록 마우스 입력은 무시한다.

const GameData := preload("res://scripts/game_data.gd")

var texture: Texture2D = null
## 그림 위에 덮는 색(글자를 또렷하게 할 때). 투명이면 덮지 않는다.
var shade := Color(0, 0, 0, 0)
## 위아래로 어두워지는 띠(0이면 없음). 그림 위에 글자를 올릴 때 쓴다.
var fade_top := 0.0
var fade_bottom := 0.0
## 얼굴이나 주인공이 잘리지 않도록 세로로 어디를 보여 줄지(0 위, 0.5 가운데, 1 아래)
var focus_y := 0.4
## 천천히 움직이기
var drift := false
var drift_speed := 1.0
var corner_radius := 0.0
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	clip_contents = true
	resized.connect(queue_redraw)


## 경로의 그림을 쓴다. 예: show_art("ui/title_keyart") → res://assets/art/ui/title_keyart.jpg
func show_art(name: String) -> void:
	texture = GameData.art(name)
	queue_redraw()


func has_art() -> bool:
	return texture != null


func _process(delta: float) -> void:
	if drift and texture != null and is_visible_in_tree():
		_time += delta * drift_speed
		queue_redraw()


func _draw() -> void:
	if texture == null or size.x <= 1.0 or size.y <= 1.0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var source := _cover(texture.get_size())
	if drift:
		# 8% 안팎으로 천천히 확대하며 좌우로 살짝 흐른다.
		var zoom := 1.0 + 0.08 * (0.5 + 0.5 * sin(_time * 0.12))
		var shrink := source.size / zoom
		var room := source.size - shrink
		var pan := Vector2(0.5 + 0.5 * sin(_time * 0.09), 0.5 + 0.5 * cos(_time * 0.07))
		source = Rect2(source.position + room * pan, shrink)
	draw_texture_rect_region(texture, rect, source)
	if shade.a > 0.0:
		draw_rect(rect, shade)
	if fade_top > 0.0:
		_draw_fade(0.0, size.y * fade_top, true)
	if fade_bottom > 0.0:
		_draw_fade(size.y * (1.0 - fade_bottom), size.y, false)


## 칸 비율에 맞게 그림에서 잘라 쓸 부분.
func _cover(texture_size: Vector2) -> Rect2:
	var ratio := size.x / size.y
	if ratio >= texture_size.x / texture_size.y:
		var height := texture_size.x / ratio
		return Rect2(0, (texture_size.y - height) * focus_y, texture_size.x, height)
	var width := texture_size.y * ratio
	return Rect2((texture_size.x - width) / 2.0, 0, width, texture_size.y)


## 위(또는 아래)로 갈수록 어두워지는 띠.
func _draw_fade(from_y: float, to_y: float, dark_at_top: bool) -> void:
	var dark := Color(0.02, 0.05, 0.14, 0.85)
	var clear := Color(0.02, 0.05, 0.14, 0.0)
	var top_color := dark if dark_at_top else clear
	var bottom_color := clear if dark_at_top else dark
	var points := PackedVector2Array([Vector2(0, from_y), Vector2(size.x, from_y), Vector2(size.x, to_y), Vector2(0, to_y)])
	var colors := PackedColorArray([top_color, top_color, bottom_color, bottom_color])
	draw_polygon(points, colors)
