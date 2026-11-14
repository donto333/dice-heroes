extends Control
## 설정: 효과음, 닉네임 바꾸기, 내 기록, 계정(준비 중), 데이터 초기화, 버전과 만든 이.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const TopBar := preload("res://scripts/ui/top_bar.gd")
const BottomNav := preload("res://scripts/ui/bottom_nav.gd")

var app
var _name_edit: LineEdit
var _coupon_edit: LineEdit
var _code_edit: TextEdit


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

	var play_panel := Kit.panel()
	body.add_child(play_panel)
	var play_column := Kit.vbox(10)
	play_panel.add_child(play_column)
	var fast_row := Kit.hbox(10)
	play_column.add_child(fast_row)
	fast_row.add_child(Kit.expand(Kit.label("대전 빠르기 ×2", 26)))
	var fast_on := bool(app.profile["settings"].get("fast", false))
	var fast_toggle := Kit.button("켜짐" if fast_on else "꺼짐", Kit.GOOD if fast_on else Kit.PANEL_LIGHT, 24, 64)
	fast_toggle.custom_minimum_size = Vector2(150, 64)
	fast_toggle.pressed.connect(_on_fast)
	fast_row.add_child(fast_toggle)
	var buzz_row := Kit.hbox(10)
	play_column.add_child(buzz_row)
	buzz_row.add_child(Kit.expand(Kit.label("내 차례 진동 알림", 26)))
	var buzz_on := bool(app.profile["settings"].get("vibrate", true))
	var buzz_toggle := Kit.button("켜짐" if buzz_on else "꺼짐", Kit.GOOD if buzz_on else Kit.PANEL_LIGHT, 24, 64)
	buzz_toggle.custom_minimum_size = Vector2(150, 64)
	buzz_toggle.pressed.connect(_on_vibrate)
	buzz_row.add_child(buzz_toggle)
	var hint_row := Kit.hbox(10)
	play_column.add_child(hint_row)
	hint_row.add_child(Kit.expand(Kit.para("첫 판 안내 말풍선을 처음부터 다시 볼 수 있어요.", 20)))
	var hint_button := Kit.button("안내 다시 보기", Kit.ACCENT, 20, 64)
	hint_button.custom_minimum_size = Vector2(190, 64)
	hint_button.pressed.connect(_on_hints)
	hint_row.add_child(hint_button)

	var coupon_panel := Kit.panel()
	body.add_child(coupon_panel)
	var coupon_column := Kit.vbox(10)
	coupon_panel.add_child(coupon_column)
	coupon_column.add_child(Kit.label("쿠폰", 26))
	var coupon_row := Kit.hbox(10)
	coupon_column.add_child(coupon_row)
	_coupon_edit = LineEdit.new()
	_coupon_edit.placeholder_text = "쿠폰 코드를 입력하세요"
	_coupon_edit.max_length = 20
	_coupon_edit.custom_minimum_size = Vector2(0, 64)
	_coupon_edit.add_theme_font_size_override("font_size", 24)
	_coupon_edit.add_theme_stylebox_override("normal", Kit.box(Color("0d1026"), Kit.LINE, 2, 10, 12))
	coupon_row.add_child(Kit.expand(_coupon_edit))
	var redeem := Kit.button("받기", Color("e8890c"), 22, 64)
	redeem.custom_minimum_size = Vector2(140, 64)
	redeem.pressed.connect(_on_coupon)
	coupon_row.add_child(redeem)

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
	account_column.add_child(Kit.para("기기를 바꿀 때는 '옮기기 코드'를 복사해 새 기기에서 붙여 넣으면 이어 할 수 있어요.", 18, Kit.MUTED))
	var move_row := Kit.hbox(10)
	account_column.add_child(move_row)
	var export_button := Kit.button("옮기기 코드 만들기", Kit.ACCENT, 20, 64)
	export_button.pressed.connect(_on_export)
	move_row.add_child(Kit.expand(export_button))
	var import_button := Kit.button("코드로 불러오기", Color("2a7d4f"), 20, 64)
	import_button.pressed.connect(_on_import)
	move_row.add_child(Kit.expand(import_button))
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


func _on_fast() -> void:
	app.profile["settings"]["fast"] = not bool(app.profile["settings"].get("fast", false))
	app.save()
	app.play("click")
	app.go("settings")


func _on_vibrate() -> void:
	app.profile["settings"]["vibrate"] = not bool(app.profile["settings"].get("vibrate", true))
	app.save()
	app.play("click")
	if bool(app.profile["settings"]["vibrate"]):
		Input.vibrate_handheld(40)
	app.go("settings")


func _on_hints() -> void:
	app.profile["tutorial"] = {}
	app.save()
	app.play("good")
	app.toast("다음 대전에서 안내가 다시 나와요.")


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


func _on_coupon() -> void:
	var result := Profile.redeem_coupon(app.profile, app.data.get("coupons", {}), _coupon_edit.text)
	if bool(result["ok"]):
		app.save()
		app.play("win")
		app.go("settings")
		app.toast("%s: %s" % [result["text"], Kit.reward_line(result["reward"])])
	elif str(result["reason"]) == "used":
		app.play("bad")
		app.toast("이미 사용한 쿠폰이에요.")
	else:
		app.play("bad")
		app.toast("없는 쿠폰 코드예요.")


## 옮기기 코드를 만들어 보여 주고, 될 수 있으면 복사도 해 둔다.
func _on_export() -> void:
	app.play("click")
	var text: String = app.SaveStore.export_text(app.profile)
	DisplayServer.clipboard_set(text)
	var body := Kit.vbox(10)
	body.add_child(Kit.para("아래 코드를 복사해서 새 기기의 '코드로 불러오기'에 붙여 넣으세요. (방금 복사해 두었어요. 안 되면 길게 눌러 직접 복사하세요.)", 18, Kit.MUTED))
	body.add_child(_code_box(text, false))
	app.dialog("옮기기 코드", body, [["닫기", Kit.PANEL_LIGHT]], 660)


func _on_import() -> void:
	app.play("click")
	var body := Kit.vbox(10)
	body.add_child(Kit.para("다른 기기에서 만든 옮기기 코드를 붙여 넣으세요. 지금 이 기기의 데이터는 그 코드의 데이터로 바뀌어요.", 18, Color("ff9a6a")))
	_code_edit = _code_box("", true)
	body.add_child(_code_edit)
	app.dialog("코드로 불러오기", body, [["불러오기", Color("2a7d4f"), _confirm_import], ["취소", Kit.PANEL_LIGHT]], 660)


func _code_box(text: String, editable: bool) -> TextEdit:
	var box := TextEdit.new()
	box.text = text
	box.editable = editable
	box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.custom_minimum_size = Vector2(0, 260)
	box.add_theme_font_size_override("font_size", 16)
	box.add_theme_stylebox_override("normal", Kit.box(Color("0d1026"), Kit.LINE, 2, 10, 10))
	box.add_theme_stylebox_override("read_only", Kit.box(Color("0d1026"), Kit.LINE, 2, 10, 10))
	return box


func _confirm_import() -> void:
	var text: String = _code_edit.text if _code_edit != null and is_instance_valid(_code_edit) else ""
	if app.import_profile(text):
		app.play("win")
		app.go_loading("lobby", {}, "데이터를 불러오는 중...", 0.9)
		app.toast("데이터를 불러왔어요.")
	else:
		app.play("bad")
		app.toast("코드가 올바르지 않아요.")


func _on_reset() -> void:
	app.message("데이터 초기화", "영웅, 재화, 기록이 모두 지워지고 처음부터 시작해요. 되돌릴 수 없어요.", "정말 지우기", _confirm_reset)


func _confirm_reset() -> void:
	app.reset_profile()
	app.go_loading("title", {}, "처음으로 돌아가는 중...", 0.8)


func _on_tab(screen_name: String) -> void:
	if screen_name == "settings":
		return
	app.play("click")
	app.go(screen_name)
