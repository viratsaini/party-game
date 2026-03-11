shader_type canvas_item;
render_mode blend_mix;

// CRT Scanlines Shader
// Authentic retro CRT monitor effect with customizable parameters
// Includes phosphor glow, curvature, and flicker

group_uniforms scanlines;
uniform float scanline_count : hint_range(100.0, 1000.0) = 300.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float scanline_sharpness : hint_range(1.0, 10.0) = 3.0;
uniform bool interlaced = false;
uniform float interlace_speed : hint_range(0.5, 5.0) = 2.0;

group_uniforms screen_effects;
uniform float curvature : hint_range(0.0, 0.5) = 0.1;
uniform float corner_darkness : hint_range(0.0, 1.0) = 0.3;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.2;
uniform bool barrel_distortion = true;

group_uniforms phosphor;
uniform bool phosphor_enabled = true;
uniform float phosphor_intensity : hint_range(0.0, 1.0) = 0.2;
uniform vec3 phosphor_r : source_color = vec3(1.0, 0.0, 0.0);
uniform vec3 phosphor_g : source_color = vec3(0.0, 1.0, 0.0);
uniform vec3 phosphor_b : source_color = vec3(0.0, 0.0, 1.0);
uniform float phosphor_scale : hint_range(0.5, 3.0) = 1.0;

group_uniforms effects;
uniform float flicker_intensity : hint_range(0.0, 0.1) = 0.02;
uniform float flicker_speed : hint_range(1.0, 120.0) = 60.0;
uniform float noise_intensity : hint_range(0.0, 0.1) = 0.02;
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.002;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.1;

group_uniforms quality;
uniform int quality_level : hint_range(0, 2) = 2;
uniform bool enabled = true;

float random(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 curve_uv(vec2 uv, float amount) {
    uv = uv * 2.0 - 1.0;
    vec2 offset = abs(uv.yx) / vec2(amount + 0.0001);
    uv = uv + uv * offset * offset;
    uv = uv * 0.5 + 0.5;
    return uv;
}

vec3 apply_phosphor(vec2 uv, vec3 color, float scale) {
    float col = floor(uv.x * scale * 3.0);
    float phosphor_type = mod(col, 3.0);

    vec3 mask;
    if (phosphor_type < 1.0) {
        mask = phosphor_r;
    } else if (phosphor_type < 2.0) {
        mask = phosphor_g;
    } else {
        mask = phosphor_b;
    }

    return color * mix(vec3(1.0), mask, phosphor_intensity);
}

void fragment() {
    if (!enabled) {
        COLOR = texture(TEXTURE, UV);
        return;
    }

    vec2 uv = UV;
    vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;

    // Apply barrel distortion / curvature
    if (barrel_distortion && curvature > 0.0) {
        uv = curve_uv(uv, 1.0 / curvature);
    }

    // Check if we're outside the screen
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec3 color;

    // Chromatic aberration
    if (chromatic_aberration > 0.0 && quality_level > 0) {
        vec2 ca_offset = (uv - 0.5) * chromatic_aberration;
        color.r = texture(TEXTURE, uv + ca_offset).r;
        color.g = texture(TEXTURE, uv).g;
        color.b = texture(TEXTURE, uv - ca_offset).b;
    } else {
        color = texture(TEXTURE, uv).rgb;
    }

    // Apply glow (blur bright areas)
    if (glow_strength > 0.0 && quality_level >= 2) {
        vec3 glow = vec3(0.0);
        float glow_samples = 4.0;
        for (float i = -glow_samples; i <= glow_samples; i++) {
            for (float j = -glow_samples; j <= glow_samples; j++) {
                vec2 offset = vec2(i, j) * 0.002;
                glow += texture(TEXTURE, uv + offset).rgb;
            }
        }
        glow /= pow(glow_samples * 2.0 + 1.0, 2.0);
        color += glow * glow_strength;
    }

    // Apply phosphor mask
    if (phosphor_enabled && quality_level > 0) {
        color = apply_phosphor(uv * screen_size, color, phosphor_scale);
    }

    // Apply scanlines
    float scanline_y = uv.y * scanline_count;
    float scanline;

    if (interlaced) {
        float frame = floor(TIME * interlace_speed);
        scanline_y += mod(frame, 2.0) * 0.5;
    }

    scanline = sin(scanline_y * 3.14159 * 2.0) * 0.5 + 0.5;
    scanline = pow(scanline, scanline_sharpness);
    color *= 1.0 - scanline * scanline_intensity;

    // Apply flicker
    float flicker = 1.0 + (random(vec2(floor(TIME * flicker_speed), 0.0)) - 0.5) * flicker_intensity;
    color *= flicker;

    // Apply noise
    if (noise_intensity > 0.0) {
        float noise = random(uv + TIME) * noise_intensity;
        color += noise - noise_intensity * 0.5;
    }

    // Apply corner darkness / vignette
    vec2 corner_dist = abs(uv - 0.5) * 2.0;
    float corner = pow(corner_dist.x * corner_dist.y, corner_darkness);
    float vignette = 1.0 - length(uv - 0.5) * vignette_strength;
    color *= vignette * (1.0 - corner * corner_darkness);

    COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
