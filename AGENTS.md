---
agents_version: 5.4
scope: root
extends: null
last_updated: 2026-04-09
owner: github:@maintainers
---

# AGENTS.md

## Project Overview

VibeProxy is a native macOS menu bar app written in SwiftUI and AppKit. It wraps CLIProxyAPIPlus so local AI coding tools can authenticate through supported providers and route requests through a bundled proxy server.

## Build & Test Commands

- `cd src && swift build` - Build the Swift package in debug mode
- `cd src && swift test` - Run package tests
- `make build` - Build the Swift executable
- `make app` - Create `VibeProxy.app`
- `make run` - Build and launch the app
- `make clean` - Remove build artifacts and bundled resources

## Code Style Guidelines

- Follow existing SwiftUI/AppKit patterns already present in `src/Sources/`
- Keep app lifecycle and server/process management logic in focused files
- Prefer small, explicit helpers over new abstraction layers
- Reuse the existing provider/catalog/config composition codepaths before adding new ones

## Testing Instructions

- Run `cd src && swift test` for logic changes
- Build the app with `make app` for packaging-sensitive changes
- For UI changes, verify the menu bar app manually on macOS and capture evidence in a task folder

## Security Considerations

- Never commit tokens, OAuth credentials, or API keys
- Treat provider credentials and local config files as sensitive user data
- Validate changes that affect process launching, config generation, or network routing carefully

## Additional Context

- Use Conventional Commits for repository history
- Create a task folder under `tasks/` before implementation work
- Prefer official upstream docs for Swift, Sparkle, and Yams when behavior is unclear
