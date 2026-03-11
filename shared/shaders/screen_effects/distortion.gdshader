shader_type canvas_item;
render_mode blend_mix;

// Screen Distortion Shader
// Various distortion effects including wave, twist, and pixelation
// Great for transitions and special effects

group_uniforms wave;
uniform bool wave_enabled = false;
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.02;
uniform float wave_frequency : hint_range(1.0, 50.0) = 10.0;
uniform float wave_speed : hint_range(0.0, 10.0) = 2.0;
uniform vec2 wave_direction = vec2(1.0, 0.0);

group_uniforms twist;
uniform bool twist_enabled = false;
uniform vec2 twist_center = vec2(0.5, 0.5);
uniform float twist_amount : hint_range(-10.0, 10.0) = 1.0;
uniform float twist_radius : hint_range(0.0, 1.0) = 0.5;
uniform float twist_falloff : hint_range(0.1, 5.0) = 2.0;

group_uniforms pixelate;
uniform bool pixelate_enabled = false;
uniform float pixel_size : hint_range(1.0, 100.0) = 8.0;
uniform bool smooth_pixels = false;

group_uniforms fisheye;
uniform bool fisheye_enabled = false;
uniform float fisheye_strength : hint_range(-1.0, 1.0) = 0.3;
uniform vec2 fisheye_center = vec2(0.5, 0.5);

group_uniforms kaleidoscope;
uniform bool kaleidoscope_enabled = false;
uniform int kaleidoscope_segments : hint_range(2, 16) = 6;
uniform float kaleidoscope_rotation : hint_range(0.0, 6.283) = 0.0;

group_uniforms quality;
uniform bool enabled = true;

vec2 apply_wave(vec2 uv, float time) {
    vec2 wave_uv = uv;
    float wave = sin((dot(uv, wave_direction) * wave_frequency) + time * wave_speed) * wave_amplitude;
    wave_uv += vec2(-wave_direction.y, wave_direction.x) * wave;
    return wave_uv;
}

vec2 apply_twist(vec2 uv, vec2 center, float amount, float radius, float falloff) {
    vec2 delta = uv - center;
    float dist = length(delta);
    float angle = atan(delta.y, delta.x);

    float twist_factor = 1.0 - smoothstep(0.0, radius, dist);
    twist_factor = pow(twist_factor, 1.0 / falloff);

    angle += twist_factor * amount;

    return center + vec2(cos(angle), sin(angle)) * dist;
}

vec2 apply_pixelate(vec2 uv, float size, vec2 screen_size) {
    vec2 pixel_uv = uv * screen_size;
    pixel_uv = floor(pixel_uv / size) * size + size * 0.5;
    return pixel_uv / screen_size;
}

vec2 apply_fisheye(vec2 uv, vec2 center, float strength) {
    vec2 delta = uv - center;
    float dist = length(delta);
    float dist2 = dist * dist;

    float bind = length(vec2(0.5, 0.5));

    if (strength > 0.0) {
        // Barrel distortion
        float power = (2.0 * PI / (2.0 * sqrt(bind))) * strength;
        float radius = sqrt(dist2);
        float r = radius * power;
        float theta = atan(delta.y, delta.x);

        float new_radius = (r > 0.0) ? tan(r) / power : r;

        return center + new_radius * vec2(cos(theta), sin(theta));
    } else {
        // Pincushion distortion
        float power = -strength;
        float new_dist = dist * (1.0 + dist2 * power);
        return center + normalize(delta + vec2(0.0001)) * new_dist;
    }
}

vec2 apply_kaleidoscope(vec2 uv, int segments, float rotation) {
    vec2 center = vec2(0.5, 0.5);
    vec2 delta = uv - center;

    float angle = atan(delta.y, delta.x) + rotation;
    float segment_angle = PI * 2.0 / float(segments);

    angle = mod(angle, segment_angle);
    if (angle > segment_angle * 0.5) {
        angle = segment_angle - angle;
    }

    float dist = length(delta);
    return center + vec2(cos(angle), sin(angle)) * dist;
}

void fragment() {
    if (!enabled) {
        COLOR = texture(TEXTURE, UV);
        return;
    }

    vec2 uv = UV;
    vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;

    // Apply effects in order
    if (kaleidoscope_enabled) {
        uv = apply_kaleidoscope(uv, kaleidoscope_segments, kaleidoscope_rotation);
    }

    if (wave_enabled) {
        uv = apply_wave(uv, TIME);
    }

    if (twist_enabled) {
        uv = apply_twist(uv, twist_center, twist_amount, twist_radius, twist_falloff);
    }

    if (fisheye_enabled) {
        uv = apply_fisheye(uv, fisheye_center, fisheye_strength);
    }

    if (pixelate_enabled) {
        uv = apply_pixelate(uv, pixel_size, screen_size);
    }

    // Clamp UV to valid range
    uv = clamp(uv, vec2(0.0), vec2(1.0));

    vec4 color = texture(TEXTURE, uv);

    // Smooth pixel edges if enabled
    if (pixelate_enabled && smooth_pixels) {
        vec2 pixel_uv = UV * screen_size / pixel_size;
        vec2 pixel_fract = fract(pixel_uv);
        vec2 smooth_factor = smoothstep(vec2(0.0), vec2(0.1), pixel_fract) *
                            smoothstep(vec2(1.0), vec2(0.9), pixel_fract);
        color.a *= smooth_factor.x * smooth_factor.y;
    }

    COLOR = color;
}
