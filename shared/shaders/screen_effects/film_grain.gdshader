shader_type canvas_item;
render_mode blend_mix;

// Film Grain Shader
// Adds cinematic film grain with adjustable intensity and animation
// Supports different grain patterns and color tinting

group_uniforms grain;
uniform float grain_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float grain_size : hint_range(0.5, 4.0) = 1.0;
uniform float grain_speed : hint_range(0.0, 60.0) = 24.0;
uniform bool colored_grain = false;
uniform float color_variation : hint_range(0.0, 1.0) = 0.3;

group_uniforms luminance;
uniform bool luminance_dependent = true;
uniform float shadow_grain : hint_range(0.0, 2.0) = 1.5;
uniform float highlight_grain : hint_range(0.0, 2.0) = 0.5;

group_uniforms quality;
uniform int quality_level : hint_range(0, 2) = 2;
uniform bool enabled = true;

float random(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // Smoothstep

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value;
}

void fragment() {
    vec4 color = texture(TEXTURE, UV);

    if (!enabled) {
        COLOR = color;
        return;
    }

    vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
    float time_seed = floor(TIME * grain_speed);

    vec2 grain_uv = UV * screen_size / grain_size;
    grain_uv += vec2(time_seed * 123.456, time_seed * 789.012);

    float grain;
    int octaves = quality_level == 0 ? 1 : (quality_level == 1 ? 2 : 3);

    grain = fbm(grain_uv, octaves) * 2.0 - 1.0;

    // Add some high-frequency detail
    if (quality_level >= 1) {
        grain += (random(grain_uv + time_seed) - 0.5) * 0.5;
    }

    // Luminance-dependent grain
    if (luminance_dependent) {
        float luminance = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
        float shadow_factor = pow(1.0 - luminance, 2.0) * shadow_grain;
        float highlight_factor = pow(luminance, 2.0) * highlight_grain;
        grain *= mix(1.0, shadow_factor + highlight_factor, 0.5);
    }

    grain *= grain_intensity;

    vec3 result;
    if (colored_grain) {
        vec3 color_grain;
        color_grain.r = grain + (random(grain_uv + vec2(1.0, 0.0) + time_seed) - 0.5) * color_variation * grain_intensity;
        color_grain.g = grain + (random(grain_uv + vec2(0.0, 1.0) + time_seed) - 0.5) * color_variation * grain_intensity;
        color_grain.b = grain + (random(grain_uv + vec2(1.0, 1.0) + time_seed) - 0.5) * color_variation * grain_intensity;
        result = color.rgb + color_grain;
    } else {
        result = color.rgb + vec3(grain);
    }

    COLOR = vec4(clamp(result, vec3(0.0), vec3(1.0)), color.a);
}
