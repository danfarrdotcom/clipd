# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-02

### Added
- Initial release of Clipd
- Menu bar screen recorder with no dock icon
- Drag-to-select region capture
- Adjustable FPS (5-30) for quality vs file size control
- Live frame counter during recording
- Cursor inclusion in GIF output
- GIF encoding via ImageIO with loop support
- Optional gifsicle optimization for smaller files
- Global hotkey (Cmd+Shift+4) for instant recording
- Copy to clipboard / Save As / Open workflow
- Settings panel for defaults and preferences
- MIT License
- Makefile for common development tasks
- GitHub Actions CI workflow

### Technical
- Swift 5.9 + SwiftUI
- ScreenCaptureKit for screen capture
- macOS 13.0+ minimum requirement
