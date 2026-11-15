extends Control
## 판 위로 던져지는 큰 주사위 연출. 굴리기 버튼(오른쪽 아래) 쪽에서 날아와 통통 튀며 구르다가 가운데에서 멈춘다.
## 보여 주기만 한다. 실제 눈은 규칙 코드(scripts/rules/game.gd)가 이미 정한 값을 받는다.
## play()는 연출이 끝날 때까지 기다린다. 화면 입력은 막지 않는다.

const PIPS := {
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.27, 0.27), Vector2(0.73, 0.73)],
	3: [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)],
	4: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	5: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	6: [Vector2(0.27, 0.25), Vector2(0.73, 0.25), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.75), Vector2(0.73, 0.75)],
}
const DiePreview := preload("res://scripts/ui/die_preview.gd")
const GameData := preload("res://scripts/game_data.gd")
const Fx := preload("res://scripts/ui/fx.gd")
const ROLL_TIME := 0.95
const HOLD_TIME := 0.6
const FADE_TIME := 0.2
const DIE := 108.0
const BOUNCES := 3.0
const FACE_TIME := 0.07

var _rolls: Array = []
var _faces: Array = []
var _t := 0.0
var _playing := false
## 멈춘 뒤 흐른 시간(빛살·고리용)
var _settle := 0.0
## 더하기 섞기로 그리는 빛 층(주사위 뒤)
var _glow: Control
var _face_timer := 0.0
var _fx_rng := RandomNumberGenerator.new()
var _caption: Label
var _total: Label
var _color := Color.WHITE
## 지금 굴리는 쪽의 주사위 스킨 {"body", "edge", "pip"}. 비어 있으면 기본 색.
var skin: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false
	_glow = Control.new()
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.material = Fx.additive()
	_glow.show_behind_parent = true
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	_caption = _label(26)
	_caption.anchor_top = 0.5
	_caption.anchor_bottom = 0.5
	_caption.offset_top = -250
	_caption.offset_bottom = -210
	add_child(_caption)
	_total = _label(64)
	_total.anchor_top = 0.5
	_total.anchor_bottom = 0.5
	_total.offset_top = 78
	_total.offset_bottom = 166
	add_child(_total)


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## caption: 위의 작은 글씨("나 이동"), rolls: 주사위 눈들, result: 멈춘 뒤 큰 글씨("6칸!").
func play(caption: String, rolls: Array, result: String, color: Color) -> void:
	if rolls.is_empty():
		return
	_rolls = rolls
	_faces = rolls.duplicate()
	_color = color
	_caption.text = caption
	_caption.add_theme_color_override("font_color", color)
	_total.text = ""
	_total.add_theme_color_override("font_color", Color("ffcf4d"))
	_fx_rng.randomize()
	_t = 0.0
	_playing = true
	modulate.a = 1.0
	visible = true
	while _t < 1.0 and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	_playing = false
	_faces = rolls.duplicate()
	queue_redraw()
	_total.text = result
	_total.pivot_offset = _total.size * 0.5
	_total.scale = Vector2(0.3, 0.3)
	var pop := create_tween()
	pop.tween_property(_total, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(HOLD_TIME).timeout
	if not is_inside_tree():
		return
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	await fade.finished
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	if not _playing:
		# 멈춘 뒤: 빛 고리가 퍼지고 뒤에서 빛살이 돈다.
		_settle += delta
		queue_redraw()
		_glow.queue_redraw()
		return
	_settle = 0.0
	_t = min(1.0, _t + delta / ROLL_TIME)
	_face_timer -= delta
	if _face_timer <= 0.0 and _t < 0.82:
		_face_timer = FACE_TIME
		for index in _faces.size():
			_faces[index] = _fx_rng.randi_range(1, 6)
	elif _t >= 0.82:
		_faces = _rolls.duplicate()
	queue_redraw()


## 굴러가는 도중 t일 때 index번째 주사위의 [바닥 위치, 뜬 높이, 돈 각도].
func _pose(index: int, count: int, t: float) -> Array:
	var gap := DIE * 1.25
	var start := Vector2(size.x - 90.0, size.y - 90.0)
	var ease_t := 1.0 - pow(1.0 - t, 2.2)
	var rest := Vector2(size.x * 0.5 + (index - (count - 1) * 0.5) * gap, size.y * 0.5)
	var ground := start.lerp(rest, ease_t)
	# 튈수록 낮아지는 통통 튀기
	var hop := absf(sin(t * PI * BOUNCES + index * 0.5)) * 150.0 * (1.0 - t) * (1.0 - t)
	var spin := (1.0 - ease_t) * TAU * (2.0 + index * 0.5) * (1.0 if index % 2 == 0 else -1.0)
	return [ground, hop, spin]


func _draw() -> void:
	if _rolls.is_empty():
		return
	var count := _rolls.size()
	# 판을 가리지 않는다. 주사위는 판 위에서 바로 구른다(바닥에 그림자만 드리운다).
	if not _playing and Fx.tex("rays_burst") == null:
		# 멈춘 주사위 뒤에서 도는 빛살과 퍼지는 고리
		for index in count:
			var rest: Vector2 = _pose(index, count, 1.0)[0]
			var beams := 10
			for beam in beams:
				var angle := _settle * 1.4 + TAU * beam / beams
				var reach := DIE * (1.25 + 0.15 * sin(_settle * 5.0 + beam))
				var wide := 0.12
				draw_polygon(PackedVector2Array([rest,
					rest + Vector2(cos(angle - wide), sin(angle - wide)) * reach,
					rest + Vector2(cos(angle + wide), sin(angle + wide)) * reach]),
					PackedColorArray([Color(1, 0.92, 0.5, 0.55), Color(1, 0.92, 0.5, 0.0), Color(1, 0.92, 0.5, 0.0)]))
			var ring_t := clampf(_settle / 0.45, 0.0, 1.0)
			if ring_t < 1.0:
				draw_arc(rest, DIE * (0.6 + ring_t * 1.1), 0.0, TAU, 40, Color(1, 1, 1, 1.0 - ring_t), 7.0 * (1.0 - ring_t) + 1.0)
	if _playing:
		# 굴러오는 동안 뒤에 남는 잔상
		for ghost: int in [3, 2, 1]:
			var past: float = _t - float(ghost) * 0.035
			if past <= 0.0 or _t > 0.85:
				continue
			for index in count:
				var pose := _pose(index, count, past)
				var where: Vector2 = pose[0]
				draw_set_transform(where - Vector2(0, float(pose[1])), float(pose[2]), Vector2.ONE)
				draw_rect(Rect2(Vector2(-DIE, -DIE) * 0.5, Vector2(DIE, DIE)), Color(_color.r, _color.g, _color.b, 0.16 / float(ghost)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for index in count:
		var pose := _pose(index, count, _t)
		var ground: Vector2 = pose[0]
		var hop := float(pose[1])
		var scale_now := 1.0 + hop / 500.0
		if not _playing:
			# 멈추는 순간 통 하고 커졌다 돌아온다.
			scale_now = 1.0 + 0.22 * maxf(1.0 - _settle / 0.2, 0.0)
		draw_set_transform(ground + Vector2(DIE * 0.12, DIE * 0.55), 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, DIE * 0.62 * (1.0 - hop / 400.0), Color(0, 0, 0, 0.22))
		draw_circle(Vector2.ZERO, DIE * 0.48 * (1.0 - hop / 400.0), Color(0, 0, 0, 0.3))
		draw_set_transform(ground - Vector2(0, hop), float(pose[2]), Vector2(scale_now, scale_now))
		var face_value := clampi(int(_faces[index]), 1, 6)
		var solid: Texture2D = GameData.die_face(face_value)
		if solid != null:
			# 입체 주사위 그림. 산 주사위 모양(스킨)의 몸통 색을 살짝 입힌다.
			var body_tint := Color(str(skin.get("body", "ffffff"))).lerp(Color.WHITE, 0.35)
			var solid_size := DIE * 1.25
			draw_texture_rect(solid, Rect2(-solid_size / 2.0, -solid_size / 2.0, solid_size, solid_size), false, body_tint)
		else:
			DiePreview.draw_die(self, DIE, face_value, skin)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not _playing and _total.text != "":
		# 합계 글자 뒤의 금색 원판(모두의 마블의 합계 표시처럼) 둘레로 작은 빛 알이 돈다.
		var badge := Vector2(size.x * 0.5, size.y * 0.5 - DIE * 1.35)
		var pop := 1.0 + 0.2 * maxf(1.0 - _settle / 0.2, 0.0)
		var medal: Texture2D = GameData.object("total_badge")
		if medal != null:
			var medal_size := 150.0 * pop
			draw_set_transform(badge, _settle * 0.6, Vector2.ONE)
			draw_texture_rect(medal, Rect2(-medal_size / 2.0, -medal_size / 2.0, medal_size, medal_size), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_circle(badge, 50.0 * pop, Color("7a4a00"))
			draw_circle(badge, 45.0 * pop, Color("ffc62b"))
			draw_circle(badge + Vector2(0, -8), 36.0 * pop, Color(1, 1, 1, 0.22))
		for spark in 10:
			var angle := _settle * 1.8 + TAU * spark / 10.0
			draw_circle(badge + Vector2(cos(angle), sin(angle)) * 60.0, 4.0, Color(1, 0.97, 0.7, 0.9))
		var sum := 0
		for value in _rolls:
			sum += int(value)
		var font := get_theme_default_font()
		var digits := int(54.0 * pop)
		draw_string_outline(font, badge + Vector2(-60, digits * 0.36), str(sum), HORIZONTAL_ALIGNMENT_CENTER, 120, digits, 6, Color("fff3c0"))
		draw_string(font, badge + Vector2(-60, digits * 0.36), str(sum), HORIZONTAL_ALIGNMENT_CENTER, 120, digits, Color("5a3200"))


## 주사위 뒤에서 빛나는 효과(더하기 섞기 층): 멈추면 빛살이 돌고 별빛이 번쩍이며 충격 고리가 퍼진다.
func _draw_glow() -> void:
	if _rolls.is_empty() or _playing or Fx.tex("rays_burst") == null:
		return
	var count := _rolls.size()
	for index in count:
		var rest: Vector2 = _pose(index, count, 1.0)[0]
		var beams: Texture2D = Fx.tex("rays_burst")
		var reach := DIE * 3.4
		_glow.draw_set_transform(rest, _settle * 0.9, Vector2.ONE)
		_glow.draw_texture_rect(beams, Rect2(-reach / 2.0, -reach / 2.0, reach, reach), false, Color(1.0, 0.9, 0.55, 0.9))
		_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var flash_t := clampf(_settle / 0.5, 0.0, 1.0)
		var flare: Texture2D = Fx.tex("flare_star")
		if flare != null and flash_t < 1.0:
			var flare_size := DIE * (2.0 + 2.6 * flash_t)
			_glow.draw_texture_rect(flare, Rect2(rest - Vector2(flare_size, flare_size) * 0.5, Vector2(flare_size, flare_size)), false, Color(1, 1, 1, 1.0 - flash_t))
		var ring: Texture2D = Fx.tex("ring_shock")
		if ring != null and flash_t < 1.0:
			var grow := 1.0 - pow(1.0 - flash_t, 3.0)
			var ring_size := DIE * (1.2 + grow * 3.2)
			_glow.draw_set_transform(rest + Vector2(0, DIE * 0.45), 0.0, Vector2(1.0, 0.42))
			_glow.draw_texture_rect(ring, Rect2(-ring_size / 2.0, -ring_size / 2.0, ring_size, ring_size), false, Color(1, 1, 1, 1.0 - flash_t))
			_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 가운데가 (0,0)인 주사위 하나. 둥근 모서리, 아래 두께, 눈.
func _draw_die(value: int) -> void:
	var half := DIE * 0.5
	var body := StyleBoxFlat.new()
	body.bg_color = Color("f8f4ea")
	body.set_corner_radius_all(16)
	body.border_color = Color("9a9484")
	body.set_border_width_all(3)
	body.border_width_bottom = 9
	draw_style_box(body, Rect2(Vector2(-half, -half), Vector2(DIE, DIE)))
	var shine := StyleBoxFlat.new()
	shine.bg_color = Color(1, 1, 1, 0.75)
	shine.set_corner_radius_all(10)
	draw_style_box(shine, Rect2(Vector2(-half + 8, -half + 7), Vector2(DIE - 16, 10)))
	var pip_color := Color("c0392b") if value == 1 else Color("1b1f3b")
	var pip_size := DIE * (0.14 if value == 1 else 0.095)
	for pip in PIPS[clampi(value, 1, 6)]:
		draw_circle(Vector2(-half, -half - 3) + pip * DIE, pip_size, pip_color)
