extends Control
## 주사위 눈을 그리는 작은 화면 요소. values에 눈 값(1~6)을 넣으면 그만큼 주사위를 그린다.

const PIPS := {
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.27, 0.27), Vector2(0.73, 0.73)],
	3: [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)],
	4: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	5: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	6: [Vector2(0.27, 0.25), Vector2(0.73, 0.25), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.75), Vector2(0.73, 0.75)],
}

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


func _update_size() -> void:
	custom_minimum_size = Vector2(values.size() * (die_size + 6.0), die_size)


func _draw() -> void:
	for index in values.size():
		var value: int = clamp(int(values[index]), 1, 6)
		var rect := Rect2(Vector2(index * (die_size + 6.0), 0), Vector2(die_size, die_size))
		draw_rect(rect, face_color)
		draw_rect(rect, Color(0, 0, 0, 0.35), false, 2.0)
		var pip_color_now := Color("c0392b") if value == 1 else pip_color
		for pip in PIPS[value]:
			draw_circle(rect.position + pip * die_size, die_size * 0.09, pip_color_now)
