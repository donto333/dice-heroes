extends Control
## 게임 방법. 목표, 파티, 이동, 전투, 칸 종류(아이콘과 함께), 카드·어빌리티, 성장을 설명한다.
## 로비와 설정에서 들어온다. params.back으로 돌아갈 화면을 정한다.

const Kit := preload("res://scripts/ui/kit.gd")

const SECTIONS := [
	["목표", "주사위를 굴려 보드를 달리고, 골(분홍 칸)을 지키는 수호자를 전투로 이기면 승리! 20턴 안에 아무도 못 들어가면 골에 더 가까운 쪽이 이겨요."],
	["맵", "초원의 길, 사막의 길(판정·보물이 많음), 설원의 성채(습격이 많아 방어가 중요) 중 하나가 매 판 무작위로 나와요."],
	["파티", "영웅 3명을 ATTACK(이동·공격), DEFENSE(방어), SUPPORT(지력) 자리에 앉혀요. ★ 합계(소환 포인트)는 6까지. 분류가 맵 속성과 같으면 그 능력에 +2."],
	["이동", "ATTACK 영웅의 이동 주사위(1~2개)만큼 걸어요. 주사위 1개짜리는 큰 눈이 잘 나오고, 2개짜리는 작은 눈이 잘 나와서 둘 다 쓸 만해요. 갈림길에서는 길을 직접 골라요."],
	["전투", "양쪽이 주사위를 굴려 합이 큰 쪽이 이겨요. 이동해 온 쪽이 공격. 지면 직전 거점으로 돌아가요. 상대 말을 지나칠 때는 싸울지 그냥 지나갈지 고를 수 있어요."],
	["카드와 어빌리티", "아이템 카드는 손에 3장까지. 어빌리티는 게이지가 100%가 되면 한 턴에 하나 쓸 수 있어요. SUPPORT의 지력이 높을수록 게이지가 빨리 차고, 넘친 게이지는 모여서 카드가 돼요."],
	["성장", "대전하면 골드와 경험치를 받아요. 상점에서 보석으로 영웅을 소환하고, 같은 영웅이 또 나오면 조각이 돼요. 조각과 골드로 강화하면 레벨 3에서 전투 +1, 레벨 5에서 +2."],
	["랭크", "랭크전에서 이기면 트로피 +30, 지면 -20. 트로피가 쌓이면 티어가 오르고 상대 AI도 강해져요."],
]

## [아이콘, 이름, 설명]
const TILES := [
	["battle", "전투", "키퍼와 싸워요. 이기면 카드."],
	["ambush", "습격", "몬스터가 덤벼요. DEFENSE가 막으면 카드."],
	["treasure", "보물", "아이템 카드를 받아요."],
	["luck", "행운", "게이지 +25%."],
	["forward", "전진", "몇 칸 더 나아가요."],
	["warp", "워프", "다른 칸으로 순간 이동."],
	["curse", "저주", "다음 전투 주사위 -1개."],
	["prison", "감옥", "다음 턴을 쉬어요."],
	["fate", "판정", "주사위 2개의 차이만큼 뒤로. 3 이상이면 거점으로."],
	["checkpoint", "거점", "지면 돌아오는 곳."],
	["fork", "갈림길", "길을 골라요."],
	["hidden", "숨은 칸", "밟기 전까지 무엇인지 몰라요."],
	["attr_hero", "속성", "맵 속성이 바뀌어요."],
	["goal", "골", "수호자를 이기면 승리!"],
]

var app
var _back := "lobby"


func setup(main_app, params: Dictionary) -> void:
	app = main_app
	_back = str(params.get("back", "lobby"))
	var column := Kit.screen_frame(self, 18)
	column.add_child(Kit.title("게임 방법", 48))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := Kit.vbox(12)
	Kit.expand(body)
	scroll.add_child(body)
	for section in SECTIONS:
		var card := Kit.panel()
		var inside := Kit.vbox(6)
		card.add_child(inside)
		inside.add_child(Kit.label(section[0], 28, Kit.GOLD))
		inside.add_child(Kit.para(section[1], 21, Color.WHITE))
		body.add_child(card)
	var tiles := Kit.panel()
	var tile_column := Kit.vbox(8)
	tiles.add_child(tile_column)
	tile_column.add_child(Kit.label("칸 종류", 28, Kit.GOLD))
	for spec in TILES:
		var row := Kit.hbox(12)
		var icon := TextureRect.new()
		icon.texture = load("res://assets/icons/%s.png" % spec[0])
		icon.custom_minimum_size = Vector2(54, 54)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var name_label := Kit.label(spec[1], 22, Color.WHITE)
		name_label.custom_minimum_size = Vector2(110, 0)
		row.add_child(name_label)
		row.add_child(Kit.expand(Kit.para(spec[2], 20, Kit.MUTED)))
		tile_column.add_child(row)
	body.add_child(tiles)
	var back := Kit.button("돌아가기", Kit.ACCENT, 28, 88)
	back.pressed.connect(_on_back)
	column.add_child(back)


func _on_back() -> void:
	app.play("click")
	app.go(_back)
