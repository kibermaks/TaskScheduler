  # SessionFlow Shortcut Templates

Ready-to-import templates for macOS Shortcuts that work with SessionFlow's trigger system.

## How to Use

1. Download a `.shortcut` file from this folder
2. Double-click to import it into the Shortcuts app
3. Customize the shortcut to your needs (notifications, Focus modes, smart home, etc.)
4. In SessionFlow Settings > Shortcuts, enter the shortcut name and enable the trigger

## Trigger Templates

### Session Lifecycle

| Template | Trigger | Description |
|----------|---------|-------------|
| [SessionFlow Approaching.shortcut](SessionFlow%20Approaching.shortcut) | `approaching` | Fires before a session starts (configurable lead time). Use to prepare your workspace. |
| [SessionFlow Started.shortcut](SessionFlow%20Started.shortcut) | `started` | Fires when a session begins. Use to enable Focus mode, silence notifications, start a timer. |
| [SessionFlow Ended.shortcut](SessionFlow%20Ended.shortcut) | `ended` | Fires when a session ends. Use to disable Focus mode, log time, send a summary. |

### Rest Lifecycle

| Template | Trigger | Description |
|----------|---------|-------------|
| [Rest Started.shortcut](Rest%20Started.shortcut) | `rest_started` | Fires when a rest period begins. Use to remind yourself to stretch, hydrate, or step away. |
| [Rest Ending Soon.shortcut](Rest%20Ending%20Soon.shortcut) | `rest_ending_soon` | Fires shortly before rest ends. Use to wrap up your break and prepare for the next session. |
| [Rest Ended.shortcut](Rest%20Ended.shortcut) | `rest_ended` | Fires when rest ends and the next session begins. Use to re-engage Focus mode. |

## JSON Input

Every shortcut receives a JSON payload as input with these fields:

```json
{
  "trigger": "started",
  "type": "deep",
  "typeName": "Deep",
  "title": "Heavy brainstorm",
  "message": "Deep session 'Heavy brainstorm' started",
  "duration": 90,
  "startTime": "2025-01-15T09:00:00Z",
  "endTime": "2025-01-15T10:30:00Z"
}
```

Rest triggers include additional fields:

```json
{
  "restDuration": 15,
  "nextTitle": "Code review",
  "nextStartTime": "2025-01-15T10:45:00Z"
}
```

### Extracting Values in Shortcuts

Use **Get Dictionary Value** action on the Shortcut Input to extract individual fields:
- `message` — ready-to-display text, great for notifications
- `type` — session type key (`deep`, `light`, `admin`, `external`)
- `title` — session title
- `trigger` — which trigger fired

## Siri & App Intents

SessionFlow also provides these Siri Shortcuts (available automatically, no import needed):

| Shortcut | What it returns |
|----------|----------------|
| **Current Session** | Active session type, title, elapsed and remaining time |
| **Next Session** | Next upcoming session type, title, and minutes until start |
| **Today's Focus Time** | Total rated focus minutes and session count for today |
| **Session Active?** | Boolean — whether any session is currently active |

These can be used in Shortcuts automations, Siri voice commands, or as conditions in your own workflows.
