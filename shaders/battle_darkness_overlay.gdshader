shader_type canvas_item;

uniform vec2 light_center = vec2(0.5, 0.5);
uniform vec2 viewport_size = vec2(1920.0, 1080.0);
uniform float vision_radius = 190.0;
uniform float edge_softness = 90.0;
uniform float darkness_alpha : hint_range(0.0, 1.0) = 0.9;

void fragment() {
	vec2 pixel_position = UV * viewport_size;
	vec2 light_pixel_position = light_center * viewport_size;
	float distance_to_player = distance(pixel_position, light_pixel_position);
	float alpha = smoothstep(vision_radius, vision_radius + edge_softness, distance_to_player);
	COLOR = vec4(0.0, 0.0, 0.0, alpha * darkness_alpha);
}
