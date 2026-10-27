shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(1.0, 0.08, 0.045, 0.9);
uniform float pulse_speed = 2.2;

void fragment() {
	float radius = length((UV - vec2(0.5)) * 2.0);
	float pulse = 0.88 + 0.12 * sin(TIME * pulse_speed);
	float core = 1.0 - smoothstep(0.02, 0.19, radius);
	float inner = 1.0 - smoothstep(0.08, 0.43, radius);
	float halo = 1.0 - smoothstep(0.20, 1.0, radius);
	float alpha = (core * 0.72 + inner * 0.28 + halo * 0.16) * glow_color.a * pulse;
	COLOR = vec4(glow_color.rgb, clamp(alpha, 0.0, 1.0));
}
