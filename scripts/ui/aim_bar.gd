extends Control
## 주사위 컨트롤 세기 막대. 굴리기 버튼을 누르고 있는 동안 표시가 좌우로 오가고,
## 놓는 순간의 자리가 '낮게 / 보통 / 높게' 중 어디인지 알려 준다.
## 보여 주기와 고르기만 한다. 실제 주사위는 규칙 코드가 굴린다.

const SWEEP_TIME := 0.9
const LOW_END := 0.34
const HIGH_START := 0.66

var value := 0.0
var _time := 0.0
var _running := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(230, 64)
	visible = false


## 막대가 차오르기 시작할 때 알린다(소리를 내는 데 쓴다).
signal started

func start() -> void:
	started.emit()
	_time = 0.0
	value = 0.0
	_running = true
	visible = true
	queue_redraw()


## 멈추고 지금 자리의 노림("low", "", "high")을 돌려준다.
func stop() -> String:
	_running = false
	visible = false
	return aim_of(value)


static func aim_of(at: float) -> String:
	if at < LOW_END:
		return "low"
	if at > HIGH_START:
		return "high"
	return ""


func _process(delta: float) -> void:
	if not _running:
		return
	_time += delta
	# 0 → 1 → 0 으로 오간다.
	var phase := fmod(_time / SWEEP_TIME, 2.0)
	value = phase if phase <= 1.0 else 2.0 - phase
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var bar := Rect2(0, 26, size.x, 26)
	var zones := [[0.0, LOW_END, Color("3a8fd0"), "낮게"], [LOW_END, HIGH_START, Color("7a8098"), "보통"], [HIGH_START, 1.0, Color("e0502b"), "높게"]]
	draw_rect(bar.grow(4.0), Color(0, 0, 0, 0.7))
	for zone in zones:
		var rect := Rect2(bar.position.x + bar.size.x * zone[0], bar.position.y, bar.size.x * (zone[1] - zone[0]), bar.size.y)
		var active: bool = aim_of(value) == aim_of((zone[0] + zone[1]) * 0.5)
		var color: Color = zone[2]
		draw_rect(rect, color if active else color.darkened(0.45))
		draw_string_outline(font, Vector2(rect.position.x, 20), zone[3], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, 5, Color.BLACK)
		draw_string(font, Vector2(rect.position.x, 20), zone[3], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, Color.WHITE if active else Color(1, 1, 1, 0.6))
	var x := bar.position.x + bar.size.x * value
	draw_rect(Rect2(x - 4.0, bar.position.y - 5.0, 8.0, bar.size.y + 10.0), Color.WHITE)
	draw_rect(Rect2(x - 2.0, bar.position.y - 3.0, 4.0, bar.size.y + 6.0), Color("ffcf4d"))
