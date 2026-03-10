shader_type canvas_item;
render_mode blend_mix;

// Vignette Shader
// Customizable vignette with multiple shapes and color options
// Perfect for cinematic framing and focus effects

group_uniforms vignette;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.5;
uniform float vignette_roundness : hint_range(0.0, 1.0) = 1.0;
uniform vec2 vignette_center = vec2(0.5, 0.5);
uniform float inner_radius : hint_range(0.0, 1.0) = 0.3;
uniform float outer_radius : hint_range(0.0, 2.0) = 1.0;

group_uniforms shape;
uniform int shape_type : hint_range(0, 3) = 0; // 0=ellipse, 1=rectangle, 2=diamond, 3=custom
uniform float aspect_ratio : hint_range(0.5, 2.0) = 1.0;
uniform float corner_radius : hint_range(0.0, 1.0) = 0.2;
uniform float rotation : hint_range(0.0, 6.283) = 0.0;

group_uniforms effects;
uniform bool chromatic_vignette = false;
uniform float chromatic_strength : hint_range(0.0, 0.05) = 0.01;
uniform bool animated = false;
uniform float animation_speed : hint_range(0.0, 5.0) = 1.0;
uniform float pulse_amount : hint_range(0.0, 0.3) = 0.1;

group_uniforms quality;
uniform bool enabled = true;

float sdf_ellipse(vec2 p, vec2 r) {
    vec2 k = p / r;
    return length(k) - 1.0;
}

float sdf_rectangle(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

float sdf_diamond(vec2 p, float s) {
    p = abs(p);
    return (p.x + p.y - s) / sqrt(2.0);
}

vec2 rotate2d(vec2 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

void fragment() {
    if (!enabled) {
        COLOR = texture(TEXTURE, UV);
        return;
    }

    vec2 uv = UV - vignette_center;
    uv = rotate2d(uv, rotation);
    uv.x *= aspect_ratio;

    float inner = inner_radius;
    float outer = outer_radius;

    if (animated) {
        float pulse = sin(TIME * animation_speed) * pulse_amount;
        inner += pulse;
        outer += pulse;
    }

    float dist;
    if (shape_type == 0) {
        // Ellipse
        dist = length(uv);
    } else if (shape_type == 1) {
        // Rectangle with rounded corners
        dist = sdf_rectangle(uv, vec2(outer * 0.7), corner_radius * outer);
        dist = dist / outer + 0.5;
    } else if (shape_type == 2) {
        // Diamond
        dist = sdf_diamond(uv, outer * 0.8);
        dist = dist / outer + 0.5;
    } else {
        // Custom (mix of shapes)
        float ellipse = length(uv);
        float rect = sdf_rectangle(uv, vec2(outer * 0.7), corner_radius * outer) / outer + 0.5;
        dist = mix(ellipse, rect, vignette_roundness);
    }

    float vignette = smoothstep(inner, outer * (1.0 + vignette_softness), dist);
    vignette = pow(vignette, 1.0 + (1.0 - vignette_softness));
    vignette *= vignette_intensity;

    vec4 original = texture(TEXTURE, UV);

    if (chromatic_vignette) {
        vec2 aberration_offset = (UV - vec2(0.5)) * chromatic_strength * vignette;
        original.r = texture(TEXTURE, UV + aberration_offset).r;
        original.b = texture(TEXTURE, UV - aberration_offset).b;
    }

    vec3 result = mix(original.rgb, vignette_color.rgb, vignette * vignette_color.a);
    COLOR = vec4(result, original.a);
}
