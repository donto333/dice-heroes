extends Control
## 설정: 효과음, 닉네임 바꾸기, 내 기록, 계정(준비 중), 데이터 초기화, 버전과 만든 이.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const TopBar := preload("res://scripts/ui/top_bar.gd")
const BottomNav := preload("res://scripts/ui/bottom_nav.gd")

var app
var _name_edit: LineEdit


func setup(main_app, _params: Dictionary) -> void:
	app = main_app
	var column := Kit.screen_frame(self, 16)
	var top := TopBar.new()
	column.add_child(top)
	top.setup(app)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := Kit.vbox(14)
	Kit.expand(body)
	scroll.add_child(body)

	var sound := Kit.panel()
	body.add_child(sound)
	var sound_row := Kit.hbox(10)
	sound.add_child(sound_row)
	sound_row.add_child(Kit.expand(Kit.label("효과음", 26)))
	var on: bool = app.sfx_on()
	var toggle := Kit.button("켜짐" if on else "꺼짐", Kit.GOOD if on else Kit.PANEL_LIGHT, 24, 64)
	toggle.custom_minimum_size = Vector2(150, 64)
	toggle.pressed.connect(_on_sound)
	sound_row.add_child(toggle)
	var music_panel := Kit.panel()
	body.add_child(music_panel)
	var music_row := Kit.hbox(10)
	music_panel.add_child(music_row)
	music_row.add_child(Kit.expand(Kit.label("배경음악", 26)))
	var music_on: bool = app.bgm_on()
	var music_toggle := Kit.button("켜짐" if music_on else "꺼짐", Kit.GOOD if music_on else Kit.PANEL_LIGHT, 24, 64)
	music_toggle.custom_minimum_size = Vector2(150, 64)
	music_toggle.pressed.connect(_on_music)
	music_row.add_child(music_toggle)

	var name_panel := Kit.panel()
	body.add_child(name_panel)
	var name_column := Kit.vbox(10)
	name_panel.add_child(name_column)
	name_column.add_child(Kit.label("닉네임", 26))
	var name_row := Kit.hbox(10)
	name_column.add_child(name_row)
	_name_edit = LineEdit.new()
	_name_edit.text = str(app.profile["nickname"])
	_name_edit.max_length = 10
	_name_edit.custom_minimum_size = Vector2(0, 64)
	_name_edit.add_theme_font_size_override("font_size", 26)
	_name_edit.add_theme_stylebox_override("normal", Kit.box(Color("0d1026"), Kit.LINE, 2, 10, 12))
	name_row.add_child(Kit.expand(_name_edit))
	var rename := Kit.button("바꾸기", Kit.ACCENT, 22, 64)
	rename.custom_minimum_size = Vector2(140, 64)
	rename.pressed.connect(_on_rename)
	name_row.add_child(rename)

	var record := Kit.panel()
	body.add_child(record)
	var record_column := Kit.vbox(6)
	record.add_child(record_column)
	record_column.add_child(Kit.label("내 기록", 26))
	var stats: Dictionary = app.profile["stats"]
	var played := int(stats["played"])
	var rate := 0 if played == 0 else int(round(100.0 * float(stats["wins"]) / float(played)))
	record_column.add_child(Kit.para("대전 %d판  ·  %d승 %d패 %d무  ·  승률 %d%%" % [played, int(stats["wins"]), int(stats["losses"]), int(stats["draws"]), rate], 20))
	record_column.add_child(Kit.para("랭크전 승리 %d  ·  최고 트로피 %d (%s)" % [int(stats["rank_wins"]), int(app.profile["best_trophies"]), Profile.tier_of(app.eco, int(app.profile["best_trophies"]))["name"]], 20))
	record_column.add_child(Kit.para("영웅 %d / %d명 보유  ·  플레이어 레벨 %d" % [app.profile["owned"].size(), app.data["characters"].size(), int(app.profile["level"])], 20))

	var account := Kit.panel()
	body.add_child(account)
	var account_column := Kit.vbox(8)
	account.add_child(account_column)
	account_column.add_child(Kit.label("계정", 26))
	account_column.add_child(Kit.para("지금은 이 기기에 저장되는 게스트 계정이에요. 온라인 서버가 열리면 구글·애플 계정에 연결해 다른 기기에서도 이어 할 수 있어요.", 18, Kit.MUTED))
	var link := Kit.button("계정 연결 (준비 중)", Kit.PANEL_LIGHT, 22, 64)
	link.disabled = true
	account_column.add_child(link)
	var reset := Kit.button("데이터 초기화", Kit.BAD, 22, 64)
	reset.pressed.connect(_on_reset)
	account_column.add_child(reset)

	var about := Kit.panel()
	body.add_child(about)
	var about_column := Kit.vbox(6)
	about.add_child(about_column)
	about_column.add_child(Kit.label("주사위 영웅전  버전 %s" % app.VERSION, 22))
	about_column.add_child(Kit.para("글꼴: Noto Sans KR (SIL Open Font License)\n엔진: Godot Engine (MIT)\n영웅 그림: AI 도구로 만든 창작 일러스트", 17, Kit.MUTED))
	var help := Kit.button("게임 방법", Color("6f43a6"), 22, 64)
	help.pressed.connect(_on_help)
	about_column.add_child(help)
	var to_title := Kit.button("타이틀로", Kit.PANEL_LIGHT, 22, 64)
	to_title.pressed.connect(func(): app.go("title"))
	about_column.add_child(to_title)

	var nav := BottomNav.new()
	column.add_child(nav)
	nav.setup("settings", app.badges())
	nav.tab_pressed.connect(_on_tab)


func _on_help() -> void:
	app.play("click")
	app.go("help", {"back": "settings"})


func _on_music() -> void:
	app.profile["settings"]["bgm"] = not app.bgm_on()
	app.music.set_enabled(app.bgm_on())
	app.save()
	app.play("click")
	app.go("settings")


func _on_sound() -> void:
	app.profile["settings"]["sfx"] = not app.sfx_on()
	app.save()
	app.play("click")
	app.go("settings")


func _on_rename() -> void:
	if not Profile.nickname_ok(_name_edit.text):
		app.toast("닉네임은 2글자 이상이어야 해요.")
		return
	app.profile["nickname"] = Profile.clean_nickname(_name_edit.text)
	app.save()
	app.play("good")
	app.toast("닉네임을 바꿨어요.")
	app.go("settings")


func _on_reset() -> void:
	app.message("데이터 초기화", "영웅, 재화, 기록이 모두 지워지고 처음부터 시작해요. 되돌릴 수 없어요.", "정말 지우기", _confirm_reset)


func _confirm_reset() -> void:
	app.reset_profile()
	app.go("title")


func _on_tab(screen_name: String) -> void:
	if screen_name == "settings":
		return
	app.play("click")
	app.go(screen_name)
