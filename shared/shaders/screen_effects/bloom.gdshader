shader_type canvas_item;
render_mode blend_mix;

// Bloom Shader with Threshold
// High-quality bloom with adjustable threshold and color tinting
// Supports HDR-style bloom effects

group_uniforms bloom;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.7;
uniform float bloom_intensity : hint_range(0.0, 3.0) = 1.0;
uniform float bloom_spread : hint_range(0.0, 0.02) = 0.005;
uniform vec3 bloom_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float bloom_softness : hint_range(0.0, 1.0) = 0.5;

group_uniforms anamorphic;
uniform bool anamorphic_enabled = false;
uniform float anamorphic_ratio : hint_range(0.0, 1.0) = 0.5;
uniform float anamorphic_angle : hint_range(0.0, 3.14159) = 0.0;

group_uniforms quality;
uniform int quality_level : hint_range(0, 2) = 2;
uniform bool enabled = true;

vec3 extract_bright(vec3 color, float threshold, float softness) {
    float brightness = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float soft_threshold = threshold * (1.0 - softness);
    float contribution = smoothstep(soft_threshold, threshold, brightness);
    return color * contribution;
}

vec4 sample_bloom(sampler2D tex, vec2 uv, float spread, int passes) {
    vec4 result = vec4(0.0);
    float total_weight = 0.0;

    // Gaussian weights for 13-tap blur
    float weights[7] = { 0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216, 0.004054, 0.001014 };

    vec2 blur_dir = anamorphic_enabled ?
        vec2(cos(anamorphic_angle), sin(anamorphic_angle)) :
        vec2(1.0, 0.0);

    vec2 blur_scale = anamorphic_enabled ?
        vec2(1.0, 1.0 - anamorphic_ratio) :
        vec2(1.0, 1.0);

    // Horizontal pass
    for (int i = -passes; i <= passes; i++) {
        float weight = weights[abs(i)];
        vec2 offset = blur_dir * float(i) * spread * blur_scale;
        vec4 s = texture(tex, uv + offset);
        vec3 bright = extract_bright(s.rgb, bloom_threshold, bloom_softness);
        result.rgb += bright * weight;
        result.a += s.a * weight;
        total_weight += weight;
    }

    // Vertical pass (perpendicular to horizontal)
    vec2 perp_dir = vec2(-blur_dir.y, blur_dir.x);
    for (int i = -passes; i <= passes; i++) {
        if (i == 0) continue; // Skip center (already sampled)
        float weight = weights[abs(i)] * 0.7; // Slightly less weight for second pass
        vec2 offset = perp_dir * float(i) * spread * blur_scale.yx;
        vec4 s = texture(tex, uv + offset);
        vec3 bright = extract_bright(s.rgb, bloom_threshold, bloom_softness);
        result.rgb += bright * weight;
        total_weight += weight;
    }

    return result / total_weight;
}

void fragment() {
    vec4 original = texture(TEXTURE, UV);

    if (!enabled) {
        COLOR = original;
        return;
    }

    int passes = quality_level == 0 ? 3 : (quality_level == 1 ? 5 : 6);

    vec4 bloom = sample_bloom(TEXTURE, UV, bloom_spread, passes);
    bloom.rgb *= bloom_tint * bloom_intensity;

    // Additive blend
    COLOR.rgb = original.rgb + bloom.rgb;
    COLOR.a = original.a;

    // Tone mapping to prevent over-saturation
    COLOR.rgb = COLOR.rgb / (COLOR.rgb + vec3(1.0));
}
