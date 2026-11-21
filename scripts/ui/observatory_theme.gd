extends RefCounted
## 별의 관측소의 그림과 팔레트. 설정에서 기존 UI를 고르면 호출처가 원래 그림을 불러온다.

const ROOT := "res://assets/ui_observatory/"
const BACKDROP := preload("res://assets/ui_observatory/ui_menu/friend_party/sky.jpg")
const NIGHT := Color("101226")
const SURFACE := Color("222441")
const EDGE := Color("777ba9")
const TEXT := Color("f4efff")
const MUTED := Color("c4c9e2")
const AMBER := Color("ffd18b")
const TEAL := Color("82dfdf")

## 같은 역할의 메뉴 부품은 편성 시안의 원본 그림 한 장을 공유한다.
const PARTY_ART := ROOT + "ui_menu/friend_party/"
const SHARED_ART := {
	"ui_menu": {
		"home_btn": "home", "content_panel": "board", "rail_panel": "board",
		"currency": "currency", "reward_capsule": "currency", "summary_card": "ability",
		"section_head": "button", "list_row": "board", "top_strip": "board",
		"menu_on": "confirm", "menu_off": "button", "tab_on": "confirm", "tab_off": "button",
		"pill_gold": "confirm", "pill_blue": "button", "pill_purple": "button",
		"slot_attack": "slot_attack", "slot_defense": "slot_defense", "slot_support": "slot_support",
	},
	"ui_lobby": {
		"tile_white": "ability", "tile_navy": "board", "dock_bottom": "board",
		"btn_sys": "board", "plate_currency": "currency", "strip_event": "button",
	},
	"ui_kit": {
		"btn_blue": "button", "btn_dark": "button", "btn_purple": "button",
		"btn_gold": "confirm", "btn_start": "confirm",
		"ribbon_blue": "button", "ribbon_violet": "button", "ribbon_gold": "confirm",
	},
}

static var active := true
static var _textures: Dictionary = {}


static func texture(directory: String, name: String) -> Texture2D:
	if active:
		var path := ROOT + directory + "/" + name + ".png"
		var shared: Dictionary = SHARED_ART.get(directory, {})
		if shared.has(name):
			path = PARTY_ART + str(shared[name]) + ".png"
		if not _textures.has(path):
			_textures[path] = load(path) if ResourceLoader.exists(path) else null
		return _textures[path]
	return null


static func backdrop() -> TextureRect:
	var view := TextureRect.new()
	view.texture = BACKDROP
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view
