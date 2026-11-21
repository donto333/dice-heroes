shader_type canvas_item;
render_mode unshaded;

uniform vec2 extent = vec2(1.0);
uniform float phase = -1.0;
uniform bool overlay = false;
varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float band = max(extent.y * 0.44, 18.0);
	float lean = extent.y * 0.55;
	float x = mix(-band * 1.6 - lean, extent.x + lean, clamp(phase, 0.0, 1.0));
	float u = (local_pos.x - x - (1.0 - local_pos.y / max(extent.y, 1.0)) * lean) / band;
	float wide = smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.78, 1.0, u));
	float thin = smoothstep(1.12, 1.17, u) * (1.0 - smoothstep(1.23, 1.30, u));
	float light = (wide + thin * 0.55) * sin(PI * clamp(phase, 0.0, 1.0)) * 0.42;
	if (overlay) {
		COLOR = vec4(vec3(1.0), COLOR.a * light);
	} else {
		COLOR.rgb = mix(COLOR.rgb, vec3(1.0), light);
	}
}
