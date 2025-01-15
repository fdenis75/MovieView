# MovieView

A modern macOS application for viewing and browsing video files with an elegant mosaic thumbnail interface.

## Features

- 🎬 View video files with dynamic thumbnail generation
- 📁 Browse folders containing multiple video files
- 🖼️ Interactive mosaic view with adjustable density
- 👆 Hover preview of video segments
- 🎯 Quick navigation with timestamp markers
- 🎨 Modern SwiftUI interface with smooth animations
- 🔄 Drag and drop support for files and folders

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Installation

1. Clone the repository
2. Open `MovieView.xcodeproj` in Xcode
3. Build and run the project

## Usage

### Opening Files

- Drag and drop video files or folders onto the application window
- Use the "Open Movie..." button to select individual video files
- Use the "Open Folder..." button to select folders containing video files

### Viewing Videos

- Click on any thumbnail to play the video from that timestamp
- Hover over thumbnails to preview the video segment
- Use the density picker to adjust the number of thumbnails displayed

### Navigation

- Use the back button to return to the main view
- Browse folders in the sidebar and select videos to view
- Double-click folder items to view their mosaic

## Project Structure

```
MovieView/
├── Models/
│   └── Models.swift           # Data models and types
├── ViewModels/
│   ├── FolderProcessor.swift  # Folder processing logic
│   └── VideoProcessor.swift   # Video processing logic
├── Views/
│   ├── ContentView.swift      # Main view
│   ├── DensityPicker.swift    # Thumbnail density control
│   ├── FolderView.swift       # Folder browsing view
│   └── ThumbnailView.swift    # Video thumbnail view
└── Utilities/
    └── VideoDropDelegate.swift # Drag and drop handling
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details. 