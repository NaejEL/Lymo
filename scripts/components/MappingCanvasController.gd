extends Control

# MappingCanvasController.gd
# Interactive canvas for creating and manipulating projection surfaces

class_name MappingCanvasController

# Camera controls
var camera_position := Vector2.ZERO
var camera_zoom := 1.0
var is_panning := false
var pan_start_position := Vector2.ZERO

# Surface management
var surfaces: Array[ProjectionSurface] = []
var selected_surface: ProjectionSurface = null

# View mode settings
var is_grid_view: bool = true
var grid_size: int = 20
var grid_color: Color = Color(0.3, 0.3, 0.3, 0.5)  # Standard gray grid
var background_color_black: Color = Color(0.0, 0.0, 0.0, 1.0)  # Pure black background (0x000000)
var background_color_grid: Color = Color(0.2, 0.2, 0.2, 1.0)  # Dark gray grid background

# Surface selection tolerance settings
var default_corner_tolerance: float = 20.0
var default_edge_tolerance: float = 8.0
var default_handle_size: float = 10.0
var default_handle_border_width: float = 2.0

# Click handling
var click_timer: Timer
var pending_click_position: Vector2

# Context menu
var context_menu: PopupMenu
var context_menu_position: Vector2

# Signals
signal surface_selected(surface: ProjectionSurface)
signal surface_deselected

func _ready() -> void:
	# Allow input events and enable focus for keyboard input
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_ALL
	grab_focus()  # Grab focus to receive keyboard events
	
	# Setup click timer for delayed canvas click detection
	click_timer = Timer.new()
	click_timer.wait_time = 0.05  # 50ms delay
	click_timer.one_shot = true
	click_timer.timeout.connect(_on_click_timer_timeout)
	add_child(click_timer)
	
	# Setup context menu
	context_menu = PopupMenu.new()
	context_menu.add_item("Create Surface", 0)
	context_menu.add_separator()
	context_menu.add_item("Paste Surface", 1)
	context_menu.set_item_disabled(1, true)  # Disable until copy/paste is implemented
	context_menu.id_pressed.connect(_on_context_menu_selected)
	add_child(context_menu)
	
	# Delay surface creation to ensure layout is complete
	call_deferred("_setup_canvas")

func _setup_canvas() -> void:
	"""Setup canvas once layout is ready"""
	# Wait a frame for layout to be finalized
	await get_tree().process_frame
	create_default_surface()

func _gui_input(event: InputEvent) -> void:
	"""Handle canvas input for panning, zooming, and context menu"""
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					# Stop any existing click timer first
					if click_timer.time_left > 0:
						click_timer.stop()
					
					# Check if we should select a different surface
					var clicked_surface = _get_topmost_surface_at_position(event.position)
					if clicked_surface:
						# Select the surface if it's different
						if clicked_surface != selected_surface:
							select_surface(clicked_surface)
						
						# Start dragging on the selected surface
						_start_surface_dragging(clicked_surface, event.position)
						return  # Don't start the deselect timer
					
					# Start timer to check if this click should deselect surfaces
					pending_click_position = event.position
					click_timer.start()
				else:
					# Handle mouse button release - forward to selected surface
					if selected_surface:
						_end_surface_dragging(selected_surface, event.position)
			
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					# Show context menu at cursor position
					context_menu_position = event.position
					# Convert to global screen coordinates for popup positioning
					var global_mouse_pos = get_global_mouse_position()
					context_menu.position = Vector2i(global_mouse_pos)
					context_menu.popup()
					
			MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					_start_panning(event.position)
				else:
					_stop_panning()
			
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_at_position(event.position, 1.1)
			
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at_position(event.position, 0.9)
	
	elif event is InputEventMouseMotion:
		if is_panning:
			_update_panning(event.position)
		else:
			# Handle surface motion (dragging or hover)
			_handle_surface_motion(event.position)
	
	elif event is InputEventKey:
		# Handle special canvas hotkeys first
		if event.pressed and event.keycode == KEY_R and event.ctrl_pressed:
			# Ctrl+R: Reset stuck states on selected surface
			if selected_surface:
				selected_surface.reset_dragging_state()
				selected_surface.force_refresh_state()
				accept_event()
				return
		
		# Forward keyboard events to selected surface for fine adjustment
		if selected_surface and selected_surface.handle_keyboard_input(event):
			accept_event()  # Consume the event if the surface handled it

func _start_panning(pan_position: Vector2) -> void:
	"""Start camera panning"""
	is_panning = true
	pan_start_position = pan_position
	Input.set_default_cursor_shape(Input.CURSOR_MOVE)

func _stop_panning() -> void:
	"""Stop camera panning"""
	is_panning = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _update_panning(current_position: Vector2) -> void:
	"""Update camera position during panning"""
	var delta = (current_position - pan_start_position) / camera_zoom
	camera_position -= delta
	pan_start_position = current_position
	queue_redraw()

func _zoom_at_position(zoom_position: Vector2, zoom_factor: float) -> void:
	"""Zoom camera at specific position"""
	var old_zoom = camera_zoom
	camera_zoom = clamp(camera_zoom * zoom_factor, 0.1, 5.0)
	
	# Adjust camera position to zoom at cursor
	var zoom_ratio = camera_zoom / old_zoom
	var screen_center = size * 0.5
	var offset_from_center = zoom_position - screen_center
	camera_position += offset_from_center * (1.0 - 1.0 / zoom_ratio) / camera_zoom
	
	queue_redraw()

func _on_click_timer_timeout() -> void:
	"""Handle delayed click - deselect surfaces if no surface was selected"""
	# If timer expires and no surface claimed the click, deselect all surfaces
	deselect_all_surfaces()

func _on_context_menu_selected(id: int) -> void:
	"""Handle context menu selection"""
	match id:
		0:  # Create Surface
			_create_surface_at_canvas_position(context_menu_position)
		1:  # Paste Surface (future implementation)
			print("Paste surface not implemented yet")

func _create_surface_at_canvas_position(canvas_position: Vector2) -> void:
	"""Create a new projection surface at canvas coordinates"""
	print("Creating surface at canvas position: ", canvas_position)
	
	var surface_scene = preload("res://scenes/components/ProjectionSurface.tscn")
	if not surface_scene:
		print("Error: Could not load ProjectionSurface scene")
		return
	
	var surface = surface_scene.instantiate()
	if not surface:
		print("Error: Could not instantiate ProjectionSurface")
		return
	
	# Ensure surface is created within visible canvas bounds
	var surface_size = Vector2(200, 150)
	var half_size = surface_size * 0.5
	
	# Clamp position to keep surface within canvas bounds
	var min_pos = half_size
	var max_pos = size - half_size
	var clamped_position = Vector2(
		clamp(canvas_position.x, min_pos.x, max_pos.x),
		clamp(canvas_position.y, min_pos.y, max_pos.y)
	)
	
	print("Original position: ", canvas_position)
	print("Clamped position: ", clamped_position)
	print("Canvas size: ", size)
	
	surface.initialize_surface(clamped_position, surface_size)
	
	# Apply default selection tolerance and handle settings
	surface.set_selection_tolerance(default_corner_tolerance, default_edge_tolerance)
	surface.set_handle_appearance(default_handle_size, default_handle_border_width)
	
	# Assign z-index for new surface (higher than existing surfaces)
	var max_z_index = 0
	for existing_surface in surfaces:
		max_z_index = max(max_z_index, existing_surface.surface_z_index)
	surface.surface_z_index = max_z_index + 1
	
	add_child(surface)
	surfaces.append(surface)
	
	# Connect surface signals
	surface.selected.connect(_on_surface_selected)
	surface.deselected.connect(_on_surface_deselected)
	
	# Select the new surface
	select_surface(surface)
	
	print("Surface created successfully. Total surfaces: ", surfaces.size())

func create_default_surface() -> void:
	"""Create a default surface for testing"""
	print("Canvas size: ", size)
	if size != Vector2.ZERO and size.x > 200 and size.y > 200:
		# Create surface at center of canvas with some safety margin
		var center_pos = size * 0.5
		print("Creating default surface at: ", center_pos, " (canvas size: ", size, ")")
		# Use canvas coordinates directly, not world coordinates
		_create_surface_at_canvas_position(center_pos)
	elif size == Vector2.ZERO:
		# If size is still zero, try again after another frame
		print("Canvas size still zero - retrying...")
		await get_tree().process_frame
		create_default_surface()
	else:
		# Canvas is too small, create a smaller surface
		print("Canvas too small (", size, "), creating small surface")
		_create_surface_at_canvas_position(Vector2(100, 100))

func _get_topmost_surface_at_position(click_position: Vector2) -> ProjectionSurface:
	"""Find the topmost surface at the given position (includes corner handles)"""
	var topmost_surface = null
	var highest_index = -1
	
	for surface in surfaces:
		# Check if position is inside this surface OR near a corner handle
		var is_inside_surface = surface._is_point_inside_surface(click_position)
		var corner_index = surface._get_corner_at_position(click_position)
		
		if is_inside_surface or corner_index >= 0:
			var surface_index = surface.get_index()
			if surface_index > highest_index:
				highest_index = surface_index
				topmost_surface = surface
	
	return topmost_surface

func select_surface(surface: ProjectionSurface) -> void:
	"""Select a projection surface"""
	# Cancel any pending canvas click deselection
	if click_timer.time_left > 0:
		click_timer.stop()
	
	# Avoid recursive selection by checking if already selected
	if selected_surface == surface:
		return
	
	if selected_surface:
		selected_surface.set_selected(false)
	
	selected_surface = surface
	if surface:
		surface.set_selected(true)
		surface_selected.emit(surface)

func deselect_all_surfaces() -> void:
	"""Deselect all surfaces"""
	if selected_surface:
		selected_surface.set_selected(false)
		selected_surface = null
	surface_deselected.emit()

func clear_all_surfaces() -> void:
	"""Remove all projection surfaces"""
	for surface in surfaces:
		surface.queue_free()
	surfaces.clear()
	selected_surface = null
	surface_deselected.emit()

func screen_to_world(screen_pos: Vector2) -> Vector2:
	"""Convert screen coordinates to world coordinates"""
	var screen_center = size * 0.5
	return camera_position + (screen_pos - screen_center) / camera_zoom

func world_to_screen(world_pos: Vector2) -> Vector2:
	"""Convert world coordinates to screen coordinates"""
	var screen_center = size * 0.5
	return screen_center + (world_pos - camera_position) * camera_zoom

func get_project_data() -> Dictionary:
	"""Get project data for saving"""
	var project_data = {
		"camera_position": {"x": camera_position.x, "y": camera_position.y},
		"camera_zoom": camera_zoom,
		"surfaces": []
	}
	
	for surface in surfaces:
		project_data.surfaces.append(surface.get_surface_data())
	
	return project_data

func load_project_data(data: Dictionary) -> void:
	"""Load project data"""
	clear_all_surfaces()
	
	print("MappingCanvas: Loading project data with keys: ", data.keys())
	
	if data.has("camera_position"):
		var pos_data = data.camera_position
		if pos_data is Vector2:
			camera_position = pos_data
		elif pos_data is Dictionary and pos_data.has("x") and pos_data.has("y"):
			camera_position = Vector2(pos_data.x, pos_data.y)
		elif pos_data is Array and pos_data.size() >= 2:
			camera_position = Vector2(pos_data[0], pos_data[1])
		elif pos_data is String:
			# Try to parse string representation like "(x, y)"
			var parsed = pos_data.strip_edges().trim_prefix("(").trim_suffix(")")
			var parts = parsed.split(",")
			if parts.size() >= 2:
				camera_position = Vector2(parts[0].to_float(), parts[1].to_float())
		else:
			print("Warning: Unsupported camera_position format: ", typeof(pos_data))
			
	if data.has("camera_zoom"):
		camera_zoom = data.camera_zoom
	
	if data.has("surfaces"):
		for surface_data in data.surfaces:
			_create_surface_from_data(surface_data)
		
		# Update surface ordering based on loaded z-index values
		_update_surface_order()
	
	queue_redraw()

func _create_surface_from_data(data: Dictionary) -> void:
	"""Create a surface from saved data"""
	var surface_scene = preload("res://scenes/components/ProjectionSurface.tscn")
	if not surface_scene:
		print("Error: Could not load ProjectionSurface scene")
		return
	
	var surface = surface_scene.instantiate()
	if not surface:
		print("Error: Could not instantiate ProjectionSurface")
		return
	
	# Load surface data BEFORE adding to scene tree to preserve loaded name
	surface.load_surface_data(data)
	
	# Apply default selection tolerance and handle settings
	surface.set_selection_tolerance(default_corner_tolerance, default_edge_tolerance)
	surface.set_handle_appearance(default_handle_size, default_handle_border_width)
	
	add_child(surface)
	surfaces.append(surface)
	
	# Connect signals
	surface.selected.connect(_on_surface_selected)
	surface.deselected.connect(_on_surface_deselected)

func _on_surface_selected(surface: ProjectionSurface) -> void:
	"""Handle surface selection"""
	select_surface(surface)

func _on_surface_deselected() -> void:
	"""Handle surface deselection"""
	# Don't call deselect_all_surfaces() to avoid infinite recursion
	# Just clear the selected surface reference
	selected_surface = null
	surface_deselected.emit()

func play_all_surface_videos() -> void:
	"""Start playback on all surfaces that have video loaded"""
	for surface in surfaces:
		if surface.video_player and surface.video_player.stream:
			surface.video_player.play()
	print("MappingCanvas: Started playback on all surfaces with video")

func stop_all_surface_videos() -> void:
	"""Stop playback on all surfaces that have video loaded"""
	for surface in surfaces:
		if surface.video_player:
			surface.video_player.stop()
	print("MappingCanvas: Stopped playback on all surfaces")

func _start_surface_dragging(surface: ProjectionSurface, click_position: Vector2) -> void:
	"""Initialize dragging on a surface - forward to the surface with canvas coordinates"""
	if surface:
		# Call the surface's drag start method directly with canvas coordinates
		surface.start_dragging_at_canvas_position(click_position)

func _handle_surface_motion(canvas_position: Vector2) -> void:
	"""Handle mouse motion for surface interaction (dragging or hover)"""
	if selected_surface:
		# Always forward motion to selected surface (for dragging or hover effects)
		selected_surface.handle_canvas_motion(canvas_position)
	else:
		# If no surface is selected, check for hover effects on any surface
		var hovered_surface = _get_topmost_surface_at_position(canvas_position)
		if hovered_surface:
			hovered_surface.handle_canvas_motion(canvas_position)

func _end_surface_dragging(surface: ProjectionSurface, release_position: Vector2) -> void:
	"""End dragging on a surface - forward to the surface with canvas coordinates"""
	if surface:
		# Call the surface's drag end method directly with canvas coordinates
		surface.end_dragging_at_canvas_position(release_position)

func _draw() -> void:
	"""Custom drawing for canvas background and guides"""
	# Don't draw if size is not valid yet
	if size.x <= 0 or size.y <= 0:
		return
	
	# Draw background based on view mode
	if is_grid_view:
		draw_rect(Rect2(Vector2.ZERO, size), background_color_grid)
		# Draw grid if zoomed in enough
		if camera_zoom > 0.5:
			_draw_grid()
	else:
		draw_rect(Rect2(Vector2.ZERO, size), background_color_black)

func _draw_grid() -> void:
	"""Draw background grid for reference"""
	if size.x <= 0 or size.y <= 0:
		return
	
	var effective_grid_size = grid_size * camera_zoom
	var camera_offset_vec = -camera_position * camera_zoom
	var camera_offset = Vector2(
		fmod(camera_offset_vec.x, effective_grid_size),
		fmod(camera_offset_vec.y, effective_grid_size)
	)
	
	# Vertical lines
	var x = camera_offset.x
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1)
		x += effective_grid_size
	
	# Horizontal lines  
	var y = camera_offset.y
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1)
		y += effective_grid_size

func set_view_mode(grid_view: bool) -> void:
	"""Set the canvas view mode and refresh display"""
	is_grid_view = grid_view
	queue_redraw()  # Trigger redraw to show the new background

func update_grid_settings(grid_size_param: int, opacity: float, color: Color, snap_enabled: bool) -> void:
	"""Update grid settings and refresh display"""
	grid_size = grid_size_param
	grid_color = color
	# Store snap setting for future use
	set_meta("snap_to_grid", snap_enabled)
	queue_redraw()  # Trigger redraw to show updated grid

func set_surface_selection_tolerance(corner_tolerance: float, edge_tolerance: float) -> void:
	"""Configure selection tolerance for all surfaces"""
	default_corner_tolerance = corner_tolerance
	default_edge_tolerance = edge_tolerance
	
	# Apply to all existing surfaces
	for surface in surfaces:
		surface.set_selection_tolerance(corner_tolerance, edge_tolerance)

func set_surface_handle_appearance(handle_size: float, border_width: float) -> void:
	"""Configure handle appearance for all surfaces"""
	default_handle_size = handle_size
	default_handle_border_width = border_width
	
	# Apply to all existing surfaces
	for surface in surfaces:
		surface.set_handle_appearance(handle_size, border_width)

func set_surface_transform_handles(transform_handle_size: float, transform_handle_offset: float, transform_handles_enabled: bool) -> void:
	"""Configure transformation handles for all surfaces"""
	# Apply to all existing surfaces
	for surface in surfaces:
		surface.configure_transformation_handles(transform_handle_size, transform_handle_offset, Color.MAGENTA)
		surface.set_transform_handles_visible(transform_handles_enabled)

func get_surface_selection_settings() -> Dictionary:
	"""Get current surface selection settings"""
	return {
		"corner_tolerance": default_corner_tolerance,
		"edge_tolerance": default_edge_tolerance,
		"handle_size": default_handle_size,
		"handle_border_width": default_handle_border_width
	}

func bring_surface_forward(surface: ProjectionSurface) -> void:
	"""Bring surface one layer forward"""
	if not surface in surfaces:
		return
		
	surface.surface_z_index += 1
	_update_surface_order()
	print("MappingCanvas: Brought surface '", surface.surface_name, "' forward to z-index: ", surface.surface_z_index)

func send_surface_backward(surface: ProjectionSurface) -> void:
	"""Send surface one layer backward"""
	if not surface in surfaces:
		return
		
	surface.surface_z_index -= 1
	_update_surface_order()
	print("MappingCanvas: Sent surface '", surface.surface_name, "' backward to z-index: ", surface.surface_z_index)

func bring_surface_to_front(surface: ProjectionSurface) -> void:
	"""Bring surface to the very front (highest z-index)"""
	if not surface in surfaces:
		return
		
	# Find the highest z-index and set this surface above it
	var max_z = surface.surface_z_index
	for other_surface in surfaces:
		if other_surface != surface:
			max_z = max(max_z, other_surface.surface_z_index)
	
	surface.surface_z_index = max_z + 1
	_update_surface_order()
	print("MappingCanvas: Brought surface '", surface.surface_name, "' to front with z-index: ", surface.surface_z_index)

func send_surface_to_back(surface: ProjectionSurface) -> void:
	"""Send surface to the very back (lowest z-index)"""
	if not surface in surfaces:
		return
		
	# Find the lowest z-index and set this surface below it
	var min_z = surface.surface_z_index
	for other_surface in surfaces:
		if other_surface != surface:
			min_z = min(min_z, other_surface.surface_z_index)
	
	surface.surface_z_index = min_z - 1
	_update_surface_order()
	print("MappingCanvas: Sent surface '", surface.surface_name, "' to back with z-index: ", surface.surface_z_index)

func _update_surface_order() -> void:
	"""Update the scene tree order of surfaces based on their z-index"""
	# Sort surfaces by z-index (lowest to highest)
	var sorted_surfaces = surfaces.duplicate()
	sorted_surfaces.sort_custom(func(a, b): return a.surface_z_index < b.surface_z_index)
	
	# Reorder children in the scene tree
	for i in range(sorted_surfaces.size()):
		var surface = sorted_surfaces[i]
		move_child(surface, i)
	
	# Update the surfaces array to match the new order
	surfaces = sorted_surfaces