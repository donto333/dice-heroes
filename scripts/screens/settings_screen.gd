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
	var summary := MenuArt.summary("book", "버전 %s" % app.VERSION, str(app.profile.get("nickname", "")))
	var column := MenuArt.frame(self, app, "ui/bg_settings", rail, "settings", _on_rail, summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := Kit.vbox(8)
	Kit.expand(body)
	scroll.add_child(body)

	# ---- 언어: 누를 때마다 한국어 → English → Tiếng Việt 차례로 바뀐다(lang.gd).
	var lang_button := MenuArt.pill_button(Lang.language_name(), "green", "m")
	lang_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lang_button.custom_minimum_size = Vector2(240, 56)
	lang_button.pressed.connect(_on_language)
	MenuArt.list_row(body, "m_monitor", "언어 (Language)", "한국어 · English · Tiếng Việt", lang_button)
	# ---- 소리
	body.add_child(MenuArt.section("소리", "m_speaker", "효과음·음성·음악"))
	_toggle_row(body, "m_speaker", "효과음", app.sfx_on(), _on_sound)
	_toggle_row(body, "m_mic", "영웅 음성", app.voice_on(), _on_voice)
	var announcer_label := "없음"
	for entry in app.announcers():
		if str(entry.get("id", "")) == app.announcer_id():
			announcer_label = str(entry.get("label", ""))
	var announcer_button := MenuArt.pill_button(announcer_label, "purple", "m")
	announcer_button.custom_minimum_size = Vector2(300, 56)
	announcer_button.pressed.connect(_on_announcer)
	MenuArt.list_row(body, "m_megaphone", "안내 음성", "누를 때마다 다음 목소리", announcer_button)
	_toggle_row(body, "m_note", "배경음악", app.bgm_on(), _on_music)
	# 소리 크기: 작게·크게 사이에 5칸 눈금 막대
	for spec in [["sfx", "효과음 크기", "m_speaker"], ["voice", "음성 크기", "m_mic"], ["bgm", "음악 크기", "m_note"]]:
		var kind := str(spec[0])
		var side := Kit.hbox(8)
		var down := MenuArt.pill_button("작게", "blue", "s")
		down.custom_minimum_size = Vector2(96, 48)
		down.pressed.connect(_on_volume.bind(kind, -20))
		side.add_child(down)
		side.add_child(_ticks(app.volume(kind)))
		var up := MenuArt.pill_button("크게", "green", "s")
		up.custom_minimum_size = Vector2(96, 48)
		up.pressed.connect(_on_volume.bind(kind, 20))
		side.add_child(up)
		MenuArt.list_row(body, str(spec[2]), "%s  %d%%" % [spec[1], app.volume(kind)], "", side)

	# ---- 게임
	body.add_child(MenuArt.section("게임", "dice", "대전과 화면"))
	_toggle_row(body, "m_bolt", "대전 빠르기 ×2", bool(app.profile["settings"].get("fast", false)), _on_fast)
	_toggle_row(body, "sound", "내 차례 진동 알림", bool(app.profile["settings"].get("vibrate", true)), _on_vibrate)
	_toggle_row(body, "m_monitor", "전체 화면", app.fullscreen_on(), _on_fullscreen)
	_toggle_row(body, "m_gauge", "저사양 모드", app.low_gfx_on(), _on_low_gfx, "그래픽카드가 약한 PC·휴대폰에서 그림자·꾸밈 모형·빛 효과를 줄여 가볍게 해요.")
	var hint_button := MenuArt.pill_button("다시 보기", "blue", "m")
	hint_button.custom_minimum_size = Vector2(160, 56)
	hint_button.pressed.connect(_on_hints)
	MenuArt.list_row(body, "help", "첫 판 안내", "안내 말풍선을 처음부터 다시 볼 수 있어요.", hint_button)

	# ---- 계정
	body.add_child(MenuArt.section("계정", "key", "닉네임·쿠폰·기록·옮기기"))
	_name_edit = _edit_box(str(app.profile["nickname"]), "", 10)
	var name_side := Kit.hbox(8)
	name_side.add_child(_name_edit)
	var rename := MenuArt.pill_button("바꾸기", "green", "m")
	rename.custom_minimum_size = Vector2(120, 56)
	rename.pressed.connect(_on_rename)
	name_side.add_child(rename)
	MenuArt.list_row(body, "m_pencil", "닉네임", "", name_side)
	_coupon_edit = _edit_box("", "쿠폰 코드를 입력하세요", 20)
	var coupon_side := Kit.hbox(8)
	coupon_side.add_child(_coupon_edit)
	var redeem := MenuArt.pill_button("받기", "gold", "m")
	redeem.custom_minimum_size = Vector2(120, 56)
	redeem.pressed.connect(_on_coupon)
	coupon_side.add_child(redeem)
	MenuArt.list_row(body, "m_coupon", "쿠폰", "", coupon_side)

	var stats: Dictionary = app.profile["stats"]
	var played := int(stats["played"])
	var rate := 0 if played == 0 else int(round(100.0 * float(stats["wins"]) / float(played)))
	var record := MenuArt.list_row(body, "m_chart", "내 기록", "대전 %d판  ·  %d승 %d패 %d무  ·  승률 %d%%" % [played, int(stats["wins"]), int(stats["losses"]), int(stats["draws"]), rate])
	record.add_child(Kit.para("랭크전 승리 %d  ·  최고 트로피 %d (%s)" % [int(stats["rank_wins"]), int(app.profile["best_trophies"]), Profile.tier_of(app.eco, int(app.profile["best_trophies"]))["name"]], 18, Kit.MUTED))
	record.add_child(Kit.para("영웅 %d / %d명 보유  ·  플레이어 레벨 %d" % [app.profile["owned"].size(), app.data["characters"].size(), int(app.profile["level"])], 18, Kit.MUTED))

	var link := MenuArt.pill_button("준비 중", "gray", "m")
	link.custom_minimum_size = Vector2(140, 56)
	link.disabled = true
	MenuArt.list_row(body, "key", "계정 연결", "지금은 이 기기에 저장되는 게스트 계정이에요. 온라인 서버가 열리면 구글·애플 계정에 연결해 다른 기기에서도 이어 할 수 있어요.", link)
	var move := MenuArt.list_row(body, "friend", "기기 옮기기", "'옮기기 코드'를 복사해 새 기기에서 붙여 넣으면 이어 할 수 있어요.")
	var move_row := Kit.hbox(8)
	move.add_child(move_row)
	var export_button := MenuArt.pill_button("옮기기 코드 만들기", "blue", "m")
	export_button.pressed.connect(_on_export)
	move_row.add_child(Kit.expand(export_button))
	var import_button := MenuArt.pill_button("코드로 불러오기", "green", "m")
	import_button.pressed.connect(_on_import)
	move_row.add_child(Kit.expand(import_button))
	var reset := MenuArt.pill_button("초기화", "red", "m")
	reset.custom_minimum_size = Vector2(130, 56)
	reset.pressed.connect(_on_reset)
	MenuArt.list_row(body, "close", "데이터 초기화", "영웅·재화·기록이 모두 지워져요.", reset)

	var about := MenuArt.list_row(body, "book", "주사위 영웅전  버전 %s" % app.VERSION, "글꼴: Noto Sans KR (SIL Open Font License) · 엔진: Godot Engine (MIT) · 영웅·화면 그림: AI 도구로 만든 창작 일러스트")
	var about_row := Kit.hbox(8)
	about.add_child(about_row)
	var news := MenuArt.pill_button("새 소식", "blue", "m")
	news.pressed.connect(_on_news)
	about_row.add_child(Kit.expand(news))
	var opening := MenuArt.pill_button("오프닝", "purple", "m")
	opening.pressed.connect(func(): app.play_opening())
	about_row.add_child(Kit.expand(opening))
	var help := MenuArt.pill_button("게임 방법", "blue", "m")
	help.pressed.connect(_on_help)
	about_row.add_child(Kit.expand(help))
	var to_title := MenuArt.pill_button("타이틀로", "red", "m")
	to_title.pressed.connect(func(): app.go("title"))
	about_row.add_child(Kit.expand(to_title))


## 켜짐(초록)·꺼짐(회색) 알약이 오른쪽에 있는 목록 줄
func _toggle_row(body: Control, icon_name: String, title: String, on: bool, callback: Callable, note: String = "") -> void:
	var toggle := MenuArt.pill_button("켜짐" if on else "꺼짐", "green" if on else "gray", "m")
	toggle.custom_minimum_size = Vector2(130, 56)
	toggle.pressed.connect(callback)
	MenuArt.list_row(body, icon_name, title, note, toggle)


## 소리 크기 5칸 눈금(20%마다 한 칸)
func _ticks(volume: int) -> HBoxContainer:
	var line := Kit.hbox(4)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for index in 5:
		var tick := Panel.new()
		tick.custom_minimum_size = Vector2(22, 30)
		tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var lit := volume >= (index + 1) * 20
		tick.add_theme_stylebox_override("panel", Kit.box(Kit.GOLD if lit else Color(0.02, 0.08, 0.25, 0.9), Color("c9a24a"), 2, 6, 0))
		line.add_child(tick)
	return line


func _edit_box(text: String, placeholder: String, limit: int) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.placeholder_text = placeholder
	edit.max_length = limit
	edit.custom_minimum_size = Vector2(260, 52)
	edit.add_theme_font_size_override("font_size", 22)
	edit.add_theme_stylebox_override("normal", Kit.box(Color(0.02, 0.08, 0.25, 0.9), Color("c9a24a"), 2, 12, 12))
	edit.add_theme_stylebox_override("focus", Kit.box(Color(0.02, 0.08, 0.25, 0.95), Kit.GOLD, 2, 12, 12))
	return edit



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


func _on_language() -> void:
	Lang.use(Lang.next_code())
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
		MenuArt.fly_reward(app, null, result["reward"])
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
	MenuArt.skin_buttons(app.dialog("옮기기 코드", body, [["닫기", Kit.PANEL_LIGHT]], 660))


func _on_import() -> void:
	app.play("click")
	var body := Kit.vbox(10)
	body.add_child(Kit.para("다른 기기에서 만든 옮기기 코드를 붙여 넣으세요. 지금 이 기기의 데이터는 그 코드의 데이터로 바뀌어요.", 18, Color("ff9a6a")))
	_code_edit = _code_box("", true)
	body.add_child(_code_edit)
	MenuArt.skin_buttons(app.dialog("코드로 불러오기", body, [["불러오기", Color("27a35a"), _confirm_import], ["취소", Kit.PANEL_LIGHT]], 660))


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
