extends Node

# ProjectManager.gd  
# Handles project save/load operations

class_name ProjectManager

var current_project_path: String = ""
var project_data: Dictionary = {}

# Signals
signal project_saved(path: String)
signal project_loaded(data: Dictionary)

func _ready() -> void:
	"""Initialize ProjectManager"""
	print("ProjectManager: Initialized with validation system")

func create_new_project() -> void:
	"""Create a new empty project"""
	current_project_path = ""
	project_data = {
		"version": "0.1.0",
		"created": Time.get_datetime_string_from_system(),
		"surfaces": []
	}
	print("ProjectManager: Created new project")

func save_project(data: Dictionary) -> void:
	"""Save project data to file"""
	if current_project_path.is_empty():
		show_save_dialog(data)
	else:
		_save_to_file(current_project_path, data)

func show_save_dialog(data: Dictionary) -> void:
	"""Show save file dialog"""
	var file_dialog = FileDialogHelper.create_file_dialog(FileDialogHelper.DialogType.SAVE_PROJECT)
	
	# Connect signals
	file_dialog.file_selected.connect(_on_save_file_selected.bind(data, file_dialog))
	file_dialog.close_requested.connect(_on_file_dialog_closed.bind(file_dialog))
	
	# Show dialog
	FileDialogHelper.show_dialog(file_dialog, get_tree().current_scene)
	print("ProjectManager: Showing save dialog")

func show_save_as_dialog(data: Dictionary) -> void:
	"""Show save as file dialog (forces dialog even if project has existing path)"""
	var file_dialog = FileDialogHelper.create_file_dialog(FileDialogHelper.DialogType.SAVE_PROJECT)
	
	# Set current file name based on existing project or default
	if not current_project_path.is_empty():
		file_dialog.current_file = current_project_path.get_file()
	else:
		file_dialog.current_file = "untitled_project.lymo"
	
	# Connect signals
	file_dialog.file_selected.connect(_on_save_file_selected.bind(data, file_dialog))
	file_dialog.close_requested.connect(_on_file_dialog_closed.bind(file_dialog))
	
	# Show dialog
	FileDialogHelper.show_dialog(file_dialog, get_tree().current_scene)
	print("ProjectManager: Showing save as dialog")

func show_open_dialog() -> void:
	"""Show open file dialog"""
	var file_dialog = FileDialogHelper.create_file_dialog(FileDialogHelper.DialogType.OPEN_PROJECT)
	
	# Connect signals
	file_dialog.file_selected.connect(_on_open_file_selected.bind(file_dialog))
	file_dialog.close_requested.connect(_on_file_dialog_closed.bind(file_dialog))
	
	# Show dialog
	FileDialogHelper.show_dialog(file_dialog, get_tree().current_scene)
	print("ProjectManager: Showing open dialog")

func _save_to_file(path: String, data: Dictionary) -> void:
	"""Save data to JSON file with proper project metadata"""
	# Ensure project data has required metadata
	var complete_data = data.duplicate(true)
	
	# Add version if missing
	if not complete_data.has("version"):
		complete_data["version"] = "0.1.0"
	
	# Add created timestamp if missing
	if not complete_data.has("created"):
		complete_data["created"] = Time.get_datetime_string_from_system()
	
	# Add last modified timestamp
	complete_data["last_modified"] = Time.get_datetime_string_from_system()
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(complete_data))
		file.close()
		current_project_path = path
		project_saved.emit(path)
		print("ProjectManager: Saved project to ", path)
	else:
		print("ProjectManager: Error saving to ", path)

func _load_from_file(path: String) -> Dictionary:
	"""Load and validate data from JSON file"""
	# Check file existence first
	if not FileAccess.file_exists(path):
		print("ProjectManager: ERROR - Project file does not exist: ", path)
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ) 
	if not file:
		print("ProjectManager: ERROR - Cannot open project file: ", path)
		return {}
		
	var json_string = file.get_as_text()
	file.close()
	
	# Validate JSON parsing
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("ProjectManager: ERROR - Invalid JSON in project file: ", path)
		print("ProjectManager: JSON parse error at line: ", json.get_error_line())
		print("ProjectManager: JSON parse message: ", json.get_error_message())
		return {}
	
	var data = json.data
	
	# Validate project file structure and content
	var validation_result = _validate_project_data(data)
	if not validation_result.valid:
		print("ProjectManager: ERROR - Invalid project file format: ", path)
		print("ProjectManager: Validation errors: ", validation_result.errors)
		return {}
	
	# Apply any necessary migrations/upgrades
	data = _migrate_project_data(data)
	
	current_project_path = path
	project_loaded.emit(data)
	print("ProjectManager: Successfully loaded and validated project: ", path)
	return data

func _on_save_file_selected(path: String, data: Dictionary, dialog: FileDialog) -> void:
	"""Handle save file dialog selection"""
	_save_to_file(path, data)
	dialog.queue_free()

func _on_open_file_selected(path: String, dialog: FileDialog) -> void:
	"""Handle open file dialog selection"""
	var loaded_data = _load_from_file(path)
	if loaded_data:
		project_loaded.emit(loaded_data)
	dialog.queue_free()

func _on_file_dialog_closed(dialog: FileDialog) -> void:
	"""Handle file dialog being closed without selection"""
	dialog.queue_free()

func _validate_project_data(data) -> Dictionary:
	"""Validate project data structure and content"""
	var errors = []
	
	# Check if data is a dictionary
	if not data is Dictionary:
		errors.append("Project data must be a Dictionary, got: " + str(typeof(data)))
		return {"valid": false, "errors": errors}
	
	var project_dict = data as Dictionary
	
	# Validate version field (optional for backwards compatibility, but will be added during migration)
	if project_dict.has("version") and not project_dict.version is String:
		errors.append("Field 'version' must be a String, got: " + str(typeof(project_dict.version)))
	
	# Validate optional but important fields
	if project_dict.has("created") and not project_dict.created is String:
		errors.append("Field 'created' must be a String, got: " + str(typeof(project_dict.created)))
	
	if project_dict.has("camera_position"):
		var pos_valid = _validate_vector2_data(project_dict.camera_position, "camera_position")
		if not pos_valid.valid:
			errors.append_array(pos_valid.errors)
	
	if project_dict.has("camera_zoom"):
		if not (project_dict.camera_zoom is float or project_dict.camera_zoom is int):
			errors.append("Field 'camera_zoom' must be a number, got: " + str(typeof(project_dict.camera_zoom)))
		elif project_dict.camera_zoom <= 0:
			errors.append("Field 'camera_zoom' must be positive, got: " + str(project_dict.camera_zoom))
	
	# Validate surfaces array
	if project_dict.has("surfaces"):
		if not project_dict.surfaces is Array:
			errors.append("Field 'surfaces' must be an Array, got: " + str(typeof(project_dict.surfaces)))
		else:
			for i in range(project_dict.surfaces.size()):
				var surface_validation = _validate_surface_data(project_dict.surfaces[i], i)
				if not surface_validation.valid:
					errors.append_array(surface_validation.errors)
	
	return {"valid": errors.is_empty(), "errors": errors}

func _validate_vector2_data(data, field_name: String) -> Dictionary:
	"""Validate Vector2 data in multiple supported formats"""
	var errors = []
	
	if data is Vector2:
		# Direct Vector2 - always valid
		return {"valid": true, "errors": []}
	elif data is Dictionary:
		if not (data.has("x") and data.has("y")):
			errors.append("Vector2 dictionary '" + field_name + "' missing x or y coordinates")
		elif not ((data.x is float or data.x is int) and (data.y is float or data.y is int)):
			errors.append("Vector2 dictionary '" + field_name + "' coordinates must be numbers")
	elif data is Array:
		if data.size() < 2:
			errors.append("Vector2 array '" + field_name + "' must have at least 2 elements")
		elif not ((data[0] is float or data[0] is int) and (data[1] is float or data[1] is int)):
			errors.append("Vector2 array '" + field_name + "' elements must be numbers")
	else:
		errors.append("Field '" + field_name + "' must be Vector2, Dictionary, or Array, got: " + str(typeof(data)))
	
	return {"valid": errors.is_empty(), "errors": errors}

func _validate_surface_data(data, index: int) -> Dictionary:
	"""Validate individual surface data structure"""
	var errors = []
	var surface_prefix = "Surface[" + str(index) + "]"
	
	if not data is Dictionary:
		errors.append(surface_prefix + " must be a Dictionary, got: " + str(typeof(data)))
		return {"valid": false, "errors": errors}
	
	var surface_dict = data as Dictionary
	
	# Validate required surface fields
	if not surface_dict.has("corner_points"):
		errors.append(surface_prefix + " missing required field: corner_points")
	elif not surface_dict.corner_points is Array:
		errors.append(surface_prefix + " field 'corner_points' must be an Array")
	else:
		var corners = surface_dict.corner_points as Array
		if corners.size() != 4:
			errors.append(surface_prefix + " field 'corner_points' must have exactly 4 corners, got: " + str(corners.size()))
		else:
			for i in range(corners.size()):
				var point_validation = _validate_vector2_data(corners[i], surface_prefix + ".corner_points[" + str(i) + "]")
				if not point_validation.valid:
					errors.append_array(point_validation.errors)
	
	# Validate optional surface fields
	if surface_dict.has("surface_opacity"):
		var opacity = surface_dict.surface_opacity
		if not (opacity is float or opacity is int):
			errors.append(surface_prefix + " field 'surface_opacity' must be a number")
		elif opacity < 0.0 or opacity > 1.0:
			errors.append(surface_prefix + " field 'surface_opacity' must be between 0.0 and 1.0, got: " + str(opacity))
	
	if surface_dict.has("surface_z_index") and not (surface_dict.surface_z_index is int or surface_dict.surface_z_index is float):
		errors.append(surface_prefix + " field 'surface_z_index' must be a number")
	
	if surface_dict.has("is_locked") and not (surface_dict.is_locked is bool):
		errors.append(surface_prefix + " field 'is_locked' must be a boolean")
	
	if surface_dict.has("video_file_path") and not (surface_dict.video_file_path is String):
		errors.append(surface_prefix + " field 'video_file_path' must be a String")
	
	if surface_dict.has("has_video") and not (surface_dict.has_video is bool):
		errors.append(surface_prefix + " field 'has_video' must be a boolean")
	
	# Validate color data if present
	if surface_dict.has("surface_color"):
		var color_validation = _validate_color_data(surface_dict.surface_color, surface_prefix + ".surface_color")
		if not color_validation.valid:
			errors.append_array(color_validation.errors)
	
	return {"valid": errors.is_empty(), "errors": errors}

func _validate_color_data(data, field_name: String) -> Dictionary:
	"""Validate color data structure"""
	var errors = []
	
	if not data is Dictionary:
		errors.append("Color field '" + field_name + "' must be a Dictionary, got: " + str(typeof(data)))
		return {"valid": false, "errors": errors}
	
	var color_dict = data as Dictionary
	var required_components = ["r", "g", "b", "a"]
	
	for component in required_components:
		if not color_dict.has(component):
			errors.append("Color field '" + field_name + "' missing component: " + component)
		elif not (color_dict[component] is float or color_dict[component] is int):
			errors.append("Color field '" + field_name + "' component '" + component + "' must be a number")
		elif color_dict[component] < 0.0 or color_dict[component] > 1.0:
			errors.append("Color field '" + field_name + "' component '" + component + "' must be between 0.0 and 1.0")
	
	return {"valid": errors.is_empty(), "errors": errors}

func _migrate_project_data(data: Dictionary) -> Dictionary:
	"""Apply migrations/upgrades to project data for version compatibility"""
	var version = data.get("version", "0.0.0")
	var migrated_data = data.duplicate(true)
	
	# Ensure version field exists (for backwards compatibility)
	if not migrated_data.has("version"):
		migrated_data["version"] = "0.1.0"
		print("ProjectManager: Adding version field to legacy project")
	
	# Version-specific migrations
	if version < "0.1.0":
		print("ProjectManager: Migrating project from version ", version, " to 0.1.0")
		migrated_data["version"] = "0.1.0"
		
		# Add any 0.1.0 migration logic here
		if not migrated_data.has("created"):
			migrated_data["created"] = Time.get_datetime_string_from_system()
	
	# Ensure surfaces array exists
	if not migrated_data.has("surfaces"):
		migrated_data["surfaces"] = []
	
	# Normalize camera data format to Dictionary
	if migrated_data.has("camera_position") and migrated_data.camera_position is Array:
		var pos_array = migrated_data.camera_position as Array
		if pos_array.size() >= 2:
			migrated_data["camera_position"] = {"x": pos_array[0], "y": pos_array[1]}
	
	# Ensure all surfaces have required fields with defaults
	if migrated_data.has("surfaces"):
		for i in range(migrated_data.surfaces.size()):
			var surface = migrated_data.surfaces[i]
			
			# Ensure surface has name
			if not surface.has("name"):
				surface["name"] = "Surface " + str(i + 1)
			
			# Ensure surface has default opacity
			if not surface.has("surface_opacity"):
				surface["surface_opacity"] = 1.0
			
			# Ensure surface has default z-index and convert to int
			if not surface.has("surface_z_index"):
				surface["surface_z_index"] = i
			elif surface.surface_z_index is float:
				surface["surface_z_index"] = int(surface.surface_z_index)
			
			# Ensure surface has lock state
			if not surface.has("is_locked"):
				surface["is_locked"] = false
	
	print("ProjectManager: Migration completed for version ", version)
	return migrated_data

