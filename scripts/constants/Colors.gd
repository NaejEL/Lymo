extends RefCounted

# Colors.gd
# Centralized color constants for consistent theming throughout the application
# All color magic numbers should be defined here for easy maintenance and consistency

class_name Colors

# Canvas and Grid Colors
const CANVAS_BLACK = Color(0.0, 0.0, 0.0, 1.0)  # Pure black background (0x000000)
const CANVAS_GRID_BG = Color(0.2, 0.2, 0.2, 1.0)  # Dark gray grid background
const GRID_LINES = Color(0.3, 0.3, 0.3, 0.5)  # Standard gray grid lines

# Surface Colors
const SURFACE_BORDER = Color.CYAN  # Standard cyan border
const SURFACE_SELECTED = Color.YELLOW  # Standard yellow for selection
const SURFACE_HANDLES = Color.RED  # Standard red handles
const SURFACE_HOVER = Color.LIGHT_BLUE  # Light blue for hover
const SURFACE_DRAGGING = Color.ORANGE  # Orange when dragging
const SURFACE_LOCKED = Color.RED  # Red for locked surfaces
const SURFACE_TRANSFORM_HANDLES = Color.MAGENTA  # Standard magenta for transform handles
const SURFACE_FILL = Color.WHITE  # White surface fill

# UI Text Colors
const UI_TEXT_PRIMARY = Color(0.2, 0.6, 1.0, 1.0)  # Blue text (matches top bar)
const UI_TEXT_SECONDARY = Color(0.7, 0.7, 0.7, 1.0)  # Light gray secondary text
const UI_TEXT_WARNING = Color.DARK_RED  # Dark red for warnings/delete actions
const UI_TEXT_WARNING_HOVER = Color.RED  # Red for warning hover states

# Button and UI Element Colors
const BUTTON_DELETE_TEXT = UI_TEXT_WARNING
const BUTTON_DELETE_HOVER = UI_TEXT_WARNING_HOVER
const BUTTON_NORMAL_TINT = Color.WHITE  # No tint for normal buttons

# Window and Background Colors
const WINDOW_BACKGROUND = Color.BLACK  # Black window background
const PANEL_BACKGROUND = Color(0.15, 0.15, 0.15, 1.0)  # Dark gray panel background

# Helper function to get contrasting text color for a background
static func get_contrasting_text_color(background_color: Color) -> Color:
	var luminance = 0.299 * background_color.r + 0.587 * background_color.g + 0.114 * background_color.b
	if luminance > 0.5:
		return Color.BLACK
	else:
		return Color.WHITE

# Helper function to create color variations
static func lighten_color(color: Color, amount: float = 0.2) -> Color:
	return Color(
		min(1.0, color.r + amount),
		min(1.0, color.g + amount),
		min(1.0, color.b + amount),
		color.a
	)

static func darken_color(color: Color, amount: float = 0.2) -> Color:
	return Color(
		max(0.0, color.r - amount),
		max(0.0, color.g - amount),
		max(0.0, color.b - amount),
		color.a
	)

# Theme presets for easy switching
static func get_light_theme_colors():
	return {
		"canvas_bg": Color.WHITE,
		"grid_bg": Color(0.9, 0.9, 0.9, 1.0),
		"grid_lines": Color(0.7, 0.7, 0.7, 0.5),
		"text_primary": Color(0.2, 0.2, 0.8, 1.0)
	}

static func get_dark_theme_colors():
	return {
		"canvas_bg": CANVAS_BLACK,
		"grid_bg": CANVAS_GRID_BG,
		"grid_lines": GRID_LINES,
		"text_primary": UI_TEXT_PRIMARY
	}