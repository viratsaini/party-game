shader_type canvas_item;
render_mode blend_mix;

// Neon Glow Tubes Shader
// Creates realistic neon sign effect with glow, flicker, and gas discharge simulation
// Perfect for retro/cyberpunk UI elements

group_uniforms neon_color;
uniform vec3 neon_color_primary : source_color = vec3(1.0, 0.1, 0.5);
uniform vec3 neon_color_secondary : source_color = vec3(0.1, 0.5, 1.0);
uniform bool dual_color = false;
uniform float color_blend : hint_range(0.0, 1.0) = 0.5;
uniform float color_cycle_speed : hint_range(0.0, 2.0) = 0.0;

group_uniforms glow;
uniform float inner_glow : hint_range(0.5, 3.0) = 1.5;
uniform float outer_glow : hint_range(0.0, 2.0) = 1.0;
uniform float glow_falloff : hint_range(0.5, 5.0) = 2.0;
uniform float glow_radius : hint_range(0.0, 0.2) = 0.05;
uniform vec3 ambient_glow : source_color = vec3(0.1, 0.05, 0.15);

group_uniforms tube_properties;
uniform float tube_brightness : hint_range(0.5, 3.0) = 2.0;
uniform float tube_saturation : hint_range(0.0, 2.0) = 1.2;
uniform float gas_density : hint_range(0.0, 1.0) = 0.3;
uniform bool show_tube_glass = true;
uniform float tube_glass_opacity : hint_range(0.0, 0.5) = 0.1;

group_uniforms flicker;
uniform bool flicker_enabled = true;
uniform float flicker_speed : hint_range(1.0, 60.0) = 15.0;
uniform float flicker_intensity : hint_range(0.0, 0.5) = 0.1;
uniform float flicker_randomness : hint_range(0.0, 1.0) = 0.5;
uniform bool broken_segment = false;
uniform float broken_on_ratio : hint_range(0.0, 1.0) = 0.3;

group_uniforms electric;
uniform bool electric_arc = false;
uniform float arc_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float arc_frequency : hint_range(1.0, 20.0) = 8.0;
uniform float arc_speed : hint_range(0.0, 10.0) = 5.0;

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

float noise2d(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    if (!enabled) {
        COLOR = tex_color;
        return;
    }

    // Base luminance from texture
    float luminance = tex_color.a;

    if (luminance < 0.01) {
        COLOR = vec4(ambient_glow * outer_glow * 0.1, 0.1);
        return;
    }

    // Determine neon color
    vec3 neon_col = neon_color_primary;
    if (dual_color) {
        float blend = color_blend;
        if (color_cycle_speed > 0.0) {
            blend = sin(TIME * color_cycle_speed) * 0.5 + 0.5;
        }
        neon_col = mix(neon_color_primary, neon_color_secondary, blend);
    }

    // Apply flicker
    float flicker_value = 1.0;
    if (flicker_enabled) {
        float flicker_time = TIME * flicker_speed;
        float base_flicker = noise(flicker_time);
        float random_flicker = noise(flicker_time * 3.7 + 100.0) * flicker_randomness;
        flicker_value = 1.0 - (base_flicker + random_flicker) * flicker_intensity;

        // Broken segment effect
        if (broken_segment) {
            float on_time = noise(floor(TIME * 2.0));
            if (on_time > broken_on_ratio) {
                flicker_value *= 0.05;
            }
        }
    }

    // Gas discharge effect (inner glow variation)
    float gas_effect = 1.0;
    if (gas_density > 0.0 && quality_level >= 1) {
        gas_effect = noise2d(UV * 20.0 + TIME * 0.5) * gas_density + (1.0 - gas_density);
    }

    // Calculate glow layers
    // Inner bright core
    float core = luminance * inner_glow * tube_brightness * flicker_value * gas_effect;

    // Outer glow (edge detection based)
    float outer = 0.0;
    if (outer_glow > 0.0 && quality_level >= 1) {
        float glow_sum = 0.0;
        int samples = quality_level == 1 ? 4 : 8;

        for (int i = 0; i < samples; i++) {
            float angle = float(i) * 6.283 / float(samples);
            vec2 offset = vec2(cos(angle), sin(angle)) * glow_radius;
            glow_sum += texture(TEXTURE, UV + offset).a;
        }
        glow_sum /= float(samples);

        outer = max(glow_sum - luminance * 0.5, 0.0) * outer_glow;
        outer = pow(outer, 1.0 / glow_falloff);
    }

    // Electric arc effect
    float arc = 0.0;
    if (electric_arc && luminance > 0.5 && quality_level >= 2) {
        float arc_noise = noise2d(UV * arc_frequency + vec2(TIME * arc_speed, 0.0));
        arc = pow(arc_noise, 4.0) * arc_intensity * flicker_value;
    }

    // Build final color
    vec3 result = neon_col * core;

    // Add outer glow
    result += neon_col * outer * 0.5;

    // Add electric arc
    result += vec3(1.0) * arc;

    // Add ambient glow
    result += ambient_glow * (outer + luminance * 0.1);

    // Tube glass effect
    if (show_tube_glass && luminance > 0.1) {
        float glass_highlight = pow(1.0 - abs(UV.x - 0.5) * 2.0, 3.0) * tube_glass_opacity;
        result += vec3(glass_highlight);
    }

    // Apply saturation
    float gray = dot(result, vec3(0.299, 0.587, 0.114));
    result = mix(vec3(gray), result, tube_saturation);

    // Calculate alpha
    float alpha = min(core + outer * 0.5 + arc, 1.0);

    COLOR = vec4(result, alpha);
}
