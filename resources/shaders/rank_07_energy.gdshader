shader_type canvas_item;

uniform int rank = 7;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float time = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Flickering energy effect
	float flicker1 = sin(time * 8.0 + UV.x * 10.0) * 0.5 + 0.5;
	float flicker2 = sin(time * 6.0 + UV.y * 8.0 + 1.0) * 0.5 + 0.5;
	float flicker = mix(flicker1, flicker2, 0.5) * 0.15 + 0.85;
	
	// Rising energy waves from bottom
	float wave = sin((UV.y * 8.0) - time * 4.0 + UV.x * 2.0) * 0.5 + 0.5;
	float energy_rise = wave * (1.0 - UV.y) * 0.2;
	
	// Hot spots
	float hot = sin(UV.x * 15.0 + time * 3.0) * sin(UV.y * 15.0 + time * 2.5);
	hot = max(0.0, hot) * 0.1;
	
	// Combine effects
	vec3 final_rgb = base_color.rgb * tex_color.rgb * flicker;
	final_rgb += vec3(energy_rise + hot) * base_color.rgb;
	
	// Slight color intensification
	final_rgb *= 1.1;
	
	COLOR = vec4(final_rgb, tex_color.a);
}
