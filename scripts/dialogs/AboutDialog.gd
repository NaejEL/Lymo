extends AcceptDialog

# AboutDialog.gd
# About dialog showing application information and branding

class_name AboutDialog

# Explicit imports for brand system
const Brand = preload("res://scripts/constants/Brand.gd")
const BrandApplier = preload("res://scripts/utils/BrandApplier.gd")

@onready var app_icon: TextureRect = $VBoxContainer/IconContainer/AppIcon
@onready var app_name: Label = $VBoxContainer/InfoContainer/AppName
@onready var app_version: Label = $VBoxContainer/InfoContainer/AppVersion
@onready var app_description: Label = $VBoxContainer/InfoContainer/AppDescription
@onready var copyright_label: Label = $VBoxContainer/InfoContainer/CopyrightLabel

func _ready() -> void:
	"""Initialize the about dialog"""
	setup_dialog()
	apply_brand_styling()
	load_app_info()

func apply_brand_styling() -> void:
	"""Apply brand styling to dialog elements"""
	# Set dialog size using brand constants
	BrandApplier.set_dialog_size(self, "default")
	
	# Apply brand typography
	if app_name:
		BrandApplier.set_font_size(app_name, "large")
		BrandApplier.set_color(app_name, "text_primary", "font_color")
	
	if app_version:
		BrandApplier.set_font_size(app_version, "normal")
		BrandApplier.set_color(app_version, "text_secondary", "font_color")
	
	if app_description:
		BrandApplier.set_font_size(app_description, "normal")
		BrandApplier.set_color(app_description, "text_primary", "font_color")
	
	if copyright_label:
		BrandApplier.set_font_size(copyright_label, "small")
		BrandApplier.set_color(copyright_label, "text_muted", "font_color")

func setup_dialog() -> void:
	"""Configure dialog properties"""
	title = "About Lymo"
	popup_window = true
	initial_position = WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_KEYBOARD_FOCUS
	size = Vector2i(400, 300)
	unresizable = true

func load_app_info() -> void:
	"""Load and display application information"""
	if app_name:
		app_name.text = "Lymo"
	
	if app_version:
		var version = ProjectSettings.get_setting("application/config/version", "1.0.0")
		app_version.text = "Version " + str(version)
	
	if app_description:
		var description = ProjectSettings.get_setting("application/config/description", "Cross-platform videomapping application")
		app_description.text = description
	
	if copyright_label:
		copyright_label.text = "© 2025 Lymo Project\nOpen Source Video Projection Mapping Tool"
	
	# Load application icon
	if app_icon:
		var icon_path = ProjectSettings.get_setting("application/config/icon", "")
		if icon_path != "":
			var icon_resource = load(icon_path)
			if icon_resource:
				app_icon.texture = icon_resource

func show_about() -> void:
	"""Show the about dialog"""
	popup_centered()