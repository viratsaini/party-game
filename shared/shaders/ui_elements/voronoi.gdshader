shader_type canvas_item;
render_mode blend_mix;

// Voronoi Diagram Shader
// Creates animated Voronoi patterns with various cell styles
// Perfect for organic textures, shattered glass, and cellular effects

group_uniforms voronoi;
uniform float cell_scale : hint_range(2.0, 50.0) = 10.0;
uniform float cell_randomness : hint_range(0.0, 1.0) = 1.0;
uniform int voronoi_type : hint_range(0, 2) = 0; // 0=distance, 1=cell, 2=edge

group_uniforms colors;
uniform vec3 cell_color_1 : source_color = vec3(0.2, 0.4, 0.8);
uniform vec3 cell_color_2 : source_color = vec3(0.8, 0.2, 0.4);
uniform vec3 edge_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float color_variation : hint_range(0.0, 1.0) = 0.5;

group_uniforms edges;
uniform float edge_thickness : hint_range(0.0, 0.3) = 0.05;
uniform float edge_softness : hint_range(0.0, 0.2) = 0.02;
uniform float edge_glow : hint_range(0.0, 2.0) = 0.5;

group_uniforms animation;
uniform bool animated = true;
uniform float animation_speed : hint_range(0.0, 2.0) = 0.5;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;
uniform bool morph_cells = true;
uniform float morph_amount : hint_range(0.0, 0.5) = 0.2;

group_uniforms effects;
uniform bool cracked_effect = false;
uniform float crack_depth : hint_range(0.0, 1.0) = 0.3;
uniform bool organic_growth = false;
uniform float growth_progress : hint_range(0.0, 1.0) = 1.0;
uniform vec2 growth_center = vec2(0.5, 0.5);

group_uniforms quality;
uniform int quality_level : hint_range(0, 2) = 2;
uniform bool enabled = true;

vec2 random2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float random(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// Returns: x = distance to nearest, y = distance to second nearest, zw = cell ID
vec4 voronoi_extended(vec2 uv, float time, float randomness) {
    vec2 i_uv = floor(uv);
    vec2 f_uv = fract(uv);

    float min_dist = 10.0;
    float second_dist = 10.0;
    vec2 min_cell = vec2(0.0);

    // Search 3x3 neighborhood
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 cell = i_uv + neighbor;

            vec2 point = random2(cell) * randomness;

            // Animate point position
            if (morph_cells && time > 0.0) {
                point += vec2(
                    sin(time + point.x * 10.0),
                    cos(time + point.y * 10.0)
                ) * morph_amount;
            }

            vec2 diff = neighbor + point - f_uv;
            float dist = length(diff);

            if (dist < min_dist) {
                second_dist = min_dist;
                min_dist = dist;
                min_cell = cell;
            } else if (dist < second_dist) {
                second_dist = dist;
            }
        }
    }

    return vec4(min_dist, second_dist, min_cell);
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    if (!enabled) {
        COLOR = tex_color;
        return;
    }

    float time = animated ? TIME * animation_speed : 0.0;
    vec2 scaled_uv = UV * cell_scale;

    // Get Voronoi data
    vec4 voronoi_data = voronoi_extended(scaled_uv, time, cell_randomness);
    float dist_to_nearest = voronoi_data.x;
    float dist_to_second = voronoi_data.y;
    vec2 cell_id = voronoi_data.zw;

    // Calculate edge distance (difference between nearest and second nearest)
    float edge_dist = dist_to_second - dist_to_nearest;

    // Cell color based on ID
    float cell_hash = random(cell_id);
    vec3 cell_color = mix(cell_color_1, cell_color_2, cell_hash * color_variation);

    // Pulse animation per cell
    if (animated && pulse_speed > 0.0) {
        float pulse = sin(time * pulse_speed + cell_hash * 6.283) * 0.5 + 0.5;
        cell_color *= 0.8 + pulse * 0.4;
    }

    vec3 result;
    float alpha = 1.0;

    if (voronoi_type == 0) {
        // Distance-based shading
        result = cell_color * (1.0 - dist_to_nearest * 0.5);

        // Add edges
        float edge = smoothstep(edge_thickness + edge_softness, edge_thickness, edge_dist);
        result = mix(result, edge_color, edge);

        // Edge glow
        float glow = smoothstep(edge_thickness * 3.0, edge_thickness, edge_dist) * edge_glow;
        result += edge_color * glow * 0.3;

    } else if (voronoi_type == 1) {
        // Flat cell coloring
        result = cell_color;

        // Subtle gradient within cell
        result *= 0.9 + dist_to_nearest * 0.2;

        // Add edges
        float edge = smoothstep(edge_thickness + edge_softness, edge_thickness, edge_dist);
        result = mix(result, edge_color, edge);

    } else {
        // Edge-only mode
        float edge = smoothstep(edge_thickness + edge_softness, edge_thickness, edge_dist);
        float glow = smoothstep(edge_thickness * 2.0, edge_thickness, edge_dist);

        result = edge_color * edge;
        result += cell_color * glow * edge_glow * 0.3;
        alpha = edge + glow * 0.3;
    }

    // Cracked effect (depth based on edge distance)
    if (cracked_effect) {
        float crack = smoothstep(edge_thickness, 0.0, edge_dist);
        result = mix(result, result * (1.0 - crack_depth), crack);

        // Add shadow at crack edges
        float shadow = smoothstep(edge_thickness * 2.0, edge_thickness, edge_dist) * crack_depth;
        result *= 1.0 - shadow * 0.5;
    }

    // Organic growth effect
    if (organic_growth) {
        float growth_dist = length(UV - growth_center);
        float growth_mask = smoothstep(growth_progress + 0.1, growth_progress - 0.1, growth_dist);

        // Noisy edge for organic look
        float noise_offset = random(cell_id) * 0.2;
        growth_mask = smoothstep(growth_progress + noise_offset + 0.1, growth_progress + noise_offset - 0.1, growth_dist);

        alpha *= growth_mask;
    }

    // Combine with texture
    vec3 final_color = mix(tex_color.rgb, result, alpha);
    float final_alpha = mix(tex_color.a, 1.0, alpha);

    COLOR = vec4(final_color, final_alpha);
}
