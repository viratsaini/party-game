// Premium UI effects shader for BattleZone Party.
// Provides multiple effects: glow, wave, ripple, glitch, hologram, shimmer.
// Optimized for mobile (GL Compatibility renderer).
shader_type canvas_item;

// === EFFECT ENABLE FLAGS ===
group_uniforms Effects;
uniform bool enable_glow = false;
uniform bool enable_wave = false;
uniform bool enable_ripple = false;
uniform bool enable_glitch = false;
uniform bool enable_hologram = false;
uniform bool enable_shimmer = false;

// === GLOW PARAMETERS ===
group_uniforms Glow;
uniform vec4 glow_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.0;
uniform float glow_size : hint_range(0.0, 0.3) = 0.05;

// === WAVE PARAMETERS ===
group_uniforms Wave;
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.02;
uniform float wave_frequency : hint_range(0.0, 20.0) = 5.0;
uniform float wave_speed : hint_range(0.0, 5.0) = 2.0;

// === RIPPLE PARAMETERS ===
group_uniforms Ripple;
uniform vec2 ripple_center = vec2(0.5, 0.5);
uniform float ripple_time : hint_range(0.0, 10.0) = 0.0;
uniform float ripple_amplitude : hint_range(0.0, 0.2) = 0.05;
uniform float ripple_frequency : hint_range(1.0, 20.0) = 10.0;

// === GLITCH PARAMETERS ===
group_uniforms Glitch;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float glitch_speed : hint_range(0.0, 10.0) = 5.0;
uniform float glitch_block_size : hint_range(0.01, 0.2) = 0.05;

// === HOLOGRAM PARAMETERS ===
group_uniforms Hologram;
uniform vec4 hologram_color : source_color = vec4(0.0, 0.8, 1.0, 0.5);
uniform float hologram_scanline_density : hint_range(10.0, 200.0) = 100.0;
uniform float hologram_scanline_speed : hint_range(0.0, 5.0) = 1.0;
uniform float hologram_flicker_speed : hint_range(0.0, 10.0) = 5.0;
uniform float hologram_flicker_intensity : hint_range(0.0, 1.0) = 0.3;

// === SHIMMER PARAMETERS ===
group_uniforms Shimmer;
uniform vec4 shimmer_color : source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform float shimmer_speed : hint_range(0.0, 5.0) = 1.5;
uniform float shimmer_width : hint_range(0.05, 0.5) = 0.2;
uniform float shimmer_angle : hint_range(0.0, 6.28318) = 0.785398; // 45 degrees default

// === TIME (auto-updated by Godot) ===
uniform float custom_time : hint_range(0.0, 100.0) = 0.0;

// Simple hash function for pseudo-random numbers.
float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

// Pseudo-random 2D hash.
float hash2d(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Smooth noise function.
float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), u);
}

// 2D noise.
float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = hash2d(i);
	float b = hash2d(i + vec2(1.0, 0.0));
	float c = hash2d(i + vec2(0.0, 1.0));
	float d = hash2d(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	vec4 original_color = texture(TEXTURE, uv);
	vec4 final_color = original_color;

	float time = custom_time > 0.0 ? custom_time : TIME;

	// === WAVE EFFECT ===
	if (enable_wave) {
		float wave_offset = sin(uv.y * wave_frequency + time * wave_speed) * wave_amplitude;
		vec2 wave_uv = vec2(uv.x + wave_offset, uv.y);
		final_color = texture(TEXTURE, wave_uv);
	}

	// === RIPPLE EFFECT ===
	if (enable_ripple) {
		vec2 to_center = uv - ripple_center;
		float dist = length(to_center);
		float ripple = sin(dist * ripple_frequency - ripple_time * 5.0) * ripple_amplitude;
		vec2 ripple_uv = uv + normalize(to_center) * ripple;
		final_color = texture(TEXTURE, ripple_uv);
	}

	// === GLITCH EFFECT ===
	if (enable_glitch) {
		float block_y = floor(uv.y / glitch_block_size) * glitch_block_size;
		float glitch_offset = noise(block_y * 10.0 + time * glitch_speed) * 2.0 - 1.0;
		glitch_offset *= glitch_intensity * 0.1;

		// RGB split effect.
		vec4 glitch_r = texture(TEXTURE, uv + vec2(glitch_offset, 0.0));
		vec4 glitch_g = texture(TEXTURE, uv);
		vec4 glitch_b = texture(TEXTURE, uv - vec2(glitch_offset, 0.0));

		if (noise(block_y + time) > 0.7) {
			final_color = vec4(glitch_r.r, glitch_g.g, glitch_b.b, final_color.a);
		}
	}

	// === HOLOGRAM EFFECT ===
	if (enable_hologram) {
		// Scanlines.
		float scanline = sin(uv.y * hologram_scanline_density + time * hologram_scanline_speed) * 0.5 + 0.5;

		// Flicker.
		float flicker = noise(time * hologram_flicker_speed) * hologram_flicker_intensity + (1.0 - hologram_flicker_intensity);

		// Apply hologram tint.
		final_color = mix(final_color, hologram_color, 0.3);
		final_color.a *= scanline * 0.3 + 0.7;
		final_color.a *= flicker;
	}

	// === SHIMMER EFFECT ===
	if (enable_shimmer) {
		// Rotating shimmer line.
		float angle = shimmer_angle;
		vec2 shimmer_dir = vec2(cos(angle), sin(angle));
		float shimmer_progress = fract(time * shimmer_speed);

		// Distance from shimmer line.
		float shimmer_line = dot(uv - vec2(0.5), shimmer_dir) + shimmer_progress * 2.0 - 1.0;
		float shimmer_mask = smoothstep(shimmer_width, 0.0, abs(shimmer_line));

		// Add shimmer highlight.
		final_color.rgb += shimmer_color.rgb * shimmer_mask * shimmer_color.a;
	}

	// === GLOW EFFECT ===
	if (enable_glow) {
		// Sample surrounding pixels for glow.
		vec4 glow_sum = vec4(0.0);
		float glow_samples = 0.0;

		// Simple box blur for glow.
		for (float x = -glow_size; x <= glow_size; x += glow_size * 0.5) {
			for (float y = -glow_size; y <= glow_size; y += glow_size * 0.5) {
				vec2 offset = vec2(x, y);
				vec4 sample_color = texture(TEXTURE, uv + offset);
				glow_sum += sample_color;
				glow_samples += 1.0;
			}
		}

		vec4 glow = (glow_sum / glow_samples) * glow_color * glow_intensity;

		// Additive blending for glow.
		final_color.rgb += glow.rgb * glow.a * original_color.a;
	}

	COLOR = final_color;
}
