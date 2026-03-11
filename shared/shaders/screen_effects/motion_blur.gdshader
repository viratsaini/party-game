shader_type canvas_item;
render_mode blend_mix;

// Motion Blur Shader
// Creates directional motion blur for movement effects
// Supports velocity-based blur direction

group_uniforms motion_blur;
uniform vec2 blur_direction = vec2(1.0, 0.0);
uniform float blur_strength : hint_range(0.0, 0.2) = 0.05;
uniform float blur_curve : hint_range(0.5, 3.0) = 1.5;
uniform bool velocity_based = false;
uniform vec2 velocity = vec2(0.0, 0.0);
uniform float velocity_scale : hint_range(0.0, 0.01) = 0.001;

group_uniforms quality;
uniform int sample_count : hint_range(4, 24) = 12;
uniform int quality_level : hint_range(0, 2) = 2;
uniform bool enabled = true;

void fragment() {
    if (!enabled) {
        COLOR = texture(TEXTURE, UV);
        return;
    }

    vec2 direction;
    float strength;

    if (velocity_based) {
        direction = normalize(velocity + vec2(0.0001));
        strength = length(velocity) * velocity_scale;
    } else {
        direction = normalize(blur_direction + vec2(0.0001));
        strength = blur_strength;
    }

    vec4 result = vec4(0.0);
    float total_weight = 0.0;

    int samples = quality_level == 0 ? 4 : (quality_level == 1 ? 8 : sample_count);

    for (int i = 0; i < samples; i++) {
        float t = (float(i) / float(samples - 1)) - 0.5; // -0.5 to 0.5
        float weight = pow(1.0 - abs(t) * 2.0, blur_curve);

        vec2 offset = direction * strength * t;
        result += texture(TEXTURE, UV + offset) * weight;
        total_weight += weight;
    }

    COLOR = result / total_weight;
}
