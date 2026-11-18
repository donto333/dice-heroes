extends Control
## 소환 연출 한 장면(기획: 프로젝트 문서 '소환연출기획').
## 별빛 제단 → 운명의 주사위 강림 → 굴림·승격(파랑→보라→금) → 폭발 → 뒷면 카드 배치 → 뒤집기(★★★는 등장 컷) → 결과.
## 뽑기 결과는 이미 정해져 저장된 뒤에 들어온다. 여기서는 보여 주기만 한다.
## 쓰는 법: var show := SummonShow.new(); app.add_child(show); var again: bool = await show.play(app, results, again_cost)

const Kit := preload("res://scripts/ui/kit.gd")
const Fx := preload("res://scripts/ui/fx.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const Confetti := preload("res://scripts/ui/confetti.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const GameData := preload("res://scripts/game_data.gd")
const ArtView := preload("res://scripts/ui/art_view.gd")

const ART := "res://assets/ui_summon/"
const GRADE_KEYS := {1: "blue", 2: "purple", 3: "gold"}
const GRADE_TINTS := {1: Color("6fc3ff"), 2: Color("c58bff"), 3: Color("ffd24a")}
const CIRCLES := {1: "magic_circle_blue", 2: "magic_circle_purple", 3: "magic_circle_gold"}
const PILLARS := {1: "light_pillar_blue", 2: "light_pillar_blue", 3: "light_pillar"}
const CARD_RATIO := 0.75
## 카드 앞면 틀에서 초상화가 들어갈 창(틀 그림 크기에 대한 비율). tools/import_summon.py가 재서 meta.json에 적는다.
const DEFAULT_WINDOW := [0.08, 0.06, 0.92, 0.76]

signal _done(again: bool)

var _app
var _results: Array = []
var _best := 1
var _again_cost := 0
## '한 번 더' 값의 재화: "gems"(보석 소환) 또는 "gold"(골드 소환)
var again_currency := "gems"
## "hero"(영웅 소환) 또는 "card"(카드 뽑기, 2026-11-18). 카드면 앞면에 카드 그림, ★★★는 전설 카드 등장 컷.
var kind := "hero"
var _skip := false
var _tapped := false
var _finished := false
var _meta: Dictionary = {}

var _backdrop: TextureRect
var _shade: ColorRect
var _glow: Control
var _die: TextureRect
var _hint: Label
var _stage: Control
var _cards: Array = []
var _flash: ColorRect
var _skip_button: Button
var _title: Label
var _buttons: HBoxContainer
var _fx: Control

var _time := 0.0
var _die_grade := 1
var _circle_open := 0.0
var _pillar := 0.0
var _rays := 0.0


static func art(name: String) -> Texture2D:
	for ending in [".png", ".jpg"]:
		var path: String = ART + name + ending
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# 메뉴 화면의 위로 올려 그리는 것(왼쪽 판 아이콘 등)보다도 위에 온다.
	z_index = 100


## 연출을 보여 주고, 닫힐 때 '한 번 더'를 눌렀는지 돌려준다. again_cost가 0이면 '한 번 더' 버튼이 없다.
func play(app, results: Array, again_cost: int = 0) -> bool:
	_app = app
	_results = results
	_again_cost = again_cost
	for entry in results:
		_best = maxi(_best, int(entry["grade"]))
	var meta_path := ART + "meta.json"
	if FileAccess.file_exists(meta_path):
		_meta = GameData.load_json(meta_path)
	_build()
	_run()
	var again: bool = await _done
	queue_free()
	return again


func _build() -> void:
	_shade = ColorRect.new()
	_shade.color = Color(0.03, 0.01, 0.1, 1.0)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_backdrop = TextureRect.new()
	_backdrop.texture = art("bg_altar")
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_glow = Control.new()
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.material = Fx.additive()
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	_die = TextureRect.new()
	_die.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_die.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_die.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_die.visible = false
	add_child(_die)
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_fx = Fx.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.quiet = GameData.low_gfx
	add_child(_fx)
	_hint = Kit.label("화면을 눌러 뽑기" if kind == "card" else "화면을 눌러 소환", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_outline(_hint, 8)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -96
	_hint.offset_bottom = -56
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	add_child(_hint)
	_title = Kit.label("", 34, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_outline(_title, 10)
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 14
	_title.offset_bottom = 64
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.visible = false
	add_child(_title)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 18)
	_buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_buttons.offset_top = -84
	_buttons.offset_bottom = -18
	_buttons.visible = false
	add_child(_buttons)
	var ok: Button = MenuArt.pill_button("확인", "blue", "m")
	ok.custom_minimum_size = Vector2(200, 60)
	ok.pressed.connect(_close.bind(false))
	_buttons.add_child(ok)
	if _again_cost > 0:
		var more: Button = MenuArt.pill_button("한 번 더  %s" % Kit.comma(_again_cost), "gold", "m")
		more.custom_minimum_size = Vector2(260, 60)
		var gem: TextureRect = Kit.icon("gold" if again_currency == "gold" else "gem", 28.0)
		if gem.texture != null:
			more.icon = gem.texture
			more.add_theme_constant_override("icon_max_width", 28)
		more.pressed.connect(_close.bind(true))
		_buttons.add_child(more)
	_skip_button = MenuArt.pill_button("건너뛰기", "gray", "s")
	_skip_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_skip_button.offset_left = -170
	_skip_button.offset_right = -18
	_skip_button.offset_top = 16
	_skip_button.offset_bottom = 62
	_skip_button.pressed.connect(_on_skip)
	add_child(_skip_button)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func _outline(label: Label, width: int) -> void:
	label.add_theme_constant_override("outline_size", width)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.14))


func _process(delta: float) -> void:
	_time += delta
	if _glow != null:
		_glow.queue_redraw()
	if _hint != null and _hint.visible:
		_hint.modulate.a = 0.55 + 0.45 * sin(_time * 5.0)
	if _die != null and _die.visible:
		_die.rotation = sin(_time * 1.7) * 0.07


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_tapped = true


# ---------------------------------------------------------------- 자리 계산

func _altar() -> Vector2:
	return size * Vector2(0.5, 0.80)


func _die_spot() -> Vector2:
	return size * Vector2(0.5, 0.40)


func _card_size() -> Vector2:
	var count := _results.size()
	var tall := size.y * (0.58 if count <= 1 else (0.44 if count <= 5 else 0.335))
	return Vector2(tall * CARD_RATIO, tall)


func _card_spot(index: int) -> Vector2:
	var count := _results.size()
	var columns := mini(count, 5)
	var rows := int(ceil(float(count) / float(columns)))
	var card := _card_size()
	var gap := 14.0
	var row := index / columns
	var in_row := mini(columns, count - row * columns)
	var wide := in_row * card.x + (in_row - 1) * gap
	var tall := rows * card.y + (rows - 1) * gap
	var top := size.y * 0.47 - tall / 2.0
	return Vector2((size.x - wide) / 2.0 + (index % columns) * (card.x + gap), top + row * (card.y + gap))


# ---------------------------------------------------------------- 빛 층

func _sprite(name: String, center: Vector2, wide: float, tint: Color, turn: float = 0.0, squash: float = 1.0) -> void:
	var texture: Texture2D = Fx.tex(name)
	if texture == null or wide <= 0.0:
		return
	var tall := wide * float(texture.get_height()) / maxf(float(texture.get_width()), 1.0)
	# 먼저 돌리고 그다음 세로로 눌러야 바닥에 누운 원판이 제자리에서 도는 것처럼 보인다.
	_glow.draw_set_transform_matrix(Transform2D(0.0, Vector2(1.0, squash), 0.0, center) * Transform2D(turn, Vector2.ZERO))
	_glow.draw_texture_rect(texture, Rect2(-wide / 2.0, -tall / 2.0, wide, tall), false, tint)
	_glow.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_glow() -> void:
	var tint: Color = GRADE_TINTS[_die_grade]
	var reach := minf(size.x, size.y)
	if _circle_open > 0.0:
		_sprite(CIRCLES[_die_grade], _altar(), reach * 0.86 * _circle_open, Color(1, 1, 1, _circle_open), _time * 1.2, 0.32)
		_sprite("ring_double", _altar(), reach * 1.1 * _circle_open, Color(tint.r, tint.g, tint.b, 0.6 * _circle_open), -_time * 0.8, 0.32)
	if _rays > 0.0:
		_sprite("rays_burst", _die_spot(), reach * (0.9 + 0.5 * _rays), Color(tint.r, tint.g, tint.b, 0.75 * _rays), _time * 0.6)
		_sprite("glow_soft", _die_spot(), reach * 0.8, Color(tint.r, tint.g, tint.b, 0.6 * _rays))
		var motes := 8 if GameData.low_gfx else 22
		for mote in motes:
			var phase := fposmod(_time * (0.7 + (mote % 5) * 0.15) + mote * 0.137, 1.0)
			var angle := mote * 2.399
			var spot := _die_spot() + Vector2(cos(angle), sin(angle)) * reach * 0.55 * (1.0 - phase)
			_sprite("flare_cross", spot, (18.0 + (mote % 4) * 10.0) * sin(phase * PI), Color(1, 1, 1, _rays), phase * 2.0)
	if _pillar > 0.0:
		var pillar: Texture2D = Fx.tex(PILLARS[_best])
		if pillar != null:
			var wide := reach * (0.3 + 0.9 * _pillar)
			var tall := size.y * 1.2
			_glow.draw_texture_rect(pillar, Rect2(_altar().x - wide / 2.0, _altar().y + reach * 0.05 - tall, wide, tall), false, Color(1, 1, 1, minf(1.0, _pillar * 1.4)))
		_sprite("flare_star", _die_spot(), size.x * (0.3 + 1.2 * _pillar), Color(1, 1, 1, _pillar))


# ---------------------------------------------------------------- 진행

func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not _skip and is_inside_tree():
		await get_tree().process_frame
		left -= get_process_delta_time()


## 누를 때까지(또는 limit초) 기다린다.
func _wait_tap(limit: float) -> void:
	_tapped = false
	var left := limit
	while left > 0.0 and not _tapped and not _skip and is_inside_tree():
		await get_tree().process_frame
		left -= get_process_delta_time()
	_tapped = false


func _set_die(grade: int) -> void:
	_die_grade = grade
	_die.texture = art("die_" + GRADE_KEYS[grade])


func _white(alpha: float, seconds: float, color: Color = Color.WHITE) -> void:
	_flash.color = Color(color.r, color.g, color.b, alpha)
	create_tween().tween_property(_flash, "color:a", 0.0, seconds)


func _run() -> void:
	await get_tree().process_frame
	if _app.instant:
		_skip = true
	if _skip:
		_finish()
		return
	# 0. 진입: 제단이 떠오른다.
	_backdrop.modulate.a = 0.0
	create_tween().tween_property(_backdrop, "modulate:a", 1.0, 0.4)
	create_tween().tween_property(self, "_circle_open", 1.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _wait(0.35)
	# 1. 강림: 파란 운명의 주사위가 내려온다.
	var die_size := size.y * 0.36
	_die.size = Vector2(die_size, die_size)
	_die.pivot_offset = _die.size / 2.0
	_set_die(1)
	_die.visible = true
	_die.position = Vector2(_die_spot().x - die_size / 2.0, -die_size)
	_app.play("skill")
	var drop := create_tween()
	drop.tween_property(_die, "position:y", _die_spot().y - die_size / 2.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(0.85)
	if not _skip:
		_hint.visible = true
		await _wait_tap(1.5)
		_hint.visible = false
	# 2. 굴림·승격: 색이 바뀔 때마다 번쩍이고 흔들린다.
	if not _skip:
		_app.play("click")
		create_tween().tween_property(self, "_rays", 1.0, 0.5)
		var hop := create_tween()
		hop.tween_property(_die, "scale", Vector2(1.18, 1.18), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		hop.tween_property(_die, "scale", Vector2.ONE, 0.2)
		await _wait(0.55)
	for grade in [2, 3]:
		if _skip or _best < grade:
			break
		await _wait(0.3)
		if _skip:
			break
		_set_die(grade)
		_white(0.75, 0.3, GRADE_TINTS[grade])
		_app.play("reveal")
		_fx.shake(self, 10.0 if grade == 2 else 20.0, 0.3)
		_fx.burst(_die_spot(), "star" if grade == 3 else "spark", 26, 1.4)
		var pulse := create_tween()
		pulse.tween_property(_die, "scale", Vector2(1.3, 1.3), 0.1)
		pulse.tween_property(_die, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await _wait(0.4)
	# 3. 폭발: 주사위가 제단에 내리꽂히고 빛기둥이 솟는다.
	if not _skip:
		await _wait(0.25)
		var slam := create_tween().set_parallel(true)
		slam.tween_property(_die, "position:y", _altar().y - die_size * 0.7, 0.16).set_ease(Tween.EASE_IN)
		slam.tween_property(_die, "scale", Vector2(0.5, 0.5), 0.16)
		await _wait(0.16)
	if not _skip:
		_die.visible = false
		_rays = 0.0
		_app.play("summon_%d" % clampi(_best, 1, 3))
		_fx.shake(self, 16.0, 0.3)
		create_tween().tween_property(self, "_pillar", 1.0, 0.3)
		await _wait(0.3)
		_white(1.0, 0.5)
		create_tween().tween_property(self, "_pillar", 0.0, 0.6)
	if _skip:
		_finish()
		return
	# 4. 카드 배치: 뒷면 카드가 빛 속에서 날아와 놓인다.
	_make_cards()
	for index in _cards.size():
		var card: Control = _cards[index]
		var target := _card_spot(index)
		card.position = _die_spot() - card.size / 2.0
		card.scale = Vector2(0.15, 0.15)
		card.modulate.a = 0.0
		var fly := card.create_tween().set_parallel(true)
		fly.tween_property(card, "position", target, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(index * 0.06)
		fly.tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(index * 0.06)
		fly.tween_property(card, "modulate:a", 1.0, 0.12).set_delay(index * 0.06)
	await _wait(0.4 + _cards.size() * 0.06)
	# 5. 뒤집기: 차례로. ★★★는 등장 컷을 먼저 보여 준다.
	for index in _cards.size():
		if _skip:
			break
		var card: Control = _cards[index]
		if bool(card.get_meta("open")):
			continue
		var entry: Dictionary = _results[index]
		if int(entry["grade"]) >= 3:
			await _wait(0.2)
			if _skip:
				break
			if kind == "card":
				await _card_cut(entry)
			else:
				await _hero_cut(entry)
			if _skip:
				break
		await _flip(card)
		await _wait(0.12)
	_finish()


## 남은 연출을 건너뛰고 결과 장면으로: 카드를 모두 앞면으로 놓고 버튼을 보여 준다.
func _finish() -> void:
	if _finished:
		return
	_finished = true
	_skip = true
	# 결과 장면에서는 카드가 잘 보이게 바탕을 조금 어둡게 한다.
	_backdrop.modulate = Color(0.7, 0.7, 0.78, 1.0)
	# 결과 장면에서는 카드가 주인공이라 바닥 마법진을 끈다.
	_circle_open = 0.0
	_pillar = 0.0
	_rays = 0.0
	_die.visible = false
	_hint.visible = false
	_skip_button.visible = false
	if _cards.is_empty():
		_make_cards()
	for index in _cards.size():
		var card: Control = _cards[index]
		card.position = _card_spot(index)
		card.scale = Vector2.ONE
		card.modulate.a = 1.0
		_open_card(card)
	if kind == "card":
		_title.text = "★★★ 전설 카드!" if _best >= 3 else "카드 뽑기 결과"
	else:
		_title.text = "★★★ 등장!" if _best >= 3 else "소환 결과"
	_title.visible = true
	_buttons.visible = true
	_buttons.modulate.a = 0.0
	create_tween().tween_property(_buttons, "modulate:a", 1.0, 0.25)
	if _best >= 3 and not _app.instant:
		_app.play("purchase")
		_fx.shower("petal", 20 if GameData.low_gfx else 50)


func _on_skip() -> void:
	_app.play("click")
	_skip = true
	# 진행 중인 기다림이 풀리면 _run이 _finish로 간다. 등장 컷이 떠 있으면 그쪽도 닫힌다.


func _close(again: bool) -> void:
	_app.play("click")
	_done.emit(again)


# ---------------------------------------------------------------- 카드

func _window_of(grade: int) -> Array:
	var found: Variant = _meta.get("card_front_" + GRADE_KEYS[grade], DEFAULT_WINDOW)
	return found if typeof(found) == TYPE_ARRAY and (found as Array).size() == 4 else DEFAULT_WINDOW


func _make_cards() -> void:
	var card_size := _card_size()
	for entry in _results:
		var grade := clampi(int(entry["grade"]), 1, 3)
		var character: Dictionary = _app.character(str(entry["id"])) if kind == "hero" else _card_info(str(entry["id"]))
		var card := Control.new()
		card.size = card_size
		card.pivot_offset = card_size / 2.0
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.set_meta("open", false)
		card.set_meta("grade", grade)
		card.gui_input.connect(_on_card_input.bind(card))
		_stage.add_child(card)
		# 앞면: 초상화(틀의 창 자리) → 틀 → 별·이름·딱지
		var front := Control.new()
		front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		front.mouse_filter = Control.MOUSE_FILTER_IGNORE
		front.visible = false
		card.add_child(front)
		var window := _window_of(grade)
		var face = _card_picture(str(entry["id"]), grade) if kind == "card" else Portrait.new()
		face.anchor_left = float(window[0])
		face.anchor_top = float(window[1])
		face.anchor_right = float(window[2])
		face.anchor_bottom = float(window[3])
		if kind == "hero":
			face.hd = _results.size() <= 5
			face.border_width = 0.0
			face.show_character(character, Kit.CATEGORY_COLORS.get(character.get("category", ""), Kit.LINE))
		front.add_child(face)
		var frame_tex := art("card_front_" + GRADE_KEYS[grade])
		if frame_tex != null:
			var frame := TextureRect.new()
			frame.texture = frame_tex
			frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			frame.stretch_mode = TextureRect.STRETCH_SCALE
			frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			front.add_child(frame)
		elif kind == "hero":
			face.border = Kit.GRADE_COLORS[grade]
			face.border_width = 4.0
		var small := _results.size() > 5
		var stars := Kit.label("★".repeat(grade), 15 if small else 22, GRADE_TINTS[grade] if grade > 1 else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		_outline(stars, 6)
		stars.anchor_left = 0.0
		stars.anchor_right = 1.0
		stars.anchor_top = float(window[3]) - 0.12
		stars.anchor_bottom = float(window[3])
		stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		front.add_child(stars)
		var name_label := Kit.label(str(character.get("name", "")), 15 if small else 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		_outline(name_label, 5)
		name_label.clip_text = true
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.anchor_left = 0.1
		name_label.anchor_right = 0.9
		name_label.anchor_top = float(window[3]) + 0.02
		name_label.anchor_bottom = 0.94
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		front.add_child(name_label)
		Kit.squeeze_text(name_label, 15 if small else 22, 10)
		if bool(entry["new"]):
			var badge := TextureRect.new()
			badge.texture = art("badge_new")
			badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var badge_size := card_size.x * 0.42
			badge.position = Vector2(-badge_size * 0.22, -badge_size * 0.22)
			badge.size = Vector2(badge_size, badge_size)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			front.add_child(badge)
			var word := Kit.label("NEW", int(badge_size * 0.26), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			_outline(word, 5)
			word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			word.position = badge.position
			word.size = badge.size
			word.mouse_filter = Control.MOUSE_FILTER_IGNORE
			front.add_child(word)
		else:
			var note := "+%s" % Kit.money_text("gold", int(entry.get("gold", 0))) if kind == "card" else "조각 +%d" % int(entry.get("shards", 0))
			var shards := Kit.label(note, 13 if small else 18, Kit.GOLD if kind == "card" else Kit.GEM, HORIZONTAL_ALIGNMENT_CENTER)
			_outline(shards, 5)
			shards.anchor_left = 0.0
			shards.anchor_right = 1.0
			shards.anchor_top = float(window[1])
			shards.anchor_bottom = float(window[1]) + 0.12
			shards.mouse_filter = Control.MOUSE_FILTER_IGNORE
			front.add_child(shards)
		# 뒷면
		var back := TextureRect.new()
		back.texture = art("card_back_" + GRADE_KEYS[grade])
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_SCALE
		back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(back)
		if back.texture == null:
			var plain := ColorRect.new()
			plain.color = (GRADE_TINTS[grade] as Color).darkened(0.45)
			plain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			plain.mouse_filter = Control.MOUSE_FILTER_IGNORE
			back.add_child(plain)
		card.set_meta("front", front)
		card.set_meta("back", back)
		_cards.append(card)


func _open_card(card: Control) -> void:
	card.set_meta("open", true)
	(card.get_meta("front") as Control).visible = true
	(card.get_meta("back") as Control).visible = false


## 카드를 직접 누르면 먼저 뒤집힌다(★★★ 등장 컷은 차례가 올 때만 나온다).
func _on_card_input(event: InputEvent, card: Control) -> void:
	if not ((event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed):
		return
	if _finished or bool(card.get_meta("open")) or int(card.get_meta("grade")) >= 3:
		_tapped = true
		return
	_flip(card)


## 가로로 접혔다가 앞면으로 펴진다.
func _flip(card: Control) -> void:
	if bool(card.get_meta("open")):
		return
	card.set_meta("open", true)
	_app.play("click")
	var grade := int(card.get_meta("grade"))
	var fold := card.create_tween()
	fold.tween_property(card, "scale:x", 0.0, 0.11).set_ease(Tween.EASE_IN)
	await fold.finished
	if not is_instance_valid(card):
		return
	_open_card(card)
	var open := card.create_tween()
	open.tween_property(card, "scale:x", 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if grade >= 2:
		_fx.burst(card.position + card.size / 2.0, "star" if grade >= 3 else "spark", 14 if grade >= 3 else 8, 1.0)
	await open.finished


# ---------------------------------------------------------------- ★★★ 등장 컷

func _hero_cut(entry: Dictionary) -> void:
	var character: Dictionary = _app.character(str(entry["id"]))
	var cut := Control.new()
	cut.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cut)
	move_child(cut, _skip_button.get_index())
	var glory := TextureRect.new()
	glory.texture = art("bg_glory")
	glory.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glory.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	glory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cut.add_child(glory)
	if glory.texture == null:
		var plain := ColorRect.new()
		plain.color = Color(0.25, 0.16, 0.02)
		plain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		plain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cut.add_child(plain)
	var side := size.y * 0.62
	var face := Portrait.new()
	face.hd = true
	face.border = Kit.GOLD
	face.border_width = 6.0
	face.size = Vector2(side, side)
	face.position = Vector2((size.x - side) / 2.0, size.y * 0.07)
	face.pivot_offset = face.size / 2.0
	face.show_character(character, Kit.CATEGORY_COLORS.get(character.get("category", ""), Kit.LINE))
	cut.add_child(face)
	var stars := Kit.label("★★★", 40, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_outline(stars, 10)
	var name_label := Kit.label(str(character.get("name", "")), 54, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_outline(name_label, 14)
	var title_label := Kit.label("「%s」" % str(character.get("title", "")), 26, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_outline(title_label, 8)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -4)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	words.offset_top = -size.y * 0.30
	words.offset_bottom = -10
	words.add_child(stars)
	words.add_child(name_label)
	if str(character.get("title", "")) != "":
		words.add_child(title_label)
	cut.add_child(words)
	var confetti := Confetti.new()
	confetti.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confetti.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cut.add_child(confetti)
	# 검은 그림자로 커지며 나타났다가 번쩍하며 색이 돌아온다.
	cut.modulate.a = 0.0
	face.modulate = Color(0, 0, 0)
	face.scale = Vector2(0.7, 0.7)
	words.modulate.a = 0.0
	var enter := cut.create_tween().set_parallel(true)
	enter.tween_property(cut, "modulate:a", 1.0, 0.2)
	enter.tween_property(face, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(0.5)
	if not _skip:
		_white(0.9, 0.35, Color("fff3c0"))
		face.modulate = Color.WHITE
		_app.play("summon_3")
		_app.say(str(character.get("id", "")), "select")
		_fx.shake(self, 12.0, 0.25)
		if not GameData.low_gfx:
			confetti.start()
		create_tween().tween_property(words, "modulate:a", 1.0, 0.2)
		await _wait(0.4)
		await _wait_tap(1.6)
	var leave := cut.create_tween()
	leave.tween_property(cut, "modulate:a", 0.0, 0.2)
	await leave.finished
	cut.queue_free()


# ---------------------------------------------------------------- 카드 뽑기

func _card_info(id: String) -> Dictionary:
	return (_app.data.get("cards", {}) as Dictionary).get(id, {})


## 카드 앞면 그림(assets/art/cards/<id>). 없으면 등급색 판에 카드 아이콘.
func _card_picture(id: String, grade: int) -> Control:
	var picture := ArtView.new()
	picture.show_art("cards/" + id)
	picture.focus_y = 0.5
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if picture.has_art():
		return picture
	picture.free()
	var plain := PanelContainer.new()
	plain.add_theme_stylebox_override("panel", Kit.box((GRADE_TINTS[grade] as Color).darkened(0.5), Color.TRANSPARENT, 0, 4, 4))
	plain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(Kit.icon("card", 64.0))
	plain.add_child(holder)
	return plain


## ★★★ 전설 카드 등장 컷: 금빛 바탕에 카드 그림이 크게 돌며 나타나고 이름·설명이 뜬다.
func _card_cut(entry: Dictionary) -> void:
	var info := _card_info(str(entry["id"]))
	var cut := Control.new()
	cut.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cut)
	move_child(cut, _skip_button.get_index())
	var glory := TextureRect.new()
	glory.texture = art("bg_glory")
	glory.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glory.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	glory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cut.add_child(glory)
	if glory.texture == null:
		var plain := ColorRect.new()
		plain.color = Color(0.25, 0.16, 0.02)
		plain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		plain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cut.add_child(plain)
	# 큰 카드: 틀(card_front_gold) 안 창 자리에 카드 그림
	var tall := size.y * 0.62
	var card := Control.new()
	card.size = Vector2(tall * CARD_RATIO, tall)
	card.position = Vector2((size.x - card.size.x) / 2.0, size.y * 0.05)
	card.pivot_offset = card.size / 2.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cut.add_child(card)
	var window := _window_of(3)
	var picture := _card_picture(str(entry["id"]), 3)
	picture.anchor_left = float(window[0])
	picture.anchor_top = float(window[1])
	picture.anchor_right = float(window[2])
	picture.anchor_bottom = float(window[3])
	card.add_child(picture)
	var frame_tex := art("card_front_gold")
	if frame_tex != null:
		var frame := TextureRect.new()
		frame.texture = frame_tex
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frame)
	var stars := Kit.label("★★★ 전설 카드", 34, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_outline(stars, 10)
	var name_label := Kit.label(str(info.get("name", "")), 50, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_outline(name_label, 14)
	var text_label := Kit.label(str(info.get("text", "")), 22, Color("fff3c0"), HORIZONTAL_ALIGNMENT_CENTER)
	_outline(text_label, 7)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	words.offset_top = -size.y * 0.31
	words.offset_bottom = -10
	words.offset_left = size.x * 0.15
	words.offset_right = -size.x * 0.15
	words.add_child(stars)
	words.add_child(name_label)
	if str(info.get("text", "")) != "":
		words.add_child(text_label)
	cut.add_child(words)
	var confetti := Confetti.new()
	confetti.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confetti.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cut.add_child(confetti)
	# 뒷면이 보이게 돌아 들어와 번쩍하며 앞면으로 바뀐다.
	cut.modulate.a = 0.0
	card.modulate = Color(0, 0, 0)
	card.scale = Vector2(0.05, 0.7)
	words.modulate.a = 0.0
	var enter := cut.create_tween().set_parallel(true)
	enter.tween_property(cut, "modulate:a", 1.0, 0.2)
	enter.tween_property(card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(0.55)
	if not _skip:
		_white(0.9, 0.35, Color("fff3c0"))
		card.modulate = Color.WHITE
		_app.play("summon_3")
		_fx.shake(self, 12.0, 0.25)
		_fx.burst(card.position + card.size / 2.0, "star", 30, 1.6)
		if not GameData.low_gfx:
			confetti.start()
		create_tween().tween_property(words, "modulate:a", 1.0, 0.2)
		await _wait(0.4)
		await _wait_tap(1.6)
	var leave := cut.create_tween()
	leave.tween_property(cut, "modulate:a", 0.0, 0.2)
	await leave.finished
	cut.queue_free()
