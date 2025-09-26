extends Control

# TopBarController.gd  
# Main application toolbar with file operations and playbook controls

class_name TopBarController

# Explicit imports for brand system
const Brand = preload("res://scripts/constants/Brand.gd")
const BrandApplier = preload("res://scripts/utils/BrandApplier.gd")

# View state
var is_grid_view: bool = true  # Start with grid view

# Grid settings state
var grid_size: int = 20
var grid_opacity: float = 0.8
var grid_color: Color = Colors.GRID_LINES  # Use centralized color constants
var snap_to_grid: bool = false

# Surface selection tolerance state
var corner_tolerance: float = 20.0
var edge_tolerance: float = 8.0
var handle_size: float = 10.0

# UI References
@onready var file_menu_button: MenuButton = $HBoxContainer/FileMenuButton
@onready var play_button: Button = $HBoxContainer/PlayButton
@onready var stop_button: Button = $HBoxContainer/StopButton
@onready var help_button: Button = $HBoxContainer/HelpButton

# View controls
@onready var view_toggle: Button = $HBoxContainer/ViewToggle
@onready var grid_settings_button: Button = $HBoxContainer/GridSettingsButton

# Grid settings popup
@onready var grid_settings_popup: PopupPanel = $GridSettingsPopup
@onready var grid_size_spinbox: SpinBox = $GridSettingsPopup/GridSettingsContainer/GridSizeContainer/GridSizeSpinBox
@onready var grid_opacity_slider: HSlider = $GridSettingsPopup/GridSettingsContainer/GridOpacityContainer/GridOpacitySlider
@onready var grid_color_picker: ColorPickerButton = $GridSettingsPopup/GridSettingsContainer/GridColorContainer/GridColorPicker
@onready var snap_to_grid_checkbox: CheckBox = $GridSettingsPopup/GridSettingsContainer/SnapToGridContainer/SnapToGridCheckBox

# Surface selection tolerance controls
@onready var corner_tolerance_spinbox: SpinBox = $GridSettingsPopup/GridSettingsContainer/CornerToleranceContainer/CornerToleranceSpinBox
@onready var edge_tolerance_spinbox: SpinBox = $GridSettingsPopup/GridSettingsContainer/EdgeToleranceContainer/EdgeToleranceSpinBox
@onready var handle_size_spinbox: SpinBox = $GridSettingsPopup/GridSettingsContainer/HandleSizeContainer/HandleSizeSpinBox

# Transformation handle references
@onready var transform_handles_enabled_checkbox: CheckBox = $GridSettingsPopup/GridSettingsContainer/TransformHandlesEnabledContainer/TransformHandlesEnabledCheckBox
@onready var transform_handle_size_spinbox: SpinBox = $GridSettingsPopup/GridSettingsContainer/TransformHandleSizeContainer/TransformHandleSizeSpinBox
@onready var transform_handle_offset_spinbox: SpinBox = $GridSettingsPopup/GridSettingsContainer/TransformHandleOffsetContainer/TransformHandleOffsetSpinBox

# Output controls
@onready var display_selector: OptionButton = $HBoxContainer/DisplaySelector
@onready var output_toggle: Button = $HBoxContainer/OutputToggle
@onready var fullscreen_button: Button = $HBoxContainer/FullscreenButton

# Signals
signal file_new_requested
signal file_open_requested
signal file_save_requested
signal file_save_as_requested
signal play_all_requested
signal stop_all_requested

# View signals
signal view_mode_changed(is_grid_view: bool)
signal grid_settings_changed(size: int, opacity: float, color: Color, snap_to_grid: bool)
signal surface_selection_settings_changed(corner_tolerance: float, edge_tolerance: float, handle_size: float)
signal surface_transform_settings_changed(transform_handle_size: float, transform_handle_offset: float, transform_handles_enabled: bool)

# Output signals
signal output_toggle_requested
signal display_changed(display_index: int)
signal fullscreen_requested

# Help dialog
const HelpDialogScene = preload("res://scenes/dialogs/HelpDialog.tscn")
var help_dialog: AcceptDialog

func _ready() -> void:
	_apply_brand_styling()
	_setup_file_menu()
	_connect_button_signals()
	_setup_view_controls()
	_setup_output_controls()
	_setup_help_dialog()
	_load_settings()

func _apply_brand_styling() -> void:
	"""Apply brand constants to UI elements"""
	# Set toolbar height using brand constants
	custom_minimum_size.y = Brand.BUTTON_HEIGHT_NORMAL + Brand.SPACING_SMALL
	
	# Apply brand styling to buttons
	if play_button:
		BrandApplier.apply_button_style(play_button, "primary")
	if stop_button:
		BrandApplier.apply_button_style(stop_button)
	if help_button:
		BrandApplier.apply_button_style(help_button)
	if view_toggle:
		BrandApplier.apply_button_style(view_toggle)
	if grid_settings_button:
		BrandApplier.apply_button_style(grid_settings_button)
	if output_toggle:
		BrandApplier.apply_button_style(output_toggle)
	if fullscreen_button:
		BrandApplier.apply_button_style(fullscreen_button)
	
	# Apply brand colors to color picker default
	if grid_color_picker:
		grid_color_picker.color = Colors.GRID_LINES

func _setup_file_menu() -> void:
	"""Configure the file menu dropdown"""
	if file_menu_button:
		var popup = file_menu_button.get_popup()
		popup.clear()
		popup.add_item("New Project", 0)
		popup.add_separator()
		popup.add_item("Open Project...", 1)
		popup.add_item("Save Project", 2)
		popup.add_item("Save Project As...", 3)
		popup.add_separator()
		popup.add_item("Export...", 4)
		popup.add_separator()
		popup.add_item("Exit", 5)
		
		popup.id_pressed.connect(_on_file_menu_item_selected)

func _connect_button_signals() -> void:
	"""Connect button signals to handlers"""
	if play_button:
		play_button.pressed.connect(_on_play_button_pressed)
	
	if stop_button:
		stop_button.pressed.connect(_on_stop_button_pressed)
	
	if help_button:
		help_button.pressed.connect(_on_help_button_pressed)

func _setup_view_controls() -> void:
	"""Setup view toggle button and grid settings"""
	if view_toggle:
		view_toggle.pressed.connect(_on_view_toggle_pressed)
		_update_view_button_text()
	
	if grid_settings_button:
		grid_settings_button.pressed.connect(_on_grid_settings_button_pressed)
	
	_setup_grid_settings_popup()

func _on_file_menu_item_selected(id: int) -> void:
	"""Handle file menu item selection"""
	match id:
		0:  # New Project
			file_new_requested.emit()
		1:  # Open Project
			file_open_requested.emit()
		2:  # Save Project  
			file_save_requested.emit()
		3:  # Save Project As
			file_save_as_requested.emit()
		4:  # Export
			# TODO: Implement export functionality
			pass
		5:  # Exit
			get_tree().quit()



func _on_play_button_pressed() -> void:
	"""Handle play button press - affects all surfaces"""
	play_all_requested.emit()
	play_button.disabled = true
	stop_button.disabled = false

func _on_stop_button_pressed() -> void:
	"""Handle stop button press - affects all surfaces"""
	stop_all_requested.emit()
	play_button.disabled = false
	stop_button.disabled = true

func _setup_output_controls() -> void:
	"""Setup output display controls"""
	if output_toggle:
		output_toggle.pressed.connect(_on_output_toggle_pressed)
	
	if fullscreen_button:
		fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	
	if display_selector:
		display_selector.item_selected.connect(_on_display_selected)
		_populate_display_selector()

func _populate_display_selector() -> void:
	"""Populate the display selector with available displays"""
	if not display_selector:
		return
	
	display_selector.clear()
	
	var screen_count = DisplayServer.get_screen_count()
	for i in range(screen_count):
		var screen_size = DisplayServer.screen_get_size(i)
		var display_name = "Display " + str(i + 1)
		if i == 0:
			display_name += " (Primary)"
		display_name += " - " + str(screen_size.x) + "x" + str(screen_size.y)
		
		display_selector.add_item(display_name)
	
	# Select secondary display by default if available
	if screen_count > 1:
		display_selector.selected = 1
	
	print("TopBar: Found ", screen_count, " displays")

func set_output_active(active: bool) -> void:
	"""Update UI to reflect output window state"""
	if output_toggle:
		output_toggle.text = "Hide Output" if active else "Show Output"
		output_toggle.button_pressed = active
	
	if fullscreen_button:
		fullscreen_button.disabled = not active

func _on_output_toggle_pressed() -> void:
	"""Handle output toggle button press"""
	output_toggle_requested.emit()
	print("TopBar: Output toggle requested")

func _on_display_selected(index: int) -> void:
	"""Handle display selection change"""
	display_changed.emit(index)
	print("TopBar: Display changed to ", index)

func _on_fullscreen_pressed() -> void:
	"""Handle fullscreen button press"""
	fullscreen_requested.emit()

func _on_view_toggle_pressed() -> void:
	"""Handle view toggle button press"""
	is_grid_view = not is_grid_view
	_update_view_button_text()
	view_mode_changed.emit(is_grid_view)
	_save_grid_settings()

func _update_view_button_text() -> void:
	"""Update view toggle button text based on current mode"""
	if view_toggle:
		view_toggle.text = "Grid" if is_grid_view else "Black"

func _setup_grid_settings_popup() -> void:
	"""Setup grid settings popup controls"""
	if grid_size_spinbox:
		grid_size_spinbox.value = grid_size
		grid_size_spinbox.value_changed.connect(_on_grid_size_changed)
	
	if grid_opacity_slider:
		grid_opacity_slider.value = grid_opacity
		grid_opacity_slider.value_changed.connect(_on_grid_opacity_changed)
	
	if grid_color_picker:
		grid_color_picker.color = grid_color
		grid_color_picker.color_changed.connect(_on_grid_color_changed)
	
	if snap_to_grid_checkbox:
		snap_to_grid_checkbox.button_pressed = snap_to_grid
		snap_to_grid_checkbox.toggled.connect(_on_snap_to_grid_toggled)
	
	# Setup surface selection tolerance controls
	if corner_tolerance_spinbox:
		corner_tolerance_spinbox.value = corner_tolerance
		corner_tolerance_spinbox.value_changed.connect(_on_corner_tolerance_changed)
	
	if edge_tolerance_spinbox:
		edge_tolerance_spinbox.value = edge_tolerance
		edge_tolerance_spinbox.value_changed.connect(_on_edge_tolerance_changed)
	
	if handle_size_spinbox:
		handle_size_spinbox.value = handle_size
		handle_size_spinbox.value_changed.connect(_on_handle_size_changed)
	
	# Connect transformation handle controls
	if transform_handles_enabled_checkbox:
		transform_handles_enabled_checkbox.button_pressed = true  # Default on - transformation handles enabled by default
		transform_handles_enabled_checkbox.toggled.connect(_on_transform_handles_enabled_changed)
	
	if transform_handle_size_spinbox:
		transform_handle_size_spinbox.value = 12.0  # Default value
		transform_handle_size_spinbox.value_changed.connect(_on_transform_handle_size_changed)
	
	if transform_handle_offset_spinbox:
		transform_handle_offset_spinbox.value = 25.0  # Default value
		transform_handle_offset_spinbox.value_changed.connect(_on_transform_handle_offset_changed)

func _on_grid_settings_button_pressed() -> void:
	"""Show grid settings popup"""
	if grid_settings_popup:
		grid_settings_popup.popup_centered()

func _on_grid_size_changed(value: float) -> void:
	"""Handle grid size change"""
	grid_size = int(value)
	_emit_grid_settings_changed()
	_save_grid_settings()

func _on_grid_opacity_changed(value: float) -> void:
	"""Handle grid opacity change"""
	grid_opacity = value
	# Update grid color alpha
	grid_color.a = grid_opacity
	if grid_color_picker:
		grid_color_picker.color = grid_color
	_emit_grid_settings_changed()
	_save_grid_settings()

func _on_grid_color_changed(color: Color) -> void:
	"""Handle grid color change"""
	grid_color = color
	grid_color.a = grid_opacity  # Maintain opacity setting
	_emit_grid_settings_changed()
	_save_grid_settings()

func _on_snap_to_grid_toggled(pressed: bool) -> void:
	"""Handle snap to grid toggle"""
	snap_to_grid = pressed
	_emit_grid_settings_changed()
	_save_grid_settings()

func _emit_grid_settings_changed() -> void:
	"""Emit grid settings changed signal"""
	grid_settings_changed.emit(grid_size, grid_opacity, grid_color, snap_to_grid)
	print("TopBar: Fullscreen requested")

func update_playback_state(is_playing: bool) -> void:
	"""Update button states based on playback status"""
	play_button.disabled = is_playing
	stop_button.disabled = not is_playing

func _on_corner_tolerance_changed(value: float) -> void:
	"""Handle corner tolerance change"""
	corner_tolerance = value
	_emit_surface_selection_settings_changed()
	_save_surface_settings()

func _on_edge_tolerance_changed(value: float) -> void:
	"""Handle edge tolerance change"""
	edge_tolerance = value
	_emit_surface_selection_settings_changed()
	_save_surface_settings()

func _on_handle_size_changed(value: float) -> void:
	"""Handle handle size change"""
	handle_size = value
	_emit_surface_selection_settings_changed()
	_save_surface_settings()

func _emit_surface_selection_settings_changed() -> void:
	"""Emit surface selection settings changed signal"""
	surface_selection_settings_changed.emit(corner_tolerance, edge_tolerance, handle_size)
	print("TopBar: Surface selection settings changed - Corner: ", corner_tolerance, ", Edge: ", edge_tolerance, ", Handle: ", handle_size)

func _on_transform_handles_enabled_changed(pressed: bool) -> void:
	"""Handle transformation handles enable/disable"""
	_emit_surface_transform_settings_changed()
	_save_transform_settings()

func _on_transform_handle_size_changed(value: float) -> void:
	"""Handle transformation handle size change"""
	_emit_surface_transform_settings_changed()
	_save_transform_settings()

func _on_transform_handle_offset_changed(value: float) -> void:
	"""Handle transformation handle offset change"""
	_emit_surface_transform_settings_changed()
	_save_transform_settings()

func _setup_help_dialog() -> void:
	"""Setup the help dialog"""
	if HelpDialogScene:
		help_dialog = HelpDialogScene.instantiate()
		if help_dialog:
			get_tree().current_scene.add_child.call_deferred(help_dialog)
		else:
			print("TopBarController: ERROR - Failed to instantiate help dialog")
	else:
		print("TopBarController: ERROR - HelpDialogScene is null")

func _on_help_button_pressed() -> void:
	"""Handle help button press"""
	if help_dialog:
		help_dialog.show_help()
	else:
		print("TopBarController: Help dialog not ready, attempting to create")
		_setup_help_dialog()
		# Use call_deferred to ensure dialog is ready before showing
		call_deferred("_show_help_when_ready")

func _show_help_when_ready() -> void:
	"""Show help dialog when it's ready (called via call_deferred)"""
	if help_dialog:
		help_dialog.show_help()

func _emit_surface_transform_settings_changed() -> void:
	"""Emit surface transformation settings changed signal"""
	var enabled = transform_handles_enabled_checkbox.button_pressed if transform_handles_enabled_checkbox else false
	var handle_size = transform_handle_size_spinbox.value if transform_handle_size_spinbox else 12.0
	var offset = transform_handle_offset_spinbox.value if transform_handle_offset_spinbox else 25.0
	
	surface_transform_settings_changed.emit(handle_size, offset, enabled)

# Settings persistence methods
func _load_settings() -> void:
	"""Load user settings and apply to UI controls"""
	var settings = SettingsManager.get_instance()
	
	# Load grid settings
	grid_size = settings.get_grid_size()
	grid_opacity = settings.get_grid_opacity()
	grid_color = settings.get_grid_color()
	snap_to_grid = settings.get_snap_to_grid()
	is_grid_view = settings.get_is_grid_view()
	
	# Load surface selection settings
	corner_tolerance = settings.get_corner_tolerance()
	edge_tolerance = settings.get_edge_tolerance()
	handle_size = settings.get_handle_size()
	
	# Apply to UI controls
	_apply_settings_to_controls()
	
	# Update view button text
	_update_view_button_text()

func _apply_settings_to_controls() -> void:
	"""Apply loaded settings to UI controls"""
	if grid_size_spinbox:
		grid_size_spinbox.value = grid_size
	if grid_opacity_slider:
		grid_opacity_slider.value = grid_opacity
	if grid_color_picker:
		grid_color_picker.color = grid_color
	if snap_to_grid_checkbox:
		snap_to_grid_checkbox.button_pressed = snap_to_grid
	if corner_tolerance_spinbox:
		corner_tolerance_spinbox.value = corner_tolerance
	if edge_tolerance_spinbox:
		edge_tolerance_spinbox.value = edge_tolerance
	if handle_size_spinbox:
		handle_size_spinbox.value = handle_size
	
	# Apply transformation handles settings
	var settings = SettingsManager.get_instance()
	if transform_handles_enabled_checkbox:
		transform_handles_enabled_checkbox.button_pressed = settings.get_transform_handles_enabled()
	if transform_handle_size_spinbox:
		transform_handle_size_spinbox.value = settings.get_transform_handle_size()
	if transform_handle_offset_spinbox:
		transform_handle_offset_spinbox.value = settings.get_transform_handle_offset()

func _save_grid_settings() -> void:
	"""Save current grid settings to persistence"""
	var settings = SettingsManager.get_instance()
	settings.save_all_grid_settings(grid_size, grid_opacity, grid_color, snap_to_grid)
	settings.set_is_grid_view(is_grid_view)
	settings.save_settings()

func _save_surface_settings() -> void:
	"""Save current surface selection settings to persistence"""
	var settings = SettingsManager.get_instance()
	settings.save_all_surface_settings(corner_tolerance, edge_tolerance, handle_size)

func _save_transform_settings() -> void:
	"""Save current transformation handle settings to persistence"""
	var settings = SettingsManager.get_instance()
	var enabled = transform_handles_enabled_checkbox.button_pressed if transform_handles_enabled_checkbox else true
	var size = transform_handle_size_spinbox.value if transform_handle_size_spinbox else 12.0
	var offset = transform_handle_offset_spinbox.value if transform_handle_offset_spinbox else 25.0
	settings.save_all_transform_settings(enabled, size, offset)
	print("TopBar: Surface transform settings changed - Size: ", size, ", Offset: ", offset, ", Enabled: ", enabled)