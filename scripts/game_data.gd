extends RefCounted
## data/ 폴더의 JSON을 읽어 오는 도우미.
## 규칙 코드와 화면 코드가 같은 데이터를 쓰도록 여기서만 파일을 읽는다.

const CHARACTERS_PATH := "res://data/characters.json"
const BOARD_PATH := "res://data/board.json"
## 대전마다 이 중 하나를 고른다. 첫 번째가 기본 맵.
const BOARD_PATHS := [
	"res://data/board.json", "res://data/boards/desert.json", "res://data/boards/frost.json", "res://data/boards/river.json",
	"res://data/boards/ruins.json", "res://data/boards/volcano.json", "res://data/boards/forest.json", "res://data/boards/sky.json",
	"res://data/boards/castle.json",
]
const CARDS_PATH := "res://data/cards.json"
const ABILITIES_PATH := "res://data/abilities.json"
const RULES_PATH := "res://data/rules.json"
const ECONOMY_PATH := "res://data/economy.json"
const ADVENTURE_PATH := "res://data/adventure.json"
const ACHIEVEMENTS_PATH := "res://data/achievements.json"
const GUIDE_PATH := "res://data/guide.json"
const MAILS_PATH := "res://data/mails.json"
const NOTICES_PATH := "res://data/notices.json"
const EVENTS_PATH := "res://data/events.json"
const COUPONS_PATH := "res://data/coupons.json"


static func load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("데이터 파일을 읽지 못했습니다: %s" % path)
		return {}
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("데이터 형식이 잘못됐습니다: %s" % path)
		return {}
	return parsed


static func load_characters() -> Array:
	return load_json(CHARACTERS_PATH).get("characters", [])


static func load_boards() -> Array:
	var boards: Array = []
	for path in BOARD_PATHS:
		boards.append(load_json(path))
	return boards


## 규칙 엔진에 넘길 데이터 묶음.
static func load_all() -> Dictionary:
	return {
		"characters": load_characters(),
		"board": load_json(BOARD_PATH),
		"boards": load_boards(),
		"cards": load_json(CARDS_PATH).get("cards", {}),
		"abilities": load_json(ABILITIES_PATH).get("abilities", {}),
		"rules": load_json(RULES_PATH),
		"economy": load_json(ECONOMY_PATH),
		"adventure": load_json(ADVENTURE_PATH),
		"achievements": load_json(ACHIEVEMENTS_PATH),
		"guide": load_json(GUIDE_PATH),
		"mails": load_json(MAILS_PATH),
		"notices": load_json(NOTICES_PATH),
		"events": load_json(EVENTS_PATH),
		"coupons": load_json(COUPONS_PATH),
	}


const PORTRAIT_PATH := "res://assets/portraits/%s.jpg"

static var _portraits: Dictionary = {}


## 캐릭터 초상화. 아직 그림이 없는 캐릭터면 null.
static func portrait(id: String) -> Texture2D:
	if _portraits.has(id):
		return _portraits[id]
	var path := PORTRAIT_PATH % id
	var texture: Texture2D = null
	if id != "" and ResourceLoader.exists(path):
		texture = load(path)
	_portraits[id] = texture
	return texture


const ART_PATH := "res://assets/art/%s.jpg"
const ENEMY_PATH := "res://assets/enemies/%s.jpg"
const ENEMIES_PATH := "res://data/enemies.json"

static var _art: Dictionary = {}
static var _enemy_ids: Dictionary = {}


## 화면용 일러스트. name은 assets/art 안의 경로(확장자 없이). 예: "ui/title_keyart", "cards/banner"
## 그림이 없으면 null이라 화면은 기존 모양을 쓴다.
static func art(name: String) -> Texture2D:
	if _art.has(name):
		return _art[name]
	var path := ART_PATH % name
	var texture: Texture2D = null
	if name != "" and ResourceLoader.exists(path):
		texture = load(path)
	_art[name] = texture
	return texture


## 적(관문지기·몬스터·골의 수호자) 초상화. 이름 앞의 "관문지기 "는 떼고 data/enemies.json에서 찾는다.
static func enemy_portrait(enemy_name: String) -> Texture2D:
	if _enemy_ids.is_empty():
		_enemy_ids = load_json(ENEMIES_PATH).get("enemies", {})
	var key := enemy_name.replace("관문지기 ", "").strip_edges()
	var id := str(_enemy_ids.get(key, ""))
	if id == "":
		return null
	var cache_key := "enemy/" + id
	if _art.has(cache_key):
		return _art[cache_key]
	var path := ENEMY_PATH % id
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path)
	_art[cache_key] = texture
	return texture


const ENEMY_STANDEE_PATH := "res://assets/enemy_standees/%s.png"
const PROP_PATH := "res://assets/props/%s.png"


## 판 위에 세우는 적의 입체 모형(바탕 투명). 없으면 null.
static func enemy_standee(enemy_name: String) -> Texture2D:
	if _enemy_ids.is_empty():
		_enemy_ids = load_json(ENEMIES_PATH).get("enemies", {})
	var id := str(_enemy_ids.get(enemy_name.replace("관문지기 ", "").strip_edges(), ""))
	if id == "":
		return null
	return _cached_texture("enemy_standee/" + id, ENEMY_STANDEE_PATH % id)


## 판 빈자리에 놓는 꾸밈 모형(나무, 탑, 바위...). 없으면 null.
static func prop(name: String) -> Texture2D:
	return _cached_texture("prop/" + name, PROP_PATH % name)


static func _cached_texture(key: String, path: String) -> Texture2D:
	if _art.has(key):
		return _art[key]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path)
	_art[key] = texture
	return texture


const STANDEE_PATH := "res://assets/standees/%s.png"


## 판 위에 세우는 입체 모형 그림(바탕 투명). 없으면 null.
static func standee(id: String) -> Texture2D:
	var key := "standee/" + id
	if _art.has(key):
		return _art[key]
	var path := STANDEE_PATH % id
	var texture: Texture2D = null
	if id != "" and ResourceLoader.exists(path):
		texture = load(path)
	_art[key] = texture
	return texture


const PORTRAIT_HD_PATH := "res://assets/portraits_hd/%s.jpg"


## 크게 보여 줄 때 쓰는 고해상도 초상화. 없으면 보통 초상화.
static func portrait_hd(id: String) -> Texture2D:
	var key := "hd/" + id
	if _art.has(key):
		return _art[key]
	var path := PORTRAIT_HD_PATH % id
	var texture: Texture2D = null
	if id != "" and ResourceLoader.exists(path):
		texture = load(path)
	else:
		texture = portrait(id)
	_art[key] = texture
	return texture


static func grade_stars(grade: int) -> String:
	return "★".repeat(grade)
