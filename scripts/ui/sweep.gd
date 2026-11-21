extends Control

const GameData := preload("res://scripts/game_data.gd")
## 큰 버튼 위를 몇 초마다 비스듬히 훑고 지나가는 흰 빛. "눌러 보세요" 하는 느낌을 준다.
## 버튼 안쪽에 붙고 입력은 받지 않는다. Kit.shimmer()가 붙인다.

## 몇 초마다 한 번 지나가는지
var period := 3.2
## 지나가는 데 걸리는 시간
var travel := 0.7
## 버튼마다 때가 다르게
var offset := 0.0
var _time := 0.0


func _init() -> void:
	name = "Sweep"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 5.0
	offset_top = 5.0
	offset_right = -5.0
	offset_bottom = -11.0


func restart() -> void:
	_time = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if GameData.low_gfx:
		return
	_time += delta
	var phase := fposmod(_time + offset, period)
	if phase <= travel + 0.05:
		queue_redraw()


func _draw() -> void:
	var button := get_parent() as BaseButton
	if button != null and button.disabled:
		return
	var phase := fposmod(_time + offset, period)
	if phase > travel:
		return
	var t := phase / travel
	var band := maxf(size.y * 0.5, 26.0)
	var lean := size.y * 0.6
	var x := lerpf(-band - lean, size.x + lean, t)
	var strength := sin(t * PI) * 0.42
	var points := PackedVector2Array([
		Vector2(x + lean, 0), Vector2(x + lean + band, 0), Vector2(x + band, size.y), Vector2(x, size.y)])
	draw_colored_polygon(points, Color(1, 1, 1, strength))
	var thin := PackedVector2Array([
		Vector2(x + lean + band * 1.25, 0), Vector2(x + lean + band * 1.45, 0),
		Vector2(x + band * 1.45, size.y), Vector2(x + band * 1.25, size.y)])
	draw_colored_polygon(thin, Color(1, 1, 1, strength * 0.6))
