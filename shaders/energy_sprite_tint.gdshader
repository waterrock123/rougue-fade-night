shader_type canvas_item;

// 保留现有火花轮廓和透明度，将冷色纹理映射成可配置的暖色能量，不生成替代几何美术。
uniform vec4 energy_color : source_color = vec4(1.0, 0.35, 0.08, 1.0);
uniform float pulse_speed = 8.0;
uniform float pulse_strength : hint_range(0.0, 0.5) = 0.12;
varying vec4 sprite_modulate;

void vertex() {
	sprite_modulate = COLOR;
}

void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	float lightness = dot(sample_color.rgb, vec3(0.299, 0.587, 0.114));
	float pulse = 1.0 - pulse_strength * (0.5 + 0.5 * sin(TIME * pulse_speed));
	vec3 glow = mix(energy_color.rgb, vec3(1.0, 0.95, 0.7), smoothstep(0.6, 1.0, lightness));
	COLOR = vec4(glow * pulse, sample_color.a * energy_color.a) * sprite_modulate;
}
