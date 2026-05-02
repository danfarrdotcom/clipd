# Contributing to Clipd

Thank you for your interest in contributing! This project welcomes pull requests, bug reports, and feature suggestions.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOURNAME/Clipd.git`
3. Install dependencies: `make install-deps` (optional, for GIF optimization)
4. Open in Xcode: `make run`

## Development Workflow

```bash
# Create a feature branch
git checkout -b feature/your-feature-name

# Make your changes
# ... edit code ...

# Build and test
make build

# Commit with clear message
git commit -m "Add feature: description of what changed"

# Push to your fork
git push origin feature/your-feature-name

# Open a Pull Request
```

## Commit Message Guidelines

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit first line to 72 characters
- Reference issues when applicable: "Fix #123"

## Code Style

- Follow Swift API Design Guidelines
- Use SwiftUI for all UI components
- Prefer `async/await` over completion handlers
- Document public APIs with doc comments
- Keep functions focused and under 50 lines when possible

## Testing

- Test on macOS 13.0+ before submitting
- Verify Screen Recording permission flow works
- Check both menu bar and global hotkey entry points
- Test GIF output opens correctly in browsers/image viewers

## Reporting Bugs

Include:
- macOS version
- Xcode version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots or GIFs if applicable

## Feature Requests

Open an issue with the `enhancement` label. Check the roadmap in README.md first.
