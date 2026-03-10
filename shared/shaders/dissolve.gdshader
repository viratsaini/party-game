// Dissolve effect shader for eliminations and respawns.
// Uses a procedural noise pattern (sin/cos based) so no texture is required.
shader_type spatial;

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Simple procedural noise based on sin/cos — cheap and mobile-friendly.
float procedural_noise(vec3 p) {
	return fract(
		sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453
		+ cos(dot(p.zxy, vec3(93.989, 67.345, 54.321))) * 23421.6312
	);
}

void fragment() {
	// Sample noise at world-ish coordinates derived from UV + vertex position.
	float noise = procedural_noise(vec3(UV * 10.0, dissolve_amount * 0.1));

	// Discard fragments below the dissolve threshold.
	if (noise < dissolve_amount) {
		discard;
	}

	// Glow at the dissolve boundary.
	float edge = smoothstep(dissolve_amount, dissolve_amount + edge_width, noise);

	ALBEDO = mix(edge_color.rgb, base_color.rgb, edge);
	EMISSION = edge_color.rgb * (1.0 - edge) * 2.0;
}
