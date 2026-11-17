extends Control
## 게임 전체 틀. 화면(타이틀·로그인·로비·영웅·상점·미션·설정·파티·대전)을 바꿔 끼우고,
## 모든 화면이 함께 쓰는 데이터(규칙 데이터, 프로필, 효과음)를 들고 있다.
## 화면 전환: go("lobby"). 화면 스크립트는 scripts/screens/에 있다.

const GameData := preload("res://scripts/game_data.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const Game := preload("res://scripts/rules/game.gd")
const SaveStore := preload("res://scripts/save_store.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")
const Voice := preload("res://scripts/ui/voice.gd")
const Dialog := preload("res://scripts/ui/dialog.gd")
const Toast := preload("res://scripts/ui/toast.gd")
const Music := preload("res://scripts/ui/music.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const ProfileCard := preload("res://scripts/ui/profile_card.gd")
const LoadingOverlay := preload("res://scripts/ui/loading_overlay.gd")
const Opening := preload("res://scripts/ui/opening.gd")
## 화면마다 틀 배경음악
const SCREEN_MUSIC := {"match": "match", "title": "title", "login": "title",
	"shop": "shop", "heroes": "shop", "missions": "shop", "pass": "shop"}

const SCREENS := {
	"title": preload("res://scripts/screens/title_screen.gd"),
	"login": preload("res://scripts/screens/login_screen.gd"),
	"lobby": preload("res://scripts/screens/lobby_screen.gd"),
	"heroes": preload("res://scripts/screens/heroes_screen.gd"),
	"shop": preload("res://scripts/screens/shop_screen.gd"),
	"missions": preload("res://scripts/screens/missions_screen.gd"),
	"settings": preload("res://scripts/screens/settings_screen.gd"),
	"party": preload("res://scripts/screens/party_screen.gd"),
	"match": preload("res://scripts/screens/match_screen.gd"),
	"help": preload("res://scripts/screens/help_screen.gd"),
	"adventure": preload("res://scripts/screens/adventure_screen.gd"),
	"pass": preload("res://scripts/screens/pass_screen.gd"),
}
## 화면마다 다른 판 색(분위기). 시안식 틀을 쓰는 메뉴 화면(영웅·상점·미션·설정·모험·패스)은 시안처럼 모두 남색(2026-11-17).
const SCREEN_MOODS := {
	"lobby": Color("3b2f9e"), "shop": Color("1f3a82"), "heroes": Color("1f3a82"), "missions": Color("1f3a82"),
	"settings": Color("1f3a82"), "adventure": Color("1f3a82"), "pass": Color("1f3a82"), "help": Color("1f3a82"),
}
const VERSION := "0.25.0"

var data: Dictionary = {}
var eco: Dictionary = {}
var profile: Dictionary = {}
var sfx: Node
var voice: Node
var music: Node
var rng := RandomNumberGenerator.new()
var current_screen: Control
var current_name := ""
var _layer: Control
## 잠시 기다리는 화면
var loading: Control
## true면 기다림·화면 전환 효과를 모두 건너뛴다(자동 사진 도구용).
var instant := false
## 지금 go()가 같은 화면을 다시 그리는 중인지(MenuArt.frame이 연출을 고를 때 본다).
var redraw := false
var _busy := false
var _characters_by_id: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 화면은 1초에 60번까지만 그린다. 144Hz 같은 빠른 모니터에서 쓸데없이 2배 넘게 그려 느려지는 것을 막는다.
	Engine.max_fps = 60
	set_process(true)
	_setup_font()
	Lang.setup()
	rng.randomize()
	data = GameData.load_all()
	eco = data.get("economy", {})
	for character in data["characters"]:
		_characters_by_id[str(character["id"])] = character
	sfx = Sfx.new()
	add_child(sfx)
	voice = Voice.new()
	add_child(voice)
	voice.spoke.connect(func(seconds: float): music.duck(seconds))
	music = Music.new()
	add_child(music)
	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	loading = LoadingOverlay.new()
	add_child(loading)
	load_profile()
	music.enabled = bgm_on()
	# 가로 화면 전용: 세로로 들어도 게임이 스스로 돌아 가로로 그려진다.
	_fit_orientation()
	_setup_display()
	go("title")


## 전체 화면으로 쓴다. 웹에서는 브라우저 규칙 때문에 화면을 처음 누르는 순간에만 전체 화면이 될 수 있어서,
## 누를 때마다(전체 화면이 아니면) 전체 화면과 가로 고정을 청하는 작은 스크립트를 페이지에 심어 둔다.
## 아이폰 사파리처럼 전체 화면을 허락하지 않는 브라우저에서는 아무 일도 일어나지 않는다.
func _setup_display() -> void:
	if instant:
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			(function () {
				if (window.__dhFullHook) { return; }
				window.__dhFullHook = true;
				window.__dhFull = %s;
				var ask = function () {
					if (!window.__dhFull || document.fullscreenElement) { return; }
					var el = document.documentElement;
					var go = el.requestFullscreen || el.webkitRequestFullscreen;
					if (!go) { return; }
					try {
						var done = go.call(el, { navigationUI: 'hide' });
						var lock = function () {
							if (screen.orientation && screen.orientation.lock) { screen.orientation.lock('landscape').catch(function () {}); }
						};
						if (done && done.then) { done.then(lock).catch(function () {}); } else { lock(); }
					} catch (e) {}
				};
				document.addEventListener('pointerup', ask, true);
				document.addEventListener('touchend', ask, true);
				document.addEventListener('keyup', ask, true);
			})();
		""" % ("true" if fullscreen_on() else "false"), true)
	elif OS.has_feature("mobile"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_on() else DisplayServer.WINDOW_MODE_WINDOWED)


## 전체 화면 설정(기본 켜짐).
func fullscreen_on() -> bool:
	return not has_profile() or bool(profile.get("settings", {}).get("fullscreen", true))


func set_fullscreen(on: bool) -> void:
	profile["settings"]["fullscreen"] = on
	save()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__dhFull = %s; if (!window.__dhFull && document.fullscreenElement && document.exitFullscreen) { document.exitFullscreen(); }" % ("true" if on else "false"), true)
	elif OS.has_feature("mobile"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


## 기본 글꼴(시안 글자에 맞춘 굵은 DiceHeroes Black, tools/build_font.py로 만듦)에
## 없는 글자·기호는 노토 산스로 메운다.
func _setup_font() -> void:
	var main_font: FontFile = load("res://assets/fonts/DiceHeroes-Black.ttf")
	var backup: FontFile = load("res://assets/fonts/NotoSansKR-Regular-subset.otf")
	if main_font != null and backup != null:
		var extra: Array[Font] = [backup]
		# 골드 금화·보석 그림을 글자 하나씩(Kit.GOLD_ICON U+E000, Kit.GEM_ICON U+E001)으로 넣어 글 사이에 금화가 보이게 한다.
		var coin := _coin_font()
		if coin != null:
			extra.append(coin)
		main_font.fallbacks = extra


## 금화·보석 그림(assets/ui_icons/gold.png·gem.png)으로 만든 그림 글꼴. 글자 크기에 맞춰 늘고 줄고, 글자 색에 물들지 않는다.
func _coin_font() -> FontFile:
	const SIZE := 64
	var font := FontFile.new()
	font.fixed_size = SIZE
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	var cache := Vector2i(SIZE, 0)
	font.set_cache_ascent(0, SIZE, SIZE * 0.88)
	font.set_cache_descent(0, SIZE, SIZE * 0.22)
	var added := 0
	for pair in [["gold", Kit.GOLD_CODE], ["gem", Kit.GEM_CODE]]:
		var image := _icon_image("res://assets/ui_icons/%s.png" % pair[0], SIZE)
		if image == null:
			continue
		var glyph: int = pair[1]
		var drawn := SIZE * 1.05
		font.set_texture_image(0, cache, added, image)
		font.set_glyph_texture_idx(0, cache, glyph, added)
		font.set_glyph_uv_rect(0, cache, glyph, Rect2(0, 0, SIZE, SIZE))
		font.set_glyph_size(0, cache, glyph, Vector2(drawn, drawn))
		font.set_glyph_offset(0, cache, glyph, Vector2(SIZE * 0.05, -SIZE * 0.88))
		font.set_glyph_advance(0, SIZE, glyph, Vector2(SIZE * 1.12, 0))
		added += 1
	return font if added > 0 else null


func _icon_image(path: String, size: int) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path)
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null:
		return null
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return image


# ---------------------------------------------------------------- 프로필

func has_profile() -> bool:
	return not profile.is_empty()


## 옮기기 코드로 받은 프로필로 바꾼다. 코드가 틀리면 false.
func import_profile(text: String) -> bool:
	var imported := SaveStore.import_text(text)
	if imported.is_empty():
		return false
	profile = imported
	Profile.repair(profile, eco)
	Profile.ensure_daily(profile, today())
	save()
	return true


func load_profile() -> void:
	profile = SaveStore.load_profile()
	# 소환 포인트 한도가 레벨별로 바뀌면서 한도를 넘게 된 예전 파티는 ★이 낮은 영웅으로 맞춘다.
	if has_profile() and Profile.fit_party(profile, data["characters"], point_limit()):
		save()
	if not profile.is_empty():
		Profile.repair(profile, eco)
		Profile.ensure_daily(profile, today())
	apply_gfx()


func create_profile(nickname: String) -> void:
	profile = Profile.new_profile(Profile.clean_nickname(nickname), eco)
	Profile.ensure_daily(profile, today())
	save()
	apply_gfx()


func reset_profile() -> void:
	SaveStore.erase()
	profile = {}


# ---------------------------------------------------------------- 저사양 모드

func low_gfx_on() -> bool:
	return has_profile() and bool(profile.get("settings", {}).get("low_gfx", false))


func set_low_gfx(on: bool) -> void:
	if not has_profile():
		return
	profile["settings"]["low_gfx"] = on
	save()
	apply_gfx()


## 설정을 실제로 적용한다: 저사양이면 1초 30번까지만 그리고, 그림 부품들이 GameData.low_gfx를 보고 무거운 효과를 끈다.
func apply_gfx() -> void:
	GameData.low_gfx = low_gfx_on()
	Engine.max_fps = 30 if GameData.low_gfx else 60


var _perf_time := 0.0
var _perf_frames := 0


## 대전 중에 5초 동안 평균 1초 32번도 못 그리면(그래픽카드가 약한 기기) 저사양 모드를 저절로 켠다.
## 사용자가 설정에서 직접 켜거나 끈 적이 있으면(settings에 low_gfx가 있으면) 건드리지 않는다.
## 세로로 든 화면에서도 게임은 언제나 가로로 그린다: 틀 전체를 90도 돌리고, 가로·세로 크기를 바꿔 잡는다.
## (브라우저는 화면 방향을 강제로 못 바꾸는 경우가 많아서, 게임 쪽에서 돌려 그린다.)
var _upright := false
var _fit_view := Vector2.ZERO


func _fit_orientation() -> void:
	var window := get_window()
	var upright := float(window.size.x) < float(window.size.y) * 0.95
	var view := get_viewport_rect().size
	if upright == _upright and view == _fit_view and _fit_view != Vector2.ZERO:
		return
	if upright != _upright or _fit_view == Vector2.ZERO:
		_upright = upright
		# 세로 화면에서는 기준 크기도 세로(720×1280)로 잡아야 돌린 뒤의 글자·버튼 크기가 가로 화면과 같아진다.
		window.content_scale_size = Vector2i(720, 1280) if upright else Vector2i(1280, 720)
		view = get_viewport_rect().size
	_fit_view = view
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	if upright:
		rotation = PI * 0.5
		position = Vector2(view.x, 0)
		size = Vector2(view.y, view.x)
	else:
		rotation = 0.0
		position = Vector2.ZERO
		size = view


## 화면(창) 좌표의 점을 이 틀(가로로 돌려 그린 좌표)의 점으로 바꾼다.
func to_app(point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * point


func _process(delta: float) -> void:
	_fit_orientation()
	if instant or GameData.low_gfx or current_name != "match" or not has_profile() or profile.get("settings", {}).has("low_gfx"):
		_perf_time = 0.0
		_perf_frames = 0
		return
	_perf_time += delta
	_perf_frames += 1
	if _perf_time < 5.0:
		return
	var fps := float(_perf_frames) / _perf_time
	_perf_time = 0.0
	_perf_frames = 0
	if fps < 32.0:
		set_low_gfx(true)
		toast("화면이 버벅여서 저사양 모드를 켰어요. 설정에서 끌 수 있어요.")


func save() -> void:
	if has_profile():
		SaveStore.save_profile(profile)


func today() -> String:
	return Time.get_date_string_from_system()


## 날짜가 바뀌었으면 일일 미션을 새로 시작한다. 화면에 들어올 때마다 부른다.
func refresh_day() -> void:
	if has_profile() and Profile.ensure_daily(profile, today()):
		save()


func sfx_on() -> bool:
	return not has_profile() or bool(profile.get("settings", {}).get("sfx", true))


func bgm_on() -> bool:
	return not has_profile() or bool(profile.get("settings", {}).get("bgm", true))


## 소리 크기(0~100). kind: sfx·voice·bgm
func volume(kind: String) -> int:
	if not has_profile():
		return 100
	return clampi(int(profile.get("settings", {}).get(kind + "_volume", 100)), 0, 100)


## 설정의 소리 크기를 세 부품에 반영한다.
func apply_volumes() -> void:
	sfx.gain_db = _gain_db(volume("sfx"))
	voice.gain_db = _gain_db(volume("voice"))
	music.set_gain(_gain_db(volume("bgm")))


func _gain_db(percent: int) -> float:
	return -60.0 if percent <= 0 else linear_to_db(float(percent) / 100.0)


## 내 플레이어 레벨에서 쓸 수 있는 소환 포인트 한도(data/rules.json의 point_limits).
func point_limit() -> int:
	return Game.point_limit_at(data["rules"], int(profile.get("level", 1)) if has_profile() else 1)


func voice_on() -> bool:
	return not has_profile() or bool(profile.get("settings", {}).get("voice", true))


## 영웅 음성을 튼다. kind: select·idle·move·attack·defend·skill·win·lose
func say(hero_id: String, kind: String) -> void:
	if voice_on() and not instant:
		if hero_id == "announcer":
			hero_id = "announcer_" + announcer_id()
		voice.say(hero_id, kind)


## 안내 음성 목록(data/voice_extra.json의 announcers: id와 설정에 보일 이름).
func announcers() -> Array:
	return GameData.load_json("res://data/voice_extra.json").get("announcers", [])


## 설정에서 고른 안내 음성 id. 고른 적이 없거나 목록에 없으면 첫 번째.
func announcer_id() -> String:
	var list := announcers()
	var chosen := str(profile.get("settings", {}).get("announcer", "")) if has_profile() else ""
	for entry in list:
		if str(entry.get("id", "")) == chosen:
			return chosen
	return str(list[0].get("id", "")) if not list.is_empty() else ""



func play(sound: String) -> void:
	if sfx_on():
		sfx.play(sound)


# ---------------------------------------------------------------- 데이터

func character(id: String) -> Dictionary:
	return _characters_by_id.get(id, {})


func ability(id: String) -> Dictionary:
	return data["abilities"].get(id, {})


func owned_characters() -> Array:
	var result: Array = []
	for character_data in data["characters"]:
		if Profile.owns(profile, str(character_data["id"])):
			result.append(character_data)
	return result


func owned_levels() -> Dictionary:
	var result := {}
	for id in profile.get("owned", {}):
		result[id] = int(profile["owned"][id]["level"])
	return result


## 로비 아래 메뉴의 빨간 점.
func badges() -> Dictionary:
	if not has_profile():
		return {}
	return {
		"missions": Profile.has_claimable(profile, eco) or Profile.can_check_in(profile, today()) or Profile.has_claimable_achievement(profile, data) or Profile.guide_claimable(profile, data),
		"shop": Profile.free_summons_left(profile, eco) > 0 or not Profile.mileage_claimable(profile, eco).is_empty(),
		"heroes": _any_upgradable() or Profile.album_has_claimable(profile, eco, data["characters"]),
	}


func _any_upgradable() -> bool:
	for id in profile.get("owned", {}):
		if Profile.can_upgrade(profile, eco, str(id)):
			return true
	return false


# ---------------------------------------------------------------- 화면 전환

func go(screen_name: String, params: Dictionary = {}) -> void:
	if not SCREENS.has(screen_name):
		push_error("없는 화면: " + screen_name)
		return
	refresh_day()
	# 같은 화면을 다시 그리는 것(왼쪽 항목 전환, 보상을 받은 뒤 새로 그림)인지. 메뉴 틀은 이때 큰 판만 살짝 페이드한다.
	redraw = current_screen != null and screen_name == current_name
	if current_screen != null:
		current_screen.queue_free()
	Kit.panel_tint = SCREEN_MOODS.get(screen_name, Kit.PANEL)
	var screen = SCREENS[screen_name].new()
	current_name = screen_name
	current_screen = screen
	_layer.add_child(screen)
	screen.setup(self, params)
	# 메뉴 틀(MenuArt.frame) 화면은 스스로 등장 연출을 하므로 여기서는 건너뛴다.
	if not instant and not screen.has_meta("own_entrance") and not redraw:
		# 새 화면이 부드럽게 나타난다.
		screen.modulate.a = 0.0
		screen.pivot_offset = size * 0.5
		screen.scale = Vector2(1.035, 1.035)
		var enter: Tween = screen.create_tween().set_parallel(true)
		enter.tween_property(screen, "modulate:a", 1.0, 0.18)
		enter.tween_property(screen, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	apply_volumes()
	music.play_track(SCREEN_MUSIC.get(screen_name, "lobby"))


## 잠시 기다리는 화면을 보여 준 뒤 화면을 바꾼다. 기다리는 동안 다시 눌러도 한 번만 넘어간다.
## 게임 진입("불러오는 중"), 접속("접속 중"), 대전 준비처럼 큰 전환에 쓴다.
func go_loading(screen_name: String, params: Dictionary = {}, message: String = "불러오는 중...", seconds: float = 0.7, with_tip: bool = false) -> void:
	if instant:
		go(screen_name, params)
		return
	if _busy:
		return
	_busy = true
	await loading.show_for(message, seconds, with_tip)
	_busy = false
	go(screen_name, params)


## 화면은 그대로 두고 잠시 기다리는 화면만 보여 준다(소환처럼 결과를 기다리는 느낌).
func wait_loading(message: String, seconds: float = 0.7) -> void:
	if instant:
		return
	await loading.show_for(message, seconds, false)


## 오프닝 영상을 띄우고 끝날 때까지 기다린다. 자동 사진 도구(instant)에서는 건너뛴다.
func play_opening() -> void:
	if instant:
		return
	var opening := Opening.new()
	add_child(opening)
	await opening.finished


func toast(message: String) -> void:
	var note := Toast.new()
	add_child(note)
	note.show_text(message)


## 가운데 뜨는 창. buttons: [["글자", 색, 콜백], ...]
func dialog(title_text: String, body: Control, buttons: Array, width: float = 640.0) -> Control:
	var window := Dialog.new()
	add_child(window)
	window.open(title_text, body, buttons, width)
	return window


## 내 프로필 창 (위쪽 막대를 누르면 뜬다)
func show_profile() -> void:
	if not has_profile():
		return
	play("click")
	dialog("내 프로필", ProfileCard.profile_body(self), [["순위표", Color("f39a1c"), show_league], ["닫기", Kit.PANEL_LIGHT]], 660)


## 연습 리그 순위표
func show_league() -> void:
	if not has_profile():
		return
	dialog("연습 리그 순위", ProfileCard.league_body(self), [["닫기", Kit.PANEL_LIGHT]], 660)


## 글자 한 줄짜리 창.
func message(title_text: String, text: String, button_text: String = "확인", callback: Callable = Callable()) -> Control:
	var body := Label.new()
	body.text = text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 24)
	return dialog(title_text, body, [[button_text, Color("2fb457"), callback]])


# ---------------------------------------------------------------- 대전

## 대전 모드를 고르면 파티를 확인한 뒤 대전 화면으로 간다.
## mode: "rank"(랭크전), "ai"(AI 연습), "local"(한 기기 2인)
func start_mode(mode: String) -> void:
	go("party", {"purpose": "match", "mode": mode, "player": 1})


# ---------------------------------------------------------------- 끌어서 내리기
# 스크롤 칸 안의 판·버튼이 터치를 먼저 받아서 손가락으로 끌어도, 마우스 휠을 굴려도 내려가지 않았다.
# 그래서 여기서 직접 처리한다: 스크롤 칸 위 어디서든 끌거나 휠을 굴리면 그 칸이 움직인다.

## 이만큼(화면 점) 넘게 움직여야 '끌기'로 본다. 그보다 작으면 그냥 누른 것.
const DRAG_START := 14.0
const WHEEL_STEP := 90

var _drag_scroll: ScrollContainer
var _drag_from := Vector2.ZERO
var _drag_scroll_from := 0
var _dragging := false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_WHEEL_UP or click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if click.pressed:
				var under := _scroll_at(click.position)
				if under != null:
					under.scroll_vertical += WHEEL_STEP * (-1 if click.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
					get_viewport().set_input_as_handled()
			return
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_drag_scroll = _scroll_at(click.position)
			_drag_from = to_app(click.position)
			_dragging = false
			if _drag_scroll != null:
				_drag_scroll_from = _drag_scroll.scroll_vertical
		else:
			if _dragging and is_instance_valid(_drag_scroll):
				_drag_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_END)
			_drag_scroll = null
			_dragging = false
	elif event is InputEventMouseMotion and _drag_scroll != null:
		if not is_instance_valid(_drag_scroll):
			_drag_scroll = null
			return
		var move := to_app((event as InputEventMouseMotion).position) - _drag_from
		if not _dragging and absf(move.y) > DRAG_START and absf(move.y) > absf(move.x):
			_dragging = true
			# 끌기 시작: 누르고 있던 버튼이 손을 뗄 때 눌리지 않게 한다.
			_drag_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
		if _dragging:
			_drag_scroll.scroll_vertical = _drag_scroll_from - int(move.y)
			get_viewport().set_input_as_handled()


## 그 자리에 있는, 위아래로 움직일 수 있는 스크롤 칸(가장 위에 그려진 것). 없으면 null.
## 대화창이 떠 있으면 맨 위 대화창 안에서만 찾는다.
func _scroll_at(point: Vector2) -> ScrollContainer:
	var root: Node = self
	var windows := get_tree().get_nodes_in_group("modal")
	if not windows.is_empty():
		root = windows[windows.size() - 1]
	var found: ScrollContainer = null
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is ScrollContainer:
			var scroll := node as ScrollContainer
			var bar := scroll.get_v_scroll_bar()
			if scroll.is_visible_in_tree() and Rect2(Vector2.ZERO, scroll.size).has_point(scroll.get_global_transform().affine_inverse() * point) and bar.max_value > bar.page + 1.0:
				found = scroll
		# 뒤에 붙은 것(위에 그려진 것)이 나중에 검사되도록 거꾸로 넣는다.
		var children := node.get_children()
		children.reverse()
		for child in children:
			stack.append(child)
	return found
