# PNGSequencePlayer.gd
# Plays PNG sequences with alpha support as an alternative to VideoStreamPlayer
# Provides same interface as VideoStreamPlayer but with perfect alpha channel support

class_name PNGSequencePlayer
extends Node

# Playback properties
var frame_rate: float = 30.0
var current_frame: int = 0
var is_playing: bool = false
var is_paused: bool = false
var loop: bool = true
var autoplay: bool = false

# Frame data
var frame_paths: Array[String] = []
var frame_count: int = 0
var frame_cache: Dictionary = {}  # Cache for loaded textures
var cache_size_limit: int = 30  # Maximum frames to keep in memory

# Timing
var frame_timer: Timer
var playback_start_time: float = 0.0
var pause_time: float = 0.0

# Current texture
var current_texture: Texture2D = null

# Signals (matching VideoStreamPlayer interface)
signal finished()  # Emitted when playback reaches end (if not looping)

func _ready() -> void:
	# Create frame timer for playback
	frame_timer = Timer.new()
	frame_timer.wait_time = 1.0 / frame_rate
	frame_timer.timeout.connect(_advance_frame)
	add_child(frame_timer)
	
	if autoplay and frame_count > 0:
		play()

func load_png_sequence(base_path: String, frame_pattern: String = "%04d", extension: String = ".png") -> bool:
	"""Load PNG sequence from directory"""
	print("PNGSequencePlayer: Loading PNG sequence from: ", base_path)
	
	frame_paths.clear()
	frame_cache.clear()
	
	# Find all PNG files matching the pattern
	var dir = DirAccess.open(base_path)
	if dir == null:
		print("PNGSequencePlayer: ERROR - Cannot open directory: ", base_path)
		return false
	
	# Collect frame files in order
	var frame_files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(extension) and not dir.current_is_dir():
			frame_files.append(file_name)
		file_name = dir.get_next()
	
	# Sort files to ensure correct order
	frame_files.sort()
	
	# Convert to full paths
	for file in frame_files:
		frame_paths.append(base_path + "/" + file)
	
	frame_count = frame_paths.size()
	print("PNGSequencePlayer: Loaded ", frame_count, " frames")
	
	if frame_count > 0:
		_load_frame(0)  # Load first frame
		return true
	else:
		print("PNGSequencePlayer: No frames found")
		return false

func play() -> void:
	"""Start or resume playback"""
	if frame_count == 0:
		print("PNGSequencePlayer: Cannot play - no frames loaded")
		return
	
	if is_paused:
		# Resume from pause
		is_paused = false
		playback_start_time = Time.get_unix_time_from_system() - pause_time
	else:
		# Start from beginning or current position
		playback_start_time = Time.get_unix_time_from_system()
	
	is_playing = true
	frame_timer.wait_time = 1.0 / frame_rate
	frame_timer.start()
	print("PNGSequencePlayer: Started playback at frame ", current_frame)

func stop() -> void:
	"""Stop playback and reset to beginning"""
	is_playing = false
	is_paused = false
	frame_timer.stop()
	current_frame = 0
	_load_frame(0)
	print("PNGSequencePlayer: Stopped playback")

func pause() -> void:
	"""Pause playback at current position"""
	if is_playing:
		is_paused = true
		is_playing = false
		pause_time = Time.get_unix_time_from_system() - playback_start_time
		frame_timer.stop()
		print("PNGSequencePlayer: Paused at frame ", current_frame)

func set_frame_rate(fps: float) -> void:
	"""Set playback frame rate"""
	frame_rate = fps
	if frame_timer:
		frame_timer.wait_time = 1.0 / frame_rate

func get_video_texture() -> Texture2D:
	"""Get current frame texture (VideoStreamPlayer interface compatibility)"""
	return current_texture

func get_stream_position() -> float:
	"""Get current playback position in seconds"""
	return current_frame / frame_rate

func set_stream_position(position: float) -> void:
	"""Set playback position in seconds"""
	var target_frame = int(position * frame_rate)
	target_frame = clamp(target_frame, 0, frame_count - 1)
	current_frame = target_frame
	_load_frame(current_frame)

func _advance_frame() -> void:
	"""Advance to next frame"""
	if not is_playing:
		return
	
	current_frame += 1
	
	if current_frame >= frame_count:
		if loop:
			current_frame = 0
		else:
			# End of sequence
			stop()
			finished.emit()
			return
	
	_load_frame(current_frame)

func _load_frame(frame_index: int) -> void:
	"""Load specific frame into current_texture"""
	if frame_index < 0 or frame_index >= frame_count:
		return
	
	var frame_path = frame_paths[frame_index]
	
	# Check if frame is already cached
	if frame_cache.has(frame_path):
		current_texture = frame_cache[frame_path]
		return
	
	# Load new frame
	var image = Image.new()
	var error = image.load(frame_path)
	
	if error != OK:
		print("PNGSequencePlayer: ERROR loading frame: ", frame_path, " Error code: ", error)
		return
	
	print("PNGSequencePlayer: Loaded frame ", frame_index, " - Size: ", image.get_size(), " Format: ", image.get_format())
	
	# Create texture from image (Godot 4.x compatible)
	var texture = ImageTexture.new()
	texture.set_image(image)
	current_texture = texture
	
	print("PNGSequencePlayer: Created texture: ", texture, " Size: ", texture.get_size())
	
	# Cache the texture (with memory management)
	_cache_frame(frame_path, texture)

func _cache_frame(frame_path: String, texture: Texture2D) -> void:
	"""Cache frame texture with memory management"""
	frame_cache[frame_path] = texture
	
	# Remove old frames if cache is too large
	if frame_cache.size() > cache_size_limit:
		var keys_to_remove: Array[String] = []
		var keys = frame_cache.keys()
		
		# Remove frames that are far from current position
		for key in keys:
			var frame_index = frame_paths.find(key)
			if frame_index != -1:
				var distance = abs(frame_index - current_frame)
				if distance > cache_size_limit / 2:
					keys_to_remove.append(key)
		
		# Remove oldest entries
		for key in keys_to_remove:
			frame_cache.erase(key)
			if frame_cache.size() <= cache_size_limit:
				break

func get_playback_info() -> Dictionary:
	"""Get detailed playback information"""
	return {
		"frame_count": frame_count,
		"current_frame": current_frame,
		"frame_rate": frame_rate,
		"duration": frame_count / frame_rate if frame_rate > 0 else 0.0,
		"position": get_stream_position(),
		"is_playing": is_playing,
		"is_paused": is_paused,
		"cache_size": frame_cache.size()
	}