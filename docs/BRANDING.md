# Lymo Branding Guidelines

## Overview

This document outlines the visual identity and branding standards for Lymo, ensuring consistent presentation across all UI elements and materials.

## Brand Identity

### Application Information

- **Name**: Lymo
- **Version**: 0.1.0
- **Tagline**: Professional Video Mapping Software
- **Description**: Cross-platform videomapping software for real-time projection mapping

### Visual Concept

The Lymo brand represents precision, professionalism, and creative technology. The visual identity emphasizes:

- **Technical Precision**: Clean lines, geometric shapes
- **Professional Quality**: Sophisticated color palette, consistent typography
- **Video Mapping Focus**: Icon depicts 4-point perspective mapping concept

## Color Palette

### Primary Colors

- **Primary Blue**: `#4a90e2` - Main brand color for key UI elements
- **Primary Blue Dark**: `#357abd` - Darker variant for emphasis and depth
- **Primary Blue Light**: Lighter variant for highlights and hover states

### Accent Colors

- **Orange**: `#ff8000` - Warning, highlights, active states
- **Green**: Success states, confirmations
- **Red**: Error states, dangerous actions

### UI Colors (Dark Theme)

- **Main Background**: `#262626` - Primary window background
- **Panel Background**: `#2e2e2e` - Secondary panels and containers
- **Toolbar Background**: `#1f1f1f` - Top toolbar and navigation
- **Input Background**: `#383838` - Form fields and inputs

### Text Colors

- **Primary Text**: `#f2f2f2` - Main content text
- **Secondary Text**: `#b3b3b3` - Supporting information
- **Muted Text**: `#808080` - Disabled or placeholder text
- **Text on Primary**: `#ffffff` - Text on blue backgrounds

## Typography

### Font Sizes

- **Large**: 16px - Headings, important labels
- **Normal**: 14px - Standard UI text
- **Small**: 12px - Secondary text, captions
- **Tiny**: 10px - Fine print, status text

### Usage Guidelines

- Use **Large** for dialog titles, section headers
- Use **Normal** for labels, buttons, standard content
- Use **Small** for help text, secondary information
- Use **Tiny** for status bars, technical details

## Layout & Spacing

### Spacing System

All spacing uses multiples of 4px for visual consistency:

- **Tiny**: 4px - Minimal spacing
- **Small**: 8px - Compact layouts
- **Normal**: 12px - Standard spacing
- **Medium**: 16px - Section spacing
- **Large**: 24px - Major section breaks
- **Extra Large**: 32px - Page-level spacing

### Component Sizing

- **Button Height**: 32px (normal), 24px (small), 40px (large)
- **Input Height**: 28px
- **Toolbar Height**: 44px
- **Panel Minimum Width**: 300px
- **Icon Sizes**: 16px (small), 24px (normal), 32px (large)

## Application Icon

### Design Concept

The Lymo icon represents the core function of video projection mapping:

- **Background**: Circular gradient using brand colors
- **Central Element**: 4-point perspective quadrilateral (mapping surface)
- **Corner Handles**: White circles showing interactive mapping points
- **Grid Pattern**: Internal lines representing mapped video content
- **Projection Rays**: Lines emanating from projector to surface
- **Projector Symbol**: Small rectangle at top representing projection source

### Technical Specifications

- **Format**: SVG (scalable vector graphics)
- **Dimensions**: 128x128px base size
- **Colors**: Brand gradient with white accents
- **File**: `assets/icon.svg`

## Implementation

### Constants Usage

All visual elements should reference centralized constants:

```gdscript
# Colors
Brand.PRIMARY_BLUE
Brand.BG_MAIN
Brand.TEXT_PRIMARY

# Typography
Brand.FONT_SIZE_LARGE
Brand.FONT_SIZE_NORMAL

# Spacing
Brand.SPACING_NORMAL
Brand.MARGIN_SECTION

# Component Sizes
Brand.BUTTON_HEIGHT_NORMAL
Brand.DIALOG_DEFAULT_SIZE
```

### Brand Application Utility

Use `BrandApplier` class for consistent styling:

```gdscript
# Apply button styling
BrandApplier.apply_button_style(button, "primary")

# Set font sizes
BrandApplier.set_font_size(label, "large")

# Apply colors
BrandApplier.set_color(control, "primary_blue")
```

### Anti-Pattern Prevention

**Never use magic numbers in UI code:**

```gdscript
# ❌ BAD: Magic numbers
button.custom_minimum_size = Vector2(80, 32)
label.add_theme_font_size_override("font_size", 16)

# ✅ GOOD: Brand constants
button.custom_minimum_size = Vector2(Brand.BUTTON_MIN_WIDTH, Brand.BUTTON_HEIGHT_NORMAL)
BrandApplier.set_font_size(label, "large")
```

## Quality Standards

### Consistency Requirements

- All UI elements must use Brand constants
- No hardcoded colors, sizes, or spacing values
- Consistent visual hierarchy through typography
- Unified color application across all screens

### Brand Compliance Checklist

- [ ] Uses Brand constants for all dimensions
- [ ] Applies consistent color palette
- [ ] Follows typography hierarchy
- [ ] Maintains proper spacing ratios
- [ ] Uses BrandApplier utility functions
- [ ] No magic numbers in code

## Future Considerations

### Theme Variations

The current implementation supports a dark theme. Future enhancements could include:

- Light theme variants
- High contrast accessibility themes
- Custom color scheme support

### Brand Evolution

As Lymo develops, the brand may evolve. This document and the Brand constants should be updated to reflect any changes while maintaining backward compatibility where possible.

---

*This document should be consulted for all UI development to ensure consistent brand application throughout the Lymo application.*