extends Control
## 처음 하는 사람 길잡이(2026-11-19). 지금 단계(data/guide.json tutorial)에 맞춰
## 화면의 버튼(노드 메타 "guide")을 반짝이는 고리와 통통 튀는 화살표로 가리키고, 길잡이 영웅의 말풍선을 띄운다.
## 화면 누르기는 막지 않는다(말풍선의 버튼만 받는다). 창이 떠 있거나 대전 중이면 숨는다.
## main.gd가 화면을 바꿀 때마다 refresh()를 부른다. 단계 바꾸기는 app.tutorial_event(일).

const Kit := preload("res://scripts/ui/kit.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const Profile := preload("res://scripts/rules/profile.gd")

var app
var _target_id := ""
var _target: Control
var _bubble: PanelContainer
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 지금 화면에 맞는 말풍선과 가리킬 곳을 다시 정한다.
func refresh() -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = null
	_target_id = ""
	_target = null
	visible = false
	if app == null or not app.has_profile():
		return
	var step: Dictionary = Profile.tutorial_step(app.profile, app.data.get("guide", {}))
	if step.is_empty():
		return
	var spec: Dictionary = step.get("screens", {}).get(str(app.current_name), {})
	if spec.is_empty():
		return
	_target_id = str(spec.get("target", ""))
	_bubble = _make_bubble(str(spec.get("text", "")), str(spec.get("action", "")))
	add_child(_bubble)
	visible = true


func _make_bubble(text: String, action: String) -> PanelContainer:
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", Kit.plate(Color("243a9c"), Kit.TRIM, 22.0, 14))
	bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	bubble.custom_minimum_size = Vector2(560, 0)
	var row := Kit.hbox(12)
	bubble.add_child(row)
	var face := Portrait.new()
	face.custom_minimum_size = Vector2(96, 96)
	var hero_id := str(app.data.get("guide", {}).get("tutorial", {}).get("guide_hero", "sejong"))
	face.show_character(app.character(hero_id), Kit.GOLD)
	face.border = Kit.GOLD
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(face)
	var column := Kit.vbox(8)
	row.add_child(Kit.expand(column))
	column.add_child(Kit.label("길잡이", 18, Kit.GOLD))
	var words := Kit.para(text, 20, Color.WHITE)
	words.custom_minimum_size = Vector2(420, 0)
	column.add_child(words)
	var buttons := Kit.hbox(8)
	column.add_child(buttons)
	if action != "":
		var go := MenuArt.pill_button(action, "gold", "m")
		go.pressed.connect(_on_action)
		buttons.add_child(Kit.expand(go))
	var skip := MenuArt.pill_button("길잡이 건너뛰기", "gray", "s")
	skip.custom_minimum_size = Vector2(170, 44)
	skip.pressed.connect(_on_skip)
	buttons.add_child(skip)
	return bubble


func _on_action() -> void:
	app.start_tutorial_match()


func _on_skip() -> void:
	app.play("click")
	Profile.skip_tutorial(app.profile)
	app.save()
	refresh()


## 가리킬 버튼을 지금 화면에서 찾는다(노드 메타 guide).
func _find(node: Node) -> Control:
	if node is Control and str(node.get_meta("guide", "")) == _target_id and (node as Control).is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := _find(child)
		if found != null:
			return found
	return null


func _process(delta: float) -> void:
	if _bubble == null or not is_instance_valid(_bubble):
		return
	# 창이 떠 있으면 숨는다(창이 닫히면 다시 보인다).
	var covered := not get_tree().get_nodes_in_group("modal").is_empty() or (app.loading != null and app.loading.visible)
	modulate.a = 0.0 if covered else 1.0
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE if covered else Control.MOUSE_FILTER_STOP
	_time += delta
	if _target == null or not is_instance_valid(_target) or not _target.is_visible_in_tree():
		_target = _find(app.current_screen) if app.current_screen != null and _target_id != "" else null
	# 말풍선은 가리키는 버튼과 겹치지 않게 위나 아래 귀퉁이에 둔다.
	var bubble_size := _bubble.get_combined_minimum_size()
	var place := Vector2(24, size.y - bubble_size.y - 24)
	var rect := _target_rect()
	if rect.size != Vector2.ZERO:
		var below := rect.position.y + rect.size.y * 0.5 > size.y * 0.55
		place.y = 24.0 + 70.0 if below else size.y - bubble_size.y - 24.0
		place.x = 24.0 if rect.position.x + rect.size.x * 0.5 > size.x * 0.5 else size.x - bubble_size.x - 24.0
	_bubble.position = place
	_bubble.size = bubble_size
	queue_redraw()


func _target_rect() -> Rect2:
	if _target == null or not is_instance_valid(_target):
		return Rect2()
	var top_left := Kit.spot_in(self, _target, Vector2.ZERO)
	var bottom_right := Kit.spot_in(self, _target, _target.size)
	return Rect2(top_left, bottom_right - top_left).abs()


func _draw() -> void:
	var rect := _target_rect()
	if rect.size == Vector2.ZERO:
		return
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	var grow := 6.0 + 6.0 * pulse
	var ring := rect.grow(grow)
	draw_rect(ring, Color(1.0, 0.85, 0.3, 0.35 + 0.4 * pulse), false, 6.0)
	draw_rect(rect.grow(grow + 6.0), Color(1.0, 0.95, 0.6, 0.18 * pulse), false, 4.0)
	# 위에서 아래로 통통 튀는 화살표(버튼 위쪽 가운데)
	var tip := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y - 8.0 - 10.0 * absf(sin(_time * 4.0)))
	if tip.y < 60.0:
		tip.y = rect.position.y + rect.size.y + 8.0 + 10.0 * absf(sin(_time * 4.0))
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-22, 34), tip + Vector2(22, 34)]), Kit.GOLD)
		draw_polyline(PackedVector2Array([tip, tip + Vector2(-22, 34), tip + Vector2(22, 34), tip]), Color("7a4a00"), 3.0)
	else:
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-22, -34), tip + Vector2(22, -34)]), Kit.GOLD)
		draw_polyline(PackedVector2Array([tip, tip + Vector2(-22, -34), tip + Vector2(22, -34), tip]), Color("7a4a00"), 3.0)
