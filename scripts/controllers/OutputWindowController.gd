# OutputWindowController.gd
# Controls the secondary output window for projection display

extends Window

class_name OutputWindowController

# References
@onready var output_canvas: Control = $OutputCanvas
@onready var status_label: Label = $StatusLabel
@onready var background: ColorRect = $ColorRect

# Output settings
var target_display: int = 0
var output_resolution: Vector2i = Vector2i(1920, 1080)
var is_fullscreen: bool = false
var is_output_active: bool = false

# Grid settings (shared with main canvas)
var is_grid_view: bool = true
var grid_size: int = 20
var grid_color: Color = Colors.GRID_LINES  # Use centralized color constants
var background_color_black: Color = Colors.CANVAS_BLACK  # Use centralized color constants
var background_color_grid: Color = Colors.CANVAS_GRID_BG  # Use centralized color constants

# Render capture
var main_canvas: Control = null
var render_texture: ImageTexture = null

# Debug counters
var update_count: int = 0
var force_update_counter: int = 0

# Signals
signal output_window_closed
signal output_resolution_changed(resolution: Vector2i)

func force_surface_update() -> void:
	"""Force a complete update of all surfaces - useful for debugging"""
	print("OutputWindow: Forcing complete surface update")
	if main_canvas != null and "surfaces" in main_canvas:
		var surfaces = main_canvas.surfaces
		
		# Clear all existing surfaces
		for child in output_canvas.get_children():
			child.queue_free()
		
		# Recreate all surfaces
		for surface in surfaces:
			_create_output_surface(surface)
		
		print("OutputWindow: Forced update complete - recreated ", surfaces.size(), " surfaces")

func _ready() -> void:
	"""Initialize the output window"""
	# Start hidden
	visible = false
	
	# Debug information about runtime environment
	var is_debug = OS.is_debug_build()
	var is_editor = Engine.is_editor_hint()
	print("OutputWindow: Debug build: ", is_debug, ", Editor mode: ", is_editor)
	print("OutputWindow: Available displays: ", DisplayServer.get_screen_count())
	
	# Setup window properties
	_setup_window()
	
	# Connect output canvas drawing for grid
	if output_canvas:
		output_canvas.draw.connect(_draw_output_background)
	
	print("OutputWindow: Initialized")

func _input(event: InputEvent) -> void:
	"""Handle input events for the output window"""
	if not is_output_active:
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE, KEY_F11:
				# Exit output mode and return to editor
				hide_output()
				get_viewport().set_input_as_handled()
			KEY_R:
				# Force refresh surfaces (for debugging)
				if event.ctrl_pressed:
					print("OutputWindow: Manual refresh requested (Ctrl+R)")
					force_surface_update()
					get_viewport().set_input_as_handled()

func _setup_window() -> void:
	"""Setup initial window properties"""
	# Set window properties
	title = "Lymo - Output Display"
	size = output_resolution
	
	# Ensure it's a separate window, not replacing the main window
	mode = Window.MODE_WINDOWED
	
	# Center on target display if possible
	_position_on_display(target_display)
	
	# Setup background
	background.color = Color.BLACK  # Black background to match canvas

func show_output(canvas_controller: Control) -> void:
	"""Show the output window and start displaying canvas content"""
	main_canvas = canvas_controller
	is_output_active = true
	
	var is_debug = OS.is_debug_build()
	var is_editor = Engine.is_editor_hint()
	
	print("OutputWindow: Starting output display...")
	print("OutputWindow: Runtime mode - Debug: ", is_debug, ", Editor: ", is_editor)
	
	# Position on target display first
	_position_on_display(target_display)
	
	# Set to windowed mode first and show
	mode = Window.MODE_WINDOWED
	visible = true
	
	print("OutputWindow: Window visible, current mode: ", mode)
	print("OutputWindow: Window position: ", position)
	print("OutputWindow: Window size: ", size)
	print("OutputWindow: Current screen: ", current_screen)
	
	# Force move to target display
	move_to_center()
	
	# Wait a frame then set up the window properly
	await get_tree().process_frame
	
	# In debug mode, we can't do true fullscreen, so just maximize
	if is_debug or is_editor:
		print("OutputWindow: Debug/Editor mode - using maximized window")
		mode = Window.MODE_MAXIMIZED
		borderless = false  # Keep borders in debug for easier window management
	else:
		print("OutputWindow: Export mode - setting up fullscreen")
		
		# Get the screen size for the target display
		var screen_rect = DisplayServer.screen_get_usable_rect(target_display)
		print("OutputWindow: Target screen rect: ", screen_rect)
		
		# First ensure we're on the right screen
		current_screen = target_display
		
		# Position and size the window to cover the entire screen
		position = screen_rect.position
		size = screen_rect.size
		
		# Wait a moment for positioning to take effect
		await get_tree().process_frame
		
		# Now try fullscreen mode
		mode = Window.MODE_FULLSCREEN
		borderless = true
		
		print("OutputWindow: Applied fullscreen mode on display ", target_display)
	
	# Wait another frame to ensure changes take effect
	await get_tree().process_frame
	
	# Log final state
	print("OutputWindow: Final mode: ", mode)
	print("OutputWindow: Final position: ", position)
	print("OutputWindow: Final size: ", size)
	print("OutputWindow: Current screen: ", current_screen)
	print("OutputWindow: Borderless: ", borderless)
	
	# Update status initially, then hide quickly
	if is_debug or is_editor:
		status_label.text = "DEBUG MODE: Output limited to editor window\nExport project for true dual-display"
		status_label.visible = true
		# Keep status visible longer in debug mode
		var timer = get_tree().create_timer(5.0)
		timer.timeout.connect(func(): if status_label: status_label.visible = false)
	else:
		status_label.text = "Output Active - Display " + str(target_display)
		status_label.visible = true
		# Hide status label after 1 second in export mode
		var timer = get_tree().create_timer(1.0)
		timer.timeout.connect(func(): if status_label: status_label.visible = false)
	
	# Start render capture timer
	_start_render_capture()
	
	print("OutputWindow: Output started on display ", target_display, " in maximized mode")

func hide_output() -> void:
	"""Hide the output window"""
	is_output_active = false
	
	# Restore windowed mode first
	mode = Window.MODE_WINDOWED
	borderless = false
	
	# Then hide
	visible = false
	
	# Stop render capture
	_stop_render_capture()
	
	# Emit signal to notify main controller
	output_window_closed.emit()
	
	print("OutputWindow: Output stopped")

func set_target_display(display_index: int) -> void:
	"""Set the target display for output and automatically update resolution"""
	var screen_count = DisplayServer.get_screen_count()
	print("OutputWindow: Setting target display to ", display_index, " (total displays: ", screen_count, ")")
	
	# Ensure display index is valid
	if display_index >= screen_count:
		print("OutputWindow: Display ", display_index, " not available, using display 0")
		display_index = 0
	
	target_display = display_index
	
	# Automatically get and set the display's full native resolution (not just usable area)
	var screen_size = DisplayServer.screen_get_size(display_index)
	var display_resolution = Vector2i(screen_size.x, screen_size.y)
	
	print("OutputWindow: Display ", display_index, " resolution: ", display_resolution)
	set_output_resolution(display_resolution)
	
	_position_on_display(display_index)
	
	print("OutputWindow: Target display set to ", display_index, " with resolution ", display_resolution)

func set_output_resolution(resolution: Vector2i) -> void:
	"""Set the output resolution and notify listeners"""
	output_resolution = resolution
	size = resolution
	
	# Emit signal to notify other systems (like canvas) of resolution change
	output_resolution_changed.emit(resolution)
	
	print("OutputWindow: Resolution set to ", resolution)

func toggle_fullscreen() -> void:
	"""Toggle fullscreen mode with proper scaling and positioning"""
	is_fullscreen = !is_fullscreen
	
	if is_fullscreen:
		# Store windowed state for restoration
		var windowed_size = size
		var windowed_position = position
		
		# Enter fullscreen with proper content scaling
		mode = Window.MODE_FULLSCREEN
		borderless = true
		status_label.visible = false
		
		# Ensure proper display positioning for fullscreen
		_position_on_display(target_display)
		
		# Set content scale mode for better fullscreen rendering
		content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		
		print("OutputWindow: Entered fullscreen on display ", target_display)
		
	else:
		# Exit fullscreen with proper restoration
		mode = Window.MODE_WINDOWED
		borderless = false
		
		# Restore original resolution and position
		size = output_resolution
		_position_on_display(target_display)
		
		status_label.visible = true
		
		# Reset content scaling for windowed mode
		content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		
		print("OutputWindow: Exited fullscreen - restored to ", output_resolution)
	
	# Force a surface update to handle any scaling changes
	if is_output_active:
		force_surface_update()
	
	print("OutputWindow: Fullscreen transition complete - ", "enabled" if is_fullscreen else "disabled")

func _position_on_display(display_index: int) -> void:
	"""Position window on the specified display"""
	var screen_count = DisplayServer.get_screen_count()
	if display_index >= screen_count:
		print("OutputWindow: Display ", display_index, " not available, using display 0")
		display_index = 0
	
	# Set the current screen property
	current_screen = display_index
	
	# Get screen info
	var screen_rect = DisplayServer.screen_get_usable_rect(display_index)
	
	# Position window on the target screen - center it
	var window_size = size
	var center_x = screen_rect.position.x + (screen_rect.size.x - window_size.x) / 2
	var center_y = screen_rect.position.y + (screen_rect.size.y - window_size.y) / 2
	
	position = Vector2i(center_x, center_y)
	
	print("OutputWindow: Positioned on display ", display_index, " at ", position)
	print("OutputWindow: Screen rect: ", screen_rect)
	print("OutputWindow: Window size: ", window_size)
	print("OutputWindow: Final position: ", position)

func _start_render_capture() -> void:
	"""Start capturing the main canvas for output"""
	if main_canvas == null:
		print("OutputWindow: No main canvas to capture")
		return
	
	# Create initial render and then set up timer for updates
	_render_canvas_content()
	
	# Create a timer for regular canvas updates
	var timer = Timer.new()
	timer.wait_time = 1.0 / 60.0  # 60 FPS for responsive live updates
	timer.timeout.connect(_update_canvas_render)
	timer.name = "RenderTimer"
	add_child(timer)
	timer.start()
	
	print("OutputWindow: Render capture started at 60 FPS")

func _stop_render_capture() -> void:
	"""Stop capturing the main canvas"""
	# Remove any existing timers
	var render_timer = get_node_or_null("RenderTimer")
	if render_timer:
		render_timer.queue_free()
	
	print("OutputWindow: Render capture stopped")

func _update_canvas_render() -> void:
	"""Update the output canvas with the main canvas content"""
	if not is_output_active or main_canvas == null:
		return
	
	# Update counter for internal tracking
	update_count += 1
	
	# For now, just copy the canvas content
	# TODO: Implement proper render texture capture
	_render_canvas_content()

func _render_canvas_content() -> void:
	"""Render the canvas content to the output window - REAL-TIME EVERY FRAME"""
	if main_canvas == null:
		return
	
	# Get current surfaces from the canvas
	var surfaces = []
	if main_canvas != null and "surfaces" in main_canvas:
		surfaces = main_canvas.surfaces
	
	# GAME ENGINE APPROACH: Always clear and recreate - let the engine optimize
	# This ensures we ALWAYS have the latest state, no complex change detection needed
	
	# Clear all existing output surfaces
	for child in output_canvas.get_children():
		child.queue_free()
	
	# Recreate all surfaces with current data - this is REAL-TIME
	for surface in surfaces:
		_create_output_surface(surface)
	
	# Debug info (reduced frequency to avoid spam)
	# Commented out to reduce log noise
	# if update_count % 300 == 0:  # Every 5 seconds
	#	print("OutputWindow: Real-time render - ", surfaces.size(), " surfaces recreated")

func _create_output_surface(source_surface) -> void:
	"""Create an output version of a surface for clean display - REAL-TIME"""
	if source_surface == null:
		return
	
	# Create a new Control node for the output surface
	var output_surface = Control.new()
	output_surface.custom_minimum_size = Vector2(200, 150)  # Will be adjusted
	
	# Copy position and size from source surface
	if "corner_points" in source_surface:
		output_surface.set_meta("source_corners", source_surface.corner_points)
		_setup_output_surface_geometry(output_surface, source_surface.corner_points)
	
	# Copy surface properties
	if "surface_opacity" in source_surface:
		output_surface.set_meta("surface_opacity", source_surface.surface_opacity)
	else:
		output_surface.set_meta("surface_opacity", 1.0)
	
	if "surface_color" in source_surface:
		output_surface.set_meta("surface_color", source_surface.surface_color)
	else:
		output_surface.set_meta("surface_color", Color.WHITE)
	
	# Copy video alpha flag
	if "video_has_alpha" in source_surface:
		output_surface.set_meta("video_has_alpha", source_surface.video_has_alpha)
	else:
		output_surface.set_meta("video_has_alpha", false)
	
	# Copy chroma key properties
	if "chroma_key_enabled" in source_surface:
		output_surface.set_meta("chroma_key_enabled", source_surface.chroma_key_enabled)
		output_surface.set_meta("chroma_key_color", source_surface.chroma_key_color)
		output_surface.set_meta("chroma_key_threshold", source_surface.chroma_key_threshold)
		output_surface.set_meta("chroma_key_smoothness", source_surface.chroma_key_smoothness)
	else:
		output_surface.set_meta("chroma_key_enabled", false)
	
	# Copy video player state for proper chroma key handling
	if "video_player" in source_surface:
		var is_active_video = source_surface.video_player != null and source_surface.video_player.is_playing()
		output_surface.set_meta("is_from_active_video_player", is_active_video)
	else:
		output_surface.set_meta("is_from_active_video_player", false)
	
	# Copy video texture if available
	if "video_texture" in source_surface and source_surface.video_texture != null:
		_setup_output_surface_texture(output_surface, source_surface.video_texture)
	else:
		# Create drawing node even without texture
		_setup_output_surface_texture(output_surface, null)
	
	# Add to output canvas
	output_canvas.add_child(output_surface)

func _setup_output_surface_geometry(output_surface: Control, corner_points: Array) -> void:
	"""Setup the geometry of an output surface based on corner points"""
	if corner_points.size() != 4:
		return
	
	# Transform coordinates from canvas space to output space
	var transformed_points = _transform_coordinates_to_output(corner_points)
	
	# Calculate bounding box from transformed points
	var min_pos = transformed_points[0]
	var max_pos = transformed_points[0]
	
	for point in corner_points:
		min_pos.x = min(min_pos.x, point.x)
		min_pos.y = min(min_pos.y, point.y)
		max_pos.x = max(max_pos.x, point.x)
		max_pos.y = max(max_pos.y, point.y)
	
	# Set surface bounds
	output_surface.position = min_pos
	output_surface.size = max_pos - min_pos
	
	# Store corner points for custom drawing
	output_surface.set_meta("corner_points", transformed_points)
	output_surface.set_meta("local_corners", _convert_to_local_coords(transformed_points, min_pos))

func _transform_coordinates_to_output(canvas_points: Array) -> Array:
	"""Transform coordinates from canvas space to output window space with aspect ratio preservation"""
	if main_canvas == null:
		return canvas_points  # Return original if no canvas reference
	
	var canvas_size = main_canvas.size
	var output_size = output_canvas.size
	
	# Use uniform scaling to preserve aspect ratio
	# Scale based on the canvas's output bounds rect, not the full canvas
	var canvas_output_rect = main_canvas._get_output_bounds_rect()
	
	# Calculate uniform scale factor based on the output bounds
	var scale_x = output_size.x / canvas_output_rect.size.x
	var scale_y = output_size.y / canvas_output_rect.size.y
	var uniform_scale = min(scale_x, scale_y)  # Use the smaller scale to fit within output
	
	# Calculate centering offset for letterboxing/pillarboxing
	var scaled_canvas_size = canvas_output_rect.size * uniform_scale
	var offset = (output_size - scaled_canvas_size) * 0.5
	
	var transformed_points = []
	for point in canvas_points:
		# First adjust point relative to output bounds rect
		var relative_point = point - canvas_output_rect.position
		
		# Apply uniform scaling
		var transformed_point = Vector2(
			relative_point.x * uniform_scale + offset.x,
			relative_point.y * uniform_scale + offset.y
		)
		transformed_points.append(transformed_point)
	
	return transformed_points

func _convert_to_local_coords(world_corners: Array, offset: Vector2) -> Array:
	"""Convert world coordinates to local coordinates"""
	var local_corners = []
	for corner in world_corners:
		local_corners.append(corner - offset)
	return local_corners

func _setup_output_surface_texture(output_surface: Control, texture: Texture2D) -> void:
	"""Setup texture rendering for an output surface"""
	output_surface.set_meta("video_texture", texture)
	
	# Create a custom drawing node
	var drawing_node = Control.new()
	drawing_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drawing_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawing_node.draw.connect(_draw_output_surface.bind(drawing_node))
	
	output_surface.add_child(drawing_node)
	drawing_node.queue_redraw()


func _draw_output_surface(drawing_node: Control) -> void:
	"""Custom draw function for output surfaces using shared renderer"""
	var parent_surface = drawing_node.get_parent()
	if parent_surface == null:
		return
	
	var corner_points = parent_surface.get_meta("local_corners", [])
	if corner_points.size() != 4:
		return
	
	# Create render data from metadata using shared renderer
	var render_data = SurfaceRenderer.create_render_data_from_meta(parent_surface, corner_points)
	
	# Use shared renderer for consistent content rendering (no editor-specific UI)
	SurfaceRenderer.render_surface_content(drawing_node, render_data)

func get_available_displays() -> Array[Dictionary]:
	"""Get information about available displays"""
	var displays: Array[Dictionary] = []
	var screen_count = DisplayServer.get_screen_count()
	
	for i in range(screen_count):
		var screen_rect = DisplayServer.screen_get_usable_rect(i)
		var display_info = {
			"index": i,
			"name": "Display " + str(i + 1),
			"resolution": Vector2i(screen_rect.size.x, screen_rect.size.y),
			"position": Vector2i(screen_rect.position.x, screen_rect.position.y),
			"is_primary": i == 0
		}
		displays.append(display_info)
	
	return displays

func _draw_output_background() -> void:
	"""Draw background and grid for output window"""
	if not output_canvas:
		return
		
	var canvas_size = output_canvas.size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return
	
	# Draw background based on view mode
	if is_grid_view:
		output_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), background_color_grid)
		_draw_output_grid()
	else:
		output_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), background_color_black)

func _draw_output_grid() -> void:
	"""Draw grid lines for output window"""
	if not output_canvas:
		return
		
	var canvas_size = output_canvas.size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return
	
	# Draw vertical lines
	var x = 0.0
	while x < canvas_size.x:
		output_canvas.draw_line(Vector2(x, 0), Vector2(x, canvas_size.y), grid_color, 1)
		x += grid_size
	
	# Draw horizontal lines  
	var y = 0.0
	while y < canvas_size.y:
		output_canvas.draw_line(Vector2(0, y), Vector2(canvas_size.x, y), grid_color, 1)
		y += grid_size

func set_view_mode(grid_view: bool) -> void:
	"""Set the output view mode and refresh display"""
	is_grid_view = grid_view
	if output_canvas:
		output_canvas.queue_redraw()

func update_grid_settings(grid_size_param: int, opacity: float, color: Color, snap_enabled: bool) -> void:
	"""Update grid settings and refresh display"""
	grid_size = grid_size_param
	grid_color = color
	# Store snap setting for future use
	set_meta("snap_to_grid", snap_enabled)
	if output_canvas:
		output_canvas.queue_redraw()

func _on_close_requested() -> void:
	"""Handle window close request"""
	hide_output()
	output_window_closed.emit()