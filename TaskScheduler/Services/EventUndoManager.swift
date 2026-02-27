import Foundation
import SwiftUI

/// Tracks move/resize operations on calendar events for undo/redo.
/// Custom class to avoid conflicts with SwiftUI's text field UndoManager.
class EventUndoManager: ObservableObject {

    struct EventTimeChange: Equatable {
        let eventId: String
        let oldStartTime: Date
        let oldEndTime: Date
        let newStartTime: Date
        let newEndTime: Date
        let description: String  // e.g. "Move Meeting" or "Resize Meeting"
    }

    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    private var undoStack: [EventTimeChange] = []
    private var redoStack: [EventTimeChange] = []
    private let maxStackSize = 50

    func record(_ change: EventTimeChange) {
        undoStack.append(change)
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        updateState()
    }

    /// Returns the inverse change to apply, or nil if stack is empty.
    func undo() -> EventTimeChange? {
        guard let change = undoStack.popLast() else { return nil }
        redoStack.append(change)
        updateState()
        return EventTimeChange(
            eventId: change.eventId,
            oldStartTime: change.newStartTime,
            oldEndTime: change.newEndTime,
            newStartTime: change.oldStartTime,
            newEndTime: change.oldEndTime,
            description: "Undo \(change.description)"
        )
    }

    /// Returns the change to re-apply, or nil if stack is empty.
    func redo() -> EventTimeChange? {
        guard let change = redoStack.popLast() else { return nil }
        undoStack.append(change)
        updateState()
        return change
    }

    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateState()
    }

    private func updateState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}
