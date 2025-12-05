shader_type canvas_item;

uniform int rank = 5;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float time = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Diagonal shimmer bands
	float band = sin((UV.x + UV.y) * 15.0 + time * 2.0) * 0.5 + 0.5;
	float shimmer = mix(0.85, 1.15, band);
	
	// Add sweeping highlight
	float sweep_pos = fract(time * 0.3);
	float sweep = smoothstep(0.2, 0.0, abs((UV.x + UV.y) * 0.5 - sweep_pos)) * 0.25;
	
	vec3 final_rgb = base_color.rgb * tex_color.rgb * shimmer + vec3(sweep);
	
	COLOR = vec4(final_rgb, tex_color.a);
}
