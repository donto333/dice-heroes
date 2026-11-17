extends Control
## 설정: 효과음, 닉네임 바꾸기, 내 기록, 계정(준비 중), 데이터 초기화, 버전과 만든 이.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const TopBar := preload("res://scripts/ui/top_bar.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const BottomNav := preload("res://scripts/ui/bottom_nav.gd")

var app
var _name_edit: LineEdit
var _coupon_edit: LineEdit
var _code_edit: TextEdit


func setup(main_app, _params: Dictionary) -> void:
	app = main_app
	# 시안식 틀: 왼쪽 세로 판에 설정 항목, 오른쪽 큰 금테 판.
	var rail := [["settings", "게임 설정", "settings"], ["help", "게임 방법", "help"], ["title", "타이틀로", "exit"]]
	var column := MenuArt.frame(self, app, "ui/bg_settings", rail, "settings", _on_rail)
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
	sound_row.add_child(Kit.icon("sound", 44.0))
	sound_row.add_child(Kit.expand(Kit.label("효과음", 26)))
	var on: bool = app.sfx_on()
	var toggle := Kit.button("켜짐" if on else "꺼짐", Kit.GOOD if on else Kit.PANEL_LIGHT, 24, 64)
	toggle.custom_minimum_size = Vector2(150, 64)
	toggle.pressed.connect(_on_sound)
	sound_row.add_child(toggle)
	var voice_panel := Kit.panel()
	body.add_child(voice_panel)
	var voice_row := Kit.hbox(10)
	voice_panel.add_child(voice_row)
	voice_row.add_child(Kit.icon("heroes", 44.0))
	voice_row.add_child(Kit.expand(Kit.label("영웅 음성", 26)))
	var voice_on: bool = app.voice_on()
	var voice_toggle := Kit.button("켜짐" if voice_on else "꺼짐", Kit.GOOD if voice_on else Kit.PANEL_LIGHT, 24, 64)
	voice_toggle.custom_minimum_size = Vector2(150, 64)
	voice_toggle.pressed.connect(_on_voice)
	voice_row.add_child(voice_toggle)
	# 안내 음성 고르기: 누를 때마다 다음 목소리로 바뀌고 바로 들려준다.
	var announcer_panel := Kit.panel()
	body.add_child(announcer_panel)
	var announcer_row := Kit.hbox(10)
	announcer_panel.add_child(announcer_row)
	announcer_row.add_child(Kit.icon("chat", 44.0))
	announcer_row.add_child(Kit.expand(Kit.label("안내 음성", 26)))
	var announcer_label := "없음"
	for entry in app.announcers():
		if str(entry.get("id", "")) == app.announcer_id():
			announcer_label = str(entry.get("label", ""))
	var announcer_button := Kit.button(announcer_label, Kit.ACCENT, 22, 64)
	announcer_button.custom_minimum_size = Vector2(310, 64)
	announcer_button.pressed.connect(_on_announcer)
	announcer_row.add_child(announcer_button)
	var music_panel := Kit.panel()
	body.add_child(music_panel)
	var music_row := Kit.hbox(10)
	music_panel.add_child(music_row)
	music_row.add_child(Kit.icon("music", 44.0))
	music_row.add_child(Kit.expand(Kit.label("배경음악", 26)))
	var music_on: bool = app.bgm_on()
	var music_toggle := Kit.button("켜짐" if music_on else "꺼짐", Kit.GOOD if music_on else Kit.PANEL_LIGHT, 24, 64)
	music_toggle.custom_minimum_size = Vector2(150, 64)
	music_toggle.pressed.connect(_on_music)
	music_row.add_child(music_toggle)

	# 소리 크기: 효과음·영웅 음성·배경음악을 20%씩 조절
	var volume_panel := Kit.panel()
	body.add_child(volume_panel)
	var volume_column := Kit.vbox(8)
	volume_panel.add_child(volume_column)
	for spec in [["sfx", "효과음 크기"], ["voice", "음성 크기"], ["bgm", "음악 크기"]]:
		var volume_row := Kit.hbox(10)
		volume_column.add_child(volume_row)
		volume_row.add_child(Kit.icon({"sfx": "sound", "voice": "chat", "bgm": "music"}.get(str(spec[0]), "sound"), 40.0))
		volume_row.add_child(Kit.expand(Kit.label("%s  %d%%" % [spec[1], app.volume(str(spec[0]))], 24)))
		var down := Kit.button("작게", Kit.PANEL_LIGHT, 22, 56)
		down.custom_minimum_size = Vector2(110, 56)
		down.pressed.connect(_on_volume.bind(str(spec[0]), -20))
		volume_row.add_child(down)
		var up := Kit.button("크게", Kit.ACCENT, 22, 56)
		up.custom_minimum_size = Vector2(110, 56)
		up.pressed.connect(_on_volume.bind(str(spec[0]), 20))
		volume_row.add_child(up)
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
	var full_row := Kit.hbox(10)
	play_column.add_child(full_row)
	full_row.add_child(Kit.expand(Kit.label("전체 화면", 26)))
	var full_on: bool = app.fullscreen_on()
	var full_toggle := Kit.button("켜짐" if full_on else "꺼짐", Kit.GOOD if full_on else Kit.PANEL_LIGHT, 24, 64)
	full_toggle.custom_minimum_size = Vector2(150, 64)
	full_toggle.pressed.connect(_on_fullscreen)
	full_row.add_child(full_toggle)
	var low_row := Kit.hbox(10)
	play_column.add_child(low_row)
	var low_text := Kit.vbox(0)
	low_row.add_child(Kit.expand(low_text))
	low_text.add_child(Kit.label("저사양 모드", 26))
	low_text.add_child(Kit.para("그래픽카드가 약한 PC·휴대폰에서 그림자·꾸밈 모형·빛 효과를 줄여 가볍게 해요.", 18))
	var low_on: bool = app.low_gfx_on()
	var low_toggle := Kit.button("켜짐" if low_on else "꺼짐", Kit.GOOD if low_on else Kit.PANEL_LIGHT, 24, 64)
	low_toggle.custom_minimum_size = Vector2(150, 64)
	low_toggle.pressed.connect(_on_low_gfx)
	low_row.add_child(low_toggle)
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
	_coupon_edit.add_theme_stylebox_override("normal", Kit.box(Color("0f3d85"), Kit.LINE, 2, 10, 12))
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
	_name_edit.add_theme_stylebox_override("normal", Kit.box(Color("0f3d85"), Kit.LINE, 2, 10, 12))
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
	var import_button := Kit.button("코드로 불러오기", Color("27a35a"), 20, 64)
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
	about_column.add_child(Kit.para("글꼴: Noto Sans KR (SIL Open Font License)\n엔진: Godot Engine (MIT)\n영웅·화면 그림: AI 도구로 만든 창작 일러스트", 17, Kit.MUTED))
	var news := Kit.button("새 소식 다시 보기", Color("19a8c9"), 22, 64)
	news.pressed.connect(_on_news)
	about_column.add_child(news)
	var opening := Kit.button("오프닝 다시 보기", Color("e0532b"), 22, 64)
	opening.pressed.connect(func(): app.play_opening())
	about_column.add_child(opening)
	var help := Kit.button("게임 방법", Color("6f43a6"), 22, 64)
	help.pressed.connect(_on_help)
	about_column.add_child(help)
	var to_title := Kit.button("타이틀로", Kit.PANEL_LIGHT, 22, 64)
	to_title.pressed.connect(func(): app.go("title"))
	about_column.add_child(to_title)



## 로비로 가서 새 소식 창을 다시 띄운다.
func _on_news() -> void:
	app.profile["seen_version"] = ""
	app.save()
	app.go("lobby")


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


func _on_low_gfx() -> void:
	app.set_low_gfx(not app.low_gfx_on())
	app.play("click")
	app.go("settings")


func _on_fullscreen() -> void:
	app.set_fullscreen(not app.fullscreen_on())
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


func _on_volume(kind: String, step: int) -> void:
	app.profile["settings"][kind + "_volume"] = clampi(app.volume(kind) + step, 0, 100)
	app.save()
	app.apply_volumes()
	app.go("settings")
	# 바뀐 크기를 바로 들려준다.
	if kind == "voice":
		app.say(str(app.profile.get("party", {}).get("attack", "")), "select")
	elif kind == "sfx":
		app.play("good")


func _on_announcer() -> void:
	var list: Array = app.announcers()
	if list.is_empty():
		return
	var index := 0
	for i in list.size():
		if str(list[i].get("id", "")) == app.announcer_id():
			index = i
	app.profile["settings"]["announcer"] = str(list[(index + 1) % list.size()].get("id", ""))
	app.save()
	app.go("settings")
	app.say("announcer", "start")


func _on_voice() -> void:
	app.profile["settings"]["voice"] = not app.voice_on()
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
	app.dialog("코드로 불러오기", body, [["불러오기", Color("27a35a"), _confirm_import], ["취소", Kit.PANEL_LIGHT]], 660)


func _code_box(text: String, editable: bool) -> TextEdit:
	var box := TextEdit.new()
	box.text = text
	box.editable = editable
	box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.custom_minimum_size = Vector2(0, 260)
	box.add_theme_font_size_override("font_size", 16)
	box.add_theme_stylebox_override("normal", Kit.box(Color("0f3d85"), Kit.LINE, 2, 10, 10))
	box.add_theme_stylebox_override("read_only", Kit.box(Color("0f3d85"), Kit.LINE, 2, 10, 10))
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


func _on_rail(id: String) -> void:
	match id:
		"help":
			_on_help()
		"title":
			app.play("click")
			app.go("title")


func _on_tab(screen_name: String) -> void:
	if screen_name == "settings":
		return
	app.play("click")
	app.go(screen_name)
