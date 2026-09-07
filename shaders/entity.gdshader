shader_type canvas_item;

// 着色器在GPU上运行，控制物体的外观,控制像素的呈现方式
//看到的一切由着色器渲染
// GLSL(OpenGl着色语言)
uniform vec4 hurt_color = vec4(1.0,1.0,1.0,1.0);
uniform bool is_hurt = false;

// 韧性状态发光。默认关闭，因此玩家、召唤物等共用此 Shader 的实体不会受到影响。
uniform bool poise_glow_enabled = false;
uniform vec4 poise_glow_color : source_color = vec4(1.0, 0.95, 0.72, 1.0);
uniform float poise_glow_size : hint_range(0.0, 4.0, 0.1) = 1.0;
uniform float poise_glow_alpha : hint_range(0.0, 1.0, 0.01) = 0.75;
uniform float poise_glow_pulse_strength : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float poise_glow_pulse_speed : hint_range(0.0, 12.0, 0.1) = 3.0;

// 破韧瞬间的强闪白由运行时 Tween 驱动，不依赖额外逐帧美术。
uniform vec4 poise_break_flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float poise_break_flash_strength : hint_range(0.0, 1.0, 0.01) = 0.0;

void fragment() {
	vec4 sampled_color = texture(TEXTURE, UV);
	vec4 color = sampled_color;

	if (poise_glow_enabled) {
		vec2 pixel_offset = TEXTURE_PIXEL_SIZE * max(poise_glow_size, 0.0);
		float neighbor_alpha = 0.0;
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(pixel_offset.x, 0.0)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(pixel_offset.x, 0.0)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, pixel_offset.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(0.0, pixel_offset.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + pixel_offset).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - pixel_offset).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(pixel_offset.x, -pixel_offset.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-pixel_offset.x, pixel_offset.y)).a);

		float outline_mask = max(neighbor_alpha - sampled_color.a, 0.0);
		float pulse = 1.0 - poise_glow_pulse_strength;
		pulse += (sin(TIME * poise_glow_pulse_speed) * 0.5 + 0.5) * poise_glow_pulse_strength;
		float outline_alpha = outline_mask * poise_glow_color.a * poise_glow_alpha * pulse;
		vec4 outline_color = vec4(poise_glow_color.rgb, outline_alpha);
		color = mix(outline_color, sampled_color, sampled_color.a);
	}
	
	if (is_hurt){
		color.rgb = mix(color.rgb,hurt_color.rgb,0.5);
	}
	if (poise_break_flash_strength > 0.0) {
		float flash_weight = clamp(poise_break_flash_strength * poise_break_flash_color.a, 0.0, 1.0);
		color.rgb = mix(color.rgb, poise_break_flash_color.rgb, flash_weight);
	}
	COLOR = color;
	
}

//void light() {
	//// Called for every pixel for every light affecting the CanvasItem.
	//// Uncomment to replace the default light processing function with this one.
//}
