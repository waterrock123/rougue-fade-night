shader_type canvas_item;

uniform bool glow_enabled = false;
uniform vec4 glow_color : source_color = vec4(1.0, 0.78, 0.22, 1.0);
uniform float border_width : hint_range(0.001, 0.2) = 0.055;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.75;
uniform float pulse_speed : hint_range(0.1, 8.0) = 2.4;

void fragment() {
	vec4 base_color = COLOR;
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float border_mask = smoothstep(border_width, 0.0, edge_distance);
	float pulse = 0.55 + 0.45 * sin(TIME * pulse_speed);
	float enabled = glow_enabled ? 1.0 : 0.0;
	float glow = border_mask * pulse * glow_strength * enabled;

	vec3 final_rgb = mix(base_color.rgb, glow_color.rgb, clamp(glow, 0.0, 1.0));
	float final_alpha = max(base_color.a, border_mask * glow_color.a * 0.55 * enabled);
	COLOR = vec4(final_rgb, final_alpha);
}
