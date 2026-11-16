extends RefCounted
## 그림 UI 부품(assets/ui_kit): 버튼·판·리본을 손으로 그린 그림으로 그린다.
## 그림을 조각내어(귀퉁이·끝 장식은 그대로, 가운데만 늘림) 어떤 크기에도 맞춘다.
## 그림이 없으면 has()가 false를 돌려주고, 부르는 쪽이 예전 도형 그리기로 돌아간다.

const PATH := "res://assets/ui_kit/%s.png"
const META_PATH := "res://assets/ui_kit/meta.json"

static var _textures := {}
static var _meta := {}
static var _meta_loaded := false


static func tex(name: String) -> Texture2D:
	if _textures.has(name):
		return _textures[name]
	var texture: Texture2D = null
	if ResourceLoader.exists(PATH % name):
		texture = load(PATH % name)
	_textures[name] = texture
	return texture


static func has(name: String) -> bool:
	return tex(name) != null


## 틀 그림의 치수 기록(안쪽 상자 inner, 몸통 상자 outer). 없으면 빈 사전.
static func meta(name: String) -> Dictionary:
	if not _meta_loaded:
		_meta_loaded = true
		if FileAccess.file_exists(META_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
			if parsed is Dictionary:
				_meta = parsed
	return _meta.get(name, {})


## 색에 가장 가까운 버튼 그림 색 이름. 채도가 낮으면 회색/짙은 남색.
static func tone(color: Color) -> String:
	if color.s < 0.22:
		return "gray" if color.v > 0.42 else "dark"
	if color.v < 0.3:
		return "dark"
	var hue := color.h * 360.0
	if hue < 18.0 or hue >= 335.0:
		return "red"
	if hue < 68.0:
		return "gold"
	if hue < 160.0:
		return "green"
	if hue < 200.0:
		return "teal"
	if hue < 255.0:
		return "blue"
	return "purple"


## 한 방향(가로 또는 세로)의 조각 나누기. cuts는 원본 경계(0..길이), stretch는 조각마다 늘릴지 여부.
## 늘리지 않는 조각은 scale배로 그리고, 남는 길이를 늘리는 조각들이 원본 비율대로 나눠 갖는다.
## 자리가 모자라면 전부 같은 비율로 줄인다. 돌려주는 값은 목적지 경계(조각 수 + 1개).
static func _spread(cuts: Array, stretch: Array, start: float, length: float, scale: float) -> PackedFloat32Array:
	var fixed := 0.0
	var loose := 0.0
	for index in stretch.size():
		var piece: float = float(cuts[index + 1]) - float(cuts[index])
		if stretch[index]:
			loose += piece
		else:
			fixed += piece * scale
	var squeeze := 1.0
	var spare := length - fixed
	if spare < 0.0 or loose <= 0.0:
		squeeze = length / maxf(fixed + loose * scale, 0.001)
		spare = loose * scale * squeeze
	var result := PackedFloat32Array([start])
	var at := start
	for index in stretch.size():
		var piece: float = float(cuts[index + 1]) - float(cuts[index])
		if stretch[index]:
			at += spare * piece / maxf(loose, 0.001)
		else:
			at += piece * scale * squeeze
		result.append(at)
	return result


## 그림을 가로·세로 조각으로 나눠 dest에 그린다.
static func draw_grid(item: RID, texture: Texture2D, dest: Rect2, xs: Array, x_stretch: Array, ys: Array, y_stretch: Array,
		scale: float, modulate: Color = Color.WHITE) -> void:
	var to_x := _spread(xs, x_stretch, dest.position.x, dest.size.x, scale)
	var to_y := _spread(ys, y_stretch, dest.position.y, dest.size.y, scale)
	var rid := texture.get_rid()
	for row in y_stretch.size():
		for column in x_stretch.size():
			var source := Rect2(float(xs[column]), float(ys[row]), float(xs[column + 1]) - float(xs[column]), float(ys[row + 1]) - float(ys[row]))
			var target := Rect2(to_x[column], to_y[row], to_x[column + 1] - to_x[column], to_y[row + 1] - to_y[row])
			if source.size.x < 0.5 or source.size.y < 0.5 or target.size.x < 0.25 or target.size.y < 0.25:
				continue
			RenderingServer.canvas_item_add_texture_rect_region(item, target, rid, source, modulate)


## 가로로 긴 버튼·리본·막대: 높이에 맞춰 줄이고 양 끝(cap 비율 × 높이)은 그대로, 가운데만 늘린다.
## center > 0이면 가운데 장식(그림 너비의 그 비율)도 늘리지 않는다.
static func draw_bar(item: RID, texture: Texture2D, dest: Rect2, cap: float = 0.8, modulate: Color = Color.WHITE, center: float = 0.0) -> void:
	var width := float(texture.get_width())
	var height := float(texture.get_height())
	var end := minf(height * cap, width * 0.45)
	var xs: Array = [0.0, end, width - end, width]
	var x_stretch: Array = [false, true, false]
	var half := width * center * 0.5
	if center > 0.0 and width * 0.5 - half > end + 4.0:
		xs = [0.0, end, width * 0.5 - half, width * 0.5 + half, width - end, width]
		x_stretch = [false, true, false, true, false]
	draw_grid(item, texture, dest, xs, x_stretch, [0.0, height], [true], dest.size.y / height, modulate)


## 틀(창·카드): 몸통 상자가 rect에 맞도록, 튀어나온 장식은 rect 바깥으로 넘치게 그린다.
## center_cap > 0이면 위·아래 가운데 장식(그림 너비의 그 비율)은 늘리지 않는다.
static func draw_frame(item: RID, name: String, rect: Rect2, scale: float, center_cap: float = 0.0, modulate: Color = Color.WHITE) -> void:
	var texture := tex(name)
	var info := meta(name)
	if texture == null or info.is_empty():
		return
	var width := float(texture.get_width())
	var height := float(texture.get_height())
	var inner: Array = info["inner"]
	var outer: Array = info["outer"]
	var dest := Rect2(rect.position.x - float(outer[0]) * scale, rect.position.y - float(outer[1]) * scale,
		rect.size.x + (float(outer[0]) + width - float(outer[2])) * scale, rect.size.y + (float(outer[1]) + height - float(outer[3])) * scale)
	var inner_w: float = float(inner[2]) - float(inner[0])
	var inner_h: float = float(inner[3]) - float(inner[1])
	var corner_x: float = float(inner[0]) + minf(inner_w * 0.12, inner_h * 0.3)
	var corner_y: float = float(inner[1]) + minf(inner_h * 0.14, inner_w * 0.3)
	var xs: Array = [0.0, corner_x, width - corner_x, width]
	var x_stretch: Array = [false, true, false]
	if center_cap > 0.0:
		var half := width * center_cap * 0.5
		xs = [0.0, corner_x, width * 0.5 - half, width * 0.5 + half, width - corner_x, width]
		x_stretch = [false, true, false, true, false]
	draw_grid(item, texture, dest, xs, x_stretch, [0.0, corner_y, height - (corner_y - float(inner[1])) - (height - float(inner[3])), height],
		[false, true, false], scale, modulate)


## 틀의 테 두께(몸통 바깥에서 안쪽 면까지, 원본 px).
static func border(name: String) -> float:
	var info := meta(name)
	if info.is_empty():
		return 0.0
	return float(info["inner"][0]) - float(info["outer"][0])
