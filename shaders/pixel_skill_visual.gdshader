shader_type canvas_item;

uniform float brightness : hint_range(0.0, 2.0) = 1.25;
uniform float white_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 base = mix(tex.rgb, vec3(1.0), white_mix);
	COLOR = vec4(base * tint.rgb * brightness, tex.a * tint.a) * vertex_tint;
}
