// Animated background shader with floating geometric patterns and light beams.
// Creates a premium, dynamic backdrop for character select screens.
shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.04, 0.04, 0.08, 1.0);
uniform vec4 accent_color : source_color = vec4(0.2, 0.5, 0.9, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.5, 0.2, 0.7, 1.0);
uniform float pattern_scale : hint_range(1.0, 20.0) = 8.0;
uniform float pattern_speed : hint_range(0.1, 2.0) = 0.5;
uniform float light_beam_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float particle_density : hint_range(0.0, 1.0) = 0.5;
uniform float depth_layers : hint_range(1.0, 5.0) = 3.0;

// Pseudo-random
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 2D noise
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Hexagonal pattern
float hexagon(vec2 p) {
	p = abs(p);
	return max(dot(p, vec2(0.866, 0.5)), p.y);
}

// Diamond pattern
float diamond(vec2 p) {
	return abs(p.x) + abs(p.y);
}

void fragment() {
	vec2 uv = UV;
	float time = TIME * pattern_speed;

	// Base gradient (vertical)
	vec3 color = mix(base_color.rgb, base_color.rgb * 1.3, uv.y * 0.5);

	// Multiple depth layers of patterns
	for (float layer = 0.0; layer < depth_layers; layer += 1.0) {
		float layer_scale = pattern_scale * (1.0 + layer * 0.5);
		float layer_speed = time * (0.5 + layer * 0.2);
		float layer_alpha = 0.1 / (layer + 1.0);

		vec2 layer_uv = uv * layer_scale;
		layer_uv.y += layer_speed;
		layer_uv.x += sin(time * 0.3 + layer) * 0.5;

		// Hexagonal grid
		vec2 hex_uv = layer_uv;
		hex_uv.x *= 1.1547; // 2/sqrt(3)
		hex_uv.y += mod(floor(hex_uv.x), 2.0) * 0.5;
		vec2 hex_id = floor(hex_uv);
		vec2 hex_local = fract(hex_uv) - 0.5;

		float hex = hexagon(hex_local);
		float hex_edge = smoothstep(0.5, 0.45, hex);
		float hex_line = smoothstep(0.5, 0.48, hex) - smoothstep(0.48, 0.46, hex);

		// Animate some hexagons
		float hex_active = step(0.85, hash(hex_id + floor(time * 0.5)));
		float hex_pulse = sin(time * 3.0 + hash(hex_id) * TAU) * 0.5 + 0.5;

		vec3 hex_color = mix(accent_color.rgb, secondary_color.rgb, hash(hex_id));
		color += hex_line * hex_color * layer_alpha;
		color += hex_edge * hex_color * hex_active * hex_pulse * layer_alpha * 0.5;
	}

	// Light beams from top
	float beam_count = 5.0;
	for (float i = 0.0; i < beam_count; i += 1.0) {
		float beam_x = hash(vec2(i, 0.0)) * 2.0 - 0.5;
		beam_x += sin(time * 0.5 + i * 1.5) * 0.1;

		float beam_width = 0.03 + hash(vec2(i, 1.0)) * 0.02;
		float beam = smoothstep(beam_width, 0.0, abs(uv.x - beam_x));
		beam *= 1.0 - uv.y; // Fade toward bottom
		beam *= 0.5 + sin(time * 2.0 + i * 2.0) * 0.3; // Flicker

		vec3 beam_color = mix(accent_color.rgb, secondary_color.rgb, i / beam_count);
		color += beam * beam_color * light_beam_intensity;
	}

	// Floating particles
	float particle_layer_count = 3.0;
	for (float pl = 0.0; pl < particle_layer_count; pl += 1.0) {
		float p_scale = 20.0 + pl * 10.0;
		float p_speed = 0.2 + pl * 0.1;

		vec2 p_uv = uv * p_scale;
		p_uv.y -= time * p_speed;

		vec2 p_id = floor(p_uv);
		vec2 p_local = fract(p_uv) - 0.5;

		float p_exist = step(1.0 - particle_density * 0.3, hash(p_id));
		float p_size = 0.02 + hash(p_id + 100.0) * 0.03;
		p_size /= (1.0 + pl * 0.5);

		float p_dist = length(p_local);
		float particle = smoothstep(p_size, p_size * 0.3, p_dist) * p_exist;

		// Twinkle
		float twinkle = sin(time * 5.0 + hash(p_id) * TAU) * 0.5 + 0.5;
		particle *= 0.5 + twinkle * 0.5;

		vec3 p_color = mix(accent_color.rgb, vec3(1.0), 0.5);
		color += particle * p_color * 0.3 / (pl + 1.0);
	}

	// Vignette
	float vignette = 1.0 - length((uv - 0.5) * vec2(1.5, 1.0));
	vignette = smoothstep(0.0, 0.7, vignette);
	color *= 0.7 + vignette * 0.3;

	// Slight scanline effect
	float scanline = sin(uv.y * 400.0) * 0.02;
	color -= scanline;

	COLOR = vec4(color, 1.0);
}
