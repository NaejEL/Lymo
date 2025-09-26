# SurfaceRenderer.gd
# Shared rendering utility for consistent surface content rendering between editor and output

class_name SurfaceRenderer

# No caching needed - GPU shader processes in real-time

# Surface content rendering data structure
class SurfaceRenderData:
	var corner_points: Array[Vector2] = []
	var surface_color: Color = Color.WHITE
	var surface_opacity: float = 1.0
	var video_texture: Texture2D = null
	var video_has_alpha: bool = false
	
	# Chroma key properties
	var chroma_key_enabled: bool = false
	var chroma_key_color: Color = Color.GREEN
	var chroma_key_threshold: float = 0.1
	var chroma_key_smoothness: float = 0.05
	
	# Video state information
	var is_from_active_video_player: bool = false  # True if texture comes from playing VideoStreamPlayer
	var is_png_sequence: bool = false  # True if texture comes from PNG sequence (needs special alpha handling)
	
	func _init(points: Array[Vector2] = [], color: Color = Color.WHITE, opacity: float = 1.0):
		corner_points = points
		surface_color = color
		surface_opacity = opacity

# Static rendering functions for consistent content rendering
static func render_surface_content(drawing_context: Control, render_data: SurfaceRenderData, local_offset: Vector2 = Vector2.ZERO) -> void:
	"""Render surface content (video or color fill) consistently across editor and output"""
	if render_data.corner_points.size() != 4:
		return
	
	# Clean up any old TextureRect nodes that might have been created by previous implementations
	for child in drawing_context.get_children():
		if child.has_meta("chroma_key_rect"):
			child.queue_free()
	
	# Convert points to local coordinates if offset provided
	var local_points = []
	for point in render_data.corner_points:
		local_points.append(point - local_offset)
	
	var points = PackedVector2Array(local_points)
	
	if render_data.video_texture != null:
		# Render video texture with effects
		_render_video_texture(drawing_context, points, render_data)
	else:
		# Render solid color fill
		_render_color_fill(drawing_context, points, render_data)

static func _render_video_texture(drawing_context: Control, points: PackedVector2Array, render_data: SurfaceRenderData) -> void:
	"""Render video texture with chroma key and alpha effects"""
	# UV coordinates for proper projection mapping
	var uv_coords = PackedVector2Array([
		Vector2(0, 0),      # Top-left UV
		Vector2(1, 0),      # Top-right UV  
		Vector2(1, 1),      # Bottom-right UV
		Vector2(0, 1)       # Bottom-left UV
	])
	
	# Apply chroma key effect if enabled - use the original working approach
	if render_data.chroma_key_enabled:
		# Use the exact same approach that was working before factorization
		_render_video_with_original_chroma_key(drawing_context, points, uv_coords, render_data)
	else:
		# Render normally without chroma key
		_render_video_without_effects(drawing_context, points, uv_coords, render_data)

static func _render_video_without_effects(drawing_context: Control, points: PackedVector2Array, uv_coords: PackedVector2Array, render_data: SurfaceRenderData) -> void:
	"""Render video texture without chroma key effects"""
	var opacity = render_data.surface_opacity
	
	# For videos with alpha channel or PNG sequences, use white colors and let texture alpha show through
	var vertex_colors: PackedColorArray
	if render_data.video_has_alpha or render_data.is_png_sequence:
		# Use white vertex colors to preserve texture alpha channel
		vertex_colors = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	else:
		# Apply surface opacity via vertex colors for standard videos
		vertex_colors = PackedColorArray([
			Color(1, 1, 1, opacity),
			Color(1, 1, 1, opacity),
			Color(1, 1, 1, opacity),
			Color(1, 1, 1, opacity)
		])
	
	drawing_context.draw_polygon(points, vertex_colors, uv_coords, render_data.video_texture)

static func _render_video_with_original_chroma_key(drawing_context: Control, points: PackedVector2Array, uv_coords: PackedVector2Array, render_data: SurfaceRenderData) -> void:
	"""Render video texture with chroma key using dedicated Control node with custom _draw method"""
	
	# Find or create a dedicated chroma key control
	var chroma_control: Control = null
	
	# Look for existing chroma key control
	for child in drawing_context.get_children():
		if child is Control and child.has_meta("chroma_key_control"):
			chroma_control = child as Control
			break
	
	# Create new Control if none exists
	if not chroma_control:
		chroma_control = Control.new()
		chroma_control.set_meta("chroma_key_control", true)
		chroma_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chroma_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		drawing_context.add_child(chroma_control)
		
		# Load and apply the shader material
		var chroma_key_shader = load("res://shaders/chroma_key.gdshader")
		if chroma_key_shader:
			var chroma_key_material = ShaderMaterial.new()
			chroma_key_material.shader = chroma_key_shader
			chroma_control.material = chroma_key_material
		else:
			print("Warning: Could not load chroma key shader")
			_render_video_without_effects(drawing_context, points, uv_coords, render_data)
			return
		
		# Connect custom draw function
		if not chroma_control.draw.is_connected(_draw_chroma_key_content):
			chroma_control.draw.connect(_draw_chroma_key_content.bind(chroma_control))
	
	# Update shader parameters
	if chroma_control.material and chroma_control.material is ShaderMaterial:
		var shader_material = chroma_control.material as ShaderMaterial
		shader_material.set_shader_parameter("chroma_key_enabled", true)
		shader_material.set_shader_parameter("chroma_key_color", render_data.chroma_key_color)
		shader_material.set_shader_parameter("threshold", render_data.chroma_key_threshold)
		shader_material.set_shader_parameter("smoothness", render_data.chroma_key_smoothness)
		shader_material.set_shader_parameter("surface_opacity", render_data.surface_opacity)
	
	# Store rendering data as metadata
	chroma_control.set_meta("points", points)
	chroma_control.set_meta("uv_coords", uv_coords)
	chroma_control.set_meta("video_texture", render_data.video_texture)
	
	# Queue redraw to apply changes
	chroma_control.queue_redraw()

static func _draw_chroma_key_content(control: Control) -> void:
	"""Draw chroma key content with shader applied"""
	var points = control.get_meta("points", PackedVector2Array())
	var uv_coords = control.get_meta("uv_coords", PackedVector2Array())
	var video_texture = control.get_meta("video_texture", null)
	
	if points.size() == 4 and uv_coords.size() == 4 and video_texture:
		var vertex_colors = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
		control.draw_polygon(points, vertex_colors, uv_coords, video_texture)



static func _render_color_fill(drawing_context: Control, points: PackedVector2Array, render_data: SurfaceRenderData) -> void:
	"""Render solid color fill for surfaces without video"""
	var opaque_color = Color(
		render_data.surface_color.r,
		render_data.surface_color.g,
		render_data.surface_color.b,
		render_data.surface_color.a * render_data.surface_opacity
	)
	drawing_context.draw_colored_polygon(points, opaque_color)

# Helper function to create render data from ProjectionSurface
static func create_render_data_from_surface(surface) -> SurfaceRenderData:
	"""Create SurfaceRenderData from a ProjectionSurface instance"""
	var render_data = SurfaceRenderData.new()
	
	# Copy surface properties - properly handle Array[Vector2]
	if "corner_points" in surface:
		render_data.corner_points.clear()
		for point in surface.corner_points:
			render_data.corner_points.append(point)
	if "surface_color" in surface:
		render_data.surface_color = surface.surface_color
	if "surface_opacity" in surface:
		render_data.surface_opacity = surface.surface_opacity
	if "video_texture" in surface:
		render_data.video_texture = surface.video_texture
	if "video_has_alpha" in surface:
		render_data.video_has_alpha = surface.video_has_alpha
	
	# Copy chroma key properties
	if "chroma_key_enabled" in surface:
		render_data.chroma_key_enabled = surface.chroma_key_enabled
	if "chroma_key_color" in surface:
		render_data.chroma_key_color = surface.chroma_key_color
	if "chroma_key_threshold" in surface:
		render_data.chroma_key_threshold = surface.chroma_key_threshold
	if "chroma_key_smoothness" in surface:
		render_data.chroma_key_smoothness = surface.chroma_key_smoothness
	
	# Check if texture comes from active video player
	if "video_player" in surface:
		render_data.is_from_active_video_player = surface.video_player != null and surface.video_player.is_playing()
	
	# Check if this is a PNG sequence
	if surface.has_meta("is_png_sequence"):
		render_data.is_png_sequence = surface.get_meta("is_png_sequence", false)
	
	return render_data

# Helper function to create render data from metadata (for output window)
static func create_render_data_from_meta(surface_node: Control, source_corners: Array) -> SurfaceRenderData:
	"""Create SurfaceRenderData from Control node metadata"""
	var render_data = SurfaceRenderData.new()
	
	# Copy properties from metadata - properly convert to Array[Vector2]
	render_data.corner_points.clear()
	for point in source_corners:
		if point is Vector2:
			render_data.corner_points.append(point)
		else:
			print("Warning: Invalid corner point type: ", typeof(point))
	render_data.surface_color = surface_node.get_meta("surface_color", Color.WHITE)
	render_data.surface_opacity = surface_node.get_meta("surface_opacity", 1.0)
	render_data.video_texture = surface_node.get_meta("video_texture", null)
	render_data.video_has_alpha = surface_node.get_meta("video_has_alpha", false)
	
	# Copy chroma key properties from metadata
	render_data.chroma_key_enabled = surface_node.get_meta("chroma_key_enabled", false)
	render_data.chroma_key_color = surface_node.get_meta("chroma_key_color", Color.GREEN)
	render_data.chroma_key_threshold = surface_node.get_meta("chroma_key_threshold", 0.1)
	render_data.chroma_key_smoothness = surface_node.get_meta("chroma_key_smoothness", 0.05)
	
	# For output window, video player state needs to be passed via metadata as well
	render_data.is_from_active_video_player = surface_node.get_meta("is_from_active_video_player", false)
	
	# Check if this is a PNG sequence
	render_data.is_png_sequence = surface_node.get_meta("is_png_sequence", false)
	
	return render_data