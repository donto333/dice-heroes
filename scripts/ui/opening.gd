extends Control
## 오프닝 영상. 일러스트 여러 장을 천천히 확대·이동하며 넘기고, 장면마다 이야기 한 줄을 띄운다.
## 처음 게임을 켠 사람에게 한 번 보여 주고, 설정의 '오프닝 다시 보기'로 다시 볼 수 있다.
## 화면을 누르면 다음 장면, '건너뛰기'를 누르면 바로 끝난다. 끝나면 finished 신호.

signal finished

const Kit := preload("res://scripts/ui/kit.gd")
const ArtView := preload("res://scripts/ui/art_view.gd")

## [그림 경로, 이야기]. 그림이 없는 장면은 건너뛴다.
const SCENES := [
	["ui/title_keyart", "아주 먼 옛날, 역사와 신화의 영웅들이\n한 권의 보드판 속에 잠들었다."],
	["chapters/c1", "평화롭던 초원에 도적이 들끓고"],
	["chapters/c2", "모래바람 너머에서는 스핑크스가 길을 막았다."],
	["chapters/c3", "얼어붙은 성채와"],
	["chapters/c6", "불타는 산맥을 넘어"],
	["chapters/c8", "구름 위 하늘 섬에는 천둥새가 기다린다."],
	["ui/summon", "주사위를 굴려 영웅을 깨워라."],
	["chapters/c9", "그리고 왕국의 성벽 끝, 골에 먼저 닿는 자가\n전설이 된다."],
]
const SCENE_TIME := 3.6
const FADE_TIME := 0.7

var _scenes: Array = []
var _index := -1
var _views: Array = []
var _caption: Label
var _timer := 0.0
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	# 장면을 겹쳐 놓고 투명도로 서로 바꾼다.
	for scene in SCENES:
		var view := ArtView.new()
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.show_art(str(scene[0]))
		if not view.has_art():
			view.free()
			continue
		view.drift = true
		view.drift_speed = 2.2
		view.focus_y = 0.4
		view.fade_bottom = 0.4
		view.modulate.a = 0.0
		add_child(view)
		_views.append(view)
		_scenes.append(scene)

	_caption = Kit.label("", 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_constant_override("outline_size", 10)
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_caption.anchor_left = 0.06
	_caption.anchor_right = 0.94
	_caption.anchor_top = 0.74
	_caption.anchor_bottom = 0.9
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)

	var skip := Kit.button("건너뛰기 >", Color(0, 0, 0, 0.45), 22, 60)
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -200
	skip.offset_right = -20
	skip.offset_top = 30
	skip.offset_bottom = 90
	skip.pressed.connect(_finish)
	add_child(skip)

	if _scenes.is_empty():
		# 그림이 하나도 없으면 보여 줄 것이 없다.
		_finish.call_deferred()
		return
	_next()


func _process(delta: float) -> void:
	if _done:
		return
	_timer += delta
	if _timer >= SCENE_TIME:
		_next()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		_next()


## 다음 장면으로. 마지막 장면 뒤면 끝낸다.
func _next() -> void:
	if _done:
		return
	_timer = 0.0
	var previous := _index
	_index += 1
	if _index >= _views.size():
		_finish()
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_views[_index], "modulate:a", 1.0, FADE_TIME)
	if previous >= 0:
		tween.tween_property(_views[previous], "modulate:a", 0.0, FADE_TIME)
	_caption.text = str(_scenes[_index][1])
	_caption.modulate.a = 0.0
	var words := create_tween()
	words.tween_interval(FADE_TIME * 0.5)
	words.tween_property(_caption, "modulate:a", 1.0, 0.6)


func _finish() -> void:
	if _done:
		return
	_done = true
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.5)
	await fade.finished
	finished.emit()
	queue_free()
