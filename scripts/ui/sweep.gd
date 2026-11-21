extends Control
## 버튼 몸통을 그리는 픽셀에만 빛을 더한다. 글자와 아이콘은 별도로 그린다.
const GameData := preload("res://scripts/game_data.gd")
const SHEEN := preload("res://scripts/ui/sweep.gdshader")

var period := 3.2
var travel := 0.7
var offset := 0.0
var surface: Control
var _time := 0.0
var _phase := -1.0
var _light := ShaderMaterial.new()


func _init() -> void:
	name = "Sweep"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var host := get_parent() as Control
	if surface == null and host.has_meta("skin"):
		surface = host.get_meta("skin")
	if surface == null:
		for skin_name in ["Pill", "Gloss"]:
			var skin := host.get_node_or_null(skin_name) as Control
			if skin != null and skin.visible:
				surface = skin
				break
	_light.shader = SHEEN
	# 그림·조각 판·광택 몸통은 자체 알파를 그대로 쓴다. 테마 버튼과 게이지는 같은 스타일 상자를 그린다.
	var painted := self if surface == null else surface
	painted.material = _light
	_light.set_shader_parameter("overlay", surface == null)
	var resize_light := func() -> void: _light.set_shader_parameter("extent", painted.size)
	painted.resized.connect(resize_light)
	resize_light.call()


func restart() -> void:
	_time = 0.0


func _process(delta: float) -> void:
	var next := -1.0
	var button := get_parent() as BaseButton
	if not GameData.low_gfx and (button == null or not button.disabled):
		_time += delta
		var elapsed := fposmod(_time + offset, period)
		if elapsed < travel:
			next = elapsed / travel
	if next != _phase:
		_phase = next
		_light.set_shader_parameter("phase", next)


func _draw() -> void:
	if surface != null:
		return
	var host := get_parent() as Control
	if host is ProgressBar:
		draw_style_box(host.get_theme_stylebox("fill"), Rect2(Vector2.ZERO, size))
	elif host is Button:
		var style_name := "pressed" if host.button_pressed else "normal"
		draw_style_box(host.get_theme_stylebox(style_name), Rect2(Vector2.ZERO, size))
