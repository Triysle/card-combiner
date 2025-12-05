shader_type canvas_item;

uniform int rank = 1;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float time = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Strong vignette - noticeably darker at edges
	vec2 center = UV - vec2(0.5);
	float vignette = 1.0 - length(center) * 0.8;
	vignette = clamp(vignette, 0.5, 1.0);
	
	vec4 final_color = tex_color * base_color * vignette;
	final_color.a = tex_color.a;
	
	COLOR = final_color;
}
