import Foundation
import SwiftUI
import Combine

class SessionAwarenessService: ObservableObject {

    // MARK: - Published state

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "TaskScheduler.SessionAwarenessEnabled")
            if isEnabled {
                startTimer()
            } else {
                stopTimer()
                audioService?.stopAmbient()
                clearActiveState()
            }
        }
    }

    // Active session state
    @Published var isActive: Bool = false
    @Published var currentSessionTitle: String = ""
    @Published var currentSessionType: SessionType? = nil
    @Published var currentEventId: String? = nil
    @Published var currentEventNotes: String? = nil
    @Published var sessionStartTime: Date? = nil
    @Published var sessionEndTime: Date? = nil
    @Published var elapsed: TimeInterval = 0
    @Published var remaining: TimeInterval = 0
    @Published var progress: Double = 0

    // Non-tagged busy slot mode
    @Published var isBusySlotMode: Bool = false
    @Published var busySlotCalendarColor: Color? = nil
    @Published var busySlotCalendarName: String? = nil

    // Next session state
    @Published var nextSessionTitle: String? = nil
    @Published var nextSessionType: SessionType? = nil
    @Published var nextSessionStartTime: Date? = nil

    // Feedback
    @Published var sessionFeedbackPending: SessionFeedback? = nil

    // Current time (updated every second)
    @Published var currentTime: Date = Date()

    // Time display mode (clickable cycle)
    @Published var timeDisplayMode: TimeDisplayMode = .remaining

    // Mini-player collapsed state (NOT persisted)
    @Published var isCollapsed: Bool = false

    // Flash trigger for attention events (presence reminder, ending soon)
    enum FlashType { case presenceReminder, endingSoon }
    @Published var flashTrigger: FlashType? = nil

    // MARK: - Config

    @Published var config: SessionAwarenessConfig {
        didSet {
            config.save()
            isEnabled = config.enabled
            // Dynamic: update ambient sound if settings change mid-session
            if isActive, let audioService = audioService {
                let soundConfig: SessionSoundConfig
                if let type = currentSessionType {
                    soundConfig = config.soundConfig(for: type)
                } else if isBusySlotMode {
                    soundConfig = config.otherEventsSound
                } else {
                    return
                }
                audioService.updateAmbientIfPlaying(config: soundConfig)
            }
        }
    }

    // MARK: - Dependencies

    private weak var calendarService: CalendarService?
    private var audioService: SessionAudioService?
    private var timer: Timer?
    private var wasActive: Bool = false
    private var previousEventId: String? = nil
    private var feedbackDismissTimer: Timer?

    // Phase 3: Presence reminder tracking
    private var lastPresenceReminderTime: Date? = nil

    // Phase 3: Ending soon tracking
    private var hasPlayedEndingSoon: Bool = false

    // MARK: - Init

    init() {
        let savedConfig = SessionAwarenessConfig.load()
        self.config = savedConfig
        self.isEnabled = savedConfig.enabled
        self.timeDisplayMode = savedConfig.timeDisplayMode
    }

    // MARK: - Lifecycle

    func start(calendarService: CalendarService, audioService: SessionAudioService) {
        self.calendarService = calendarService
        self.audioService = audioService

        // Clean old feedback entries
        SessionFeedbackStore.shared.clearOldEntries(keepingDate: Date())

        if isEnabled {
            startTimer()
        }
    }

    func stop() {
        stopTimer()
    }

    // MARK: - Time display

    func cycleTimeDisplay() {
        switch timeDisplayMode {
        case .remaining: timeDisplayMode = .elapsed
        case .elapsed: timeDisplayMode = .remaining
        }
        config.timeDisplayMode = timeDisplayMode
    }

    // MARK: - Notes helper

    static func strippedNotes(_ notes: String?) -> String? {
        guard let notes = notes, !notes.isEmpty else { return nil }
        var result = notes
        for tag in ["#work", "#side", "#deep", "#plan", "#break"] {
            result = result.replacingOccurrences(of: tag, with: "", options: .caseInsensitive)
        }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    // MARK: - Timer

    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.tick() }
        }
        RunLoop.current.add(timer!, forMode: .common)
        tick() // immediate first tick
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Core tick

    private func tick() {
        let now = Date()
        currentTime = now

        guard let calendarService = calendarService else {
            clearActiveState()
            return
        }

        // 1. Try to find active tagged session
        if let slot = findActiveTaggedSession(in: calendarService.busySlots, at: now) {
            let sessionType = CalendarService.sessionType(fromNotes: slot.notes)
            activateSession(slot: slot, sessionType: sessionType, isBusySlot: false, at: now)
        }
        // 2. Try non-tagged event if enabled
        else if config.trackOtherEvents, let slot = findActiveBusySlot(in: calendarService.busySlots, at: now) {
            activateSession(slot: slot, sessionType: nil, isBusySlot: true, at: now)
        }
        // 3. No active session
        else {
            if wasActive, let prevId = previousEventId {
                // Session just ended — trigger feedback + end sound
                triggerSessionEnd(eventId: prevId)
            }
            clearActiveState()
        }

        // Phase 3: Presence reminder
        if isActive && config.presenceReminderEnabled {
            checkPresenceReminder(at: now)
        }

        // Phase 3: Ending soon
        if isActive && !hasPlayedEndingSoon && config.endingSoonSound.sound != "Off" {
            if remaining <= 120 && remaining > 0 {
                audioService?.playTransition(config: config.endingSoonSound)
                hasPlayedEndingSoon = true
                triggerFlash(.endingSoon)
            }
        }

        // Phase 3: Accelerando — update playback rate
        if isActive {
            let accelConfig: AccelerandoConfig
            if let type = currentSessionType {
                accelConfig = config.accelerandoConfig(for: type)
            } else if isBusySlotMode {
                accelConfig = config.otherEventsSoundAccelerando
            } else {
                accelConfig = .init()
            }
            audioService?.updatePlaybackRate(progress: progress, accelerando: accelConfig)
        }

        // Update next session
        updateNextSession(in: calendarService.busySlots, at: now)

        wasActive = isActive
        previousEventId = currentEventId
    }

    // MARK: - Presence reminder

    private func checkPresenceReminder(at now: Date) {
        let intervalSeconds = TimeInterval(config.presenceReminderIntervalMinutes * 60)
        let referenceTime = lastPresenceReminderTime ?? sessionStartTime ?? now

        if now.timeIntervalSince(referenceTime) >= intervalSeconds {
            audioService?.playTransition(config: config.presenceReminderSound)
            lastPresenceReminderTime = now
            triggerFlash(.presenceReminder)
        }
    }

    // MARK: - Session detection

    private func findActiveTaggedSession(in slots: [BusyTimeSlot], at now: Date) -> BusyTimeSlot? {
        slots
            .filter { $0.startTime <= now && now < $0.endTime }
            .filter { CalendarService.sessionType(fromNotes: $0.notes) != nil }
            .sorted { $0.startTime < $1.startTime }
            .first
    }

    private func findActiveBusySlot(in slots: [BusyTimeSlot], at now: Date) -> BusyTimeSlot? {
        slots
            .filter { $0.startTime <= now && now < $0.endTime }
            .filter { CalendarService.sessionType(fromNotes: $0.notes) == nil }
            .sorted { $0.startTime < $1.startTime }
            .first
    }

    private func updateNextSession(in slots: [BusyTimeSlot], at now: Date) {
        let upcoming = slots
            .filter { $0.startTime > now }
            .filter { CalendarService.sessionType(fromNotes: $0.notes) != nil }
            .sorted { $0.startTime < $1.startTime }

        if let next = upcoming.first {
            nextSessionTitle = next.title
            nextSessionType = CalendarService.sessionType(fromNotes: next.notes)
            nextSessionStartTime = next.startTime
        } else {
            nextSessionTitle = nil
            nextSessionType = nil
            nextSessionStartTime = nil
        }
    }

    // MARK: - State management

    private func activateSession(slot: BusyTimeSlot, sessionType: SessionType?, isBusySlot: Bool, at now: Date) {
        let isNewSession = currentEventId != slot.id

        currentEventId = slot.id
        currentSessionTitle = slot.title
        currentSessionType = sessionType
        currentEventNotes = slot.notes
        sessionStartTime = slot.startTime
        sessionEndTime = slot.endTime
        isBusySlotMode = isBusySlot
        busySlotCalendarColor = isBusySlot ? slot.calendarColor : nil
        busySlotCalendarName = isBusySlot ? slot.calendarName : nil

        let total = slot.endTime.timeIntervalSince(slot.startTime)
        elapsed = now.timeIntervalSince(slot.startTime)
        remaining = slot.endTime.timeIntervalSince(now)
        progress = total > 0 ? min(1.0, max(0.0, elapsed / total)) : 0

        let wasActiveBeforeThisTick = isActive
        isActive = true

        // Dismiss any pending feedback
        sessionFeedbackPending = nil
        feedbackDismissTimer?.invalidate()

        // Audio: start sound + ambient on new session
        if isNewSession && !wasActiveBeforeThisTick {
            lastPresenceReminderTime = nil
            hasPlayedEndingSoon = false
            playSessionStartAudio(sessionType: sessionType)
        }
    }

    private func clearActiveState() {
        isActive = false
        currentSessionTitle = ""
        currentSessionType = nil
        currentEventId = nil
        currentEventNotes = nil
        sessionStartTime = nil
        sessionEndTime = nil
        elapsed = 0
        remaining = 0
        progress = 0
        isBusySlotMode = false
        busySlotCalendarColor = nil
        busySlotCalendarName = nil
        lastPresenceReminderTime = nil
        hasPlayedEndingSoon = false
    }

    // MARK: - Session transitions

    private func triggerSessionEnd(eventId: String) {
        audioService?.stopAmbient()

        // Play end sound
        if config.endSound.sound != "Off" {
            audioService?.playTransition(config: config.endSound)
        }

        // Create feedback prompt from the session that just ended
        if let calendarService = calendarService,
           let slot = calendarService.busySlots.first(where: { $0.id == eventId }),
           CalendarService.sessionType(fromNotes: slot.notes) != nil {
            sessionFeedbackPending = SessionFeedback(
                eventId: slot.id,
                sessionTitle: slot.title,
                sessionType: CalendarService.sessionType(fromNotes: slot.notes),
                startTime: slot.startTime,
                endTime: slot.endTime
            )

            // Auto-dismiss feedback after 15 seconds
            feedbackDismissTimer?.invalidate()
            feedbackDismissTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.sessionFeedbackPending = nil
                }
            }
        }
    }

    private func playSessionStartAudio(sessionType: SessionType?) {
        guard let audioService = audioService else { return }

        // Play start transition sound
        if config.startSound.sound != "Off" {
            audioService.playTransition(config: config.startSound)
        }

        // Start ambient sound (delayed slightly if start sound is playing)
        let soundConfig: SessionSoundConfig
        if let type = sessionType {
            soundConfig = config.soundConfig(for: type)
        } else {
            soundConfig = config.otherEventsSound
        }

        if soundConfig.sound != "Off" {
            let delay: TimeInterval = config.startSound.sound != "Off" ? 3.0 : 0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                audioService.playAmbient(config: soundConfig)
            }
        }
    }

    // MARK: - Feedback actions

    func submitFeedback(rating: SessionRating) {
        guard let feedback = sessionFeedbackPending else { return }
        let entry = SessionFeedbackEntry(from: feedback, rating: rating)
        SessionFeedbackStore.shared.saveEntry(entry)
        feedbackDismissTimer?.invalidate()
        sessionFeedbackPending = nil
    }

    func dismissFeedback() {
        feedbackDismissTimer?.invalidate()
        sessionFeedbackPending = nil
    }

    // MARK: - Flash

    private func triggerFlash(_ type: FlashType) {
        flashTrigger = type
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.flashTrigger = nil
        }
    }
}
