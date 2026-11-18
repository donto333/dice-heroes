extends Control
## 주사위 스킨 미리보기: 스킨 전용 그림이 있으면 그것을, 없으면 스킨 색으로 주사위 한 개를 그린다. (상점·설정용)

const GameData := preload("res://scripts/game_data.gd")

const PIPS := {
	1: [Vector2(0.5, 0.5)],
	5: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	6: [Vector2(0.27, 0.25), Vector2(0.73, 0.25), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.75), Vector2(0.73, 0.75)],
}

## {"body": 몸통 색, "edge": 테두리 색, "pip": 눈 색}
var skin: Dictionary = {}:
	set(value):
		skin = value
		queue_redraw()
var face := 5


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(96, 100)


func _draw() -> void:
	var side: float = min(size.x, size.y - 8.0)
	var own: Texture2D = GameData.skin_die_face(skin, face)
	if own != null and str(skin.get("id", "classic")) != "classic":
		var box := side * 1.15
		draw_texture_rect(own, Rect2((size.x - box) / 2.0, (size.y - box) / 2.0, box, box), false)
		return
	draw_set_transform(Vector2(size.x * 0.5, size.y * 0.5 - 2.0), -0.12, Vector2.ONE)
	draw_die(self, side, face, skin)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 가운데가 (0,0)인 주사위 하나를 canvas에 그린다. 큰 주사위 연출도 이 함수를 쓴다.
static func draw_die(canvas: CanvasItem, side: float, value: int, skin_colors: Dictionary) -> void:
	var half := side * 0.5
	var body_color := Color(str(skin_colors.get("body", "f8f4ea")))
	var body := StyleBoxFlat.new()
	body.bg_color = body_color
	body.set_corner_radius_all(int(side * 0.17))
	body.border_color = Color(str(skin_colors.get("edge", "9a9484")))
	body.set_border_width_all(max(2, int(side * 0.035)))
	body.border_width_bottom = max(4, int(side * 0.1))
	canvas.draw_style_box(body, Rect2(Vector2(-half, -half), Vector2(side, side)))
	var shine := StyleBoxFlat.new()
	shine.bg_color = Color(1, 1, 1, 0.55)
	shine.set_corner_radius_all(int(side * 0.1))
	canvas.draw_style_box(shine, Rect2(Vector2(-half + side * 0.09, -half + side * 0.08), Vector2(side * 0.82, side * 0.1)))
	var pip_color := Color(str(skin_colors.get("pip", "1b1f3b")))
	if value == 1 and not skin_colors.has("pip_one"):
		pip_color = Color("c0392b") if body_color.get_luminance() > 0.5 else pip_color
	var pip_size := side * (0.14 if value == 1 else 0.095)
	var faces: Array = PIPS.get(value, [])
	if faces.is_empty():
		faces = _pips(value)
	for pip in faces:
		canvas.draw_circle(Vector2(-half, -half - side * 0.03) + pip * side, pip_size, pip_color)


static func _pips(value: int) -> Array:
	match value:
		2:
			return [Vector2(0.27, 0.27), Vector2(0.73, 0.73)]
		3:
			return [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)]
		4:
			return [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)]
	return [Vector2(0.5, 0.5)]
