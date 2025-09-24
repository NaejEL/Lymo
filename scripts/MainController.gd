extends Control

# MainController.gd
# Root controller for Lymo videomapping application
# Manages the main window layout and coordinates between components

class_name MainController

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

func _setup_window() -> void:
	"""Configure main window properties"""
	# Set minimum window size for usability
	get_window().min_size = Vector2i(800, 600)
	
	# Configure split container
	if content_container:
		content_container.split_offset = 900  # Give more space to mapping canvas
		
	# Add temporary background colors for debugging
	if top_bar:
		top_bar.modulate = Color.LIGHT_BLUE
	if settings_panel:
		settings_panel.modulate = Color.LIGHT_GREEN

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
		project_manager.show_save_dialog(project_data)

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
	if output_window:
		output_window.set_target_display(display_index)
		print("MainController: Changed output to display ", display_index)
	else:
		print("MainController: Display changed to ", display_index, " but no output window exists")

func _on_fullscreen_requested() -> void:
	"""Handle fullscreen toggle request"""
	if output_window:
		output_window.toggle_fullscreen()
		print("MainController: Toggled output fullscreen")
	else:
		print("MainController: Fullscreen requested but no output window exists")

func _on_project_loaded(data: Dictionary) -> void:
	"""Handle project loaded from file"""
	if mapping_canvas and data:
		mapping_canvas.load_project_data(data)
		print("MainController: Project loaded successfully")

func _on_project_saved(path: String) -> void:
	"""Handle project saved to file"""
	print("MainController: Project saved to ", path)