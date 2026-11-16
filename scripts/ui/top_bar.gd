extends PanelContainer
## 화면 위의 프로필 띠: 대표 영웅 얼굴, 닉네임, 레벨과 경험치, 골드, 보석.
## app은 scripts/main.gd. refresh()로 다시 그린다.

const Kit := preload("res://scripts/ui/kit.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")

var app
var _avatar: Control
var _name: Label
var _level: Label
var _exp_bar: ProgressBar
var _gold: Label
var _gems: Label


func setup(main_app) -> void:
	app = main_app
	var frame := Kit.box(Color("0f3d85"), Kit.LINE, 3, 26, 10)
	frame.border_width_bottom = 5
	frame.shadow_color = Color(0, 0.05, 0.2, 0.4)
	frame.shadow_size = 6
	frame.shadow_offset = Vector2(0, 3)
	add_theme_stylebox_override("panel", Kit.plate(Color("17357f"), Kit.TRIM, 24.0, 10, false))
	var strip := MenuArt.style("top_strip", Vector4(26, 18, 26, 18), Vector4(14, 8, 14, 8))
	if strip != null:
		add_theme_stylebox_override("panel", strip)
	var row := Kit.hbox(12)
	add_child(row)
	# 그림 부품이 있으면 왼쪽에 지금 화면의 제목 명판(아이콘 + 이름).
	var title_spec: Array = MenuArt.TITLES.get(str(app.get("current_name")), [])
	if not title_spec.is_empty():
		var plate := MenuArt.title_plate(str(title_spec[0]), Kit.icon(str(title_spec[1]), 40.0).texture)
		if plate != null:
			plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(plate)
	_avatar = Portrait.new()
	_avatar.custom_minimum_size = Vector2(58, 58)
	_avatar.border_width = 4.0
	_avatar.border = Kit.GOLD
	row.add_child(_avatar)
	var info := Kit.vbox(0)
	Kit.expand(info)
	row.add_child(info)
	_name = Kit.label("", 22)
	info.add_child(_name)
	var level_row := Kit.hbox(8)
	info.add_child(level_row)
	_level = Kit.label("", 20, Kit.GOLD)
	level_row.add_child(_level)
	_exp_bar = Kit.bar(0.0, Kit.GOLD, 14)
	_exp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Kit.expand(_exp_bar)
	level_row.add_child(_exp_bar)
	var money := Kit.hbox(8)
	row.add_child(money)
	_gold = _chip(money, "gold", Kit.GOLD)
	_gems = _chip(money, "gem", Kit.GEM)
	add_child(_clear_button(app.show_profile))
	refresh()


## 막대 전체를 덮는 투명 버튼. 누르면 프로필 창.
func _clear_button(callback: Callable) -> Button:
	var button := Button.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(callback)
	return button


## 재화 칸: 왼쪽에 아이콘이 살짝 튀어나온 알약 모양, 오른쪽 정렬 숫자.
func _chip(parent: Control, icon_name: String, color: Color) -> Label:
	var capsule := PanelContainer.new()
	capsule.custom_minimum_size = Vector2(180, 40)
	var style := Kit.box(Color(0, 0.06, 0.22, 0.72), color.darkened(0.2), 2, 20, 4)
	style.content_margin_left = 6
	style.content_margin_right = 14
	capsule.add_theme_stylebox_override("panel", style)
	var art := MenuArt.style("currency", Vector4(24, 0, 24, 0), Vector4(8, 3, 16, 3))
	if art != null:
		capsule.custom_minimum_size = Vector2(180, 46)
		capsule.add_theme_stylebox_override("panel", art)
	var row := Kit.hbox(4)
	capsule.add_child(row)
	row.add_child(Kit.icon(icon_name, 34.0))
	var amount := Kit.label("", 23, color, HORIZONTAL_ALIGNMENT_RIGHT)
	Kit.expand(amount)
	row.add_child(amount)
	parent.add_child(capsule)
	return amount


func refresh() -> void:
	if app == null:
		return
	var profile: Dictionary = app.profile
	var leader_id := str(profile.get("avatar", ""))
	if leader_id == "" or not Profile.owns(profile, leader_id):
		leader_id = str(profile["party"].get("attack", ""))
	var leader: Dictionary = app.character(leader_id)
	_avatar.show_character(leader, Kit.CATEGORY_COLORS.get(leader.get("category", ""), Kit.LINE))
	_name.text = str(profile["nickname"])
	_level.text = "Lv.%d" % int(profile["level"])
	var need := Profile.exp_to_next(profile, app.eco)
	_exp_bar.value = float(profile["exp"]) / float(max(need, 1))
	_gold.text = Kit.comma(int(profile["gold"]))
	_gems.text = Kit.comma(int(profile["gems"]))
