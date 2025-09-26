extends Node

# VideoManager.gd
# Handles video input/output, format conversion, and playback management
# Hybrid approach: Native VideoStreamPlayer + FFmpeg conversion for unsupported formats

class_name VideoManager

# Load required classes for PNG sequence support
const PNGSequencePlayer = preload("res://scripts/utilities/PNGSequencePlayer.gd")

# Video playback components
var video_player: VideoStreamPlayer = null
var current_video_path: String = ""
var is_playing: bool = false
var last_texture: Texture2D = null

# Format support and conversion
const NATIVE_FORMATS = [".ogv", ".ogg"]  # Only truly native formats that Godot can load directly
const SUPPORTED_FORMATS = [".mp4", ".avi", ".mov", ".mkv", ".flv", ".wmv", ".m4v", ".webm"]
const ALPHA_CAPABLE_SOURCES = [".mov", ".webm", ".mkv", ".png", ".gif"]  # Formats that can contain alpha
const ALPHA_CAPABLE_CODECS = ["prores", "vp8", "vp9", "png", "gif"]  # Codecs that support alpha
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
	
	# Try using ResourceLoader first (works for most formats in Godot 4)
	print("VideoManager: Attempting to load video with ResourceLoader...")
	var video_stream = load(path) as VideoStream
	
	if video_stream:
		print("VideoManager: ResourceLoader succeeded for ", file_extension)
		video_player.stream = video_stream
	else:
		print("VideoManager: ResourceLoader failed, trying manual creation for ", file_extension)
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
	var file_dialog = FileDialogHelper.create_file_dialog(FileDialogHelper.DialogType.LOAD_VIDEO)
	
	# Connect signal and show
	file_dialog.file_selected.connect(_on_video_file_selected)
	FileDialogHelper.show_dialog(file_dialog, get_tree().current_scene)

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
	
	# Check if source video has alpha channel
	var has_alpha = _check_video_has_alpha(original_path)
	
	# Choose conversion format based on alpha support
	var args: Array
	var final_target_path: String
	
	if has_alpha:
		# WORKAROUND: Godot VideoStreamWebm cannot handle alpha channels properly (purple/black artifacts)
		# Convert alpha videos to standard Theora/OGV format and warn user to use chroma key instead
		final_target_path = target_path
		args = _create_theora_conversion_args(original_path, final_target_path)
		print("VideoManager: ALPHA DETECTED - Using Theora/OGV workaround (Godot cannot display WebM alpha)")
		if progress_dialog:
			progress_dialog.update_status("Converting alpha video (using standard format workaround)...")
		
		# Show warning about alpha limitation
		print("VideoManager: WARNING - This video contains transparency but Lymo cannot display it properly yet.")
		print("VideoManager: SUGGESTION - Use Chroma Key effects for transparency instead of embedded alpha.")
	else:
		# Use Theora/OGV for standard videos (better compatibility)
		final_target_path = target_path
		args = _create_theora_conversion_args(original_path, final_target_path)
		print("VideoManager: No alpha detected - converting to Theora/OGV format")
		if progress_dialog:
			progress_dialog.update_status("Converting video (Theora/OGV)...")
	
	# Update target path for caller
	target_path = final_target_path
	
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

func _check_video_has_alpha(video_path: String) -> bool:
	"""Check if video file contains alpha channel using comprehensive detection"""
	if ffmpeg_path.is_empty():
		return false
	
	var file_ext = "." + video_path.get_extension().to_lower()
	
	# First check: Is it a format that can potentially have alpha?
	if not file_ext in ALPHA_CAPABLE_SOURCES:
		print("VideoManager: Format ", file_ext, " cannot contain alpha channel")
		return false
	
	# Use ffprobe to check both pixel format and codec
	var ffprobe_path = ffmpeg_path.replace("ffmpeg", "ffprobe")
	var probe_args = [
		"-v", "quiet",
		"-select_streams", "v:0",
		"-show_entries", "stream=pix_fmt,codec_name",
		"-of", "csv=p=0:s=|",
		video_path
	]
	
	var output = []
	var exit_code = OS.execute(ffprobe_path, probe_args, output)
	
	if exit_code == 0 and output.size() > 0:
		var probe_data = output[0].strip_edges().to_lower()
		var parts = probe_data.split("|")
		
		if parts.size() >= 2:
			# ffprobe output order: pix_fmt|codec_name, but sometimes it's reversed
			# Let's check both parts for both pixel format and codec
			var part1 = parts[0].strip_edges()
			var part2 = parts[1].strip_edges()
			
			print("VideoManager: ffprobe output: ", part1, " | ", part2)
			
			# Check for alpha-supporting pixel formats in both parts
			var alpha_formats = ["yuva420p", "yuva422p", "yuva444p", "yuva444p10", "rgba", "argb", "bgra", "abgr", "ya8", "ya16"]
			for format in alpha_formats:
				if part1.contains(format) or part2.contains(format):
					print("VideoManager: Alpha channel detected via pixel format: ", format)
					return true
			
			# Check for alpha-capable codecs in both parts
			for codec in ALPHA_CAPABLE_CODECS:
				if part1.contains(codec) or part2.contains(codec):
					print("VideoManager: Alpha-capable codec detected: ", codec)
					return true
	
	# Enhanced fallback: check specific format characteristics
	if file_ext == ".mov":
		print("VideoManager: MOV format detected - likely ProRes with alpha support")
		return true
	elif file_ext == ".webm":
		print("VideoManager: WebM format detected - VP8/VP9 may support alpha")
		return true
	elif file_ext in [".png", ".gif"]:
		print("VideoManager: Image format with alpha support detected: ", file_ext)
		return true
	
	return false

func _create_vp9_conversion_args(input_path: String, output_path: String) -> Array:
	"""Create FFmpeg arguments for VP9/WebM conversion with alpha support"""
	return [
		"-i", input_path,
		"-c:v", "libvpx-vp9",     # VP9 codec (supports alpha)
		"-c:a", "libopus",        # Opus audio codec (better than Vorbis)
		"-pix_fmt", "yuva420p",   # Pixel format with alpha support
		"-crf", "23",             # Constant Rate Factor (15-25 for high quality)
		"-b:v", "0",              # Let CRF control bitrate
		"-b:a", "128k",           # Good audio quality for Opus
		"-speed", "1",            # VP9 encoding speed (0=slowest/best, 4=fastest)
		"-threads", "0",          # Use all available CPU threads
		"-auto-alt-ref", "1",     # Enable automatic alternate reference frames
		"-lag-in-frames", "25",   # Look-ahead frames for better compression
		"-progress", "pipe:1",    # Output progress to stdout
		"-y",                     # Overwrite output file
		output_path
	]

func _create_theora_conversion_args(input_path: String, output_path: String) -> Array:
	"""Create FFmpeg arguments for Theora/OGV conversion (no alpha)"""
	return [
		"-i", input_path,
		"-f", "ogg",              # Force ogg container format
		"-c:v", "libtheora",      # Theora codec for .ogv
		"-c:a", "libvorbis",      # Vorbis audio codec
		"-q:v", "7",              # Maximum quality for Theora (0-10, 7-10 is high quality)
		"-b:v", "8000k",          # High video bitrate (8Mbps for excellent quality)
		"-b:a", "320k",           # High audio bitrate (320kbps for excellent audio)
		"-threads", "0",          # Use all available CPU threads for faster encoding
		"-progress", "pipe:1",    # Output progress to stdout
		"-y",                     # Overwrite output file
		output_path
	]

func _extract_png_sequence_and_load(video_path: String, target_surface) -> void:
	"""Extract video to PNG sequence with alpha preservation and load into surface"""
	if ffmpeg_path.is_empty():
		print("VideoManager: ERROR - Cannot extract PNG sequence, FFmpeg not available")
		return
	
	# Generate PNG sequence directory
	var filename = video_path.get_file().get_basename()
	var absolute_video_dir = ProjectSettings.globalize_path(project_video_dir)
	var png_sequence_dir = absolute_video_dir + filename + "_png_sequence/"
	
	# Check if PNG sequence already exists and is up-to-date
	if _is_png_sequence_cached(video_path, png_sequence_dir):
		print("VideoManager: PNG sequence already exists, loading cached version")
		_load_png_sequence_player(video_path, png_sequence_dir, target_surface)
		return
	
	print("VideoManager: Extracting PNG sequence:")
	print("  Source: ", video_path)
	print("  Target dir: ", png_sequence_dir)
	
	# Create PNG sequence directory
	var dir = DirAccess.open(absolute_video_dir.get_base_dir())
	if dir == null:
		DirAccess.make_dir_recursive_absolute(absolute_video_dir)
	DirAccess.make_dir_recursive_absolute(png_sequence_dir)
	
	# Show progress dialog
	if progress_dialog:
		progress_dialog.start_conversion(video_path, png_sequence_dir + "frame_%04d.png")
	
	# Get video info first for frame rate and codec
	var frame_rate = _get_video_frame_rate(video_path)
	var codec = _get_video_codec(video_path)
	
	# Create FFmpeg arguments for PNG extraction with alpha preservation
	var png_output_path = png_sequence_dir + "frame_%04d.png"
	var args = []
	
	# Use appropriate decoder for alpha channel support
	print("VideoManager: Detected codec: ", codec)
	if codec == "vp8":
		args.append_array(["-c:v", "libvpx"])     # VP8 with libvpx decoder
		print("VideoManager: Using libvpx decoder for VP8")
	elif codec == "vp9":
		args.append_array(["-c:v", "libvpx-vp9"])     # VP9 with proper libvpx-vp9 decoder for alpha
		print("VideoManager: Using libvpx-vp9 decoder for VP9")
	# For other codecs, use default decoder
	
	args.append_array([
		"-i", video_path,
		"-vf", "fps=" + str(frame_rate),  # Maintain original frame rate
		"-f", "image2",                   # Image sequence format
		"-pix_fmt", "rgba",              # RGBA format to preserve alpha
		"-y",                            # Overwrite existing files
		png_output_path
	])
	
	print("VideoManager: Starting PNG sequence extraction...")
	
	# Create process for async execution
	var pid = OS.create_process(ffmpeg_path, args)
	if pid == -1:
		var error_msg = "Failed to start PNG extraction process"
		print("VideoManager: ERROR - ", error_msg)
		if progress_dialog:
			progress_dialog.conversion_failed(error_msg)
		return
	
	# Monitor PNG extraction process
	_monitor_png_extraction_process(pid, video_path, png_sequence_dir, target_surface, frame_rate)

func _get_video_frame_rate(video_path: String) -> float:
	"""Get frame rate of video using ffprobe"""
	var ffprobe_path = ffmpeg_path.replace("ffmpeg", "ffprobe")
	var output = []
	var args = [
		"-v", "quiet",
		"-select_streams", "v:0",
		"-show_entries", "stream=r_frame_rate",
		"-of", "csv=p=0",
		video_path
	]
	
	var exit_code = OS.execute(ffprobe_path, args, output)
	if exit_code == 0 and output.size() > 0:
		var frame_rate_str = output[0].strip_edges()
		# Parse frame rate (e.g., "60/1" -> 60.0)
		if "/" in frame_rate_str:
			var parts = frame_rate_str.split("/")
			if parts.size() == 2:
				var numerator = parts[0].to_float()
				var denominator = parts[1].to_float()
				if denominator != 0:
					return numerator / denominator
	
	# Default to 30 FPS if detection fails
	print("VideoManager: Could not detect frame rate, defaulting to 30 FPS")
	return 30.0

func _get_video_codec(video_path: String) -> String:
	"""Get codec name of video using ffprobe"""
	var ffprobe_path = ffmpeg_path.replace("ffmpeg", "ffprobe")
	var output = []
	var args = [
		"-v", "quiet",
		"-select_streams", "v:0",
		"-show_entries", "stream=codec_name",
		"-of", "csv=p=0",
		video_path
	]
	
	var exit_code = OS.execute(ffprobe_path, args, output)
	if exit_code == 0 and output.size() > 0:
		return output[0].strip_edges()
	
	# Return empty string if detection fails
	return ""

func _is_png_sequence_cached(video_path: String, png_sequence_dir: String) -> bool:
	"""Check if PNG sequence exists and is up-to-date compared to source video"""
	var dir = DirAccess.open(png_sequence_dir)
	if dir == null:
		return false
	
	# Check if cache info file exists
	var cache_info_path = png_sequence_dir + "cache_info.json"
	var cache_file = FileAccess.open(cache_info_path, FileAccess.READ)
	if cache_file == null:
		return false
	
	# Parse cache info
	var json_string = cache_file.get_as_text()
	cache_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		return false
	
	var cache_data = json.data
	if not cache_data.has("source_path") or not cache_data.has("source_modified_time"):
		return false
	
	# Check if source video path matches
	if cache_data["source_path"] != video_path:
		return false
	
	# Check if source video has been modified since cache creation
	var current_modified_time = FileAccess.get_modified_time(video_path)
	if current_modified_time == 0:
		print("VideoManager: Cannot get modification time for source video")
		return false
	
	if current_modified_time != cache_data["source_modified_time"]:
		print("VideoManager: Source video modified, cache invalidated")
		return false
	
	# Check if at least one PNG frame exists
	var frame_files = dir.get_files()
	var has_png_files = false
	for file in frame_files:
		if file.ends_with(".png") and file.begins_with("frame_"):
			has_png_files = true
			break
	
	if not has_png_files:
		print("VideoManager: No PNG frames found in cache directory")
		return false
	
	print("VideoManager: Valid PNG sequence cache found")
	return true

func _create_cache_info(video_path: String, png_sequence_dir: String) -> void:
	"""Create cache info file to track PNG sequence validity"""
	var modified_time = FileAccess.get_modified_time(video_path)
	if modified_time == 0:
		print("VideoManager: Cannot get modification time for cache creation")
		return
	
	var cache_data = {
		"source_path": video_path,
		"source_modified_time": modified_time,
		"created_time": Time.get_unix_time_from_system(),
		"version": "1.0"
	}
	
	var cache_info_path = png_sequence_dir + "cache_info.json"
	var cache_file = FileAccess.open(cache_info_path, FileAccess.WRITE)
	if cache_file != null:
		cache_file.store_string(JSON.stringify(cache_data))
		cache_file.close()
		print("VideoManager: Cache info created: ", cache_info_path)

func _load_png_sequence_player(video_path: String, png_sequence_dir: String, target_surface) -> void:
	"""Load cached PNG sequence into surface using PNGSequencePlayer"""
	if not is_instance_valid(target_surface):
		print("VideoManager: Target surface was freed before PNG sequence could be loaded")
		return
	
	# Get frame rate from cache or detect it from video
	var frame_rate = _get_video_frame_rate(video_path)
	
	if _load_png_sequence_for_surface(png_sequence_dir, target_surface, frame_rate):
		print("VideoManager: Cached PNG sequence loaded successfully")
	else:
		print("VideoManager: Failed to load cached PNG sequence - will re-extract")
		# Remove invalid cache and re-extract
		_remove_png_cache(png_sequence_dir)
		_extract_png_sequence_and_load(video_path, target_surface)

func _remove_png_cache(png_sequence_dir: String) -> void:
	"""Remove PNG cache directory and all its contents"""
	var dir = DirAccess.open(png_sequence_dir)
	if dir != null:
		var files = dir.get_files()
		for file in files:
			dir.remove(file)
		dir.remove(png_sequence_dir.trim_suffix("/"))
		print("VideoManager: Removed invalid PNG cache: ", png_sequence_dir)

func _monitor_png_extraction_process(pid: int, video_path: String, png_dir: String, target_surface, frame_rate: float) -> void:
	"""Monitor PNG extraction process and load sequence when complete"""
	var check_interval = 0.5
	var total_wait_time = 0.0
	var max_wait_time = 180.0  # 3 minutes for PNG extraction
	
	while true:
		await get_tree().create_timer(check_interval).timeout
		total_wait_time += check_interval
		
		# Check if process is still running
		if not OS.is_process_running(pid):
			# Process finished - load PNG sequence
			await get_tree().process_frame
			
			if _load_png_sequence_for_surface(png_dir, target_surface, frame_rate):
				print("VideoManager: PNG sequence loaded successfully")
				# Create cache info to prevent re-conversion
				_create_cache_info(video_path, png_dir)
				if progress_dialog:
					progress_dialog.conversion_completed()
			else:
				print("VideoManager: Failed to load PNG sequence")
				if progress_dialog:
					progress_dialog.conversion_failed("PNG sequence loading failed")
			return
		
		# Check for timeout
		if total_wait_time >= max_wait_time:
			print("VideoManager: PNG extraction timeout - killing process")
			OS.kill(pid)
			if progress_dialog:
				progress_dialog.conversion_failed("PNG extraction timed out")
			return

func _load_png_sequence_for_surface(png_dir: String, target_surface, frame_rate: float) -> bool:
	"""Load PNG sequence into surface using PNGSequencePlayer"""
	if not is_instance_valid(target_surface):
		print("VideoManager: Target surface was freed before PNG sequence could be loaded")
		return false
	
	# Create PNGSequencePlayer if it doesn't exist
	if not target_surface.has_meta("png_sequence_player"):
		print("VideoManager: Creating new PNGSequencePlayer for surface ", target_surface.surface_name)
		var png_player = PNGSequencePlayer.new()
		png_player.set_frame_rate(frame_rate)
		png_player.loop = true
		target_surface.add_child(png_player)
		target_surface.set_meta("png_sequence_player", png_player)
		target_surface.set_meta("is_png_sequence", true)
		print("VideoManager: Created PNGSequencePlayer for surface - meta set")
	else:
		print("VideoManager: PNG sequence player already exists for surface")
	
	var png_player = target_surface.get_meta("png_sequence_player")
	print("VideoManager: Retrieved PNG player: ", png_player)
	
	# Load PNG sequence
	if png_player.load_png_sequence(png_dir):
		print("VideoManager: PNG sequence loaded successfully")
		target_surface.video_file_path = png_dir  # Store directory path
		
		# IMPORTANT: Reset alpha flag for PNG sequences (PNG alpha works perfectly with standard rendering)
		if target_surface.has_method("set_video_alpha_flag"):
			target_surface.set_video_alpha_flag(false)
			print("VideoManager: Reset alpha flag to false for PNG sequence")
		
		# Set up texture updates for PNG sequence
		_setup_png_sequence_updates(target_surface)
		return true
	else:
		print("VideoManager: Failed to load PNG sequence from: ", png_dir)
		return false

func _setup_png_sequence_updates(target_surface) -> void:
	"""Setup texture updates for PNG sequence player"""
	if not is_instance_valid(target_surface):
		return
	
	# Create update timer
	var update_timer = Timer.new()
	update_timer.wait_time = 1.0 / 60.0  # 60 FPS updates
	update_timer.autostart = true
	update_timer.timeout.connect(_update_png_sequence_texture.bind(target_surface))
	add_child(update_timer)
	
	print("VideoManager: Setup PNG sequence updates for surface: ", target_surface.surface_name)

func _update_png_sequence_texture(target_surface) -> void:
	"""Update PNG sequence texture for a specific surface"""
	if not is_instance_valid(target_surface):
		return
	
	var png_player = target_surface.get_meta("png_sequence_player", null)
	if png_player and png_player.is_playing:
		var texture = png_player.get_video_texture()
		if texture and texture != target_surface.video_texture:
			target_surface.set_video_texture(texture)

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

func _load_video_for_surface_webm_direct(file_path: String, target_surface) -> void:
	"""Try to load WebM file directly without conversion"""
	print("VideoManager: Attempting direct WebM load for surface")
	
	# Check if target_surface is still valid
	if not is_instance_valid(target_surface):
		print("VideoManager: Target surface was freed before video could be loaded")
		return
	
	# Create video player if it doesn't exist
	if not target_surface.video_player:
		target_surface.video_player = VideoStreamPlayer.new()
		target_surface.video_player.loop = true
		target_surface.video_player.autoplay = false
		target_surface.add_child(target_surface.video_player)
		print("VideoManager: Created video player for surface")
	
	# Try ResourceLoader first (best compatibility)
	var video_stream = load(file_path) as VideoStream
	if video_stream:
		print("VideoManager: WebM loaded successfully with ResourceLoader")
		target_surface.video_player.stream = video_stream
	else:
		# Try VideoStreamTheora as fallback (some WebM files might work)
		print("VideoManager: ResourceLoader failed, trying VideoStreamTheora for WebM")
		video_stream = VideoStreamTheora.new()
		video_stream.file = file_path
		target_surface.video_player.stream = video_stream
	
	# Wait for stream to initialize
	await get_tree().process_frame
	
	if target_surface.video_player.stream:
		print("VideoManager: WebM video stream loaded successfully for surface")
		# Set up video updates
		_setup_surface_video_updates(target_surface)
	else:
		print("VideoManager: Direct WebM loading failed, falling back to conversion")
		# Fallback to conversion if direct loading fails
		_convert_and_load_video_for_surface(file_path, target_surface)

func load_video_for_surface(file_path: String, target_surface) -> void:
	"""Load video specifically for a target surface"""
	print("VideoManager: Loading video for surface: ", file_path)
	
	var file_extension = "." + file_path.get_extension().to_lower()
	
	if file_extension in NATIVE_FORMATS:
		# Native format - load directly
		_load_video_for_surface_direct(file_path, target_surface)
	elif file_extension in SUPPORTED_FORMATS:
		# Special case: WebM files - check for alpha and handle accordingly
		if file_extension == ".webm":
			print("VideoManager: WebM detected - checking for alpha channel")
			var has_alpha = _check_video_has_alpha(file_path)
			
			if has_alpha:
				# NEW APPROACH: Extract alpha videos to PNG sequences for perfect alpha support
				print("VideoManager: ALPHA DETECTED in WebM - Extracting to PNG sequence")
				print("VideoManager: This will preserve perfect alpha channel support!")
				if target_surface.has_method("set_video_alpha_flag"):
					# PNG sequences use standard Godot texture rendering (no special alpha handling needed)
					target_surface.set_video_alpha_flag(false)
				_extract_png_sequence_and_load(file_path, target_surface)
				return
			else:
				# No alpha - safe to load directly
				print("VideoManager: WebM without alpha - attempting direct load")
				if target_surface.has_method("set_video_alpha_flag"):
					target_surface.set_video_alpha_flag(false)
				_load_video_for_surface_webm_direct(file_path, target_surface)
				return
		
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
	
	# Handle converted WebM files (they should load as Theora since they're converted)
	if file_extension == ".webm" and file_path.contains("_converted"):
		print("VideoManager: Loading converted WebM file as Theora stream")
		video_stream = VideoStreamTheora.new()
		if video_stream:
			video_stream.file = file_path
	else:
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
			
			# Check for alpha channel and update surface flag
			var has_alpha = _check_video_has_alpha(file_path)
			if target_surface.has_method("set_video_alpha_flag"):
				# WORKAROUND: Always set alpha flag to false to prevent rendering artifacts
				# since Godot cannot properly handle alpha video textures
				target_surface.set_video_alpha_flag(false)
				if has_alpha:
					print("VideoManager: ALPHA DETECTED but flag set to false (Godot limitation workaround)")
					print("VideoManager: WARNING - Use Chroma Key effects for transparency instead")
				else:
					print("VideoManager: Set alpha flag for surface: false")
			
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
	
	# Generate base target path (actual format will be determined by alpha detection)
	var filename = file_path.get_file().get_basename()
	var absolute_video_dir = ProjectSettings.globalize_path(project_video_dir)
	var base_target_path = absolute_video_dir + filename + "_surface_" + str(target_surface.get_instance_id()) + "_converted"
	
	# Store surface reference for after conversion
	var conversion_data = {
		"target_surface": target_surface,
		"original_path": file_path,
		"base_target_path": base_target_path,
		"target_path": base_target_path + ".ogv"  # Default to .ogv, will be updated by conversion function
	}
	
	# Show progress dialog
	if progress_dialog:
		progress_dialog.start_conversion(file_path, conversion_data.target_path)
	
	# Start async conversion (modified to handle surface-specific loading)
	_start_async_surface_conversion(conversion_data)

func _start_async_surface_conversion(conversion_data: Dictionary) -> void:
	"""Start asynchronous FFmpeg conversion for a surface with alpha support"""
	var original_path = conversion_data.original_path
	var base_target_path = conversion_data.base_target_path
	var target_surface = conversion_data.target_surface
	
	if progress_dialog:
		progress_dialog.update_status("Starting conversion for " + target_surface.surface_name + "...")
	
	# Check for alpha channel and choose appropriate conversion format
	var has_alpha = _check_video_has_alpha(original_path)
	print("VideoManager: Surface conversion - Alpha detected: ", has_alpha)
	
	# Update surface alpha flag - but set to false due to workaround
	if is_instance_valid(target_surface) and target_surface.has_method("set_video_alpha_flag"):
		# WORKAROUND: Set alpha flag to false since we're converting to standard format to avoid artifacts
		target_surface.set_video_alpha_flag(false)
	
	# Choose conversion format based on alpha support
	var args: Array
	var final_target_path: String
	
	if has_alpha:
		# WORKAROUND: Convert alpha videos to standard format to prevent purple/black artifacts
		final_target_path = base_target_path + ".ogv"
		args = _create_theora_conversion_args(original_path, final_target_path)
		print("VideoManager: Surface conversion - Using Theora/OGV workaround for alpha video (avoiding WebM artifacts)")
		if progress_dialog:
			progress_dialog.update_status("Converting " + target_surface.surface_name + " (alpha video - using standard format workaround)...")
		
		print("VideoManager: ALPHA VIDEO WARNING - Transparency removed. Use Chroma Key effects instead.")
	else:
		# Use Theora/OGV for standard videos (better compatibility)
		final_target_path = base_target_path + ".ogv"
		args = _create_theora_conversion_args(original_path, final_target_path)
		print("VideoManager: Surface conversion - using Theora/OGV for standard video")
		if progress_dialog:
			progress_dialog.update_status("Converting " + target_surface.surface_name + " (Theora/OGV)...")
	
	# Update conversion data with final path
	conversion_data.target_path = final_target_path
	
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