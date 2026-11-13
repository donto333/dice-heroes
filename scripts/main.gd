extends Control
## 1단계(뼈대) 확인용 화면.
## 프로젝트가 빌드되고, 한글 글꼴이 나오고, 데이터가 읽히고,
## 주사위가 굴러가는지만 보여 준다. 2단계에서 실제 보드 화면으로 바뀐다.

const GameData := preload("res://scripts/game_data.gd")

var _rng := RandomNumberGenerator.new()
var _dice_label: Label


func _ready() -> void:
	_rng.randomize()

	var background := ColorRect.new()
	background.color = Color("1b1f3b")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)

	var title := Label.new()
	title.text = "주사위 영웅전"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "1단계: 프로젝트 뼈대 확인 화면"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 26)
	column.add_child(subtitle)

	_dice_label = Label.new()
	_dice_label.text = "주사위를 굴려 보세요"
	_dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_label.add_theme_font_size_override("font_size", 40)
	column.add_child(_dice_label)

	var roll_button := Button.new()
	roll_button.text = "주사위 5개 굴리기"
	roll_button.custom_minimum_size = Vector2(0, 96)
	roll_button.add_theme_font_size_override("font_size", 32)
	roll_button.pressed.connect(_on_roll_pressed)
	column.add_child(roll_button)

	var characters := GameData.load_characters()
	var list_title := Label.new()
	list_title.text = "프로토타입 캐릭터 %d명" % characters.size()
	list_title.add_theme_font_size_override("font_size", 30)
	column.add_child(list_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for character in characters:
		var row := Label.new()
		row.text = "%s %s (%s)  이동 %d · 공격 %d · 방어 %d · 지력 %d" % [
			GameData.grade_stars(int(character["grade"])),
			character["name"],
			character["category"],
			int(character["move"]),
			int(character["attack"]),
			int(character["defense"]),
			int(character["intellect"]),
		]
		row.add_theme_font_size_override("font_size", 24)
		list.add_child(row)


func _on_roll_pressed() -> void:
	var rolls: Array[int] = []
	var total := 0
	for i in 5:
		var value := _rng.randi_range(1, 6)
		rolls.append(value)
		total += value
	_dice_label.text = "%s  →  합계 %d" % [str(rolls), total]
