extends Control
## 잠시 기다리는 화면: 어두운 바탕, 돌아가는 점, 안내 글자, 아래쪽 도움말 한 줄.
## 게임에 들어갈 때·접속할 때·대전을 준비할 때처럼 화면이 크게 바뀌기 전에 잠깐 보여 준다.
## 떠 있는 동안에는 아래 화면을 누를 수 없다(두 번 눌림 방지).

const Kit := preload("res://scripts/ui/kit.gd")
const GameData := preload("res://scripts/game_data.gd")

const TIPS := [
	"주사위 1개짜리 영웅은 큰 눈이, 2개짜리 영웅은 작은 눈이 잘 나와요.",
	"맵 속성과 영웅의 분류가 같으면 전투와 이동에 +2를 받아요.",
	"전투에서 지면 직전 거점(파란 깃발)으로 돌아가요.",
	"아이템 카드는 주사위를 굴리기 전에 써야 해요.",
	"어빌리티 게이지는 SUPPORT 영웅의 지력이 높을수록 빨리 차요.",
	"상대보다 10칸 이상 뒤처지면 이동 주사위에서 큰 눈이 더 잘 나와요.",
	"갈림길의 위쪽 길은 짧지만 위험하고, 아래쪽 길은 안전해요.",
	"같은 영웅을 또 뽑으면 강화에 쓰는 조각이 돼요.",
	"행운의 룰렛과 오늘의 도전은 하루에 한 번씩 꼭 챙기세요.",
	"대전이 느리게 느껴지면 위쪽의 '빠르기 ×2'를 눌러 보세요.",
	"파티는 소환 포인트 합계 6 이하로 짜야 해요.",
	"50턴이 끝나도 승부가 안 나면 골에 더 가까운 쪽이 이겨요.",
]

var _message: Label
var _tip: Label
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _shows := 0
## 바탕 그림(assets/art/ui/loading_bg.jpg). 없으면 파란 바탕만.
var _background: Texture2D = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_rng.randomize()
	_background = GameData.art("ui/loading_bg")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_message = Kit.label("", 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_message.add_theme_constant_override("outline_size", 8)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.anchor_left = 0.0
	_message.anchor_right = 1.0
	_message.anchor_top = 0.5
	_message.anchor_bottom = 0.5
	_message.offset_top = 70
	_message.offset_bottom = 120
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_message)
	_tip = Kit.para("", 22, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	_tip.anchor_left = 0.08
	_tip.anchor_right = 0.92
	_tip.anchor_top = 0.8
	_tip.anchor_bottom = 0.8
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tip)


## message를 seconds초 동안 보여 주고 사라진다. 끝날 때까지 기다릴 수 있다.
## with_tip이 true면 아래쪽에 게임 도움말 한 줄을 무작위로 보여 준다.
func show_for(message: String, seconds: float, with_tip: bool = false) -> void:
	_shows += 1
	var ticket := _shows
	_message.text = message
	_tip.text = "도움말 · %s" % TIPS[_rng.randi_range(0, TIPS.size() - 1)] if with_tip else ""
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	modulate.a = 0.0
	visible = true
	var fade_in := create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, 0.12)
	await get_tree().create_timer(max(seconds, 0.05)).timeout
	# 그 사이에 다른 안내가 새로 떴으면 그쪽이 끝낼 때까지 둔다.
	if ticket != _shows or not is_inside_tree():
		return
	var fade_out := create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, 0.14)
	await fade_out.finished
	if ticket == _shows:
		visible = false


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


func _draw() -> void:
	if _background != null:
		# 바탕 그림을 꽉 차게, 아주 천천히 확대하며 그리고 위에 살짝 어둡게 덮는다.
		var texture_size := _background.get_size()
		var ratio := size.x / max(size.y, 1.0)
		var source := Rect2(Vector2.ZERO, texture_size)
		if ratio < texture_size.x / texture_size.y:
			source.size.x = texture_size.y * ratio
			source.position.x = (texture_size.x - source.size.x) / 2.0
		else:
			source.size.y = texture_size.x / ratio
			source.position.y = (texture_size.y - source.size.y) / 2.0
		var zoom := 1.0 + minf(_time, 3.0) * 0.015
		var shrink := source.size / zoom
		source = Rect2(source.position + (source.size - shrink) / 2.0, shrink)
		draw_texture_rect_region(_background, Rect2(Vector2.ZERO, size), source)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.12, 0.3, 0.45))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.32, 0.72, 0.97))
	# 돌아가는 점 8개: 앞선 점일수록 크고 밝다.
	var center := Vector2(size.x * 0.5, size.y * 0.5 - 10.0)
	var head := int(_time * 10.0) % 8
	for index in 8:
		var age := (head - index + 8) % 8
		var strength := 1.0 - age / 8.0
		var angle := TAU * index / 8.0 - PI / 2.0
		var color := Color(1.0, 0.81, 0.3, 0.25 + 0.75 * strength)
		draw_circle(center + Vector2(cos(angle), sin(angle)) * 46.0, 6.0 + 7.0 * strength, color)
