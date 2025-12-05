shader_type canvas_item;

uniform int rank = 2;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float time = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Strong diagonal gradient - clearly brighter top-left to darker bottom-right
	float diagonal = (UV.x + UV.y) * 0.5;
	float gradient = 1.3 - diagonal * 0.6;
	gradient = clamp(gradient, 0.6, 1.3);
	
	vec4 final_color = tex_color * base_color * gradient;
	final_color.a = tex_color.a;
	
	COLOR = final_color;
}
