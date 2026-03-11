shader_type canvas_item;
render_mode blend_mix;

// Glass Refraction Shader
// Realistic glass effect with refraction, reflection, and frosted options
// Perfect for UI panels, windows, and overlays

group_uniforms glass_properties;
uniform vec3 glass_tint : source_color = vec3(0.9, 0.95, 1.0);
uniform float refraction_strength : hint_range(0.0, 0.1) = 0.02;
uniform float glass_opacity : hint_range(0.0, 1.0) = 0.3;
uniform float ior : hint_range(1.0, 2.0) = 1.5; // Index of refraction

group_uniforms frosted_glass;
uniform bool frosted = false;
uniform float frost_amount : hint_range(0.0, 1.0) = 0.5;
uniform float frost_scale : hint_range(1.0, 50.0) = 20.0;
uniform bool animated_frost = false;
uniform float frost_speed : hint_range(0.0, 2.0) = 0.5;

group_uniforms reflection;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.2;
uniform sampler2D reflection_texture : hint_default_white;
uniform bool use_reflection_texture = false;
uniform float fresnel_power : hint_range(0.5, 5.0) = 3.0;

group_uniforms surface;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.1;
uniform float thickness : hint_range(0.0, 1.0) = 0.5;
uniform bool double_sided = false;

group_uniforms edge_effects;
uniform float edge_highlight : hint_range(0.0, 1.0) = 0.3;
uniform float edge_thickness : hint_range(0.01, 0.1) = 0.02;
uniform vec3 edge_color : source_color = vec3(1.0, 1.0, 1.0);

group_uniforms lighting;
uniform vec2 light_position = vec2(0.3, 0.2);
uniform float specular_power : hint_range(1.0, 128.0) = 64.0;
uniform float specular_intensity : hint_range(0.0, 2.0) = 0.5;

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

vec2 get_refraction_offset(vec2 uv, float strength) {
    // Simple refraction based on UV position (simulating curved glass)
    vec2 center = vec2(0.5, 0.5);
    vec2 delta = uv - center;
    float dist = length(delta);

    // Chromatic dispersion effect
    float refract_amount = strength * (1.0 + dist * 0.5);

    return delta * refract_amount;
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    if (!enabled) {
        COLOR = tex_color;
        return;
    }

    vec2 uv = UV;
    float time = animated_frost ? TIME * frost_speed : 0.0;

    // Calculate refraction offset
    vec2 refract_offset = get_refraction_offset(uv, refraction_strength);

    // Add frosted glass distortion
    if (frosted && frost_amount > 0.0) {
        int octaves = quality_level == 0 ? 2 : (quality_level == 1 ? 3 : 4);
        float frost_noise = fbm(uv * frost_scale + time, octaves);
        refract_offset += (vec2(frost_noise) - 0.5) * frost_amount * 0.05;
    }

    // Sample refracted color
    vec2 refracted_uv = uv + refract_offset;
    refracted_uv = clamp(refracted_uv, vec2(0.0), vec2(1.0));

    vec4 refracted_color;

    if (quality_level >= 2 && refraction_strength > 0.0) {
        // Chromatic aberration in refraction
        float ca = refraction_strength * 0.5;
        refracted_color.r = texture(TEXTURE, refracted_uv + vec2(ca, 0.0)).r;
        refracted_color.g = texture(TEXTURE, refracted_uv).g;
        refracted_color.b = texture(TEXTURE, refracted_uv - vec2(ca, 0.0)).b;
        refracted_color.a = texture(TEXTURE, refracted_uv).a;
    } else {
        refracted_color = texture(TEXTURE, refracted_uv);
    }

    // Frosted glass blur
    if (frosted && frost_amount > 0.0 && quality_level >= 1) {
        vec4 blur_color = vec4(0.0);
        float blur_samples = quality_level == 1 ? 4.0 : 8.0;
        float blur_radius = frost_amount * 0.02;

        for (float i = -blur_samples; i <= blur_samples; i++) {
            for (float j = -blur_samples; j <= blur_samples; j++) {
                vec2 offset = vec2(i, j) * blur_radius / blur_samples;
                blur_color += texture(TEXTURE, refracted_uv + offset);
            }
        }
        blur_color /= pow(blur_samples * 2.0 + 1.0, 2.0);
        refracted_color = mix(refracted_color, blur_color, frost_amount);
    }

    // Fresnel effect
    float edge_x = abs(UV.x - 0.5) * 2.0;
    float edge_y = abs(UV.y - 0.5) * 2.0;
    float fresnel = pow(max(edge_x, edge_y), fresnel_power);

    // Reflection
    vec3 reflection = vec3(0.0);
    if (reflection_strength > 0.0) {
        if (use_reflection_texture) {
            vec2 reflect_uv = vec2(1.0 - UV.x, UV.y); // Simple flip reflection
            reflection = texture(reflection_texture, reflect_uv).rgb;
        } else {
            // Fake environment reflection
            reflection = mix(glass_tint, vec3(1.0), fresnel);
        }
        reflection *= reflection_strength * (fresnel + 0.2);
    }

    // Specular highlight
    vec2 light_dir = normalize(light_position - UV);
    float specular = pow(max(dot(vec2(0.0, 0.0) - light_dir, vec2(0.0, 1.0)), 0.0), specular_power);
    specular *= specular_intensity;

    // Edge highlight
    float edge_dist = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
    float edge = smoothstep(edge_thickness, 0.0, edge_dist) * edge_highlight;

    // Build final color
    vec3 glass_color = refracted_color.rgb * glass_tint;

    // Add reflection
    glass_color = mix(glass_color, reflection, reflection_strength * fresnel);

    // Add specular
    glass_color += vec3(specular);

    // Add edge highlight
    glass_color = mix(glass_color, edge_color, edge);

    // Double-sided effect (slight color shift)
    if (double_sided) {
        glass_color *= 1.0 + thickness * 0.1;
    }

    // Calculate alpha
    float alpha = glass_opacity + fresnel * 0.3 + edge * 0.2 + specular * 0.5;
    alpha = clamp(alpha, 0.0, 1.0);
    alpha *= tex_color.a;

    COLOR = vec4(glass_color, alpha);
}
