extends Label

const OrnateBox := preload("res://scripts/ui/ornate_box.gd")
## 잠깐 떴다 사라지는 알림 글자. 입력은 막지 않는다.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_font_size_override("font_size", 26)
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_constant_override("outline_size", 8)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	var style := OrnateBox.new()
	style.fill = Color(0.14, 0.12, 0.44, 0.96)
	style.radius = 24.0
	style.gems = false
	style.set_content_margin_all(14)
	add_theme_stylebox_override("normal", style)


func show_text(message: String) -> void:
	text = message
	anchor_left = 0.3
	anchor_right = 0.7
	anchor_top = 0.2
	anchor_bottom = 0.2
	offset_top = 0
	offset_bottom = 0
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
