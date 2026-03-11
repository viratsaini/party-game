shader_type canvas_item;
render_mode blend_mix;

// Color Grading Shader with LUT Support
// Professional color correction with LUT, curves, and color wheels
// Supports both texture LUT and procedural grading

group_uniforms lut;
uniform sampler2D lut_texture : filter_linear;
uniform bool use_lut = false;
uniform float lut_strength : hint_range(0.0, 1.0) = 1.0;
uniform int lut_size : hint_range(8, 64) = 32;

group_uniforms color_adjustments;
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float gamma : hint_range(0.1, 3.0) = 1.0;
uniform float exposure : hint_range(-3.0, 3.0) = 0.0;

group_uniforms color_balance;
uniform vec3 shadows_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 midtones_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 highlights_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float shadows_weight : hint_range(0.0, 1.0) = 0.3;
uniform float highlights_weight : hint_range(0.0, 1.0) = 0.7;

group_uniforms split_toning;
uniform vec3 shadows_tint : source_color = vec3(0.5, 0.5, 0.5);
uniform vec3 highlights_tint : source_color = vec3(0.5, 0.5, 0.5);
uniform float split_balance : hint_range(-1.0, 1.0) = 0.0;

group_uniforms curves;
uniform vec4 red_curve = vec4(0.0, 0.33, 0.67, 1.0);
uniform vec4 green_curve = vec4(0.0, 0.33, 0.67, 1.0);
uniform vec4 blue_curve = vec4(0.0, 0.33, 0.67, 1.0);
uniform bool curves_enabled = false;

group_uniforms quality;
uniform bool enabled = true;

vec3 apply_lut(vec3 color, sampler2D lut, int size) {
    float scale = float(size - 1) / float(size);
    float offset = 0.5 / float(size);

    // LUT is arranged as a strip of slices
    float blue_slice = color.b * float(size - 1);
    float blue_floor = floor(blue_slice);
    float blue_frac = blue_slice - blue_floor;

    vec2 uv1 = vec2(
        (color.r * scale + offset) / float(size) + blue_floor / float(size),
        color.g * scale + offset
    );

    vec2 uv2 = vec2(
        (color.r * scale + offset) / float(size) + (blue_floor + 1.0) / float(size),
        color.g * scale + offset
    );

    vec3 color1 = texture(lut, uv1).rgb;
    vec3 color2 = texture(lut, uv2).rgb;

    return mix(color1, color2, blue_frac);
}

float apply_curve(float value, vec4 curve) {
    // Simple cubic bezier curve approximation
    float t = value;
    float t2 = t * t;
    float t3 = t2 * t;
    float mt = 1.0 - t;
    float mt2 = mt * mt;
    float mt3 = mt2 * mt;

    return mt3 * curve.x + 3.0 * mt2 * t * curve.y + 3.0 * mt * t2 * curve.z + t3 * curve.w;
}

vec3 rgb_to_hsl(vec3 color) {
    float max_c = max(max(color.r, color.g), color.b);
    float min_c = min(min(color.r, color.g), color.b);
    float delta = max_c - min_c;

    float l = (max_c + min_c) * 0.5;
    float s = 0.0;
    float h = 0.0;

    if (delta > 0.0001) {
        s = l < 0.5 ? delta / (max_c + min_c) : delta / (2.0 - max_c - min_c);

        if (max_c == color.r) {
            h = (color.g - color.b) / delta + (color.g < color.b ? 6.0 : 0.0);
        } else if (max_c == color.g) {
            h = (color.b - color.r) / delta + 2.0;
        } else {
            h = (color.r - color.g) / delta + 4.0;
        }
        h /= 6.0;
    }

    return vec3(h, s, l);
}

vec3 hsl_to_rgb(vec3 hsl) {
    if (hsl.y == 0.0) {
        return vec3(hsl.z);
    }

    float q = hsl.z < 0.5 ? hsl.z * (1.0 + hsl.y) : hsl.z + hsl.y - hsl.z * hsl.y;
    float p = 2.0 * hsl.z - q;

    vec3 t = vec3(hsl.x + 1.0/3.0, hsl.x, hsl.x - 1.0/3.0);
    t = fract(t);

    vec3 result;
    for (int i = 0; i < 3; i++) {
        if (t[i] < 1.0/6.0) {
            result[i] = p + (q - p) * 6.0 * t[i];
        } else if (t[i] < 0.5) {
            result[i] = q;
        } else if (t[i] < 2.0/3.0) {
            result[i] = p + (q - p) * (2.0/3.0 - t[i]) * 6.0;
        } else {
            result[i] = p;
        }
    }

    return result;
}

void fragment() {
    vec4 color = texture(TEXTURE, UV);

    if (!enabled) {
        COLOR = color;
        return;
    }

    vec3 result = color.rgb;

    // Apply exposure
    result *= pow(2.0, exposure);

    // Apply curves if enabled
    if (curves_enabled) {
        result.r = apply_curve(result.r, red_curve);
        result.g = apply_curve(result.g, green_curve);
        result.b = apply_curve(result.b, blue_curve);
    }

    // Apply brightness and contrast
    result = (result - 0.5) * contrast + 0.5 + brightness;

    // Apply gamma
    result = pow(max(result, vec3(0.0)), vec3(1.0 / gamma));

    // Apply saturation
    float luminance = dot(result, vec3(0.2126, 0.7152, 0.0722));
    result = mix(vec3(luminance), result, saturation);

    // Apply color balance
    float lum = dot(result, vec3(0.2126, 0.7152, 0.0722));
    vec3 shadows_factor = (1.0 - smoothstep(0.0, shadows_weight, lum)) * (shadows_color - vec3(1.0));
    vec3 highlights_factor = smoothstep(highlights_weight, 1.0, lum) * (highlights_color - vec3(1.0));
    vec3 midtones_factor = (1.0 - abs(lum - 0.5) * 2.0) * (midtones_color - vec3(1.0));
    result += shadows_factor + highlights_factor + midtones_factor;

    // Apply split toning
    float split_lum = dot(result, vec3(0.2126, 0.7152, 0.0722));
    float split_point = 0.5 + split_balance * 0.5;
    vec3 shadow_tone = (shadows_tint - vec3(0.5)) * 2.0 * (1.0 - smoothstep(0.0, split_point, split_lum));
    vec3 highlight_tone = (highlights_tint - vec3(0.5)) * 2.0 * smoothstep(split_point, 1.0, split_lum);
    result += shadow_tone + highlight_tone;

    // Apply LUT if enabled
    if (use_lut) {
        vec3 lut_color = apply_lut(clamp(result, vec3(0.0), vec3(1.0)), lut_texture, lut_size);
        result = mix(result, lut_color, lut_strength);
    }

    COLOR = vec4(clamp(result, vec3(0.0), vec3(1.0)), color.a);
}
