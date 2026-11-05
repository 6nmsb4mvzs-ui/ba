# GlassOS

A macOS desktop customization engine inspired by Wallpaper Engine, featuring glassmorphic UI, a 3D wallpaper carousel, system monitoring, and a global window navigator.

## Features

- **3D Wallpaper Carousel** — Browse and select wallpapers in a perspective carousel with smooth animations
- **Video Wallpapers** — Set video files (MP4, MOV, M4V) as your desktop wallpaper
- **Gradient Wallpapers** — 12 built-in gradient themes (Night City, Cyber Rain, Aurora, etc.)
- **Glassmorphic UI** — All interfaces use translucent, frosted-glass effects
- **F3 Window Navigator** — Press F3 for an overlay showing all open windows with quick switching
- **System Monitor** — Real-time CPU, Memory, GPU, and temperature monitoring with history charts
- **Auto-Updater** — Detects new versions from GitHub and updates with one click
- **Menu Bar Integration** — Quick access from the system menu bar

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools

## Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/6nmsb4mvzs-ui/ba.git
   cd ba
   ```

2. **Build and run:**
   Double-click `build.command` in Finder, or run in Terminal:
   ```bash
   chmod +x build.command
   ./build.command
   ```

3. The app will be built as `GlassOS.app` in the project root.

## Adding Wallpapers

Place your wallpaper files in:
```
~/Library/Application Support/GlassOS/Wallpapers/
```

Supported formats:
- **Video:** MP4, MOV, M4V, WebM
- **Image:** JPG, PNG, HEIC, WebP, TIFF

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **F3** | Toggle Window Navigator |
| **⌘B** | Show Wallpaper Browser |
| **⌘,** | Settings |
| **⌘U** | Check for Updates |
| **⌘Q** | Quit |

## Auto-Updates

GlassOS checks GitHub for new versions automatically. When an update is available:
1. Open the Updates tab in the app
2. Click "Update Now"
3. The app will pull the latest source and rebuild
4. Restart to apply

## Architecture

```
Sources/GlassOS/
├── main.swift              # App entry point
├── App/
│   ├── AppDelegate.swift   # App lifecycle, menus, windows
│   ├── AppVersion.swift    # Version management
│   └── GlassWindow.swift   # Custom frosted-glass window
├── Views/
│   ├── MainContentView.swift       # Main app layout with sidebar
│   ├── WallpaperBrowserView.swift  # 3D carousel and grid views
│   ├── WindowNavigatorView.swift   # F3 window switcher overlay
│   ├── SystemMonitorView.swift     # System stats dashboard
│   ├── SettingsView.swift          # App configuration
│   ├── UpdateView.swift            # Auto-updater UI
│   ├── AboutView.swift             # About screen
│   └── Components/
│       └── GlassCard.swift         # Reusable glass UI components
├── Engine/
│   ├── WallpaperEngine.swift       # Video/image/gradient rendering
│   └── WallpaperManager.swift      # Wallpaper state management
├── Hotkeys/
│   └── GlobalHotkeyManager.swift   # F3 global hotkey
├── Monitor/
│   └── SystemMonitor.swift         # System stats collection
└── Updater/
    └── AutoUpdater.swift           # GitHub-based auto-updater
```

## Version History

- **1.0.0** — Initial release with wallpaper engine, carousel browser, window navigator, system monitor, and auto-updater
