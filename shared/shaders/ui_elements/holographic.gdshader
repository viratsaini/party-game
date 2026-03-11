shader_type canvas_item;
render_mode blend_mix;

// Holographic Projection Shader
// Sci-fi hologram effect with scanlines, flicker, and color separation
// Perfect for futuristic UI elements

group_uniforms hologram_color;
uniform vec3 primary_color : source_color = vec3(0.0, 0.8, 1.0);
uniform vec3 secondary_color : source_color = vec3(0.0, 0.4, 0.8);
uniform float color_shift_speed : hint_range(0.0, 5.0) = 1.0;
uniform float color_shift_amount : hint_range(0.0, 1.0) = 0.3;

group_uniforms scanlines;
uniform float scanline_count : hint_range(10.0, 500.0) = 100.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float scanline_speed : hint_range(0.0, 10.0) = 2.0;
uniform bool moving_scanlines = true;

group_uniforms flicker;
uniform float flicker_intensity : hint_range(0.0, 0.5) = 0.1;
uniform float flicker_speed : hint_range(1.0, 60.0) = 15.0;
uniform float glitch_probability : hint_range(0.0, 0.2) = 0.05;
uniform float glitch_intensity : hint_range(0.0, 0.1) = 0.02;

group_uniforms edge_effects;
uniform float edge_glow : hint_range(0.0, 2.0) = 1.0;
uniform float edge_thickness : hint_range(0.001, 0.02) = 0.005;
uniform float fresnel_power : hint_range(0.0, 5.0) = 2.0;
uniform float transparency : hint_range(0.0, 1.0) = 0.3;

group_uniforms distortion;
uniform float wave_distortion : hint_range(0.0, 0.05) = 0.01;
uniform float wave_frequency : hint_range(1.0, 20.0) = 5.0;
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.005;

group_uniforms quality;
uniform int quality_level : hint_range(0, 2) = 2;
uniform bool enabled = true;

float random(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(float x) {
    float i = floor(x);
    float f = fract(x);
    return mix(random(vec2(i, 0.0)), random(vec2(i + 1.0, 0.0)), smoothstep(0.0, 1.0, f));
}

void fragment() {
    if (!enabled) {
        COLOR = texture(TEXTURE, UV);
        return;
    }

    vec2 uv = UV;

    // Wave distortion
    float wave = sin(uv.y * wave_frequency + TIME * 2.0) * wave_distortion;
    uv.x += wave;

    // Glitch offset
    float glitch_time = floor(TIME * 10.0);
    if (random(vec2(glitch_time, 0.0)) < glitch_probability) {
        float glitch_offset = (random(vec2(glitch_time, 1.0)) - 0.5) * glitch_intensity;
        if (random(vec2(glitch_time, UV.y * 10.0)) > 0.5) {
            uv.x += glitch_offset;
        }
    }

    // Sample with chromatic aberration
    vec4 color;
    if (quality_level >= 1 && chromatic_aberration > 0.0) {
        color.r = texture(TEXTURE, uv + vec2(chromatic_aberration, 0.0)).r;
        color.g = texture(TEXTURE, uv).g;
        color.b = texture(TEXTURE, uv - vec2(chromatic_aberration, 0.0)).b;
        color.a = texture(TEXTURE, uv).a;
    } else {
        color = texture(TEXTURE, uv);
    }

    if (color.a < 0.01) {
        discard;
    }

    // Convert to grayscale for hologram tinting
    float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));

    // Color shifting
    float color_phase = sin(TIME * color_shift_speed) * 0.5 + 0.5;
    vec3 holo_color = mix(primary_color, secondary_color, color_phase * color_shift_amount);

    // Apply hologram color
    vec3 result = holo_color * luminance;

    // Edge detection for glow
    float edge = 0.0;
    if (quality_level >= 1 && edge_glow > 0.0) {
        float center = texture(TEXTURE, UV).a;
        float left = texture(TEXTURE, UV + vec2(-edge_thickness, 0.0)).a;
        float right = texture(TEXTURE, UV + vec2(edge_thickness, 0.0)).a;
        float top = texture(TEXTURE, UV + vec2(0.0, -edge_thickness)).a;
        float bottom = texture(TEXTURE, UV + vec2(0.0, edge_thickness)).a;

        edge = abs(center - left) + abs(center - right) + abs(center - top) + abs(center - bottom);
        edge = clamp(edge * edge_glow, 0.0, 1.0);
        result += holo_color * edge * 2.0;
    }

    // Scanlines
    float scanline_y = UV.y * scanline_count;
    if (moving_scanlines) {
        scanline_y += TIME * scanline_speed;
    }
    float scanline = sin(scanline_y * 3.14159) * 0.5 + 0.5;
    scanline = pow(scanline, 2.0);
    result *= 1.0 - scanline * scanline_intensity;

    // Horizontal lines (every N pixels)
    float h_line = step(0.98, fract(UV.y * scanline_count * 0.1 + TIME * 0.5));
    result += holo_color * h_line * 0.5;

    // Flicker
    float flicker = 1.0 + (noise(TIME * flicker_speed) - 0.5) * flicker_intensity;
    result *= flicker;

    // Fresnel-like edge brightness
    float fresnel = pow(1.0 - abs(UV.x - 0.5) * 2.0, fresnel_power) *
                   pow(1.0 - abs(UV.y - 0.5) * 2.0, fresnel_power);
    fresnel = 1.0 - fresnel * 0.3;
    result *= fresnel;

    // Calculate final alpha
    float alpha = color.a * (transparency + edge + luminance * 0.5);
    alpha = clamp(alpha, 0.0, 1.0);

    COLOR = vec4(result, alpha);
}
