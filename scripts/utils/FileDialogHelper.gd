extends RefCounted

# FileDialogHelper.gd
# Centralized helper for creating and configuring FileDialog instances
# Eliminates duplicate file dialog setup code across managers

class_name FileDialogHelper

# Common file dialog configurations
enum DialogType {
	SAVE_PROJECT,
	OPEN_PROJECT,
	LOAD_VIDEO
}

static func create_file_dialog(dialog_type: DialogType) -> FileDialog:
	"""Create and configure a file dialog based on type"""
	var file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	
	match dialog_type:
		DialogType.SAVE_PROJECT:
			file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			file_dialog.add_filter("*.lymo", "Lymo Project Files")
			file_dialog.current_file = "untitled_project.lymo"
			
		DialogType.OPEN_PROJECT:
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.add_filter("*.lymo", "Lymo Project Files")
			
		DialogType.LOAD_VIDEO:
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			_add_video_filters(file_dialog)
	
	return file_dialog

static func show_dialog(file_dialog: FileDialog, parent_scene: Node) -> void:
	"""Show file dialog with consistent settings"""
	parent_scene.add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))

static func _add_video_filters(file_dialog: FileDialog) -> void:
	"""Add video file format filters using VideoManager constants"""
	# Get all supported formats from VideoManager
	var all_formats = VideoManager.NATIVE_FORMATS + VideoManager.SUPPORTED_FORMATS
	var filter_parts = []
	for format in all_formats:
		filter_parts.append("*" + format)
	
	var filter_string = "Video Files (" + ", ".join(filter_parts) + ") ; " + " ".join(filter_parts)
	file_dialog.add_filter(filter_string)