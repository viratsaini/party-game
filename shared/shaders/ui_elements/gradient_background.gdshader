shader_type canvas_item;
render_mode blend_mix;

// Gradient Background Shader
// Creates beautiful animated gradients with multiple styles
// Perfect for UI backgrounds, panels, and decorative elements

group_uniforms gradient_colors;
uniform vec3 color_1 : source_color = vec3(0.1, 0.2, 0.4);
uniform vec3 color_2 : source_color = vec3(0.3, 0.1, 0.5);
uniform vec3 color_3 : source_color = vec3(0.5, 0.2, 0.3);
uniform vec3 color_4 : source_color = vec3(0.2, 0.4, 0.3);
uniform int color_count : hint_range(2, 4) = 2;

group_uniforms gradient_type;
uniform int gradient_style : hint_range(0, 5) = 0;
// 0 = Linear, 1 = Radial, 2 = Angular, 3 = Diamond, 4 = Spiral, 5 = Wave

uniform float gradient_angle : hint_range(0.0, 6.283) = 0.0;
uniform vec2 gradient_center = vec2(0.5, 0.5);
uniform float gradient_scale : hint_range(0.1, 5.0) = 1.0;

group_uniforms animation;
uniform bool animated = true;
uniform float animation_speed : hint_range(0.0, 2.0) = 0.5;
uniform float color_shift_speed : hint_range(0.0, 2.0) = 0.3;
uniform bool morphing = false;
uniform float morph_amount : hint_range(0.0, 0.5) = 0.1;

group_uniforms effects;
uniform float noise_amount : hint_range(0.0, 0.3) = 0.05;
uniform float dither_amount : hint_range(0.0, 0.1) = 0.02;
uniform bool add_vignette = false;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;

group_uniforms blend;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform bool multiply_texture = false;

group_uniforms quality;
uniform bool enabled = true;

float random(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 gradient_color(float t, float time) {
    // Shift colors over time
    t = fract(t + time * color_shift_speed);

    if (color_count == 2) {
        return mix(color_1, color_2, t);
    } else if (color_count == 3) {
        if (t < 0.5) {
            return mix(color_1, color_2, t * 2.0);
        } else {
            return mix(color_2, color_3, (t - 0.5) * 2.0);
        }
    } else {
        if (t < 0.333) {
            return mix(color_1, color_2, t * 3.0);
        } else if (t < 0.666) {
            return mix(color_2, color_3, (t - 0.333) * 3.0);
        } else {
            return mix(color_3, color_4, (t - 0.666) * 3.0);
        }
    }
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    if (!enabled) {
        COLOR = tex_color;
        return;
    }

    float time = animated ? TIME * animation_speed : 0.0;
    vec2 uv = UV;

    // Apply morphing distortion
    if (morphing) {
        float morph_noise = noise(uv * 5.0 + time);
        uv += (vec2(morph_noise) - 0.5) * morph_amount;
    }

    vec2 centered = uv - gradient_center;
    float t = 0.0;

    if (gradient_style == 0) {
        // Linear gradient
        float c = cos(gradient_angle);
        float s = sin(gradient_angle);
        t = (centered.x * c + centered.y * s) / gradient_scale + 0.5;
    } else if (gradient_style == 1) {
        // Radial gradient
        t = length(centered) / gradient_scale;
    } else if (gradient_style == 2) {
        // Angular/Conic gradient
        t = (atan(centered.y, centered.x) + 3.14159) / 6.28318;
        t = fract(t + gradient_angle / 6.28318);
    } else if (gradient_style == 3) {
        // Diamond gradient
        t = (abs(centered.x) + abs(centered.y)) / gradient_scale;
    } else if (gradient_style == 4) {
        // Spiral gradient
        float angle = atan(centered.y, centered.x);
        float dist = length(centered);
        t = fract((angle / 6.28318 + dist * gradient_scale) + time);
    } else {
        // Wave gradient
        float wave = sin(centered.x * gradient_scale * 10.0 + time * 2.0) * 0.1;
        t = centered.y / gradient_scale + 0.5 + wave;
    }

    // Apply noise
    if (noise_amount > 0.0) {
        float n = noise(uv * 20.0 + time * 0.5);
        t += (n - 0.5) * noise_amount;
    }

    t = clamp(t, 0.0, 1.0);

    // Get gradient color
    vec3 grad_color = gradient_color(t, time);

    // Apply dithering to reduce banding
    if (dither_amount > 0.0) {
        float dither = (random(uv * 1000.0 + time) - 0.5) * dither_amount;
        grad_color += vec3(dither);
    }

    // Apply vignette
    if (add_vignette) {
        float vignette = 1.0 - length(UV - 0.5) * vignette_strength * 2.0;
        grad_color *= vignette;
    }

    // Combine with texture
    vec3 final_color;
    if (multiply_texture) {
        final_color = grad_color * tex_color.rgb;
    } else {
        final_color = mix(tex_color.rgb, grad_color, opacity);
    }

    COLOR = vec4(final_color, tex_color.a);
}
