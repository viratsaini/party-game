shader_type canvas_item;
render_mode blend_mix;

// Radial Blur Shader
// Creates zoom/radial blur for action emphasis and focus effects
// Optimized for real-time UI use

group_uniforms radial_blur;
uniform vec2 blur_center = vec2(0.5, 0.5);
uniform float blur_strength : hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float blur_falloff : hint_range(0.1, 5.0) = 2.0;
uniform float inner_radius : hint_range(0.0, 1.0) = 0.2;
uniform float outer_radius : hint_range(0.0, 2.0) = 1.0;

group_uniforms quality;
uniform int sample_count : hint_range(4, 32) = 12;
uniform int quality_level : hint_range(0, 2) = 2;
uniform bool enabled = true;

void fragment() {
    if (!enabled) {
        COLOR = texture(TEXTURE, UV);
        return;
    }

    vec2 dir = UV - blur_center;
    float dist = length(dir);

    // Calculate blur amount based on distance
    float blur_amount = smoothstep(inner_radius, outer_radius, dist);
    blur_amount = pow(blur_amount, blur_falloff) * blur_strength;

    vec4 result = vec4(0.0);
    float total_weight = 0.0;

    int samples = quality_level == 0 ? 4 : (quality_level == 1 ? 8 : sample_count);

    for (int i = 0; i < samples; i++) {
        float t = float(i) / float(samples - 1);
        float weight = 1.0 - abs(t - 0.5) * 2.0; // Center-weighted

        vec2 sample_uv = mix(UV, blur_center, blur_amount * t);
        result += texture(TEXTURE, sample_uv) * weight;
        total_weight += weight;
    }

    COLOR = result / total_weight;
}
