shader_type canvas_item;

// Chroma key (color key) shader for making specific colors transparent
// Used for green screen effects and color keying on surfaces

uniform bool chroma_key_enabled = false;
uniform vec4 chroma_key_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);  // Green by default
uniform float threshold : hint_range(0.0, 1.0) = 0.1;
uniform float smoothness : hint_range(0.0, 1.0) = 0.05;
uniform float surface_opacity : hint_range(0.0, 1.0) = 1.0;

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Calculate color distance for chroma key matching
float color_distance(vec3 a, vec3 b) {
	// Use Euclidean distance in RGB space
	vec3 diff = a - b;
	return sqrt(dot(diff, diff));
}

void fragment() {
	// Get the texture color from the TextureRect's texture (TEXTURE is the built-in sampler)
	vec4 tex_color = texture(TEXTURE, UV);
	
	if (chroma_key_enabled) {
		// Calculate distance between pixel color and chroma key color
		float distance = color_distance(tex_color.rgb, chroma_key_color.rgb);
		
		// Create alpha mask based on distance
		float alpha_mask = 1.0;
		if (distance <= threshold) {
			// Within threshold - make transparent with smooth edges
			alpha_mask = smoothstep(threshold - smoothness, threshold + smoothness, distance);
		}
		
		// Apply chroma key alpha and surface opacity
		COLOR = vec4(tex_color.rgb, tex_color.a * alpha_mask * surface_opacity);
	} else {
		// No chroma key - just apply surface opacity
		COLOR = vec4(tex_color.rgb, tex_color.a * surface_opacity);
	}
}