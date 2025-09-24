extends Node

# ProjectManager.gd  
# Handles project save/load operations

class_name ProjectManager

var current_project_path: String = ""
var project_data: Dictionary = {}

# Signals
signal project_saved(path: String)
signal project_loaded(data: Dictionary)

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
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.lymo", "Lymo Project Files")
	file_dialog.current_file = "untitled_project.lymo"
	
	# Connect signal
	file_dialog.file_selected.connect(_on_save_file_selected.bind(data, file_dialog))
	file_dialog.close_requested.connect(_on_file_dialog_closed.bind(file_dialog))
	
	# Add to scene and show
	get_tree().current_scene.add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))
	print("ProjectManager: Showing save dialog")

func show_save_as_dialog(data: Dictionary) -> void:
	"""Show save as file dialog (same as save but forces dialog)"""
	show_save_dialog(data)

func show_open_dialog() -> void:
	"""Show open file dialog"""
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.lymo", "Lymo Project Files")
	
	# Connect signal
	file_dialog.file_selected.connect(_on_open_file_selected.bind(file_dialog))
	file_dialog.close_requested.connect(_on_file_dialog_closed.bind(file_dialog))
	
	# Add to scene and show
	get_tree().current_scene.add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))
	print("ProjectManager: Showing open dialog")

func _save_to_file(path: String, data: Dictionary) -> void:
	"""Save data to JSON file"""
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		current_project_path = path
		project_saved.emit(path)
		print("ProjectManager: Saved project to ", path)
	else:
		print("ProjectManager: Error saving to ", path)

func _load_from_file(path: String) -> Dictionary:
	"""Load data from JSON file"""
	var file = FileAccess.open(path, FileAccess.READ) 
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			current_project_path = path
			project_loaded.emit(json.data)
			return json.data
		else:
			print("ProjectManager: Error parsing JSON from ", path)
	else:
		print("ProjectManager: Error loading from ", path)
	
	return {}

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