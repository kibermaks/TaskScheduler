# Developer Testing Guide

## Hidden Developer Settings

### Activation

**4-click** on the "Task Scheduler" title in the header to toggle dev settings on/off.

When enabled:

- Version number turns **green** in the header
- Developer Settings section appears at the bottom of the Settings panel
- State persists across app launches (stored in UserDefaults)

### Features

#### Reset Calendar Setup

- Button: "Reset Calendar Setup"
- Function: Clears the setup completion flag
- Use Case: Test the calendar permission and setup flow multiple times
- Effect: Next time you launch/refresh, you'll see the CalendarSetupView again

## Testing Calendar Permission & Setup Flow

### Reset App State Completely

```bash
# Clear all app preferences
defaults delete com.kibermaks.TaskScheduler

# Revoke calendar permissions (manual)
# Go to: System Settings > Privacy & Security > Calendars
# Remove "Task Scheduler" from the list
```

### Expected Flow

1. **First Launch (no permissions)**
   - Shows: CalendarPermissionView
   - Action: Click "Grant Calendar Access"
   - System: macOS permission dialog appears
   - After granting: Automatically transitions to setup

2. **After Permissions (no setup)**
   - Shows: CalendarSetupView
   - Action: Select calendars for Work, Side, Deep sessions
   - Action: Click "Complete Setup"
   - After completing: Transitions to main app

3. **Normal Launch**
   - Shows: Main app interface
   - First time only: Welcome guide appears

### Quick Reset for Testing

Using Dev Settings:

1. 4-click "Task Scheduler" title
2. Verify version turns green
3. Scroll to bottom of Settings panel
4. Click "Reset Calendar Setup"
5. The setup screen will appear immediately

## App Bundle ID

```code
com.kibermaks.TaskScheduler
```

## Current Version

- Marketing Version: 1.1
- Build Number: 79

## UserDefaults Keys

### Setup & Permissions

- `TaskScheduler.HasCompletedSetup` - Boolean, tracks if calendar setup is done
- `showDevSettings` - Boolean, tracks if dev settings are enabled

### Calendars

- `TaskScheduler.SavedState` - JSON, stores current scheduling configuration
- Includes: workCalendarName, sideCalendarName, deepSessionConfig.calendarName

### Guides

- `hasSeenWelcome` - Boolean
- `hasSeenPatternsGuide` - Boolean
- `hasSeenTasksGuide` - Boolean

## Implementation Details

### Files Modified

1. **ContentView.swift**
   - Added `@AppStorage("showDevSettings")`
   - Added 4-click gesture on app title
   - Version number changes color when dev mode active
   - Listeners for ResetCalendarSetup notification

2. **SettingsPanel.swift**
   - New dev settings section (conditionally shown)
   - Reset Calendar Setup button
   - Posts ResetCalendarSetup notification

3. **LeftPanel.swift**
   - Passes showDevSettings binding through to SettingsPanel

### Files Created

1. **CalendarPermissionView.swift**
   - Beautiful onboarding for calendar access
   - Explains why permissions are needed
   - 3-step guide for setup process

2. **CalendarSetupView.swift**
   - One-time calendar assignment form
   - Visual cards for each session type
   - Validation before completion
   - Saves to SchedulingEngine

## Notification Events

- `SetupCompleted` - Posted when calendar setup is completed
- `ResetCalendarSetup` - Posted when dev reset button is clicked
- ContentView listens to both and updates `hasCompletedSetup` accordingly
