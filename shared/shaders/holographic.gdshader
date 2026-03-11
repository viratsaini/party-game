// Holographic shimmer effect for premium UI elements like character cards.
// Creates a rainbow gradient that sweeps across the surface.
shader_type canvas_item;

uniform float shimmer_speed : hint_range(0.1, 5.0) = 1.0;
uniform float shimmer_width : hint_range(0.05, 0.5) = 0.15;
uniform float shimmer_intensity : hint_range(0.0, 1.0) = 0.6;
uniform float saturation : hint_range(0.0, 1.0) = 0.5;
uniform float rainbow_frequency : hint_range(0.5, 4.0) = 2.0;
uniform vec4 base_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool enabled = true;

// Convert HSV to RGB
vec3 hsv_to_rgb(vec3 hsv) {
	vec3 rgb = clamp(abs(mod(hsv.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return hsv.z * mix(vec3(1.0), rgb, hsv.y);
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	if (!enabled) {
		COLOR = tex_color * base_tint;
		return;
	}

	// Calculate shimmer position (diagonal sweep)
	float time = TIME * shimmer_speed;
	float shimmer_pos = fract(time);

	// Diagonal coordinate for the shimmer
	float diag = (UV.x + UV.y) * 0.5;

	// Calculate distance from shimmer line
	float dist = abs(diag - shimmer_pos);
	// Handle wrap-around
	dist = min(dist, abs(diag - shimmer_pos + 1.0));
	dist = min(dist, abs(diag - shimmer_pos - 1.0));

	// Shimmer intensity based on distance
	float shimmer = smoothstep(shimmer_width, 0.0, dist);

	// Rainbow hue based on position
	float hue = fract(diag * rainbow_frequency + time * 0.3);
	vec3 rainbow = hsv_to_rgb(vec3(hue, saturation, 1.0));

	// Combine with base color
	vec3 final_color = mix(tex_color.rgb, rainbow, shimmer * shimmer_intensity);
	final_color *= base_tint.rgb;

	// Add slight brightness boost in shimmer area
	final_color += shimmer * 0.15;

	COLOR = vec4(final_color, tex_color.a * base_tint.a);
}
