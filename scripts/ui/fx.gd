extends Control
## 화면 연출 층. 화면 맨 위에 얹어 두고 번쩍임, 터짐, 속도선, 빛살, 튀어나오는 글자, 흔들림을 그린다.
## 도형을 조합해 그리지 않고, 그려 둔 효과 그림(assets/fx)을 겹쳐서 쓴다:
##  - 검은 바탕 그림(빛·불·얼음·마법진)은 "더하기 섞기"로 그려 빛나 보이게 하고(_glow 층),
##  - 바탕을 지운 그림(금화·별·꽃가루)은 보통 섞기로 그린다.
## 한 번의 터짐은 큰 그림 도장 몇 장(커지며 사라짐)과 작은 그림 알갱이 여러 개를 겹쳐 만든다.
## 입력은 막지 않는다. 쓰는 법: var fx := Fx.new(); add_child(fx); fx.burst(위치, "spark")
## 자동 사진 도구처럼 연출을 건너뛸 때는 quiet = true로 둔다. 효과 그림이 없으면 단순한 도형으로 대신 그린다.

const FX_PATH := "res://assets/fx/%s.png"
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

var quiet := false

## 큰 그림 도장: {"tex", "p", "t", "life", "from", "to", "px", "rot", "spin", "color", "add", "rise", "delay", "squash"}
var _stamps: Array = []
## 알갱이: {"tex", "p", "v", "life", "max", "size", "color", "kind", "spin", "add"}
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
## 더하기 섞기로 그리는 빛 층
var _glow: Control

static var _textures: Dictionary = {}
static var _pieces: Dictionary = {}


## 효과 그림 한 장. 없으면 null.
static func tex(name: String) -> Texture2D:
	if _textures.has(name):
		return _textures[name]
	var texture: Texture2D = null
	var path := FX_PATH % name
	if ResourceLoader.exists(path):
		texture = load(path)
	_textures[name] = texture
	return texture


## 여러 조각으로 나눠 둔 그림(confetti_0, confetti_1 ...)을 모두 모은다.
static func pieces(name: String) -> Array:
	if _pieces.has(name):
		return _pieces[name]
	var found: Array = []
	for index in 24:
		var piece := tex("%s_%d" % [name, index])
		if piece == null:
			break
		found.append(piece)
	_pieces[name] = found
	return found


## 더하기 섞기 재질(빛나는 그림용). 다른 화면 조각들도 같이 쓴다.
static func additive() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	_glow = Control.new()
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.material = additive()
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


## 화면 전체가 잠깐 이 색으로 번쩍인다.
func flash(color: Color = Color.WHITE, seconds: float = 0.25) -> void:
	if quiet:
		return
	_flash_color = color
	_flash_time = seconds
	_flash_left = seconds
	queue_redraw()


## 효과 그림 한 장을 도장처럼 찍는다: px 크기의 from배에서 to배로 커지며 사라진다.
## options: from, to, spin(초당 회전), rot(처음 각도), color, add(더하기 섞기, 기본 참), rise(위로 떠오르는 거리), delay, squash(세로 눌림)
func stamp(name: String, center: Vector2, px: float, seconds: float = 0.5, options: Dictionary = {}) -> void:
	if quiet:
		return
	var texture := tex(name)
	if texture == null:
		return
	_stamps.append({"tex": texture, "p": center, "t": -float(options.get("delay", 0.0)), "life": seconds,
		"from": float(options.get("from", 0.35)), "to": float(options.get("to", 1.2)), "px": px,
		"rot": float(options.get("rot", 0.0)), "spin": float(options.get("spin", 0.0)),
		"color": options.get("color", Color.WHITE), "add": bool(options.get("add", true)),
		"rise": float(options.get("rise", 0.0)), "squash": float(options.get("squash", 1.0))})
	_refresh()


## center에서 효과가 터진다. kind:
## spark(반짝), coin(금화), smoke(저주 연기), star(별), petal(종이 꽃가루), ember(불꽃), ice(얼음),
## impact(충돌), heal(회복 빛), dust(먼지), bolt(번개)
func burst(center: Vector2, kind: String = "spark", count: int = 18, power: float = 1.0) -> void:
	if quiet:
		return
	var scale_px := 300.0 * power
	match kind:
		"spark":
			stamp("spark_burst", center, scale_px, 0.5, {"from": 0.3, "to": 1.35, "rot": _rng.randf() * TAU})
			stamp("flare_star", center, scale_px * 0.9, 0.38, {"from": 0.5, "to": 1.3, "spin": 1.2})
			stamp("ring_shock", center, scale_px * 0.9, 0.45, {"from": 0.2, "to": 1.5})
			_scatter(center, "flare_cross", count, power, true, COLORS["spark"])
		"coin":
			stamp("flare_star", center, scale_px * 0.8, 0.4, {"from": 0.4, "to": 1.2, "color": Color("ffd24a")})
			stamp("ring_shock", center, scale_px * 0.7, 0.4, {"from": 0.2, "to": 1.3, "color": Color("ffe9a0")})
			_scatter(center, "coin", count, power, false, COLORS["coin"])
		"smoke":
			stamp("dark_aura", center, scale_px * 1.1, 0.9, {"from": 0.6, "to": 1.3, "rise": 70.0})
			stamp("magic_circle_purple", center + Vector2(0, 26), scale_px * 0.9, 0.8, {"from": 0.5, "to": 1.1, "spin": 1.6, "squash": 0.4})
			stamp("skull_curse", center - Vector2(0, 20), scale_px * 0.42, 0.9, {"from": 0.5, "to": 1.05, "rise": 60.0, "add": false})
			if tex("dark_aura") == null:
				_scatter(center, "", count / 2, power, false, COLORS["smoke"], "smoke")
		"star":
			stamp("flare_star", center, scale_px, 0.45, {"from": 0.4, "to": 1.3, "spin": -1.0})
			stamp("ring_shock", center, scale_px * 0.8, 0.45, {"from": 0.2, "to": 1.5, "color": Color("fff0a0")})
			_scatter(center, "star_gold", count, power, false, COLORS["star"], "star")
		"petal":
			stamp("flare_star", center, scale_px * 0.7, 0.35, {"from": 0.4, "to": 1.2})
			_scatter(center, "confetti", count, power, false, COLORS["petal"], "petal")
		"ember":
			stamp("fire_burst", center, scale_px * 1.15, 0.55, {"from": 0.35, "to": 1.3, "rot": _rng.randf() * TAU})
			stamp("impact_burst", center, scale_px * 0.9, 0.3, {"from": 0.5, "to": 1.25, "color": Color("ffd9a0")})
			stamp("ring_shock", center, scale_px, 0.5, {"from": 0.2, "to": 1.6, "color": Color("ffb060")})
			_scatter(center, "flame", count / 2, power * 0.7, true, COLORS["ember"], "rise")
		"ice":
			stamp("ice_burst", center, scale_px * 1.15, 0.6, {"from": 0.3, "to": 1.25, "rot": _rng.randf() * TAU})
			stamp("ring_double", center, scale_px, 0.55, {"from": 0.3, "to": 1.5, "spin": 2.0})
			_scatter(center, "flare_cross", count, power, true, COLORS["ice"])
		"impact":
			stamp("impact_burst", center, scale_px * 1.3, 0.38, {"from": 0.4, "to": 1.35, "rot": _rng.randf() * TAU})
			stamp("slash_cross", center, scale_px * 1.2, 0.34, {"from": 0.6, "to": 1.3})
			stamp("ring_shock", center, scale_px * 1.1, 0.45, {"from": 0.2, "to": 1.7})
			_scatter(center, "flare_cross", count, power * 1.2, true, COLORS["spark"])
		"heal":
			stamp("heal_sparkles", center, scale_px, 0.9, {"from": 0.7, "to": 1.15, "rise": 80.0})
			stamp("magic_circle_blue", center + Vector2(0, 26), scale_px * 0.9, 0.8, {"from": 0.5, "to": 1.1, "spin": -1.6, "squash": 0.4, "color": Color("9dffb0")})
		"dust":
			_scatter(center, "dust_puff", count, power * 0.5, false, [Color.WHITE], "smoke")
		"bolt":
			stamp("lightning", center - Vector2(0, scale_px * 0.9), scale_px * 2.0, 0.32, {"from": 1.0, "to": 1.05})
			stamp("impact_burst", center, scale_px, 0.35, {"from": 0.4, "to": 1.3, "color": Color("d9c8ff")})
			stamp("ring_shock", center, scale_px, 0.45, {"from": 0.2, "to": 1.6, "color": Color("c9a0ff")})
			_scatter(center, "flare_cross", count, power, true, [Color("e6d9ff"), Color.WHITE])
		_:
			_scatter(center, "flare_cross", count, power, true, COLORS.get(kind, COLORS["spark"]))
	_refresh()


## 작은 그림 알갱이들을 사방으로 날린다. motion: ""(터져 나갔다 떨어짐), smoke(천천히 떠오름), rise(위로 솟음), star·petal(위로 튀었다 떨어짐)
func _scatter(center: Vector2, name: String, count: int, power: float, add: bool, palette: Array, motion: String = "") -> void:
	var texture: Texture2D = null
	var many: Array = []
	if name == "confetti":
		many = pieces("confetti")
	elif name != "":
		texture = tex(name)
	for index in count:
		var angle := _rng.randf_range(0.0, TAU)
		var speed := _rng.randf_range(160.0, 520.0) * power
		var velocity := Vector2(cos(angle), sin(angle)) * speed
		var life := _rng.randf_range(0.45, 0.95)
		match motion:
			"smoke":
				velocity = Vector2(velocity.x * 0.35, -absf(velocity.y) * 0.4 - 60.0)
				life *= 1.5
			"rise":
				velocity = Vector2(velocity.x * 0.5, -absf(velocity.y) - 120.0)
			"petal", "star":
				velocity.y = -absf(velocity.y) - 240.0 * power
				life *= 1.4
		if name == "coin":
			velocity.y = -absf(velocity.y) - 240.0 * power
		var chosen: Texture2D = texture
		if not many.is_empty():
			chosen = many[index % many.size()]
		var base := _rng.randf_range(18.0, 34.0) if chosen != null else _rng.randf_range(5.0, 12.0)
		if motion == "smoke":
			base *= 2.2
		if name == "flame":
			base *= 1.8
		var tint: Color = palette[index % palette.size()] if (chosen == null or add) else Color.WHITE
		_bits.append({"tex": chosen, "p": center, "v": velocity, "life": life, "max": life, "size": base, "color": tint,
			"kind": motion if motion != "" else ("coin" if name == "coin" else "spark"), "spin": _rng.randf_range(-8.0, 8.0), "add": add and chosen != null})


## 화면 위에서 종이 꽃가루가 쏟아진다(승리).
func shower(kind: String = "petal", count: int = 60) -> void:
	if quiet:
		return
	var palette: Array = COLORS.get(kind, COLORS["petal"])
	var many: Array = pieces("confetti") + pieces("petal")
	for index in count:
		var life := _rng.randf_range(1.8, 3.4)
		var chosen: Texture2D = many[index % many.size()] if not many.is_empty() else null
		_bits.append({"tex": chosen, "p": Vector2(_rng.randf_range(0.0, size.x), _rng.randf_range(-size.y * 0.4, -10.0)),
			"v": Vector2(_rng.randf_range(-60.0, 60.0), _rng.randf_range(120.0, 320.0)), "life": life, "max": life,
			"size": _rng.randf_range(16.0, 30.0) if chosen != null else _rng.randf_range(7.0, 13.0),
			"color": Color.WHITE if chosen != null else palette[index % palette.size()], "kind": "petal_fall",
			"spin": _rng.randf_range(-6.0, 6.0), "add": false})
	_refresh()


## 한 점에서 뻗어 나오는 속도선(스킬 발동, 돌진).
func speed_lines(center: Vector2, color: Color = Color.WHITE, seconds: float = 0.6) -> void:
	if quiet:
		return
	_lines_center = center
	_lines_color = color
	_lines_time = seconds
	_lines_left = seconds
	_refresh()


## 천천히 도는 빛살을 켜고 끈다(승리 화면, 좋은 보상).
func rays(on: bool, center: Vector2 = Vector2.ZERO, color: Color = Color(1.0, 0.9, 0.4, 0.3)) -> void:
	_rays_on = on and not quiet
	_rays_center = center
	_rays_color = color
	_refresh()


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
	stamp("flare_star", center, font_size * 3.4, 0.35, {"from": 0.5, "to": 1.2, "color": color})
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


func _refresh() -> void:
	queue_redraw()
	if _glow != null:
		_glow.queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var busy := _rays_on
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		busy = true
	if _lines_left > 0.0:
		_lines_left = maxf(_lines_left - delta, 0.0)
		busy = true
	if not _stamps.is_empty():
		for item in _stamps:
			item["t"] = float(item["t"]) + delta
		_stamps = _stamps.filter(func(item): return float(item["t"]) < float(item["life"]))
		busy = true
	if not _bits.is_empty():
		for bit in _bits:
			var kind := str(bit["kind"])
			var velocity: Vector2 = bit["v"]
			if kind == "smoke" or kind == "rise":
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
		_refresh()


## 도장 한 장 그리기(어느 층에든).
func _draw_stamp(canvas: Control, item: Dictionary) -> void:
	var t := float(item["t"])
	if t < 0.0:
		return
	var progress := clampf(t / float(item["life"]), 0.0, 1.0)
	# 빠르게 커지고 천천히 사라진다.
	var grow := 1.0 - pow(1.0 - progress, 3.0)
	var scale_now := lerpf(float(item["from"]), float(item["to"]), grow)
	var alpha := 1.0 - pow(progress, 2.2)
	var color: Color = item["color"]
	color.a *= alpha
	var texture: Texture2D = item["tex"]
	var px := float(item["px"]) * scale_now
	var tall := px * float(texture.get_height()) / maxf(float(texture.get_width()), 1.0)
	var spot: Vector2 = item["p"]
	spot.y -= float(item["rise"]) * grow
	canvas.draw_set_transform(spot, float(item["rot"]) + float(item["spin"]) * t, Vector2(1.0, float(item["squash"])))
	canvas.draw_texture_rect(texture, Rect2(-px / 2.0, -tall / 2.0, px, tall), false, color)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 알갱이 한 개 그리기.
func _draw_bit(canvas: Control, bit: Dictionary) -> void:
	var fade := clampf(float(bit["life"]) / float(bit["max"]), 0.0, 1.0)
	var color: Color = bit["color"]
	color.a *= minf(fade * 2.0, 1.0)
	var spot: Vector2 = bit["p"]
	var radius := float(bit["size"])
	var texture: Texture2D = bit["tex"]
	var kind := str(bit["kind"])
	if texture != null:
		var wide := radius * 2.0
		var tall := wide * float(texture.get_height()) / maxf(float(texture.get_width()), 1.0)
		var squash := Vector2.ONE
		var turn := _time * float(bit["spin"])
		match kind:
			"coin":
				# 금화는 빙글빙글 돌며 얇아졌다 두꺼워진다.
				squash = Vector2(absf(cos(_time * 9.0 + float(bit["spin"]))) * 0.85 + 0.15, 1.0)
				turn = 0.0
			"petal", "petal_fall":
				squash = Vector2(1.0, absf(sin(_time * 5.0 + float(bit["spin"]))) * 0.7 + 0.3)
			"smoke":
				wide *= 2.0 - fade
				tall *= 2.0 - fade
				turn *= 0.1
			"rise":
				turn = 0.0
				wide *= 0.5 + fade * 0.5
				tall *= 0.5 + fade * 0.5
			"spark":
				wide *= 0.4 + fade
				tall *= 0.4 + fade
		canvas.draw_set_transform(spot, turn, squash)
		canvas.draw_texture_rect(texture, Rect2(-wide / 2.0, -tall / 2.0, wide, tall), false, color)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# 그림이 없을 때의 단순한 대체 모양
	match kind:
		"smoke":
			canvas.draw_circle(spot, radius * (2.0 - fade), color)
		"petal", "petal_fall":
			canvas.draw_set_transform(spot, _time * float(bit["spin"]), Vector2(1.0, absf(sin(_time * 5.0 + float(bit["spin"]))) * 0.8 + 0.2))
			canvas.draw_rect(Rect2(-radius, -radius * 0.6, radius * 2.0, radius * 1.2), color)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_:
			canvas.draw_circle(spot, radius * 0.45 * fade + 1.0, color)
			canvas.draw_line(spot - Vector2(radius * fade * 1.6, 0), spot + Vector2(radius * fade * 1.6, 0), color, 2.0)
			canvas.draw_line(spot - Vector2(0, radius * fade * 1.6), spot + Vector2(0, radius * fade * 1.6), color, 2.0)


## 빛나는 것들(더하기 섞기 층): 빛살, 속도선, 빛 도장, 빛 알갱이.
func _draw_glow() -> void:
	if _rays_on:
		var center := _rays_center if _rays_center != Vector2.ZERO else size * 0.5
		var beams := tex("rays_burst")
		if beams != null:
			var reach := size.length() * 1.3
			var tint := Color(_rays_color.r, _rays_color.g, _rays_color.b, minf(_rays_color.a * 2.6, 1.0))
			for layer in 2:
				_glow.draw_set_transform(center, _time * (0.22 if layer == 0 else -0.15), Vector2.ONE)
				_glow.draw_texture_rect(beams, Rect2(-reach / 2.0, -reach / 2.0, reach, reach), false, tint)
			_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var core := tex("glow_soft")
			if core != null:
				var core_size := size.y * (0.9 + 0.06 * sin(_time * 2.0))
				_glow.draw_texture_rect(core, Rect2(center - Vector2(core_size, core_size) * 0.5, Vector2(core_size, core_size)), false, tint)
		else:
			var reach := size.length()
			for index in 12:
				var angle := TAU * index / 12.0 + _time * 0.35
				var half := TAU / 48.0
				_glow.draw_colored_polygon(PackedVector2Array([center,
					center + Vector2(cos(angle - half), sin(angle - half)) * reach,
					center + Vector2(cos(angle + half), sin(angle + half)) * reach]), _rays_color)
	if _lines_left > 0.0 and _lines_time > 0.0:
		var ratio := _lines_left / _lines_time
		var lines := tex("speed_lines")
		if lines != null:
			# 속도선 그림을 화면보다 크게 깔고 조금씩 떨며 커지게 한다.
			var reach := size.length() * (1.15 + 0.25 * (1.0 - ratio)) * (1.0 + 0.03 * sin(_time * 60.0))
			var tint := Color(_lines_color.r, _lines_color.g, _lines_color.b, minf(ratio * 1.6, 1.0))
			_glow.draw_set_transform(_lines_center, floorf(_time * 24.0) * 0.21, Vector2.ONE)
			_glow.draw_texture_rect(lines, Rect2(-reach / 2.0, -reach / 2.0, reach, reach), false, tint)
			_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var reach := size.length()
			for index in 36:
				var angle := TAU * index / 36.0 + sin(index * 12.9898) * 0.08
				var inner := reach * (0.22 + 0.1 * absf(sin(index * 7.13 + _time * 18.0)))
				var direction := Vector2(cos(angle), sin(angle))
				var color := _lines_color
				color.a = 0.55 * ratio
				_glow.draw_line(_lines_center + direction * inner, _lines_center + direction * reach, color, 3.0 + 5.0 * absf(sin(index * 3.7)))
	for item in _stamps:
		if bool(item["add"]):
			_draw_stamp(_glow, item)
	for bit in _bits:
		if bool(bit["add"]):
			_draw_bit(_glow, bit)


func _draw() -> void:
	for item in _stamps:
		if not bool(item["add"]):
			_draw_stamp(self, item)
	for bit in _bits:
		if not bool(bit["add"]):
			_draw_bit(self, bit)
	if _flash_left > 0.0 and _flash_time > 0.0:
		var color := _flash_color
		color.a *= _flash_left / _flash_time
		draw_rect(Rect2(Vector2.ZERO, size), color)
