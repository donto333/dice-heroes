extends Control
## 잠시 기다리는 화면: 어두운 바탕, 돌아가는 점, 안내 글자, 아래쪽 도움말 한 줄.
## 게임에 들어갈 때·접속할 때·대전을 준비할 때처럼 화면이 크게 바뀌기 전에 잠깐 보여 준다.
## 떠 있는 동안에는 아래 화면을 누를 수 없다(두 번 눌림 방지).

const Kit := preload("res://scripts/ui/kit.gd")
const GameData := preload("res://scripts/game_data.gd")
const WaitBackdrop := preload("res://scripts/ui/wait_backdrop.gd")

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
	"소환 포인트 한도는 플레이어 레벨이 오르면 5에서 8까지 늘어나요.",
	"50턴이 끝나도 승부가 안 나면 골에 더 가까운 쪽이 이겨요.",
]

var _message: Label
var _tip: Label
## 도움말 그림(assets/art/tips/tip_NN.png, TIPS와 같은 순서). 그림이 있으면 왼쪽 아래에 보이고 도움말 글은 그 오른쪽에 둔다.
var _tip_art: TextureRect
var _rng := RandomNumberGenerator.new()
var _shows := 0
## 바탕 그림과 가운데 돌아가는 금테 주사위 문양(wait_backdrop.gd).
var _backdrop


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_rng.randomize()
	_backdrop = WaitBackdrop.new()
	add_child(_backdrop)
	_message = Kit.label("", 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_message.add_theme_constant_override("outline_size", 8)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.anchor_left = 0.0
	_message.anchor_right = 1.0
	_message.anchor_top = 0.5
	_message.anchor_bottom = 0.5
	_message.offset_top = 92
	_message.offset_bottom = 142
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_message)
	_tip = Kit.para("", 22, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	_tip.anchor_left = 0.08
	_tip.anchor_right = 0.92
	_tip.anchor_top = 0.8
	_tip.anchor_bottom = 0.8
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tip)
	_tip_art = TextureRect.new()
	_tip_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tip_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tip_art.anchor_left = 0.04
	_tip_art.anchor_right = 0.04
	_tip_art.anchor_top = 1.0
	_tip_art.anchor_bottom = 1.0
	_tip_art.offset_right = 250
	_tip_art.offset_top = -240
	_tip_art.offset_bottom = -26
	_tip_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_art.visible = false
	add_child(_tip_art)


## message를 seconds초 동안 보여 주고 사라진다. 끝날 때까지 기다릴 수 있다.
## with_tip이 true면 아래쪽에 게임 도움말 한 줄을 무작위로 보여 준다.
func show_for(message: String, seconds: float, with_tip: bool = false) -> void:
	_shows += 1
	var ticket := _shows
	_message.text = message
	var tip_index := _rng.randi_range(0, TIPS.size() - 1)
	_tip.text = "도움말 · %s" % TIPS[tip_index] if with_tip else ""
	var picture: Texture2D = GameData.tip_art(tip_index + 1) if with_tip else null
	_tip_art.texture = picture
	_tip_art.visible = picture != null
	# 그림이 있으면 도움말 글을 그림 오른쪽 아래로 옮긴다.
	_tip.anchor_left = 0.26 if picture != null else 0.08
	_tip.anchor_top = 0.84 if picture != null else 0.8
	_tip.anchor_bottom = _tip.anchor_top
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if picture != null else HORIZONTAL_ALIGNMENT_CENTER
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	modulate.a = 0.0
	visible = true
	_backdrop.restart()
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
