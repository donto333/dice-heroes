extends RefCounted
## 별의 관측소의 그림과 팔레트. 설정에서 기존 UI를 고르면 호출처가 원래 그림을 불러온다.

const ROOT := "res://assets/ui_observatory/"
const BACKDROP := preload("res://assets/ui_observatory/observatory.jpg")
const NIGHT := Color("101226")
const SURFACE := Color("222441")
const EDGE := Color("777ba9")
const TEXT := Color("f4efff")
const MUTED := Color("c4c9e2")
const AMBER := Color("ffd18b")
const TEAL := Color("82dfdf")

static var active := true
static var _textures: Dictionary = {}


static func texture(directory: String, name: String) -> Texture2D:
	if active:
		var path := ROOT + directory + "/" + name + ".png"
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
