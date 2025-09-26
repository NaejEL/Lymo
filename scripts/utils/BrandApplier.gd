extends RefCounted

# BrandApplier.gd
# Utility to apply Brand constants to UI nodes
# Eliminates magic numbers in UI controllers and ensures consistent branding

class_name BrandApplier

# Import Brand constants
const Brand = preload("res://scripts/constants/Brand.gd")

# Apply brand constants to common UI nodes
static func apply_button_style(button: Button, style_type: String = "normal") -> void:
	"""Apply brand styling to a button"""
	if not button:
		return
		
	var style_props = Brand.get_button_style_normal()
	if style_type == "primary":
		style_props = Brand.get_button_style_primary()
	
	# Set minimum size
	button.custom_minimum_size.x = Brand.BUTTON_MIN_WIDTH
	button.custom_minimum_size.y = style_props.height

static func apply_panel_style(panel: Control) -> void:
	"""Apply brand styling to a panel"""
	if not panel:
		return
		
	var style_props = Brand.get_panel_style()
	# Note: Panel styling typically done via theme resources in production
	# This is for runtime adjustments

static func set_font_size(label: Label, size_type: String = "normal") -> void:
	"""Set font size using brand constants"""
	if not label:
		return
		
	var font_size = Brand.FONT_SIZE_NORMAL
	match size_type:
		"large":
			font_size = Brand.FONT_SIZE_LARGE
		"small":
			font_size = Brand.FONT_SIZE_SMALL
		"tiny":
			font_size = Brand.FONT_SIZE_TINY
	
	label.add_theme_font_size_override("font_size", font_size)

static func set_spacing(container: Container, spacing_type: String = "normal") -> void:
	"""Set container spacing using brand constants"""
	if not container:
		return
		
	var spacing = Brand.SPACING_NORMAL
	match spacing_type:
		"tiny":
			spacing = Brand.SPACING_TINY
		"small":
			spacing = Brand.SPACING_SMALL
		"medium":
			spacing = Brand.SPACING_MEDIUM
		"large":
			spacing = Brand.SPACING_LARGE
		"extra_large":
			spacing = Brand.SPACING_EXTRA_LARGE
	
	# Apply to different container types
	if container is VBoxContainer:
		(container as VBoxContainer).add_theme_constant_override("separation", spacing)
	elif container is HBoxContainer:
		(container as HBoxContainer).add_theme_constant_override("separation", spacing)
	elif container is GridContainer:
		(container as GridContainer).add_theme_constant_override("h_separation", spacing)
		(container as GridContainer).add_theme_constant_override("v_separation", spacing)

static func set_color(node: Control, color_type: String, property: String = "modulate") -> void:
	"""Set node color using brand constants"""
	if not node:
		return
		
	var color = Brand.TEXT_PRIMARY
	match color_type:
		"primary_blue":
			color = Brand.PRIMARY_BLUE
		"primary_blue_dark":
			color = Brand.PRIMARY_BLUE_DARK
		"primary_blue_light":
			color = Brand.PRIMARY_BLUE_LIGHT
		"accent_orange":
			color = Brand.ACCENT_ORANGE
		"accent_green":
			color = Brand.ACCENT_GREEN
		"accent_red":
			color = Brand.ACCENT_RED
		"bg_main":
			color = Brand.BG_MAIN
		"bg_panel":
			color = Brand.BG_PANEL
		"bg_toolbar":
			color = Brand.BG_TOOLBAR
		"bg_input":
			color = Brand.BG_INPUT
		"text_primary":
			color = Brand.TEXT_PRIMARY
		"text_secondary":
			color = Brand.TEXT_SECONDARY
		"text_muted":
			color = Brand.TEXT_MUTED
		"text_on_primary":
			color = Brand.TEXT_ON_PRIMARY
		"border_default":
			color = Brand.BORDER_DEFAULT
		"border_focus":
			color = Brand.BORDER_FOCUS
		"border_error":
			color = Brand.BORDER_ERROR
	
	# Apply color based on property type
	match property:
		"modulate":
			node.modulate = color
		"color":
			if node.has_method("set_color"):
				node.set_color(color)
		"font_color":
			if node is Label:
				(node as Label).add_theme_color_override("font_color", color)
			elif node is Button:
				(node as Button).add_theme_color_override("font_color", color)

static func set_dialog_size(dialog: AcceptDialog, size_type: String = "default") -> void:
	"""Set dialog size using brand constants"""
	if not dialog:
		return
		
	var size = Brand.DIALOG_DEFAULT_SIZE
	match size_type:
		"min":
			size = Brand.DIALOG_MIN_SIZE
		"large":
			size = Brand.DIALOG_LARGE_SIZE
	
	dialog.size = size
	dialog.min_size = Brand.DIALOG_MIN_SIZE

static func set_popup_size(popup: Popup, size_type: String = "default") -> void:
	"""Set popup size using brand constants"""
	if not popup:
		return
		
	var size = Brand.POPUP_DEFAULT_SIZE
	if size_type == "min":
		size = Brand.POPUP_MIN_SIZE
	
	popup.size = size

# Convenience functions for common UI patterns
static func setup_toolbar(toolbar: Control) -> void:
	"""Setup toolbar with brand constants"""
	if not toolbar:
		return
		
	toolbar.custom_minimum_size.y = Brand.BUTTON_HEIGHT_NORMAL + Brand.SPACING_SMALL
	set_color(toolbar, "bg_toolbar", "modulate")

static func setup_title_label(label: Label, text: String = "") -> void:
	"""Setup a title label with brand styling"""
	if not label:
		return
		
	set_font_size(label, "large")
	set_color(label, "text_primary", "font_color")
	if not text.is_empty():
		label.text = text

static func setup_input_field(input: LineEdit) -> void:
	"""Setup input field with brand constants"""
	if not input:
		return
		
	input.custom_minimum_size.y = Brand.INPUT_HEIGHT
	input.custom_minimum_size.x = Brand.INPUT_MIN_WIDTH