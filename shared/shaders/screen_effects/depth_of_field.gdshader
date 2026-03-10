shader_type canvas_item;
render_mode blend_mix;

// Depth of Field Shader
// Simulates camera focus with adjustable focal plane
// Perfect for UI layer separation

group_uniforms depth_of_field;
uniform float focal_depth : hint_range(0.0, 1.0) = 0.5;
uniform float focal_range : hint_range(0.0, 0.5) = 0.1;
uniform float blur_amount : hint_range(0.0, 0.02) = 0.005;
uniform float bokeh_brightness : hint_range(1.0, 2.0) = 1.2;
uniform bool bokeh_shape = true; // true = circular, false = hexagonal

group_uniforms layer_depth;
uniform sampler2D depth_texture : hint_default_white;
uniform bool use_depth_texture = false;
uniform float manual_depth : hint_range(0.0, 1.0) = 0.5;

group_uniforms quality;
uniform int quality_level : hint_range(0, 2) = 2;
uniform bool enabled = true;

// Hexagonal bokeh offsets
const vec2 HEX_OFFSETS[6] = {
    vec2(1.0, 0.0),
    vec2(0.5, 0.866),
    vec2(-0.5, 0.866),
    vec2(-1.0, 0.0),
    vec2(-0.5, -0.866),
    vec2(0.5, -0.866)
};

vec4 sample_bokeh(sampler2D tex, vec2 uv, float blur_size, int samples) {
    vec4 result = vec4(0.0);
    float total_weight = 0.0;

    if (bokeh_shape) {
        // Circular bokeh
        for (int i = 0; i < samples; i++) {
            float angle = float(i) * 6.283 / float(samples);
            for (int j = 1; j <= 3; j++) {
                float r = float(j) / 3.0;
                vec2 offset = vec2(cos(angle), sin(angle)) * blur_size * r;
                vec4 s = texture(tex, uv + offset);
                float brightness = dot(s.rgb, vec3(0.299, 0.587, 0.114));
                float weight = 1.0 + brightness * (bokeh_brightness - 1.0);
                result += s * weight;
                total_weight += weight;
            }
        }
    } else {
        // Hexagonal bokeh
        for (int i = 0; i < 6; i++) {
            for (int j = 1; j <= 3; j++) {
                float r = float(j) / 3.0;
                vec2 offset = HEX_OFFSETS[i] * blur_size * r;
                vec4 s = texture(tex, uv + offset);
                float brightness = dot(s.rgb, vec3(0.299, 0.587, 0.114));
                float weight = 1.0 + brightness * (bokeh_brightness - 1.0);
                result += s * weight;
                total_weight += weight;
            }
        }
    }

    // Add center sample
    vec4 center = texture(tex, uv);
    result += center;
    total_weight += 1.0;

    return result / total_weight;
}

void fragment() {
    if (!enabled) {
        COLOR = texture(TEXTURE, UV);
        return;
    }

    float depth = use_depth_texture ? texture(depth_texture, UV).r : manual_depth;
    float distance_from_focus = abs(depth - focal_depth);
    float blur_factor = smoothstep(0.0, focal_range, distance_from_focus);

    if (blur_factor < 0.01) {
        COLOR = texture(TEXTURE, UV);
        return;
    }

    float blur_size = blur_amount * blur_factor;
    int samples = quality_level == 0 ? 4 : (quality_level == 1 ? 8 : 12);

    COLOR = sample_bokeh(TEXTURE, UV, blur_size, samples);
}
