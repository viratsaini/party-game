shader_type canvas_item;
render_mode blend_mix;

// Liquid Metal Surface Shader
// Creates realistic liquid metal/chrome effect with reflections and distortion
// Perfect for premium UI elements and buttons

group_uniforms metal_properties;
uniform vec3 base_color : source_color = vec3(0.8, 0.8, 0.85);
uniform vec3 highlight_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 shadow_color : source_color = vec3(0.3, 0.3, 0.35);
uniform float reflectivity : hint_range(0.0, 1.0) = 0.8;
uniform float metalness : hint_range(0.0, 1.0) = 1.0;

group_uniforms surface_distortion;
uniform float ripple_strength : hint_range(0.0, 0.05) = 0.02;
uniform float ripple_frequency : hint_range(1.0, 20.0) = 8.0;
uniform float ripple_speed : hint_range(0.0, 5.0) = 1.0;
uniform float surface_tension : hint_range(0.0, 1.0) = 0.5;

group_uniforms environment;
uniform sampler2D environment_map : hint_default_white;
uniform bool use_environment_map = false;
uniform float environment_rotation : hint_range(0.0, 6.283) = 0.0;
uniform float environment_blur : hint_range(0.0, 0.1) = 0.02;

group_uniforms lighting;
uniform vec2 light_direction = vec2(0.3, -0.5);
uniform float specular_power : hint_range(1.0, 128.0) = 32.0;
uniform float specular_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float fresnel_power : hint_range(0.0, 5.0) = 3.0;

group_uniforms animation;
uniform bool animate_surface = true;
uniform float drip_effect : hint_range(0.0, 1.0) = 0.0;
uniform vec2 flow_direction = vec2(0.0, 1.0);
uniform float flow_speed : hint_range(0.0, 2.0) = 0.5;

group_uniforms quality;
uniform int quality_level : hint_range(0, 2) = 2;
uniform bool enabled = true;

float noise(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float smooth_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = noise(i);
    float b = noise(i + vec2(1.0, 0.0));
    float c = noise(i + vec2(0.0, 1.0));
    float d = noise(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < octaves; i++) {
        value += amplitude * smooth_noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value;
}

vec3 calculate_normal(vec2 uv, float time) {
    float eps = 0.01;
    vec2 flow = flow_direction * flow_speed * time;

    float h = fbm((uv + flow) * ripple_frequency, 3);
    float h_x = fbm((uv + vec2(eps, 0.0) + flow) * ripple_frequency, 3);
    float h_y = fbm((uv + vec2(0.0, eps) + flow) * ripple_frequency, 3);

    vec3 normal = normalize(vec3(
        (h - h_x) / eps * ripple_strength,
        (h - h_y) / eps * ripple_strength,
        1.0
    ));

    return normal;
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    if (!enabled) {
        COLOR = tex_color;
        return;
    }

    float time = animate_surface ? TIME : 0.0;

    // Calculate surface normal
    vec3 normal;
    if (quality_level >= 1) {
        normal = calculate_normal(UV, time * ripple_speed);
    } else {
        float h = smooth_noise(UV * ripple_frequency + time * ripple_speed);
        normal = normalize(vec3(0.0, 0.0, 1.0) + vec3(h - 0.5, h - 0.5, 0.0) * ripple_strength * 10.0);
    }

    // Fresnel effect
    float fresnel = pow(1.0 - abs(dot(normal, vec3(0.0, 0.0, 1.0))), fresnel_power);

    // Light calculation
    vec3 light_dir = normalize(vec3(light_direction, 0.5));
    vec3 view_dir = vec3(0.0, 0.0, 1.0);
    vec3 half_dir = normalize(light_dir + view_dir);

    float ndotl = max(dot(normal, light_dir), 0.0);
    float ndoth = max(dot(normal, half_dir), 0.0);
    float specular = pow(ndoth, specular_power) * specular_intensity;

    // Environment reflection
    vec3 reflection_color = base_color;
    if (use_environment_map && quality_level >= 2) {
        vec2 reflect_uv = UV + normal.xy * 0.1;
        reflect_uv.x = fract(reflect_uv.x + environment_rotation / 6.283);

        if (environment_blur > 0.0) {
            vec3 blur_sample = vec3(0.0);
            float samples = 4.0;
            for (float i = -samples; i <= samples; i++) {
                for (float j = -samples; j <= samples; j++) {
                    vec2 offset = vec2(i, j) * environment_blur / samples;
                    blur_sample += texture(environment_map, reflect_uv + offset).rgb;
                }
            }
            reflection_color = blur_sample / pow(samples * 2.0 + 1.0, 2.0);
        } else {
            reflection_color = texture(environment_map, reflect_uv).rgb;
        }
    }

    // Build final color
    vec3 diffuse = mix(shadow_color, base_color, ndotl * 0.5 + 0.5);
    vec3 metal_color = mix(diffuse, reflection_color, reflectivity * metalness);

    // Add specular highlight
    metal_color += highlight_color * specular * reflectivity;

    // Add fresnel rim
    metal_color = mix(metal_color, highlight_color, fresnel * reflectivity * 0.5);

    // Drip effect
    if (drip_effect > 0.0) {
        float drip = sin(UV.x * 20.0 + time * 2.0) * 0.5 + 0.5;
        drip *= smoothstep(0.8, 1.0, UV.y);
        drip *= drip_effect;

        float drip_stretch = 1.0 + drip * 0.3;
        metal_color = mix(metal_color, highlight_color, drip * 0.5);
    }

    // Apply surface tension (edge darkening)
    float edge_dist = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
    float tension_factor = smoothstep(0.0, 0.1, edge_dist);
    metal_color = mix(shadow_color, metal_color, mix(1.0, tension_factor, surface_tension));

    // Combine with original texture
    vec3 final_color = mix(tex_color.rgb, metal_color, metalness);

    COLOR = vec4(final_color, tex_color.a);
}
