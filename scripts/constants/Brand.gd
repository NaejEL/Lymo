extends RefCounted

# Brand.gd
# Centralized branding constants for Lymo's visual identity
# All UI dimensions, typography, and visual elements should reference these constants
# This enables easy theme changes and consistent visual design

class_name Brand

# === APPLICATION IDENTITY ===
const APP_NAME = "Lymo"
const APP_TAGLINE = "Professional Video Mapping Software"
const APP_VERSION = "0.1.0"
const APP_DESCRIPTION = "Cross-platform videomapping software for real-time projection mapping"

# === BRAND COLORS ===
# Primary brand colors
const PRIMARY_BLUE = Color(0.29, 0.565, 0.886, 1.0)  # #4a90e2 - Main brand color
const PRIMARY_BLUE_DARK = Color(0.208, 0.478, 0.741, 1.0)  # #357abd - Darker variant
const PRIMARY_BLUE_LIGHT = Color(0.4, 0.65, 0.95, 1.0)  # Lighter variant

# UI accent colors
const ACCENT_ORANGE = Color(1.0, 0.5, 0.0, 1.0)  # #ff8000 - Warning/highlight
const ACCENT_GREEN = Color(0.2, 0.8, 0.2, 1.0)  # Success/confirm
const ACCENT_RED = Color(0.9, 0.2, 0.2, 1.0)  # Error/danger

# Background colors (dark theme)
const BG_MAIN = Color(0.15, 0.15, 0.15, 1.0)  # Main window background
const BG_PANEL = Color(0.18, 0.18, 0.18, 1.0)  # Panel backgrounds
const BG_TOOLBAR = Color(0.12, 0.12, 0.12, 1.0)  # Toolbar background
const BG_INPUT = Color(0.22, 0.22, 0.22, 1.0)  # Input field backgrounds

# Text colors
const TEXT_PRIMARY = Color(0.95, 0.95, 0.95, 1.0)  # Main text
const TEXT_SECONDARY = Color(0.7, 0.7, 0.7, 1.0)  # Secondary text
const TEXT_MUTED = Color(0.5, 0.5, 0.5, 1.0)  # Disabled/muted text
const TEXT_ON_PRIMARY = Color.WHITE  # Text on primary blue

# Border and outline colors
const BORDER_DEFAULT = Color(0.3, 0.3, 0.3, 1.0)  # Default borders
const BORDER_FOCUS = PRIMARY_BLUE  # Focused element borders
const BORDER_ERROR = ACCENT_RED  # Error state borders

# === TYPOGRAPHY ===
# Font sizes (in pixels)
const FONT_SIZE_LARGE = 16  # Headings, important labels
const FONT_SIZE_NORMAL = 14  # Standard UI text
const FONT_SIZE_SMALL = 12  # Secondary text, captions
const FONT_SIZE_TINY = 10  # Fine print, status text

# Font weights
const FONT_WEIGHT_BOLD = "Bold"
const FONT_WEIGHT_NORMAL = "Regular"
const FONT_WEIGHT_LIGHT = "Light"

# === SPACING & LAYOUT ===
# Standard spacing units (multiples of 4px for consistency)
const SPACING_TINY = 4
const SPACING_SMALL = 8
const SPACING_NORMAL = 12
const SPACING_MEDIUM = 16
const SPACING_LARGE = 24
const SPACING_EXTRA_LARGE = 32

# Padding standards
const PADDING_BUTTON = Vector2(16, 8)  # Button internal padding
const PADDING_PANEL = Vector2(12, 12)  # Panel content padding
const PADDING_DIALOG = Vector2(20, 16)  # Dialog padding

# Margins
const MARGIN_CONTROL_VERTICAL = 6  # Space between UI controls
const MARGIN_SECTION = 16  # Space between UI sections
const MARGIN_WINDOW = 8  # Window edge margins

# === UI COMPONENT SIZES ===
# Button dimensions
const BUTTON_HEIGHT_NORMAL = 32
const BUTTON_HEIGHT_SMALL = 24
const BUTTON_HEIGHT_LARGE = 40
const BUTTON_MIN_WIDTH = 80

# Input field dimensions
const INPUT_HEIGHT = 28
const INPUT_MIN_WIDTH = 100

# Icon sizes
const ICON_SIZE_SMALL = 16
const ICON_SIZE_NORMAL = 24
const ICON_SIZE_LARGE = 32
const ICON_SIZE_TOOLBAR = 20

# Handle and interactive element sizes
const HANDLE_SIZE_DEFAULT = 10  # Surface corner handles
const HANDLE_SIZE_LARGE = 12  # Transform handles
const HANDLE_HIT_AREA = 20  # Clickable area around handles

# === WINDOW & DIALOG SIZES ===
const DIALOG_MIN_SIZE = Vector2i(400, 300)
const DIALOG_DEFAULT_SIZE = Vector2i(600, 400)
const DIALOG_LARGE_SIZE = Vector2i(800, 600)

const POPUP_MIN_SIZE = Vector2i(200, 150)
const POPUP_DEFAULT_SIZE = Vector2i(300, 200)

# Main window defaults
const WINDOW_MIN_SIZE = Vector2i(1024, 768)
const WINDOW_DEFAULT_SIZE = Vector2i(1280, 720)

# Panel dimensions
const PANEL_WIDTH_SETTINGS = 300
const PANEL_WIDTH_TOOLBAR = 44

# === ANIMATION & TRANSITIONS ===
const TRANSITION_FAST = 0.15  # Quick transitions (hover, click)
const TRANSITION_NORMAL = 0.25  # Standard transitions
const TRANSITION_SLOW = 0.4  # Slow transitions (panels, dialogs)

# Easing curves
const EASE_UI = "ease_out"  # Standard UI easing
const EASE_SMOOTH = "ease_in_out"  # Smooth animations

# === VISUAL EFFECTS ===
# Border radius for rounded corners
const RADIUS_SMALL = 3
const RADIUS_NORMAL = 5
const RADIUS_LARGE = 8

# Shadow and glow effects
const SHADOW_OFFSET = Vector2(0, 2)
const SHADOW_BLUR = 4
const SHADOW_COLOR = Color(0, 0, 0, 0.3)

# === HELPER FUNCTIONS ===
static func get_button_style_normal() -> Dictionary:
	"""Get standard button style properties"""
	return {
		"bg_color": BG_INPUT,
		"border_color": BORDER_DEFAULT,
		"text_color": TEXT_PRIMARY,
		"padding": PADDING_BUTTON,
		"height": BUTTON_HEIGHT_NORMAL,
		"radius": RADIUS_NORMAL
	}

static func get_button_style_primary() -> Dictionary:
	"""Get primary button style properties"""
	return {
		"bg_color": PRIMARY_BLUE,
		"border_color": PRIMARY_BLUE_DARK,
		"text_color": TEXT_ON_PRIMARY,
		"padding": PADDING_BUTTON,
		"height": BUTTON_HEIGHT_NORMAL,
		"radius": RADIUS_NORMAL
	}

static func get_panel_style() -> Dictionary:
	"""Get standard panel style properties"""
	return {
		"bg_color": BG_PANEL,
		"border_color": BORDER_DEFAULT,
		"padding": PADDING_PANEL,
		"radius": RADIUS_NORMAL
	}

static func scale_for_dpi(base_size: float, dpi_scale: float = 1.0) -> float:
	"""Scale UI elements for different DPI settings"""
	return base_size * dpi_scale

static func lighten_color(color: Color, amount: float = 0.1) -> Color:
	"""Lighten a color by the specified amount"""
	return Color(
		min(1.0, color.r + amount),
		min(1.0, color.g + amount),
		min(1.0, color.b + amount),
		color.a
	)

static func darken_color(color: Color, amount: float = 0.1) -> Color:
	"""Darken a color by the specified amount"""
	return Color(
		max(0.0, color.r - amount),
		max(0.0, color.g - amount),
		max(0.0, color.b - amount),
		color.a
	)