shader_type canvas_item;

uniform float time : hint_range(0.0, 1000.0) = 0.0;
uniform vec4 diamond_color : source_color = vec4(0.4, 0.8, 1.0, 1.0);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Gentle pulse/hum animation
	float pulse = sin(time * 2.5) * 0.1 + 1.0;
	
	// Neon-like glow effect - brighter at edges
	float edge_dist = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float edge_glow = smoothstep(0.0, 0.3, edge_dist) * 0.3 + 0.7;
	
	// Sweeping sparkle
	float sweep_pos = fract(time * 0.5);
	float sweep = smoothstep(0.1, 0.0, abs((UV.x + UV.y) * 0.5 - sweep_pos)) * 0.2;
	
	// Apply diamond tint with pulse
	vec3 base = tex_color.rgb * diamond_color.rgb * pulse * edge_glow;
	
	// Add glow overlay
	base += diamond_color.rgb * sweep;
	
	// Boost brightness for that diamond shine
	base *= 1.15;
	
	COLOR = vec4(base, tex_color.a);
}
