extends RefCounted
## 별의 관측소 창에서 쓰는 그림과 보상 카드. 규칙과 저장은 호출 화면이 맡는다.

const Kit := preload("res://scripts/ui/kit.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const ArtView := preload("res://scripts/ui/art_view.gd")
const GameData := preload("res://scripts/game_data.gd")
const ATTEND_SKY := preload("res://assets/ui_observatory/attendance_sky.jpg")
const NOTICE_SKY := preload("res://assets/ui_observatory/notice_bg.jpg")


static func picture(texture: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


static func divider() -> Control:
	var view := Control.new()
	view.custom_minimum_size.y = 12
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.resized.connect(view.queue_redraw)
	view.draw.connect(func() -> void:
		var middle := view.size * 0.5
		view.draw_line(Vector2(0, middle.y), Vector2(view.size.x, middle.y), Color("8c779c"), 1.5, true)
		for band in [44.0, 24.0, 9.0]:
			view.draw_line(middle - Vector2(band, 0), middle + Vector2(band, 0), Color(1.0, 0.79, 0.52, 0.4), 3.0, true))
	return view


static func attendance(rewards: Array, today: int) -> Control:
	var body := Kit.vbox(11)
	var sky := ArtView.new()
	sky.texture = ATTEND_SKY
	sky.focus_y = 0.25
	sky.custom_minimum_size.y = 135
	body.add_child(sky)
	var days := Kit.hbox(8)
	body.add_child(days)
	for index in rewards.size():
		days.add_child(Kit.expand(_day(index, rewards[index], index == today, index < today)))
	body.add_child(divider())
	body.add_child(Kit.para("매일 접속하면 보상을 받아요. 7일마다 다시 시작합니다.", 17, Kit.Observatory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	return body


static func _day(index: int, reward: Dictionary, today: bool, done: bool) -> Control:
	var amber := Kit.Observatory.AMBER
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(85, 215)
	var frame := Kit.box(Color("352636") if today else Color("22243f"), amber if today else Kit.Observatory.EDGE,
		3 if today else 1, 14, 4)
	if today:
		frame.shadow_color = Color(1.0, 0.66, 0.35, 0.45)
		frame.shadow_size = 7
	tile.add_theme_stylebox_override("panel", frame)
	var column := Kit.vbox(4)
	tile.add_child(column)
	var title_band := PanelContainer.new()
	title_band.add_theme_stylebox_override("panel", Kit.box(Color("614439") if today else Color("37405d"), Color.TRANSPARENT, 0, 9, 5))
	title_band.add_child(Kit.label("%d일" % (index + 1), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(title_band)
	column.add_child(Kit.spacer())
	for key in ["gold", "gems"]:
		if not reward.has(key):
			continue
		var holder := Control.new()
		holder.custom_minimum_size.y = 62
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(holder)
		var icon := Kit.icon("gem" if key == "gems" else "gold", 56)
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon.offset_left = -28
		icon.offset_top = -28
		holder.add_child(icon)
		if done:
			icon.modulate = Color(0.65, 0.65, 0.73)
			var tick := Kit.icon("m_check", 28)
			tick.modulate = amber
			tick.anchor_left = 0.5
			tick.anchor_right = 0.5
			tick.offset_left = 11
			tick.offset_top = -3
			holder.add_child(tick)
		column.add_child(Kit.label(Kit.comma(int(reward[key])), 26, Kit.MUTED if done else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var other := reward.duplicate()
	other.erase("gold")
	other.erase("gems")
	if not other.is_empty():
		column.add_child(Kit.para(Kit.reward_line(other), 15, Kit.Observatory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(Kit.spacer())
	return tile


static func notice(entries: Array, hero_id: String) -> Control:
	var body := Kit.vbox(8)
	var banner := Control.new()
	banner.custom_minimum_size.y = 370
	banner.clip_contents = true
	body.add_child(banner)
	var art := ArtView.new()
	art.texture = NOTICE_SKY
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.add_child(art)
	var hero := picture(GameData.cutin_art(hero_id))
	hero.anchor_right = 0.53
	hero.anchor_bottom = 1.0
	banner.add_child(hero)
	var shade := PanelContainer.new()
	shade.add_theme_stylebox_override("panel", Kit.box(Color(0.09, 0.075, 0.18, 0.80), Kit.Observatory.EDGE, 1, 12, 14))
	shade.anchor_left = 0.49
	shade.anchor_right = 0.945
	shade.anchor_bottom = 0.97
	shade.offset_top = 11
	banner.add_child(shade)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shade.add_child(scroll)
	var content := Kit.vbox(8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(content)
	var dots := Kit.hbox(3)
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(dots)
	if entries.is_empty():
		content.add_child(Kit.para("표시할 공지가 없어요.", 22, Kit.Observatory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		return body
	var index := [0]
	var render := func(next: int) -> void:
		index[0] = posmod(next, entries.size())
		for child in content.get_children():
			content.remove_child(child)
			child.queue_free()
		var current: Dictionary = entries[index[0]]
		if current.has("date"):
			content.add_child(Kit.label(str(current["date"]), 17, Kit.Observatory.MUTED))
		content.add_child(Kit.para(str(current.get("title", current["text"])), 30, Kit.Observatory.AMBER))
		if current.has("title"):
			content.add_child(Kit.para(str(current["text"]), 21, Color.WHITE))
		if current.has("gold_scale"):
			var badge := MenuArt.capsule("×%s" % current["gold_scale"], "gold", 22)
			badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			content.add_child(badge)
		scroll.scroll_vertical = 0
		for dot in dots.get_children():
			dot.modulate = Kit.Observatory.AMBER if dot.get_index() == index[0] else Kit.Observatory.MUTED
	for n in entries.size():
		var dot := Button.new()
		dot.text = "●"
		dot.flat = true
		dot.custom_minimum_size = Vector2(24, 28)
		dot.pressed.connect(render.bind(n))
		dots.add_child(dot)
	for direction in [-1, 1]:
		var arrow := MenuArt.pill_button("‹" if direction < 0 else "›", "purple", "s")
		arrow.tooltip_text = "이전 공지" if direction < 0 else "다음 공지"
		var side := 0.0 if direction < 0 else 1.0
		arrow.anchor_left = side
		arrow.anchor_right = side
		arrow.anchor_top = 0.5
		arrow.anchor_bottom = 0.5
		arrow.offset_left = 4 if direction < 0 else -52
		arrow.offset_right = arrow.offset_left + 48
		arrow.offset_top = -23
		arrow.offset_bottom = 23
		arrow.pressed.connect(func() -> void: render.call(int(index[0]) + direction))
		banner.add_child(arrow)
	render.call(0)
	return body
