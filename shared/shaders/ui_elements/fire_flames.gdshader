shader_type canvas_item;
render_mode blend_mix;

// Fire/Flames Shader
// Creates realistic animated fire effect
// Perfect for UI effects, torches, and burning elements

group_uniforms fire_colors;
uniform vec3 fire_color_core : source_color = vec3(1.0, 0.9, 0.5);
uniform vec3 fire_color_mid : source_color = vec3(1.0, 0.5, 0.1);
uniform vec3 fire_color_outer : source_color = vec3(0.8, 0.2, 0.0);
uniform vec3 fire_color_smoke : source_color = vec3(0.1, 0.1, 0.1);
uniform float color_intensity : hint_range(0.5, 3.0) = 1.5;

group_uniforms fire_shape;
uniform float fire_height : hint_range(0.5, 2.0) = 1.0;
uniform float fire_width : hint_range(0.5, 2.0) = 1.0;
uniform float flame_sharpness : hint_range(0.5, 5.0) = 2.0;
uniform float flame_detail : hint_range(1.0, 10.0) = 5.0;

group_uniforms animation;
uniform float animation_speed : hint_range(0.0, 5.0) = 2.0;
uniform float turbulence : hint_range(0.0, 1.0) = 0.5;
uniform float flicker_speed : hint_range(0.0, 10.0) = 3.0;
uniform float flicker_intensity : hint_range(0.0, 0.5) = 0.2;

group_uniforms effects;
uniform bool add_smoke = false;
uniform float smoke_amount : hint_range(0.0, 1.0) = 0.3;
uniform bool add_embers = true;
uniform float ember_density : hint_range(0.0, 1.0) = 0.3;
uniform float ember_size : hint_range(0.001, 0.02) = 0.005;

group_uniforms quality;
uniform int quality_level : hint_range(0, 2) = 2;
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
    vec4 tex_color = texture(TEXTURE, UV);

    if (!enabled) {
        COLOR = tex_color;
        return;
    }

    float time = TIME * animation_speed;

    // Transform UV for fire shape
    vec2 uv = UV;
    uv.x = (uv.x - 0.5) / fire_width + 0.5;
    uv.y = 1.0 - uv.y / fire_height;

    // Add horizontal turbulence
    int octaves = quality_level == 0 ? 2 : (quality_level == 1 ? 3 : 4);
    float turb = fbm(vec2(uv.x * 3.0, uv.y * 2.0 - time), octaves);
    uv.x += (turb - 0.5) * turbulence * (1.0 - uv.y);

    // Calculate fire shape
    float center_dist = abs(uv.x - 0.5) * 2.0;
    float fire_shape = 1.0 - center_dist;
    fire_shape *= 1.0 - uv.y;
    fire_shape = pow(max(fire_shape, 0.0), flame_sharpness);

    // Add flame detail
    float detail = fbm(vec2(uv.x * flame_detail, uv.y * flame_detail - time * 1.5), octaves);
    fire_shape *= 0.5 + detail;

    // Flicker effect
    float flicker = 1.0 + (noise(vec2(time * flicker_speed, 0.0)) - 0.5) * flicker_intensity;
    fire_shape *= flicker;

    // Color based on intensity
    vec3 fire_color;
    if (fire_shape > 0.7) {
        fire_color = mix(fire_color_mid, fire_color_core, (fire_shape - 0.7) / 0.3);
    } else if (fire_shape > 0.3) {
        fire_color = mix(fire_color_outer, fire_color_mid, (fire_shape - 0.3) / 0.4);
    } else {
        fire_color = mix(vec3(0.0), fire_color_outer, fire_shape / 0.3);
    }

    fire_color *= color_intensity;

    // Add embers
    float embers = 0.0;
    if (add_embers && quality_level >= 1) {
        for (int i = 0; i < 5; i++) {
            vec2 ember_uv = UV;
            float ember_seed = float(i) * 1.234;
            float ember_time = time * (0.5 + random(vec2(ember_seed, 0.0)) * 0.5);

            ember_uv.y = fract(ember_uv.y + ember_time * 0.3 + ember_seed);
            ember_uv.x += sin(ember_time + ember_seed) * 0.2;

            float ember = random(floor(ember_uv * 50.0) + vec2(ember_seed));

            if (ember > 1.0 - ember_density) {
                vec2 ember_pos = fract(ember_uv * 50.0);
                float ember_dist = length(ember_pos - 0.5);
                float ember_glow = smoothstep(ember_size, 0.0, ember_dist);
                embers += ember_glow * (1.0 - UV.y);
            }
        }
    }

    fire_color += fire_color_core * embers;

    // Add smoke
    vec3 smoke = vec3(0.0);
    float smoke_alpha = 0.0;
    if (add_smoke) {
        float smoke_noise = fbm(vec2(uv.x * 3.0, uv.y * 2.0 - time * 0.5), octaves);
        float smoke_shape = (1.0 - center_dist) * uv.y;
        smoke_shape *= smoke_noise;
        smoke_shape = clamp(smoke_shape * smoke_amount, 0.0, 1.0);

        smoke = fire_color_smoke;
        smoke_alpha = smoke_shape * 0.5;
    }

    // Calculate final alpha
    float alpha = clamp(fire_shape + embers * 0.5, 0.0, 1.0);

    // Combine fire and smoke
    vec3 result = mix(smoke, fire_color, alpha / max(alpha + smoke_alpha, 0.001));
    float final_alpha = max(alpha, smoke_alpha);

    // Blend with texture
    result = mix(tex_color.rgb, result, final_alpha);
    final_alpha = max(tex_color.a, final_alpha);

    COLOR = vec4(result, final_alpha);
}
