extends Control

# ProjectionSurface.gd
# Individual projection surface with 4-point corner manipulation and per-surface video support

class_name ProjectionSurface

# Surface properties
var corner_points: Array[Vector2] = []
var is_selected: bool = false
var surface_name: String = ""
var is_locked: bool = false
var surface_z_index: int = 0  # Layer order (higher values appear on top)

# Visual properties
var surface_color := Color.WHITE
var surface_opacity := 1.0  # Opacity from 0.0 (transparent) to 1.0 (opaque)
var border_color := Colors.SURFACE_BORDER  # Use centralized color constants
var selected_border_color := Colors.SURFACE_SELECTED  # Use centralized color constants
var handle_color := Colors.SURFACE_HANDLES  # Use centralized color constants
var handle_size := 10.0  # Increased from 8.0 for better visibility
var handle_hit_area := 20.0  # Increased from 16.0 for easier selection
var handle_border_width := 2.0  # Border width for handles

# Enhanced visual feedback
var hover_border_color := Colors.SURFACE_HOVER  # Use centralized color constants
var dragging_border_color := Colors.SURFACE_DRAGGING  # Use centralized color constants
var locked_border_color := Colors.SURFACE_LOCKED  # Use centralized color constants
var show_surface_info := true  # Show surface info overlay
var show_coordinate_overlay := false  # Show corner coordinates
var show_distance_indicators := false  # Show distances between corners

# Selection tolerance settings (configurable)
var corner_selection_tolerance := 20.0  # Distance tolerance for corner selection
var edge_selection_tolerance := 8.0     # Distance tolerance for edge selection
var surface_selection_enabled := true   # Whether surface body can be selected

# Input handling
var dragging_corner := -1
var dragging_surface := false
var hovered_corner := -1  # Track which corner is being hovered
var selected_corner := -1  # Track which corner is selected for keyboard control
var drag_offset := Vector2.ZERO

# Dragging improvements
var drag_smoothing_enabled := true
var drag_smoothing_factor := 0.8  # Higher = smoother but more lag
var last_drag_position := Vector2.ZERO
var drag_accumulator := Vector2.ZERO
var minimum_drag_distance := 0.5  # Reduced from 0.1 for better sensitivity

# Video properties
var video_texture: Texture2D = null
var video_player: VideoStreamPlayer = null
var video_file_path: String = ""
var is_video_loaded: bool = false
var video_has_alpha: bool = false  # Track if the current video contains alpha channel

# Chroma key properties (color keying/green screen effect)
var chroma_key_enabled: bool = false  # Enable/disable chroma key effect
var chroma_key_color: Color = Color.GREEN  # Color to make transparent (default green)
var chroma_key_threshold: float = 0.1  # Color similarity threshold (0.0-1.0)
var chroma_key_smoothness: float = 0.05  # Edge smoothness for better blending (0.0-1.0)

# Shader materials for effects
var chroma_key_material: ShaderMaterial = null
var chroma_key_shader: Shader = null
var chroma_key_rect: ColorRect = null  # Child node for shader effect

# Transformation handles
enum TransformHandleType {
	NONE = -1,
	ROTATE_TOP_LEFT = 0,
	ROTATE_TOP_RIGHT = 1,
	ROTATE_BOTTOM_RIGHT = 2,
	ROTATE_BOTTOM_LEFT = 3,
	SCALE_CENTER = 4
}

var show_transform_handles := false  # Show transformation handles when selected
var transform_handle_size := 12.0   # Size of transformation handles
var transform_handle_color := Colors.SURFACE_TRANSFORM_HANDLES  # Use centralized color constants
var transform_handle_offset := 25.0  # Distance from corners for rotation handles
var dragging_transform_handle := TransformHandleType.NONE
var transform_center := Vector2.ZERO  # Center point for transformations
var initial_transform_state := {}  # Store initial state for transformations

# Centralized editing operations - single source of truth
enum EditOperationType {
	NONE,
	MOVE_CORNER,
	MOVE_SURFACE,
	SCALE_SURFACE,
	ROTATE_SURFACE
}

var current_edit_operation := EditOperationType.NONE
var edit_operation_data := {}  # Store operation-specific data

# Signals
signal selected(surface: ProjectionSurface)
signal deselected
signal properties_changed

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let canvas handle all input
	# Only set default name if no name has been loaded
	if surface_name == "":
		surface_name = "Surface " + str(get_instance_id())
	
	# Initialize chroma key shader
	_setup_chroma_key_shader()

func _setup_chroma_key_shader() -> void:
	"""Initialize the chroma key shader and material"""
	# Load the proper chroma key shader
	chroma_key_shader = load("res://shaders/chroma_key.gdshader")
	if chroma_key_shader:
		chroma_key_material = ShaderMaterial.new()
		chroma_key_material.shader = chroma_key_shader
		_update_chroma_key_uniforms()
		print("ProjectionSurface: Chroma key shader initialized")
	else:
		print("ProjectionSurface: ERROR - Failed to load chroma key shader")

func _update_chroma_key_uniforms() -> void:
	"""Update chroma key shader uniforms with current values"""
	if chroma_key_material:
		chroma_key_material.set_shader_parameter("chroma_key_enabled", chroma_key_enabled)
		chroma_key_material.set_shader_parameter("chroma_key_color", chroma_key_color)
		chroma_key_material.set_shader_parameter("threshold", chroma_key_threshold)
		chroma_key_material.set_shader_parameter("smoothness", chroma_key_smoothness)
		chroma_key_material.set_shader_parameter("surface_opacity", surface_opacity)
		if video_texture:
			chroma_key_material.set_shader_parameter("video_texture", video_texture)
		print("ProjectionSurface: Updated chroma key uniforms - enabled: ", chroma_key_enabled, ", color: ", chroma_key_color, ", threshold: ", chroma_key_threshold)

func _mouse_exited() -> void:
	"""Clear hover state when mouse leaves the surface"""
	if hovered_corner != -1:
		hovered_corner = -1
		queue_redraw()

func initialize_surface(center_position: Vector2, surface_size: Vector2) -> void:
	"""Initialize surface with default corner positions"""
	print("Initializing surface at center: ", center_position, " with size: ", surface_size)
	var half_size = surface_size * 0.5
	corner_points = [
		center_position + Vector2(-half_size.x, -half_size.y),  # Top-left
		center_position + Vector2(half_size.x, -half_size.y),   # Top-right  
		center_position + Vector2(half_size.x, half_size.y),    # Bottom-right
		center_position + Vector2(-half_size.x, half_size.y)    # Bottom-left
	]
	
	print("Corner points: ", corner_points)
	_update_surface_bounds()
	queue_redraw()

# CENTRALIZED SURFACE OPERATIONS - Single source of truth for all editing
# All input methods (mouse, keyboard, API) must use these functions

func can_edit() -> bool:
	"""Check if surface can be edited (not locked, valid state, etc.)"""
	if is_locked:
		return false
	return true

func request_corner_move(corner_index: int, new_position: Vector2) -> bool:
	"""Request to move a corner to a new position. Returns true if successful."""
	if not can_edit():
		return false
	if corner_index < 0 or corner_index >= corner_points.size():
		return false
	
	return _execute_corner_move(corner_index, new_position)

func request_corner_offset(corner_index: int, offset: Vector2) -> bool:
	"""Request to move a corner by an offset. Returns true if successful."""
	if not can_edit():
		return false
	if corner_index < 0 or corner_index >= corner_points.size():
		return false
	
	var new_position = corner_points[corner_index] + offset
	return _execute_corner_move(corner_index, new_position)

func request_surface_move(offset: Vector2) -> bool:
	"""Request to move entire surface by offset. Returns true if successful."""
	if not can_edit():
		return false
	
	return _execute_surface_move(offset)

func request_surface_scale(scale_factor: float, center_point: Vector2 = Vector2.ZERO) -> bool:
	"""Request to scale surface. Returns true if successful."""
	if not can_edit():
		return false
	if scale_factor <= 0:
		return false
	
	if center_point == Vector2.ZERO:
		center_point = _get_surface_center()
	
	return _execute_surface_scale(scale_factor, center_point)

func request_surface_rotation(angle_delta: float, center_point: Vector2 = Vector2.ZERO) -> bool:
	"""Request to rotate surface. Returns true if successful."""
	if not can_edit():
		return false
	
	if center_point == Vector2.ZERO:
		center_point = _get_surface_center()
	
	return _execute_surface_rotation(angle_delta, center_point)

# Internal execution functions
func _execute_corner_move(corner_index: int, new_position: Vector2) -> bool:
	"""Internal: Execute corner move with bounds checking and updates"""
	# TODO: Add bounds checking if needed
	corner_points[corner_index] = new_position
	_update_surface_bounds()
	properties_changed.emit()
	queue_redraw()
	return true

func _execute_surface_move(offset: Vector2) -> bool:
	"""Internal: Execute surface move with bounds checking and updates"""
	for i in range(corner_points.size()):
		corner_points[i] += offset
	_update_surface_bounds()
	properties_changed.emit()
	queue_redraw()
	return true

func _execute_surface_scale(scale_factor: float, center_point: Vector2) -> bool:
	"""Internal: Execute surface scaling around center point"""
	for i in range(corner_points.size()):
		var relative_pos = corner_points[i] - center_point
		corner_points[i] = center_point + relative_pos * scale_factor
	_update_surface_bounds()
	properties_changed.emit()
	queue_redraw()
	return true

func _execute_surface_rotation(angle_delta: float, center_point: Vector2) -> bool:
	"""Internal: Execute surface rotation around center point"""
	var cos_angle = cos(angle_delta)
	var sin_angle = sin(angle_delta)
	
	for i in range(corner_points.size()):
		var relative_pos = corner_points[i] - center_point
		var rotated = Vector2(
			relative_pos.x * cos_angle - relative_pos.y * sin_angle,
			relative_pos.x * sin_angle + relative_pos.y * cos_angle
		)
		corner_points[i] = center_point + rotated
	_update_surface_bounds()
	properties_changed.emit()
	queue_redraw()
	return true

func _get_surface_center() -> Vector2:
	"""Internal: Get the center point of the surface"""
	var center = Vector2.ZERO
	for point in corner_points:
		center += point
	return center / corner_points.size()

func _gui_input(event: InputEvent) -> void:
	"""Handle mouse input for corner dragging and selection"""
	# Prevent any modification when surface is locked
	if is_locked:
# Surface is locked - block all input
		if event is InputEventMouseButton:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				# Still allow selection for locked surfaces, but prevent dragging
				var canvas_pos = event.position + position
				if _point_in_surface(canvas_pos) or _get_corner_at_position(canvas_pos) >= 0:
					# Allow selection but prevent dragging by consuming the event

					selected.emit(self)
					accept_event()
					return
			elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				# Allow context menu for locked surfaces (to unlock them)
				var canvas_pos = event.position + position  
				if _point_in_surface(canvas_pos) or _get_corner_at_position(canvas_pos) >= 0:
					_show_context_menu(event.global_position)
					accept_event()
					return
			# Block all other mouse button events (including releases)

			accept_event()
			return
		elif event is InputEventMouseMotion:
			# Block all mouse motion when locked to prevent dragging

			accept_event()
			return
		# Block any other input events

		accept_event()
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Convert local position to canvas position
				var canvas_pos = event.position + position
				
				# Check for transformation handles first (highest priority)
				var transform_handle = _get_transform_handle_at_position(canvas_pos)
				if transform_handle != TransformHandleType.NONE:

					dragging_transform_handle = transform_handle
					# Store initial state for transformations
					initial_transform_state = {
						"corner_points": corner_points.duplicate(),
						"mouse_pos": canvas_pos,
						"center": transform_center
					}
					accept_event()
					return
				
				# Check for corner handles
				var corner_index = _get_corner_at_position(canvas_pos)
				if corner_index >= 0:
					# Start dragging corner immediately (selection handled by canvas first)

					dragging_corner = corner_index
					hovered_corner = -1  # Clear hover when dragging starts
					drag_offset = canvas_pos - corner_points[corner_index]
					accept_event()  # Consume the event to start dragging
				else:
					# Check if clicking inside surface
					if _point_in_surface(canvas_pos):
						# Start dragging the whole surface immediately

						dragging_surface = true
						hovered_corner = -1  # Clear hover when dragging starts
						drag_offset = canvas_pos - corner_points[0]  # Use top-left corner as reference
						accept_event()  # Consume the event to start dragging
					else:
						# Click is outside this surface - don't interfere with other surfaces
						pass
			else:
				# Stop dragging
				if dragging_transform_handle != TransformHandleType.NONE:
					dragging_transform_handle = TransformHandleType.NONE
					initial_transform_state.clear()
					properties_changed.emit()
					accept_event()
				elif dragging_corner >= 0:
					dragging_corner = -1
					_update_surface_bounds()
					properties_changed.emit()
					accept_event()  # Consume the event
				elif dragging_surface:
					dragging_surface = false
					# Don't update bounds for surface dragging - causes jumping
					properties_changed.emit()
					accept_event()  # Consume the event
		
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				# Show context menu for surface operations
				var canvas_pos = event.position + position
				if _point_in_surface(canvas_pos) or _get_corner_at_position(canvas_pos) >= 0:
					_show_context_menu(event.global_position)
					accept_event()
	
	elif event is InputEventMouseMotion:
		# Additional safety check: prevent any dragging operations when locked
		if is_locked:

			accept_event()
			return
			
		if dragging_transform_handle != TransformHandleType.NONE:
			# Safety check: prevent transformation when locked
			if is_locked:
				dragging_transform_handle = TransformHandleType.NONE  # Reset dragging state
				accept_event()
				return
			# Handle transformation dragging
			var canvas_pos = event.position + position
			var initial_mouse_pos = initial_transform_state.mouse_pos
			var center = initial_transform_state.center
			
			if dragging_transform_handle == TransformHandleType.SCALE_CENTER:
				# Scale transformation
				var initial_dist = initial_mouse_pos.distance_to(center)
				var current_dist = canvas_pos.distance_to(center)
				if initial_dist > 0:
					var scale_factor = current_dist / initial_dist
					# Restore initial state
					corner_points = initial_transform_state.corner_points.duplicate()
					_apply_scale_transform(scale_factor)
			else:
				# Rotation transformation 
				var initial_angle = (initial_mouse_pos - center).angle()
				var current_angle = (canvas_pos - center).angle()
				var angle_delta = current_angle - initial_angle
				# Restore initial state
				corner_points = initial_transform_state.corner_points.duplicate()
				_apply_rotation_transform(angle_delta, dragging_transform_handle)
			
			accept_event()
		elif dragging_corner >= 0:
			# Use centralized corner move operation
			var canvas_pos = event.position + position
			var new_corner_pos = canvas_pos - drag_offset
			if not request_corner_move(dragging_corner, new_corner_pos):
				# Operation failed (likely due to lock), reset drag state
				dragging_corner = -1
			accept_event()  # Consume the event
		elif dragging_surface:
			# Use centralized surface move operation
			var canvas_pos = event.position + position
			var new_reference_pos = canvas_pos - drag_offset
			var offset = new_reference_pos - corner_points[0]
			if not request_surface_move(offset):
				# Operation failed (likely due to lock), reset drag state
				dragging_surface = false
			accept_event()  # Consume the event
		else:
			# Update cursor and hover state
			var canvas_pos = event.position + position
			var corner_index = _get_corner_at_position(canvas_pos)
			
			# Update hovered corner and redraw if changed
			if hovered_corner != corner_index:
				hovered_corner = corner_index
				queue_redraw()
			
			if corner_index >= 0:
				mouse_default_cursor_shape = Control.CURSOR_MOVE
			elif _point_in_surface(canvas_pos):
				mouse_default_cursor_shape = Control.CURSOR_DRAG
			else:
				mouse_default_cursor_shape = Control.CURSOR_ARROW

func start_dragging_at_canvas_position(canvas_position: Vector2) -> void:
	"""Start dragging (corner or surface) at the given canvas position"""
	if is_locked:
		return
		
	# Reset any existing dragging state first
	reset_dragging_state()
	
	var corner_index = _get_corner_at_position(canvas_position)
	if corner_index >= 0:
		# Start dragging corner
		dragging_corner = corner_index
		selected_corner = corner_index  # Keep corner selected for keyboard control
		hovered_corner = -1  # Clear hover when dragging starts
		# Calculate precise drag offset
		drag_offset = canvas_position - corner_points[corner_index]
		last_drag_position = canvas_position

	else:
		# Check if clicking inside surface (and surface selection is enabled)
		if surface_selection_enabled and _point_in_surface(canvas_position):
			# Start dragging the whole surface
			dragging_surface = true
			hovered_corner = -1  # Clear hover when dragging starts
			selected_corner = -1  # Clear selected corner when dragging surface
			# Use precise reference point (top-left corner)
			drag_offset = canvas_position - corner_points[0]
			last_drag_position = canvas_position
			drag_accumulator = Vector2.ZERO


func handle_canvas_motion(canvas_position: Vector2) -> void:
	"""Handle mouse motion at the given canvas position during dragging"""
	# Use centralized operations for consistency and proper locking
	if dragging_corner >= 0:
		# Calculate new corner position
		var target_pos = canvas_position - drag_offset
		
		# Apply smoothing if enabled
		if drag_smoothing_enabled and last_drag_position != Vector2.ZERO:
			var smooth_pos = corner_points[dragging_corner].lerp(target_pos, 1.0 - drag_smoothing_factor)
			request_corner_move(dragging_corner, smooth_pos)
		else:
			request_corner_move(dragging_corner, target_pos)
		
		last_drag_position = canvas_position
		
	elif dragging_surface:
		# Calculate movement offset for surface dragging
		var new_reference_pos = canvas_position - drag_offset
		var current_reference_pos = corner_points[0]
		var raw_offset = new_reference_pos - current_reference_pos
		
		# Apply smoothing to surface movement if enabled
		var offset = raw_offset
		if drag_smoothing_enabled:
			drag_accumulator = drag_accumulator.lerp(raw_offset, 1.0 - drag_smoothing_factor)
			offset = drag_accumulator
		
		# Only apply movement if there's meaningful displacement
		if offset.length() > minimum_drag_distance:
			request_surface_move(offset)
			
			# Reset accumulator after applying movement
			if drag_smoothing_enabled:
				drag_accumulator = Vector2.ZERO
			
			last_drag_position = canvas_position
	else:
		# Update cursor and hover state for non-dragging motion
		var corner_index = _get_corner_at_position(canvas_position)
		
		# Update hovered corner and redraw if changed
		if hovered_corner != corner_index:
			hovered_corner = corner_index
			queue_redraw()
		
		# Set appropriate cursor based on what's under the mouse
		if corner_index >= 0:
			mouse_default_cursor_shape = Control.CURSOR_MOVE
		elif _point_in_surface(canvas_position):
			mouse_default_cursor_shape = Control.CURSOR_DRAG
		else:
			mouse_default_cursor_shape = Control.CURSOR_ARROW

func end_dragging_at_canvas_position(canvas_position: Vector2) -> void:
	"""End dragging at the given canvas position"""
	var was_dragging = dragging_corner >= 0 or dragging_surface
	
	if dragging_corner >= 0:
		print("Ended dragging corner ", dragging_corner, " at ", canvas_position)
		dragging_corner = -1
		_update_surface_bounds()
		properties_changed.emit()
	elif dragging_surface:
		print("Ended dragging surface at ", canvas_position)
		dragging_surface = false
		# Update bounds for surface dragging to ensure proper positioning
		_update_surface_bounds()
		properties_changed.emit()
	
	if was_dragging:
		# Reset drag state
		drag_offset = Vector2.ZERO
		last_drag_position = Vector2.ZERO
		drag_accumulator = Vector2.ZERO
		# Force a final redraw to ensure clean state
		queue_redraw()

func handle_keyboard_input(event: InputEventKey) -> bool:
	"""Handle keyboard input for fine corner adjustment and surface movement. Returns true if handled."""
	if not is_selected:
		return false
	
	# If surface is locked, consume arrow keys to prevent UI navigation but don't move
	if is_locked:
		if event.pressed and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			return true  # Consume the input without doing anything
		return false
	
	if event.pressed:
		var movement = Vector2.ZERO
		var step_size = 1.0
		if event.shift_pressed:
			step_size = 10.0  # Bigger steps with Shift
		elif event.ctrl_pressed:
			step_size = 0.1   # Smaller steps with Ctrl
		
		match event.keycode:
			KEY_LEFT:
				movement.x = -step_size
			KEY_RIGHT:
				movement.x = step_size
			KEY_UP:
				movement.y = -step_size
			KEY_DOWN:
				movement.y = step_size
			_:
				return false
		
		# Use centralized operations for consistency and proper locking
		var success = false
		if selected_corner >= 0 and selected_corner < corner_points.size():
			# Move individual corner using centralized operation
			success = request_corner_offset(selected_corner, movement)
		else:
			# Move entire surface using centralized operation
			success = request_surface_move(movement)
		
		return success
	
	return false

func reset_dragging_state() -> void:
	"""Reset all dragging states - useful for fixing stuck states"""
	dragging_corner = -1
	dragging_surface = false
	drag_offset = Vector2.ZERO
	last_drag_position = Vector2.ZERO
	drag_accumulator = Vector2.ZERO
	# Don't reset hovered_corner or selected_corner as they're useful for keyboard control

func is_dragging() -> bool:
	"""Check if this surface is currently being dragged"""
	return dragging_corner >= 0 or dragging_surface

func force_refresh_state() -> void:
	"""Force refresh the surface state - useful if corners seem stuck"""
	_update_surface_bounds()
	queue_redraw()
	properties_changed.emit()

func set_selection_tolerance(corner_tolerance: float, edge_tolerance: float) -> void:
	"""Configure selection tolerance settings"""
	corner_selection_tolerance = max(corner_tolerance, 5.0)  # Minimum 5 pixels
	edge_selection_tolerance = max(edge_tolerance, 2.0)      # Minimum 2 pixels
	handle_hit_area = corner_selection_tolerance  # Keep handle_hit_area in sync

func get_selection_tolerance() -> Dictionary:
	"""Get current selection tolerance settings"""
	return {
		"corner_tolerance": corner_selection_tolerance,
		"edge_tolerance": edge_selection_tolerance,
		"surface_selection_enabled": surface_selection_enabled
	}

func set_handle_appearance(new_size: float, border_width: float) -> void:
	"""Configure handle visual appearance"""
	handle_size = max(new_size, 6.0)  # Minimum 6 pixels
	handle_border_width = max(border_width, 1.0)  # Minimum 1 pixel
	queue_redraw()

func set_drag_behavior(smoothing_enabled: bool, smoothing_factor: float, min_distance: float) -> void:
	"""Configure dragging behavior"""
	drag_smoothing_enabled = smoothing_enabled
	drag_smoothing_factor = clamp(smoothing_factor, 0.0, 0.95)  # Prevent infinite smoothing
	minimum_drag_distance = max(min_distance, 0.1)  # Minimum threshold

func get_drag_behavior() -> Dictionary:
	"""Get current drag behavior settings"""
	return {
		"smoothing_enabled": drag_smoothing_enabled,
		"smoothing_factor": drag_smoothing_factor,
		"minimum_drag_distance": minimum_drag_distance
	}

func set_visual_feedback(show_info: bool, show_coordinates: bool, show_distances: bool) -> void:
	"""Configure visual feedback options"""
	show_surface_info = show_info
	show_coordinate_overlay = show_coordinates
	show_distance_indicators = show_distances
	queue_redraw()

func get_visual_feedback() -> Dictionary:
	"""Get current visual feedback settings"""
	return {
		"show_surface_info": show_surface_info,
		"show_coordinate_overlay": show_coordinate_overlay,
		"show_distance_indicators": show_distance_indicators
	}

func set_feedback_colors(hover_color: Color, drag_color: Color) -> void:
	"""Configure feedback colors"""
	hover_border_color = hover_color
	dragging_border_color = drag_color
	queue_redraw()



func _get_corner_at_position(pos: Vector2) -> int:
	"""Check if position is near a corner handle with improved precision"""
	if corner_points.size() != 4:
		return -1
	
	var closest_corner = -1
	var closest_distance = INF
	
	# Find the closest corner within tolerance
	for i in range(corner_points.size()):
		var distance = pos.distance_to(corner_points[i])
		if distance <= corner_selection_tolerance and distance < closest_distance:
			closest_distance = distance
			closest_corner = i
	
	return closest_corner

func _get_edge_at_position(pos: Vector2) -> int:
	"""Check if position is near a surface edge (returns edge index 0-3)"""
	if corner_points.size() != 4:
		return -1
	
	var closest_edge = -1
	var closest_distance = INF
	
	# Check each edge
	for i in range(4):
		var p1 = corner_points[i]
		var p2 = corner_points[(i + 1) % 4]
		var distance = _point_to_line_distance(pos, p1, p2)
		
		# Only consider if point is actually between the edge endpoints
		if _is_point_on_edge_segment(pos, p1, p2) and distance <= edge_selection_tolerance and distance < closest_distance:
			closest_distance = distance
			closest_edge = i
	
	return closest_edge

func _point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	"""Calculate the shortest distance from a point to a line segment"""
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	var line_len_sq = line_vec.length_squared()
	
	if line_len_sq == 0:
		return point.distance_to(line_start)  # Line is actually a point
	
	var t = clamp(point_vec.dot(line_vec) / line_len_sq, 0.0, 1.0)
	var projection = line_start + t * line_vec
	return point.distance_to(projection)

func _is_point_on_edge_segment(point: Vector2, edge_start: Vector2, edge_end: Vector2) -> bool:
	"""Check if point projection falls within the edge segment"""
	var line_vec = edge_end - edge_start
	var point_vec = point - edge_start
	var line_len_sq = line_vec.length_squared()
	
	if line_len_sq == 0:
		return false
	
	var t = point_vec.dot(line_vec) / line_len_sq
	return t >= 0.0 and t <= 1.0

func _get_canvas_position_from_local(local_pos: Vector2) -> Vector2:
	"""Convert local drawing coordinates back to canvas coordinates"""
	return local_pos + position

func _point_in_surface(point: Vector2) -> bool:
	"""Check if point is inside the surface using cross product method"""
	if corner_points.size() != 4:
		return false
	
	# Use ray casting algorithm for point-in-polygon test
	var x = point.x
	var y = point.y
	var inside = false
	
	var j = corner_points.size() - 1
	for i in range(corner_points.size()):
		var xi = corner_points[i].x
		var yi = corner_points[i].y
		var xj = corner_points[j].x
		var yj = corner_points[j].y
		
		if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi):
			inside = !inside
		
		j = i
	
	return inside

func set_selected(is_selected_param: bool) -> void:
	"""Set selection state"""
	is_selected = is_selected_param
	# Enable transform handles for selected surface
	show_transform_handles = is_selected_param
	queue_redraw()
	
	if is_selected_param:
		selected.emit(self)
	else:
		# Clear corner selection when surface is deselected
		selected_corner = -1
		show_transform_handles = false
		deselected.emit()

func set_transform_handles_visible(show_handles: bool) -> void:
	"""Toggle transformation handles visibility"""
	show_transform_handles = show_handles and is_selected
	queue_redraw()

func configure_transformation_handles(new_handle_size: float, handle_offset: float, new_handle_color: Color) -> void:
	"""Configure transformation handle appearance"""
	transform_handle_size = new_handle_size
	transform_handle_offset = handle_offset
	transform_handle_color = new_handle_color
	if is_selected:
		queue_redraw()

func _get_transformation_handle_positions() -> Dictionary:
	"""Get positions of all transformation handles"""
	if not is_selected or not show_transform_handles:
		return {}
	
	# Calculate center point
	var center = Vector2.ZERO
	for point in corner_points:
		center += point
	center /= corner_points.size()
	transform_center = center
	
	var handles = {}
	
	# Rotation handles - positioned outside each corner
	for i in range(4):
		var corner = corner_points[i]
		var to_center = (center - corner).normalized()
		var handle_pos = corner - to_center * transform_handle_offset
		handles[i] = handle_pos  # TransformHandleType rotation handles 0-3
	
	# Scale handle at center
	handles[TransformHandleType.SCALE_CENTER] = center
	
	return handles

func _get_transform_handle_at_position(pos: Vector2) -> TransformHandleType:
	"""Get transformation handle at given position"""
	if not is_selected or not show_transform_handles:
		return TransformHandleType.NONE
	
	var handles = _get_transformation_handle_positions()
	var tolerance = transform_handle_size + 5.0
	
	for handle_type in handles:
		var handle_pos = handles[handle_type]
		if pos.distance_to(handle_pos) <= tolerance:
			return handle_type
	
	return TransformHandleType.NONE

func _apply_rotation_transform(angle_delta: float, handle_type: TransformHandleType) -> void:
	"""Apply rotation transformation around the surface center"""
	_execute_surface_rotation(angle_delta, transform_center)

func _apply_scale_transform(scale_factor: float) -> void:
	"""Apply uniform scale transformation around the surface center"""
	_execute_surface_scale(scale_factor, transform_center)

func _update_surface_bounds() -> void:
	"""Update the control's position and size to encompass all corner points"""
	if corner_points.size() != 4:
		return
	
	# Find bounding box of all corners
	var min_pos = corner_points[0]
	var max_pos = corner_points[0]
	
	for point in corner_points:
		min_pos.x = min(min_pos.x, point.x)
		min_pos.y = min(min_pos.y, point.y)
		max_pos.x = max(max_pos.x, point.x)
		max_pos.y = max(max_pos.y, point.y)
	
	# Add padding for handles and transformation handles
	var padding = handle_size + 2
	if show_transform_handles:
		# Account for transformation handles extending beyond corners
		padding = max(padding, transform_handle_offset + transform_handle_size + 5)
	
	var new_position = min_pos - Vector2(padding, padding)
	var new_size = max_pos - min_pos + Vector2(padding * 2, padding * 2)
	
	# Set the control's bounds
	position = new_position
	size = new_size
	
	# DON'T adjust corner points - they should stay in canvas coordinates
	# The drawing will handle the coordinate conversion

func _draw() -> void:
	"""Draw the projection surface"""
	if corner_points.size() != 4:
		return
	
	# Don't draw if size is not valid
	if size.x <= 0 or size.y <= 0:
		return
	
	# Ensure no material is applied to Control to avoid affecting borders/handles
	material = null
	
	# Get font for text drawing throughout the method
	var font = ThemeDB.fallback_font
	
	# Convert canvas coordinates to local drawing coordinates
	var local_points = []
	for point in corner_points:
		local_points.append(point - position)
	
	# Create points array for border drawing and other UI elements
	var points = PackedVector2Array(local_points)
	
	# Draw the surface content using shared renderer for consistency
	var render_data = SurfaceRenderer.create_render_data_from_surface(self)
	SurfaceRenderer.render_surface_content(self, render_data, position)
	
	# Draw border with enhanced feedback
	var border_color_to_use = border_color
	var border_width = 2.0
	
	# Determine border appearance based on state
	if is_locked:
		border_color_to_use = locked_border_color
		border_width = 3.0
	elif dragging_corner >= 0 or dragging_surface:
		border_color_to_use = dragging_border_color
		border_width = 3.0
	elif is_selected:
		border_color_to_use = selected_border_color
		border_width = 2.5
	elif hovered_corner >= 0:
		border_color_to_use = hover_border_color
		border_width = 2.0
	
	# Draw border lines
	for i in range(points.size()):
		var start = points[i] 
		var end = points[(i + 1) % points.size()]
		draw_line(start, end, border_color_to_use, border_width)
		
		# Draw edge highlight if this edge is being hovered
		var edge_index = _get_edge_at_position(_get_canvas_position_from_local(start + (end - start) * 0.5))
		if edge_index == i and not (dragging_corner >= 0 or dragging_surface):
			# Draw a thicker, semi-transparent line for edge hover feedback
			draw_line(start, end, Color(border_color_to_use.r, border_color_to_use.g, border_color_to_use.b, 0.6), border_width + 2.0)
	
	# Draw corner handles with improved visual feedback
	for i in range(local_points.size()):
		var corner_pos = local_points[i]
		var handle_color_to_use = handle_color
		var handle_border_color = Color.BLACK
		var current_handle_size = handle_size
		
		# Different colors and sizes for different states
		if selected_corner == i:
			handle_color_to_use = Color.GREEN  # Selected corner (for keyboard control)
			handle_border_color = Color.DARK_GREEN
			current_handle_size = handle_size * 1.2  # Larger when selected
		elif hovered_corner == i:
			handle_color_to_use = Color.WHITE  # Hovered corner
			handle_border_color = Color.GRAY
			current_handle_size = handle_size * 1.1  # Slightly larger when hovered
		elif dragging_corner == i:
			handle_color_to_use = Color.YELLOW  # Currently dragging
			handle_border_color = Color.ORANGE
			current_handle_size = handle_size * 1.3  # Largest when dragging
		
		# Draw handle with glow effect for better visibility
		if is_selected or hovered_corner == i or selected_corner == i:
			# Glow effect - larger, semi-transparent circle
			draw_circle(corner_pos, current_handle_size + 3, Color(handle_color_to_use.r, handle_color_to_use.g, handle_color_to_use.b, 0.3))
		
		# Main handle
		draw_circle(corner_pos, current_handle_size, handle_color_to_use)
		# Handle border
		draw_circle(corner_pos, current_handle_size, handle_border_color, false, handle_border_width)
		
		# Draw corner index number for debugging (when selected)
		if is_selected and (selected_corner == i or hovered_corner == i):
			var text = str(i)
			var text_pos = corner_pos + Vector2(current_handle_size + 5, -current_handle_size)
			draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	
	# Draw transformation handles (rotation and scale)
	if is_selected and show_transform_handles:
		var transform_handles = _get_transformation_handle_positions()
		
		for handle_type in transform_handles:
			var handle_pos = transform_handles[handle_type] - position  # Convert to local coordinates
			var handle_color_to_use = transform_handle_color
			var current_transform_handle_size = transform_handle_size
			
			# Different appearance based on handle type and state
			if dragging_transform_handle == handle_type:
				handle_color_to_use = Color.YELLOW
				current_transform_handle_size *= 1.2
			elif handle_type == TransformHandleType.SCALE_CENTER:
				handle_color_to_use = Color.CYAN  # Different color for scale handle
			
			# Draw handle with distinctive shape based on type
			if handle_type == TransformHandleType.SCALE_CENTER:
				# Scale handle - draw as square
				var rect_size = current_transform_handle_size
				var rect = Rect2(handle_pos - Vector2(rect_size/2, rect_size/2), Vector2(rect_size, rect_size))
				draw_rect(rect, handle_color_to_use)
				draw_rect(rect, Color.BLACK, false, 2.0)
				
				# Draw scale icon
				var icon_size = rect_size * 0.6
				var center_pos = handle_pos
				draw_line(center_pos - Vector2(icon_size/2, icon_size/2), center_pos + Vector2(icon_size/2, icon_size/2), Color.BLACK, 2.0)
				draw_line(center_pos - Vector2(icon_size/2, -icon_size/2), center_pos + Vector2(icon_size/2, -icon_size/2), Color.BLACK, 2.0)
			else:
				# Rotation handles - draw as circles with rotation icon
				draw_circle(handle_pos, current_transform_handle_size, handle_color_to_use)
				draw_circle(handle_pos, current_transform_handle_size, Color.BLACK, false, 2.0)
				
				# Draw rotation icon (small arc)
				var arc_radius = current_transform_handle_size * 0.6
				var arc_points = []
				for angle_deg in range(30, 150, 20):  # Draw partial arc
					var angle_rad = deg_to_rad(angle_deg)
					var point = handle_pos + Vector2(cos(angle_rad), sin(angle_rad)) * arc_radius
					arc_points.append(point)
				
				# Draw arc as connected line segments
				for i in range(arc_points.size() - 1):
					draw_line(arc_points[i], arc_points[i + 1], Color.BLACK, 2.0)
	
	# Draw surface name with lock indicator
	if surface_name != "":
		var center = Vector2.ZERO
		for point in local_points:
			center += point
		center /= local_points.size()
		
		var display_text = surface_name
		if is_locked:
			display_text = "🔒 " + surface_name
		
		var text_pos = center - Vector2(0, 20)
		var text_size = font.get_string_size(display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_rect(Rect2(text_pos - Vector2(4, text_size.y + 2), text_size + Vector2(8, 4)), Color(0, 0, 0, 0.7))
		var text_color = Color.WHITE if not is_locked else Color.LIGHT_CORAL
		draw_string(font, text_pos, display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_color)
		
		# Draw move indicator if dragging the whole surface
		if dragging_surface:
			draw_circle(center, 8, Color.YELLOW)
			draw_circle(center, 8, Color.ORANGE, false, 2.0)
			draw_string(font, center + Vector2(15, 0), "MOVING", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.YELLOW)
	
	# Draw coordinate overlays if enabled
	if show_coordinate_overlay and is_selected:
		for i in range(local_points.size()):
			var corner_pos = local_points[i]
			var canvas_pos = corner_points[i] 
			var coord_text = "(%d,%d)" % [canvas_pos.x, canvas_pos.y]
			var text_size = font.get_string_size(coord_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
			var text_pos = corner_pos + Vector2(handle_size + 5, -handle_size - 5)
			
			# Background for coordinate text
			draw_rect(Rect2(text_pos - Vector2(2, text_size.y), text_size + Vector2(4, 2)), Color(0, 0, 0, 0.8))
			draw_string(font, text_pos, coord_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	
	# Draw distance indicators if enabled
	if show_distance_indicators and is_selected:
		for i in range(local_points.size()):
			var start_pos = local_points[i]
			var end_pos = local_points[(i + 1) % local_points.size()]
			var mid_point = (start_pos + end_pos) * 0.5
			var distance = corner_points[i].distance_to(corner_points[(i + 1) % corner_points.size()])
			var distance_text = "%.1f" % distance
			
			# Background for distance text
			var text_size = font.get_string_size(distance_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
			draw_rect(Rect2(mid_point - text_size * 0.5 - Vector2(2, 1), text_size + Vector2(4, 2)), Color(0, 0, 0, 0.7))
			draw_string(font, mid_point - text_size * 0.5, distance_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.CYAN)

func get_surface_data() -> Dictionary:
	"""Get surface data for saving"""
	# Corner points are already in canvas/global coordinates, save them directly
	var corners_to_save = []
	for point in corner_points:
		corners_to_save.append({"x": point.x, "y": point.y})
	
	print("ProjectionSurface: Saving corner points (canvas coords): ", corner_points)
	print("ProjectionSurface: Surface position: ", position)
	print("ProjectionSurface: Formatted corners: ", corners_to_save)
	
	var surface_data = {
		"name": surface_name,
		"corner_points": corners_to_save,
		"surface_color": {
			"r": surface_color.r,
			"g": surface_color.g, 
			"b": surface_color.b,
			"a": surface_color.a
		},
		"surface_opacity": surface_opacity,
		"surface_z_index": surface_z_index,
		"video_file_path": video_file_path,
		"has_video": is_video_loaded,
		"is_locked": is_locked,
		"chroma_key": {
			"enabled": chroma_key_enabled,
			"color": {
				"r": chroma_key_color.r,
				"g": chroma_key_color.g,
				"b": chroma_key_color.b,
				"a": chroma_key_color.a
			},
			"threshold": chroma_key_threshold,
			"smoothness": chroma_key_smoothness
		}
	}
	
	print("ProjectionSurface: Complete surface data: ", surface_data)
	return surface_data

func load_surface_data(data: Dictionary) -> void:
	"""Load surface data"""
	if data.has("name"):
		surface_name = data.name
	
	if data.has("corner_points"):
		var corners_data = data.corner_points
		corner_points = []
		
		print("ProjectionSurface: Loading corner points data: ", corners_data)
		print("ProjectionSurface: Corner points data type: ", typeof(corners_data))
		
		if corners_data is Array:
			for i in range(corners_data.size()):
				var point_data = corners_data[i]
				print("ProjectionSurface: Point ", i, " data: ", point_data, " type: ", typeof(point_data))
				
				var loaded_point = Vector2.ZERO
				if point_data is Vector2:
					loaded_point = point_data
				elif point_data is Dictionary and point_data.has("x") and point_data.has("y"):
					loaded_point = Vector2(point_data.x, point_data.y)
				elif point_data is Array and point_data.size() >= 2:
					loaded_point = Vector2(point_data[0], point_data[1])
				else:
					print("Warning: Unsupported corner point format for point ", i, ": ", typeof(point_data), " value: ", point_data)
					loaded_point = Vector2.ZERO
				
				# The saved points are in global coordinates, use them directly
				corner_points.append(loaded_point)
		else:
			print("Warning: corner_points is not an Array: ", typeof(corners_data))
			
		print("ProjectionSurface: Loaded corner points: ", corner_points)
		_update_surface_bounds()
	
	if data.has("surface_color"):
		var color_data = data.surface_color
		surface_color = Color(color_data.r, color_data.g, color_data.b, color_data.a)
	
	if data.has("surface_opacity"):
		surface_opacity = data.surface_opacity
	
	if data.has("surface_z_index"):
		surface_z_index = data.surface_z_index
	
	if data.has("is_locked"):
		is_locked = data.is_locked
	
	# Load video data
	if data.has("video_file_path") and data.has("has_video"):
		print("ProjectionSurface: Found video data - path: ", data.video_file_path, ", has_video: ", data["has_video"])
		if data["has_video"] and data.video_file_path != "":
			print("ProjectionSurface: Loading video file: ", data.video_file_path)
			# Use a timer to delay video loading until surface is fully initialized
			var load_timer = Timer.new()
			load_timer.wait_time = 0.1  # Short delay
			load_timer.one_shot = true
			load_timer.autostart = true  # Auto-start when added to scene
			load_timer.timeout.connect(_delayed_video_load.bind(data.video_file_path))
			add_child(load_timer)
		else:
			print("ProjectionSurface: Skipping video load - has_video: ", data["has_video"], ", path: '", data.video_file_path, "'")
	
	# Load chroma key data
	if data.has("chroma_key"):
		var chroma_data = data.chroma_key
		if chroma_data.has("enabled"):
			chroma_key_enabled = chroma_data.enabled
		if chroma_data.has("color"):
			var color_data = chroma_data.color
			chroma_key_color = Color(color_data.r, color_data.g, color_data.b, color_data.a)
		if chroma_data.has("threshold"):
			chroma_key_threshold = chroma_data.threshold
		if chroma_data.has("smoothness"):
			chroma_key_smoothness = chroma_data.smoothness
		print("ProjectionSurface: Loaded chroma key settings - enabled: ", chroma_key_enabled, ", color: ", chroma_key_color)
	
	queue_redraw()

func set_video_texture(texture: Texture2D) -> void:
	"""Set video texture for this surface"""
	print("ProjectionSurface: Setting video texture for surface '", surface_name, "': ", texture)
	if video_texture != texture:  # Only update if texture actually changed
		video_texture = texture
		is_video_loaded = (texture != null)
		print("ProjectionSurface: Video texture set, is_video_loaded: ", is_video_loaded)
		queue_redraw()

func set_video_alpha_flag(has_alpha: bool) -> void:
	"""Set flag indicating if the current video contains alpha channel"""
	if video_has_alpha != has_alpha:
		video_has_alpha = has_alpha
		print("ProjectionSurface: Video alpha flag set to: ", has_alpha)
		queue_redraw()  # Redraw to apply new alpha handling
	else:
		print("ProjectionSurface: Video texture unchanged, skipping update")

# Chroma key functions
func set_chroma_key_enabled(enabled: bool) -> void:
	"""Enable or disable chroma key effect"""
	if chroma_key_enabled != enabled:
		chroma_key_enabled = enabled
		print("ProjectionSurface: Chroma key enabled: ", enabled, " - Material available: ", chroma_key_material != null)
		queue_redraw()

func set_chroma_key_color(color: Color) -> void:
	"""Set the color to make transparent in chroma key effect"""
	if chroma_key_color != color:
		chroma_key_color = color
		if chroma_key_enabled:
			queue_redraw()

func set_chroma_key_threshold(threshold: float) -> void:
	"""Set chroma key color similarity threshold (0.0-1.0)"""
	threshold = clamp(threshold, 0.0, 1.0)
	if chroma_key_threshold != threshold:
		chroma_key_threshold = threshold
		if chroma_key_enabled:
			queue_redraw()

func set_chroma_key_smoothness(smoothness: float) -> void:
	"""Set chroma key edge smoothness (0.0-1.0)"""
	smoothness = clamp(smoothness, 0.0, 1.0)
	if chroma_key_smoothness != smoothness:
		chroma_key_smoothness = smoothness
		if chroma_key_enabled:
			queue_redraw()

func get_chroma_key_settings() -> Dictionary:
	"""Get current chroma key settings"""
	return {
		"enabled": chroma_key_enabled,
		"color": chroma_key_color,
		"threshold": chroma_key_threshold,
		"smoothness": chroma_key_smoothness
	}

func _delayed_video_load(file_path: String) -> void:
	"""Delayed video loading after surface is fully initialized"""
	print("ProjectionSurface: _delayed_video_load called for: ", file_path)
	if is_instance_valid(self):
		print("ProjectionSurface: Surface is valid, calling load_video_file")
		load_video_file(file_path)
	else:
		print("ProjectionSurface: Surface is not valid, skipping video load")
	
	# Clean up the timer
	var timer = get_children().filter(func(child): return child is Timer and child.one_shot)
	for t in timer:
		print("ProjectionSurface: Cleaning up timer")
		t.queue_free()

func load_video_file(file_path: String) -> void:
	"""Load a video file specifically for this surface"""
	print("ProjectionSurface: Loading video file for surface '", surface_name, "': ", file_path)
	
	# Check if file exists
	if not FileAccess.file_exists(file_path):
		print("ProjectionSurface: Error - Video file does not exist: ", file_path)
		return
	
	# Clear existing video
	clear_video()
	
	# Store the file path
	video_file_path = file_path
	
	# Create individual VideoStreamPlayer for this surface
	if video_player == null:
		video_player = VideoStreamPlayer.new()
		video_player.autoplay = false
		video_player.loop = true
		video_player.expand = true
		add_child(video_player)
	
	# Request video manager to load this file and send texture to this surface
	var video_manager = get_node("/root/Main/VideoManager")
	if not video_manager:
		# Fallback: try to find VideoManager by class
		var main_node = get_node("/root/Main")
		if main_node:
			for child in main_node.get_children():
				if child.get_script() and child.get_script().resource_path.ends_with("VideoManager.gd"):
					video_manager = child
					break
	
	if video_manager:
		print("ProjectionSurface: Found VideoManager, calling load_video_for_surface")
		video_manager.load_video_for_surface(file_path, self)
	else:
		print("ProjectionSurface: Error - VideoManager not found at path: /root/Main/VideoManager")

func clear_video() -> void:
	"""Clear video from this surface"""
	if video_player:
		video_player.stop()
		video_player.queue_free()
		video_player = null
	
	video_texture = null
	video_file_path = ""
	is_video_loaded = false
	video_has_alpha = false  # Reset alpha flag when clearing video
	# Note: Chroma key settings are kept so user can apply them to next video
	queue_redraw()
	print("ProjectionSurface: Video cleared from surface '", surface_name, "'")

func start_video_playback() -> void:
	"""Start video playback for this surface (supports both VideoStreamPlayer and PNGSequencePlayer)"""
	print("ProjectionSurface: start_video_playback called for surface '", surface_name, "'")
	
	# Check for PNG sequence player first
	if has_meta("png_sequence_player"):
		print("ProjectionSurface: Found PNG sequence player meta")
		var png_player = get_meta("png_sequence_player")
		if png_player:
			print("ProjectionSurface: PNG player exists, calling play()")
			png_player.play()
			is_video_loaded = true
			print("ProjectionSurface: Started PNG sequence playback for surface '", surface_name, "'")
			return
		else:
			print("ProjectionSurface: PNG player meta exists but player is null!")
	else:
		print("ProjectionSurface: No PNG sequence player meta found")
	
	# Fall back to regular video player
	if video_player and video_player.stream:
		video_player.play()
		is_video_loaded = true
		print("ProjectionSurface: Started video playback for surface '", surface_name, "'")
	else:
		print("ProjectionSurface: Cannot start playback - no video loaded")

func stop_video_playback() -> void:
	"""Stop video playback for this surface (supports both VideoStreamPlayer and PNGSequencePlayer)"""
	# Check for PNG sequence player first
	if has_meta("png_sequence_player"):
		var png_player = get_meta("png_sequence_player")
		if png_player:
			png_player.stop()
			print("ProjectionSurface: Stopped PNG sequence playback for surface '", surface_name, "'")
			return
	
	# Fall back to regular video player
	if video_player:
		video_player.stop()
		print("ProjectionSurface: Stopped video playback for surface '", surface_name, "'")

func get_video_info() -> Dictionary:
	"""Get video information for this surface (supports both VideoStreamPlayer and PNGSequencePlayer)"""
	# Check for PNG sequence player first
	if has_meta("png_sequence_player"):
		var png_player = get_meta("png_sequence_player")
		if png_player:
			return {
				"has_video": true,
				"file_path": video_file_path,
				"is_playing": png_player.is_playing,
				"is_png_sequence": true,
				"frame_count": png_player.frame_count,
				"current_frame": png_player.current_frame,
				"frame_rate": png_player.frame_rate
			}
	
	# Fall back to regular video player info
	return {
		"has_video": is_video_loaded,
		"file_path": video_file_path,
		"is_playing": video_player != null and video_player.is_playing() if video_player else false,
		"is_png_sequence": false
	}

func get_corner_points_global() -> Array[Vector2]:
	"""Get corner points in global coordinates"""
	var global_points: Array[Vector2] = []
	for point in corner_points:
		global_points.append(point + position)
	return global_points

func _is_point_inside_surface(point: Vector2) -> bool:
	"""Check if a point is inside this surface using ray casting algorithm"""
	if corner_points.size() != 4:
		return false
	
	# corner_points are already in canvas coordinates, use them directly
	# Use ray casting algorithm for point-in-polygon test
	var inside = false
	var j = corner_points.size() - 1
	
	for i in range(corner_points.size()):
		var pi = corner_points[i]
		var pj = corner_points[j]
		
		if ((pi.y > point.y) != (pj.y > point.y)) and \
		   (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x):
			inside = !inside
		j = i
	
	return inside

func _show_context_menu(menu_position: Vector2) -> void:
	"""Show context menu for surface operations"""
	var context_menu = PopupMenu.new()
	get_tree().current_scene.add_child(context_menu)
	
	# Add menu items
	context_menu.add_item("Load Video...", 0)
	context_menu.add_separator()
	context_menu.add_item("Clear Video", 1)
	context_menu.add_separator()
	if is_video_loaded:
		if video_player and video_player.is_playing():
			context_menu.add_item("Stop Video", 2)
		else:
			context_menu.add_item("Play Video", 3)
		context_menu.add_separator()
	context_menu.add_item("Rename Surface...", 4)
	context_menu.add_separator()
	if is_locked:
		context_menu.add_item("🔓 Unlock Surface", 6)
	else:
		context_menu.add_item("🔒 Lock Surface", 6)
	context_menu.add_separator()
	context_menu.add_item("Delete Surface", 5)
	
	# Connect signal
	context_menu.id_pressed.connect(_on_context_menu_item_selected)
	context_menu.popup_on_parent(Rect2i(menu_position, Vector2i.ZERO))
	
	# Clean up after menu closes
	context_menu.popup_hide.connect(_on_context_menu_closed.bind(context_menu))

func _on_context_menu_item_selected(id: int) -> void:
	"""Handle context menu item selection"""
	match id:
		0: # Load Video
			_open_video_file_dialog()
		1: # Clear Video
			clear_video()
		2: # Stop Video
			stop_video_playback()
		3: # Play Video
			start_video_playback()
		4: # Rename Surface
			_show_rename_dialog()
		5: # Delete Surface
			_delete_surface()
		6: # Lock/Unlock Surface
			_toggle_lock_surface()

func _on_context_menu_closed(menu: PopupMenu) -> void:
	"""Clean up context menu"""
	menu.queue_free()

func _open_video_file_dialog() -> void:
	"""Open file dialog to select video for this surface"""
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.mp4,*.avi,*.mov,*.mkv,*.webm,*.flv,*.wmv,*.m4v,*.ogv,*.ogg", "Video Files")
	
	# Connect signal
	file_dialog.file_selected.connect(_on_video_file_selected)
	file_dialog.close_requested.connect(_on_file_dialog_closed.bind(file_dialog))
	
	get_tree().current_scene.add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_video_file_selected(path: String) -> void:
	"""Handle video file selection for this surface"""
	load_video_file(path)

func _on_file_dialog_closed(dialog: FileDialog) -> void:
	"""Clean up file dialog"""
	dialog.queue_free()

func _show_rename_dialog() -> void:
	"""Show dialog to rename surface"""
	var dialog = AcceptDialog.new()
	dialog.title = "Rename Surface"
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Surface Name:"
	vbox.add_child(label)
	
	var line_edit = LineEdit.new()
	line_edit.text = surface_name
	line_edit.custom_minimum_size = Vector2(300, 30)
	vbox.add_child(line_edit)
	
	dialog.confirmed.connect(_on_rename_confirmed.bind(line_edit))
	dialog.close_requested.connect(_on_rename_dialog_closed.bind(dialog))
	
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()
	line_edit.grab_focus()
	line_edit.select_all()

func _on_rename_confirmed(line_edit: LineEdit) -> void:
	"""Handle surface rename confirmation"""
	surface_name = line_edit.text
	queue_redraw()
	properties_changed.emit()

func _on_rename_dialog_closed(dialog: AcceptDialog) -> void:
	"""Clean up rename dialog"""
	dialog.queue_free()

func _delete_surface() -> void:
	"""Delete this surface"""
	# Signal to parent that this surface should be removed
	deselected.emit()
	queue_free()

func _toggle_lock_surface() -> void:
	"""Toggle surface lock state"""
	var was_locked = is_locked
	is_locked = !is_locked
	

	
	# When locking, immediately stop any ongoing drag operations
	if is_locked:

		dragging_corner = -1
		dragging_surface = false
		dragging_transform_handle = TransformHandleType.NONE
		selected_corner = -1  # Also clear keyboard selection
	
	queue_redraw()  # Refresh visual state
	properties_changed.emit()
	print("ProjectionSurface: Surface '", surface_name, "' is now ", "locked" if is_locked else "unlocked")