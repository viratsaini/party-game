shader_type canvas_item;
render_mode blend_mix;

// Animated Border Shader
// Creates dynamic animated borders with various styles
// Perfect for UI frames, buttons, and highlight effects

group_uniforms border;
uniform float border_width : hint_range(0.0, 0.2) = 0.02;
uniform float border_softness : hint_range(0.0, 0.05) = 0.005;
uniform float corner_radius : hint_range(0.0, 0.5) = 0.05;
uniform bool inner_glow = true;
uniform float glow_width : hint_range(0.0, 0.1) = 0.02;

group_uniforms colors;
uniform vec3 border_color : source_color = vec3(0.0, 0.8, 1.0);
uniform vec3 glow_color : source_color = vec3(0.0, 0.5, 1.0);
uniform float color_intensity : hint_range(0.5, 3.0) = 1.5;

group_uniforms animation;
uniform bool animated = true;
uniform float animation_speed : hint_range(0.0, 5.0) = 1.0;
uniform int animation_style : hint_range(0, 4) = 0;
// 0 = Pulse, 1 = Rotate, 2 = Dash, 3 = Wave, 4 = Rainbow

uniform float dash_length : hint_range(0.01, 0.2) = 0.05;
uniform float dash_gap : hint_range(0.01, 0.2) = 0.03;

group_uniforms effects;
uniform bool gradient_border = false;
uniform vec3 gradient_color_2 : source_color = vec3(1.0, 0.0, 0.5);
uniform float gradient_angle : hint_range(0.0, 6.283) = 0.0;

group_uniforms quality;
uniform bool enabled = true;

float rounded_rect_sdf(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

vec3 hsv_to_rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

float get_border_position(vec2 uv) {
    // Calculate position along the border (0-1)
    vec2 centered = uv - 0.5;
    float angle = atan(centered.y, centered.x);
    return fract((angle + 3.14159) / 6.28318);
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    if (!enabled) {
        COLOR = tex_color;
        return;
    }

    float time = animated ? TIME * animation_speed : 0.0;

    // Calculate SDF for rounded rectangle
    vec2 centered = UV - 0.5;
    vec2 size = vec2(0.5, 0.5) - vec2(border_width);
    float dist = rounded_rect_sdf(centered, size, corner_radius);

    // Border calculation
    float outer_edge = smoothstep(-border_softness, border_softness, dist + border_width);
    float inner_edge = smoothstep(-border_softness, border_softness, dist);
    float border = outer_edge - inner_edge;

    // Inner glow
    float glow = 0.0;
    if (inner_glow) {
        glow = smoothstep(glow_width, 0.0, dist);
        glow = pow(glow, 2.0);
    }

    // Calculate border position for animations
    float border_pos = get_border_position(UV);

    // Apply animation
    vec3 final_border_color = border_color;
    float border_alpha = 1.0;

    if (animation_style == 0) {
        // Pulse
        float pulse = sin(time * 2.0) * 0.5 + 0.5;
        final_border_color *= 0.7 + pulse * 0.6;

    } else if (animation_style == 1) {
        // Rotating highlight
        float highlight_pos = fract(time * 0.5);
        float highlight = 1.0 - abs(border_pos - highlight_pos);
        highlight = smoothstep(0.8, 1.0, highlight) + smoothstep(0.2, 0.0, highlight_pos) * smoothstep(0.8, 1.0, border_pos);
        final_border_color *= 0.5 + highlight * 1.0;

    } else if (animation_style == 2) {
        // Dashed border
        float dash_pattern = fract((border_pos + time * 0.2) / (dash_length + dash_gap));
        float dash = step(dash_pattern, dash_length / (dash_length + dash_gap));
        border_alpha *= dash;

    } else if (animation_style == 3) {
        // Wave
        float wave = sin(border_pos * 20.0 + time * 3.0) * 0.5 + 0.5;
        final_border_color = mix(border_color, gradient_color_2, wave);

    } else if (animation_style == 4) {
        // Rainbow
        float hue = fract(border_pos + time * 0.3);
        final_border_color = hsv_to_rgb(vec3(hue, 0.8, 1.0));
    }

    // Apply gradient to border
    if (gradient_border && animation_style != 4) {
        float grad_t = cos(gradient_angle) * centered.x + sin(gradient_angle) * centered.y + 0.5;
        final_border_color = mix(border_color, gradient_color_2, grad_t);
    }

    // Apply intensity
    final_border_color *= color_intensity;

    // Combine
    vec3 result = tex_color.rgb;

    // Add glow
    result = mix(result, glow_color, glow * 0.5);

    // Add border
    result = mix(result, final_border_color, border * border_alpha);

    // Calculate alpha
    float alpha = tex_color.a;
    alpha = max(alpha, (border * border_alpha + glow * 0.3));

    COLOR = vec4(result, alpha);
}
