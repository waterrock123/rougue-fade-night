shader_type canvas_item;

uniform vec4 hurt_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform bool is_hurt = false;
uniform float shimmer_speed = 3.0;

void fragment() {
	vec4 tint = COLOR;
	vec4 flame = texture(TEXTURE, UV);
	float shimmer = 0.92 + 0.08 * sin(TIME * shimmer_speed + UV.y * 4.0);
	flame.rgb *= shimmer;
	if (is_hurt) {
		flame.rgb = mix(flame.rgb, hurt_color.rgb, 0.7);
	}
	COLOR = flame * tint;
}
