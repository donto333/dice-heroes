extends Control
## 금테 알약 버튼 몸통(UI 개편 1단계, 2026-11-17). 버튼 맨 뒤에 붙어 그림 `assets/ui_menu/pill_<색>.png`을 그린다.
## 그림은 2배 크기로 넣어 두고, 버튼 높이에 맞춰 줄인 뒤 양 끝(금 장식)은 그대로, 가운데만 가로로 늘린다.
## 누르면 살짝 어두워지며 내려가고, 꺼지면 회색 알약(pill_gray)으로 바뀐다. 색은 MenuArt.pill()이 정한다.

var texture: Texture2D
var off_texture: Texture2D
## 그림에서 양 끝 장식 너비(그림 높이에 대한 비율)
var cap := 0.5
var _button: BaseButton


func _init() -> void:
	name = "Pill"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _ready() -> void:
	_button = get_parent() as BaseButton
	if _button != null:
		_button.draw.connect(queue_redraw)
		_button.button_down.connect(_on_down)
		_button.button_up.connect(_on_up)


func _on_down() -> void:
	if _button == null or _button.disabled:
		return
	_button.pivot_offset = _button.size * 0.5
	_button.create_tween().tween_property(_button, "scale", Vector2(0.96, 0.96), 0.05)


func _on_up() -> void:
	if _button == null:
		return
	_button.pivot_offset = _button.size * 0.5
	var tween := _button.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_button, "scale", Vector2.ONE, 0.16)


func _draw() -> void:
	var picture := texture
	var tint := Color.WHITE
	var drop := 0.0
	if _button != null:
		if _button.disabled:
			if off_texture != null:
				picture = off_texture
			else:
				tint = Color(0.6, 0.62, 0.7)
		else:
			var mode := _button.get_draw_mode()
			if mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED:
				tint = Color(0.82, 0.82, 0.86)
				drop = 2.0
			elif mode == BaseButton.DRAW_HOVER:
				tint = Color(1.1, 1.1, 1.1)
	if picture == null or size.x < 8.0 or size.y < 8.0:
		return
	draw_slices(self, picture, Rect2(Vector2(0, drop), size), cap, tint)


## 가로로 3조각(왼 끝·가운데·오른 끝)을 높이에 맞춰 그린다. 끝 조각 너비는 그림 높이에 대한 비율.
static func draw_slices(canvas: CanvasItem, picture: Texture2D, area: Rect2, cap_left: float, tint: Color = Color.WHITE, cap_right: float = -1.0) -> void:
	if cap_right < 0.0:
		cap_right = cap_left
	var tex_size := picture.get_size()
	var ratio := area.size.y / tex_size.y
	var left_dst := tex_size.y * cap_left * ratio
	var right_dst := tex_size.y * cap_right * ratio
	var fit := minf(1.0, area.size.x / maxf(left_dst + right_dst, 1.0))
	left_dst *= fit
	right_dst *= fit
	var left_src := left_dst / ratio
	var right_src := right_dst / ratio
	var mid_src := maxf(tex_size.x - left_src - right_src, 1.0)
	var mid_dst := maxf(area.size.x - left_dst - right_dst, 0.0)
	var top := area.position.y
	var x := area.position.x
	canvas.draw_texture_rect_region(picture, Rect2(x, top, left_dst, area.size.y), Rect2(0, 0, left_src, tex_size.y), tint)
	if mid_dst > 0.0:
		canvas.draw_texture_rect_region(picture, Rect2(x + left_dst, top, mid_dst, area.size.y), Rect2(left_src, 0, mid_src, tex_size.y), tint)
	canvas.draw_texture_rect_region(picture, Rect2(x + left_dst + mid_dst, top, right_dst, area.size.y), Rect2(tex_size.x - right_src, 0, right_src, tex_size.y), tint)
