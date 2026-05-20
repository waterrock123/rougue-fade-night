shader_type canvas_item;

uniform vec4 inner_color : source_color = vec4(1.0, 0.08, 0.02, 0.85);
uniform vec4 outer_color : source_color = vec4(0.45, 0.0, 0.0, 0.0);
uniform float pulse_speed = 1.35;
uniform float pulse_strength = 0.28;
uniform float ring_sharpness = 3.2;
uniform float distort_strength = 0.025;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float dist = length(centered_uv);
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	float breath = 1.0 + pulse * pulse_strength;

	vec2 direction = normalize(centered_uv + vec2(0.0001));
	vec2 distorted_uv = UV + direction * sin(TIME * 1.8 + dist * 18.0) * distort_strength;
	vec4 tex = texture(TEXTURE, distorted_uv);

	float ring = pow(max(1.0 - dist * ring_sharpness, 0.0), 1.35);
	float edge_flare = smoothstep(0.48, 0.18, dist) * (0.45 + pulse * 0.55);
	vec4 aura_color = mix(outer_color, inner_color, clamp(ring * breath + edge_flare * 0.35, 0.0, 1.0));

	COLOR.rgb = tex.rgb * aura_color.rgb * (1.1 + pulse * 0.45);
	COLOR.a = tex.a * aura_color.a * (0.55 + pulse * 0.45);
}
