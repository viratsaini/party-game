// Advanced Menu Shaders - Round 2 Ultra-Premium Effects
// BattleZone Party - AAA-Quality Visual Effects
//
// Features:
// - Chromatic aberration with dynamic intensity
// - Holographic text effect with rainbow scanning
// - Cursor distortion field
// - Dynamic color grading (time-of-day)
// - Depth-of-field blur for inactive elements
// - Energy field visualization
// - Advanced particle-reactive backgrounds
shader_type canvas_item;

// ============================================================================
// EFFECT TOGGLES
// ============================================================================
group_uniforms EffectToggles;
uniform bool enable_chromatic_aberration = false;
uniform bool enable_holographic = false;
uniform bool enable_distortion_field = false;
uniform bool enable_color_grading = false;
uniform bool enable_depth_blur = false;
uniform bool enable_energy_field = false;
uniform bool enable_background_fx = true;
uniform bool enable_constellation = false;

// ============================================================================
// CHROMATIC ABERRATION PARAMETERS
// ============================================================================
group_uniforms ChromaticAberration;
uniform float chromatic_intensity : hint_range(0.0, 0.1) = 0.0;
uniform float chromatic_speed : hint_range(0.0, 5.0) = 2.0;
uniform vec2 chromatic_direction = vec2(1.0, 0.0);
uniform bool chromatic_radial = true;

// ============================================================================
// HOLOGRAPHIC TEXT PARAMETERS
// ============================================================================
group_uniforms Holographic;
uniform float holo_scan_speed : hint_range(0.0, 10.0) = 3.0;
uniform float holo_scan_width : hint_range(0.01, 0.3) = 0.08;
uniform float holo_rainbow_frequency : hint_range(0.5, 5.0) = 2.0;
uniform float holo_intensity : hint_range(0.0, 1.0) = 0.7;
uniform float holo_flicker_speed : hint_range(0.0, 20.0) = 12.0;
uniform float holo_flicker_amount : hint_range(0.0, 0.5) = 0.15;
uniform float holo_edge_glow : hint_range(0.0, 2.0) = 1.0;
uniform vec4 holo_primary_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform vec4 holo_secondary_color : source_color = vec4(0.8, 0.2, 1.0, 1.0);

// ============================================================================
// DISTORTION FIELD PARAMETERS
// ============================================================================
group_uniforms DistortionField;
uniform vec2 cursor_position = vec2(0.5, 0.5);
uniform float distortion_radius : hint_range(0.0, 0.5) = 0.15;
uniform float distortion_strength : hint_range(0.0, 0.2) = 0.05;
uniform float distortion_wave_count : hint_range(1.0, 10.0) = 3.0;
uniform float distortion_rotation_speed : hint_range(0.0, 5.0) = 2.0;

// ============================================================================
// COLOR GRADING PARAMETERS (Time-of-Day)
// ============================================================================
group_uniforms ColorGrading;
uniform float time_of_day : hint_range(0.0, 24.0) = 12.0;
uniform float grading_intensity : hint_range(0.0, 1.0) = 0.5;
uniform vec4 dawn_tint : source_color = vec4(1.0, 0.8, 0.6, 1.0);
uniform vec4 day_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 dusk_tint : source_color = vec4(1.0, 0.6, 0.5, 1.0);
uniform vec4 night_tint : source_color = vec4(0.6, 0.7, 1.0, 1.0);

// ============================================================================
// DEPTH BLUR PARAMETERS
// ============================================================================
group_uniforms DepthBlur;
uniform float blur_amount : hint_range(0.0, 10.0) = 0.0;
uniform float blur_focus_distance : hint_range(0.0, 1.0) = 0.5;
uniform float blur_falloff : hint_range(0.1, 5.0) = 1.0;

// ============================================================================
// ENERGY FIELD PARAMETERS
// ============================================================================
group_uniforms EnergyField;
uniform float energy_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float energy_pulse_speed : hint_range(0.0, 5.0) = 1.5;
uniform float energy_wave_scale : hint_range(1.0, 20.0) = 8.0;
uniform vec4 energy_color_a : source_color = vec4(0.2, 0.6, 1.0, 0.3);
uniform vec4 energy_color_b : source_color = vec4(0.6, 0.2, 1.0, 0.3);

// ============================================================================
// BACKGROUND FX PARAMETERS
// ============================================================================
group_uniforms BackgroundFX;
uniform float bg_hex_scale : hint_range(10.0, 100.0) = 50.0;
uniform float bg_hex_glow : hint_range(0.0, 1.0) = 0.3;
uniform float bg_noise_scale : hint_range(1.0, 10.0) = 4.0;
uniform float bg_flow_speed : hint_range(0.0, 2.0) = 0.5;
uniform vec4 bg_color_primary : source_color = vec4(0.05, 0.05, 0.15, 1.0);
uniform vec4 bg_color_secondary : source_color = vec4(0.1, 0.05, 0.2, 1.0);
uniform vec4 bg_glow_color : source_color = vec4(0.3, 0.5, 1.0, 0.15);

// ============================================================================
// CONSTELLATION PARAMETERS
// ============================================================================
group_uniforms Constellation;
uniform float constellation_density : hint_range(0.0, 1.0) = 0.5;
uniform float constellation_twinkle_speed : hint_range(0.0, 10.0) = 3.0;
uniform float constellation_line_alpha : hint_range(0.0, 0.5) = 0.2;
uniform vec4 constellation_color : source_color = vec4(0.8, 0.9, 1.0, 0.6);

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

// High-quality hash for pseudo-random numbers
float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

float hash2d(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// Smooth noise
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = hash2d(i);
	float b = hash2d(i + vec2(1.0, 0.0));
	float c = hash2d(i + vec2(0.0, 1.0));
	float d = hash2d(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fractal Brownian Motion
float fbm(vec2 p, int octaves) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;

	for (int i = 0; i < octaves; i++) {
		value += amplitude * noise(p * frequency);
		amplitude *= 0.5;
		frequency *= 2.0;
	}

	return value;
}

// HSV to RGB conversion
vec3 hsv_to_rgb(vec3 hsv) {
	vec3 rgb = clamp(abs(mod(hsv.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return hsv.z * mix(vec3(1.0), rgb, hsv.y);
}

// Hexagon distance function
float hex_dist(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.732))), p.x);
}

// Get hexagon grid coordinates
vec4 hex_coords(vec2 uv) {
	vec2 r = vec2(1.0, 1.732);
	vec2 h = r * 0.5;
	vec2 a = mod(uv, r) - h;
	vec2 b = mod(uv - h, r) - h;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;

	vec2 id = uv - gv;
	return vec4(gv, id);
}

// ============================================================================
// EFFECT IMPLEMENTATIONS
// ============================================================================

// Chromatic Aberration Effect
vec4 apply_chromatic_aberration(sampler2D tex, vec2 uv, float time) {
	float intensity = chromatic_intensity;

	// Animate intensity subtly
	intensity *= 1.0 + sin(time * chromatic_speed) * 0.2;

	vec2 direction;
	if (chromatic_radial) {
		// Radial chromatic aberration from center
		direction = normalize(uv - vec2(0.5));
	} else {
		direction = normalize(chromatic_direction);
	}

	// Distance from center affects intensity
	float dist_from_center = length(uv - vec2(0.5));
	intensity *= dist_from_center * 2.0;

	vec2 offset = direction * intensity;

	float r = texture(tex, uv + offset).r;
	float g = texture(tex, uv).g;
	float b = texture(tex, uv - offset).b;
	float a = texture(tex, uv).a;

	return vec4(r, g, b, a);
}

// Holographic Text Effect
vec4 apply_holographic(vec4 color, vec2 uv, float time) {
	// Scanning line position
	float scan_pos = fract(time * holo_scan_speed * 0.1);

	// Multiple scan directions for complex effect
	float scan_h = smoothstep(holo_scan_width, 0.0, abs(uv.y - scan_pos));
	float scan_d = smoothstep(holo_scan_width, 0.0, abs((uv.x + uv.y) * 0.5 - scan_pos));
	float scan = max(scan_h, scan_d * 0.7);

	// Rainbow hue based on position and time
	float hue = fract(uv.x * holo_rainbow_frequency + uv.y * 0.5 + time * 0.3);
	vec3 rainbow = hsv_to_rgb(vec3(hue, 0.8, 1.0));

	// Gradient between primary and secondary colors
	vec3 holo_base = mix(holo_primary_color.rgb, holo_secondary_color.rgb, uv.y);

	// Flicker effect
	float flicker = 1.0 - holo_flicker_amount * (0.5 + 0.5 * sin(time * holo_flicker_speed));
	flicker *= 1.0 - holo_flicker_amount * 0.3 * hash(floor(time * 20.0));

	// Edge glow (based on alpha edges)
	float edge = smoothstep(0.1, 0.3, color.a) * smoothstep(0.9, 0.7, color.a);
	edge *= holo_edge_glow;

	// Combine effects
	vec3 holo_color = mix(color.rgb, rainbow, scan * holo_intensity);
	holo_color = mix(holo_color, holo_base, 0.3 * holo_intensity);
	holo_color += rainbow * edge * 0.5;
	holo_color *= flicker;

	// Scanline overlay
	float scanlines = 0.95 + 0.05 * sin(uv.y * 400.0 + time * 5.0);
	holo_color *= scanlines;

	return vec4(holo_color, color.a);
}

// Cursor Distortion Field Effect
vec2 apply_distortion_field(vec2 uv, float time) {
	vec2 to_cursor = uv - cursor_position;
	float dist = length(to_cursor);

	if (dist > distortion_radius) {
		return uv;
	}

	float factor = 1.0 - (dist / distortion_radius);
	factor = factor * factor; // Quadratic falloff

	// Rotating wave distortion
	float angle = atan(to_cursor.y, to_cursor.x);
	float wave = sin(angle * distortion_wave_count + time * distortion_rotation_speed);
	wave += sin(dist * 30.0 - time * 3.0) * 0.5;

	// Apply distortion
	vec2 offset = normalize(to_cursor) * wave * distortion_strength * factor;

	// Add swirl effect
	float swirl = factor * 0.5;
	float cos_swirl = cos(swirl);
	float sin_swirl = sin(swirl);
	mat2 rotation = mat2(vec2(cos_swirl, -sin_swirl), vec2(sin_swirl, cos_swirl));

	vec2 distorted = uv + offset;
	distorted = cursor_position + rotation * (distorted - cursor_position);

	return distorted;
}

// Time-of-Day Color Grading
vec3 apply_color_grading(vec3 color) {
	// Calculate blend factors based on time of day
	// 6 = dawn, 12 = day, 18 = dusk, 0/24 = night

	vec4 tint;

	if (time_of_day < 6.0) {
		// Night to Dawn
		float t = time_of_day / 6.0;
		tint = mix(night_tint, dawn_tint, t);
	} else if (time_of_day < 12.0) {
		// Dawn to Day
		float t = (time_of_day - 6.0) / 6.0;
		tint = mix(dawn_tint, day_tint, t);
	} else if (time_of_day < 18.0) {
		// Day to Dusk
		float t = (time_of_day - 12.0) / 6.0;
		tint = mix(day_tint, dusk_tint, t);
	} else {
		// Dusk to Night
		float t = (time_of_day - 18.0) / 6.0;
		tint = mix(dusk_tint, night_tint, t);
	}

	return mix(color, color * tint.rgb, grading_intensity);
}

// Depth-of-Field Blur
vec4 apply_depth_blur(sampler2D tex, vec2 uv, vec2 pixel_size) {
	if (blur_amount < 0.01) {
		return texture(tex, uv);
	}

	// Calculate blur based on distance from focus
	float depth = length(uv - vec2(0.5, blur_focus_distance));
	float blur_factor = smoothstep(0.0, blur_falloff, depth) * blur_amount;

	if (blur_factor < 0.01) {
		return texture(tex, uv);
	}

	// Gaussian blur approximation
	vec4 color = vec4(0.0);
	float total_weight = 0.0;

	int samples = int(blur_factor) + 3;
	samples = min(samples, 9);

	for (int x = -samples; x <= samples; x++) {
		for (int y = -samples; y <= samples; y++) {
			vec2 offset = vec2(float(x), float(y)) * pixel_size * blur_factor;
			float weight = 1.0 / (1.0 + length(vec2(x, y)) * 0.5);
			color += texture(tex, uv + offset) * weight;
			total_weight += weight;
		}
	}

	return color / total_weight;
}

// Energy Field Visualization
vec3 apply_energy_field(vec2 uv, float time) {
	// Wave patterns
	float wave1 = sin(uv.x * energy_wave_scale + time * energy_pulse_speed) * 0.5 + 0.5;
	float wave2 = sin(uv.y * energy_wave_scale * 0.7 + time * energy_pulse_speed * 1.3) * 0.5 + 0.5;
	float wave3 = sin((uv.x + uv.y) * energy_wave_scale * 0.5 - time * energy_pulse_speed * 0.8) * 0.5 + 0.5;

	// Combine waves
	float energy = wave1 * wave2 * wave3;
	energy = pow(energy, 2.0);

	// Pulsing
	float pulse = sin(time * energy_pulse_speed * 2.0) * 0.3 + 0.7;
	energy *= pulse;

	// Color gradient
	vec3 energy_color = mix(energy_color_a.rgb, energy_color_b.rgb, uv.y);

	return energy_color * energy * energy_intensity;
}

// Background Hexagonal Grid with Flow
vec3 apply_background_fx(vec2 uv, float time) {
	// Base gradient
	vec3 bg = mix(bg_color_primary.rgb, bg_color_secondary.rgb, uv.y);

	// Flowing noise
	vec2 flow_uv = uv * bg_noise_scale + vec2(time * bg_flow_speed, time * bg_flow_speed * 0.5);
	float flow = fbm(flow_uv, 4);
	bg = mix(bg, bg * 1.5, flow * 0.3);

	// Hexagonal grid
	vec2 hex_uv = uv * bg_hex_scale;
	vec4 hex = hex_coords(hex_uv);
	float hex_dist_val = hex_dist(hex.xy);

	// Animated hex edges
	float hex_edge = smoothstep(0.5, 0.45, hex_dist_val);
	float hex_center = smoothstep(0.3, 0.0, hex_dist_val);

	// Pulse individual hexes based on position
	float hex_pulse = sin(hex.z * 0.5 + hex.w * 0.5 + time * 2.0) * 0.5 + 0.5;

	// Add hex glow
	vec3 hex_glow = bg_glow_color.rgb * hex_edge * bg_hex_glow * (0.5 + hex_pulse * 0.5);

	// Random hex highlighting
	float hex_id = hash2d(hex.zw);
	if (hex_id > 0.95) {
		hex_glow += bg_glow_color.rgb * hex_center * sin(time * 3.0 + hex_id * 10.0) * 0.5;
	}

	return bg + hex_glow;
}

// Constellation Pattern
vec3 apply_constellation(vec2 uv, float time) {
	vec3 result = vec3(0.0);

	// Star grid
	float star_scale = 10.0 + constellation_density * 20.0;
	vec2 star_uv = uv * star_scale;
	vec2 star_id = floor(star_uv);
	vec2 star_fract = fract(star_uv);

	// Current cell star
	vec2 star_offset = hash22(star_id);
	float star_dist = length(star_fract - star_offset);

	// Twinkle
	float twinkle = sin(time * constellation_twinkle_speed + hash2d(star_id) * 10.0) * 0.5 + 0.5;

	// Star brightness
	float star_brightness = smoothstep(0.1, 0.0, star_dist) * twinkle;

	// Only show some stars based on density
	if (hash2d(star_id + vec2(100.0)) < constellation_density) {
		result += constellation_color.rgb * star_brightness * constellation_color.a;
	}

	// Draw lines to nearby stars
	for (int dx = -1; dx <= 1; dx++) {
		for (int dy = -1; dy <= 1; dy++) {
			if (dx == 0 && dy == 0) continue;

			vec2 neighbor_id = star_id + vec2(float(dx), float(dy));

			// Check if should draw line
			float line_hash = hash2d(min(star_id, neighbor_id) * 100.0 + max(star_id, neighbor_id));
			if (line_hash > 0.85 && hash2d(neighbor_id + vec2(100.0)) < constellation_density) {
				vec2 neighbor_offset = hash22(neighbor_id);
				vec2 neighbor_pos = vec2(float(dx), float(dy)) + neighbor_offset;

				// Line distance
				vec2 line_dir = normalize(neighbor_pos - star_offset);
				float line_len = length(neighbor_pos - star_offset);
				vec2 to_point = star_fract - star_offset;
				float along_line = dot(to_point, line_dir);

				if (along_line > 0.0 && along_line < line_len) {
					float line_dist = length(to_point - line_dir * along_line);
					float line_alpha = smoothstep(0.03, 0.0, line_dist) * constellation_line_alpha;
					line_alpha *= twinkle;
					result += constellation_color.rgb * line_alpha;
				}
			}
		}
	}

	return result;
}

// ============================================================================
// MAIN FRAGMENT SHADER
// ============================================================================

void fragment() {
	vec2 uv = UV;
	float time = TIME;
	vec2 pixel_size = 1.0 / vec2(textureSize(TEXTURE, 0));

	// Apply distortion field first (affects UV)
	if (enable_distortion_field) {
		uv = apply_distortion_field(uv, time);
	}

	// Sample texture with optional chromatic aberration
	vec4 color;
	if (enable_chromatic_aberration && chromatic_intensity > 0.001) {
		color = apply_chromatic_aberration(TEXTURE, uv, time);
	} else if (enable_depth_blur && blur_amount > 0.01) {
		color = apply_depth_blur(TEXTURE, uv, pixel_size);
	} else {
		color = texture(TEXTURE, uv);
	}

	// Apply background effects (for background elements)
	if (enable_background_fx && color.a < 0.1) {
		vec3 bg = apply_background_fx(UV, time);

		if (enable_constellation) {
			bg += apply_constellation(UV, time);
		}

		if (enable_energy_field) {
			bg += apply_energy_field(UV, time);
		}

		color = vec4(bg, 1.0);
	}

	// Apply holographic effect
	if (enable_holographic) {
		color = apply_holographic(color, uv, time);
	}

	// Apply energy field overlay
	if (enable_energy_field && color.a > 0.1) {
		color.rgb += apply_energy_field(UV, time) * 0.3;
	}

	// Apply color grading
	if (enable_color_grading) {
		color.rgb = apply_color_grading(color.rgb);
	}

	COLOR = color;
}
