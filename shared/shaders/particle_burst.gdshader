// Particle burst effect for selection confirmations and lock-ins.
// Creates expanding ring of particles with trail effects.
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 particle_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform vec4 trail_color : source_color = vec4(0.1, 0.4, 0.8, 0.5);
uniform float ring_thickness : hint_range(0.01, 0.2) = 0.05;
uniform float particle_count : hint_range(4.0, 32.0) = 12.0;
uniform float particle_size : hint_range(0.01, 0.1) = 0.03;
uniform float explosion_speed : hint_range(0.5, 3.0) = 1.5;
uniform bool show_ring = true;
uniform bool show_particles = true;

// Simple hash for randomness
float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 uv_centered = UV - center;
	float dist = length(uv_centered);
	float angle = atan(uv_centered.y, uv_centered.x);

	float alpha = 0.0;
	vec3 color = vec3(0.0);

	// Expanding ring
	if (show_ring) {
		float ring_radius = progress * 0.5 * explosion_speed;
		float ring_dist = abs(dist - ring_radius);
		float ring_alpha = smoothstep(ring_thickness, 0.0, ring_dist);
		ring_alpha *= 1.0 - progress; // Fade out as it expands

		color += particle_color.rgb * ring_alpha;
		alpha = max(alpha, ring_alpha * particle_color.a);

		// Inner glow trail
		if (dist < ring_radius) {
			float trail_alpha = (ring_radius - dist) / ring_radius;
			trail_alpha *= 0.3 * (1.0 - progress);
			color += trail_color.rgb * trail_alpha;
			alpha = max(alpha, trail_alpha * trail_color.a);
		}
	}

	// Individual particles
	if (show_particles) {
		for (float i = 0.0; i < particle_count; i += 1.0) {
			float particle_angle = (i / particle_count) * TAU + hash(i) * 0.5;
			float particle_speed = 0.3 + hash(i + 100.0) * 0.4;
			float particle_dist = progress * particle_speed * explosion_speed;

			vec2 particle_pos = center + vec2(cos(particle_angle), sin(particle_angle)) * particle_dist;
			float particle_d = distance(UV, particle_pos);

			// Particle with size falloff
			float p_size = particle_size * (1.0 - progress * 0.5);
			float particle_alpha = smoothstep(p_size, p_size * 0.3, particle_d);
			particle_alpha *= 1.0 - progress; // Fade out

			// Slight color variation per particle
			vec3 p_color = particle_color.rgb;
			p_color.r += hash(i * 2.0) * 0.2 - 0.1;
			p_color.g += hash(i * 3.0) * 0.2 - 0.1;

			color += p_color * particle_alpha;
			alpha = max(alpha, particle_alpha * particle_color.a);
		}
	}

	// Central flash at start
	float flash_alpha = (1.0 - progress * 3.0);
	flash_alpha = max(0.0, flash_alpha);
	float flash_dist = smoothstep(0.15, 0.0, dist);
	color += vec3(1.0) * flash_dist * flash_alpha;
	alpha = max(alpha, flash_dist * flash_alpha);

	COLOR = vec4(color, alpha);
}
