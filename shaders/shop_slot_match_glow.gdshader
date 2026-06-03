shader_type canvas_item;

uniform bool glow_enabled = false;
uniform vec4 glow_color : source_color = vec4(1.0, 0.78, 0.18, 1.0);
uniform vec4 outer_glow_color : source_color = vec4(1.0, 0.45, 0.05, 0.85);
uniform float border_width : hint_range(0.001, 0.2) = 0.085;
uniform float outer_width : hint_range(0.001, 0.35) = 0.16;
uniform float glow_strength : hint_range(0.0, 3.0) = 1.65;
uniform float pulse_speed : hint_range(0.1, 8.0) = 3.2;

void fragment() {
	vec4 base_color = COLOR;
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float enabled = glow_enabled ? 1.0 : 0.0;
	float inner_mask = smoothstep(border_width, 0.0, edge_distance);
	float outer_mask = smoothstep(outer_width, border_width, edge_distance);
	float pulse = 0.72 + 0.28 * sin(TIME * pulse_speed);
	float inner_glow = inner_mask * pulse * glow_strength * enabled;
	float outer_glow = outer_mask * pulse * 0.85 * enabled;

	vec3 final_rgb = base_color.rgb;
	final_rgb = mix(final_rgb, outer_glow_color.rgb, clamp(outer_glow, 0.0, 0.85));
	final_rgb = mix(final_rgb, glow_color.rgb, clamp(inner_glow, 0.0, 1.0));
	float final_alpha = max(base_color.a, max(inner_mask * glow_color.a * 0.9, outer_mask * outer_glow_color.a * 0.38) * enabled);
	COLOR = vec4(final_rgb, final_alpha);
}
