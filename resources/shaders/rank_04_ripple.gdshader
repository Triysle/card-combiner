shader_type canvas_item;

uniform int rank = 4;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float time = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Ripple waves emanating from center
	vec2 center = UV - vec2(0.5);
	float dist = length(center);
	float ripple = sin(dist * 15.0 - time * 3.0) * 0.1 + 0.9;
	
	// Fade ripple effect toward edges
	float fade = 1.0 - dist * 0.3;
	float effect = mix(1.0, ripple, smoothstep(0.0, 0.4, dist));
	
	vec4 final_color = tex_color * base_color * effect * fade;
	final_color.a = tex_color.a;
	
	COLOR = final_color;
}
