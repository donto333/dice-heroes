extends Control
## 게임 방법. 목표, 파티, 이동, 전투, 칸 종류(아이콘과 함께), 카드·어빌리티, 성장을 설명한다.
## 로비와 설정에서 들어온다. params.back으로 돌아갈 화면을 정한다.

const Kit := preload("res://scripts/ui/kit.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")

const SECTIONS := [
	["목표", "주사위를 굴려 보드를 달리고, 골(분홍 칸)을 지키는 수호자를 전투로 이기면 승리! 50턴 안에 아무도 못 들어가면 골에 더 가까운 쪽이 이겨요."],
	["맵", "약 120칸짜리 맵 9종이 매 판 무작위로 나와요. 초원의 길(유턴형), 사막의 길(피라미드형, 판정·보물 많음), 설원의 성채(나선형, 습격 많음), 강변의 길(직선형, 전진·행운 많음), 고대 유적(계단형, 보물과 함정), 화산 산맥(산맥형, 키퍼가 강함), 깊은 숲(세로 S자형, 숨은 칸 많음), 하늘 섬(쌍고리형, 판정·전진 많음). 갈림길이 3번 있고, 위쪽 갈래는 위험하지만 보상이, 아래쪽 갈래는 안전한 길이에요. 보드는 내 말을 따라 움직이고, 손가락으로 끌면 둘러볼 수 있어요. 왕국의 성벽(성벽형, 전진·감옥 많음)."],
	["파티", "영웅 3명을 ATTACK(이동·공격), DEFENSE(방어), SUPPORT(지력) 자리에 앉혀요. ★ 합계(소환 포인트)는 플레이어 레벨 1에 5, 레벨 5에 6, 레벨 10에 7, 레벨 20에 8까지. 분류가 맵 속성과 같으면 그 능력에 +2."],
	["주사위 컨트롤", "굴리기 버튼을 꾹 누르면 세기 막대가 움직여요. '낮게'나 '높게'에서 손을 떼면 35% 확률로 성공해서 그쪽 눈이 잘 나와요. 실패하면 보통 굴림과 같아요. 짧게 누르면 그냥 굴려요."],
	["시너지", "파티 세 명이 모두 같은 분류면 '결속'(시작 게이지 +15%), 모두 다른 분류면 '조화'(부적 1개)가 붙어요. 파티를 고를 때 아래에 보여요."],
	["더블", "이동 주사위가 2개인 영웅이 같은 눈 두 개를 굴리면 '더블!' 우리 팀 어빌리티 게이지가 12% 더 차요."],
	["모험 소탕", "별 3개로 깬 모험 스테이지는 '소탕'으로 대전 없이 승리 보상을 받을 수 있어요. 하루 5번까지예요."],
	["따라잡기", "상대보다 10칸 이상 뒤처지면 이동 주사위에서 큰 눈(5·6)이 더 잘 나와요. 차이가 10칸 안으로 줄면 원래대로 돌아가요."],
	["이동", "ATTACK 영웅의 이동 주사위(1~2개)만큼 걸어요. 주사위 1개짜리는 큰 눈이 잘 나오고, 2개짜리는 작은 눈이 잘 나와서 둘 다 쓸 만해요. 갈림길에서는 길을 직접 골라요."],
	["전투", "양쪽이 주사위를 굴려 합이 큰 쪽이 이겨요. 이동해 온 쪽이 공격. 지면 직전 거점으로 돌아가요. 상대 말을 지나칠 때는 싸울지 그냥 지나갈지 고를 수 있어요."],
	["카드와 어빌리티", "아이템 카드는 손에 3장까지, 판 왼쪽에 세워져 있어요. 카드를 누르면 설명이 나오고 '사용'을 누르면 써요(내 차례, 주사위를 굴리기 전에만). 어빌리티는 게이지가 100%가 되면 한 턴에 하나 쓸 수 있어요. SUPPORT의 지력이 높을수록 게이지가 빨리 차고, 넘친 게이지는 모여서 카드가 돼요."],
	["성장", "대전하면 골드와 경험치를 받아요. 상점에서 보석으로 영웅을 소환하고, 같은 영웅이 또 나오면 조각이 돼요. 조각과 골드로 강화하면 레벨 3에서 전투 +1, 레벨 5에서 +2."],
	["랭크", "랭크전에서 이기면 트로피 +30, 지면 -20. 트로피가 쌓이면 티어가 오르고 상대 AI도 강해져요."],
	["모험", "8장, 장마다 3판씩 모두 24판이에요. 장마다 맵과 수호자가 달라요. 이기면 ★1, 24턴 안에 이기면 ★1, 전투에서 한 번도 지지 않으면 ★1. 앞 장을 끝내야 다음 장이 열려요."],
	["AI 연습전", "쉬움·보통·어려움과 맵을 골라요. 어려울수록 상대 영웅 레벨이 높고, 보상은 1배·1.5배·2배예요. 트로피는 변하지 않아요."],
	["매일 할 것", "오늘의 도전(하루 한 번, 이기면 골드 300·보석 30), 출석 보상, 일일 미션 6개(12종 중 매일 바뀜), 행운의 룰렛(하루 한 번 무료, 보석으로 3번 더), 상점의 무료 소환 1회와 오늘의 특가(가진 영웅의 조각을 골드로). 로비 오른쪽의 동그란 버튼으로 바로 갈 수 있어요."],
	["업적", "미션 화면 아래에 있어요. 승리 횟수, 영웅 모으기, 모험 별, 티어 같은 목표를 이루면 한 번씩 큰 보상을 받아요."],
]

## [아이콘, 이름, 설명]
const TILES := [
	["battle", "전투", "키퍼와 싸워요. 이기면 카드."],
	["ambush", "습격", "몬스터가 덤벼요. DEFENSE가 막으면 카드."],
	["battle", "관문", "지나가다가도 반드시 멈춰서 싸워요. 이기면 카드를 받고 그 뒤로는 그냥 지나가요. 지면 거점으로 돌아가지만 관문지기 주사위가 1개 줄어요. 골의 수호자도 질 때마다 1개씩 줄어요(3개까지)."],
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


## 왼쪽 세로 판 항목: [id, 글자, 아이콘, 넣을 SECTIONS 제목들]
const GROUPS := [
	["basic", "기본 규칙", "help", ["목표", "맵", "파티", "이동", "전투"]],
	["dice", "주사위", "dice", ["주사위 컨트롤", "더블", "따라잡기", "시너지"]],
	["play", "카드·성장", "card", ["카드와 어빌리티", "성장", "랭크"]],
	["content", "콘텐츠", "adventure", ["모험", "모험 소탕", "AI 연습전", "매일 할 것", "업적"]],
	["tiles", "칸 종류", "flag", []],
]

var _group := "basic"


func setup(main_app, params: Dictionary) -> void:
	app = main_app
	_back = str(params.get("back", "lobby"))
	_group = str(params.get("group", "basic"))
	# 시안식 틀: 왼쪽 세로 판에 설명 묶음, 오른쪽 큰 금테 판.
	var rail: Array = []
	for group in GROUPS:
		rail.append([group[0], group[1], group[2]])
	if _back != "lobby":
		rail.append(["back", "돌아가기", "exit"])
	var column := MenuArt.frame(self, app, "ui/bg_settings", rail, _group, _on_rail)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := Kit.vbox(12)
	Kit.expand(body)
	scroll.add_child(body)
	if _group == "tiles":
		_add_tiles(body)
		return
	var wanted: Array = []
	for group in GROUPS:
		if group[0] == _group:
			wanted = group[3]
	for section in SECTIONS:
		if not wanted.has(section[0]):
			continue
		var card := Kit.panel()
		var inside := Kit.vbox(6)
		card.add_child(inside)
		inside.add_child(Kit.label(section[0], 30, Kit.GOLD))
		inside.add_child(Kit.para(section[1], 22, Color.WHITE))
		body.add_child(card)


func _add_tiles(body: VBoxContainer) -> void:
	var tiles := Kit.panel()
	var tile_column := Kit.vbox(8)
	tiles.add_child(tile_column)
	tile_column.add_child(Kit.label("칸 종류", 30, Kit.GOLD))
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


func _on_rail(id: String) -> void:
	if id == "back":
		_on_back()
		return
	app.play("click")
	app.go("help", {"back": _back, "group": id})


func _on_back() -> void:
	app.play("click")
	app.go(_back)
