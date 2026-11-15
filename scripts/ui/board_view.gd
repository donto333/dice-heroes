extends Control
## 보드를 그리는 화면 요소. 프로토타입이라 그림 대신 색 칸과 글자로 그린다.
## 칸의 자리는 board.json의 x, y 좌표를 따르고, 이어진 칸 사이에는 선을 긋는다.
## 말은 규칙 엔진이 보낸 "pos" 사건을 받아 한 칸씩 걸어간다.

const TILE_GAP := 8.0
## 판을 뒤로 기울여 보이게: 세로 칸 간격을 이만큼 눌러 그린다.
const TILT := 0.74
## 블록 칸의 두께(칸 크기에 대한 비율)
const BLOCK_DEPTH := 0.17
## 진 말이 거점으로 날아가는 시간(초)
const FLING_TIME := 0.8
const STEP_TIME := 0.17
const PAUSE_TIME := 0.35

const TILE_COLORS := {
	"start": Color("5c6b8a"),
	"normal": Color("b59a5c"),
	"fork": Color("8a6fd0"),
	"treasure": Color("c9a227"),
	"battle": Color("d9702b"),
	"ambush": Color("a8323e"),
	"gate": Color("5a1020"),
	"forward": Color("7cb342"),
	"warp": Color("1ba39c"),
	"luck": Color("e6c84a"),
	"curse": Color("5b2a86"),
	"prison": Color("777777"),
	"fate": Color("222222"),
	"checkpoint": Color("4aa3df"),
	"goal": Color("e85d9a"),
}
const HIDDEN_COLOR := Color("4b4f6b")
const ATTR_COLORS := {
	"영웅": Color("c0392b"),
	"위인": Color("2f6fb5"),
	"신화": Color("7d4bb3"),
	"근현대": Color("2e8b57"),
}
const TILE_LABELS := {
	"start": "출발",
	"normal": "",
	"fork": "갈림길",
	"treasure": "보물",
	"battle": "전투",
	"ambush": "습격",
	"gate": "관문",
	"forward": "전진",
	"warp": "워프",
	"luck": "행운",
	"curse": "저주",
	"prison": "감옥",
	"fate": "판정",
	"checkpoint": "거점",
	"goal": "골",
}
const PLAYER_COLORS := [Color("4fc3f7"), Color("ff7043")]
const ICON_NAMES := {
	"start": "start", "fork": "fork", "treasure": "treasure", "battle": "battle", "ambush": "ambush", "gate": "battle",
	"forward": "forward", "warp": "warp", "luck": "luck", "curse": "curse",
	"prison": "prison", "fate": "fate", "checkpoint": "checkpoint", "goal": "goal",
}
const ATTR_ICONS := {"영웅": "attr_hero", "위인": "attr_great", "신화": "attr_myth", "근현대": "attr_modern"}

const GameData := preload("res://scripts/game_data.gd")
## 광택 그림 아이콘(assets/ui_icons)에서 칸 종류마다 쓸 이름. 없으면 도트 아이콘을 쓴다.
const GLOSSY_ICONS := {
	"start": "t_start", "fork": "t_fork", "treasure": "chest", "battle": "swords", "ambush": "t_ambush", "gate": "t_gate",
	"forward": "t_forward", "warp": "t_warp", "luck": "t_luck", "curse": "t_curse",
	"prison": "t_prison", "fate": "t_fate", "checkpoint": "flag", "goal": "crown", "hidden": "help",
	"attr_hero": "attr_hero", "attr_great": "attr_great", "attr_myth": "attr_myth", "attr_modern": "attr_modern",
}

var _icons: Dictionary = {}
## 그린 바탕(assets/art/boards/<지형>.jpg). 있으면 도트 지형·꾸밈 대신 이것을 깐다.
var _ground: Texture2D = null
var _styles: Dictionary = {}

signal stepped
## 말이 칸에 내려앉았을 때(player, flung: 날아가 떨어진 것인지)
signal landed(player_index: int, flung: bool)
## 말이 져서 날아가기 시작할 때
signal flung_away(player_index: int)

var game = null
## 화면에 그려지는 말의 위치(칸 id). 규칙상 위치를 따라 한 칸씩 움직인다.
var shown_pos: Array = [0, 0]
## 갈림길에서 고를 수 있는 칸. 테두리로 강조한다.
var highlight: Array = []
var _queue: Array = []
var _timer := 0.0

## 큰 맵은 화면에 다 안 들어가므로 칸 크기를 MIN_CELL로 두고 카메라로 일부만 보여 준다.
const MIN_CELL := 84.0
const CAMERA_SPEED := 6.0
const MINIMAP_WIDTH := 110.0
## 카메라가 보고 있는 맵 위의 점(맵 좌표, 픽셀)
var _camera := Vector2.ZERO
var _camera_target := Vector2.ZERO
var _camera_ready := false
## 손가락으로 끌어서 보고 있는 중이면 true. 다음 움직임이 시작되면 다시 말을 따라간다.
var _manual := false
var _dragging := false
## 카메라가 따라갈 말
var focus_player := 0
## 말로 그릴 영웅 초상화(플레이어마다). 없으면 기본 말 아이콘.
var piece_textures: Array = [null, null]
## 말로 세울 입체 모형 그림(플레이어마다, 바탕이 투명한 전신 그림). 없으면 둥근 초상화 말.
var piece_standees: Array = [null, null]
## 말이 보는 방향(1 오른쪽, -1 왼쪽). 움직인 쪽을 본다.
var _facing: Array = [1.0, 1.0]
## 착지 직후 눌렸다 펴지는 정도(말마다 0~1, 시간이 지나면 0으로)
var _squash: Array = [0.0, 0.0]
## 칸에서 피어오르는 먼지·별: [{"id": 칸, "t": 0~1, "kind": "dust" 또는 "stars"}]
var _puffs: Array = []
## 위에서 아래 순서로 정렬한 칸 id(위 칸의 옆면이 아래 칸의 아이콘을 가리지 않게 이 순서로 그린다).
var _draw_order: Array = []
var _draw_order_for := -1
## 지금 차례인 말은 살짝 통통 튄다.
var active_player := -1
var _anim_time := 0.0
## 통통 튀는 이동: 말마다 {"from": 칸 id, "t": 0~1}. 없으면 멈춰 있는 것.
var _hops: Dictionary = {}
## 말이 내려앉은 칸에서 퍼지는 고리: [{"id": 칸, "t": 0~1, "color": 색}]
var _rings: Array = []
## 지형 바탕과 꾸밈 그림(assets/terrain). 맵 테마가 바뀌면 다시 읽는다.
var _terrain_name := ""
var _terrain: Texture2D = null
var _deco: Texture2D = null
var _occupied: Dictionary = {}
## 이 맵의 빈자리에 놓을 꾸밈 모형들
var _props: Array = []
const PROP_NAMES := {
	"grass": ["plain_haystack", "plain_tent", "plain_signpost", "plain_flowers", "castle_tower", "castle_wall", "castle_banner", "castle_catapult", "forest_tree"],
	"desert": ["desert_palm", "desert_pyramid", "desert_cactus", "desert_obelisk"],
	"forest": ["forest_tree", "forest_pines", "forest_mushrooms", "forest_stump"],
	"snow": ["snow_pine", "snow_igloo", "snow_crystal", "snow_snowman"],
	"river": ["river_bridge", "river_reeds", "river_boat", "river_windmill"],
	"ruins": ["ruins_pillar", "ruins_statue", "ruins_arch", "ruins_chest"],
	"sky": ["sky_cloud", "sky_island", "sky_balloon", "sky_temple"],
	"volcano": ["volcano_cone", "volcano_rock", "volcano_skull", "volcano_torch"],
}
## 칸 위에 서 있는 적 그림 시트(assets/terrain/monsters.png, tools/make_terrain.py). 32px 그림이 가로로 붙어 있다.
var _monsters: Texture2D = null
## 시트의 그림 순서와, 이름에 이 낱말이 들어가면 그 그림을 쓴다. 맞는 게 없으면 짐승.
const MONSTER_KINDS := [
	["늑대", "들개", "멧돼지", "곰", "악어", "도마뱀", "개구리", "전갈", "벌레", "거미", "뱀", "괴물", "설인"],
	["기사", "병사", "산적", "도굴꾼", "도적", "강도", "지기", "두목"],
	["골렘", "석상", "수호병"],
	["정령", "유령", "그림자", "귀신", "마법사"],
	["하피", "독수리", "고래", "새"],
	["천장", "화살", "돌풍", "화산탄"],
]
const MONSTER_BOSS := 6
const TERRAIN_SCALE := 4.0
## 판 위에 얹힌 것(정보판, 주사위 버튼)이 가리는 위·아래 높이(픽셀)
var pad_top := 0.0
var pad_bottom := 0.0
var pad_left := 0.0
const HOP_HEIGHT := 0.42


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 지형 바탕을 이어 붙여 그리려면 반복이 켜져 있어야 한다.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if ResourceLoader.exists("res://assets/terrain/monsters.png"):
		_monsters = load("res://assets/terrain/monsters.png")
	# 카메라로 보는 큰 맵이 판 밖으로 삐져나오지 않게 자른다.
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	for icon_name in ["start", "fork", "treasure", "battle", "ambush", "forward", "warp", "luck", "curse", "prison",
			"fate", "checkpoint", "goal", "hidden", "pawn", "attr_hero", "attr_great", "attr_myth", "attr_modern"]:
		var path := "res://assets/icons/%s.png" % icon_name
		var glossy := "res://assets/ui_icons/%s.png" % str(GLOSSY_ICONS.get(icon_name, ""))
		if ResourceLoader.exists(glossy):
			_icons[icon_name] = load(glossy)
		elif ResourceLoader.exists(path):
			_icons[icon_name] = load(path)


func reset_pieces() -> void:
	_queue.clear()
	_timer = 0.0
	_manual = false
	_camera_ready = false
	highlight = []
	_hops = {}
	_rings = []
	_puffs = []
	_squash = [0.0, 0.0]
	_draw_order_for = -1
	shown_pos = [0, 0]
	if game != null:
		for index in game.players.size():
			shown_pos[index] = int(game.players[index]["pos"])
	queue_redraw()


## [{"player": 0, "to": 칸 id}, ...] 순서대로 한 칸씩 움직인다.
func push_moves(moves: Array) -> void:
	_queue.append_array(moves)


## 이 말이 이어서 더 움직일 칸 수(지금 뛰는 칸 포함). 다른 말의 움직임이 끼어들면 거기까지만 센다.
func _steps_left(player_index: int) -> int:
	var count := 1 if _hops.has(player_index) else 0
	for move in _queue:
		if int(move["player"]) != player_index:
			break
		count += 1
	return count if count > 1 else 0


func is_busy() -> bool:
	return not _queue.is_empty() or not _hops.is_empty()


## 카메라를 이 말에게 맞춘다(턴이 시작될 때 부른다).
func focus_on(player_index: int) -> void:
	focus_player = player_index
	_manual = false


func _process(delta: float) -> void:
	_update_camera(delta)
	_anim_time += delta
	if active_player >= 0:
		queue_redraw()
	for player_index in _hops.keys():
		var hop: Dictionary = _hops[player_index]
		var duration: float = FLING_TIME if bool(hop.get("fling", false)) else STEP_TIME * 0.92
		hop["t"] = float(hop["t"]) + delta / duration
		if float(hop["t"]) >= 1.0:
			var flung := bool(hop.get("fling", false))
			_hops.erase(player_index)
			_squash[player_index] = 1.0
			landed.emit(int(player_index), flung)
			_puffs.append({"id": int(shown_pos[player_index]), "t": 0.0, "kind": "stars" if flung else "dust"})
			# 이어서 뛸 칸이 없으면(도착) 고리를 퍼뜨린다.
			if _queue.is_empty() or int(_queue[0]["player"]) != int(player_index):
				_rings.append({"id": int(shown_pos[player_index]), "t": 0.0, "color": PLAYER_COLORS[player_index]})
		queue_redraw()
	for index in _squash.size():
		if float(_squash[index]) > 0.0:
			_squash[index] = maxf(float(_squash[index]) - delta / 0.22, 0.0)
			queue_redraw()
	if not _puffs.is_empty():
		for puff in _puffs:
			puff["t"] = float(puff["t"]) + delta / (0.7 if str(puff["kind"]) == "stars" else 0.35)
		_puffs = _puffs.filter(func(puff): return float(puff["t"]) < 1.0)
		queue_redraw()
	if not _rings.is_empty():
		for ring in _rings:
			ring["t"] = float(ring["t"]) + delta / 0.5
		_rings = _rings.filter(func(ring): return float(ring["t"]) < 1.0)
		queue_redraw()
	if _queue.is_empty():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var move: Dictionary = _queue.pop_front()
	var who := int(move["player"])
	var from_id := int(shown_pos[who])
	var to_id := int(move["to"])
	# 앞으로 이어진 칸이 아니면(전투에 져서 돌아가기, 워프) 한 번에 크게 날아간다.
	var flying: bool = game != null and game.nodes.has(from_id) and not (to_id in game.nodes[from_id]["next"])
	if flying:
		# 이어지는 뒤로 가기는 모두 합쳐 마지막 칸까지 한 번에 간다.
		while not _queue.is_empty() and int(_queue[0]["player"]) == who and game.nodes.has(to_id) \
				and not (int(_queue[0]["to"]) in game.nodes[to_id]["next"]):
			to_id = int(_queue.pop_front()["to"])
	_hops[who] = {"from": from_id, "t": 0.0, "fling": flying}
	if flying:
		flung_away.emit(who)
	shown_pos[who] = to_id
	if game != null and game.nodes.has(from_id) and game.nodes.has(to_id):
		var dx := int(game.nodes[to_id].get("x", 0)) - int(game.nodes[from_id].get("x", 0))
		if dx != 0 and not flying:
			_facing[who] = 1.0 if dx > 0 else -1.0
	focus_player = who
	_manual = false
	stepped.emit()
	_timer = FLING_TIME + 0.15 if flying else STEP_TIME
	# 다음 움직임이 다른 말이면 잠깐 쉬어서 누가 움직이는지 보이게 한다.
	if not flying and (_queue.is_empty() or int(_queue[0]["player"]) != who):
		_timer = PAUSE_TIME
	queue_redraw()


func _grid_size() -> Vector2i:
	var max_x := 0
	var max_y := 0
	for id in game.nodes:
		max_x = max(max_x, int(game.nodes[id].get("x", 0)))
		max_y = max(max_y, int(game.nodes[id].get("y", 0)))
	return Vector2i(max_x + 1, max_y + 1)


## 맵 전체가 들어가면 화면에 맞추고, 안 들어가면 칸 크기를 고정하고 카메라 위치에 맞춰 그린다.
func _layout() -> Dictionary:
	var grid := _grid_size()
	var fit: float = min(size.x / grid.x, size.y / (grid.y * TILT))
	if fit >= MIN_CELL:
		var origin := Vector2((size.x - fit * grid.x) / 2.0, (size.y - fit * TILT * grid.y) / 2.0)
		return {"cell": fit, "origin": origin, "camera": false}
	var cell := MIN_CELL
	var world := Vector2(grid.x, grid.y * TILT) * cell
	var view_origin := size / 2.0 - _clamped_camera(world)
	# 맵이 화면보다 좁은 쪽은 가운데에 둔다.
	if world.x <= size.x:
		view_origin.x = (size.x - world.x) / 2.0
	if world.y <= size.y:
		view_origin.y = (size.y - world.y) / 2.0
	return {"cell": cell, "origin": view_origin, "camera": true, "world": world}


func _clamped_camera(world: Vector2) -> Vector2:
	var half := size / 2.0
	# 위아래 여백만큼 맵 밖까지 밀 수 있게 해서, 가장자리 칸이 판 위에 얹힌 정보판에 가려지지 않게 한다.
	return Vector2(clampf(_camera.x, half.x - pad_left, max(half.x - pad_left, world.x - half.x)),
		clampf(_camera.y, half.y - pad_top, max(half.y - pad_top, world.y - half.y + pad_bottom)))


## 카메라가 따라갈 말의 맵 위 위치(픽셀)
func _focus_point() -> Vector2:
	var id := int(shown_pos[clampi(focus_player, 0, shown_pos.size() - 1)])
	if not game.nodes.has(id):
		return Vector2.ZERO
	var node: Dictionary = game.nodes[id]
	return Vector2(int(node.get("x", 0)) + 0.5, (int(node.get("y", 0)) + 0.5) * TILT) * MIN_CELL


func _update_camera(delta: float) -> void:
	if game == null or game.nodes.is_empty():
		return
	var grid := _grid_size()
	if min(size.x / grid.x, size.y / (grid.y * TILT)) >= MIN_CELL:
		return
	if not _manual:
		_camera_target = _focus_point()
	if not _camera_ready:
		_camera = _camera_target
		_camera_ready = true
		queue_redraw()
		return
	var world := Vector2(grid.x, grid.y * TILT) * MIN_CELL
	_camera = _clamped_camera(world)
	if _camera.distance_to(_camera_target) > 0.5 and not _dragging:
		_camera = _camera.lerp(_camera_target, clampf(delta * CAMERA_SPEED, 0.0, 1.0))
		queue_redraw()


## 손가락(마우스)으로 끌면 맵을 둘러본다.
func _gui_input(event: InputEvent) -> void:
	if game == null:
		return
	var grid := _grid_size()
	if min(size.x / grid.x, size.y / (grid.y * TILT)) >= MIN_CELL:
		return
	var world := Vector2(grid.x, grid.y * TILT) * MIN_CELL
	if event is InputEventScreenDrag:
		_drag_by(event.relative, world)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_drag_by(event.relative, world)
	elif event is InputEventMouseButton or event is InputEventScreenTouch:
		_dragging = event.is_pressed()


func _drag_by(relative: Vector2, world: Vector2) -> void:
	_manual = true
	_dragging = true
	_camera = _clamped_camera(world) - relative
	_camera = _clamped_camera(world)
	_camera_target = _camera
	queue_redraw()


## 칸 종류와 적 이름으로 시트의 몇 번째 그림을 쓸지 정한다. 골의 수호자는 늘 보스 그림.
static func monster_kind(tile_type: String, monster_name: String) -> int:
	if tile_type == "goal":
		return MONSTER_BOSS
	for index in MONSTER_KINDS.size():
		for word in MONSTER_KINDS[index]:
			if monster_name.contains(str(word)):
				return index
	return 0


func _load_terrain(name: String) -> void:
	if name == _terrain_name:
		return
	_terrain_name = name
	_terrain = null
	_deco = null
	_ground = GameData.art("boards/" + name) if name != "" else null
	# 그린 바탕과 그림 아이콘은 부드럽게, 도트 그림은 또렷하게 키운다.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if _ground != null else CanvasItem.TEXTURE_FILTER_NEAREST
	if name == "":
		return
	var ground := "res://assets/terrain/%s.png" % name
	if ResourceLoader.exists(ground):
		_terrain = load(ground)
	var sheet := "res://assets/terrain/%s_deco.png" % name
	if ResourceLoader.exists(sheet):
		_deco = load(sheet)
	_occupied = {}
	for id in game.nodes:
		_occupied[Vector2i(int(game.nodes[id].get("x", 0)), int(game.nodes[id].get("y", 0)))] = true
	_props = []
	for prop_name in PROP_NAMES.get(name, []):
		var prop_texture: Texture2D = GameData.prop(str(prop_name))
		if prop_texture != null:
			_props.append(prop_texture)


## 칸이 없는 빈자리에 나무·탑·바위 같은 입체 꾸밈 모형을 세운다. 자리와 종류는 좌표로 정해져 늘 같다.
## 바로 위에 칸이 있는 자리는 비워 둔다(칸을 가리지 않게).
func _draw_props(layout: Dictionary) -> void:
	if _props.is_empty():
		return
	var cell: float = layout["cell"]
	var origin: Vector2 = layout["origin"]
	var row := cell * TILT
	var first := Vector2i(floori(-origin.x / cell) - 1, floori(-origin.y / row) - 1)
	var last := Vector2i(floori((size.x - origin.x) / cell) + 1, floori((size.y - origin.y) / row) + 2)
	for gy in range(first.y, last.y + 1):
		for gx in range(first.x, last.x + 1):
			if _occupied.has(Vector2i(gx, gy)) or _occupied.has(Vector2i(gx, gy - 1)):
				continue
			var seed_value: int = absi((gx * 73856093) ^ (gy * 19349663) ^ 0x2545f491)
			if seed_value % 100 >= 34:
				continue
			var texture: Texture2D = _props[(seed_value / 100) % _props.size()]
			var tall := cell * (0.95 + ((seed_value / 7) % 30) / 100.0)
			var wide := tall * float(texture.get_width()) / float(texture.get_height())
			var jitter := Vector2(((seed_value / 1000) % 21 - 10) / 70.0, ((seed_value / 30000) % 21 - 10) / 90.0)
			var foot := origin + Vector2((gx + 0.5 + jitter.x) * cell, (gy + 0.62 + jitter.y) * row)
			draw_set_transform(foot, 0.0, Vector2(1.0, 0.36))
			draw_circle(Vector2.ZERO, wide * 0.42, Color(0, 0, 0, 0.26))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_texture_rect(texture, Rect2(foot.x - wide / 2.0, foot.y - tall * 0.96, wide, tall), false)


## 칸이 없는 빈 자리에 나무·집·바위 같은 꾸밈 그림을 흩어 놓는다. 자리와 종류는 좌표로 정해져 늘 같다.
func _draw_decorations(layout: Dictionary) -> void:
	if _deco == null:
		return
	var cell: float = layout["cell"]
	var origin: Vector2 = layout["origin"]
	var count: int = max(1, int(_deco.get_width() / 32.0))
	var first := Vector2i(floori(-origin.x / cell) - 1, floori(-origin.y / cell) - 1)
	var last := Vector2i(floori((size.x - origin.x) / cell) + 1, floori((size.y - origin.y) / cell) + 1)
	for gy in range(first.y, last.y + 1):
		for gx in range(first.x, last.x + 1):
			if _occupied.has(Vector2i(gx, gy)):
				continue
			var seed_value: int = absi((gx * 73856093) ^ (gy * 19349663) ^ 0x5bd1e995)
			if seed_value % 100 >= 46:
				continue
			var kind: int = (seed_value / 100) % count
			var jitter := Vector2(((seed_value / 1000) % 21 - 10) / 60.0, ((seed_value / 30000) % 21 - 10) / 60.0)
			var side := cell * (0.78 + ((seed_value / 7) % 20) / 100.0)
			var spot := origin + (Vector2(gx, gy) + Vector2(0.5, 0.5) + jitter) * cell
			draw_texture_rect_region(_deco, Rect2(spot - Vector2(side, side) / 2.0, Vector2(side, side)), Rect2(kind * 32, 0, 32, 32))


## 두께가 있는 블록 칸: 그림자 → 옆면(어두운 색) → 윗면 → 윗면의 광택과 밝은 테.
## lit이면(갈림길에서 고를 수 있는 칸) 흰 테가 깜빡인다.
func _draw_hex(center: Vector2, _half: Vector2, cell: float, color: Color, lit: bool) -> void:
	var width := cell - TILE_GAP
	var height := cell * TILT - TILE_GAP * 0.6
	var depth := cell * BLOCK_DEPTH
	var top := Rect2(center.x - width / 2.0, center.y - height / 2.0 - depth * 0.5, width, height)
	var radius := int(cell * 0.16)
	var key := color.to_html()
	if not _styles.has(key):
		var wall := StyleBoxFlat.new()
		wall.bg_color = color.darkened(0.55)
		wall.set_corner_radius_all(radius)
		wall.shadow_color = Color(0, 0, 0, 0.32)
		wall.shadow_size = 4
		wall.shadow_offset = Vector2(0, 4)
		wall.anti_aliasing_size = 1.0
		var face := StyleBoxFlat.new()
		face.bg_color = color
		face.set_corner_radius_all(radius)
		face.border_color = color.lightened(0.38)
		face.set_border_width_all(3)
		face.anti_aliasing_size = 1.0
		var gleam := StyleBoxFlat.new()
		gleam.bg_color = Color(1, 1, 1, 0.2)
		gleam.set_corner_radius_all(maxi(radius - 4, 2))
		gleam.anti_aliasing_size = 1.0
		_styles[key] = [wall, face, gleam]
	var parts: Array = _styles[key]
	draw_style_box(parts[0], Rect2(top.position, Vector2(width, height + depth)))
	draw_style_box(parts[1], top)
	draw_style_box(parts[2], Rect2(top.position + Vector2(5, 5), Vector2(width - 10, height * 0.42)))
	if lit:
		var pulse := 0.6 + 0.4 * sin(_anim_time * 6.0)
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.border_color = Color(1, 1, 1, pulse)
		ring.set_border_width_all(5)
		ring.set_corner_radius_all(radius + 3)
		draw_style_box(ring, top.grow(4.0))


## 칸 종류마다 다른 살아 있는 효과(워프 소용돌이, 보물 반짝임, 저주 연기, 감옥 창살, 전투 칸 붉은 숨결).
## 가벼운 선·점만 그려서 칸이 많아도 느려지지 않는다.
func _draw_tile_fx(kind: String, center: Vector2, cell: float, id: int) -> void:
	var top := center - Vector2(0, cell * BLOCK_DEPTH * 0.5)
	var beat := _anim_time + float(id % 11) * 0.37
	match kind:
		"warp":
			draw_set_transform(top, 0.0, Vector2(1.0, TILT))
			for index in 3:
				var start := beat * 2.6 + TAU * index / 3.0
				draw_arc(Vector2.ZERO, cell * (0.2 + index * 0.08), start, start + 2.2, 14, Color(0.6, 1.0, 0.95, 0.75 - index * 0.18), 3.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"treasure", "luck":
			for index in 3:
				var phase := fposmod(beat * 0.9 + index * 0.33, 1.0)
				var spot := top + Vector2(cos(index * 2.3 + id) * cell * 0.3, -cell * (0.1 + phase * 0.42))
				var arm := cell * 0.07 * sin(phase * PI)
				var glint := Color(1.0, 0.97, 0.7, sin(phase * PI))
				draw_line(spot - Vector2(arm, 0), spot + Vector2(arm, 0), glint, 2.0)
				draw_line(spot - Vector2(0, arm), spot + Vector2(0, arm), glint, 2.0)
		"curse":
			for index in 3:
				var phase := fposmod(beat * 0.6 + index * 0.33, 1.0)
				var spot := top + Vector2(sin(beat * 2.0 + index * 2.0) * cell * 0.16 + (index - 1) * cell * 0.16, -cell * phase * 0.55)
				draw_circle(spot, cell * (0.05 + phase * 0.05), Color(0.72, 0.4, 1.0, (1.0 - phase) * 0.55))
		"prison":
			var bar_top := top.y - cell * 0.5
			var bar_bottom := top.y + cell * TILT * 0.3
			for index in 5:
				var x := center.x + (index - 2) * cell * 0.17
				draw_line(Vector2(x, bar_top), Vector2(x, bar_bottom), Color(0.12, 0.13, 0.18, 0.9), cell * 0.055)
				draw_line(Vector2(x - cell * 0.012, bar_top), Vector2(x - cell * 0.012, bar_bottom), Color(0.8, 0.84, 0.9, 0.7), cell * 0.016)
			draw_line(Vector2(center.x - cell * 0.4, bar_top), Vector2(center.x + cell * 0.4, bar_top), Color(0.12, 0.13, 0.18, 0.95), cell * 0.07)
		"battle", "ambush", "gate":
			var breath := 0.5 + 0.5 * sin(beat * 3.2)
			draw_set_transform(top, 0.0, Vector2(1.0, TILT))
			draw_arc(Vector2.ZERO, cell * (0.44 + breath * 0.04), 0.0, TAU, 28, Color(1.0, 0.3, 0.2, 0.25 + breath * 0.35), 3.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"forward":
			for index in 2:
				var phase := fposmod(beat * 1.2 + index * 0.5, 1.0)
				var tip := top + Vector2(-cell * 0.3 + phase * cell * 0.6, cell * 0.2)
				var arrow := Color(0.9, 1.0, 0.6, sin(phase * PI) * 0.8)
				draw_line(tip - Vector2(cell * 0.08, cell * 0.06), tip, arrow, 3.0)
				draw_line(tip - Vector2(cell * 0.08, -cell * 0.06), tip, arrow, 3.0)
		"checkpoint":
			var wave := fposmod(beat * 0.7, 1.0)
			draw_set_transform(top, 0.0, Vector2(1.0, TILT))
			draw_arc(Vector2.ZERO, cell * (0.3 + wave * 0.26), 0.0, TAU, 28, Color(0.7, 0.92, 1.0, (1.0 - wave) * 0.7), 3.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"fate":
			var spin := beat * 1.5
			for index in 4:
				var spot := top + Vector2(cos(spin + TAU * index / 4.0) * cell * 0.36, sin(spin + TAU * index / 4.0) * cell * 0.36 * TILT)
				draw_circle(spot, cell * 0.035, Color(1.0, 0.85, 0.3, 0.85))


## 말이 서 있는 곳(이 보드 안의 좌표). 연출 층이 여기서 알갱이를 터뜨린다.
func piece_point(player_index: int) -> Vector2:
	if game == null or player_index >= shown_pos.size() or not game.nodes.has(int(shown_pos[player_index])):
		return size * 0.5
	var layout := _layout()
	return _center(int(shown_pos[player_index]), layout) - Vector2(0, float(layout["cell"]) * 0.5)


## 서 있는 입체 모형 말: 발밑 그림자와 색 고리 → 모형(뛸 때 늘어나고 착지 때 눌림) → 내 차례 표시와 남은 칸 수.
func _draw_standee(texture: Texture2D, player_index: int, center: Vector2, lift: float, cell: float, hop_t: float, flinging: bool, font: Font) -> void:
	var player_color: Color = PLAYER_COLORS[player_index]
	var active: bool = player_index == active_player
	var foot := center + Vector2(0, cell * 0.1)
	var shade := 1.0 - minf(lift / (cell * 2.4), 1.0) * 0.6
	draw_set_transform(foot, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, cell * 0.3 * shade, Color(0, 0, 0, 0.36 * shade))
	draw_arc(Vector2.ZERO, cell * 0.36, 0.0, TAU, 32, player_color, 6.0)
	if active:
		var pulse := 0.5 + 0.5 * sin(_anim_time * 5.0)
		draw_arc(Vector2.ZERO, cell * (0.44 + pulse * 0.05), 0.0, TAU, 32, Color(1, 1, 1, 0.9 - pulse * 0.5), 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var height := cell * 1.5
	var texture_size := texture.get_size()
	var width := height * texture_size.x / maxf(texture_size.y, 1.0)
	var stretch := Vector2.ONE
	if hop_t >= 0.0 and not flinging:
		stretch = Vector2(1.0 - 0.07 * sin(hop_t * PI), 1.0 + 0.12 * sin(hop_t * PI))
	var squash := float(_squash[player_index]) if player_index < _squash.size() else 0.0
	stretch = Vector2(stretch.x * (1.0 + 0.14 * squash), stretch.y * (1.0 - 0.18 * squash))
	var bob := 0.0
	if active and hop_t < 0.0 and _queue.is_empty():
		bob = -absf(sin(_anim_time * 4.0)) * cell * 0.07
	var base := foot + Vector2(0, bob - lift)
	var facing := float(_facing[player_index]) if player_index < _facing.size() else 1.0
	if flinging:
		# 빙글빙글 돌며 날아간다.
		draw_set_transform(base - Vector2(0, height * 0.5), hop_t * TAU * 2.0, Vector2(facing, 1.0))
		draw_texture_rect(texture, Rect2(-width / 2.0, -height / 2.0, width, height), false)
	else:
		draw_set_transform(base, 0.0, Vector2(stretch.x * facing, stretch.y))
		draw_texture_rect(texture, Rect2(-width / 2.0, -height, width, height), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var head := base - Vector2(0, height * stretch.y)
	if active and hop_t < 0.0:
		# 내 차례 표시: 머리 위에서 통통 튀는 금색 화살표
		var tip := head - Vector2(0, cell * 0.06 + absf(sin(_anim_time * 5.0)) * cell * 0.1)
		var arrow := PackedVector2Array([tip, tip + Vector2(-cell * 0.14, -cell * 0.2), tip + Vector2(cell * 0.14, -cell * 0.2)])
		draw_colored_polygon(arrow, Color("ffcf4d"))
		arrow.append(arrow[0])
		draw_polyline(arrow, Color("4a2600"), 3.0)
	var left := _steps_left(player_index)
	if left > 0 and not flinging:
		var bubble_center := head - Vector2(0, cell * 0.22)
		draw_circle(bubble_center, cell * 0.21, Color("4a2600"))
		draw_circle(bubble_center, cell * 0.18, Color("ffcf4d"))
		var count_size := int(cell * 0.28)
		draw_string(font, bubble_center + Vector2(-cell * 0.2, count_size * 0.36), str(left),
			HORIZONTAL_ALIGNMENT_CENTER, cell * 0.4, count_size, Color("4a2600"))


## 작은 다섯 꼭지 별.
func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for corner in 10:
		var angle := TAU * corner / 10.0 - PI / 2.0
		points.append(center + Vector2(cos(angle), sin(angle)) * (radius if corner % 2 == 0 else radius * 0.45))
	draw_colored_polygon(points, color)


## 둥근 메달: 짙은 테 → 색 테 → 동그랗게 자른 그림.
func _draw_medal(face: Texture2D, center: Vector2, radius: float, rim: Color) -> void:
	draw_circle(center + Vector2(0, radius * 0.16), radius + 4.0, Color(0, 0, 0, 0.35))
	draw_circle(center, radius + 5.0, rim.darkened(0.55))
	draw_circle(center, radius + 3.0, rim)
	var size_px := face.get_size()
	var side: float = min(size_px.x, size_px.y) * 0.8
	var src := Rect2((size_px.x - side) / 2.0, size_px.y * 0.04, side, side)
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for corner in 28:
		var a := TAU * corner / 28.0
		var unit := Vector2(cos(a), sin(a))
		points.append(center + unit * radius)
		uvs.append((src.position + (unit * 0.5 + Vector2(0.5, 0.5)) * src.size) / size_px)
	draw_colored_polygon(points, Color.WHITE, uvs, face)


func top_center(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point in points:
		sum += point
	return sum / float(points.size())


func _center(id: int, layout: Dictionary) -> Vector2:
	var node: Dictionary = game.nodes[id]
	var cell: float = layout["cell"]
	return layout["origin"] + Vector2(int(node.get("x", 0)) + 0.5, (int(node.get("y", 0)) + 0.5) * TILT) * cell


func _draw() -> void:
	if game == null or game.nodes.is_empty():
		return
	var font := get_theme_default_font()
	var layout := _layout()
	var cell: float = layout["cell"]
	var small: int = int(clamp(cell * 0.18, 9.0, 20.0))

	# 맵마다 다른 바탕: 지형 그림이 있으면 이어 붙여 깔고, 없으면 바탕색.
	var theme: Dictionary = game.board_theme
	_load_terrain(str(theme.get("terrain", "")))
	if theme.has("bg"):
		draw_rect(Rect2(Vector2.ZERO, size), Color(str(theme["bg"])))
	var origin: Vector2 = layout["origin"]
	if _ground != null:
		# 그림 한 장이 칸 8개 너비를 덮도록 이어 붙인다(그림은 이어 붙여도 티가 안 나게 만들어져 있다).
		var ground_scale := cell * 8.0 / float(_ground.get_width())
		draw_texture_rect_region(_ground, Rect2(Vector2.ZERO, size), Rect2(-origin / ground_scale, size / ground_scale))
	elif _terrain != null:
		var scale_px := cell / 21.0 if not bool(layout.get("camera", false)) else TERRAIN_SCALE
		draw_texture_rect_region(_terrain, Rect2(Vector2.ZERO, size), Rect2(-origin / scale_px, size / scale_px))
		_draw_decorations(layout)
	# 칸 사이 연결선은 흙길처럼: 어두운 테 위에 밝은 길
	var road := Color(str(theme.get("line", "ffffff")))
	for pass_index in 2:
		var road_color := Color(0, 0, 0, 0.28) if pass_index == 0 else Color(road.r, road.g, road.b, 0.55)
		var road_width: float = cell * (0.30 if pass_index == 0 else 0.20)
		for id in game.nodes:
			for next_id in game.nodes[id]["next"]:
				if game.nodes.has(next_id):
					draw_line(_center(id, layout), _center(next_id, layout), road_color, road_width)

	_draw_props(layout)
	var view := Rect2(Vector2(-cell, -cell), size + Vector2(cell, cell) * 2.0)
	if _draw_order_for != game.get_instance_id() or _draw_order.size() != game.nodes.size():
		_draw_order = game.nodes.keys()
		_draw_order.sort_custom(func(a, b): return int(game.nodes[a].get("y", 0)) < int(game.nodes[b].get("y", 0)))
		_draw_order_for = game.get_instance_id()
	for id in _draw_order:
		var tile: Dictionary = game.nodes[id]
		var half := Vector2(cell - TILE_GAP, cell - TILE_GAP) / 2.0
		var rect := Rect2(_center(id, layout) - half, half * 2.0)
		if not view.intersects(rect):
			continue
		var color: Color = TILE_COLORS.get(tile["type"], Color("3a4466"))
		var label: String = TILE_LABELS.get(tile["type"], "")
		var icon_name: String = ICON_NAMES.get(tile["type"], "")
		if tile["type"] == "attr":
			color = ATTR_COLORS.get(tile["attr"], color)
			label = tile["attr"]
			icon_name = ATTR_ICONS.get(tile["attr"], "")
		if game.is_hidden(id):
			color = HIDDEN_COLOR
			label = ""
			icon_name = "hidden"
		_draw_hex(rect.get_center(), half, cell, color, id in highlight)
		var monster := -1
		if not game.is_hidden(id) and tile.get("type", "") in ["battle", "ambush", "gate", "goal"]:
			monster = monster_kind(str(tile.get("type", "")), str(tile.get("name", "")))
		if tile.get("type", "") == "gate" and not game.is_hidden(id):
			# 관문: 돌기둥 두 개와 가로대. 내가(0번) 이미 뚫었으면 초록 가로대에 '통과', 적은 사라진다.
			var passed: bool = game.gates_cleared[0].has(id)
			var width := rect.size.x
			var foot := rect.position.y + rect.size.y * 0.5
			var pillar := Vector2(width * 0.15, width * 0.95)
			for side in [-1.0, 1.0]:
				var left: float = rect.get_center().x + side * width * 0.47 - pillar.x / 2.0
				draw_rect(Rect2(left, foot - pillar.y, pillar.x, pillar.y), Color("9aa6b2"))
				draw_rect(Rect2(left, foot - pillar.y, pillar.x, pillar.y), Color("3f4852"), false, 2.0)
				draw_rect(Rect2(left - width * 0.03, foot - pillar.y - width * 0.07, pillar.x + width * 0.06, width * 0.09), Color("3f4852"))
			draw_rect(Rect2(rect.get_center().x - width * 0.5, foot - pillar.y + width * 0.02, width, width * 0.11),
				Color("2fb457") if passed else Color("c2272f"))
			if passed:
				monster = -1
				label = "통과"
		var enemy_face: Texture2D = GameData.enemy_portrait(str(tile.get("name", ""))) if monster >= 0 else null
		var enemy_model: Texture2D = GameData.enemy_standee(str(tile.get("name", ""))) if monster >= 0 else null
		if enemy_model != null:
			# 적의 입체 모형이 있으면 칸 위에 세운다(숨 쉬듯 살짝 늘었다 줄었다).
			var is_boss: bool = tile.get("type", "") in ["goal", "gate"]
			var breath := 1.0 + 0.03 * sin(_anim_time * 2.6 + float(int(id) % 5))
			var model_tall := cell * (1.2 if is_boss else 0.98) * breath
			var model_wide := cell * (1.2 if is_boss else 0.98) * float(enemy_model.get_width()) / float(enemy_model.get_height())
			var model_foot := rect.get_center() + Vector2(0, cell * 0.06)
			draw_set_transform(model_foot, 0.0, Vector2(1.0, 0.36))
			draw_circle(Vector2.ZERO, model_wide * 0.4, Color(0, 0, 0, 0.3))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_texture_rect(enemy_model, Rect2(model_foot.x - model_wide / 2.0, model_foot.y - model_tall, model_wide, model_tall), false)
		elif enemy_face != null:
			# 그려 둔 적 초상화가 있으면 둥근 메달로 칸 위에 세운다.
			var big: bool = tile.get("type", "") in ["goal", "gate"]
			var medal_radius := cell * (0.36 if big else 0.3)
			var medal_center := rect.get_center() - Vector2(0, cell * (0.3 if big else 0.22))
			_draw_medal(enemy_face, medal_center, medal_radius, Color("ffcf4d") if tile.get("type", "") == "goal" else Color("c2272f"))
		elif monster >= 0 and _monsters != null:
			# 키퍼·습격·골 칸에는 아이콘 대신 적이 서 있다(살짝 위로 올려 서 있는 느낌).
			var stand := rect.size.x * (0.86 if tile.get("type", "") in ["goal", "gate"] else 0.7)
			var stand_rect := Rect2(rect.get_center().x - stand / 2.0, rect.position.y + rect.size.y * 0.5 - stand * 0.92, stand, stand)
			draw_texture_rect_region(_monsters, stand_rect, Rect2(monster * 32, 0, 32, 32))
		elif _icons.has(icon_name):
			var icon_size := rect.size.x * 0.62
			# 아이콘은 칸마다 다른 박자로 살짝 둥실거린다.
			var bob := sin(_anim_time * 2.4 + float(int(id) % 7) * 0.9) * cell * 0.035
			var icon_rect := Rect2(rect.position + Vector2((rect.size.x - icon_size) / 2.0, rect.size.y * -0.06 + bob),
				Vector2(icon_size, icon_size))
			draw_texture_rect(_icons[icon_name], icon_rect, false)
		if not game.is_hidden(id):
			_draw_tile_fx(str(tile.get("type", "")), rect.get_center(), cell, int(id))
		if label != "":
			draw_string_outline(font, rect.position + Vector2(0, rect.size.y * 0.74), label,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, small, 5, Color(0, 0, 0, 0.8))
			draw_string(font, rect.position + Vector2(0, rect.size.y * 0.74), label,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, small, Color.WHITE)

	# 골 칸은 반짝이는 테와 수호자 이름으로 눈에 띄게
	for id in game.nodes:
		if game.nodes[id].get("type", "") != "goal":
			continue
		var goal_center := _center(id, layout)
		if not view.has_point(goal_center):
			continue
		var pulse := 0.5 + 0.5 * sin(_anim_time * 3.0)
		draw_set_transform(goal_center - Vector2(0, cell * BLOCK_DEPTH * 0.5), 0.0, Vector2(1.0, TILT))
		draw_arc(Vector2.ZERO, cell * (0.56 + pulse * 0.06), 0.0, TAU, 40, Color(1.0, 0.85, 0.3, 0.9 - pulse * 0.4), 5.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var boss := "수호자 %s" % str(game.nodes[id].get("name", ""))
		var boss_size := int(cell * 0.2)
		var boss_pos := goal_center + Vector2(-cell * 1.5, -cell * 0.62)
		draw_string_outline(font, boss_pos, boss, HORIZONTAL_ALIGNMENT_CENTER, cell * 3.0, boss_size, 6, Color.BLACK)
		draw_string(font, boss_pos, boss, HORIZONTAL_ALIGNMENT_CENTER, cell * 3.0, boss_size, Color("ffcf4d"))
	# 내려앉은 칸에서 퍼지는 고리
	for ring in _rings:
		if not game.nodes.has(int(ring["id"])):
			continue
		var ring_t := float(ring["t"])
		var ring_color: Color = ring["color"]
		ring_color.a = 1.0 - ring_t
		draw_set_transform(_center(int(ring["id"]), layout) - Vector2(0, cell * BLOCK_DEPTH * 0.5), 0.0, Vector2(1.0, TILT))
		draw_arc(Vector2.ZERO, cell * (0.35 + ring_t * 0.55), 0.0, TAU, 36, ring_color, 6.0 * (1.0 - ring_t) + 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 착지 먼지와 날아가 떨어진 자리의 별
	for puff in _puffs:
		if not game.nodes.has(int(puff["id"])):
			continue
		var puff_t := float(puff["t"])
		var puff_center := _center(int(puff["id"]), layout) + Vector2(0, cell * 0.08)
		if str(puff["kind"]) == "stars":
			for index in 5:
				var angle := TAU * index / 5.0 + puff_t * 5.0
				var spot := puff_center + Vector2(cos(angle) * cell * 0.42, sin(angle) * cell * 0.16 - cell * 0.75)
				_draw_star(spot, cell * 0.11 * (1.0 - puff_t * 0.4), Color(1.0, 0.86, 0.25, 1.0 - puff_t))
		else:
			for index in 4:
				var side := -1.0 if index % 2 == 0 else 1.0
				var spread := cell * (0.14 + 0.1 * floorf(index / 2.0)) + cell * 0.3 * puff_t
				draw_circle(puff_center + Vector2(side * spread, -cell * 0.08 * puff_t * (1.0 + floorf(index / 2.0))), cell * 0.09 * (1.0 - puff_t * 0.5),
					Color(1, 1, 1, 0.55 * (1.0 - puff_t)))

	# 말. 같은 칸에 있으면 좌우로 나눠 그린다.
	for player_index in shown_pos.size():
		var id := int(shown_pos[player_index])
		if not game.nodes.has(id):
			continue
		var center := _center(id, layout)
		var lift := 0.0
		var hop_t := -1.0
		var flinging := false
		if _hops.has(player_index) and game.nodes.has(int(_hops[player_index]["from"])):
			# 앞 칸에서 이 칸으로 포물선을 그리며 뛴다. 져서 돌아갈 때는 높이 날아간다.
			var t := clampf(float(_hops[player_index]["t"]), 0.0, 1.0)
			hop_t = t
			flinging = bool(_hops[player_index].get("fling", false))
			center = _center(int(_hops[player_index]["from"]), layout).lerp(center, t)
			lift = sin(t * PI) * cell * (2.4 if flinging else HOP_HEIGHT)
		center.x += (player_index * 2 - 1) * cell * 0.22
		center.y += cell * 0.06
		var pawn_size := cell * 0.62
		var pawn_rect := Rect2(center - Vector2(pawn_size, pawn_size) / 2.0, Vector2(pawn_size, pawn_size))
		var standee: Texture2D = piece_standees[player_index] if player_index < piece_standees.size() else null
		if standee != null:
			_draw_standee(standee, player_index, center, lift, cell, hop_t, flinging, font)
			continue
		var face: Texture2D = piece_textures[player_index] if player_index < piece_textures.size() else null
		if face != null:
			var piece := cell * 0.7
			var bob := 0.0
			if player_index == active_player and _queue.is_empty():
				bob = -abs(sin(_anim_time * 4.0)) * cell * 0.08
			var player_color: Color = PLAYER_COLORS[player_index]
			var radius := cell * 0.34
			var foot := center + Vector2(0, cell * 0.16)
			var head := foot + Vector2(0, bob - lift - cell * 0.52)
			var piece_rect := Rect2(head - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
			# 그림자(높이 뛸수록 작고 옅게)
			var shade := 1.0 - lift / (cell * HOP_HEIGHT) * 0.45 if lift > 0.0 else 1.0
			draw_set_transform(foot, 0.0, Vector2(1.0, 0.42))
			draw_circle(Vector2.ZERO, cell * 0.27 * shade, Color(0, 0, 0, 0.38 * shade))
			draw_set_transform(Vector2(foot.x, foot.y + bob - lift), 0.0, Vector2(1.0, 0.42))
			# 받침대
			draw_circle(Vector2(0, cell * 0.05), cell * 0.2, player_color.darkened(0.45))
			draw_circle(Vector2.ZERO, cell * 0.2, player_color)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# 받침대와 초상화를 잇는 목
			var base_top := Vector2(foot.x, foot.y + bob - lift)
			draw_colored_polygon(PackedVector2Array([base_top + Vector2(-cell * 0.1, 0), base_top + Vector2(cell * 0.1, 0),
				head + Vector2(cell * 0.14, radius * 0.6), head + Vector2(-cell * 0.14, radius * 0.6)]), player_color.darkened(0.2))
			# 둥근 초상화: 색 테 → 그림 → 흰 테(내 차례일 때)
			draw_circle(head, radius + 5.0, player_color.darkened(0.45))
			draw_circle(head, radius + 3.0, Color.WHITE if player_index == active_player else player_color)
			var size_px := face.get_size()
			var side: float = min(size_px.x, size_px.y) * 0.78
			var src := Rect2((size_px.x - side) / 2.0, 0.0, side, side)
			var ring_points := PackedVector2Array()
			var ring_uvs := PackedVector2Array()
			for corner in 28:
				var a := TAU * corner / 28.0
				var unit := Vector2(cos(a), sin(a))
				ring_points.append(head + unit * radius)
				ring_uvs.append((src.position + (unit * 0.5 + Vector2(0.5, 0.5)) * src.size) / size_px)
			draw_colored_polygon(ring_points, Color.WHITE, ring_uvs, face)
			# 이동 중이면 남은 칸 수를 말 위에 보여 준다.
			var left := _steps_left(player_index)
			if left > 0:
				var bubble_center := Vector2(piece_rect.get_center().x, piece_rect.position.y - cell * 0.2)
				draw_circle(bubble_center, cell * 0.19, Color("ffcf4d"))
				draw_arc(bubble_center, cell * 0.19, 0.0, TAU, 24, Color("4a2600"), 2.5)
				var count_size := int(cell * 0.26)
				draw_string(font, bubble_center + Vector2(-cell * 0.19, count_size * 0.36), str(left),
					HORIZONTAL_ALIGNMENT_CENTER, cell * 0.38, count_size, Color("4a2600"))
			continue
		if _icons.has("pawn"):
			draw_texture_rect(_icons["pawn"], pawn_rect, false, PLAYER_COLORS[player_index])
		else:
			draw_circle(center, cell * 0.14, PLAYER_COLORS[player_index])
	if bool(layout.get("camera", false)):
		_draw_minimap(layout)


## 오른쪽 위의 작은 전체 지도: 칸은 점, 말은 색 점, 지금 보이는 곳은 흰 네모.
func _draw_minimap(layout: Dictionary) -> void:
	var grid := _grid_size()
	# 아주 긴 맵(직선형)은 작은 지도를 가로로 더 길게 쓴다.
	var dot: float = min(MINIMAP_WIDTH * 2.6 / grid.x, MINIMAP_WIDTH / grid.y)
	var map_size := Vector2(grid.x, grid.y) * dot
	var corner := Vector2(size.x - map_size.x - 10.0, 10.0)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0, 0, 0, 0.45)
	panel.set_corner_radius_all(8)
	draw_style_box(panel, Rect2(corner - Vector2(6, 6), map_size + Vector2(12, 12)))
	for id in game.nodes:
		var tile: Dictionary = game.nodes[id]
		var color: Color = TILE_COLORS.get(tile["type"], Color("3a4466"))
		if tile["type"] == "attr":
			color = ATTR_COLORS.get(tile["attr"], color)
		if game.is_hidden(id):
			color = HIDDEN_COLOR
		var spot := corner + Vector2(int(tile.get("x", 0)), int(tile.get("y", 0))) * dot
		color.a = 0.7
		var dot_size: float = max(dot - 1.0, 2.5)
		color.a = 0.9
		draw_rect(Rect2(spot, Vector2(dot_size, dot_size)), color)
	for player_index in shown_pos.size():
		var id := int(shown_pos[player_index])
		if game.nodes.has(id):
			var node: Dictionary = game.nodes[id]
			var center := corner + (Vector2(int(node.get("x", 0)), int(node.get("y", 0))) + Vector2(0.5, 0.5)) * dot
			draw_circle(center, max(3.0, dot * 0.45), PLAYER_COLORS[player_index])
			draw_arc(center, max(3.0, dot * 0.45), 0.0, TAU, 12, Color.BLACK, 1.0)
	var cell: float = layout["cell"]
	var view_origin: Vector2 = layout["origin"]
	var shown := Rect2(Vector2(-view_origin.x / cell, -view_origin.y / (cell * TILT)) * dot, Vector2(size.x / cell, size.y / (cell * TILT)) * dot)
	shown.position += corner
	draw_rect(shown.intersection(Rect2(corner, map_size)), Color.WHITE, false, 1.5)
