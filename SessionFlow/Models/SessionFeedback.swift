import Foundation

// MARK: - Feedback rating (stored as emoji hashtags in calendar event notes)

enum SessionRating: String, Codable, CaseIterable {
    case rocket = "rocket"          // Amazing session, nailed it
    case completed = "completed"    // Stayed focused the whole time
    case partial = "partial"        // Was there some of the time
    case skipped = "skipped"        // Was AFK / didn't do it

    /// Emoji hashtag written to calendar event notes (e.g. "#flow✅")
    var tag: String {
        switch self {
        case .rocket: return "#flow🚀"
        case .completed: return "#flow✅"
        case .partial: return "#flow🌗"
        case .skipped: return "#flow❌"
        }
    }

    /// All known feedback tags for stripping/parsing
    static var allTags: [String] {
        allCases.map(\.tag)
    }

    var icon: String {
        switch self {
        case .rocket: return "flame.fill"
        case .completed: return "checkmark.circle.fill"
        case .partial: return "circle.lefthalf.filled"
        case .skipped: return "xmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .rocket: return "Fire"
        case .completed: return "Done"
        case .partial: return "Partly"
        case .skipped: return "Skipped"
        }
    }

    var focusMultiplier: Double {
        switch self {
        case .rocket: return 1.0
        case .completed: return 0.8
        case .partial: return 0.5
        case .skipped: return 0.0
        }
    }

    /// Parse a rating from calendar event notes by looking for emoji hashtags
    static func fromNotes(_ notes: String?) -> SessionRating? {
        guard let notes = notes else { return nil }
        for rating in allCases {
            if notes.contains(rating.tag) { return rating }
        }
        return nil
    }

    /// Strips only feedback tags from notes, preserving session type tags
    static func stripFeedbackTags(_ notes: String?) -> String? {
        guard let notes = notes, !notes.isEmpty else { return nil }
        var result = notes
        for tag in allTags {
            result = result.replacingOccurrences(of: tag, with: "")
        }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    /// Applies this rating tag to notes, removing any existing feedback tag first
    func applyTo(notes: String?) -> String {
        var result = notes ?? ""
        // Remove existing feedback tags
        for existingTag in Self.allTags {
            result = result.replacingOccurrences(of: existingTag, with: "")
        }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        // Append new tag
        result += (result.isEmpty ? "" : " ") + tag
        return result
    }
}

// MARK: - Pending feedback (in-memory, drives the panel prompt)

struct SessionFeedback: Identifiable {
    let id = UUID()
    let eventId: String         // BusyTimeSlot.id for lookup
    let sessionTitle: String
    let sessionType: SessionType?
    let startTime: Date
    let endTime: Date

    var totalDuration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}
