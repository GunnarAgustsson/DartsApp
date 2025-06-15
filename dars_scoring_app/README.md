# DARTS Scoring App

A modern darts scoring application built with Flutter.

## Features

- Multiple game modes (301, 501, 701, etc.)
- Player management system
- Game history tracking
- Statistics and performance analysis
- Checkout suggestions
- Theme customization
- Sound and haptic feedback

## Recent Improvements

### Enhanced Theme System
- Implemented a comprehensive theme system with dedicated files for:
  - Colors (app_colors.dart)
  - Dimensions (app_dimensions.dart)
  - Text styles (app_text_styles.dart)
  - Theme provider for state management
- Added light and dark theme modes with smooth transitions
- Added text scaling options for better accessibility

### Improved UI Components
- Made all screens responsive for both portrait and landscape orientations
- Implemented adaptive layouts for different device sizes (phone vs tablet)
- Enhanced button designs with theming and haptic feedback
- Improved navigation with consistent UI patterns
- Added animations for better user experience

### Code Quality Improvements
- Reorganized project structure with cleaner architecture
- Implemented provider pattern for state management
- Added centralized settings system for user preferences
- Improved performance with optimized rendering
- Enhanced code readability and maintainability

## Getting Started

1. Ensure Flutter is installed (v3.2.0 or later)
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to launch the app

## Architecture

The app is structured with the following directories:

- **lib/screens/** - Main UI screens
- **lib/widgets/** - Reusable UI components
- **lib/theme/** - Theme definitions and styling
- **lib/services/** - Business logic and data handling
- **lib/models/** - Data models
- **lib/utils/** - Helper utilities
- **lib/data/** - Static data and constants

## Technologies Used

- Flutter SDK 3.2+
- Provider for state management
- SharedPreferences for local storage
- Haptic feedback and sound effects

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.