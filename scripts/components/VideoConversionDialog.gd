extends AcceptDialog

# VideoConversionDialog.gd
# Progress dialog for video format conversion

class_name VideoConversionDialog

# UI Components (connected to scene file)
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressContainer/ProgressBar
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var progress_label: Label = $VBoxContainer/ProgressContainer/ProgressLabel
@onready var cancel_button: Button = $VBoxContainer/ButtonContainer/CancelButton
@onready var source_label: Label = $VBoxContainer/SourceLabel
@onready var target_label: Label = $VBoxContainer/TargetLabel

# Conversion state
var conversion_active: bool = false
var current_file: String = ""
var target_file: String = ""

# Signals
signal conversion_cancelled

func _ready() -> void:
	"""Initialize the dialog"""
	# Dialog is initially hidden
	hide()
	
	# Set up close behavior
	close_requested.connect(_on_close_requested)

func start_conversion(source_path: String, target_path: String) -> void:
	"""Start showing conversion progress"""
	current_file = source_path
	target_file = target_path
	conversion_active = true
	
	var filename = source_path.get_file()
	source_label.text = "Source: " + filename
	target_label.text = "Target: " + target_path.get_file()
	status_label.text = "Initializing FFmpeg..."
	progress_label.text = "0% complete"
	progress_bar.value = 0
	
	# Show dialog
	popup_centered()
	
	print("VideoConversionDialog: Started conversion display for: ", filename)

func update_progress(progress_percent: float, details: String = "") -> void:
	"""Update conversion progress"""
	if not conversion_active:
		return
	
	progress_bar.value = progress_percent
	progress_label.text = str(int(progress_percent)) + "% complete"
	
	if details != "":
		status_label.text = details

func update_status(message: String) -> void:
	"""Update status message"""
	if not conversion_active:
		return
		
	status_label.text = message

func conversion_completed() -> void:
	"""Handle conversion completion"""
	conversion_active = false
	
	var filename = current_file.get_file()
	status_label.text = "Conversion completed: " + filename
	progress_label.text = "100% complete"
	progress_bar.value = 100
	
	# Auto-close after short delay
	await get_tree().create_timer(1.0).timeout
	hide()

func conversion_failed(error_message: String) -> void:
	"""Handle conversion failure"""
	conversion_active = false
	
	var filename = current_file.get_file()
	status_label.text = "Conversion failed: " + filename
	progress_label.text = error_message
	progress_bar.value = 0
	
	# Change cancel button to close
	cancel_button.text = "Close"

func _on_cancel_button_pressed() -> void:
	"""Handle cancel/close button"""
	if conversion_active:
		# User wants to cancel conversion
		conversion_cancelled.emit()
		conversion_active = false
		hide()
	else:
		# Just close the dialog
		hide()

func _on_close_requested() -> void:
	"""Handle window close request"""
	if conversion_active:
		conversion_cancelled.emit()
		conversion_active = false
	hide()

func parse_ffmpeg_progress(output_line: String) -> float:
	"""Parse FFmpeg output line for progress information"""
	# Look for time= information in FFmpeg output
	# Example: "time=00:00:15.92 bitrate=1053.8kbits/s"
	
	var time_regex = RegEx.new()
	time_regex.compile(r"time=(\d{2}):(\d{2}):(\d{2}\.?\d*)")
	var result = time_regex.search(output_line)
	
	if result:
		var hours = result.get_string(1).to_float()
		var minutes = result.get_string(2).to_float()  
		var seconds = result.get_string(3).to_float()
		
		var total_seconds = hours * 3600 + minutes * 60 + seconds
		
		# For our 30-second test clip, calculate percentage
		# TODO: Get actual video duration for accurate progress
		var estimated_duration = 30.0  # We're limiting to 30 seconds in conversion
		var progress = (total_seconds / estimated_duration) * 100.0
		
		return min(progress, 100.0)
	
	return -1.0  # No progress info found

func extract_conversion_details(output_line: String) -> String:
	"""Extract useful details from FFmpeg output"""
	# Look for frame rate, bitrate, speed info
	var frame_regex = RegEx.new()
	frame_regex.compile(r"frame=\s*(\d+).*fps=\s*([\d.]+).*speed=\s*([\d.]+x)")
	var result = frame_regex.search(output_line)
	
	if result:
		var frame = result.get_string(1)
		var fps = result.get_string(2)
		var speed = result.get_string(3)
		
		return "Frame " + frame + " • " + fps + " fps • " + speed + " speed"
	
	return ""