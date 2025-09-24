extends Control

# SettingsPanelController.gd
# Properties inspector for selected projection surfaces

class_name SettingsPanelController

# Import centralized colors
const Colors = preload("res://scripts/constants/Colors.gd")

# UI References
@onready var surface_label: Label = $ScrollContainer/VBoxContainer/SurfaceInfo/SurfaceLabel
@onready var name_input: LineEdit = $ScrollContainer/VBoxContainer/SurfaceProperties/NameInput
@onready var color_picker: ColorPicker = $ScrollContainer/VBoxContainer/SurfaceProperties/ColorPicker

# Lock UI (created dynamically)
var lock_checkbox: CheckBox = null

# Opacity UI (created dynamically)
var opacity_slider: HSlider = null
var opacity_label: Label = null

# Layer UI (created dynamically)
var layer_section: VBoxContainer = null
var layer_forward_button: Button = null
var layer_backward_button: Button = null
var layer_front_button: Button = null
var layer_back_button: Button = null
var layer_label: Label = null

# Delete UI (created dynamically)
var delete_button: Button = null

# Video UI References (created dynamically)
var video_section: VBoxContainer = null
var video_file_label: Label = null
var video_status_label: Label = null
var video_load_button: Button = null
var video_play_button: Button = null
var video_pause_button: Button = null
var video_stop_button: Button = null

# Current surface reference
var current_surface: ProjectionSurface = null

func _ready() -> void:
	# Create dynamic UI elements
	_create_lock_ui()
	_create_opacity_ui()
	_create_layer_ui()
	_create_delete_ui()
	_create_video_ui()
	
	# Apply consistent theming
	_apply_theme_colors()
	
	# Hide properties initially
	clear_properties()

func show_surface_properties(surface: ProjectionSurface) -> void:
	"""Display properties for the selected surface"""
	# Clear any existing connections first
	_disconnect_signals()
	
	current_surface = surface
	
	if surface_label:
		surface_label.text = "Surface: " + surface.surface_name
		surface_label.show()
	
	if name_input:
		name_input.text = surface.surface_name
		name_input.show()
		name_input.text_changed.connect(_on_name_changed)
	
	if color_picker:
		color_picker.color = surface.surface_color
		color_picker.show()
		color_picker.color_changed.connect(_on_color_changed)
	
	if lock_checkbox:
		lock_checkbox.button_pressed = surface.is_locked
		lock_checkbox.show()
		lock_checkbox.toggled.connect(_on_lock_toggled)
	
	if opacity_slider and opacity_label:
		opacity_slider.value = surface.surface_opacity
		opacity_label.text = "Opacity: " + str(int(surface.surface_opacity * 100)) + "%"
		opacity_slider.show()
		opacity_label.show()
		opacity_slider.value_changed.connect(_on_opacity_changed)
	
	# Update layer controls
	if layer_section and layer_label and layer_forward_button and layer_backward_button and layer_front_button and layer_back_button:
		layer_label.text = "Z-Index: " + str(surface.surface_z_index)
		layer_section.show()
		
		# Connect layer control signals
		layer_forward_button.pressed.connect(_on_layer_forward_pressed)
		layer_backward_button.pressed.connect(_on_layer_backward_pressed)
		layer_front_button.pressed.connect(_on_layer_front_pressed)
		layer_back_button.pressed.connect(_on_layer_back_pressed)
	
	# Update delete button
	if delete_button:
		delete_button.show()
		delete_button.pressed.connect(_on_delete_pressed)
	
	# Update video display
	_update_video_display()
	_update_button_states()
	
	# Show video section
	if video_section:
		video_section.show()
	
	# Show the properties container
	visible = true

func clear_properties() -> void:
	"""Hide properties when no surface is selected"""
	_disconnect_signals()
	current_surface = null
	
	if surface_label:
		surface_label.hide()
	
	if name_input:
		name_input.hide()
	
	if color_picker:
		color_picker.hide()
	
	if lock_checkbox:
		lock_checkbox.hide()
	
	if opacity_slider:
		opacity_slider.hide()
		
	if opacity_label:
		opacity_label.hide()
	
	if layer_section:
		layer_section.hide()
	
	if delete_button:
		delete_button.hide()
	
	# Hide video section
	if video_section:
		video_section.hide()
	
	# Keep panel visible but show "No selection" message
	visible = true

func _disconnect_signals() -> void:
	"""Disconnect any existing signal connections"""
	if name_input and name_input.text_changed.is_connected(_on_name_changed):
		name_input.text_changed.disconnect(_on_name_changed)
	
	if color_picker and color_picker.color_changed.is_connected(_on_color_changed):
		color_picker.color_changed.disconnect(_on_color_changed)
	
	if lock_checkbox and lock_checkbox.toggled.is_connected(_on_lock_toggled):
		lock_checkbox.toggled.disconnect(_on_lock_toggled)
	
	if opacity_slider and opacity_slider.value_changed.is_connected(_on_opacity_changed):
		opacity_slider.value_changed.disconnect(_on_opacity_changed)
	
	# Disconnect layer control signals
	if layer_forward_button and layer_forward_button.pressed.is_connected(_on_layer_forward_pressed):
		layer_forward_button.pressed.disconnect(_on_layer_forward_pressed)
	if layer_backward_button and layer_backward_button.pressed.is_connected(_on_layer_backward_pressed):
		layer_backward_button.pressed.disconnect(_on_layer_backward_pressed)
	if layer_front_button and layer_front_button.pressed.is_connected(_on_layer_front_pressed):
		layer_front_button.pressed.disconnect(_on_layer_front_pressed)
	if layer_back_button and layer_back_button.pressed.is_connected(_on_layer_back_pressed):
		layer_back_button.pressed.disconnect(_on_layer_back_pressed)
	
	if delete_button and delete_button.pressed.is_connected(_on_delete_pressed):
		delete_button.pressed.disconnect(_on_delete_pressed)

func _on_name_changed(new_name: String) -> void:
	"""Handle surface name change"""
	if current_surface:
		current_surface.surface_name = new_name
		if surface_label:
			surface_label.text = "Surface: " + new_name

func _on_color_changed(new_color: Color) -> void:
	"""Handle surface color change"""
	if current_surface:
		current_surface.surface_color = new_color
		current_surface.queue_redraw()

func _on_lock_toggled(is_pressed: bool) -> void:
	"""Handle surface lock toggle"""
	if current_surface:
		current_surface.is_locked = is_pressed
		current_surface.queue_redraw()
		print("SettingsPanel: Surface lock toggled to: ", is_pressed)

func _on_opacity_changed(value: float) -> void:
	"""Handle surface opacity change"""
	if current_surface and opacity_label:
		current_surface.surface_opacity = value
		current_surface.queue_redraw()
		opacity_label.text = "Opacity: " + str(int(value * 100)) + "%"
		print("SettingsPanel: Surface opacity changed to: ", value)

func _on_layer_forward_pressed() -> void:
	"""Handle bring forward button press"""
	if current_surface:
		var canvas = _find_mapping_canvas()
		if canvas and canvas.has_method("bring_surface_forward"):
			canvas.bring_surface_forward(current_surface)
			layer_label.text = "Z-Index: " + str(current_surface.surface_z_index)
			print("SettingsPanel: Brought surface forward, new z-index: ", current_surface.surface_z_index)
		else:
			print("SettingsPanel: Could not find mapping canvas or method")

func _on_layer_backward_pressed() -> void:
	"""Handle send backward button press"""
	if current_surface:
		var canvas = _find_mapping_canvas()
		if canvas and canvas.has_method("send_surface_backward"):
			canvas.send_surface_backward(current_surface)
			layer_label.text = "Z-Index: " + str(current_surface.surface_z_index)
			print("SettingsPanel: Sent surface backward, new z-index: ", current_surface.surface_z_index)
		else:
			print("SettingsPanel: Could not find mapping canvas or method")

func _on_layer_front_pressed() -> void:
	"""Handle bring to front button press"""
	if current_surface:
		var canvas = _find_mapping_canvas()
		if canvas and canvas.has_method("bring_surface_to_front"):
			canvas.bring_surface_to_front(current_surface)
			layer_label.text = "Z-Index: " + str(current_surface.surface_z_index)
			print("SettingsPanel: Brought surface to front, new z-index: ", current_surface.surface_z_index)
		else:
			print("SettingsPanel: Could not find mapping canvas or method")

func _on_layer_back_pressed() -> void:
	"""Handle send to back button press"""
	if current_surface:
		var canvas = _find_mapping_canvas()
		if canvas and canvas.has_method("send_surface_to_back"):
			canvas.send_surface_to_back(current_surface)
			layer_label.text = "Z-Index: " + str(current_surface.surface_z_index)
			print("SettingsPanel: Sent surface to back, new z-index: ", current_surface.surface_z_index)
		else:
			print("SettingsPanel: Could not find mapping canvas or method")

func _find_mapping_canvas() -> Node:
	"""Find the MappingCanvas node in the scene tree"""
	# Try common paths first
	var paths_to_try = [
		"../../MappingCanvas",
		"../MappingCanvas", 
		"../../MainContent/MappingCanvas",
		"../MainContent/MappingCanvas"
	]
	
	for path in paths_to_try:
		var node = get_node_or_null(path)
		if node != null:
			return node
	
	# If direct paths fail, search the tree
	var main_scene = get_tree().current_scene
	if main_scene:
		return _find_node_by_class(main_scene, "MappingCanvasController")
	
	return null

func _find_node_by_class(target_node: Node, target_class_name: String) -> Node:
	"""Recursively find a node by its class name"""
	if target_node.get_script() != null:
		var script = target_node.get_script()
		if script.get_global_name() == target_class_name:
			return target_node
	
	for child in target_node.get_children():
		var result = _find_node_by_class(child, target_class_name)
		if result != null:
			return result
	
	return null

func _on_delete_pressed() -> void:
	"""Handle delete surface button press"""
	if current_surface:
		# Show confirmation dialog
		var confirm_dialog = ConfirmationDialog.new()
		confirm_dialog.dialog_text = "Are you sure you want to delete surface '" + current_surface.surface_name + "'?"
		confirm_dialog.title = "Delete Surface"
		confirm_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_KEYBOARD_FOCUS
		
		confirm_dialog.confirmed.connect(_on_delete_confirmed.bind(current_surface))
		confirm_dialog.close_requested.connect(_on_delete_dialog_closed.bind(confirm_dialog))
		
		get_tree().current_scene.add_child(confirm_dialog)
		confirm_dialog.popup_centered()

func _on_delete_confirmed(surface_to_delete: ProjectionSurface) -> void:
	"""Handle delete confirmation"""
	if surface_to_delete:
		surface_to_delete._delete_surface()
		current_surface = null
		clear_properties()

func _on_delete_dialog_closed(dialog: AcceptDialog) -> void:
	"""Clean up delete confirmation dialog"""
	dialog.queue_free()

func _create_lock_ui() -> void:
	"""Create lock-related UI elements dynamically"""
	var properties_container = $ScrollContainer/VBoxContainer/SurfaceProperties
	if not properties_container:
		return
	
	# Add separator
	var separator = HSeparator.new()
	properties_container.add_child(separator)
	
	# Create lock checkbox
	lock_checkbox = CheckBox.new()
	lock_checkbox.text = "Lock Surface"
	lock_checkbox.custom_minimum_size = Vector2(0, 30)
	lock_checkbox.add_theme_color_override("font_color", Colors.UI_TEXT_PRIMARY)
	properties_container.add_child(lock_checkbox)

func _create_opacity_ui() -> void:
	"""Create opacity-related UI elements dynamically"""
	var properties_container = $ScrollContainer/VBoxContainer/SurfaceProperties
	if not properties_container:
		return
	
	# Add separator
	var separator = HSeparator.new()
	properties_container.add_child(separator)
	
	# Create opacity label
	opacity_label = Label.new()
	opacity_label.text = "Opacity: 100%"
	opacity_label.add_theme_color_override("font_color", Colors.UI_TEXT_PRIMARY)
	properties_container.add_child(opacity_label)
	
	# Create opacity slider
	opacity_slider = HSlider.new()
	opacity_slider.min_value = 0.0
	opacity_slider.max_value = 1.0
	opacity_slider.step = 0.01
	opacity_slider.value = 1.0
	opacity_slider.custom_minimum_size = Vector2(200, 30)
	properties_container.add_child(opacity_slider)

func _create_layer_ui() -> void:
	"""Create layer ordering UI elements dynamically"""
	var properties_container = $ScrollContainer/VBoxContainer/SurfaceProperties
	if not properties_container:
		return
	
	# Add separator
	var separator = HSeparator.new()
	properties_container.add_child(separator)
	
	# Create layer section
	layer_section = VBoxContainer.new()
	properties_container.add_child(layer_section)
	
	# Layer section title
	var layer_title = Label.new()
	layer_title.text = "Layer Order:"
	layer_section.add_child(layer_title)
	
	# Layer info label
	layer_label = Label.new()
	layer_label.text = "Z-Index: 0"
	layer_section.add_child(layer_label)
	
	# Layer control buttons container
	var buttons_container = HBoxContainer.new()
	layer_section.add_child(buttons_container)
	
	# Layer control buttons
	layer_back_button = Button.new()
	layer_back_button.text = "To Back"
	layer_back_button.custom_minimum_size = Vector2(70, 30)
	layer_back_button.add_theme_color_override("font_color", Colors.UI_TEXT_PRIMARY)
	buttons_container.add_child(layer_back_button)
	
	layer_backward_button = Button.new()
	layer_backward_button.text = "Back"
	layer_backward_button.custom_minimum_size = Vector2(50, 30)
	layer_backward_button.add_theme_color_override("font_color", Colors.UI_TEXT_PRIMARY)
	buttons_container.add_child(layer_backward_button)
	
	layer_forward_button = Button.new()
	layer_forward_button.text = "Forward"
	layer_forward_button.custom_minimum_size = Vector2(60, 30)
	layer_forward_button.add_theme_color_override("font_color", Colors.UI_TEXT_PRIMARY)
	buttons_container.add_child(layer_forward_button)
	
	layer_front_button = Button.new()
	layer_front_button.text = "To Front"
	layer_front_button.custom_minimum_size = Vector2(70, 30)
	layer_front_button.add_theme_color_override("font_color", Colors.UI_TEXT_PRIMARY)
	buttons_container.add_child(layer_front_button)

func _create_delete_ui() -> void:
	"""Create delete UI elements dynamically"""
	var properties_container = $ScrollContainer/VBoxContainer/SurfaceProperties
	if not properties_container:
		return
	
	# Add separator
	var separator = HSeparator.new()
	properties_container.add_child(separator)
	
	# Create delete button
	delete_button = Button.new()
	delete_button.text = "Delete Surface"
	delete_button.custom_minimum_size = Vector2(0, 35)
	# Use centralized colors
	delete_button.add_theme_color_override("font_color", Colors.UI_TEXT_WARNING)
	delete_button.add_theme_color_override("font_hover_color", Colors.UI_TEXT_WARNING_HOVER)
	delete_button.modulate = Colors.BUTTON_NORMAL_TINT
	properties_container.add_child(delete_button)

func _create_video_ui() -> void:
	"""Create video-related UI elements dynamically"""
	var properties_container = $ScrollContainer/VBoxContainer/SurfaceProperties
	if not properties_container:
		return
	
	# Add separator
	var separator = HSeparator.new()
	properties_container.add_child(separator)
	
	# Create video section
	video_section = VBoxContainer.new()
	properties_container.add_child(video_section)
	
	# Video section title
	var video_title = Label.new()
	video_title.text = "Video:"
	video_title.add_theme_color_override("font_color", Colors.UI_TEXT_PRIMARY)
	video_section.add_child(video_title)
	
	# Video file label
	video_file_label = Label.new()
	video_file_label.text = "No video loaded"
	video_file_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	video_file_label.add_theme_color_override("font_color", Colors.UI_TEXT_PRIMARY)
	video_section.add_child(video_file_label)
	
	# Video status label
	video_status_label = Label.new()
	video_status_label.text = "Status: Stopped"
	video_status_label.add_theme_color_override("font_color", Colors.UI_TEXT_PRIMARY)
	video_section.add_child(video_status_label)
	
	# Video load button
	video_load_button = Button.new()
	video_load_button.text = "Load Video..."
	video_load_button.add_theme_color_override("font_color", Colors.UI_TEXT_PRIMARY)
	video_load_button.pressed.connect(_on_video_load_button_pressed)
	video_section.add_child(video_load_button)
	
	# Video control buttons container
	var controls_container = HBoxContainer.new()
	video_section.add_child(controls_container)
	
	# Play button
	video_play_button = Button.new()
	video_play_button.text = "Play"
	video_play_button.add_theme_color_override("font_color", Colors.UI_TEXT_PRIMARY)
	video_play_button.pressed.connect(_on_video_play_pressed)
	controls_container.add_child(video_play_button)
	
	# Pause button  
	video_pause_button = Button.new()
	video_pause_button.text = "Pause"
	video_pause_button.add_theme_color_override("font_color", Colors.UI_TEXT_PRIMARY)
	video_pause_button.pressed.connect(_on_video_pause_pressed)
	controls_container.add_child(video_pause_button)
	
	# Stop button
	video_stop_button = Button.new()
	video_stop_button.text = "Stop"
	video_stop_button.add_theme_color_override("font_color", Colors.UI_TEXT_PRIMARY)
	video_stop_button.pressed.connect(_on_video_stop_pressed)
	controls_container.add_child(video_stop_button)

func _on_video_load_button_pressed() -> void:
	"""Handle video load button press - delegate to surface"""
	if current_surface:
		current_surface._open_video_file_dialog()

func _on_video_play_pressed() -> void:
	"""Handle video play button press"""
	if current_surface and current_surface.video_player and current_surface.video_player.stream:
		current_surface.video_player.play()
		# Reset pause state when playing
		current_surface.video_player.paused = false
		_update_video_display()
		_update_button_states()

func _on_video_pause_pressed() -> void:
	"""Handle video pause button press"""
	if current_surface and current_surface.video_player:
		current_surface.video_player.paused = not current_surface.video_player.paused
		_update_video_display()
		_update_button_states()

func _on_video_stop_pressed() -> void:
	"""Handle video stop button press"""
	if current_surface and current_surface.video_player:
		current_surface.video_player.stop()
		# Reset pause state when stopping
		current_surface.video_player.paused = false
		_update_video_display()
		_update_button_states()

func _update_video_display() -> void:
	"""Update video information display"""
	if not current_surface or not video_file_label or not video_status_label:
		return
	
	# Update video file path
	if current_surface.video_file_path and current_surface.video_file_path != "":
		video_file_label.text = "File: " + current_surface.video_file_path.get_file()
	else:
		video_file_label.text = "No video loaded"
	
	# Update video status
	if current_surface.video_player and current_surface.video_player.stream:
		if current_surface.video_player.is_playing():
			if current_surface.video_player.paused:
				video_status_label.text = "Status: Paused"
			else:
				video_status_label.text = "Status: Playing"
		else:
			video_status_label.text = "Status: Loaded (Stopped)"
	elif current_surface.video_player:
		video_status_label.text = "Status: No video loaded"
	else:
		video_status_label.text = "Status: No video player"

func _update_button_states() -> void:
	"""Update video control button states based on current video status"""
	if not current_surface or not video_play_button or not video_pause_button or not video_stop_button:
		return
	
	var has_video = current_surface.video_player and current_surface.video_player.stream
	var is_playing = has_video and current_surface.video_player.is_playing()
	var is_paused = has_video and current_surface.video_player.paused
	
	# Enable/disable buttons based on video availability
	video_play_button.disabled = not has_video
	video_pause_button.disabled = not has_video or not is_playing
	video_stop_button.disabled = not has_video
	
	# Update pause button text and pressed state
	if is_paused:
		video_pause_button.text = "Resume"
		video_pause_button.button_pressed = true

func _apply_theme_colors() -> void:
	"""Apply consistent theme colors throughout the panel"""
	# Use centralized color constants instead of magic numbers
	var text_color = Colors.UI_TEXT_PRIMARY
	
	# Apply to all dynamic labels
	if surface_label:
		surface_label.add_theme_color_override("font_color", text_color)
	if opacity_label:
		opacity_label.add_theme_color_override("font_color", text_color)
	if layer_label:
		layer_label.add_theme_color_override("font_color", text_color)
	if video_file_label:
		video_file_label.add_theme_color_override("font_color", text_color)
	if video_status_label:
		video_status_label.add_theme_color_override("font_color", text_color)
	
	# Apply to static labels in the scene
	var title_label = $ScrollContainer/VBoxContainer/TitleLabel
	if title_label:
		title_label.add_theme_color_override("font_color", text_color)
	
	var name_label = $ScrollContainer/VBoxContainer/SurfaceProperties/NameLabel
	if name_label:
		name_label.add_theme_color_override("font_color", text_color)
	
	var color_label = $ScrollContainer/VBoxContainer/SurfaceProperties/ColorLabel
	if color_label:
		color_label.add_theme_color_override("font_color", text_color)
	
	# Apply to input fields
	if name_input:
		name_input.add_theme_color_override("font_color", text_color)
		name_input.add_theme_color_override("font_placeholder_color", Colors.UI_TEXT_SECONDARY)
	
	# Apply to all dynamically created UI elements
	if lock_checkbox:
		lock_checkbox.add_theme_color_override("font_color", text_color)
	if opacity_slider:
		opacity_slider.add_theme_color_override("font_color", text_color)
	if layer_back_button:
		layer_back_button.add_theme_color_override("font_color", text_color)
	if layer_backward_button:
		layer_backward_button.add_theme_color_override("font_color", text_color)
	if layer_forward_button:
		layer_forward_button.add_theme_color_override("font_color", text_color)
	if layer_front_button:
		layer_front_button.add_theme_color_override("font_color", text_color)
	
	# Apply to video UI elements
	if video_play_button:
		video_play_button.add_theme_color_override("font_color", text_color)
	if video_pause_button:
		video_pause_button.add_theme_color_override("font_color", text_color)
	if video_stop_button:
		video_stop_button.add_theme_color_override("font_color", text_color)
	if video_load_button:
		video_load_button.add_theme_color_override("font_color", text_color)
	else:
		video_pause_button.text = "Pause"
		video_pause_button.button_pressed = false