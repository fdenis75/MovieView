# Changelog

## [Unreleased]

### Added
- New HomeView with improved navigation and organization
  - Three-panel layout using NavigationSplitView
  - Sidebar with Library and History sections
  - Main content area with Statistics, Recent Activity, and Quick Actions
  - Detail view for selected items
  - Global search functionality
  - Placeholder components for future features
- Comprehensive unit tests for Models and ViewModels
  - Tests for MovieFile initialization and equality
  - Tests for DensityConfig values and behavior
  - Tests for VideoThumbnail initialization and time formatting
  - Tests for VideoProcessor functionality
  - Tests for ViewState enum cases
- Comprehensive UI tests
  - Tests for initial application state
  - Tests for density picker functionality
  - Tests for navigation elements
  - Tests for thumbnail grid layout
  - Tests for accessibility labels
  - Tests for user interaction responsiveness
- Launch tests
  - Tests for initial UI elements presence
  - Performance metrics for app launch
  - Screenshot capture of launch state
- Added optional scene detection for smart thumbnail generation
  - Accelerate framework integration for fast histogram calculation
  - Parallel frame processing with TaskGroup
  - 0.25s sampling rate for accurate detection
  - vImage and vDSP optimizations for performance
  - Adaptive thumbnail placement at scene boundaries
  - Toggle button in toolbar to enable/disable
  - Adjustable sensitivity slider (0.1-0.5)
  - Visual indicators for scene change thumbnails
  - Yellow border and camera icon for scene transitions
- Enhanced cancellation support for processing operations:
  - Added escape key support to cancel ongoing operations
  - Added cancel button in toolbar for both folder scanning and video processing
  - Improved task cancellation handling with proper cleanup
  - Clear partial results when cancelling operations
  - Visual feedback during cancellation
  - Keyboard shortcut (Escape) for quick cancellation
- Comprehensive error handling system with detailed error messages and recovery suggestions
- Unified macOS logging system using `OSLog`
- Improved error feedback in the UI with descriptive alerts
- Added error recovery suggestions for common issues
- Detailed logging for video and folder processing operations
- Better error handling for file access and processing issues
- Error handling for IINA player integration

### Changed
- Optimized cache key generation to use file path and modification date instead of file content
  - Significantly improved performance by avoiding full file reads
  - Reduced memory usage during cache key generation
  - Maintained cache invalidation on file modifications
- Enhanced thumbnail display with scene change information
  - Added isSceneChange property to VideoThumbnail model
  - Updated ThumbnailView to show scene change indicators
  - Improved timestamp formatting to include hours when needed
- Improved folder processing with better cancellation support
  - Added progress cleanup on cancellation
  - Clear partial results when cancelled
  - Better state management during cancellation
- Enhanced video processing with robust cancellation
  - Added progress cleanup on cancellation
  - Clear partial thumbnails when cancelled
  - Improved state management for cancellation
  - Better error handling for cancellation
- Enhanced video processing error handling with specific error types
- Improved folder processing with better error reporting
- Better feedback during thumbnail generation failures
- More informative error messages for file access issues
- Added logging throughout the application for better debugging

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
- Implemented hover preview with 2-second looping video clips
- Added thumbnail density control (XXS to XXL) with dynamic thumbnail count calculation
- Added automatic reprocessing when density is changed
- Added progressive thumbnail loading with fade-in animations
- Added file picker to open movie files directly from the app
- Added ability to cancel video processing with escape key or cancel button
- Added thumbnail count preview when changing density
- Added folder browsing with movie previews and double-click to process
- Added back navigation between folder and processing views
- Added split view for folder browsing with movie list and mosaic preview
- Modified thumbnail generation to respect original video aspect ratios
- Updated ThumbnailView to handle variable height thumbnails while maintaining consistent width
- Updated folder processor to respect video aspect ratios when generating thumbnails
- Added thumbnail size slider to control thumbnail dimensions (160px to 480px)
- Updated thumbnail generation to support higher resolution previews
- Modified grid layout to dynamically adjust to thumbnail size changes
- Added "Today's Videos" feature to quickly access videos created today
- Added Spotlight integration for finding today's videos
- Added loading indicator for today's videos search
- Added date range search for finding videos between specific dates
- Added date picker sheet with start and end date selection
- Added loading indicators for date range search

### Changed
- Removed SwiftData references from the project
- Updated MovieViewApp to support mosaic viewer layout
- Modified window configuration for better UX
- Consolidated all components into a single core file
- Improved error handling with proper MainActor usage
- Updated thumbnail generation to use density-based calculations
- Added currentVideoURL tracking to VideoProcessor for density changes
- Enhanced thumbnail loading with sequential appearance and animations
- Made video processing more accessible with public processVideo method
- Added task cancellation support to VideoProcessor
- Replaced density menu with segmented control for better UX
- Enhanced drag and drop to support folders
- Added state management for different view modes
- Improved folder browsing with NavigationSplitView layout

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
- Better handling of invalid video files
- Improved error handling for inaccessible files and folders
- More graceful handling of processing failures
- Clear error messages when IINA is not installed

### Security
- Added sandbox entitlements for secure file access
- Added read-only permissions for movies and user-selected files
- Implemented proper memory management to prevent leaks 

## [1.1.0] - 2024-01-11

### Changed
- Major code refactoring for better organization and maintainability
- Split monolithic MovieViewCore.swift into multiple modules:
  - Models: MovieFile, ViewState, DensityConfig, VideoThumbnail
  - ViewModels: FolderProcessor, VideoProcessor
  - Views: ContentView, FolderView, ThumbnailView, DensityPicker
  - Utilities: VideoDropDelegate
- Improved code organization and separation of concerns
- Enhanced modularity for better testing and maintenance 

### Added
- Added loading indicators for date range search
- Fixed thumbnail generation for date-based video searches
- Added background thumbnail processing for search results 