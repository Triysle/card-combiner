shader_type canvas_item;

uniform int rank = 9;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float time = 0.0;

// Simple pseudo-random
float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Base metallic sheen
	float sheen = sin((UV.x + UV.y) * 4.0 + time) * 0.1 + 0.9;
	
	// Electric arcs - jagged lines
	float arc_time = floor(time * 8.0);
	float arc1 = smoothstep(0.02, 0.0, abs(UV.y - 0.5 - sin(UV.x * 20.0 + arc_time) * 0.1 * rand(vec2(arc_time, 0.0))));
	float arc2 = smoothstep(0.015, 0.0, abs(UV.x - 0.5 - sin(UV.y * 15.0 + arc_time * 1.3) * 0.15 * rand(vec2(arc_time, 1.0))));
	
	// Crackling effect - random bright spots
	float crackle_seed = floor(time * 12.0);
	float crackle = rand(UV * 10.0 + crackle_seed);
	crackle = step(0.97, crackle) * 0.5;
	
	// Pulsing glow
	float pulse = sin(time * 6.0) * 0.1 + 0.9;
	
	// Combine
	vec3 final_rgb = base_color.rgb * tex_color.rgb * sheen * pulse;
	
	// Add electric highlights (white-ish)
	float electric = (arc1 + arc2) * 0.6 + crackle;
	final_rgb += vec3(electric) * vec3(0.9, 0.95, 1.0);
	
	COLOR = vec4(final_rgb, tex_color.a);
}
