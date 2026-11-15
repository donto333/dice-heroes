extends Control
## 어빌리티 컷인: 영웅 그림과 기술 이름이 띠와 함께 화면을 가로질러 나왔다 사라진다.
## play()는 끝날 때까지 기다린다. 화면 입력은 막지 않는다.

const Portrait := preload("res://scripts/ui/portrait.gd")
const Fx := preload("res://scripts/ui/fx.gd")

const IN_TIME := 0.2
const HOLD_TIME := 1.0
const OUT_TIME := 0.18

var _band: Panel
var _style: StyleBoxFlat
var _face: Control
var _title: Label
var _note: Label
## 띠 안에서 빛나는 것들(속도선·빛살·별빛)을 그리는 더하기 섞기 층
var _streaks: Control
var _tint := Color.WHITE
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# 뒤 화면을 어둡게 해서 컷인에 눈이 가게 한다.
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.08, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_band = Panel.new()
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.04, 0.16, 0.42, 0.96)
	_style.border_width_top = 8
	_style.border_width_bottom = 8
	_style.shadow_color = Color(0, 0, 0, 0.5)
	_style.shadow_size = 14
	_band.add_theme_stylebox_override("panel", _style)
	# 화면보다 넓은 띠를 살짝 기울여 가로지르게 한다.
	_band.anchor_left = -0.08
	_band.anchor_right = 1.08
	_band.rotation = deg_to_rad(-4.0)
	_band.anchor_top = 0.34
	_band.anchor_bottom = 0.34
	_band.offset_bottom = 210
	add_child(_band)
	_streaks = Control.new()
	_streaks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_streaks.offset_top = 8
	_streaks.offset_bottom = -8
	_streaks.clip_contents = true
	_streaks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_streaks.material = Fx.additive()
	_streaks.draw.connect(_draw_streaks)
	_band.add_child(_streaks)
	_face = Portrait.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.border_width = 5.0
	_face.hd = true
	_face.position = Vector2(60, -44)
	_face.size = Vector2(260, 298)
	_band.add_child(_face)
	_title = _label(64, 16)
	_title.position = Vector2(340, 34)
	_band.add_child(_title)
	_note = _label(22, 6)
	_note.position = Vector2(342, 116)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(410, 0)
	_note.size = Vector2(410, 80)
	_band.add_child(_note)


func _process(delta: float) -> void:
	if visible:
		_time += delta
		_streaks.queue_redraw()


## 띠 안의 빛: 왼쪽에서 뻗어 나오는 속도선, 영웅 그림 뒤에서 도는 빛살, 기술 이름 옆에서 번쩍이는 별빛.
func _draw_streaks() -> void:
	var area := _streaks.size
	var lines: Texture2D = Fx.tex("speed_lines")
	if lines != null:
		# 속도선 그림을 아주 크게 깔아 띠 안에서는 옆으로 달리는 줄무늬로 보이게 한다.
		var reach := area.x * 2.4 * (1.0 + 0.02 * sin(_time * 50.0))
		_streaks.draw_set_transform(Vector2(-area.x * 0.12, area.y * 0.5), floorf(_time * 20.0) * 0.17, Vector2.ONE)
		_streaks.draw_texture_rect(lines, Rect2(-reach / 2.0, -reach / 2.0, reach, reach), false, Color(_tint.r, _tint.g, _tint.b, 0.55))
		_streaks.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var beams: Texture2D = Fx.tex("rays_burst")
	if beams != null:
		var glow_size := area.y * 2.6
		_streaks.draw_set_transform(Vector2(190, area.y * 0.5), _time * 0.8, Vector2.ONE)
		_streaks.draw_texture_rect(beams, Rect2(-glow_size / 2.0, -glow_size / 2.0, glow_size, glow_size), false, Color(_tint.r, _tint.g, _tint.b, 0.8))
		_streaks.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var flare: Texture2D = Fx.tex("flare_star")
	if flare != null:
		var pulse := 0.6 + 0.4 * sin(_time * 9.0)
		var flare_size := 170.0 * pulse
		_streaks.draw_texture_rect(flare, Rect2(Vector2(336, 26) - Vector2(flare_size, flare_size) * 0.5, Vector2(flare_size, flare_size)), false, Color(1, 1, 1, 0.9))


func _label(font_size: int, outline: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## character: 기술을 쓰는 영웅, title: 기술 이름, note: 설명 한 줄, color: 쓰는 쪽 색
func play(character: Dictionary, title: String, note: String, color: Color) -> void:
	_style.border_color = color
	_style.bg_color = Color(color.r * 0.16, color.g * 0.16, color.b * 0.24, 0.96)
	_tint = color.lightened(0.25)
	_time = 0.0
	_face.border = color
	_face.show_character(character, color.darkened(0.5))
	_title.text = title
	_title.add_theme_color_override("font_color", Color("ffcf4d"))
	_note.text = note
	modulate.a = 0.0
	visible = true
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var rest := _band.position.x
	_band.position.x = rest - size.x * 0.6
	var tween := create_tween()
	tween.tween_property(_band, "position:x", rest, IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 1.0, IN_TIME * 0.7)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(_band, "position:x", rest + size.x * 0.4, OUT_TIME).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, OUT_TIME)
	await tween.finished
	_band.position.x = rest
	visible = false
