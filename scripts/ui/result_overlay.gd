extends Control
## 한 판이 끝났을 때 보여 주는 결과 화면(UI 개편 2단계, docs/UI개편기획.md 4장 '대전 결과').
## 왼쪽 40%: VICTORY/DEFEAT 로고 → 한 줄 설명 → MVP 금테 카드(초상화, 이름, 자리) → 두 파티 이름.
## 오른쪽 60%: 결과 줄(아이콘 + 이름 + 값) → 알림 띠(레벨 업·미션 완료 등) → 얻은 보상 칸 → 로비로 · 다시 하기.

signal retry_pressed
## 왼쪽 버튼(로비로)
signal change_party_pressed
## 보상형 광고 버튼(골드 2배, 2026-11-19)
signal ad_pressed

const Kit := preload("res://scripts/ui/kit.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const Confetti := preload("res://scripts/ui/confetti.gd")
const ArtView := preload("res://scripts/ui/art_view.gd")
const GameData := preload("res://scripts/game_data.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")

const GOLD := Color("ffcf4d")
const WIN_COLOR := Color("7ee081")
const LOSE_COLOR := Color("ff6b6b")
## MVP 카드 틀(mvp_frame) 안쪽 그림 자리(그림에서 잰 비율: 왼, 위, 오른, 아래)
const MVP_HOLE := [0.17, 0.205, 0.83, 0.84]

var _title: Label
var _subtitle: Label
var _panel: PanelContainer
var _confetti: Control
var _ad: Button
var _again: Button
var _mvp_box: Control
var _mvp_face: Control
var _mvp_name: Label
var _mvp_note: Label
var _parties: VBoxContainer
var _rows: VBoxContainer
var _notes: HFlowContainer
var _reward_title: Label
var _rewards: HBoxContainer
## 승리·패배 그림(assets/art/ui/victory.jpg, defeat.jpg)
var _logo: TextureRect = null
var _banner: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.1, 0.28, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_confetti = Confetti.new()
	add_child(_confetti)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(1160, 0)
	var frame = Kit.plate(Color("2a2f9c"), Kit.TRIM, 28.0, 22)
	frame.grand = true
	if Kit.UiSkin.has("win_navy"):
		frame.set_content_margin_all(26)
		frame.content_margin_top = 34
	_panel.add_theme_stylebox_override("panel", frame)
	center.add_child(_panel)

	var halves := HBoxContainer.new()
	halves.add_theme_constant_override("separation", 22)
	_panel.add_child(halves)

	# ---------------- 왼쪽: 로고 · 설명 · MVP 카드 · 파티
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.68
	halves.add_child(left)
	_banner = ArtView.new()
	_banner.custom_minimum_size = Vector2(0, 96)
	_banner.focus_y = 0.45
	_banner.fade_bottom = 0.35
	_banner.visible = false
	left.add_child(_banner)
	_title = _label(54)
	_title.add_theme_constant_override("outline_size", 12)
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	left.add_child(_title)
	_subtitle = _label(19)
	_subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_subtitle.add_theme_constant_override("outline_size", 4)
	_subtitle.add_theme_color_override("font_outline_color", Color(0, 0.04, 0.18))
	left.add_child(_subtitle)

	_mvp_box = VBoxContainer.new()
	_mvp_box.add_theme_constant_override("separation", 0)
	left.add_child(_mvp_box)
	var card := Control.new()
	card.custom_minimum_size = Vector2(156, 196)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mvp_box.add_child(card)
	_mvp_face = Portrait.new()
	_mvp_face.border_width = 0.0
	var frame_tex := MenuArt.tex("mvp_frame")
	if frame_tex != null:
		_mvp_face.anchor_left = MVP_HOLE[0]
		_mvp_face.anchor_top = MVP_HOLE[1]
		_mvp_face.anchor_right = MVP_HOLE[2]
		_mvp_face.anchor_bottom = MVP_HOLE[3]
		card.add_child(_mvp_face)
		var picture := TextureRect.new()
		picture.texture = frame_tex
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(picture)
	else:
		_mvp_face.border = GOLD
		_mvp_face.border_width = 4.0
		_mvp_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.add_child(_mvp_face)
	# 카드 아래 가운데: MVP 띠 + 이름 + 자리
	var ribbon := Kit.label(" MVP ", 20, Color("3a2408"), HORIZONTAL_ALIGNMENT_CENTER)
	ribbon.add_theme_stylebox_override("normal", Kit.box(GOLD, Color("7a4a12"), 3, 10, 4))
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_mvp_box.add_child(ribbon)
	_mvp_name = Kit.label("", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	TextStyle.menu(_mvp_name, Color(0, 0.04, 0.2), 7)
	_mvp_box.add_child(_mvp_name)
	_mvp_note = Kit.label("", 18, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	_mvp_box.add_child(_mvp_note)

	_parties = VBoxContainer.new()
	_parties.add_theme_constant_override("separation", 2)
	left.add_child(_parties)

	# ---------------- 오른쪽: 결과 줄 · 알림 띠 · 얻은 보상 · 버튼
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	halves.add_child(right)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	right.add_child(_rows)
	_notes = HFlowContainer.new()
	_notes.add_theme_constant_override("h_separation", 8)
	_notes.add_theme_constant_override("v_separation", 6)
	right.add_child(_notes)
	# 얻은 보상: 왼쪽에 제목, 오른쪽에 금테 칸들
	var reward_line := HBoxContainer.new()
	reward_line.add_theme_constant_override("separation", 12)
	right.add_child(reward_line)
	_reward_title = Kit.label("얻은\n보상", 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	TextStyle.gold(_reward_title, 6)
	_reward_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reward_title.size_flags_vertical = Control.SIZE_FILL
	reward_line.add_child(_reward_title)
	_rewards = HBoxContainer.new()
	_rewards.add_theme_constant_override("separation", 10)
	reward_line.add_child(_rewards)
	right.add_child(Kit.spacer())

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	right.add_child(buttons)
	var change := MenuArt.pill_button("로비로", "blue", "l")
	change.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	change.pressed.connect(_on_change_pressed)
	buttons.add_child(change)
	_ad = MenuArt.pill_button("", "purple", "l")
	_ad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ad.size_flags_stretch_ratio = 1.4
	_ad.visible = false
	_ad.pressed.connect(func() -> void: ad_pressed.emit())
	buttons.add_child(_ad)
	var again := MenuArt.pill_button("다시 하기", "gold", "l")
	_again = again
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.size_flags_stretch_ratio = 1.5
	again.pressed.connect(_on_again_pressed)
	buttons.add_child(again)


## 광고를 보고 보상을 받은 뒤 버튼을 끈다.
func ad_done(text: String) -> void:
	_ad.text = text
	_ad.disabled = true


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label


## 결과를 보여 준다. outcome은 "win", "lose", "draw".
## details: 결과 줄을 따로 주지 않았을 때 대신 보여 줄 글 줄.
## extras(없어도 됨):
##   "rows": [[아이콘, 이름, 값], ...]  결과 줄
##   "notes": [글, ...]  결과 줄 아래 작은 알림 띠(레벨 업·미션 완료 등)
##   "parties": [글, ...]  왼쪽 아래 파티 이름 줄
##   "rewards": [[아이콘, 글], ...]  얻은 보상 칸
##   "mvp": 캐릭터, "mvp_note": "ATTACK · 전투 3승", "again_text": 오른쪽 버튼 글
func show_result(outcome: String, subtitle: String, details: PackedStringArray, extras: Dictionary = {}) -> void:
	_again.text = str(extras.get("again_text", "다시 하기"))
	_ad.text = str(extras.get("ad_text", ""))
	_ad.visible = _ad.text != ""
	_ad.disabled = false
	var mvp: Dictionary = extras.get("mvp", {})
	_mvp_box.visible = not mvp.is_empty()
	if not mvp.is_empty():
		_mvp_face.show_character(mvp, Color("8fd0ff"))
		_mvp_name.text = str(mvp.get("name", ""))
		_mvp_note.text = str(extras.get("mvp_note", ""))
	_fill_rows(extras.get("rows", []), details)
	_fill_notes(extras.get("notes", []))
	for child in _parties.get_children():
		child.queue_free()
	for line in extras.get("parties", []):
		var party_label: Label = Kit.para(str(line), 18, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
		_parties.add_child(party_label)
	for child in _rewards.get_children():
		child.queue_free()
	var rewards: Array = extras.get("rewards", [])
	for entry in rewards:
		_rewards.add_child(MenuArt.reward_cell(str(entry[0]), str(entry[1]), 86.0))
	_rewards.visible = not rewards.is_empty()
	_reward_title.visible = not rewards.is_empty()
	if outcome == "win":
		_confetti.start()
	else:
		_confetti.stop()
	_banner.show_art("ui/defeat" if outcome == "lose" else "ui/victory")
	_banner.visible = _banner.has_art()
	# 배너 위에 입체 로고(VICTORY·DEFEAT·DRAW)를 얹는다.
	var logo_name := "victory" if outcome == "win" else ("defeat" if outcome == "lose" else "draw")
	var logo_texture: Texture2D = GameData.logo(logo_name)
	if _logo == null:
		_logo = TextureRect.new()
		_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_logo.offset_top = 8
		_logo.offset_bottom = -8
		_banner.add_child(_logo)
	_logo.texture = logo_texture
	if logo_texture != null and _banner.visible:
		_logo.pivot_offset = _logo.size * 0.5
		_logo.scale = Vector2(0.3, 0.3)
		_logo.create_tween().tween_property(_logo, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	match outcome:
		"win":
			_title.text = "승리!"
			_title.add_theme_color_override("font_color", WIN_COLOR)
		"lose":
			_title.text = "패배"
			_title.add_theme_color_override("font_color", LOSE_COLOR)
		_:
			_title.text = "무승부"
			_title.add_theme_color_override("font_color", GOLD)
	# 로고 그림이 있으면 큰 글자 제목은 숨긴다(같은 말을 두 번 하지 않게). 친구 대전처럼 설명이 이긴 사람을 알려 준다.
	_title.visible = not (_banner.visible and logo_texture != null)
	_subtitle.text = subtitle
	# 이미 떠 있으면(같은 판의 결과를 다시 채울 때) 튀어나오는 연출을 다시 하지 않는다.
	if visible and _panel.modulate.a > 0.0:
		return
	visible = true
	_panel.modulate.a = 0.0
	# 내용이 바뀌어 판 크기가 달라지므로 자리를 잡은 뒤(두 프레임) 가운데와 크기를 잰다.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_panel):
		return
	# 창 위·아래 장식(판 밖으로 약 54 튀어나옴)까지 화면 안에 들어오고 위아래 여백이 12 이상 남게 줄인다.
	var room: float = size.y - 2.0 * (54.0 + 12.0)
	var fit: float = minf(1.0, room / maxf(_panel.size.y, 1.0))
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.8, 0.8) * fit
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "scale", Vector2.ONE * fit, 0.35)
	tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.25)


## 결과 줄을 채운다. rows가 비면 details 글 줄을 "이름: 값" 모양으로 나눠 결과 줄로 보여 준다.
func _fill_rows(rows: Array, details: PackedStringArray) -> void:
	for child in _rows.get_children():
		child.queue_free()
	var list: Array = rows
	if list.is_empty():
		for line in details:
			var parts := str(line).split(": ", true, 1)
			if parts.size() == 2:
				list.append(["star", parts[0], parts[1]])
			else:
				list.append(["star", str(line), ""])
	for entry in list:
		_rows.add_child(MenuArt.result_row(str(entry[0]), str(entry[1]), str(entry[2]), 42.0))


## 알림 띠: 작은 어두운 캡슐에 글을 하나씩.
func _fill_notes(notes: Array) -> void:
	for child in _notes.get_children():
		child.queue_free()
	for line in notes:
		var band := PanelContainer.new()
		band.add_theme_stylebox_override("panel", Kit.box(Color(0.02, 0.08, 0.3, 0.85), Color("f2c14e"), 2, 14, 6))
		var label: Label = Kit.label(str(line), 17, Color("fff1c2"))
		band.add_child(label)
		_notes.add_child(band)
	_notes.visible = not notes.is_empty()


func _on_change_pressed() -> void:
	_confetti.stop()
	visible = false
	change_party_pressed.emit()


func _on_again_pressed() -> void:
	_confetti.stop()
	visible = false
	retry_pressed.emit()
