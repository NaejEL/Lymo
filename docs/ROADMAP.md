# Lymo Project — ROADMAP for LLMs

This roadmap is designed for LLMs assisting with the development of Lymo, a cross-platform videomapping software using Godot and GDScript. 

**🎯 Implementation Strategy:** Follow priority levels (P0-P3) and respect dependencies. Complete each priority level before moving to the next.

---

## ✅ COMPLETED: Foundation & MVP
### Project Initialization
- [x] Create Godot project (target Windows & Linux)
- [x] Set up Git version control
- [x] Add GUIDELINES.md and ROADMAP.md
- [x] Create README.md
- [x] Establish directory structure: scenes/, scripts/, assets/, plugins/, docs/
- [x] Establish Core features we need to implement

### Core Features (MVP)
- [x] Main GUI window (beautiful, user-friendly)
- [x] Video input/output support (hybrid approach: native + FFmpeg conversion)
- [x] Video conversion progress dialog (prevents UI freeze perception)
- [x] Mapping canvas for projection surfaces
- [x] Settings panel for platform-specific options
- [x] Multi-screen/display output selection
- [x] Output resolution selection and configuration
- [x] Separate preview (editing) and output (projection) displays
- [x] Fullscreen output mode for projection
- [x] Output display calibration and positioning
- [x] Per-surface video selection (move from global to surface properties)

### Canvas Basics (Completed)
- [x] Background view toggle: Black/Grid view for empty canvas areas
- [x] Customizable grid settings (size, color, opacity, snap-to-grid)

---

## 🚀 P0: CORE SYSTEM FOUNDATION
*Complete these first - everything else depends on them*

### Critical UI/UX Fixes
- [x] Fix surface selection system - improve corner/edge detection precision
- [x] Fix surface dragging system - reduce bugs in surface movement  
- [x] Improve surface interaction feedback (hover states, selection indicators)
- [x] Add surface selection tolerance settings for easier interaction
- [ ] Ability to drag surface using keyboard arrow (with same ctrl/shift helpers than for corners)
- [ ] **Canvas Aspect Ratio Matching** - Editor canvas must reflect the aspect ratio (16:9, 4:3, etc.) of the selected output display for accurate preview
- [ ] **Editor Resolution Scaling** - Fix low editor window resolution and implement proper scaling when transitioning to fullscreen output mode

### Essential File Operations
- [ ] Add file dialogs for project save/load operations
- [ ] Implement proper project file format validation
- [x] Add keyboard shortcuts documentation (Help dialog fixed - now properly opens with comprehensive shortcuts)
- [ ] Create application icon and branding assets
- [ ] Save user settings preferences( grid settings, Surface selection, transformation handles)

### Core Surface Features (Basic Functionality) - **COMPLETED**
- [ ] Add surface transformation handles (rotation, scale) 
- [x] Surface opacity/transparency controls (working in both editor and output)
- [x] Surface locking (prevent accidental editing - blocks mouse/keyboard interaction)
- [x] Surface naming and organization
- [x] Surface layering and depth ordering (Z-index controls with back/forward buttons)
- [x] Surface deletion with confirmation dialog

---

## ⚡ P1: ESSENTIAL USER FEATURES  
*Basic professional functionality users need immediately*

### Canvas Improvements (High Priority)
- [x] Canvas background color customization (black canvas background implemented)
- [ ] Grid overlay on surfaces (optional, customizable)
- [x] Surface layering and depth ordering (bring to front/back - moved to P0, completed)
- [ ] Copy/paste surfaces with properties
- [ ] Undo/redo system for surface operations

### Basic Media Support
- [ ] Image support for surfaces (static images as textures)
- [ ] Text overlay on surfaces with font/size/color controls
- [ ] Surface color correction (brightness, contrast, saturation, hue)

### Essential Surface Operations
- [ ] Surface transformation: rotation, scale, skew, perspective
- [ ] Surface blending modes (multiply, add, overlay, etc.)
- [ ] Surface masking and clipping

---

## 🔧 P2: ADVANCED PROFESSIONAL FEATURES
*Professional videomapping capabilities for complex projects*

### Advanced Surface Geometry
- [ ] Arbitrary polygon surfaces (add/remove corners via right-click)
- [ ] Curved surface support using Bézier curves between corners
- [ ] 3D surface shapes: convex, concave, cylindrical, spherical
- [ ] Corner/edge right-click context menu for shape editing
- [ ] Surface subdivision and mesh refinement tools

### Advanced Mapping Techniques
- [ ] **Cornerpin/Keystone Correction** - 4-point perspective correction for projector positioning
- [ ] **Raster Correction** - Pixel-perfect geometric correction and calibration
- [ ] **Content-Aware Mesh Correction** - Automatic surface detection and mesh generation
- [ ] **Bezier Warp** - Smooth curved surface mapping with control points
- [ ] **Cylindrical/Spherical Mapping** - Specialized projections for curved surfaces
- [ ] **Homography Transform** - Mathematical perspective correction methods
- [ ] **Barrel/Pincushion Correction** - Lens distortion compensation

### Professional Visual Cues & Test Patterns
- [ ] **Calibration Test Patterns**: Checkerboard, color bars, white field, registration marks
- [ ] **Advanced Grid Systems**: Perspective grid, polar/radial grid, logarithmic spacing
- [ ] **Measurement Tools**: Distance rulers, angle indicators, scale references, coordinates display
- [ ] **Surface Analysis Tools**: Wireframe overlay, UV coordinate visualization, mesh geometry display
- [ ] **Alignment Aids**: Crosshair/registration marks, safety margins, overscan boundaries
- [ ] **Real-Time Feedback**: Live transformation matrices, geometry data, corner handle visualization

### Surface Interaction & Workflow
- [ ] Surface edge/corner snapping and alignment tools
- [ ] Surface linking: connect edges/corners to create complex 3D shapes
- [ ] Surface grouping and hierarchical transformations
- [ ] Surface templates and presets
- [ ] Multiple media types per surface (video + text + effects)

---

## 🎯 P3: MULTI-PROJECTOR & ENTERPRISE
*Advanced multi-display and professional workflow features*

### Multi-Projector Support
- [ ] **Multi-projector Blending** - Edge blending and feathering for seamless multi-projector setups
- [ ] **Edge Blending Zones** - Soft edge transitions for projector overlap areas
- [ ] **Multi-Projector Tools**: Blend zone indicators, overlap visualization, brightness maps
- [ ] **Hotspot Detection**: Projector intensity maps, brightness uniformity analysis
- [ ] **Automatic Calibration** - Camera-based surface detection and auto-mapping

### Multi-Canvas & Multi-Output System
- [ ] Multiple canvas support (Canvas 1, Canvas 2, etc.)
- [ ] Canvas-to-output assignment (Canvas A → Display 1, Canvas B → Display 2)
- [ ] Canvas templates and presets
- [ ] Independent canvas settings (grid, zoom, camera position)
- [ ] Canvas switching/tabbed interface
- [ ] Multiple simultaneous output windows
- [ ] Per-canvas output assignment and routing
- [ ] Output window management (create, delete, configure)
- [ ] Cross-canvas surface referencing and sharing
- [ ] Output synchronization and timing control

### Multi-Scene System
- [ ] Scene management UI (Scene 1, Scene 2, etc.)
- [ ] Per-scene media assignment (same surface shapes, different videos)
- [ ] Scene switching and transitions
- [ ] Scene presets and templates
- [ ] Cross-scene surface geometry sharing
- [ ] Scene-specific effects and properties

### Advanced 3D Visualization
- [ ] **3D Visualization**: Depth indicators, surface normal vectors, perspective helpers
- [ ] Real-time effects and transitions
- [ ] Timeline and keyframe animation support
- [ ] Performance optimization for multiple surfaces

---

## 🚀 P4: ADVANCED FEATURES & POLISH
*Optimization, advanced workflows, and professional production features*

### Live Production Features
- [ ] Live input capture (cameras, screen sharing)
- [ ] User preset management and templates
- [ ] Network synchronization for multi-machine setups
- [ ] Timeline and keyframe animation support

---

## 📋 IMPLEMENTATION GUIDELINES

### Priority Order & Dependencies
**P0 → P1 → P2 → P3 → P4**: Complete each priority level before advancing

### Key Dependencies
- **P0 Critical**: Surface interaction fixes must be completed first
- **P1 Essential**: Canvas improvements build on P0 surface system
- **P2 Professional**: Advanced mapping requires stable P1 foundation
- **P3 Multi-Projector**: Enterprise features need P2 professional tools
- **P4 Polish**: Performance and advanced features come last

### Best Practices
- Always follow GUIDELINES.md
- Break down complex tasks into TODO lists
- Explain reasoning and choices in code and documentation
- Ask for clarification if requirements are unclear
- Test each priority level thoroughly before moving to next

### Current Implementation Status
- ✅ **Foundation & MVP**: Complete
- 🔄 **P0 Core System**: Significant progress - major surface features completed
- ⏳ **P1 Essential**: Ready to start
- ⏳ **P2-P4**: Blocked until previous priorities complete

### Recent Completed Work (September 2025)
**P0 Core Surface Features - Major Progress:**
- ✅ Surface locking system (prevents interaction when locked)
- ✅ Surface opacity controls (working in both editor and output windows)
- ✅ Surface Z-index/layering system (back/forward controls functional)
- ✅ Help dialog with keyboard shortcuts documentation
- ✅ Surface deletion with confirmation dialogs
- ✅ Canvas background color fix (proper black background)
- ✅ Video conversion quality improvements (high-quality FFmpeg settings)
- ✅ Centralized color system (Colors.gd constants file)
- ✅ UI color consistency improvements (partial - needs completion)

**Technical Fixes:**
- ✅ Surface interaction blocking for locked surfaces
- ✅ Output window property synchronization
- ✅ Variable shadowing resolution across codebase
- ✅ Syntax error fixes and compilation stability

---

**LLM Note:** Use this priority-based roadmap to structure work efficiently. Focus on completing each priority level completely before advancing to maintain system stability and user value.