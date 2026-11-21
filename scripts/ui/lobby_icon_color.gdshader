shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 icon = COLOR;
	float light = dot(icon.rgb, vec3(0.299, 0.587, 0.114));
	vec3 shade = tint.rgb * mix(0.17, 0.94, smoothstep(0.05, 0.83, light));
	vec3 highlight = mix(shade, vec3(1.0), smoothstep(0.80, 1.0, light) * 0.65);
	COLOR = vec4(highlight, icon.a);
}
