shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(0.48, 0.03, 0.08, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.12, 0.08, 1.0);
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float alpha_multiplier : hint_range(0.0, 1.0) = 1.0;
uniform float edge_width : hint_range(0.0, 0.25) = 0.08;
uniform float noise_scale = 24.0;
uniform float distortion_strength : hint_range(0.0, 0.08) = 0.015;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	float wave = sin(UV.y * 30.0 + TIME * 12.0) * distortion_strength;
	vec2 sample_uv = UV + vec2(wave, 0.0);
	vec4 tex = texture(TEXTURE, sample_uv);

	float dissolve_noise = noise(UV * noise_scale + vec2(TIME * 1.7, -TIME * 0.9));
	float dissolve_mask = smoothstep(dissolve_amount - edge_width, dissolve_amount + edge_width, dissolve_noise);
	float edge_mask = smoothstep(dissolve_amount - edge_width, dissolve_amount, dissolve_noise)
		- smoothstep(dissolve_amount, dissolve_amount + edge_width, dissolve_noise);

	vec4 base_color = tex * tint_color;
	base_color.rgb = mix(base_color.rgb, edge_color.rgb, clamp(edge_mask, 0.0, 1.0));
	base_color.a *= alpha_multiplier * dissolve_mask;
	COLOR = base_color;
}
