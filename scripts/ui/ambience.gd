extends Control
## 화면 바탕 위에 떠다니는 빛 알갱이와 천천히 도는 빛줄기. 메뉴 화면이 밋밋하지 않게 살아 있는 느낌을 준다.
## 그림만 그리고 입력은 받지 않는다. Kit.backdrop()이 바탕 그림 위에 자동으로 붙인다.

const Fx := preload("res://scripts/ui/fx.gd")

## 알갱이 개수
var count := 26
## 빛줄기를 그릴지
var beams := true
## 알갱이 색
var tint := Color(1.0, 0.95, 0.7)
var _time := 0.0
var _motes: Array = []


func _init() -> void:
	name = "Ambience"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	material = Fx.additive()


func _ready() -> void:
	# 매번 같은 자리에서 시작하도록 정해진 씨앗을 쓴다(자동 사진이 흔들리지 않게).
	var rng := RandomNumberGenerator.new()
	rng.seed = 7411
	for index in count:
		_motes.append({
			"x": rng.randf(),
			"y": rng.randf(),
			"speed": rng.randf_range(0.012, 0.04),
			"sway": rng.randf_range(0.01, 0.035),
			"phase": rng.randf() * TAU,
			"size": rng.randf_range(2.5, 7.0),
			"star": rng.randf() < 0.3,
		})


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	if beams:
		# 왼쪽 위에서 비스듬히 내려오는 빛줄기 세 가닥이 천천히 흔들린다.
		var source := Vector2(size.x * 0.12, -size.y * 0.08)
		for index in 3:
			var angle := 0.55 + index * 0.28 + sin(_time * 0.25 + index * 1.7) * 0.06
			var spread := 0.07 + 0.02 * sin(_time * 0.4 + index)
			var reach := size.y * 1.5
			var a := source + Vector2(cos(angle - spread), sin(angle - spread)) * reach
			var b := source + Vector2(cos(angle + spread), sin(angle + spread)) * reach
			var glow := 0.07 + 0.03 * sin(_time * 0.6 + index * 2.1)
			draw_polygon(PackedVector2Array([source, a, b]),
				PackedColorArray([Color(1, 1, 0.9, glow * 1.6), Color(1, 1, 0.9, 0.0), Color(1, 1, 0.9, 0.0)]))
	for mote in _motes:
		var rise := fposmod(float(mote["y"]) - _time * float(mote["speed"]), 1.0)
		var x := (float(mote["x"]) + sin(_time * 0.7 + float(mote["phase"])) * float(mote["sway"])) * size.x
		var y := rise * size.y
		var twinkle := 0.45 + 0.55 * sin(_time * 2.2 + float(mote["phase"]) * 3.0)
		# 위아래 끝에서는 서서히 사라진다.
		var edge := clampf(minf(rise, 1.0 - rise) * 6.0, 0.0, 1.0)
		var alpha := twinkle * edge
		var radius := float(mote["size"])
		var soft: Texture2D = Fx.tex("flare_cross" if bool(mote["star"]) else "glow_soft")
		if soft != null:
			# 그려 둔 빛 그림을 쓴다(더하기 섞기라 겹칠수록 밝아진다).
			var reach := radius * (9.0 if bool(mote["star"]) else 6.0) * (0.7 + 0.3 * twinkle)
			draw_texture_rect(soft, Rect2(x - reach / 2.0, y - reach / 2.0, reach, reach), false, Color(tint.r, tint.g, tint.b, alpha * 0.8))
			continue
		draw_circle(Vector2(x, y), radius * 2.4, Color(tint.r, tint.g, tint.b, alpha * 0.12))
		if bool(mote["star"]):
			var arm := radius * 2.2 * (0.7 + 0.3 * twinkle)
			var color := Color(1, 1, 1, alpha * 0.9)
			draw_line(Vector2(x - arm, y), Vector2(x + arm, y), color, 1.6)
			draw_line(Vector2(x, y - arm), Vector2(x, y + arm), color, 1.6)
			draw_circle(Vector2(x, y), radius * 0.5, color)
		else:
			draw_circle(Vector2(x, y), radius * 0.7, Color(tint.r, tint.g, tint.b, alpha * 0.6))
