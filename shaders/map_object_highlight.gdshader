shader_type canvas_item;

uniform bool highlight_enabled = true;
uniform vec4 outline_color : source_color = vec4(1.0, 0.86, 0.22, 1.0);
uniform float outline_size : hint_range(0.0, 8.0) = 2.0;
uniform float outline_alpha : hint_range(0.0, 1.0) = 0.82;
uniform float inner_glow_strength : hint_range(0.0, 1.0) = 0.12;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.22;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.0;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.08;

void fragment() {
	vec4 base_color = texture(TEXTURE, UV) * COLOR;
	vec4 final_color = base_color;

	if (highlight_enabled && outline_size > 0.0) {
		vec2 offset = TEXTURE_PIXEL_SIZE * outline_size;
		float neighbor_alpha = 0.0;
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(offset.x, 0.0)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-offset.x, 0.0)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, offset.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, -offset.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(offset.x, offset.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-offset.x, offset.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(offset.x, -offset.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-offset.x, -offset.y)).a);

		float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_strength;
		float base_solid = step(alpha_threshold, base_color.a);
		float outline_mask = step(alpha_threshold, neighbor_alpha) * (1.0 - base_solid);
		vec3 inner_rgb = base_color.rgb + outline_color.rgb * inner_glow_strength * base_solid * pulse;
		vec3 final_rgb = mix(inner_rgb, outline_color.rgb, outline_mask);
		float final_alpha = max(base_color.a, outline_mask * outline_color.a * outline_alpha * pulse);
		final_color = vec4(final_rgb, final_alpha);
	}

	COLOR = final_color;
}
