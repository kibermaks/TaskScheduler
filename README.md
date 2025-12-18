# Task Scheduler

Task Scheduler is a macOS application built with SwiftUI that helps users plan their productive day by automatically scheduling work and side sessions around existing calendar events. It features a dynamic scheduling engine, preset management, and a beautiful timeline visualization.

## 🚀 Key Features

- **Smart Scheduling**: Automatically fits work and side sessions into available gaps in your macOS Calendar.
- **Dynamic Patterns**: Choose from multiple scheduling patterns (Alternating, All Work First, All Side First, Custom Ratio).
- **Preset Management**: Save and quickly apply different configurations for Workdays, Focus Days, or Weekends.
- **Timeline Visualization**: Interactive side-by-side view of existing calendar events and projected sessions.
- **Calendar Integration**: Read from and write directly to macOS Calendar calendars.
- **Customizable Sessions**: Configure specific names, durations, and target calendars for different session types (Work, Side, Planning, Extra).

## 🏗 Architecture & Key Elements

The project follows a modular architecture with a clear separation of concerns:

### Models
- `Session.swift`: Defines `SessionType` and `ScheduledSession` data structures.
- `Preset.swift`: Handles preset configuration and persistence via `UserDefaults`.
- `SchedulePattern.swift`: Contains the logic for generating session orders based on user-defined patterns.

### Services
- `SchedulingEngine.swift`: The core logic that calculates where sessions can fit based on current availability and user preferences.
- `CalendarService.swift`: Manages `EventKit` interactions for reading and writing calendar events.
- `AvailabilityCalculator.swift`: A utility service that identifies free time gaps between existing events.

### Views
- `ContentView.swift`: The main layout container.
- `TimelineView.swift`: Renders the interactive daily schedule.
- `SettingsPanel.swift`: Provides controls for session counts, durations, and patterns.
- `PresetManager.swift`: View for managing and applying saved presets.

## 🛠 How to Proceed with Changes

### Adding a New Session Type
1. Update `SessionType` enum in `Session.swift` with a new case, icon, and color.
2. Update `SchedulingEngine.swift` to handle the new type in its generation loop.
3. Add UI controls in `SettingsPanel.swift` to allow users to configure the new session type.

### Modifying Scheduling Logic
- The core algorithm resides in `SchedulingEngine.generateSchedule()`.
- To change how gaps are found, look at `AvailabilityCalculator.calculate()`.
- To add a new pattern, add a case to `SchedulePattern` and implement its logic in `SessionOrderGenerator.generateOrder()`.

### UI Enhancements
- Visual styles are primarily defined using standard SwiftUI modifiers and a custom `Color(hex:)` extension.
- Most components follow a dark-themed, glassmorphic aesthetic.

## 📦 Dependencies
- **SwiftUI**: Main UI framework.
- **EventKit**: For macOS Calendar integration.
- **Foundation**: Core logic and date handling.
