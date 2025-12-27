import Foundation
import EventKit
import SwiftUI

// MARK: - Calendar Service
/// Manages all interactions with macOS Calendar via EventKit
class CalendarService: ObservableObject {
    private let eventStore = EKEventStore()
    private var notificationObserver: NSObjectProtocol?
    
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var availableCalendars: [EKCalendar] = []
    @Published var busySlots: [BusyTimeSlot] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastRefresh: Date = Date()
    
    // Store the current date for auto-refresh
    private var currentFetchDate: Date?
    
    init() {
        checkAuthorizationStatus()
        setupNotificationObserver()
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Notification Observer
    
    private func setupNotificationObserver() {
        // Listen for calendar changes
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, let date = self.currentFetchDate else { return }
            // Refresh events when calendar changes
            Task {
                await self.fetchEvents(for: date)
            }
        }
    }
    
    // MARK: - Authorization
    
    func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if authorizationStatus == .fullAccess {
            loadCalendars()
        }
    }
    
    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(macOS 14.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await eventStore.requestAccess(to: .event)
            }
            
            await MainActor.run {
                self.authorizationStatus = granted ? .fullAccess : .denied
                if granted {
                    self.loadCalendars()
                }
            }
            return granted
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to request calendar access: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // MARK: - Calendar Loading
    
    func loadCalendars() {
        availableCalendars = eventStore.calendars(for: .event).filter { calendar in
            calendar.type != .birthday && calendar.allowsContentModifications
        }
    }
    
    func getCalendar(named name: String) -> EKCalendar? {
        return availableCalendars.first { $0.title == name }
    }
    
    func calendarNames() -> [String] {
        return availableCalendars.map { $0.title }
    }
    
    // MARK: - Event Fetching
    
    func fetchEvents(for date: Date) async {
        await MainActor.run {
            self.isLoading = true
            self.currentFetchDate = date
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        // Filter out all-day events (duration >= 23 hours)
        let nearAlldayThreshold: TimeInterval = 23 * 60 * 60
        let timedEvents = events.filter { event in
            let duration = event.endDate.timeIntervalSince(event.startDate)
            return duration < nearAlldayThreshold && !event.isAllDay
        }
        
        let slots = timedEvents.map { BusyTimeSlot(from: $0) }
        
        await MainActor.run {
            self.busySlots = slots
            self.isLoading = false
            self.lastRefresh = Date()
        }
    }
    
    // MARK: - Event Creation
    
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        calendarName: String
    ) -> Bool {
        guard let calendar = getCalendar(named: calendarName) else {
            errorMessage = "Calendar '\(calendarName)' not found"
            return false
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            errorMessage = "Failed to create event: \(error.localizedDescription)"
            return false
        }
    }
    
    func createSessions(_ sessions: [ScheduledSession]) -> (success: Int, failed: Int) {
        var successCount = 0
        var failCount = 0
        
        for session in sessions {
            if createEvent(
                title: session.title,
                startDate: session.startTime,
                endDate: session.endTime,
                calendarName: session.calendarName
            ) {
                successCount += 1
            } else {
                failCount += 1
            }
        }
        
        return (successCount, failCount)
    }
    
    // MARK: - Check for Existing Planning Session
    
    func hasPlanningSession(for date: Date, planningEventName: String = "Planning") -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return false }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        return events.contains { $0.title == planningEventName }
    }
    
    // MARK: - Delete Events
    
    /// Deletes all events from specified calendars for a given date
    func deleteEvents(for date: Date, fromCalendars calendarNames: [String]) -> (deleted: Int, failed: Int) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return (0, 0)
        }
        
        // Get the calendars to delete from
        let calendarsToDelete = availableCalendars.filter { calendarNames.contains($0.title) }
        
        guard !calendarsToDelete.isEmpty else {
            errorMessage = "No matching calendars found for deletion"
            return (0, 0)
        }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendarsToDelete)
        let events = eventStore.events(matching: predicate)
        
        var deletedCount = 0
        var failedCount = 0
        
        for event in events {
            do {
                try eventStore.remove(event, span: .thisEvent)
                deletedCount += 1
            } catch {
                failedCount += 1
            }
        }
        
        return (deletedCount, failedCount)
    }
    
    /// Deletes specific events or all events from specified calendars
    func deleteSessionEvents(for date: Date, sessionNames: [String]? = nil, fromCalendars calendarNames: [String]) -> (deleted: Int, failed: Int) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return (0, 0)
        }
        
        let calendarsToDelete = availableCalendars.filter { calendarNames.contains($0.title) }
        
        guard !calendarsToDelete.isEmpty else {
            return (0, 0)
        }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendarsToDelete)
        let events = eventStore.events(matching: predicate)
        
        // Filter: match session names if provided, otherwise delete all
        let sessionsToDelete = events.filter { event in
            guard let title = event.title else { return false }
            if let names = sessionNames, !names.isEmpty {
                return names.contains(title)
            }
            return true
        }
        
        var deletedCount = 0
        var failedCount = 0
        
        for event in sessionsToDelete {
            do {
                try eventStore.remove(event, span: .thisEvent)
                deletedCount += 1
            } catch {
                failedCount += 1
            }
        }
        
        return (deletedCount, failedCount)
    }
    
    /// Deletes specific future events or all future events from specified calendars
    func deleteFutureSessionEvents(for date: Date, after cutoffTime: Date, sessionNames: [String]? = nil, fromCalendars calendarNames: [String]) -> (deleted: Int, failed: Int) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return (0, 0)
        }
        
        let calendarsToDelete = availableCalendars.filter { calendarNames.contains($0.title) }
        
        guard !calendarsToDelete.isEmpty else {
            return (0, 0)
        }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendarsToDelete)
        let events = eventStore.events(matching: predicate)
        
        // Filter: match session names if provided (AND check cutoff), otherwise just check cutoff
        let sessionsToDelete = events.filter { event in
            guard event.startDate >= cutoffTime else { return false }
            
            if let names = sessionNames, !names.isEmpty, let title = event.title {
                return names.contains(title)
            }
            return true
        }
        
        var deletedCount = 0
        var failedCount = 0
        
        for event in sessionsToDelete {
            do {
                try eventStore.remove(event, span: .thisEvent)
                deletedCount += 1
            } catch {
                failedCount += 1
            }
        }
        
        return (deletedCount, failedCount)
    }
}
