extends Control
## 기다리는 화면의 바탕(UI 개편 2단계): 대전 준비 그림(assets/art/ui/loading_bg)을 꽉 차게 천천히 확대해 깔고,
## 가운데에 금테 주사위 문양(assets/ui_menu/wait_emblem)을 천천히 돌린다.
## 그림이 없으면 파란 바탕과 돌아가는 금빛 점 8개로 그린다. 기다림 화면과 '상대를 찾는 중' 화면이 함께 쓴다.

const GameData := preload("res://scripts/game_data.gd")

## 문양 가운데가 화면 높이의 몇 % 자리에 오나
var center_y := 0.46
## 문양 지름(픽셀)
var emblem_size := 170.0

var _time := 0.0
var _background: Texture2D = null
var _emblem: Texture2D = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_background = GameData.art("ui/loading_bg")
	var path := "res://assets/ui_menu/wait_emblem.png"
	if ResourceLoader.exists(path):
		_emblem = load(path)


## 처음부터 다시(확대·회전 시작점).
func restart() -> void:
	_time = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_time += delta
		queue_redraw()


func _draw() -> void:
	if _background != null:
		var texture_size := _background.get_size()
		var ratio := size.x / maxf(size.y, 1.0)
		var source := Rect2(Vector2.ZERO, texture_size)
		if ratio < texture_size.x / texture_size.y:
			source.size.x = texture_size.y * ratio
			source.position.x = (texture_size.x - source.size.x) / 2.0
		else:
			source.size.y = texture_size.x / ratio
			source.position.y = (texture_size.y - source.size.y) / 2.0
		var zoom := 1.0 + minf(_time, 3.0) * 0.015
		var shrink := source.size / zoom
		source = Rect2(source.position + (source.size - shrink) / 2.0, shrink)
		draw_texture_rect_region(_background, Rect2(Vector2.ZERO, size), source)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.12, 0.3, 0.45))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.32, 0.72, 0.97))
	var center := Vector2(size.x * 0.5, size.y * center_y)
	if _emblem != null:
		# 뒤에 은은한 빛 + 천천히 도는 문양(살짝 숨 쉬듯 커졌다 작아짐)
		for ring in 4:
			draw_circle(center, emblem_size * (0.62 + ring * 0.09), Color(1.0, 0.85, 0.4, 0.07))
		var pulse := 1.0 + sin(_time * 3.0) * 0.03
		var half := Vector2(emblem_size, emblem_size * _emblem.get_height() / maxf(_emblem.get_width(), 1.0)) * 0.5 * pulse
		draw_set_transform(center, _time * 1.6, Vector2.ONE)
		draw_texture_rect(_emblem, Rect2(-half, half * 2.0), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# 돌아가는 점 8개: 앞선 점일수록 크고 밝다.
	var head := int(_time * 10.0) % 8
	for index in 8:
		var age := (head - index + 8) % 8
		var strength := 1.0 - age / 8.0
		var angle := TAU * index / 8.0 - PI / 2.0
		var color := Color(1.0, 0.81, 0.3, 0.25 + 0.75 * strength)
		draw_circle(center + Vector2(cos(angle), sin(angle)) * 46.0, 6.0 + 7.0 * strength, color)
