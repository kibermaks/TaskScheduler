#!/usr/bin/env python3
"""Generate SessionFlow shortcut template files.

Creates .shortcut files that users can double-click to import into the Shortcuts app.
Each template parses the JSON input from SessionFlow and shows a notification.
"""

import plistlib
import subprocess
import os
import tempfile
import uuid

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "public", "shortcuts")

SHORTCUTS = [
    {
        "filename": "SessionFlow Approaching",
        "comment": (
            "SessionFlow Template: Session Approaching\n\n"
            "Runs before a session starts (configurable lead time in SessionFlow settings).\n"
            "Use this to prepare your workspace.\n\n"
            "Input JSON keys: trigger, type, typeName, title, message, duration, startTime, endTime"
        ),
        "extra_comment": (
            "Add your custom actions below. For example:\n"
            "- Set Focus mode\n"
            "- Send a notification via Pushover or ntfy\n"
            "- Toggle smart home devices"
        ),
        "color": 1536288255,
        "glyph": 59511,
    },
    {
        "filename": "SessionFlow Started",
        "comment": (
            "SessionFlow Template: Session Started\n\n"
            "Runs when a session begins.\n"
            "Use this to enter focus mode, start a timer, or begin tracking.\n\n"
            "Input JSON keys: trigger, type, typeName, title, message, duration, startTime, endTime"
        ),
        "extra_comment": (
            "Add your custom actions below. For example:\n"
            "- Enable Do Not Disturb / Focus mode\n"
            "- Start a Toggl or RescueTime timer\n"
            "- Lock distracting websites\n"
            "- Send a Slack status update"
        ),
        "color": 4282601983,
        "glyph": 59511,
    },
    {
        "filename": "SessionFlow Ended",
        "comment": (
            "SessionFlow Template: Session Ended\n\n"
            "Runs when a session ends.\n"
            "Use this to exit focus mode, log completed work, or notify yourself.\n\n"
            "Input JSON keys: trigger, type, typeName, title, message, duration, startTime, endTime"
        ),
        "extra_comment": (
            "Add your custom actions below. For example:\n"
            "- Disable Do Not Disturb / Focus mode\n"
            "- Stop a Toggl timer\n"
            "- Log session to a note or spreadsheet\n"
            "- Unlock blocked websites"
        ),
        "color": 4251333119,
        "glyph": 59511,
    },
    {
        "filename": "Rest Started",
        "comment": (
            "SessionFlow Template: Rest Started\n\n"
            "Runs when a rest period begins between sessions.\n"
            "Use this to remind yourself to take a real break.\n\n"
            "Input JSON keys: trigger, type, typeName, title, message, duration,\n"
            "  startTime, endTime, restDuration, nextTitle, nextStartTime"
        ),
        "extra_comment": (
            "Add your custom actions below. For example:\n"
            "- Remind to stretch or drink water\n"
            "- Set a timer for the break duration\n"
            "- Play relaxing music"
        ),
        "color": 4292093695,
        "glyph": 59511,
    },
    {
        "filename": "Rest Ending Soon",
        "comment": (
            "SessionFlow Template: Rest Ending Soon\n\n"
            "Runs when a rest period is about to end.\n"
            "Use this to wrap up your break and get ready.\n\n"
            "Input JSON keys: trigger, type, typeName, title, message, duration,\n"
            "  startTime, endTime, restDuration, nextTitle, nextStartTime"
        ),
        "extra_comment": (
            "Add your custom actions below. For example:\n"
            "- Alert to wrap up the break\n"
            "- Preview the next session title\n"
            "- Re-enable Focus mode early"
        ),
        "color": 4271458815,
        "glyph": 59511,
    },
    {
        "filename": "Rest Ended",
        "comment": (
            "SessionFlow Template: Rest Ended\n\n"
            "Runs when a rest period ends and the next session is starting.\n"
            "Use this to re-engage focus mode.\n\n"
            "Input JSON keys: trigger, type, typeName, title, message, duration,\n"
            "  startTime, endTime, nextTitle, nextStartTime"
        ),
        "extra_comment": (
            "Add your custom actions below. For example:\n"
            "- Re-enable Focus mode\n"
            "- Close break-related apps\n"
            "- Start the next session timer"
        ),
        "color": 4282601983,
        "glyph": 59511,
    },
]


def make_shortcut(config):
    dict_uuid = str(uuid.uuid4()).upper()
    value_uuid = str(uuid.uuid4()).upper()

    actions = []

    # Comment explaining the template
    actions.append({
        'WFWorkflowActionIdentifier': 'is.workflow.actions.comment',
        'WFWorkflowActionParameters': {
            'WFCommentActionText': config['comment']
        }
    })

    # Get Dictionary from Input (parse JSON)
    actions.append({
        'WFWorkflowActionIdentifier': 'is.workflow.actions.detect.dictionary',
        'WFWorkflowActionParameters': {
            'UUID': dict_uuid
        }
    })

    # Get Dictionary Value for "message"
    actions.append({
        'WFWorkflowActionIdentifier': 'is.workflow.actions.getvalueforkey',
        'WFWorkflowActionParameters': {
            'UUID': value_uuid,
            'WFGetDictionaryValueType': 'Value',
            'WFDictionaryKey': 'message',
            'WFInput': {
                'Value': {
                    'OutputName': 'Dictionary',
                    'OutputUUID': dict_uuid,
                    'Type': 'ActionOutput'
                },
                'WFSerializationType': 'WFTextTokenAttachment'
            }
        }
    })

    # Show Notification with the message
    actions.append({
        'WFWorkflowActionIdentifier': 'is.workflow.actions.notification',
        'WFWorkflowActionParameters': {
            'WFNotificationActionTitle': 'SessionFlow',
            'WFNotificationActionBody': {
                'Value': {
                    'attachmentsByRange': {
                        '{0, 1}': {
                            'OutputName': 'Dictionary Value',
                            'OutputUUID': value_uuid,
                            'Type': 'ActionOutput'
                        }
                    },
                    'string': '\uFFFC'
                },
                'WFSerializationType': 'WFTextTokenString'
            }
        }
    })

    # Extra comment with customization suggestions
    if config.get('extra_comment'):
        actions.append({
            'WFWorkflowActionIdentifier': 'is.workflow.actions.comment',
            'WFWorkflowActionParameters': {
                'WFCommentActionText': config['extra_comment']
            }
        })

    return {
        'WFWorkflowMinimumClientVersionString': '900',
        'WFWorkflowMinimumClientVersion': 900,
        'WFWorkflowIcon': {
            'WFWorkflowIconStartColor': config['color'],
            'WFWorkflowIconGlyphNumber': config['glyph']
        },
        'WFWorkflowTypes': ['NCWidget', 'WatchKit'],
        'WFWorkflowInputContentItemClasses': ['WFStringContentItem'],
        'WFWorkflowActions': actions,
        'WFWorkflowImportQuestions': []
    }


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    for config in SHORTCUTS:
        shortcut_data = make_shortcut(config)
        output_path = os.path.join(OUTPUT_DIR, f"{config['filename']}.shortcut")

        # Write unsigned plist to temp file (must have .shortcut extension for signing)
        temp_dir = tempfile.mkdtemp()
        temp_path = os.path.join(temp_dir, f"{config['filename']}.shortcut")
        with open(temp_path, 'wb') as f:
            plistlib.dump(shortcut_data, f, fmt=plistlib.FMT_BINARY)

        # Sign the shortcut for universal import
        try:
            result = subprocess.run(
                ['shortcuts', 'sign', '-i', temp_path, '-o', output_path, '-m', 'anyone'],
                capture_output=True, text=True, timeout=30
            )
            if result.returncode == 0:
                print(f"  Created: {config['filename']}.shortcut")
            else:
                import shutil
                shutil.copy2(temp_path, output_path)
                print(f"  Created (unsigned): {config['filename']}.shortcut — {result.stderr.strip()}")
        except (subprocess.TimeoutExpired, FileNotFoundError):
            import shutil
            shutil.copy2(temp_path, output_path)
            print(f"  Created (unsigned): {config['filename']}.shortcut")
        finally:
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)

    print(f"\nDone! {len(SHORTCUTS)} shortcuts in {OUTPUT_DIR}/")


if __name__ == '__main__':
    main()
