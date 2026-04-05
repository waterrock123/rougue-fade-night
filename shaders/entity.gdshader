shader_type canvas_item;

// 着色器在GPU上运行，控制物体的外观,控制像素的呈现方式
//看到的一切由着色器渲染
// GLSL(OpenGl着色语言)
uniform vec4 hurt_color = vec4(1.0,1.0,1.0,1.0);
uniform bool is_hurt = false;

void fragment() {
	vec4 color = texture(TEXTURE,UV);
	
	if (is_hurt){
		color.rgb = mix(color.rgb,hurt_color.rgb,0.5);
	}
	COLOR = color;
	
}

//void light() {
	//// Called for every pixel for every light affecting the CanvasItem.
	//// Uncomment to replace the default light processing function with this one.
//}
