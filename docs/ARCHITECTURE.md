# Core Features Architecture

This document outlines the MVP architecture for Lymo videomapping software.

## System Overview

Lymo follows a modular architecture with clear separation of concerns:

```
┌─────────────────────────────────────────┐
│              Main Scene                 │
│  ┌─────────────┐ ┌─────────────────────┐ │
│  │   TopBar    │ │    SettingsPanel    │ │
│  └─────────────┘ └─────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │        MappingCanvas               │ │
│  │  ┌─────────────────────────────────┐ │ │
│  │  │      Projection Surface        │ │ │
│  │  │   ┌───┐ ┌───┐ ┌───┐ ┌───┐    │ │ │
│  │  │   │ A │ │ B │ │ C │ │ D │    │ │ │
│  │  │   └───┘ └───┘ └───┘ └───┘    │ │ │
│  │  └─────────────────────────────────┐ │ │
│  └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## Core Components

### 1. Main Scene (`Main.tscn`)
- **Purpose**: Root scene containing all UI components
- **Script**: `MainController.gd`
- **Responsibilities**: 
  - Window management and layout
  - Coordinate between components
  - Handle global shortcuts and menu actions

### 2. TopBar Component
- **Purpose**: Main application toolbar
- **Features**: 
  - File operations (New, Open, Save, Export)
  - Video source selection
  - Output device selection
  - Play/Stop controls
- **Script**: `TopBarController.gd`

### 3. MappingCanvas Component  
- **Purpose**: Interactive projection surface editor
- **Features**:
  - Visual representation of projection surfaces
  - Corner point manipulation (4-point mapping)
  - Pan and zoom navigation
  - Multiple surface management
- **Script**: `MappingCanvasController.gd`
- **Child nodes**: Multiple `ProjectionSurface` instances

### 4. ProjectionSurface Component
- **Purpose**: Individual mappable surface with 4-point distortion
- **Features**:
  - Quadrilateral shape definition
  - Corner point drag handles
  - Video texture mapping
  - Real-time preview
- **Script**: `ProjectionSurface.gd`

### 5. SettingsPanel Component
- **Purpose**: Properties inspector for selected surfaces
- **Features**:
  - Surface-specific settings
  - Video source assignment
  - Transform properties
  - Effect parameters
- **Script**: `SettingsPanelController.gd`

## Data Flow

1. **Video Input** → VideoManager → ProjectionSurface
2. **User Interaction** → MappingCanvas → ProjectionSurface
3. **Settings Changes** → SettingsPanel → ProjectionSurface
4. **Output** → ProjectionSurface → Display/Export

## Video I/O Strategy

### Phase 1 (MVP): File Playback
- Use Godot's built-in `VideoStreamPlayer` 
- Support: MP4, WebM, OGV formats
- Simple but limited codec support

### Phase 2: Advanced Video I/O
Options to evaluate:
- **godot-gstreamer**: Live capture + more codecs (runtime deps: GStreamer)
- **godot-ffmpeg**: File + streaming support (compile per-platform)

## Performance Considerations

1. **Rendering**: Use `SubViewport` for each projection surface
2. **Video Memory**: Efficient texture sharing between surfaces
3. **Update Rate**: 60 FPS target with frame rate limiting
4. **Threading**: Separate video decoding from rendering thread

## File Structure

```
scenes/
├── Main.tscn                 # Root scene
├── components/
│   ├── TopBar.tscn          # Application toolbar  
│   ├── MappingCanvas.tscn   # Projection editor
│   ├── ProjectionSurface.tscn # Individual surface
│   └── SettingsPanel.tscn   # Properties panel

scripts/
├── MainController.gd         # Main scene logic
├── components/
│   ├── TopBarController.gd   # Toolbar functionality
│   ├── MappingCanvasController.gd # Canvas management
│   ├── ProjectionSurface.gd  # Surface behavior
│   └── SettingsPanelController.gd # Settings UI
└── managers/
    ├── VideoManager.gd       # Video I/O handling
    ├── ProjectManager.gd     # Save/load projects  
    └── ExportManager.gd      # Output generation
```

## Next Implementation Steps

1. Create basic Main.tscn with placeholder components
2. Implement MappingCanvas with simple 4-point surface
3. Add TopBar with basic file operations
4. Integrate video playback using VideoStreamPlayer
5. Add SettingsPanel for surface properties

Each component will be implemented as text-editable .tscn files following Godot 4 format conventions.