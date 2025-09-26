shader_type canvas_item;

// Simple debug shader that just tints everything red
void fragment() {
    COLOR = vec4(1.0, 0.0, 0.0, 1.0); // Red tint to verify shader is working
}