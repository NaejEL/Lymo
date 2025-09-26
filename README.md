# Lymo

![Icon](/assets/icon.svg)

Cross-platform videomapping application built with Godot 4 and GDScript.

## Overview

Lymo is a powerful, user-friendly videomapping software designed for projection mapping applications. Built with Godot Engine, it provides a modern, cross-platform solution for mapping video content onto irregular surfaces and 3D objects.

### Key Features

**✅ Currently Available:**
- **Cross-platform support** for Windows and Linux
- **Real-time video mapping** with quadrilateral projection surfaces
- **Alpha video support** with full transparency for VP8/VP9 WebM videos
- **Intelligent caching system** prevents re-processing of unchanged videos
- **Intuitive GUI** with professional workflow design
- **Multi-screen output** with fullscreen projection mode
- **Chroma key effects** for green/blue screen transparency
- **Surface controls**: opacity, layering, locking, transformation
- **Project management** with save/load functionality
- **Text-first workflow** optimized for version control

**🚧 In Development (VideoStream Module):**
- **Hardware-accelerated video decoding** (NVDEC, QuickSync, VAAPI)
- **Professional video formats** (ProRes 4444, advanced codecs)
- **Multi-video performance optimization** for 4K+ content

**📋 Planned Features:**
- **Live camera input** and real-time capture
- **Advanced surface geometry** (bezier curves, 3D mapping)
- **Timeline and keyframe animation**
- **Multi-projector blending** and calibration
- **Network synchronization** for multi-machine setups

## 🎯 Alpha Video Support

Lymo now features **full alpha channel video support** through an innovative PNG sequence approach:

### ✅ What's Working
- **VP8/VP9 WebM videos** with alpha channels display correctly
- **Automatic codec detection** and proper FFmpeg decoder selection
- **Smart caching system** avoids re-processing unchanged videos
- **Seamless integration** via PNGSequencePlayer (VideoStreamPlayer-compatible)
- **Real-time playback** with proper alpha compositing

### 🛠️ Technical Implementation
- **libvpx decoder** for VP8 alpha videos
- **libvpx-vp9 decoder** for VP9 alpha videos  
- **JSON-based cache validation** using file modification times
- **PNG sequence extraction** preserves full alpha channel data

### 📈 Future Enhancements
- **C++ module approach** for hardware-accelerated alpha video decoding
- **GPU-based PNG sequence rendering** for improved performance

## Requirements

### Basic Requirements
- Godot Engine 4.5 or later
- Windows 10/11 or Linux (Ubuntu 20.04+ recommended)  
- Graphics card with OpenGL 3.3 support
- 8GB RAM minimum, 16GB+ recommended for 4K videos

### For Professional Alpha Video Support (In Development)
- **Windows:** NVIDIA GTX 1060+ (NVDEC) or Intel HD Graphics 630+ (QuickSync)
- **Linux:** VAAPI-compatible graphics card (Intel/AMD)
- **Development:** Visual Studio 2019+ (Windows) or GCC 9+ (Linux)
- **Dependencies:** CUDA SDK, Intel Media SDK, FFmpeg with hardware acceleration

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

## Development Status

Current development status can be found in [`docs/ROADMAP.md`](docs/ROADMAP.md).

### **Current Phase: Custom VideoStream Development (P0.5)**

**⚠️ Critical Blocker:** Godot's built-in video system cannot support professional videomapping:
- ❌ No alpha channel support in VideoStreamWebm
- ❌ CPU-only video decoding (no hardware acceleration)
- ❌ Poor performance with multiple high-resolution videos

**🚀 Solution:** Custom VideoStream implementation (10-12 weeks)
- 📋 **Phase 1-2:** Hardware decoder architecture (NVDEC, QuickSync, VAAPI)
- 📋 **Phase 3:** Godot integration with alpha support
- 📋 **Phase 4-5:** Production optimization and cross-platform testing

**Platform Strategy:**
- **Windows:** Full alpha video + hardware acceleration
- **Linux:** Hardware decode + chroma key transparency fallback
- **Single Codebase:** No separate development branches needed

### **Completed Foundation:**
- ✅ Core GUI framework and user interface
- ✅ Basic video conversion and loading system
- ✅ Projection surface management and rendering
- ✅ Chroma key (green screen) effects
- ✅ Multi-display output and fullscreen projection
- ✅ Cross-platform project structure

## License

*License to be determined*

## Acknowledgments

- Inspired by professional videomapping tools like HeavyM and Resolume
- Built with the amazing [Godot Engine](https://godotengine.org)
- Thanks to the open-source videomapping community

---

**Note for developers:** This project prioritizes maintainability and text-based workflows. All scenes are stored as `.tscn` text files and can be edited directly if needed.