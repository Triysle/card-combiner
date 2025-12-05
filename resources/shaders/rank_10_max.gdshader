shader_type canvas_item;

uniform int rank = 10;
uniform vec4 base_color : source_color = vec4(1.0, 0.85, 0.0, 1.0);
uniform float time = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Sweeping highlight (diagonal)
	float sweep_pos = fract(time * 0.4);
	float sweep = smoothstep(0.15, 0.0, abs((UV.x + UV.y) * 0.5 - sweep_pos));
	
	// Secondary sweep (opposite direction)
	float sweep2_pos = fract(time * 0.25 + 0.5);
	float sweep2 = smoothstep(0.1, 0.0, abs((UV.x - UV.y + 1.0) * 0.5 - sweep2_pos)) * 0.5;
	
	// Sparkle effect
	float sparkle_grid = sin(UV.x * 40.0) * sin(UV.y * 40.0);
	float sparkle_time = sin(time * 8.0 + UV.x * 10.0 + UV.y * 10.0);
	float sparkle = max(0.0, sparkle_grid * sparkle_time) * 0.4;
	
	// Pulsing glow
	float pulse = sin(time * 2.0) * 0.08 + 1.0;
	
	// Combine effects
	vec3 final_rgb = base_color.rgb * tex_color.rgb * pulse;
	final_rgb += vec3(sweep * 0.5);   // Bright sweep
	final_rgb += vec3(sweep2 * 0.25); // Secondary sweep
	final_rgb += vec3(sparkle);       // Sparkles
	
	// Boost overall brightness for MAX
	final_rgb *= 1.1;
	
	COLOR = vec4(final_rgb, tex_color.a);
}
