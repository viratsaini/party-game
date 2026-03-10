shader_type canvas_item;
render_mode blend_mix;

// Gaussian Blur Shader
// High-quality separable Gaussian blur with adjustable kernel size
// Optimized for real-time UI effects

group_uniforms blur;
uniform float blur_amount : hint_range(0.0, 20.0) = 5.0;
uniform vec2 blur_direction = vec2(1.0, 0.0);
uniform bool two_pass = true; // For full blur, use two passes

group_uniforms mask;
uniform sampler2D blur_mask : hint_default_white;
uniform bool use_mask = false;
uniform bool invert_mask = false;

group_uniforms quality;
uniform int quality_level : hint_range(0, 2) = 2;
uniform bool enabled = true;

// Precomputed Gaussian weights for different kernel sizes
const float WEIGHTS_5[5] = { 0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216 };
const float WEIGHTS_9[9] = { 0.1270270, 0.1401710, 0.1039640, 0.0545990, 0.0204180, 0.0054100, 0.0009670, 0.0001100, 0.0000070 };

void fragment() {
    if (!enabled || blur_amount < 0.01) {
        COLOR = texture(TEXTURE, UV);
        return;
    }

    float mask_value = 1.0;
    if (use_mask) {
        mask_value = texture(blur_mask, UV).r;
        if (invert_mask) mask_value = 1.0 - mask_value;
    }

    if (mask_value < 0.01) {
        COLOR = texture(TEXTURE, UV);
        return;
    }

    vec2 tex_offset = TEXTURE_PIXEL_SIZE * blur_amount * normalize(blur_direction + vec2(0.0001));

    vec4 result = vec4(0.0);
    float total_weight = 0.0;

    if (quality_level == 0) {
        // Mobile: 5-tap blur
        for (int i = 0; i < 5; i++) {
            float weight = WEIGHTS_5[i];
            vec2 offset = tex_offset * float(i);

            if (i == 0) {
                result += texture(TEXTURE, UV) * weight;
                total_weight += weight;
            } else {
                result += texture(TEXTURE, UV + offset) * weight;
                result += texture(TEXTURE, UV - offset) * weight;
                total_weight += weight * 2.0;
            }
        }
    } else if (quality_level == 1) {
        // Balanced: 9-tap blur
        for (int i = 0; i < 9; i++) {
            float weight = WEIGHTS_9[i];
            vec2 offset = tex_offset * float(i);

            if (i == 0) {
                result += texture(TEXTURE, UV) * weight;
                total_weight += weight;
            } else {
                result += texture(TEXTURE, UV + offset) * weight;
                result += texture(TEXTURE, UV - offset) * weight;
                total_weight += weight * 2.0;
            }
        }
    } else {
        // High: Dynamic kernel based on blur amount
        int kernel_size = int(min(blur_amount, 15.0));
        float sigma = blur_amount / 3.0;

        for (int i = -kernel_size; i <= kernel_size; i++) {
            float x = float(i);
            float weight = exp(-(x * x) / (2.0 * sigma * sigma));
            vec2 offset = tex_offset * x / blur_amount;

            result += texture(TEXTURE, UV + offset) * weight;
            total_weight += weight;
        }
    }

    result /= total_weight;

    // Apply mask
    vec4 original = texture(TEXTURE, UV);
    COLOR = mix(original, result, mask_value);
}
