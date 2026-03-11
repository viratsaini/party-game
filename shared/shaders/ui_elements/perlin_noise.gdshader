shader_type canvas_item;
render_mode blend_mix;

// Perlin Noise Variations Shader
// Comprehensive noise generation with multiple algorithms and effects
// Perfect for organic textures, clouds, fire, and procedural patterns

group_uniforms noise_type;
uniform int noise_algorithm : hint_range(0, 5) = 0;
// 0 = Classic Perlin, 1 = Simplex-like, 2 = Worley, 3 = Curl, 4 = Turbulence, 5 = Ridged

group_uniforms noise_parameters;
uniform float noise_scale : hint_range(1.0, 50.0) = 10.0;
uniform int octaves : hint_range(1, 8) = 4;
uniform float persistence : hint_range(0.0, 1.0) = 0.5;
uniform float lacunarity : hint_range(1.0, 4.0) = 2.0;
uniform vec2 offset = vec2(0.0, 0.0);

group_uniforms colors;
uniform vec3 color_low : source_color = vec3(0.0, 0.0, 0.2);
uniform vec3 color_mid : source_color = vec3(0.0, 0.5, 1.0);
uniform vec3 color_high : source_color = vec3(1.0, 1.0, 1.0);
uniform float color_contrast : hint_range(0.5, 3.0) = 1.0;
uniform bool use_gradient = true;

group_uniforms animation;
uniform bool animated = true;
uniform float animation_speed : hint_range(0.0, 2.0) = 0.5;
uniform vec2 flow_direction = vec2(1.0, 0.0);
uniform float flow_speed : hint_range(0.0, 2.0) = 0.3;

group_uniforms domain_warp;
uniform bool domain_warp_enabled = false;
uniform float warp_strength : hint_range(0.0, 1.0) = 0.3;
uniform float warp_scale : hint_range(1.0, 20.0) = 5.0;

group_uniforms effects;
uniform bool posterize = false;
uniform int posterize_levels : hint_range(2, 16) = 4;
uniform bool invert = false;
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;

group_uniforms quality;
uniform int quality_level : hint_range(0, 2) = 2;
uniform bool enabled = true;

// Hash functions
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Gradient noise (Perlin-like)
float gradient_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0));
    float b = dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
    float c = dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
    float d = dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.5 + 0.5;
}

// Value noise
float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Worley noise (cellular)
float worley_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    float min_dist = 1.0;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = hash2(i + neighbor) * 0.5 + 0.5;
            float dist = length(neighbor + point - f);
            min_dist = min(min_dist, dist);
        }
    }

    return min_dist;
}

// FBM (Fractal Brownian Motion)
float fbm(vec2 p, int oct, float pers, float lac) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    float max_value = 0.0;

    for (int i = 0; i < oct; i++) {
        value += amplitude * gradient_noise(p * frequency);
        max_value += amplitude;
        amplitude *= pers;
        frequency *= lac;
    }

    return value / max_value;
}

// Turbulence (absolute value FBM)
float turbulence(vec2 p, int oct, float pers, float lac) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    float max_value = 0.0;

    for (int i = 0; i < oct; i++) {
        value += amplitude * abs(gradient_noise(p * frequency) * 2.0 - 1.0);
        max_value += amplitude;
        amplitude *= pers;
        frequency *= lac;
    }

    return value / max_value;
}

// Ridged noise
float ridged_noise(vec2 p, int oct, float pers, float lac) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    float weight = 1.0;

    for (int i = 0; i < oct; i++) {
        float n = 1.0 - abs(gradient_noise(p * frequency) * 2.0 - 1.0);
        n = n * n * weight;
        weight = clamp(n * 2.0, 0.0, 1.0);
        value += amplitude * n;
        amplitude *= pers;
        frequency *= lac;
    }

    return value;
}

// Curl noise (for flow effects)
vec2 curl_noise(vec2 p) {
    float eps = 0.01;
    float n1 = gradient_noise(p + vec2(eps, 0.0));
    float n2 = gradient_noise(p - vec2(eps, 0.0));
    float n3 = gradient_noise(p + vec2(0.0, eps));
    float n4 = gradient_noise(p - vec2(0.0, eps));

    float dx = (n3 - n4) / (2.0 * eps);
    float dy = -(n1 - n2) / (2.0 * eps);

    return vec2(dx, dy);
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    if (!enabled) {
        COLOR = tex_color;
        return;
    }

    float time = animated ? TIME * animation_speed : 0.0;
    vec2 uv = UV * noise_scale + offset + flow_direction * flow_speed * time;

    // Domain warping
    if (domain_warp_enabled && quality_level >= 1) {
        vec2 warp = vec2(
            fbm(uv * warp_scale, 3, 0.5, 2.0),
            fbm(uv * warp_scale + vec2(5.2, 1.3), 3, 0.5, 2.0)
        );
        uv += (warp - 0.5) * warp_strength;
    }

    // Calculate noise based on algorithm
    float noise_value = 0.0;
    int oct = quality_level == 0 ? min(octaves, 3) : octaves;

    if (noise_algorithm == 0) {
        noise_value = fbm(uv, oct, persistence, lacunarity);
    } else if (noise_algorithm == 1) {
        noise_value = fbm(uv + time * 0.1, oct, persistence, lacunarity);
        noise_value = pow(noise_value, 1.5);
    } else if (noise_algorithm == 2) {
        noise_value = 1.0 - worley_noise(uv);
        if (oct > 1) {
            noise_value = noise_value * 0.7 + (1.0 - worley_noise(uv * 2.0)) * 0.3;
        }
    } else if (noise_algorithm == 3) {
        vec2 curl = curl_noise(uv);
        noise_value = length(curl) * 0.5;
        noise_value = fbm(uv + curl * 0.5, oct, persistence, lacunarity);
    } else if (noise_algorithm == 4) {
        noise_value = turbulence(uv, oct, persistence, lacunarity);
    } else {
        noise_value = ridged_noise(uv, oct, persistence, lacunarity);
    }

    // Apply contrast
    noise_value = (noise_value - 0.5) * color_contrast + 0.5;
    noise_value += brightness;

    // Invert
    if (invert) {
        noise_value = 1.0 - noise_value;
    }

    // Posterize
    if (posterize) {
        noise_value = floor(noise_value * float(posterize_levels)) / float(posterize_levels);
    }

    noise_value = clamp(noise_value, 0.0, 1.0);

    // Color mapping
    vec3 result;
    if (use_gradient) {
        if (noise_value < 0.5) {
            result = mix(color_low, color_mid, noise_value * 2.0);
        } else {
            result = mix(color_mid, color_high, (noise_value - 0.5) * 2.0);
        }
    } else {
        result = vec3(noise_value);
    }

    // Combine with texture
    vec3 final_color = mix(tex_color.rgb, result, tex_color.a > 0.0 ? 1.0 : noise_value);
    float final_alpha = max(tex_color.a, noise_value);

    COLOR = vec4(final_color, final_alpha);
}
