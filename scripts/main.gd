extends Control
## 게임 전체 틀. 화면(타이틀·로그인·로비·영웅·상점·미션·설정·파티·대전)을 바꿔 끼우고,
## 모든 화면이 함께 쓰는 데이터(규칙 데이터, 프로필, 효과음)를 들고 있다.
## 화면 전환: go("lobby"). 화면 스크립트는 scripts/screens/에 있다.

const GameData := preload("res://scripts/game_data.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const SaveStore := preload("res://scripts/save_store.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")
const Dialog := preload("res://scripts/ui/dialog.gd")
const Toast := preload("res://scripts/ui/toast.gd")
const Music := preload("res://scripts/ui/music.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const ProfileCard := preload("res://scripts/ui/profile_card.gd")
const LoadingOverlay := preload("res://scripts/ui/loading_overlay.gd")
## 화면마다 틀 배경음악
const SCREEN_MUSIC := {"match": "match"}

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
const VERSION := "0.8.0"

var data: Dictionary = {}
var eco: Dictionary = {}
var profile: Dictionary = {}
var sfx: Node
var music: Node
var rng := RandomNumberGenerator.new()
var current_screen: Control
var current_name := ""
var _layer: Control
## 잠시 기다리는 화면
var loading: Control
## true면 기다림·화면 전환 효과를 모두 건너뛴다(자동 사진 도구용).
var instant := false
var _busy := false
var _characters_by_id: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rng.randomize()
	data = GameData.load_all()
	eco = data.get("economy", {})
	for character in data["characters"]:
		_characters_by_id[str(character["id"])] = character
	sfx = Sfx.new()
	add_child(sfx)
	music = Music.new()
	add_child(music)
	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	loading = LoadingOverlay.new()
	add_child(loading)
	load_profile()
	music.enabled = bgm_on()
	go("title")


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
	if not profile.is_empty():
		Profile.repair(profile, eco)
		Profile.ensure_daily(profile, today())


func create_profile(nickname: String) -> void:
	profile = Profile.new_profile(Profile.clean_nickname(nickname), eco)
	Profile.ensure_daily(profile, today())
	save()


func reset_profile() -> void:
	SaveStore.erase()
	profile = {}


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
		"shop": Profile.free_summons_left(profile, eco) > 0,
		"heroes": _any_upgradable(),
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
	if current_screen != null:
		current_screen.queue_free()
	var screen = SCREENS[screen_name].new()
	current_name = screen_name
	current_screen = screen
	_layer.add_child(screen)
	screen.setup(self, params)
	if not instant:
		# 새 화면이 부드럽게 나타난다.
		screen.modulate.a = 0.0
		screen.create_tween().tween_property(screen, "modulate:a", 1.0, 0.16)
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
	dialog("내 프로필", ProfileCard.profile_body(self), [["순위표", Color("c4861c"), show_league], ["닫기", Kit.PANEL_LIGHT]], 660)


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
	return dialog(title_text, body, [[button_text, Color("2f80ed"), callback]])


# ---------------------------------------------------------------- 대전

## 대전 모드를 고르면 파티를 확인한 뒤 대전 화면으로 간다.
## mode: "rank"(랭크전), "ai"(AI 연습), "local"(한 기기 2인)
func start_mode(mode: String) -> void:
	go("party", {"purpose": "match", "mode": mode, "player": 1})
