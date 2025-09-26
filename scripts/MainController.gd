extends Control

# MainController.gd
# Root controller for Lymo videomapping application
# Manages the main window layout and coordinates between components

class_name MainController

# Explicit imports to ensure loading order
const TopBarController = preload("res://scripts/components/TopBarController.gd")

# References to main UI components
@onready var top_bar: TopBarController = $VBoxContainer/TopBar
@onready var content_container: HSplitContainer = $VBoxContainer/ContentContainer
@onready var mapping_canvas: MappingCanvasController = $VBoxContainer/ContentContainer/MappingCanvas
@onready var settings_panel: SettingsPanelController = $VBoxContainer/ContentContainer/SettingsPanel

# Managers
var video_manager: VideoManager
var project_manager: ProjectManager
var export_manager: ExportManager

# Output window
var output_window: OutputWindowController
var output_window_scene: PackedScene

func _ready() -> void:
	# Initialize the application
	_setup_managers()
	_connect_signals()
	_load_window_settings()
	_setup_window()
	
	# Load default project or prompt user
	_initialize_project()

func _setup_managers() -> void:
	"""Initialize all manager singletons"""
	# Load output window scene
	output_window_scene = preload("res://scenes/OutputWindow.tscn")
	video_manager = VideoManager.new()
	video_manager.name = "VideoManager"
	project_manager = ProjectManager.new()
	project_manager.name = "ProjectManager"
	export_manager = ExportManager.new()
	export_manager.name = "ExportManager"
	
	# Add managers to scene tree to enable processing
	add_child(video_manager)
	add_child(project_manager)
	add_child(export_manager)

func _connect_signals() -> void:
	"""Connect signals between components"""
	# Top bar to main controller
	if top_bar:
		top_bar.file_new_requested.connect(_on_file_new_requested)
		top_bar.file_open_requested.connect(_on_file_open_requested)
		top_bar.file_save_requested.connect(_on_file_save_requested)
		top_bar.file_save_as_requested.connect(_on_file_save_as_requested)
		top_bar.play_all_requested.connect(_on_play_all_requested)
		top_bar.stop_all_requested.connect(_on_stop_all_requested)
		
		# View controls
		top_bar.view_mode_changed.connect(_on_view_mode_changed)
		top_bar.grid_settings_changed.connect(_on_grid_settings_changed)
		top_bar.surface_selection_settings_changed.connect(_on_surface_selection_settings_changed)
		top_bar.surface_transform_settings_changed.connect(_on_surface_transform_settings_changed)
		
		# Output window controls
		top_bar.output_toggle_requested.connect(_on_output_toggle_requested)
		top_bar.display_changed.connect(_on_display_changed)
		top_bar.fullscreen_requested.connect(_on_fullscreen_requested)
	
	# Video manager to top bar
	if video_manager and top_bar:
		video_manager.playback_started.connect(top_bar.update_playback_state.bind(true))
		video_manager.playback_stopped.connect(top_bar.update_playback_state.bind(false))
	
	# Video manager to surfaces
	if video_manager:
		video_manager.video_loaded.connect(_on_video_loaded)
		video_manager.video_conversion_started.connect(_on_video_conversion_started)
		video_manager.video_conversion_completed.connect(_on_video_conversion_completed)
		video_manager.video_conversion_failed.connect(_on_video_conversion_failed)
	
	# Project manager
	if project_manager:
		project_manager.project_loaded.connect(_on_project_loaded)
		project_manager.project_saved.connect(_on_project_saved)
	
	# Mapping canvas selection to settings panel
	if mapping_canvas and settings_panel:
		mapping_canvas.surface_selected.connect(settings_panel.show_surface_properties)
		mapping_canvas.surface_deselected.connect(settings_panel.clear_properties)
	
	# Initialize canvas with default output resolution
	_initialize_canvas_aspect_ratio()

func _setup_window() -> void:
	"""Configure main window properties with proper scaling and sizing"""
	var window = get_window()
	
	# Set minimum window size for usability
	window.min_size = Vector2i(1000, 700)  # Increased from 800x600 for better UX
	
	# Set reasonable default size based on screen size
	var primary_screen = DisplayServer.screen_get_usable_rect(0)
	var default_width = min(1400, int(primary_screen.size.x * 0.8))  # 80% of screen width, max 1400
	var default_height = min(900, int(primary_screen.size.y * 0.8))  # 80% of screen height, max 900
	
	window.size = Vector2i(default_width, default_height)
	
	# Center window on primary display
	var center_x = primary_screen.position.x + (primary_screen.size.x - default_width) / 2
	var center_y = primary_screen.position.y + (primary_screen.size.y - default_height) / 2
	window.position = Vector2i(center_x, center_y)
	
	# Disable content scaling to provide more workspace instead of bigger widgets
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	
	print("MainWindow: Set default size to ", window.size, " on screen ", primary_screen.size)
	
	# Configure split container with proportional sizing
	if content_container:
		# Give mapping canvas 70% of the window width (more space for editing)
		var canvas_width = int(default_width * 0.7)
		content_container.split_offset = canvas_width
		print("MainWindow: Set split offset to ", canvas_width)
	
	# Connect window resize signal for responsive layout updates
	window.size_changed.connect(_on_window_resized)

func _initialize_project() -> void:
	"""Initialize with empty project or load last project"""
	if project_manager:
		project_manager.create_new_project()

# Signal handlers
func _on_file_new_requested() -> void:
	"""Handle new project request from top bar"""
	if project_manager:
		project_manager.create_new_project()
		mapping_canvas.clear_all_surfaces()
		settings_panel.clear_properties()

func _on_file_open_requested() -> void:
	"""Handle open project request from top bar"""
	if project_manager:
		project_manager.show_open_dialog()

func _on_file_save_requested() -> void:
	"""Handle save project request from top bar"""
	if project_manager and mapping_canvas:
		var project_data = mapping_canvas.get_project_data()
		project_manager.save_project(project_data)  # Use save_project, not show_save_dialog

func _on_file_save_as_requested() -> void:
	"""Handle save as project request from top bar"""
	if project_manager and mapping_canvas:
		var project_data = mapping_canvas.get_project_data()
		project_manager.show_save_as_dialog(project_data)

func _on_play_all_requested() -> void:
	"""Handle play all request from top bar - start all surface videos"""
	if mapping_canvas:
		mapping_canvas.play_all_surface_videos()

func _on_stop_all_requested() -> void:
	"""Handle stop all request from top bar - stop all surface videos"""
	if mapping_canvas:
		mapping_canvas.stop_all_surface_videos()

func _on_video_loaded(texture: Texture2D) -> void:
	"""Handle video loaded - set texture on all surfaces"""  
	print("MainController: Video loaded, setting texture on surfaces")
	if mapping_canvas:
		# Get all surfaces from the mapping canvas
		for surface in mapping_canvas.surfaces:
			surface.set_video_texture(texture)
			print("MainController: Set video texture on surface: ", surface.surface_name)

func _on_video_conversion_started(original_path: String, target_path: String) -> void:
	"""Handle video conversion started"""
	print("MainController: Video conversion started: ", original_path.get_file(), " -> ", target_path.get_file())
	# TODO: Show conversion progress UI
	if top_bar and top_bar.video_source_button:
		top_bar.video_source_button.text = "Converting: " + original_path.get_file()
		top_bar.video_source_button.disabled = true

func _on_video_conversion_completed(original_path: String, target_path: String) -> void:
	"""Handle video conversion completed"""
	print("MainController: Video conversion completed successfully")
	if top_bar and top_bar.video_source_button:
		top_bar.video_source_button.text = "Video: " + original_path.get_file()
		top_bar.video_source_button.disabled = false

func _on_video_conversion_failed(original_path: String, error: String) -> void:
	"""Handle video conversion failed"""
	print("MainController: Video conversion failed: ", error)
	if top_bar and top_bar.video_source_button:
		top_bar.video_source_button.text = "Video (conversion failed)"
		top_bar.video_source_button.disabled = false
	# TODO: Show error dialog to user

# Input handling
func _input(event: InputEvent) -> void:
	"""Handle global shortcuts"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_N when event.ctrl_pressed:
				_on_file_new_requested()
			KEY_O when event.ctrl_pressed:
				_on_file_open_requested()
			KEY_R when event.ctrl_pressed:
				# Force refresh output window
				if output_window != null and output_window.is_output_active:
					print("MainController: Force refreshing output window")
					output_window.force_surface_update()
			KEY_F11:
				toggle_output_window()

# Output Window Management
func create_output_window() -> void:
	"""Create and initialize the output window"""
	if output_window != null:
		print("MainController: Output window already exists")
		return
	
	if output_window_scene == null:
		print("MainController: Error - Output window scene not loaded")
		return
	
	output_window = output_window_scene.instantiate()
	if output_window == null:
		print("MainController: Error - Could not instantiate output window")
		return
	
	# Add to scene tree as a separate window (not replacing main window)
	get_tree().root.add_child(output_window)
	
	# Ensure it doesn't interfere with main window
	output_window.wrap_controls = false
	output_window.transient = false
	
	# Make sure it's not the main window
	output_window.force_native = true
	
	print("MainController: Output window added to scene tree")
	print("MainController: Main window is: ", get_window())
	print("MainController: Output window is: ", output_window)
	
	# Connect signals
	output_window.output_window_closed.connect(_on_output_window_closed)
	output_window.output_resolution_changed.connect(_on_output_resolution_changed)
	
	# Sync view mode with main canvas
	if mapping_canvas:
		output_window.set_view_mode(mapping_canvas.is_grid_view)
	
	print("MainController: Output window created")

func show_output_window(display_index: int = 1) -> void:
	"""Show the output window on the specified display"""
	if output_window == null:
		create_output_window()
	
	if output_window == null:
		print("MainController: Failed to create output window")
		return
	
	# Set target display
	output_window.set_target_display(display_index)
	
	# Show output with canvas content
	output_window.show_output(mapping_canvas)
	
	# Update top bar to reflect output state
	if top_bar:
		top_bar.set_output_active(true)
	
	print("MainController: Output window shown on display ", display_index)

func hide_output_window() -> void:
	"""Hide the output window"""
	if output_window != null:
		output_window.hide_output()
	
	# Update top bar to reflect output state
	if top_bar:
		top_bar.set_output_active(false)

func toggle_output_window() -> void:
	"""Toggle the output window visibility"""
	if output_window == null or not output_window.visible:
		show_output_window()
	else:
		hide_output_window()

func get_available_displays() -> Array[Dictionary]:
	"""Get information about available displays"""
	if output_window != null:
		return output_window.get_available_displays()
	else:
		# Fallback implementation
		var displays: Array[Dictionary] = []
		var screen_count = DisplayServer.get_screen_count()
		
		for i in range(screen_count):
			var screen_rect = DisplayServer.screen_get_usable_rect(i)
			var display_info = {
				"index": i,
				"name": "Display " + str(i + 1), 
				"resolution": Vector2i(screen_rect.size.x, screen_rect.size.y),
				"is_primary": i == 0
			}
			displays.append(display_info)
		
		return displays

func _on_output_window_closed() -> void:
	"""Handle output window being closed"""
	print("MainController: Output window closed")
	# Update top bar state
	if top_bar:
		top_bar.set_output_active(false)

func _on_view_mode_changed(is_grid_view: bool) -> void:
	"""Handle view mode change from top bar"""
	if mapping_canvas:
		mapping_canvas.set_view_mode(is_grid_view)
	
	# Also update output window if it exists
	if output_window:
		output_window.set_view_mode(is_grid_view)

func _on_grid_settings_changed(grid_size_param: int, opacity: float, color: Color, snap_to_grid: bool) -> void:
	"""Handle grid settings changes from top bar"""
	if mapping_canvas:
		mapping_canvas.update_grid_settings(grid_size_param, opacity, color, snap_to_grid)
	
	# Also update output window if it exists
	if output_window:
		output_window.update_grid_settings(grid_size_param, opacity, color, snap_to_grid)

func _on_surface_selection_settings_changed(corner_tolerance: float, edge_tolerance: float, handle_size: float) -> void:
	"""Handle surface selection settings changes from top bar"""
	if mapping_canvas:
		mapping_canvas.set_surface_selection_tolerance(corner_tolerance, edge_tolerance)
		mapping_canvas.set_surface_handle_appearance(handle_size, 2.0)  # Default border width
	
	print("MainController: Updated surface selection settings - Corner: ", corner_tolerance, ", Edge: ", edge_tolerance, ", Handle: ", handle_size)

func _on_surface_transform_settings_changed(transform_handle_size: float, transform_handle_offset: float, transform_handles_enabled: bool) -> void:
	"""Handle surface transformation settings changes from top bar"""
	if mapping_canvas:
		mapping_canvas.set_surface_transform_handles(transform_handle_size, transform_handle_offset, transform_handles_enabled)
	
	print("MainController: Updated surface transform settings - Size: ", transform_handle_size, ", Offset: ", transform_handle_offset, ", Enabled: ", transform_handles_enabled)

func _on_output_toggle_requested() -> void:
	"""Handle output toggle request from top bar"""
	toggle_output_window()
	
	# Update top bar state
	if top_bar and output_window:
		top_bar.set_output_active(output_window.visible)

func _on_display_changed(display_index: int) -> void:
	"""Handle display selection change"""
	# Always update canvas preview for the selected display, regardless of output window state
	var screen_size = DisplayServer.screen_get_size(display_index)
	var display_resolution = Vector2i(screen_size.x, screen_size.y)
	
	if mapping_canvas:
		mapping_canvas.set_target_aspect_ratio(display_resolution)
		print("MainController: Updated canvas preview for display ", display_index, " (", display_resolution, ")")
	
	# Also update output window if it exists
	if output_window:
		output_window.set_target_display(display_index)
		print("MainController: Changed output window to display ", display_index)
	else:
		print("MainController: Display changed to ", display_index, " - canvas updated, no output window yet")

func _on_fullscreen_requested() -> void:
	"""Handle fullscreen toggle request"""
	if output_window:
		output_window.toggle_fullscreen()
		print("MainController: Toggled output fullscreen")
	else:
		print("MainController: Fullscreen requested but no output window exists")

func _on_output_resolution_changed(resolution: Vector2i) -> void:
	"""Handle output resolution change and update canvas aspect ratio"""
	if mapping_canvas:
		mapping_canvas.set_target_aspect_ratio(resolution)
		print("MainController: Updated canvas aspect ratio to match ", resolution)
	else:
		print("MainController: Resolution changed to ", resolution, " but no canvas available")

func _on_project_loaded(data: Dictionary) -> void:
	"""Handle project loaded from file"""
	if mapping_canvas and data:
		mapping_canvas.load_project_data(data)
		print("MainController: Project loaded successfully")

func _on_project_saved(path: String) -> void:
	"""Handle project saved to file"""
	print("MainController: Project saved to ", path)

func _initialize_canvas_aspect_ratio() -> void:
	"""Initialize canvas with the appropriate aspect ratio for the selected display"""
	if not mapping_canvas:
		return
	
	# Get the current selected display from top bar
	var selected_display = 0  # Default to primary display
	if top_bar and top_bar.display_selector:
		selected_display = top_bar.display_selector.selected
	
	# Get the resolution for that display
	var screen_size = DisplayServer.screen_get_size(selected_display)
	var display_resolution = Vector2i(screen_size.x, screen_size.y)
	
	print("MainController: Initializing canvas with display ", selected_display, " resolution: ", display_resolution)
	mapping_canvas.set_target_aspect_ratio(display_resolution)

func _on_window_resized() -> void:
	"""Handle main window resize for responsive layout updates"""
	var window = get_window()
	var new_size = window.size
	
	# Update split container proportions based on new window size
	if content_container and new_size.x > 0:
		# Maintain 70% for canvas, 30% for settings panel
		var canvas_width = int(new_size.x * 0.7)
		content_container.split_offset = canvas_width
	
	# Notify canvas of size changes and handle scaling adjustments
	if mapping_canvas:
		# Give canvas a frame to adjust to new size
		await get_tree().process_frame
		mapping_canvas.handle_window_scaling_change()
		mapping_canvas.queue_redraw()
	
	# Save window settings when size changes
	_save_window_settings()

# Settings persistence methods
func _load_window_settings() -> void:
	"""Load window settings from persistence"""
	var settings = SettingsManager.get_instance()
	var window_size = settings.get_window_size()
	
	# Apply window size if it's reasonable
	if window_size.x > 800 and window_size.y > 600:
		get_window().size = window_size

func _save_window_settings() -> void:
	"""Save current window settings to persistence"""
	var settings = SettingsManager.get_instance()
	var current_size = get_window().size
	
	settings.set_window_size(current_size)
	
	# Save split offset if available
	if content_container:
		settings.set_split_offset(content_container.split_offset)
	
	settings.save_settings()
	
	print("MainWindow: Resized to ", current_size, " - updated layout proportions and canvas scaling")