shader_type canvas_item;
render_mode blend_mix;

// Hexagonal Grid Pattern Shader
// Creates animated hexagonal grid patterns with customizable effects
// Perfect for sci-fi interfaces, tech backgrounds, and energy fields

group_uniforms grid_properties;
uniform float hex_size : hint_range(5.0, 100.0) = 30.0;
uniform float line_thickness : hint_range(0.01, 0.2) = 0.05;
uniform float line_softness : hint_range(0.0, 0.1) = 0.02;
uniform bool filled_hexagons = false;
uniform float fill_opacity : hint_range(0.0, 1.0) = 0.1;

group_uniforms colors;
uniform vec3 line_color : source_color = vec3(0.0, 0.8, 1.0);
uniform vec3 fill_color : source_color = vec3(0.0, 0.4, 0.8);
uniform vec3 highlight_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float color_intensity : hint_range(0.5, 3.0) = 1.5;

group_uniforms animation;
uniform bool animated = true;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;
uniform float wave_speed : hint_range(0.0, 5.0) = 0.5;
uniform vec2 wave_direction = vec2(1.0, 0.5);
uniform float wave_frequency : hint_range(0.1, 2.0) = 0.5;

group_uniforms effects;
uniform bool glow_enabled = true;
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.5;
uniform float glow_radius : hint_range(0.0, 0.1) = 0.03;
uniform bool highlight_random = true;
uniform float highlight_probability : hint_range(0.0, 0.3) = 0.1;
uniform float highlight_fade_speed : hint_range(0.5, 5.0) = 2.0;

group_uniforms mask;
uniform bool radial_mask = false;
uniform vec2 mask_center = vec2(0.5, 0.5);
uniform float mask_radius : hint_range(0.0, 1.5) = 1.0;
uniform float mask_softness : hint_range(0.0, 0.5) = 0.2;

group_uniforms quality;
uniform int quality_level : hint_range(0, 2) = 2;
uniform bool enabled = true;

const vec2 HEX_RATIO = vec2(1.0, 1.73205080757);

float random(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// Hexagon signed distance function
float hex_sdf(vec2 p) {
    p = abs(p);
    return max(p.x * 0.866025 + p.y * 0.5, p.y) - 0.5;
}

// Get hexagon coordinates and local position
vec4 hex_coords(vec2 uv, float size) {
    vec2 r = HEX_RATIO;
    vec2 h = r * 0.5;

    vec2 scaled = uv * size;

    vec2 a = mod(scaled, r) - h;
    vec2 b = mod(scaled - h, r) - h;

    vec2 gv = length(a) < length(b) ? a : b;
    vec2 id = scaled - gv;

    return vec4(gv, id);
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    if (!enabled) {
        COLOR = tex_color;
        return;
    }

    // Get hexagon data
    vec4 hex = hex_coords(UV, hex_size);
    vec2 local_pos = hex.xy;
    vec2 hex_id = hex.zw;

    // Calculate hex distance
    float hex_dist = hex_sdf(local_pos);

    // Calculate line with softness
    float line = smoothstep(line_thickness + line_softness, line_thickness, abs(hex_dist));

    // Hex fill
    float fill = filled_hexagons ? smoothstep(0.0, -0.1, hex_dist) * fill_opacity : 0.0;

    // Animation
    float anim_value = 1.0;
    if (animated) {
        // Wave animation
        float wave = dot(hex_id / hex_size, wave_direction) * wave_frequency;
        wave = sin(wave * 6.283 + TIME * wave_speed) * 0.5 + 0.5;

        // Pulse animation per hex
        float hex_random = random(floor(hex_id));
        float pulse = sin(TIME * pulse_speed + hex_random * 6.283) * 0.5 + 0.5;

        anim_value = mix(0.5, 1.0, wave * 0.5 + pulse * 0.5);
    }

    // Random highlights
    float highlight = 0.0;
    if (highlight_random) {
        float time_slot = floor(TIME * highlight_fade_speed);
        float hex_hash = random(floor(hex_id) + vec2(time_slot, 0.0));

        if (hex_hash < highlight_probability) {
            float fade = fract(TIME * highlight_fade_speed);
            fade = 1.0 - abs(fade - 0.5) * 2.0;
            highlight = fade * (1.0 - smoothstep(-0.1, 0.0, hex_dist));
        }
    }

    // Calculate glow
    float glow = 0.0;
    if (glow_enabled && quality_level >= 1) {
        glow = smoothstep(glow_radius + line_thickness, line_thickness, abs(hex_dist));
        glow = pow(glow, 2.0) * glow_intensity;
    }

    // Build color
    vec3 result = vec3(0.0);

    // Fill color
    result += fill_color * fill * anim_value;

    // Line color
    result += line_color * line * anim_value * color_intensity;

    // Glow
    result += line_color * glow * 0.5;

    // Highlight
    result += highlight_color * highlight;

    // Radial mask
    float mask_alpha = 1.0;
    if (radial_mask) {
        float mask_dist = length(UV - mask_center);
        mask_alpha = 1.0 - smoothstep(mask_radius - mask_softness, mask_radius, mask_dist);
    }

    // Calculate final alpha
    float alpha = max(max(line, fill), glow * 0.3) + highlight;
    alpha = clamp(alpha, 0.0, 1.0) * mask_alpha;

    // Combine with texture
    vec3 final_color = mix(tex_color.rgb, result, alpha);
    float final_alpha = max(tex_color.a, alpha);

    COLOR = vec4(final_color, final_alpha);
}
