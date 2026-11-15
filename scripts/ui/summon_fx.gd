extends Control
## 소환 연출: 어두운 화면 가운데서 마법진이 돌고, 빛기둥이 솟다가 번쩍 터진다.
## 빛 색은 이번 소환에서 가장 높은 등급을 따른다(★ 파랑, ★★ 보라, ★★★ 금색). 누르면 건너뛴다.
## play()는 끝날 때까지 기다린 뒤 스스로 사라진다.

const Fx := preload("res://scripts/ui/fx.gd")
const TIME := 2.4
const CIRCLES := {1: "magic_circle_blue", 2: "magic_circle_purple", 3: "magic_circle_gold"}
const PILLARS := {1: "light_pillar_blue", 2: "light_pillar_blue", 3: "light_pillar"}
const GRADE_TINTS := {1: Color("6fc3ff"), 2: Color("c58bff"), 3: Color("ffd24a")}

var _t := 0.0
var _tint := Color("6fc3ff")
var _grade := 1
var _skipped := false


## 더하기 섞기로 그리는 빛 층
var _glow: Control


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_glow = Control.new()
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.material = Fx.additive()
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


func _sprite(name: String, center: Vector2, wide: float, tint: Color, turn: float = 0.0, squash: float = 1.0) -> void:
	var texture: Texture2D = Fx.tex(name)
	if texture == null:
		return
	var tall := wide * float(texture.get_height()) / maxf(float(texture.get_width()), 1.0)
	_glow.draw_set_transform(center, turn, Vector2(1.0, squash))
	_glow.draw_texture_rect(texture, Rect2(-wide / 2.0, -tall / 2.0, wide, tall), false, tint)
	_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 그려 둔 효과 그림으로 하는 소환 연출: 바닥에 누운 마법진 두 겹이 서로 반대로 돌고,
## 빛기둥이 굵어지며 솟고, 빛살이 퍼지다가 큰 별빛과 함께 터진다.
func _draw_glow() -> void:
	if Fx.tex("magic_circle_gold") == null:
		return
	var progress := clampf(_t / TIME, 0.0, 1.0)
	var center := size * Vector2(0.5, 0.66)
	var reach := minf(size.x, size.y) * 0.95
	var open := 1.0 - pow(1.0 - clampf(progress * 3.0, 0.0, 1.0), 3.0)
	_sprite(CIRCLES[_grade], center, reach * open, Color(1, 1, 1, open), _t * 1.3, 0.4)
	_sprite("ring_double", center, reach * 1.25 * open, Color(_tint.r, _tint.g, _tint.b, 0.7 * open), -_t * 0.8, 0.4)
	var grow := clampf((progress - 0.22) / 0.6, 0.0, 1.0)
	if grow > 0.0:
		var pillar: Texture2D = Fx.tex(PILLARS[_grade])
		if pillar != null:
			var wide := reach * (0.35 + 0.75 * grow * grow) * (1.0 + 0.04 * sin(_t * 40.0))
			var tall := size.y * 1.15
			_glow.draw_texture_rect(pillar, Rect2(center.x - wide / 2.0, center.y + reach * 0.08 - tall, wide, tall), false, Color(1, 1, 1, 0.35 + 0.65 * grow))
		_sprite("rays_burst", center - Vector2(0, size.y * 0.2), size.x * (0.6 + 0.7 * grow), Color(_tint.r, _tint.g, _tint.b, 0.8 * grow), _t * 0.5)
		for mote in 14 + _grade * 8:
			var phase := fposmod(_t * (0.5 + (mote % 5) * 0.12) + mote * 0.137, 1.0)
			var spot := center + Vector2(sin(mote * 12.9898) * reach * 0.34, -phase * size.y * 0.7)
			_sprite("flare_cross", spot, (26.0 + (mote % 4) * 14.0) * sin(phase * PI), Color(1, 1, 1, grow), phase * 2.0)
	var burst := clampf((progress - 0.84) / 0.16, 0.0, 1.0)
	if burst > 0.0:
		_sprite("flare_star", center - Vector2(0, size.y * 0.22), size.x * (0.4 + 1.6 * burst), Color(1, 1, 1, 1.0), burst)


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
		_glow.queue_redraw()
	queue_free()


func _draw() -> void:
	var progress := clampf(_t / TIME, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.01, 0.1, minf(progress * 6.0, 0.92)))
	var burst_white := clampf((progress - 0.9) / 0.1, 0.0, 1.0)
	if Fx.tex("magic_circle_gold") != null:
		# 효과 그림이 있으면 빛 층이 그린다. 여기서는 마지막의 하얀 번쩍임만.
		if burst_white > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, burst_white))
		return
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
