shader_type canvas_item;

uniform int rank = 6;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float time = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Crystal facet highlights based on angle
	float angle = atan(UV.y - 0.5, UV.x - 0.5);
	float facets = abs(sin(angle * 6.0 + time * 0.5)) * 0.2 + 0.9;
	
	// Rotating highlight
	float highlight_angle = time * 0.4;
	float highlight = smoothstep(0.3, 0.0, abs(angle - highlight_angle)) * 0.3;
	
	// Distance from center for depth
	float dist = length(UV - vec2(0.5));
	float depth = 1.0 - dist * 0.3;
	
	vec3 final_rgb = base_color.rgb * tex_color.rgb * facets * depth + vec3(highlight);
	
	COLOR = vec4(final_rgb, tex_color.a);
}
