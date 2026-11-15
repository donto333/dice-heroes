extends Control
## 소환 연출: 어두운 화면 가운데서 마법진이 돌고, 빛기둥이 솟다가 번쩍 터진다.
## 빛 색은 이번 소환에서 가장 높은 등급을 따른다(★ 파랑, ★★ 보라, ★★★ 금색). 누르면 건너뛴다.
## play()는 끝날 때까지 기다린 뒤 스스로 사라진다.

const TIME := 2.1
const GRADE_TINTS := {1: Color("6fc3ff"), 2: Color("c58bff"), 3: Color("ffd24a")}

var _t := 0.0
var _tint := Color("6fc3ff")
var _grade := 1
var _skipped := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_skipped = true


func play(best_grade: int) -> void:
	_grade = clampi(best_grade, 1, 3)
	_tint = GRADE_TINTS[_grade]
	_t = 0.0
	while _t < TIME and not _skipped and is_inside_tree():
		await get_tree().process_frame
		_t += get_process_delta_time()
		queue_redraw()
	queue_free()


func _draw() -> void:
	var progress := clampf(_t / TIME, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.01, 0.1, minf(progress * 6.0, 0.92)))
	var center := size * Vector2(0.5, 0.62)
	var reach := minf(size.x, size.y) * 0.3
	# 바닥의 마법진: 눕힌 원 세 겹과 별이 서로 반대로 돈다.
	draw_set_transform(center, 0.0, Vector2(1.0, 0.38))
	for ring in 3:
		var radius := reach * (1.0 - ring * 0.22) * minf(progress * 3.0, 1.0)
		var spin := _t * (1.6 + ring * 0.7) * (1.0 if ring % 2 == 0 else -1.0)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(_tint.r, _tint.g, _tint.b, 0.85), 4.0 - ring)
		for mark in 8:
			var angle := spin + TAU * mark / 8.0
			draw_circle(Vector2(cos(angle), sin(angle)) * radius, 7.0 - ring * 1.5, Color(1, 1, 1, 0.9))
	var star := PackedVector2Array()
	for corner in 5:
		var angle := -_t * 1.2 + TAU * float(corner) * 2.0 / 5.0
		star.append(Vector2(cos(angle), sin(angle)) * reach * 0.78 * minf(progress * 3.0, 1.0))
	star.append(star[0])
	draw_polyline(star, Color(_tint.r, _tint.g, _tint.b, 0.7), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 빛기둥: 점점 굵어지고 밝아진다.
	var grow := clampf((progress - 0.25) / 0.55, 0.0, 1.0)
	if grow > 0.0:
		var half := reach * (0.12 + 0.5 * grow * grow)
		var bright := Color(_tint.r, _tint.g, _tint.b, 0.25 + 0.6 * grow)
		var faint := Color(_tint.r, _tint.g, _tint.b, 0.0)
		draw_polygon(PackedVector2Array([center + Vector2(-half, 0), center + Vector2(half, 0), Vector2(center.x + half * 0.7, 0), Vector2(center.x - half * 0.7, 0)]),
			PackedColorArray([bright, bright, faint, faint]))
		draw_polygon(PackedVector2Array([center + Vector2(-half * 0.3, 0), center + Vector2(half * 0.3, 0), Vector2(center.x + half * 0.2, 0), Vector2(center.x - half * 0.2, 0)]),
			PackedColorArray([Color(1, 1, 1, grow), Color(1, 1, 1, grow), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
		# 위로 떠오르는 빛 알
		for mote in 22 + _grade * 10:
			var phase := fposmod(_t * (0.5 + (mote % 5) * 0.12) + mote * 0.137, 1.0)
			var spread := sin(mote * 12.9898) * half * 1.6
			var spot := center + Vector2(spread, -phase * size.y * 0.6)
			draw_circle(spot, 2.5 + (mote % 3), Color(1, 1, 1, (1.0 - phase) * grow))
	# 마지막에 화면이 하얗게 터진다.
	var burst := clampf((progress - 0.86) / 0.14, 0.0, 1.0)
	if burst > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, burst))
