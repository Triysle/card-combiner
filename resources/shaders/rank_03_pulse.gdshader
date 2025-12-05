shader_type canvas_item;

uniform int rank = 3;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float time = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// Strong breathing pulse - clearly visible
	float pulse = sin(time * 1.0) * 0.2 + 0.9;

	// Radial gradient from center
	vec2 center = UV - vec2(0.5);
	float radial = 1.0 - length(center) * 0.4;

	vec4 final_color = tex_color * base_color * pulse * radial;
	final_color.a = tex_color.a;

	COLOR = final_color;
}
