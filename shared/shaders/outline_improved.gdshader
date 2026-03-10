// Enhanced cel-outline shader with distance-based thickness.
// Renders as a separate pass behind the main mesh.
// Features: dynamic outline width based on camera distance, screen-space consistent width,
// color variation, and mobile-optimized performance.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

// === OUTLINE WIDTH PARAMETERS ===
group_uniforms Outline_Width;
// Base outline thickness (in world units at reference distance)
uniform float outline_width : hint_range(0.0, 0.2) = 0.03;
// Minimum outline width (prevents outline from disappearing at distance)
uniform float min_outline_width : hint_range(0.0, 0.1) = 0.01;
// Maximum outline width (prevents outline from getting too thick up close)
uniform float max_outline_width : hint_range(0.0, 0.3) = 0.08;
// Reference distance for width calculation (outline_width is exact at this distance)
uniform float reference_distance : hint_range(1.0, 50.0) = 10.0;
// How much the outline scales with distance (0 = fixed, 1 = fully dynamic)
uniform float distance_scale_factor : hint_range(0.0, 2.0) = 0.8;

// === OUTLINE COLOR PARAMETERS ===
group_uniforms Outline_Color;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Optional: different color for parts facing away from light
uniform vec4 outline_shadow_color : source_color = vec4(0.1, 0.05, 0.15, 1.0);
uniform bool use_shadow_color = false;
// Blend outline color toward shadow color based on normal direction
uniform float shadow_color_blend : hint_range(0.0, 1.0) = 0.5;

// === DEPTH FADE PARAMETERS ===
group_uniforms Depth_Fade;
// Fade outline at extreme distances
uniform bool enable_distance_fade = true;
uniform float fade_start_distance : hint_range(10.0, 100.0) = 40.0;
uniform float fade_end_distance : hint_range(20.0, 150.0) = 60.0;

// === SILHOUETTE ENHANCEMENT ===
group_uniforms Silhouette;
// Enhance outline where normals face away from camera (silhouette edges)
uniform bool enhance_silhouette = true;
uniform float silhouette_boost : hint_range(1.0, 3.0) = 1.5;
uniform float silhouette_power : hint_range(0.5, 4.0) = 2.0;

// === TEAM/PLAYER COLOR ===
group_uniforms Team_Color;
uniform bool use_team_tint = false;
uniform vec4 team_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float team_color_blend : hint_range(0.0, 1.0) = 0.3;

// Varying for world-space calculations
varying float vertex_distance;
varying vec3 world_normal;
varying float facing_ratio; // How much the normal faces the camera

void vertex() {
	// Calculate world-space position for distance calculation
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vertex_distance = length(CAMERA_POSITION_WORLD - world_pos);

	// Get world-space normal for various effects
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);

	// Calculate how much this vertex faces the camera (for silhouette enhancement)
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	facing_ratio = max(dot(world_normal, view_dir), 0.0);

	// Calculate dynamic outline width based on distance
	float distance_ratio = vertex_distance / reference_distance;

	// Scale width with distance (further = thicker to maintain screen presence)
	float scaled_width = outline_width * pow(distance_ratio, distance_scale_factor);

	// Clamp to min/max
	float final_width = clamp(scaled_width, min_outline_width, max_outline_width);

	// Enhance silhouette edges (normals facing away from camera)
	if (enhance_silhouette) {
		float silhouette_factor = pow(1.0 - facing_ratio, silhouette_power);
		final_width *= mix(1.0, silhouette_boost, silhouette_factor);
	}

	// Apply distance fade (reduce width at extreme distances)
	if (enable_distance_fade && vertex_distance > fade_start_distance) {
		float fade = 1.0 - smoothstep(fade_start_distance, fade_end_distance, vertex_distance);
		final_width *= fade;
	}

	// Expand vertex along normal
	VERTEX += NORMAL * final_width;
}

void fragment() {
	// Start with base outline color
	vec3 final_color = outline_color.rgb;

	// Apply shadow color variation based on normal direction
	if (use_shadow_color) {
		// Use facing_ratio to blend toward shadow color on back-facing parts
		float shadow_blend = (1.0 - facing_ratio) * shadow_color_blend;
		final_color = mix(final_color, outline_shadow_color.rgb, shadow_blend);
	}

	// Apply team color tint
	if (use_team_tint) {
		final_color = mix(final_color, team_color.rgb * 0.3, team_color_blend);
	}

	// Distance-based fade (alpha)
	float alpha = 1.0;
	if (enable_distance_fade && vertex_distance > fade_start_distance) {
		alpha = 1.0 - smoothstep(fade_start_distance, fade_end_distance, vertex_distance);
	}

	// Output final color
	ALBEDO = final_color;
	ALPHA = outline_color.a * alpha;

	// Ensure outline renders properly with alpha
	if (ALPHA < 0.01) {
		discard;
	}
}
