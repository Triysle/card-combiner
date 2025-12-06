shader_type canvas_item;

uniform float time : hint_range(0.0, 1000.0) = 0.0;
uniform vec4 base_tint : source_color = vec4(0.9, 0.9, 0.95, 1.0);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Sweeping highlight across the plate
	float sweep_pos = fract(time * 0.4);
	float sweep = smoothstep(0.15, 0.0, abs(UV.x - sweep_pos)) * 0.3;
	
	// Subtle shimmer
	float shimmer = sin(UV.x * 20.0 + time * 2.0) * 0.05 + 0.95;
	
	// Apply tint and effects
	vec3 tinted = tex_color.rgb * base_tint.rgb * shimmer;
	tinted += vec3(sweep);
	
	COLOR = vec4(tinted, tex_color.a * base_tint.a);
}
