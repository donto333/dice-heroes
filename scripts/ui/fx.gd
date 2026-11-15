extends Control
## 화면 연출 층. 화면 맨 위에 얹어 두고 번쩍임, 알갱이 터짐, 속도선, 튀어나오는 글자, 흔들림을 그린다.
## 입력은 막지 않는다. 쓰는 법: var fx := Fx.new(); add_child(fx); fx.burst(위치, "spark")
## 자동 사진 도구처럼 연출을 건너뛸 때는 quiet = true로 둔다.

var quiet := false

## 알갱이: {"p": 위치, "v": 속도, "life": 남은 시간, "max": 처음 시간, "size": 크기, "color": 색, "kind": 모양, "spin": 회전}
var _bits: Array = []
var _flash_color := Color(1, 1, 1, 0)
var _flash_left := 0.0
var _flash_time := 0.0
var _lines_left := 0.0
var _lines_time := 0.0
var _lines_color := Color.WHITE
var _lines_center := Vector2.ZERO
var _rays_on := false
var _rays_color := Color(1.0, 0.9, 0.4, 0.35)
var _rays_center := Vector2.ZERO
var _time := 0.0
var _rng := RandomNumberGenerator.new()

const GRAVITY := 900.0
const COLORS := {
	"spark": [Color("fff3b0"), Color("ffd24a"), Color.WHITE],
	"coin": [Color("ffd24a"), Color("ffb81f"), Color("fff0a0")],
	"smoke": [Color(0.45, 0.2, 0.7, 0.8), Color(0.3, 0.12, 0.5, 0.8), Color(0.6, 0.35, 0.85, 0.8)],
	"star": [Color("ffe066"), Color("ff9d3c"), Color("ffffff")],
	"petal": [Color("ff6b6b"), Color("4fc3f7"), Color("ffd24a"), Color("7ee081"), Color("c58bff")],
	"ember": [Color("ff7a2a"), Color("ffb347"), Color("ff4a2a")],
	"ice": [Color("bfe9ff"), Color("ffffff"), Color("7fd0ff")],
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()


## 화면 전체가 잠깐 이 색으로 번쩍인다.
func flash(color: Color = Color.WHITE, seconds: float = 0.25) -> void:
	if quiet:
		return
	_flash_color = color
	_flash_time = seconds
	_flash_left = seconds
	queue_redraw()


## center에서 사방으로 알갱이가 터진다. kind: spark(반짝), coin(금화), smoke(연기), star(별), petal(종이 꽃가루), ember(불씨), ice(얼음)
func burst(center: Vector2, kind: String = "spark", count: int = 18, power: float = 1.0) -> void:
	if quiet:
		return
	var palette: Array = COLORS.get(kind, COLORS["spark"])
	for index in count:
		var angle := _rng.randf_range(0.0, TAU)
		var speed := _rng.randf_range(160.0, 520.0) * power
		var velocity := Vector2(cos(angle), sin(angle)) * speed
		if kind == "coin" or kind == "petal":
			velocity.y = -absf(velocity.y) - 240.0 * power
		if kind == "smoke":
			velocity = Vector2(velocity.x * 0.35, -absf(velocity.y) * 0.4 - 60.0)
		var life := _rng.randf_range(0.45, 0.95) * (1.5 if kind == "smoke" or kind == "petal" else 1.0)
		_bits.append({"p": center, "v": velocity, "life": life, "max": life, "size": _rng.randf_range(5.0, 12.0) * (1.8 if kind == "smoke" else 1.0),
			"color": palette[index % palette.size()], "kind": kind, "spin": _rng.randf_range(-8.0, 8.0)})
	queue_redraw()


## 화면 위에서 종이 꽃가루가 쏟아진다(승리).
func shower(kind: String = "petal", count: int = 60) -> void:
	if quiet:
		return
	var palette: Array = COLORS.get(kind, COLORS["petal"])
	for index in count:
		var life := _rng.randf_range(1.6, 3.0)
		_bits.append({"p": Vector2(_rng.randf_range(0.0, size.x), _rng.randf_range(-size.y * 0.4, -10.0)),
			"v": Vector2(_rng.randf_range(-60.0, 60.0), _rng.randf_range(120.0, 320.0)), "life": life, "max": life,
			"size": _rng.randf_range(7.0, 13.0), "color": palette[index % palette.size()], "kind": "petal_fall", "spin": _rng.randf_range(-6.0, 6.0)})
	queue_redraw()


## 한 점에서 뻗어 나오는 속도선(스킬 발동, 돌진).
func speed_lines(center: Vector2, color: Color = Color.WHITE, seconds: float = 0.6) -> void:
	if quiet:
		return
	_lines_center = center
	_lines_color = color
	_lines_time = seconds
	_lines_left = seconds
	queue_redraw()


## 천천히 도는 빛살을 켜고 끈다(승리 화면, 좋은 보상).
func rays(on: bool, center: Vector2 = Vector2.ZERO, color: Color = Color(1.0, 0.9, 0.4, 0.3)) -> void:
	_rays_on = on and not quiet
	_rays_center = center
	_rays_color = color
	queue_redraw()


## 글자가 튀어나와 위로 떠오르며 사라진다(주사위 눈, +보상, 피해).
func pop_text(center: Vector2, text: String, color: Color = Color("ffcf4d"), font_size: int = 72) -> void:
	if quiet:
		return
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", maxi(8, int(font_size * 0.22)))
	label.add_theme_color_override("font_outline_color", Color("3a1c00"))
	add_child(label)
	label.size = label.get_combined_minimum_size()
	label.position = center - label.size * 0.5
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.2, 0.2)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2(1.25, 1.25), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.08)
	tween.tween_interval(0.35)
	tween.tween_property(label, "position:y", label.position.y - 70.0, 0.4)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)


## target을 잠깐 흔든다(충돌, 피해). 끝나면 제자리로 돌아온다.
func shake(target: Control, strength: float = 14.0, seconds: float = 0.3) -> void:
	if quiet or target == null or not is_instance_valid(target):
		return
	var home := target.position
	var tween := target.create_tween()
	var steps := maxi(3, int(seconds / 0.04))
	for index in steps:
		var fade := 1.0 - float(index) / steps
		tween.tween_property(target, "position", home + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * strength * fade, 0.04)
	tween.tween_property(target, "position", home, 0.04)


func _process(delta: float) -> void:
	_time += delta
	var busy := _rays_on
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		busy = true
	if _lines_left > 0.0:
		_lines_left = maxf(_lines_left - delta, 0.0)
		busy = true
	if not _bits.is_empty():
		for bit in _bits:
			var kind := str(bit["kind"])
			var velocity: Vector2 = bit["v"]
			if kind == "smoke":
				velocity *= 1.0 - delta * 1.2
			elif kind == "petal_fall":
				velocity.x += sin(_time * 3.0 + float(bit["spin"])) * 40.0 * delta
			else:
				velocity.y += GRAVITY * delta * (0.5 if kind == "petal" else 1.0)
			bit["v"] = velocity
			bit["p"] = (bit["p"] as Vector2) + velocity * delta
			bit["life"] = float(bit["life"]) - delta
		_bits = _bits.filter(func(bit): return float(bit["life"]) > 0.0)
		busy = true
	if busy:
		queue_redraw()


func _draw() -> void:
	if _rays_on:
		var center := _rays_center if _rays_center != Vector2.ZERO else size * 0.5
		var reach := size.length()
		for index in 12:
			var angle := TAU * index / 12.0 + _time * 0.35
			var half := TAU / 48.0
			draw_colored_polygon(PackedVector2Array([center,
				center + Vector2(cos(angle - half), sin(angle - half)) * reach,
				center + Vector2(cos(angle + half), sin(angle + half)) * reach]), _rays_color)
	if _lines_left > 0.0 and _lines_time > 0.0:
		var ratio := _lines_left / _lines_time
		var reach := size.length()
		for index in 36:
			var angle := TAU * index / 36.0 + sin(index * 12.9898) * 0.08
			var inner := reach * (0.22 + 0.1 * absf(sin(index * 7.13 + _time * 18.0)))
			var direction := Vector2(cos(angle), sin(angle))
			var color := _lines_color
			color.a = 0.55 * ratio
			draw_line(_lines_center + direction * inner, _lines_center + direction * reach, color, 3.0 + 5.0 * absf(sin(index * 3.7)))
	for bit in _bits:
		var fade := clampf(float(bit["life"]) / float(bit["max"]), 0.0, 1.0)
		var color: Color = bit["color"]
		color.a *= fade
		var spot: Vector2 = bit["p"]
		var radius := float(bit["size"])
		match str(bit["kind"]):
			"smoke":
				draw_circle(spot, radius * (2.0 - fade), color)
			"coin":
				draw_set_transform(spot, 0.0, Vector2(absf(cos(_time * 9.0 + float(bit["spin"]))) * 0.8 + 0.2, 1.0))
				draw_circle(Vector2.ZERO, radius, Color("8a5a00", color.a))
				draw_circle(Vector2.ZERO, radius * 0.78, color)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"petal", "petal_fall":
				draw_set_transform(spot, _time * float(bit["spin"]), Vector2(1.0, absf(sin(_time * 5.0 + float(bit["spin"]))) * 0.8 + 0.2))
				draw_rect(Rect2(-radius, -radius * 0.6, radius * 2.0, radius * 1.2), color)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"star":
				_star(spot, radius * (0.6 + fade), color, _time * float(bit["spin"]))
			_:
				# 반짝이: 십자 빛
				draw_circle(spot, radius * 0.45 * fade + 1.0, color)
				draw_line(spot - Vector2(radius * fade * 1.6, 0), spot + Vector2(radius * fade * 1.6, 0), color, 2.0)
				draw_line(spot - Vector2(0, radius * fade * 1.6), spot + Vector2(0, radius * fade * 1.6), color, 2.0)
	if _flash_left > 0.0 and _flash_time > 0.0:
		var color := _flash_color
		color.a *= _flash_left / _flash_time
		draw_rect(Rect2(Vector2.ZERO, size), color)


func _star(center: Vector2, radius: float, color: Color, turn: float) -> void:
	var points := PackedVector2Array()
	for corner in 10:
		var angle := TAU * corner / 10.0 - PI / 2.0 + turn
		points.append(center + Vector2(cos(angle), sin(angle)) * (radius if corner % 2 == 0 else radius * 0.45))
	draw_colored_polygon(points, color)
