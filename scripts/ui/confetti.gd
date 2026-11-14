extends Control
## 승리했을 때 화면 위에서 떨어지는 색종이. 보여 주기만 하고 입력은 막지 않는다.

const COLORS := [Color("ffcf4d"), Color("ff6b6b"), Color("4fc3f7"), Color("7ee081"), Color("d08aff"), Color.WHITE]
const COUNT := 90

var _pieces: Array = []
var _rng := RandomNumberGenerator.new()
var _running := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func start() -> void:
	_rng.randomize()
	_pieces = []
	for index in COUNT:
		_pieces.append({
			"pos": Vector2(_rng.randf_range(0.0, max(size.x, 1.0)), _rng.randf_range(-size.y * 0.9, 0.0)),
			"speed": _rng.randf_range(220.0, 520.0),
			"sway": _rng.randf_range(0.0, TAU),
			"spin": _rng.randf_range(-6.0, 6.0),
			"angle": _rng.randf_range(0.0, TAU),
			"size": Vector2(_rng.randf_range(8.0, 16.0), _rng.randf_range(5.0, 10.0)),
			"color": COLORS[index % COLORS.size()],
		})
	_running = true


func stop() -> void:
	_running = false
	_pieces = []
	queue_redraw()


func _process(delta: float) -> void:
	if not _running:
		return
	for piece in _pieces:
		piece["sway"] = float(piece["sway"]) + delta * 3.0
		piece["angle"] = float(piece["angle"]) + float(piece["spin"]) * delta
		var pos: Vector2 = piece["pos"]
		pos.y += float(piece["speed"]) * delta
		pos.x += sin(float(piece["sway"])) * 60.0 * delta
		if pos.y > size.y + 20.0:
			pos = Vector2(_rng.randf_range(0.0, max(size.x, 1.0)), -20.0)
		piece["pos"] = pos
	queue_redraw()


func _draw() -> void:
	for piece in _pieces:
		var piece_size: Vector2 = piece["size"]
		draw_set_transform(piece["pos"], float(piece["angle"]), Vector2(1.0, absf(cos(float(piece["sway"]))) * 0.8 + 0.2))
		draw_rect(Rect2(-piece_size / 2.0, piece_size), piece["color"])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
