extends AcceptDialog

# HelpDialog.gd
# Help dialog showing keyboard shortcuts and usage information

class_name HelpDialog

@onready var shortcuts_text: RichTextLabel = $VBoxContainer/ScrollContainer/ShortcutsText

func _ready() -> void:
	"""Initialize the help dialog"""
	setup_dialog()
	load_shortcuts_content()

func setup_dialog() -> void:
	"""Configure dialog properties"""
	title = "Lymo - Keyboard Shortcuts & Help"
	popup_window = true
	initial_position = WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_KEYBOARD_FOCUS
	size = Vector2i(800, 600)
	# Note: AcceptDialog doesn't have resizable property in Godot 4.5

func load_shortcuts_content() -> void:
	"""Load and display shortcuts content"""
	if shortcuts_text:
		var shortcuts_content = """
[center][font_size=18][b]Lymo - Keyboard Shortcuts & Help[/b][/font_size][/center]

[font_size=16][b]Global Shortcuts[/b][/font_size]

[b]File Operations:[/b]
• [b]Ctrl+N[/b] - Create new project
• [b]Ctrl+O[/b] - Open existing project
• [b]Ctrl+S[/b] - Save current project
• [b]F11[/b] - Toggle fullscreen mode

[font_size=16][b]Main Canvas Shortcuts[/b][/font_size]

[b]Camera Controls:[/b]
• [b]Mouse Wheel[/b] - Zoom in/out at cursor position
• [b]Middle Mouse + Drag[/b] - Pan camera view
• [b]Ctrl+R[/b] - Reset stuck surface states (emergency reset)

[b]Surface Creation:[/b]
• [b]Double-click[/b] - Create new surface at cursor position

[b]Surface Selection:[/b]
• [b]Left Click[/b] - Select surface or corner handle
• [b]Right Click[/b] - Open surface context menu
• [b]Click empty area[/b] - Deselect all surfaces

[font_size=16][b]Surface Manipulation[/b][/font_size]

[b]Precise Movement:[/b]
• [b]Arrow Keys[/b] - Move selected corner by 1 pixel
• [b]Shift + Arrow Keys[/b] - Move selected corner by 10 pixels (large steps)
• [b]Ctrl + Arrow Keys[/b] - Move selected corner by 0.1 pixel (fine adjustment)

[font_size=16][b]Surface Context Menu[/b][/font_size]

Right-click on any surface to access:
• [b]Load Video...[/b] - Assign video file to surface
• [b]Clear Video[/b] - Remove video from surface
• [b]Play/Stop Video[/b] - Control video playback
• [b]Rename Surface...[/b] - Change surface name
• [b]🔒 Lock/Unlock Surface[/b] - Prevent/allow modification
• [b]Delete Surface[/b] - Remove surface permanently

[font_size=16][b]Settings Panel Controls[/b][/font_size]

When a surface is selected:
• [b]Name Input[/b] - Change surface name
• [b]Color Picker[/b] - Change surface fill color
• [b]Lock Checkbox[/b] - Toggle surface lock state
• [b]Opacity Slider[/b] - Adjust surface transparency (0-100%)
• [b]Layer Ordering[/b] - Control which surfaces appear in front

[font_size=16][b]Tips for Efficient Use[/b][/font_size]

• Use [b]Ctrl + Arrow Keys[/b] for pixel-perfect adjustments
• Use [b]Shift + Arrow Keys[/b] for quick major movements
• Combine with camera zoom for detailed positioning
• Save frequently with [b]Ctrl+S[/b]
• Use [b]F11[/b] for fullscreen presentation mode
"""
		shortcuts_text.text = shortcuts_content

func show_help() -> void:
	"""Show the help dialog"""
	popup_centered()