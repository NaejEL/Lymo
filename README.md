# Lymo

![Icon](/assets/icon.svg)

Cross-platform videomapping application built with Godot 4 and GDScript.

## Overview

Lymo is a powerful, user-friendly videomapping software designed for projection mapping applications. Built with Godot Engine, it provides a modern, cross-platform solution for mapping video content onto irregular surfaces and 3D objects.

### Key Features (Planned)
- **Cross-platform support**: Windows and Linux
- **Real-time video mapping** with multiple projection surfaces
- **Intuitive GUI** inspired by professional tools like HeavyM and Resolume  
- **Video I/O support** for live camera input and file playback
- **Multi-screen output** for complex projection setups
- **Real-time effects and transitions**
- **User preset management**
- **Text-first workflow** for version control and collaboration

## Requirements

- Godot Engine 4.3 or later
- Windows 10/11 or Linux (Ubuntu 20.04+ recommended)
- Graphics card with OpenGL 3.3 support
- For video I/O: FFmpeg libraries or GStreamer (depending on chosen plugin)

## Installation

### Development Setup

1. **Clone the repository:**
   ```powershell
   git clone https://github.com/NaejEL/Lymo.git
   cd Lymo
   ```

2. **Install Godot Engine:**
   - Download Godot 4.3+ from [godotengine.org](https://godotengine.org/download)
   - Add Godot executable to your PATH (optional)

3. **Open the project:**
   - Launch Godot Engine
   - Click "Import" and select the `project.godot` file
   - Or use command line: `godot --path . --editor`

### Building for Production

*Coming soon - export templates and build instructions will be added as the project develops.*

## Project Structure

```
Lymo/
├── docs/           # Documentation and guidelines
├── scenes/         # Godot scene files (.tscn)
├── scripts/        # GDScript files (.gd)
├── assets/         # Textures, icons, and media files
├── plugins/        # Third-party Godot plugins
└── project.godot   # Main Godot project configuration
```

## Development Guidelines

This project follows a **text-first workflow** to ensure all files can be reviewed and edited in any text editor. See [`docs/GUIDELINES.md`](docs/GUIDELINES.md) for detailed development instructions.

### Key Principles:
- All scenes and scripts must be editable as text files
- Clean, well-commented GDScript code
- Performance-first approach
- Cross-platform compatibility
- Prefer open-source dependencies

## Contributing

1. Read [`docs/GUIDELINES.md`](docs/GUIDELINES.md) and [`docs/ROADMAP.md`](docs/ROADMAP.md)
2. Create a feature branch from `main`
3. Follow the established code style and documentation practices
4. Submit a pull request with a clear description

## Roadmap

Current development status can be found in [`docs/ROADMAP.md`](docs/ROADMAP.md).

**Current Phase:** Project Initialization
- ✅ Basic project structure
- ⏳ Core GUI framework
- 📋 Video I/O integration
- 📋 Mapping canvas implementation

## License

*License to be determined*

## Acknowledgments

- Inspired by professional videomapping tools like HeavyM and Resolume
- Built with the amazing [Godot Engine](https://godotengine.org)
- Thanks to the open-source videomapping community

---

**Note for developers:** This project prioritizes maintainability and text-based workflows. All scenes are stored as `.tscn` text files and can be edited directly if needed.