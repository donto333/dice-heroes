extends Control
## 로그인 화면. 지금은 기기 안에 저장하는 게스트 계정으로 시작한다.
## 온라인 계정(구글·애플)은 서버(Nakama)를 붙인 뒤 연다.

const Kit := preload("res://scripts/ui/kit.gd")
const GameData := preload("res://scripts/game_data.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")

var app
var _name_edit: LineEdit
var _start: Button
var _warning: Label


func setup(main_app, _params: Dictionary) -> void:
	app = main_app
	var column := Kit.screen_frame(self, 28, Kit.BG)
	var art := Kit.backdrop(self, "ui/title_keyart", 0.55)
	move_child(art, 1)
	# 가로 화면: 왼쪽에 제목과 영웅 그림, 오른쪽에 닉네임 칸과 시작 버튼. 세로로 쌓으면 버튼이 화면 아래로 밀려난다.
	var row := Kit.hbox(36)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)

	var left := Kit.vbox(14)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.custom_minimum_size = Vector2(540, 0)
	row.add_child(left)
	var logo_art := GameData.logo("title")
	if logo_art != null:
		# 타이틀과 같은 금빛 로고(주사위 엠블럼·월계수·보석).
		var logo := TextureRect.new()
		logo.texture = logo_art
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(500, 237)
		logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left.add_child(logo)
	else:
		left.add_child(Kit.title("주사위 영웅전", 68))
	left.add_child(Kit.para("영웅을 모으고, 주사위를 굴려 골을 향해 달리세요.", 22, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var heroes := Kit.hbox(10)
	heroes.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(heroes)
	for id in ["lubu", "athena", "choichiwon"]:
		var face := Portrait.new()
		face.custom_minimum_size = Vector2(164, 164)
		var info: Dictionary = app.character(id)
		face.show_character(info, Kit.CATEGORY_COLORS.get(info.get("category", ""), Kit.LINE))
		heroes.add_child(face)
	left.add_child(Kit.para("처음 함께할 영웅: 여포 · 아테나 · 최치원 외 9명", 19, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var right := Kit.vbox(0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.custom_minimum_size = Vector2(540, 0)
	row.add_child(right)
	var card := Kit.panel(Kit.PANEL, Kit.LINE, 20)
	right.add_child(card)
	var inside := Kit.vbox(12)
	card.add_child(inside)
	inside.add_child(Kit.para("닉네임을 정해 주세요 (2~10글자)", 24))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "예: 주사위왕"
	_name_edit.max_length = 10
	_name_edit.custom_minimum_size = Vector2(0, 68)
	_name_edit.add_theme_font_size_override("font_size", 28)
	_name_edit.add_theme_stylebox_override("normal", Kit.box(Color("0f3d85"), Kit.LINE, 2, 12, 16))
	_name_edit.add_theme_stylebox_override("focus", Kit.box(Color("0f3d85"), Kit.GOLD, 2, 12, 16))
	_name_edit.text_changed.connect(_on_text_changed)
	_name_edit.text_submitted.connect(func(_text): _on_start_pressed())
	inside.add_child(_name_edit)
	_warning = Kit.label("", 18, Kit.BAD)
	inside.add_child(_warning)
	_start = Kit.button("게스트로 시작하기", Kit.ACCENT, 30, 88)
	_start.pressed.connect(_on_start_pressed)
	inside.add_child(_start)
	var online := Kit.button("구글 · 애플 계정으로 시작 (준비 중)", Kit.PANEL_LIGHT, 20, 60)
	online.disabled = true
	inside.add_child(online)
	inside.add_child(Kit.para("게스트 기록은 이 기기에 저장됩니다. 온라인 서버가 열리면 계정에 옮길 수 있습니다.", 17, Kit.MUTED))
	_on_text_changed("")


func _on_text_changed(text: String) -> void:
	var ok := Profile.nickname_ok(text)
	_start.disabled = not ok
	_warning.text = "" if ok or text == "" else "닉네임은 2글자 이상이어야 해요."


func _on_start_pressed() -> void:
	if not Profile.nickname_ok(_name_edit.text):
		return
	app.play("good")
	app.create_profile(_name_edit.text)
	app.go_loading("lobby", {"welcome": true}, "접속 중...", 1.0, true)
