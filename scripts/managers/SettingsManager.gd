extends RefCounted

# SettingsManager.gd
# Handles persistent storage and loading of user preferences

class_name SettingsManager

const SETTINGS_FILE_PATH = "user://settings.cfg"

# Settings categories
const GRID_SECTION = "grid"
const SURFACE_SECTION = "surface_selection"
const TRANSFORM_SECTION = "transformation_handles"
const UI_SECTION = "ui"

# Default values
const DEFAULT_SETTINGS = {
	GRID_SECTION: {
		"size": 20,
		"opacity": 0.8,
		"color": Colors.GRID_LINES,
		"snap_to_grid": false,
		"is_grid_view": true
	},
	SURFACE_SECTION: {
		"corner_tolerance": 20.0,
		"edge_tolerance": 8.0,
		"handle_size": 10.0
	},
	TRANSFORM_SECTION: {
		"handles_enabled": true,
		"handle_size": 12.0,
		"handle_offset": 20.0
	},
	UI_SECTION: {
		"window_width": 1280,
		"window_height": 720,
		"split_offset": 800
	}
}

static var _instance: SettingsManager = null
static var _config_file: ConfigFile = null

# Get singleton instance
static func get_instance() -> SettingsManager:
	if _instance == null:
		_instance = SettingsManager.new()
		_config_file = ConfigFile.new()
		_instance.load_settings()
	return _instance

# Load settings from file
func load_settings() -> void:
	var error = _config_file.load(SETTINGS_FILE_PATH)
	
	if error != OK:
		print("Settings file not found, using defaults")
		# Create settings file with defaults
		save_default_settings()
	else:
		print("Settings loaded successfully")

# Save current settings to file
func save_settings() -> void:
	var error = _config_file.save(SETTINGS_FILE_PATH)
	if error != OK:
		print("Error saving settings: ", error)
	else:
		print("Settings saved successfully")

# Save default settings
func save_default_settings() -> void:
	for section in DEFAULT_SETTINGS:
		for key in DEFAULT_SETTINGS[section]:
			_config_file.set_value(section, key, DEFAULT_SETTINGS[section][key])
	save_settings()

# Grid settings
func get_grid_size() -> int:
	return _config_file.get_value(GRID_SECTION, "size", DEFAULT_SETTINGS[GRID_SECTION]["size"])

func set_grid_size(value: int) -> void:
	_config_file.set_value(GRID_SECTION, "size", value)

func get_grid_opacity() -> float:
	return _config_file.get_value(GRID_SECTION, "opacity", DEFAULT_SETTINGS[GRID_SECTION]["opacity"])

func set_grid_opacity(value: float) -> void:
	_config_file.set_value(GRID_SECTION, "opacity", value)

func get_grid_color() -> Color:
	return _config_file.get_value(GRID_SECTION, "color", DEFAULT_SETTINGS[GRID_SECTION]["color"])

func set_grid_color(value: Color) -> void:
	_config_file.set_value(GRID_SECTION, "color", value)

func get_snap_to_grid() -> bool:
	return _config_file.get_value(GRID_SECTION, "snap_to_grid", DEFAULT_SETTINGS[GRID_SECTION]["snap_to_grid"])

func set_snap_to_grid(value: bool) -> void:
	_config_file.set_value(GRID_SECTION, "snap_to_grid", value)

func get_is_grid_view() -> bool:
	return _config_file.get_value(GRID_SECTION, "is_grid_view", DEFAULT_SETTINGS[GRID_SECTION]["is_grid_view"])

func set_is_grid_view(value: bool) -> void:
	_config_file.set_value(GRID_SECTION, "is_grid_view", value)

# Surface selection settings
func get_corner_tolerance() -> float:
	return _config_file.get_value(SURFACE_SECTION, "corner_tolerance", DEFAULT_SETTINGS[SURFACE_SECTION]["corner_tolerance"])

func set_corner_tolerance(value: float) -> void:
	_config_file.set_value(SURFACE_SECTION, "corner_tolerance", value)

func get_edge_tolerance() -> float:
	return _config_file.get_value(SURFACE_SECTION, "edge_tolerance", DEFAULT_SETTINGS[SURFACE_SECTION]["edge_tolerance"])

func set_edge_tolerance(value: float) -> void:
	_config_file.set_value(SURFACE_SECTION, "edge_tolerance", value)

func get_handle_size() -> float:
	return _config_file.get_value(SURFACE_SECTION, "handle_size", DEFAULT_SETTINGS[SURFACE_SECTION]["handle_size"])

func set_handle_size(value: float) -> void:
	_config_file.set_value(SURFACE_SECTION, "handle_size", value)

# Transformation handle settings
func get_transform_handles_enabled() -> bool:
	return _config_file.get_value(TRANSFORM_SECTION, "handles_enabled", DEFAULT_SETTINGS[TRANSFORM_SECTION]["handles_enabled"])

func set_transform_handles_enabled(value: bool) -> void:
	_config_file.set_value(TRANSFORM_SECTION, "handles_enabled", value)

func get_transform_handle_size() -> float:
	return _config_file.get_value(TRANSFORM_SECTION, "handle_size", DEFAULT_SETTINGS[TRANSFORM_SECTION]["handle_size"])

func set_transform_handle_size(value: float) -> void:
	_config_file.set_value(TRANSFORM_SECTION, "handle_size", value)

func get_transform_handle_offset() -> float:
	return _config_file.get_value(TRANSFORM_SECTION, "handle_offset", DEFAULT_SETTINGS[TRANSFORM_SECTION]["handle_offset"])

func set_transform_handle_offset(value: float) -> void:
	_config_file.set_value(TRANSFORM_SECTION, "handle_offset", value)

# UI settings
func get_window_size() -> Vector2i:
	var width = _config_file.get_value(UI_SECTION, "window_width", DEFAULT_SETTINGS[UI_SECTION]["window_width"])
	var height = _config_file.get_value(UI_SECTION, "window_height", DEFAULT_SETTINGS[UI_SECTION]["window_height"])
	return Vector2i(width, height)

func set_window_size(size: Vector2i) -> void:
	_config_file.set_value(UI_SECTION, "window_width", size.x)
	_config_file.set_value(UI_SECTION, "window_height", size.y)

func get_split_offset() -> int:
	return _config_file.get_value(UI_SECTION, "split_offset", DEFAULT_SETTINGS[UI_SECTION]["split_offset"])

func set_split_offset(value: int) -> void:
	_config_file.set_value(UI_SECTION, "split_offset", value)

# Convenience methods
func save_all_grid_settings(size: int, opacity: float, color: Color, snap: bool) -> void:
	set_grid_size(size)
	set_grid_opacity(opacity)
	set_grid_color(color)
	set_snap_to_grid(snap)
	save_settings()

func save_all_surface_settings(corner_tol: float, edge_tol: float, handle_sz: float) -> void:
	set_corner_tolerance(corner_tol)
	set_edge_tolerance(edge_tol)
	set_handle_size(handle_sz)
	save_settings()

func save_all_transform_settings(enabled: bool, size: float, offset: float) -> void:
	set_transform_handles_enabled(enabled)
	set_transform_handle_size(size)
	set_transform_handle_offset(offset)
	save_settings()