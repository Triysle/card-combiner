shader_type canvas_item;

uniform int rank = 8;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float time = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Metallic reflection - diagonal sweep
	float sweep = sin((UV.x - UV.y) * 5.0 + time * 1.5) * 0.5 + 0.5;
	
	// Specular highlight moving across card
	float highlight_pos = fract(time * 0.3);
	float highlight = smoothstep(0.1, 0.0, abs(UV.x - highlight_pos)) * 0.4;
	
	// Create metallic look with varied brightness
	float metallic = 0.7 + sweep * 0.3 + highlight;
	
	vec3 final_rgb = base_color.rgb * tex_color.rgb * metallic;
	
	// Add slight color shift in highlights
	final_rgb += vec3(highlight * 0.2);
	
	COLOR = vec4(final_rgb, tex_color.a);
}
