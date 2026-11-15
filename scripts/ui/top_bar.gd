extends PanelContainer
## 화면 위의 프로필 띠: 대표 영웅 얼굴, 닉네임, 레벨과 경험치, 골드, 보석.
## app은 scripts/main.gd. refresh()로 다시 그린다.

const Kit := preload("res://scripts/ui/kit.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const Profile := preload("res://scripts/rules/profile.gd")

var app
var _avatar: Control
var _name: Label
var _level: Label
var _exp_bar: ProgressBar
var _gold: Label
var _gems: Label


func setup(main_app) -> void:
	app = main_app
	add_theme_stylebox_override("panel", Kit.box(Color("0f3d85"), Kit.LINE, 3, 26, 10))
	var row := Kit.hbox(12)
	add_child(row)
	_avatar = Portrait.new()
	_avatar.custom_minimum_size = Vector2(84, 84)
	_avatar.border_width = 3.0
	row.add_child(_avatar)
	var info := Kit.vbox(4)
	Kit.expand(info)
	row.add_child(info)
	_name = Kit.label("", 26)
	info.add_child(_name)
	var level_row := Kit.hbox(8)
	info.add_child(level_row)
	_level = Kit.label("", 20, Kit.GOLD)
	level_row.add_child(_level)
	_exp_bar = Kit.bar(0.0, Kit.GOLD, 14)
	_exp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Kit.expand(_exp_bar)
	level_row.add_child(_exp_bar)
	var money := Kit.vbox(4)
	row.add_child(money)
	_gold = _chip(Kit.GOLD)
	money.add_child(_gold)
	_gems = _chip(Kit.GEM)
	money.add_child(_gems)
	add_child(_clear_button(app.show_profile))
	refresh()


## 막대 전체를 덮는 투명 버튼. 누르면 프로필 창.
func _clear_button(callback: Callable) -> Button:
	var button := Button.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(callback)
	return button


func _chip(color: Color) -> Label:
	var chip := Kit.label("", 22, color, HORIZONTAL_ALIGNMENT_RIGHT)
	chip.custom_minimum_size = Vector2(170, 38)
	chip.add_theme_stylebox_override("normal", Kit.box(Color(0, 0.08, 0.25, 0.6), color, 2, 19, 6))
	return chip


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
	_gold.text = Kit.money_text("gold", int(profile["gold"]))
	_gems.text = Kit.money_text("gems", int(profile["gems"]))
