extends Control
## 주사위 눈을 그리는 작은 화면 요소. values에 눈 값(1~6)을 넣으면 그만큼 주사위를 그린다.
## roll_to()는 주사위가 구르는 모습을 흉내 낸 뒤 정해진 눈에서 멈춘다.
## 굴림 중에 보이는 눈은 화면용 흉내일 뿐이고, 실제 결과는 규칙 엔진이 이미 정해 둔 값이다.

const PIPS := {
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.27, 0.27), Vector2(0.73, 0.73)],
	3: [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)],
	4: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	5: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	6: [Vector2(0.27, 0.25), Vector2(0.73, 0.25), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.75), Vector2(0.73, 0.75)],
}
const FRAME_TIME := 0.06

var values: Array = []:
	set(new_values):
		values = new_values
		_update_size()
		queue_redraw()
var die_size := 40.0:
	set(new_size):
		die_size = new_size
		_update_size()
		queue_redraw()
var face_color := Color("f4f1e8")
var pip_color := Color("1b1f3b")

var _rolling := false
var _fx_rng := RandomNumberGenerator.new()


func _update_size() -> void:
	custom_minimum_size = Vector2(values.size() * (die_size + 6.0), die_size + 6.0)


## 구르는 모습을 duration초 보여 준 뒤 final_values에서 멈춘다.
func roll_to(final_values: Array, duration: float = 0.5) -> void:
	_fx_rng.randomize()
	_rolling = true
	var elapsed := 0.0
	while elapsed < duration and is_inside_tree():
		var faces: Array = []
		for i in final_values.size():
			faces.append(_fx_rng.randi_range(1, 6))
		values = faces
		await get_tree().create_timer(FRAME_TIME).timeout
		elapsed += FRAME_TIME
	_rolling = false
	values = final_values


func _draw() -> void:
	for index in values.size():
		var value: int = clamp(int(values[index]), 1, 6)
		var offset := Vector2.ZERO
		if _rolling:
			offset = Vector2(_fx_rng.randf_range(-2.0, 2.0), _fx_rng.randf_range(-3.0, 3.0))
		var rect := Rect2(Vector2(index * (die_size + 6.0), 3.0) + offset, Vector2(die_size, die_size))
		# 입체감: 아래쪽 그림자 면을 먼저 그린다.
		draw_rect(Rect2(rect.position + Vector2(0, 3), rect.size), Color(0, 0, 0, 0.45))
		draw_rect(rect, face_color)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), Color(1, 1, 1, 0.6))
		draw_rect(rect, Color(0, 0, 0, 0.5), false, 2.0)
		var pip_color_now := Color("c0392b") if value == 1 else pip_color
		for pip in PIPS[value]:
			draw_circle(rect.position + pip * die_size, die_size * 0.09, pip_color_now)
