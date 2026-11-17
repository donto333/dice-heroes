class_name TextStyle
extends RefCounted
## 시안(ChatGPT '게임 UI 재디자인 요청' 메뉴 시안)의 글자 효과 세 가지.
## 글꼴 자체는 굵은 DiceHeroes Black(main.gd의 _setup_font)이고, 분위기는 여기 효과가 만든다.
## - gold: 판 안의 큰 제목. 위는 연노랑, 아래는 주황인 금색 그라데이션 + 짙은 갈색 외곽선 + 아래 그림자
## - menu: 메뉴·버튼 글자. 흰 글자 + 짙은 외곽선 + 아래 그림자
## - number: 재화·수치. 흰 글자 + 남색 외곽선 + 옅은 그림자

const GOLD_TOP := Color("fff6b0")
const GOLD_BOTTOM := Color("ffa412")
const GOLD_EDGE := Color("4a2200")
const NAVY_EDGE := Color(0.0, 0.05, 0.22)

static var _gold_shader: Shader = null


## 금색 그라데이션 제목. 글자 몸통(흰색으로 칠한 부분)만 그라데이션으로 바꾸고 외곽선은 그대로 둔다.
static func gold(label: Label, outline: int = 9) -> void:
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", GOLD_EDGE)
	_shadow(label, Color(0.12, 0.04, 0.0, 0.75), 3)
	var material := ShaderMaterial.new()
	material.shader = _gold()
	material.set_shader_parameter("top_color", GOLD_TOP)
	material.set_shader_parameter("bottom_color", GOLD_BOTTOM)
	label.material = material
	var fit := func() -> void:
		material.set_shader_parameter("span", Vector2(0.0, maxf(label.size.y, 1.0)))
	label.resized.connect(fit)
	fit.call()


## 메뉴·버튼 글자(Label·Button 모두).
static func menu(target: Control, edge: Color = NAVY_EDGE, outline: int = 7) -> void:
	target.add_theme_constant_override("outline_size", outline)
	target.add_theme_color_override("font_outline_color", edge)
	_shadow(target, Color(edge.r, edge.g, edge.b, 0.7), 3)


## 재화·수치 글자.
static func number(target: Control, outline: int = 5) -> void:
	target.add_theme_color_override("font_color", Color.WHITE)
	target.add_theme_constant_override("outline_size", outline)
	target.add_theme_color_override("font_outline_color", NAVY_EDGE)
	_shadow(target, Color(0, 0.03, 0.15, 0.55), 2)


static func _shadow(target: Control, color: Color, drop: int) -> void:
	target.add_theme_color_override("font_shadow_color", color)
	target.add_theme_constant_override("shadow_offset_x", 0)
	target.add_theme_constant_override("shadow_offset_y", drop)
	target.add_theme_constant_override("shadow_outline_size", 6)


static func _gold() -> Shader:
	if _gold_shader == null:
		_gold_shader = Shader.new()
		_gold_shader.code = """
shader_type canvas_item;
uniform vec4 top_color : source_color;
uniform vec4 bottom_color : source_color;
uniform vec2 span = vec2(0.0, 40.0);
varying float fill;
varying float height;
void vertex() {
	// 흰색으로 칠하는 글자 몸통만 고른다(외곽선·그림자는 어두운 색이라 빠진다).
	fill = step(0.92, min(COLOR.r, min(COLOR.g, COLOR.b)));
	height = clamp((VERTEX.y - span.x) / max(span.y - span.x, 1.0), 0.0, 1.0);
}
void fragment() {
	vec4 base = COLOR * texture(TEXTURE, UV);
	float t = smoothstep(0.2, 0.8, height);
	vec3 gold = mix(top_color.rgb, bottom_color.rgb, t);
	COLOR = vec4(mix(base.rgb, gold * base.rgb, fill), base.a);
}
"""
	return _gold_shader
