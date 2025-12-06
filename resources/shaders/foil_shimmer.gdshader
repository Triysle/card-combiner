shader_type canvas_item;
render_mode blend_add;

uniform float time : hint_range(0.0, 1000.0) = 0.0;
uniform float shimmer_speed : hint_range(0.1, 2.0) = 0.4;
uniform float rainbow_intensity : hint_range(0.0, 1.0) = 0.6;
uniform float shimmer_sharpness : hint_range(1.0, 10.0) = 3.0;

// Convert hue to RGB
vec3 hue_to_rgb(float h) {
	float r = abs(h * 6.0 - 3.0) - 1.0;
	float g = 2.0 - abs(h * 6.0 - 2.0);
	float b = 2.0 - abs(h * 6.0 - 4.0);
	return clamp(vec3(r, g, b), 0.0, 1.0);
}

void fragment() {
	// Create diagonal bands that shift over time
	float diagonal = (UV.x + UV.y) * 2.0;
	float wave = sin(diagonal * shimmer_sharpness - time * shimmer_speed * 3.0) * 0.5 + 0.5;
	
	// Secondary wave at different angle
	float diagonal2 = (UV.x - UV.y + 1.0) * 1.5;
	float wave2 = sin(diagonal2 * shimmer_sharpness * 0.7 - time * shimmer_speed * 2.5 + 1.0) * 0.5 + 0.5;
	
	// Combine waves
	float combined_wave = (wave + wave2) * 0.5;
	
	// Create rainbow hue based on position and time
	float hue = fract(diagonal * 0.2 + time * shimmer_speed * 0.15);
	vec3 rainbow = hue_to_rgb(hue);
	
	// Boost saturation of rainbow colors
	rainbow = mix(vec3(0.5), rainbow, 1.4);
	rainbow = clamp(rainbow, 0.0, 1.0);
	
	// Shimmer intensity varies across the card
	float shimmer_mask = pow(combined_wave, 1.2);
	
	// Apply rainbow with shimmer masking
	vec3 foil_color = rainbow * shimmer_mask * rainbow_intensity;
	
	// Metallic specular highlight - sharp bright bands
	float specular = pow(combined_wave, 6.0) * 0.8;
	
	// Secondary specular at different phase for more complexity
	float spec_wave = sin(diagonal * shimmer_sharpness * 1.3 - time * shimmer_speed * 3.5 + 2.0) * 0.5 + 0.5;
	float specular2 = pow(spec_wave, 8.0) * 0.5;
	
	// Combine all highlights
	float total_highlight = specular + specular2;
	foil_color += vec3(total_highlight);
	
	// Output with enhanced alpha for bright areas
	float alpha = shimmer_mask * 0.85 + total_highlight * 0.5;
	COLOR = vec4(foil_color, alpha);
}
