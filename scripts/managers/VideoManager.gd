extends Node

# VideoManager.gd
# Handles video input/output, format conversion, and playback management
# Hybrid approach: Native VideoStreamPlayer + FFmpeg conversion for unsupported formats

class_name VideoManager

# Video playback components
var video_player: VideoStreamPlayer = null
var current_video_path: String = ""
var is_playing: bool = false
var last_texture: Texture2D = null

# Format support and conversion
const NATIVE_FORMATS = [".ogv", ".ogg"]
const SUPPORTED_FORMATS = [".mp4", ".avi", ".mov", ".mkv", ".webm", ".flv", ".wmv", ".m4v"]
var project_video_dir: String = ""
var ffmpeg_path: String = ""
var loaded_videos: Dictionary = {}  # path -> VideoStreamPlayer for multiple videos

# Progress dialog
var progress_dialog = null

# Signals
signal video_loaded(texture: Texture2D)
signal playback_started
signal playback_stopped
signal video_conversion_started(original_path: String, target_path: String)
signal video_conversion_completed(original_path: String, target_path: String)
signal video_conversion_failed(original_path: String, error: String)

func _ready() -> void:
	# Create video player node
	video_player = VideoStreamPlayer.new()
	video_player.autoplay = false
	video_player.loop = true
	video_player.expand = true
	add_child(video_player)
	
	# Initialize FFmpeg and directories
	_detect_ffmpeg()
	_setup_project_directories()
	_create_progress_dialog()
	
	print("VideoManager: VideoStreamPlayer created")
	set_process(true)

func _process(_delta: float) -> void:
	"""Update video texture if playing"""
	if is_playing and video_player and video_player.stream:
		var texture = video_player.get_video_texture()
		if texture:
			# Update every frame for smoothest playback
			# Only emit when texture is different to avoid unnecessary work
			if texture != last_texture:
				last_texture = texture
				video_loaded.emit(texture)

func load_video_source(path: String) -> void:
	"""Load a video file as the current source"""
	current_video_path = path
	print("VideoManager: Loading video source: ", path)
	
	if not FileAccess.file_exists(path):
		print("VideoManager: Error - Video file does not exist: ", path)
		return
	
	# Stop any current playback first
	if video_player.is_playing():
		video_player.stop()
		video_player.stream = null
	
	# Try to load the video stream
	var file_extension = path.get_extension().to_lower()
	print("VideoManager: File extension: ", file_extension)
	
	# Try using ResourceLoader first (might work better)
	print("VideoManager: Attempting to load video with ResourceLoader...")
	var video_stream = load(path) as VideoStream
	
	if video_stream:
		print("VideoManager: ResourceLoader succeeded")
		video_player.stream = video_stream
	else:
		print("VideoManager: ResourceLoader failed, trying manual VideoStreamTheora...")
		match file_extension:
			"ogv", "ogg":
				video_stream = VideoStreamTheora.new()
				video_stream.file = path
				video_player.stream = video_stream
			_:
				print("VideoManager: Unsupported video format: ", file_extension)
				return
	
	# Wait a frame to let the stream initialize
	await get_tree().process_frame
	
	# Check if stream is valid
	if video_player.stream:
		print("VideoManager: Video stream loaded successfully")
		# Don't emit the texture yet - wait for playback to start
		# video_loaded.emit(video_player.get_video_texture())
	else:
		print("VideoManager: Video stream failed to initialize")

func start_playback() -> void:
	"""Start video playback"""
	print("VideoManager: start_playback() called")
	
	if not video_player:
		print("VideoManager: No video player")
		return
		
	if not video_player.stream:
		print("VideoManager: No video stream loaded")
		return
	
	print("VideoManager: About to call play()...")
	
	# Make sure we're on the main thread and try a safer approach
	call_deferred("_do_play")

func _do_play() -> void:
	"""Actually perform the play operation on the main thread"""
	print("VideoManager: _do_play() called")
	
	if not video_player or not video_player.stream:
		print("VideoManager: Player or stream became null")
		return
	
	# Check if we can get basic info from the stream
	print("VideoManager: Stream info - Length: ", video_player.get_stream_length())
	
	# Try to play
	print("VideoManager: Calling play()...")
	video_player.play()
	print("VideoManager: play() returned")
	
	# Give it some time to start
	await get_tree().create_timer(0.1).timeout
	
	print("VideoManager: Checking if playing: ", video_player.is_playing())
	print("VideoManager: Current position: ", video_player.get_stream_position())
	
	if video_player.is_playing():
		print("VideoManager: Playback confirmed!")
		is_playing = true
		playback_started.emit()
		# Now emit the video texture when we know it's working
		var texture = video_player.get_video_texture()
		if texture:
			print("VideoManager: Emitting video texture")
			video_loaded.emit(texture)
		else:
			print("VideoManager: Warning - no video texture available yet")
	else:
		print("VideoManager: Still not playing, trying to troubleshoot...")
		
		# Try setting position to start
		video_player.set_stream_position(0.0)
		await get_tree().process_frame
		
		if video_player.is_playing():
			print("VideoManager: Started after position reset")
			is_playing = true
			playback_started.emit()
		else:
			print("VideoManager: Complete failure to start playback")
			# Try once more with paused = false
			video_player.paused = false
			if video_player.is_playing():
				print("VideoManager: Started after unpausing")
				is_playing = true
				playback_started.emit()

func stop_playback() -> void:
	"""Stop video playback"""
	if video_player:
		print("VideoManager: Stopping playback")
		video_player.stop()
		is_playing = false
		playback_stopped.emit()

func get_current_frame_texture() -> Texture2D:
	"""Get current frame as texture"""
	if video_player:
		return video_player.get_video_texture()
	return null

# ============================================================================
# ENHANCED VIDEO LOADING WITH FORMAT CONVERSION
# ============================================================================

func _detect_ffmpeg() -> void:
	"""Detect FFmpeg installation for format conversion"""
	print("VideoManager: Detecting FFmpeg installation...")
	
	# Check if ffmpeg is in PATH
	var output = []
	var exit_code = OS.execute("ffmpeg", ["-version"], output)
	
	if exit_code == 0:
		ffmpeg_path = "ffmpeg"  # Available in PATH
		print("VideoManager: FFmpeg detected in PATH")
		if output.size() > 0:
			print("VideoManager: FFmpeg version: ", output[0])
		return
	
	print("VideoManager: FFmpeg not in PATH (exit code: ", exit_code, "), trying specific locations...")
	
	# Try common installation paths
	var possible_paths = [
		"C:/ffmpeg/bin/ffmpeg.exe",
		"C:/Program Files/ffmpeg/bin/ffmpeg.exe", 
		"ffmpeg.exe"
	]
	
	for path in possible_paths:
		print("VideoManager: Checking: ", path)
		if FileAccess.file_exists(path):
			# Test if it actually works
			var test_output = []
			var test_exit = OS.execute(path, ["-version"], test_output)
			if test_exit == 0:
				ffmpeg_path = path
				print("VideoManager: FFmpeg found and working at: ", path)
				if test_output.size() > 0:
					print("VideoManager: FFmpeg version: ", test_output[0])
				return
			else:
				print("VideoManager: Found ", path, " but it doesn't work (exit code: ", test_exit, ")")
	
	print("VideoManager: WARNING - FFmpeg not found or not working.")
	print("VideoManager: Video conversion will not be available.")
	print("VideoManager: Only native formats (.ogv, .ogg) will be supported.")
	print("VideoManager: To enable format conversion:")
	print("  1. Install FFmpeg from https://ffmpeg.org/download.html")
	print("  2. Add FFmpeg to your system PATH")
	print("  3. Or place ffmpeg.exe in the project directory")

func _setup_project_directories() -> void:
	"""Setup project video directories"""
	project_video_dir = "user://videos/"
	
	# Create video directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(project_video_dir):
		DirAccess.open("user://").make_dir("videos")
		print("VideoManager: Created video directory: ", project_video_dir)

func _create_progress_dialog() -> void:
	"""Create the progress dialog for conversions"""
	var dialog_scene = preload("res://scenes/dialogs/VideoConversionDialog.tscn")
	progress_dialog = dialog_scene.instantiate()
	progress_dialog.conversion_cancelled.connect(_on_conversion_cancelled)
	# Add to main scene so it shows over everything
	call_deferred("_add_progress_dialog_to_scene")

func _add_progress_dialog_to_scene() -> void:
	"""Add progress dialog to main scene"""
	var main_scene = get_tree().current_scene
	if main_scene:
		main_scene.add_child(progress_dialog)
		print("VideoManager: Progress dialog created")

func load_video_file() -> void:
	"""Open file dialog to load a video file with format conversion support"""
	var file_dialog = FileDialog.new()
	
	# Configure file dialog
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	
	# Build filter string for supported formats
	var all_formats = NATIVE_FORMATS + SUPPORTED_FORMATS
	var filter_parts = []
	for format in all_formats:
		filter_parts.append("*" + format)
	
	var filter_string = "Video Files (" + ", ".join(filter_parts) + ") ; " + " ".join(filter_parts)
	file_dialog.add_filter(filter_string)
	
	# Connect signal and show
	file_dialog.file_selected.connect(_on_video_file_selected)
	get_tree().current_scene.add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_video_file_selected(path: String) -> void:
	"""Handle video file selection with format conversion"""
	print("VideoManager: Selected video file: ", path)
	
	var file_extension = "." + path.get_extension().to_lower()
	
	if file_extension in NATIVE_FORMATS:
		# Native format - load directly using existing method
		load_video_source(path)
	elif file_extension in SUPPORTED_FORMATS:
		# Needs conversion
		_convert_and_load_video(path)
	else:
		print("VideoManager: ERROR - Unsupported video format: ", file_extension)

func _convert_and_load_video(original_path: String) -> void:
	"""Convert video to native format and load (async with progress)"""
	if ffmpeg_path.is_empty():
		print("VideoManager: ERROR - Cannot convert video, FFmpeg not available")
		print("VideoManager: Please install FFmpeg to use non-native video formats")
		return
	
	# Generate target path - convert user:// to absolute path
	var filename = original_path.get_file().get_basename()
	var absolute_video_dir = ProjectSettings.globalize_path(project_video_dir)
	var target_path = absolute_video_dir + filename + "_converted.ogv"
	
	print("VideoManager: Converting video:")
	print("  Source: ", original_path)
	print("  Target: ", target_path)
	print("  FFmpeg: ", ffmpeg_path)
	
	# Ensure target directory exists
	var dir = DirAccess.open(absolute_video_dir.get_base_dir())
	if dir == null:
		DirAccess.make_dir_recursive_absolute(absolute_video_dir)
		print("VideoManager: Created target directory: ", absolute_video_dir)
	
	# Show progress dialog
	if progress_dialog:
		progress_dialog.start_conversion(original_path, target_path)
	
	video_conversion_started.emit(original_path, target_path)
	
	# Test FFmpeg first
	if progress_dialog:
		progress_dialog.update_status("Testing FFmpeg...")
	
	var test_output = []
	var test_code = OS.execute(ffmpeg_path, ["-version"], test_output)
	if test_code != 0:
		var error_msg = "FFmpeg test failed with exit code: " + str(test_code)
		print("VideoManager: ERROR - ", error_msg)
		if progress_dialog:
			progress_dialog.conversion_failed(error_msg)
		video_conversion_failed.emit(original_path, error_msg)
		return
	
	# Start async conversion
	_start_async_conversion(original_path, target_path)

func _start_async_conversion(original_path: String, target_path: String) -> void:
	"""Start asynchronous FFmpeg conversion with progress tracking"""
	if progress_dialog:
		progress_dialog.update_status("Starting conversion...")
	
	# Create conversion args for maximum quality
	var args = [
		"-i", original_path,
		"-f", "ogg",              # Force ogg container format
		"-c:v", "libtheora",      # Theora codec for .ogv
		"-c:a", "libvorbis",      # Vorbis audio codec
		"-q:v", "7",              # Maximum quality for Theora (0-10, 7-10 is high quality)
		"-b:v", "8000k",          # High video bitrate (8Mbps for excellent quality)
		"-b:a", "320k",           # High audio bitrate (320kbps for excellent audio)
		"-threads", "0",          # Use all available CPU threads for faster encoding
		"-progress", "pipe:1",    # Output progress to stdout
		"-y",                     # Overwrite output file
		target_path
	]
	
	print("VideoManager: Starting async FFmpeg conversion...")
	
	# Create process for async execution
	var pid = OS.create_process(ffmpeg_path, args)
	if pid == -1:
		var error_msg = "Failed to start FFmpeg process"
		print("VideoManager: ERROR - ", error_msg)
		if progress_dialog:
			progress_dialog.conversion_failed(error_msg)
		video_conversion_failed.emit(original_path, error_msg)
		return
	
	# Start monitoring the conversion process
	_monitor_conversion_process(pid, original_path, target_path)

func _monitor_conversion_process(pid: int, original_path: String, target_path: String) -> void:
	"""Monitor async conversion process"""
	var check_interval = 0.5  # Check every 500ms
	var total_wait_time = 0.0
	var max_wait_time = 120.0  # 2 minutes timeout
	
	while true:
		await get_tree().create_timer(check_interval).timeout
		total_wait_time += check_interval
		
		# Check if process is still running
		if not OS.is_process_running(pid):
			# Process finished
			await get_tree().process_frame  # Wait a frame for file system
			
			if FileAccess.file_exists(target_path):
				print("VideoManager: Async conversion completed successfully!")
				if progress_dialog:
					progress_dialog.conversion_completed()
				
				video_conversion_completed.emit(original_path, target_path)
				
				# Load the converted video
				var godot_path = ProjectSettings.localize_path(target_path)
				load_video_source(godot_path)
			else:
				var error_msg = "Conversion process ended but no output file found"
				print("VideoManager: ERROR - ", error_msg)
				if progress_dialog:
					progress_dialog.conversion_failed(error_msg)
				video_conversion_failed.emit(original_path, error_msg)
			
			return
		
		# Update progress (simulated for now - we could parse actual FFmpeg progress)
		var progress = min((total_wait_time / 30.0) * 100.0, 95.0)  # Estimate based on time
		if progress_dialog:
			progress_dialog.update_progress(progress, "Converting... " + str(int(total_wait_time)) + "s elapsed")
		
		# Timeout check
		if total_wait_time >= max_wait_time:
			print("VideoManager: Conversion timeout - killing process")
			OS.kill(pid)
			if progress_dialog:
				progress_dialog.conversion_failed("Conversion timed out")
			video_conversion_failed.emit(original_path, "Conversion timed out after " + str(max_wait_time) + " seconds")
			return

func _on_conversion_cancelled() -> void:
	"""Handle user cancelling conversion"""
	print("VideoManager: User cancelled conversion")
	# TODO: Kill the FFmpeg process if running

func load_video_for_surface(file_path: String, target_surface) -> void:
	"""Load video specifically for a target surface"""
	print("VideoManager: Loading video for surface: ", file_path)
	
	var file_extension = "." + file_path.get_extension().to_lower()
	
	if file_extension in NATIVE_FORMATS:
		# Native format - load directly
		_load_video_for_surface_direct(file_path, target_surface)
	elif file_extension in SUPPORTED_FORMATS:
		# Needs conversion
		_convert_and_load_video_for_surface(file_path, target_surface)
	else:
		print("VideoManager: ERROR - Unsupported video format for surface: ", file_extension)

func _load_video_for_surface_direct(file_path: String, target_surface) -> void:
	"""Load native format video directly for a surface"""
	print("VideoManager: Loading native format video for surface: ", file_path)
	
	# Create video stream based on file extension
	var file_extension = "." + file_path.get_extension().to_lower()
	var video_stream = null
	
	match file_extension:
		".ogv", ".ogg":
			video_stream = VideoStreamTheora.new()
			if video_stream:
				video_stream.file = file_path
		_:
			print("VideoManager: Unsupported native format: ", file_extension)
			return
	
	# Check if target_surface is still valid before accessing it
	if not is_instance_valid(target_surface):
		print("VideoManager: Target surface was freed before video could be loaded")
		return
		
	if video_stream and is_instance_valid(target_surface) and target_surface.video_player:
		target_surface.video_player.stream = video_stream
		await get_tree().process_frame
		
		# Double-check surface is still valid after await
		if not is_instance_valid(target_surface):
			print("VideoManager: Target surface was freed during video loading")
			return
			
		if target_surface.video_player and target_surface.video_player.stream:
			print("VideoManager: Video stream loaded for surface successfully")
			# Video is loaded but NOT started - user must control playback
			# Set up texture updates for this surface
			_setup_surface_video_updates(target_surface)
		else:
			print("VideoManager: Video stream failed to initialize for surface")

func _convert_and_load_video_for_surface(file_path: String, target_surface) -> void:
	"""Convert and load video for a specific surface"""
	print("VideoManager: Converting video for surface: ", file_path)
	
	# Check if target surface is still valid
	if not is_instance_valid(target_surface):
		print("VideoManager: Target surface was freed before conversion could start")
		return
	
	# Generate target path
	var filename = file_path.get_file().get_basename()
	var absolute_video_dir = ProjectSettings.globalize_path(project_video_dir)
	var target_path = absolute_video_dir + filename + "_surface_" + str(target_surface.get_instance_id()) + "_converted.ogv"
	
	# Store surface reference for after conversion
	var conversion_data = {
		"target_surface": target_surface,
		"original_path": file_path,
		"target_path": target_path
	}
	
	# Show progress dialog
	if progress_dialog:
		progress_dialog.start_conversion(file_path, target_path)
	
	# Start async conversion (modified to handle surface-specific loading)
	_start_async_surface_conversion(conversion_data)

func _start_async_surface_conversion(conversion_data: Dictionary) -> void:
	"""Start asynchronous FFmpeg conversion for a surface"""
	var original_path = conversion_data.original_path
	var target_path = conversion_data.target_path
	var target_surface = conversion_data.target_surface
	
	if progress_dialog:
		progress_dialog.update_status("Starting conversion for " + target_surface.surface_name + "...")
	
	# Create conversion args for maximum quality (same as main conversion)
	var args = [
		"-i", original_path,
		"-f", "ogg",              # Force ogg container format
		"-c:v", "libtheora",      # Theora codec for .ogv
		"-c:a", "libvorbis",      # Vorbis audio codec
		"-q:v", "7",              # Maximum quality for Theora (0-10, 7-10 is high quality)
		"-b:v", "8000k",          # High video bitrate (8Mbps for excellent quality)
		"-b:a", "320k",           # High audio bitrate (320kbps for excellent audio)
		"-threads", "0",          # Use all available CPU threads for faster encoding
		"-progress", "pipe:1",    # Output progress to stdout
		"-y",                     # Overwrite output file
		target_path
	]
	
	print("VideoManager: Starting async FFmpeg conversion for surface...")
	
	# Create process for async execution
	var pid = OS.create_process(ffmpeg_path, args)
	if pid == -1:
		var error_msg = "Failed to start FFmpeg process for surface"
		print("VideoManager: ERROR - ", error_msg)
		if progress_dialog:
			progress_dialog.conversion_failed(error_msg)
		return
	
	# Start monitoring the conversion process for this surface
	_monitor_surface_conversion_process(pid, conversion_data)

func _monitor_surface_conversion_process(pid: int, conversion_data: Dictionary) -> void:
	"""Monitor async conversion process for a surface"""
	var check_interval = 0.5
	var total_wait_time = 0.0
	var max_wait_time = 120.0
	
	var target_path = conversion_data.target_path
	var target_surface = conversion_data.target_surface
	
	while true:
		await get_tree().create_timer(check_interval).timeout
		total_wait_time += check_interval
		
		# Check if process is still running
		if not OS.is_process_running(pid):
			# Process finished
			await get_tree().process_frame
			
			if FileAccess.file_exists(target_path):
				print("VideoManager: Surface video conversion completed successfully!")
				if progress_dialog:
					progress_dialog.conversion_completed()
				
				# Load the converted video into the specific surface
				_load_video_for_surface_direct(target_path, target_surface)
			else:
				var error_msg = "Surface conversion process ended but no output file found"
				print("VideoManager: ERROR - ", error_msg)
				if progress_dialog:
					progress_dialog.conversion_failed(error_msg)
			
			return
		
		# Update progress
		var progress = min((total_wait_time / 30.0) * 100.0, 95.0)
		if progress_dialog:
			var surface_name = target_surface.surface_name if target_surface else "Unknown"
			progress_dialog.update_progress(progress, "Converting for " + surface_name + "... " + str(int(total_wait_time)) + "s elapsed")
		
		# Timeout check
		if total_wait_time >= max_wait_time:
			print("VideoManager: Surface conversion timeout - killing process")
			OS.kill(pid)
			if progress_dialog:
				progress_dialog.conversion_failed("Surface conversion timed out")
			return

func _setup_surface_video_updates(target_surface) -> void:
	"""Setup continuous video texture updates for a specific surface"""
	if not is_instance_valid(target_surface) or not target_surface.video_player:
		return
	
	# Create a timer for this surface's video updates
	var update_timer = Timer.new()
	update_timer.wait_time = 1.0 / 60.0  # 60 FPS updates
	update_timer.autostart = true
	update_timer.timeout.connect(_update_surface_video_texture.bind(target_surface))
	add_child(update_timer)
	
	print("VideoManager: Setup video updates for surface: ", target_surface.surface_name)

func _update_surface_video_texture(target_surface) -> void:
	"""Update video texture for a specific surface"""
	if not is_instance_valid(target_surface) or not target_surface.video_player:
		return
	
	if target_surface.video_player.is_playing():
		var texture = target_surface.video_player.get_video_texture()
		if texture and texture != target_surface.video_texture:
			target_surface.set_video_texture(texture)

func is_ffmpeg_available() -> bool:
	"""Check if FFmpeg is available for conversion"""
	return not ffmpeg_path.is_empty()

func get_supported_formats() -> Array[String]:
	"""Get list of all supported video formats"""
	if is_ffmpeg_available():
		return NATIVE_FORMATS + SUPPORTED_FORMATS
	else:
		return NATIVE_FORMATS

func get_format_info() -> Dictionary:
	"""Get detailed format support information"""
	return {
		"native_formats": NATIVE_FORMATS,
		"conversion_formats": SUPPORTED_FORMATS if is_ffmpeg_available() else [],
		"ffmpeg_available": is_ffmpeg_available(),
		"ffmpeg_path": ffmpeg_path
	}

# DEBUG/TEST METHODS
func test_ffmpeg_conversion(test_file_path: String) -> void:
	"""Test FFmpeg conversion with a specific file - for debugging"""
	print("VideoManager: Testing conversion with file: ", test_file_path)
	
	if not FileAccess.file_exists(test_file_path):
		print("VideoManager: Test file doesn't exist: ", test_file_path)
		return
	
	if not is_ffmpeg_available():
		print("VideoManager: FFmpeg not available for testing")
		return
	
	_convert_and_load_video(test_file_path)

func test_simple_ffmpeg_command() -> void:
	"""Test a very simple FFmpeg command to verify it works"""
	if not is_ffmpeg_available():
		print("VideoManager: FFmpeg not available")
		return
	
	print("VideoManager: Testing simple FFmpeg command...")
	var output = []
	var exit_code = OS.execute(ffmpeg_path, ["-f", "lavfi", "-i", "testsrc=duration=1:size=320x240:rate=1", "-y", "test_output.mp4"], output, true, true)
	
	print("VideoManager: Simple test exit code: ", exit_code)
	print("VideoManager: Simple test output: ", output)