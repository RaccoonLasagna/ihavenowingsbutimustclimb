shader_type canvas_item;

uniform float min_y = 0.0;       // bottom of level
uniform float max_y = -4000.0;   // top of level

// Aggressive overlay colour so you can SEE it
uniform vec4 overlay_color : source_color = vec4(1, 1, 1.0, 1.0);

// How strong the overlay is at the bottom
uniform float max_opacity = 0.9;

varying float world_y;

void vertex() {
    world_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    float t = clamp((world_y - min_y) / (max_y - min_y), 0.0, 1.0);

    // 0 at bottom → 1 at top
    float overlay_strength = (0.3 - t) * max_opacity;

    // Blend original texture with overlay
    vec3 final_color = mix(tex.rgb, overlay_color.rgb, overlay_strength);

    COLOR = vec4(final_color, tex.a);
}