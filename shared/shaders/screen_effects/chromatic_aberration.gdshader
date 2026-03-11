shader_type canvas_item;
render_mode blend_mix;

// Chromatic Aberration Shader
// Creates RGB channel separation for cinematic or glitch effects
// Mobile-optimized with quality LOD levels

group_uniforms chromatic_aberration;
uniform float aberration_strength : hint_range(0.0, 0.1, 0.001) = 0.01;
uniform float aberration_angle : hint_range(0.0, 6.283, 0.01) = 0.0;
uniform bool radial_aberration = false;
uniform vec2 radial_center = vec2(0.5, 0.5);
uniform float radial_falloff : hint_range(0.0, 2.0) = 1.0;

group_uniforms quality;
uniform int quality_level : hint_range(0, 2) = 2; // 0=mobile, 1=balanced, 2=high
uniform bool enabled = true;

vec2 get_aberration_offset(vec2 uv, float channel_offset) {
    if (radial_aberration) {
        vec2 dir = uv - radial_center;
        float dist = length(dir);
        float strength = aberration_strength * pow(dist, radial_falloff);
        return normalize(dir) * strength * channel_offset;
    } else {
        vec2 dir = vec2(cos(aberration_angle), sin(aberration_angle));
        return dir * aberration_strength * channel_offset;
    }
}

void fragment() {
    if (!enabled) {
        COLOR = texture(TEXTURE, UV);
        return;
    }

    vec4 result;

    if (quality_level == 0) {
        // Mobile: Simple 3-sample
        vec2 r_offset = get_aberration_offset(UV, -1.0);
        vec2 b_offset = get_aberration_offset(UV, 1.0);

        result.r = texture(TEXTURE, UV + r_offset).r;
        result.g = texture(TEXTURE, UV).g;
        result.b = texture(TEXTURE, UV + b_offset).b;
        result.a = texture(TEXTURE, UV).a;
    } else if (quality_level == 1) {
        // Balanced: 5-sample with interpolation
        vec2 r_offset = get_aberration_offset(UV, -1.0);
        vec2 g_offset = get_aberration_offset(UV, 0.0);
        vec2 b_offset = get_aberration_offset(UV, 1.0);

        result.r = texture(TEXTURE, UV + r_offset).r;
        result.g = (texture(TEXTURE, UV + g_offset * 0.5).g + texture(TEXTURE, UV).g) * 0.5;
        result.b = texture(TEXTURE, UV + b_offset).b;
        result.a = texture(TEXTURE, UV).a;
    } else {
        // High: 7-sample with smooth gradient
        vec2 r_offset2 = get_aberration_offset(UV, -1.0);
        vec2 r_offset1 = get_aberration_offset(UV, -0.5);
        vec2 b_offset1 = get_aberration_offset(UV, 0.5);
        vec2 b_offset2 = get_aberration_offset(UV, 1.0);

        result.r = (texture(TEXTURE, UV + r_offset2).r * 0.6 +
                   texture(TEXTURE, UV + r_offset1).r * 0.4);
        result.g = texture(TEXTURE, UV).g;
        result.b = (texture(TEXTURE, UV + b_offset2).b * 0.6 +
                   texture(TEXTURE, UV + b_offset1).b * 0.4);
        result.a = texture(TEXTURE, UV).a;
    }

    COLOR = result;
}
