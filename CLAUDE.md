# OCC — One's Command Center

macOS menu bar app for receiving and responding to AI nudge notifications.

## Design Principles

**User-friendliness is the #1 priority.** The UI must be:
- Gorgeous and minimal — Apple-like aesthetic
- Extremely low cognitive load — users should instantly understand what to do
- Clean, spacious, and uncluttered
- Even when features are requested that sound complex, push back toward simplicity

When in doubt, remove rather than add. Every element must earn its place.

## Build

```bash
swift build        # Build the project
swift run occ      # Run the app
```

## Architecture

- `OCC/App/` — App entry point, AppDelegate
- `OCC/UI/` — SwiftUI views (MenuBarPopover, PillView, NudgeDetailView, etc.)
- `OCC/Core/` — Models, state management, file parsing
- `OCC/Bridge/` — CLI socket bridge, file watchers, request/reply writers
