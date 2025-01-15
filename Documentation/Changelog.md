# Changelog

## [0.1.0] - 2024-01-11

### Added
- Initial project setup
- Basic SwiftUI project structure
- Documentation directory created
- Project specifications defined
- Created VideoThumbnail model for thumbnail representation
- Implemented VideoProcessor for handling video files
- Added ThumbnailView for displaying video thumbnails
- Implemented main ContentView with drag-and-drop support
- Added necessary entitlements for file access
- Created Models and Views directory structure
- Implemented video thumbnail generation
- Added video playback functionality
- Implemented error handling
- Added loading indicators
- Created unified MovieViewCore.swift for better organization

### Changed
- Removed SwiftData references from the project
- Updated MovieViewApp to support mosaic viewer layout
- Modified window configuration for better UX
- Consolidated all components into a single core file
- Improved error handling with proper MainActor usage

### Deprecated
- N/A

### Removed
- Removed default Item model and related code
- Removed SwiftData container configuration
- Removed separate model files in favor of unified core file

### Fixed
- Fixed thread safety issues with @MainActor
- Improved error handling with proper error propagation
- Fixed memory management with weak self references

### Security
- Added sandbox entitlements for secure file access
- Added read-only permissions for movies and user-selected files
- Implemented proper memory management to prevent leaks 