shader_type canvas_item;
render_mode blend_mix;

// Energy Shield Shimmer Shader
// Creates force field / energy shield effect with hexagonal patterns
// Perfect for sci-fi UI, health shields, and barriers

group_uniforms shield_color;
uniform vec3 primary_color : source_color = vec3(0.2, 0.6, 1.0);
uniform vec3 secondary_color : source_color = vec3(0.1, 0.3, 0.8);
uniform vec3 hit_color : source_color = vec3(1.0, 0.3, 0.1);
uniform float color_intensity : hint_range(0.5, 3.0) = 1.5;

group_uniforms hexagon_pattern;
uniform float hex_scale : hint_range(5.0, 50.0) = 20.0;
uniform float hex_thickness : hint_range(0.01, 0.2) = 0.05;
uniform float hex_glow : hint_range(0.0, 2.0) = 0.5;
uniform bool animated_hex = true;
uniform float hex_pulse_speed : hint_range(0.0, 5.0) = 1.0;

group_uniforms shimmer;
uniform float shimmer_speed : hint_range(0.0, 5.0) = 1.0;
uniform float shimmer_intensity : hint_range(0.0, 1.0) = 0.5;
uniform vec2 shimmer_direction = vec2(1.0, 0.5);
uniform float shimmer_scale : hint_range(1.0, 20.0) = 5.0;

group_uniforms fresnel;
uniform float fresnel_power : hint_range(0.5, 5.0) = 2.0;
uniform float fresnel_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float edge_softness : hint_range(0.0, 0.5) = 0.1;

group_uniforms hit_effect;
uniform vec2 hit_position = vec2(0.5, 0.5);
uniform float hit_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float hit_radius : hint_range(0.0, 1.0) = 0.3;
uniform float hit_ripple_count : hint_range(1.0, 10.0) = 3.0;

group_uniforms distortion;
uniform float wave_amplitude : hint_range(0.0, 0.02) = 0.005;
uniform float wave_frequency : hint_range(1.0, 20.0) = 10.0;
uniform float wave_speed : hint_range(0.0, 5.0) = 2.0;

group_uniforms quality;
uniform int quality_level : hint_range(0, 2) = 2;
uniform bool enabled = true;

// Hexagon SDF
float hex_distance(vec2 p) {
    p = abs(p);
    return max(p.x * 0.866025 + p.y * 0.5, p.y);
}

vec4 hex_coords(vec2 uv, float scale) {
    vec2 r = vec2(1.0, 1.73205);
    vec2 h = r * 0.5;

    vec2 a = mod(uv * scale, r) - h;
    vec2 b = mod(uv * scale - h, r) - h;

    vec2 gv = length(a) < length(b) ? a : b;
    vec2 id = uv * scale - gv;

    return vec4(gv, id);
}

float noise(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    if (!enabled) {
        COLOR = tex_color;
        return;
    }

    vec2 uv = UV;

    // Apply wave distortion
    if (wave_amplitude > 0.0) {
        float wave_x = sin(uv.y * wave_frequency + TIME * wave_speed) * wave_amplitude;
        float wave_y = sin(uv.x * wave_frequency + TIME * wave_speed * 0.7) * wave_amplitude;
        uv += vec2(wave_x, wave_y);
    }

    // Hexagon pattern
    vec4 hex = hex_coords(uv, hex_scale);
    float hex_dist = hex_distance(hex.xy);

    // Hexagon edge
    float hex_edge = smoothstep(0.5, 0.5 - hex_thickness, hex_dist);
    float hex_inner = smoothstep(0.5 - hex_thickness, 0.5 - hex_thickness * 2.0, hex_dist);
    float hex_line = hex_edge - hex_inner;

    // Animated pulse per hexagon
    float hex_id = noise(hex.zw);
    float hex_pulse = 0.0;
    if (animated_hex) {
        hex_pulse = sin(TIME * hex_pulse_speed + hex_id * 6.283) * 0.5 + 0.5;
    }

    // Shimmer effect
    float shimmer = 0.0;
    if (shimmer_intensity > 0.0) {
        vec2 shimmer_uv = uv * shimmer_scale + shimmer_direction * TIME * shimmer_speed;
        shimmer = sin(shimmer_uv.x + shimmer_uv.y) * 0.5 + 0.5;
        shimmer = pow(shimmer, 3.0) * shimmer_intensity;
    }

    // Fresnel (edge glow)
    float edge_x = 1.0 - abs(UV.x - 0.5) * 2.0;
    float edge_y = 1.0 - abs(UV.y - 0.5) * 2.0;
    float fresnel = 1.0 - pow(edge_x * edge_y, fresnel_power);
    fresnel = smoothstep(0.0, 1.0, fresnel) * fresnel_intensity;

    // Edge softness
    float alpha_edge = smoothstep(0.0, edge_softness, edge_x) * smoothstep(0.0, edge_softness, edge_y);
    alpha_edge *= smoothstep(0.0, edge_softness, 1.0 - edge_x) * smoothstep(0.0, edge_softness, 1.0 - edge_y);

    // Hit effect
    float hit_effect = 0.0;
    if (hit_intensity > 0.0) {
        float hit_dist = length(UV - hit_position);
        float ripple = sin(hit_dist * hit_ripple_count * 20.0 - TIME * 10.0) * 0.5 + 0.5;
        hit_effect = (1.0 - smoothstep(0.0, hit_radius, hit_dist)) * ripple * hit_intensity;
    }

    // Build final color
    vec3 shield_color = mix(secondary_color, primary_color, fresnel + shimmer);

    // Add hexagon pattern
    shield_color += primary_color * hex_line * hex_glow * (1.0 + hex_pulse);

    // Add shimmer highlights
    shield_color += vec3(shimmer * 0.5);

    // Add hit effect
    shield_color = mix(shield_color, hit_color, hit_effect);

    // Apply intensity
    shield_color *= color_intensity;

    // Calculate alpha
    float alpha = fresnel * 0.5 + hex_line * 0.3 + shimmer * 0.2 + 0.1;
    alpha += hit_effect * 0.5;
    alpha = clamp(alpha, 0.0, 1.0);
    alpha *= alpha_edge;
    alpha *= tex_color.a;

    COLOR = vec4(shield_color, alpha);
}
