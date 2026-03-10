// Cel-shading (toon) shader for BattleZone Party.
// Creates a cartoon/anime look similar to Borderlands or Jet Set Radio.
// Optimized for mobile (GL Compatibility renderer).
shader_type spatial;

// Render modes for proper lighting
render_mode diffuse_toon, specular_toon;

// === BASE COLOR PARAMETERS ===
group_uniforms Base_Color;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_albedo_texture = false;

// === CEL SHADING PARAMETERS ===
group_uniforms Cel_Shading;
// Number of shading steps (3-5 recommended for cartoon look)
uniform int cel_levels : hint_range(2, 8, 1) = 4;
// How sharp the transitions between shading levels are (0 = smooth, 1 = hard)
uniform float cel_sharpness : hint_range(0.0, 1.0) = 0.8;
// Shadow color tint (darker colors work best)
uniform vec4 shadow_color : source_color = vec4(0.2, 0.15, 0.25, 1.0);
// How dark the shadows get (0 = no shadow, 1 = full shadow)
uniform float shadow_intensity : hint_range(0.0, 1.0) = 0.6;

// === RIM LIGHTING PARAMETERS ===
group_uniforms Rim_Lighting;
uniform bool enable_rim_light = true;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.8;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
// Rim light threshold for cel-style rim
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.5;

// === SPECULAR/HIGHLIGHT PARAMETERS ===
group_uniforms Specular;
uniform bool enable_specular = true;
uniform vec4 specular_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float specular_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float specular_size : hint_range(0.0, 1.0) = 0.2;
uniform float specular_smoothness : hint_range(0.0, 0.5) = 0.05;

// === EMISSION/GLOW PARAMETERS ===
group_uniforms Emission;
uniform bool enable_emission = false;
uniform vec4 emission_color : source_color = vec4(1.0, 0.8, 0.0, 1.0);
uniform float emission_intensity : hint_range(0.0, 3.0) = 1.0;

// === FRESNEL PARAMETERS ===
group_uniforms Fresnel;
uniform bool enable_fresnel = false;
uniform vec4 fresnel_color : source_color = vec4(0.5, 0.7, 1.0, 1.0);
uniform float fresnel_power : hint_range(0.5, 8.0) = 4.0;
uniform float fresnel_intensity : hint_range(0.0, 1.0) = 0.3;

// === TEAM COLOR SUPPORT ===
group_uniforms Team_Color;
uniform bool use_team_color = false;
uniform vec4 team_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float team_color_blend : hint_range(0.0, 1.0) = 0.5;

// Varying for world-space calculations
varying vec3 world_normal;
varying vec3 world_position;
varying vec3 view_direction;

void vertex() {
	// Transform normal to world space for lighting calculations
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// World position for various effects
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// View direction from vertex to camera
	view_direction = normalize(CAMERA_POSITION_WORLD - world_position);
}

// Quantize a value into discrete steps (cel-shading core function)
float cel_quantize(float value, int levels, float sharpness) {
	float quantized = floor(value * float(levels)) / float(levels - 1);
	// Blend between smooth and quantized based on sharpness
	return mix(value, quantized, sharpness);
}

// Calculate rim lighting with cel-style quantization
float calculate_rim(vec3 normal, vec3 view, float power, float threshold) {
	float rim = 1.0 - max(dot(normal, view), 0.0);
	rim = pow(rim, power);
	// Apply threshold for harder cel-style rim
	rim = smoothstep(threshold, threshold + 0.2, rim);
	return rim;
}

// Calculate specular highlight with cel-style
float calculate_specular_cel(vec3 normal, vec3 view, vec3 light_dir, float size, float smoothness) {
	vec3 half_vec = normalize(view + light_dir);
	float spec = max(dot(normal, half_vec), 0.0);
	// Create hard-edged specular highlight
	float spec_threshold = 1.0 - size;
	spec = smoothstep(spec_threshold - smoothness, spec_threshold + smoothness, spec);
	return spec;
}

void fragment() {
	// Get base color
	vec4 base = albedo_color;
	if (use_albedo_texture) {
		base *= texture(albedo_texture, UV);
	}

	// Apply team color if enabled
	if (use_team_color) {
		base.rgb = mix(base.rgb, team_color.rgb, team_color_blend);
	}

	// Calculate fresnel effect
	float fresnel = 0.0;
	if (enable_fresnel) {
		fresnel = pow(1.0 - max(dot(normalize(world_normal), normalize(view_direction)), 0.0), fresnel_power);
		fresnel *= fresnel_intensity;
	}

	// Output base albedo with optional fresnel tint
	ALBEDO = base.rgb;
	if (enable_fresnel) {
		ALBEDO = mix(ALBEDO, fresnel_color.rgb, fresnel);
	}

	// Set roughness high for toon look (reduces PBR reflections)
	ROUGHNESS = 0.9;

	// Set metallic low for cartoon materials
	METALLIC = 0.0;

	// Emission
	if (enable_emission) {
		EMISSION = emission_color.rgb * emission_intensity;
	}
}

// Custom light function for cel-shading effect
void light() {
	// Calculate diffuse lighting
	float ndotl = dot(NORMAL, LIGHT);
	float diffuse = max(ndotl, 0.0);

	// Apply cel quantization to diffuse
	float cel_diffuse = cel_quantize(diffuse, cel_levels, cel_sharpness);

	// Calculate shadow factor
	float shadow_factor = mix(1.0, shadow_intensity, 1.0 - cel_diffuse);

	// Calculate shadow-tinted color
	vec3 lit_color = ALBEDO * LIGHT_COLOR * ATTENUATION;
	vec3 shadow_tinted = mix(lit_color, shadow_color.rgb * ALBEDO, 1.0 - cel_diffuse);

	// Blend between full light and shadow based on cel_diffuse
	vec3 final_diffuse = mix(shadow_tinted, lit_color, cel_diffuse);

	// Rim lighting
	float rim = 0.0;
	if (enable_rim_light) {
		rim = calculate_rim(NORMAL, VIEW, rim_power, rim_threshold);
		// Only apply rim on lit side (facing light)
		rim *= max(ndotl * 0.5 + 0.5, 0.0);
	}

	// Specular highlight
	float spec = 0.0;
	if (enable_specular) {
		spec = calculate_specular_cel(NORMAL, VIEW, LIGHT, specular_size, specular_smoothness);
		// Only show specular where lit
		spec *= step(0.1, cel_diffuse);
	}

	// Combine all lighting
	DIFFUSE_LIGHT += final_diffuse;

	// Add rim light
	if (enable_rim_light) {
		DIFFUSE_LIGHT += rim_color.rgb * rim * rim_intensity * ATTENUATION;
	}

	// Add specular
	if (enable_specular) {
		SPECULAR_LIGHT += specular_color.rgb * spec * specular_intensity * ATTENUATION;
	}
}
