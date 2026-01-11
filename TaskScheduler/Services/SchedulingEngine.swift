import Foundation
import SwiftUI

// MARK: - Scheduling Engine
/// Core scheduling algorithm ported from AppleScript
class SchedulingEngine: ObservableObject {
    // MARK: - Configuration
    // MARK: - Configuration
    @Published var workSessions: Int = 5 { didSet { saveState() } }
    @Published var sideSessions: Int = 2 { didSet { saveState() } }
    @Published var workSessionName: String = "Work Session" { didSet { saveState() } }
    @Published var sideSessionName: String = "Side Session" { didSet { saveState() } }
    @Published var workSessionDuration: Int = 40 { didSet { saveState() } }
    @Published var sideSessionDuration: Int = 30 { didSet { saveState() } }
    @Published var planningDuration: Int = 15 { didSet { saveState() } }
    @Published var restDuration: Int = 20 { didSet { saveState() } }
    @Published var schedulePlanning: Bool = true { didSet { saveState() } }
    @Published var pattern: SchedulePattern = .alternating { didSet { saveState() } }
    @Published var workSessionsPerCycle: Int = 2 { didSet { saveState() } }
    @Published var sideSessionsPerCycle: Int = 1 { didSet { saveState() } }
    @Published var sideFirst: Bool = false { didSet { saveState() } } // New
    @Published var workCalendarName: String = "Work" { didSet { saveState() } }
    @Published var sideCalendarName: String = "Side Tasks" { didSet { saveState() } }
    @Published var hideNightHours: Bool = UserDefaults.standard.object(forKey: "TaskScheduler.HideNightHours") as? Bool ?? true {
        didSet { UserDefaults.standard.set(hideNightHours, forKey: "TaskScheduler.HideNightHours") }
    }
    @Published var awareExistingTasks: Bool = UserDefaults.standard.object(forKey: "TaskScheduler.AwareExistingTasks") as? Bool ?? true {
        didSet { UserDefaults.standard.set(awareExistingTasks, forKey: "TaskScheduler.AwareExistingTasks") }
    }
    @Published var dayStartHour: Int = (UserDefaults.standard.object(forKey: "TaskScheduler.DayStartHour") as? Int) ?? 6 {
        didSet { UserDefaults.standard.set(dayStartHour, forKey: "TaskScheduler.DayStartHour") }
    }
    @Published var dayEndHour: Int = (UserDefaults.standard.object(forKey: "TaskScheduler.DayEndHour") as? Int) ?? 24 {
        didSet { UserDefaults.standard.set(dayEndHour, forKey: "TaskScheduler.DayEndHour") }
    }
    
    
    
    
    // Task lists and enablement
    @Published var workTasks: String = UserDefaults.standard.string(forKey: "TaskScheduler.WorkTasks") ?? "" {
        didSet { UserDefaults.standard.set(workTasks, forKey: "TaskScheduler.WorkTasks") }
    }
    @Published var sideTasks: String = UserDefaults.standard.string(forKey: "TaskScheduler.SideTasks") ?? "" {
        didSet { UserDefaults.standard.set(sideTasks, forKey: "TaskScheduler.SideTasks") }
    }
    @Published var deepTasks: String = UserDefaults.standard.string(forKey: "TaskScheduler.DeepTasks") ?? "" {
        didSet { UserDefaults.standard.set(deepTasks, forKey: "TaskScheduler.DeepTasks") }
    }
    @Published var useWorkTasks: Bool = UserDefaults.standard.bool(forKey: "TaskScheduler.UseWorkTasks") {
        didSet { UserDefaults.standard.set(useWorkTasks, forKey: "TaskScheduler.UseWorkTasks") }
    }
    @Published var useSideTasks: Bool = UserDefaults.standard.bool(forKey: "TaskScheduler.UseSideTasks") {
        didSet { UserDefaults.standard.set(useSideTasks, forKey: "TaskScheduler.UseSideTasks") }
    }
    @Published var useDeepTasks: Bool = UserDefaults.standard.bool(forKey: "TaskScheduler.UseDeepTasks") {
        didSet { UserDefaults.standard.set(useDeepTasks, forKey: "TaskScheduler.UseDeepTasks") }
    }
    
    @Published var sideRestDuration: Int = 15 { didSet { saveState() } }
    @Published var deepRestDuration: Int = 20 { didSet { saveState() } }
    
    @Published var deepSessionConfig: DeepSessionConfig = .default { didSet { saveState() } }

    // MARK: - State Tracking
    @Published var currentPresetId: UUID? {
        didSet {
             // Save the ID if it changes (though saveState covers the config, we might want to know which preset was "base")
             UserDefaults.standard.set(currentPresetId?.uuidString, forKey: "TaskScheduler.CurrentPresetId")
        }
    }
    
    // MARK: - Scheduling Settings
    private let existingEventBuffer: Int = 10 // minutes
    private let roundingInterval: Int = 5 // Changed to 5 minutes for better precision
    private let maxSchedulingHour: Int = 24
    
    // MARK: - Scheduled Output
    @Published var projectedSessions: [ScheduledSession] = []
    @Published var schedulingMessage: String = ""
    
    // MARK: - Initialization
    
    init() {
        loadState()
        
        // Load last preset ID if exists (though loadState should handle logic, we track the ID separately)
        if let idStr = UserDefaults.standard.string(forKey: "TaskScheduler.CurrentPresetId"),
           let id = UUID(uuidString: idStr) {
            self.currentPresetId = id
        }
    }
    
    // MARK: - Apply Preset
    
    func applyPreset(_ preset: Preset) {
        // Temporarily disable save to avoid multiple writes? optional.
        workSessions = preset.workSessionCount
        sideSessions = preset.sideSessionCount
        workSessionName = preset.workSessionName
        sideSessionName = preset.sideSessionName
        workSessionDuration = preset.workSessionDuration
        sideSessionDuration = preset.sideSessionDuration
        planningDuration = preset.planningDuration
        restDuration = preset.restDuration
        
        // New params
        sideRestDuration = preset.sideRestDuration
        deepRestDuration = preset.deepRestDuration
        sideSessionsPerCycle = preset.sideSessionsPerCycle
        deepSessionConfig = preset.deepSessionConfig
        sideFirst = preset.sideFirst
        
        schedulePlanning = preset.schedulePlanning
        pattern = preset.pattern
        workSessionsPerCycle = preset.workSessionsPerCycle
        workCalendarName = preset.calendarMapping.workCalendarName
        sideCalendarName = preset.calendarMapping.sideCalendarName
        
        
        currentPresetId = preset.id
        saveState()
    }
    
    // MARK: - Save as Preset
    
    func saveAsPreset(name: String, icon: String) -> Preset {
        return Preset(
            name: name,
            icon: icon,
            workSessionCount: workSessions,
            sideSessionCount: sideSessions,
            workSessionName: workSessionName,
            sideSessionName: sideSessionName,
            workSessionDuration: workSessionDuration,
            sideSessionDuration: sideSessionDuration,
            planningDuration: planningDuration,
            restDuration: restDuration,
            sideRestDuration: sideRestDuration,
            deepRestDuration: deepRestDuration,
            schedulePlanning: schedulePlanning,
            pattern: pattern,
            workSessionsPerCycle: workSessionsPerCycle,
            sideSessionsPerCycle: sideSessionsPerCycle,
            sideFirst: sideFirst,
            deepSessionConfig: deepSessionConfig,
            calendarMapping: CalendarMapping(
                workCalendarName: workCalendarName,
                sideCalendarName: sideCalendarName
            )
        )
    }
    

    // MARK: - Core Scheduling Algorithm
    
    func generateSchedule(
        startTime: Date,
        baseDate: Date,
        busySlots: [BusyTimeSlot],
        includePlanning: Bool,
        existingSessions: (work: Int, side: Int, deep: Int)? = nil,
        existingTitles: Set<String>? = nil
    ) -> [ScheduledSession] {
        var sessions: [ScheduledSession] = []
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: baseDate)
        let endOfDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: baseDate)!)
        
        let roundedStart = roundToNextInterval(startTime)
        var currentTime = max(roundedStart, startOfDay)
        
        let bufferDuration = TimeInterval(existingEventBuffer * 60)
        var planningNeeded = includePlanning && schedulePlanning
        
        // Generate session order based on pattern
        let sessionOrder = SessionOrderGenerator(
            pattern: pattern,
            workSessions: workSessions,
            sideSessions: sideSessions,
            workSessionsPerCycle: workSessionsPerCycle,
            sideSessionsPerCycle: sideSessionsPerCycle,
            sideFirst: sideFirst
        ).generateOrder()
        
        var sessionIndex = 0
        var workCount = 0
        var sideCount = 0
        var deepCount = 0
        var regularSessionsScheduled = 0
        
        if awareExistingTasks, let existing = existingSessions {
            workCount = existing.work
            sideCount = existing.side
            deepCount = existing.deep
            regularSessionsScheduled = workCount + sideCount
        }
        
        var attempts = 0
        let maxAttempts = 500
        
        // Prepare task titles
        var workTitles = workTasks.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var sideTitles = sideTasks.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var deepTitles = deepTasks.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        // Smart allocation: Remove titles that already exist on the calendar today
        if let existing = existingTitles {
            workTitles = workTitles.filter { !existing.contains($0) }
            sideTitles = sideTitles.filter { !existing.contains($0) }
            deepTitles = deepTitles.filter { !existing.contains($0) }
        }
        
        var projectedWorkCount = 0
        var projectedSideCount = 0
        var projectedDeepCount = 0
        
        while (workCount < workSessions || sideCount < sideSessions || planningNeeded || (deepSessionConfig.enabled && deepCount < deepSessionConfig.sessionCount)) && attempts < maxAttempts {
            attempts += 1
            
            if currentTime >= endOfDay {
                schedulingMessage = "Reached end of day."
                break
            }
            
            var sessionType: SessionType
            var sessionDuration: Int
            var sessionTitle: String
            var calendarName: String
            var sessionTag: String
            var isDeep = false
            
            if planningNeeded {
                sessionType = .planning
                sessionDuration = planningDuration
                sessionTitle = "Planning"
                calendarName = workCalendarName
                sessionTag = "#plan"
            } else {
                let shouldInjectDeep = deepSessionConfig.enabled
                    && deepCount < deepSessionConfig.sessionCount
                    && regularSessionsScheduled > 0
                
                let sessionsSinceLastDeep = regularSessionsScheduled - (deepCount * deepSessionConfig.injectAfterEvery)
                 
                if shouldInjectDeep && sessionsSinceLastDeep >= deepSessionConfig.injectAfterEvery {
                     sessionType = .deep
                     sessionDuration = deepSessionConfig.duration
                     
                     if useDeepTasks && deepCount < deepTitles.count {
                         sessionTitle = deepTitles[deepCount]
                     } else {
                         sessionTitle = deepSessionConfig.name
                     }
                     
                     calendarName = deepSessionConfig.calendarName
                     sessionTag = "#deep"
                     isDeep = true
                 } else if sessionIndex < sessionOrder.count {
                    let proposedType = sessionOrder[sessionIndex]
                    
                    if (proposedType == .work && workCount >= workSessions) ||
                       (proposedType == .side && sideCount >= sideSessions) {
                        sessionIndex += 1
                        continue
                    }
                    
                    sessionType = proposedType
                    switch sessionType {
                    case .work:
                        sessionDuration = workSessionDuration
                        sessionTitle = (useWorkTasks && projectedWorkCount < workTitles.count) ? workTitles[projectedWorkCount] : workSessionName
                        calendarName = workCalendarName
                        sessionTag = "#work"
                    case .side:
                        sessionDuration = sideSessionDuration
                        sessionTitle = (useSideTasks && projectedSideCount < sideTitles.count) ? sideTitles[projectedSideCount] : sideSessionName
                        calendarName = sideCalendarName
                        sessionTag = "#side"
                    case .planning, .deep:
                         sessionDuration = workSessionDuration
                         sessionTitle = "Unknown"
                         calendarName = workCalendarName
                         sessionTag = ""
                    }
                } else {
                    if workCount < workSessions {
                        sessionType = .work
                        sessionDuration = workSessionDuration
                        sessionTitle = (useWorkTasks && projectedWorkCount < workTitles.count) ? workTitles[projectedWorkCount] : workSessionName
                        calendarName = workCalendarName
                        sessionTag = "#work"
                    } else if sideCount < sideSessions {
                        sessionType = .side
                        sessionDuration = sideSessionDuration
                        sessionTitle = (useSideTasks && projectedSideCount < sideTitles.count) ? sideTitles[projectedSideCount] : sideSessionName
                        calendarName = sideCalendarName
                        sessionTag = "#side"
                    } else if deepSessionConfig.enabled && deepCount < deepSessionConfig.sessionCount {
                         sessionType = .deep
                         sessionDuration = deepSessionConfig.duration
                         sessionTitle = (useDeepTasks && projectedDeepCount < deepTitles.count) ? deepTitles[projectedDeepCount] : deepSessionConfig.name
                         calendarName = deepSessionConfig.calendarName
                         sessionTag = "#deep"
                         isDeep = true
                    } else {
                        break
                    }
                }
            }
            
            let potentialEnd = currentTime.addingTimeInterval(TimeInterval(sessionDuration * 60))
            
            if potentialEnd > endOfDay {
                schedulingMessage = "Cannot fit remaining sessions."
                break
            }
            
            let conflict = findConflict(start: currentTime, end: potentialEnd, busySlots: busySlots, buffer: bufferDuration)
            
            if let conflictEnd = conflict {
                if !planningNeeded && !isDeep {
                    if let alt = tryAlternativeSession(
                        currentTime: currentTime,
                        conflictEnd: conflictEnd,
                        currentType: sessionType,
                        workCount: workCount,
                        sideCount: sideCount,
                        busySlots: busySlots,
                        buffer: bufferDuration,
                        endOfDay: endOfDay,
                        workTitles: workTitles,
                        sideTitles: sideTitles,
                        projectedWorkCount: projectedWorkCount,
                        projectedSideCount: projectedSideCount
                    ) {
                        sessions.append(alt)
                        if alt.type == .work {
                            workCount += 1
                            projectedWorkCount += 1
                        } else {
                            sideCount += 1
                            projectedSideCount += 1
                        }
                        regularSessionsScheduled += 1
                        let appliedRest = alt.type == .side ? sideRestDuration : restDuration
                        currentTime = roundToNextInterval(alt.endTime.addingTimeInterval(TimeInterval(appliedRest * 60)))
                        continue
                    }
                }
                currentTime = roundToNextInterval(conflictEnd)
                continue
            }
            
            let session = ScheduledSession(
                type: sessionType,
                title: sessionTitle,
                startTime: currentTime,
                endTime: potentialEnd,
                calendarName: calendarName,
                notes: sessionTag
            )
            sessions.append(session)
            
            var appliedRest = restDuration
            
            if planningNeeded {
                planningNeeded = false
                appliedRest = max(5, restDuration / 2)
            } else if isDeep {
                deepCount += 1
                projectedDeepCount += 1
                appliedRest = deepRestDuration
            } else {
                switch sessionType {
                case .work:
                    workCount += 1
                    projectedWorkCount += 1
                    regularSessionsScheduled += 1
                    appliedRest = restDuration
                case .side:
                    sideCount += 1
                    projectedSideCount += 1
                    regularSessionsScheduled += 1
                    appliedRest = sideRestDuration
                default: break
                }
                sessionIndex += 1
            }
            
            currentTime = roundToNextInterval(potentialEnd.addingTimeInterval(TimeInterval(appliedRest * 60)))
        }
        
        projectedSessions = sessions
        
        var existingNote = ""
        if awareExistingTasks, let existing = existingSessions {
            let total = existing.work + existing.side + existing.deep
            if total > 0 {
                existingNote = " (Found \(total) existing sessions)"
            }
        }

        if sessions.isEmpty {
            if awareExistingTasks && workCount >= workSessions && sideCount >= sideSessions {
                schedulingMessage = "Daily quota met by existing sessions." + existingNote
            } else {
                schedulingMessage = "No suitable time slots found or quota already met." + existingNote
            }
        } else if workCount < workSessions || sideCount < sideSessions {
            schedulingMessage = "Projected \(sessions.count) sessions. Quota not met." + existingNote
        } else {
            schedulingMessage = "Successfully projected \(sessions.count) sessions." + existingNote
        }
        
        return sessions
    }
    
    // MARK: - Try Alternative Session
    
    /// Tries to fit a different session type in a gap that's too small for the preferred type
    private func tryAlternativeSession(
        currentTime: Date,
        conflictEnd: Date,
        currentType: SessionType,
        workCount: Int,
        sideCount: Int,
        busySlots: [BusyTimeSlot],
        buffer: TimeInterval,
        endOfDay: Date,
        workTitles: [String],
        sideTitles: [String],
        projectedWorkCount: Int,
        projectedSideCount: Int
    ) -> ScheduledSession? {
        // If we can't fit a work session, try side (and vice versa)
        let alternativeType: SessionType
        let alternativeDuration: Int
        let alternativeTitle: String
        let alternativeCalendar: String
        
        if currentType == .work && sideCount < sideSessions {
            alternativeType = .side
            alternativeDuration = sideSessionDuration
            alternativeCalendar = sideCalendarName
            alternativeTitle = (useSideTasks && projectedSideCount < sideTitles.count) ? sideTitles[projectedSideCount] : sideSessionName
        } else if currentType == .side && workCount < workSessions {
            alternativeType = .work
            alternativeDuration = workSessionDuration
            alternativeCalendar = workCalendarName
            alternativeTitle = (useWorkTasks && projectedWorkCount < workTitles.count) ? workTitles[projectedWorkCount] : workSessionName
        } else {
            return nil
        }
        
        let potentialEnd = currentTime.addingTimeInterval(TimeInterval(alternativeDuration * 60))
        
        // Check if fits before day end
        if potentialEnd > endOfDay {
            return nil
        }
        
        // Check for conflicts
        let conflict = findConflict(
            start: currentTime,
            end: potentialEnd,
            busySlots: busySlots,
            buffer: buffer
        )
        
        if conflict == nil {
            return ScheduledSession(
                type: alternativeType,
                title: alternativeTitle,
                startTime: currentTime,
                endTime: potentialEnd,
                calendarName: alternativeCalendar,
                notes: alternativeType == .work ? "#work" : "#side"
            )
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    /// Rounds the given date UP to the next interval boundary (e.g., 15-minute mark)
    private func roundToNextInterval(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minutes = components.minute ?? 0
        
        let remainder = minutes % roundingInterval
        
        // If already on an interval boundary, return as-is
        if remainder == 0 {
            // Create a clean date without seconds
            var cleanComponents = components
            cleanComponents.second = 0
            return calendar.date(from: cleanComponents) ?? date
        }
        
        // Otherwise, round up to next interval
        let minutesToAdd = roundingInterval - remainder
        
        return calendar.date(byAdding: .minute, value: minutesToAdd, to: date) ?? date
    }
    
    // MARK: - Single Session Projection
    
    func projectSingleSession(
        type: SessionType,
        startTime: Date,
        baseDate: Date,
        busySlots: [BusyTimeSlot]
    ) -> ScheduledSession? {
        let calendar = Calendar.current
        let endOfDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: baseDate)!)
        let bufferDuration = TimeInterval(existingEventBuffer * 60)
        
        var currentTime = roundToNextInterval(startTime)
        let sessionDuration: Int
        switch type {
        case .work: sessionDuration = workSessionDuration
        case .side: sessionDuration = sideSessionDuration
        case .planning: sessionDuration = planningDuration
        case .deep: sessionDuration = deepSessionConfig.duration
        }

        var attempts = 0
        let maxAttempts = 100
        
        while attempts < maxAttempts {
            attempts += 1
            
            if currentTime >= endOfDay {
                return nil
            }
            
            let potentialEnd = currentTime.addingTimeInterval(TimeInterval(sessionDuration * 60))
            
            if potentialEnd > endOfDay {
                return nil
            }
            
            let conflict = findConflict(
                start: currentTime,
                end: potentialEnd,
                busySlots: busySlots,
                buffer: bufferDuration
            )
            
            if let conflictEnd = conflict {
                currentTime = roundToNextInterval(conflictEnd)
                continue
            }
            
            // Found a slot
            return ScheduledSession(
                type: type,
                title: type == .planning ? "Planning" : type.rawValue + " Session",
                startTime: currentTime,
                endTime: potentialEnd,
                calendarName: workCalendarName,
                notes: type == .work ? "#work" : (type == .side ? "#side" : (type == .planning ? "#plan" : "#deep"))
            )
        }
        
        return nil
    }
    
    private func findConflict(
        start: Date,
        end: Date,
        busySlots: [BusyTimeSlot],
        buffer: TimeInterval
    ) -> Date? {
        for slot in busySlots {
            let effectiveStart = slot.startTime.addingTimeInterval(-buffer)
            let effectiveEnd = slot.endTime.addingTimeInterval(buffer)
            
            // Check for overlap
            if start < effectiveEnd && end > effectiveStart {
                return effectiveEnd
            }
        }
        return nil
    }
    
    // MARK: - Availability Stats
    
    func calculateAvailability(
        startTime: Date,
        baseDate: Date,
        busySlots: [BusyTimeSlot]
    ) -> (availableMinutes: Int, possibleWorkSessions: Int, possibleSideSessions: Int, possibleDeepSessions: Int) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: baseDate)
        let endOfDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: baseDate)!)
        
        let effectiveStart = max(startTime, startOfDay)
        
        var totalAvailable = 0
        var currentTime = effectiveStart
        let bufferDuration = TimeInterval(existingEventBuffer * 60)
        
        // Sort busy slots by start time
        let sortedSlots = busySlots.sorted { $0.startTime < $1.startTime }
        
        for slot in sortedSlots {
            let effectiveStart = slot.startTime.addingTimeInterval(-bufferDuration)
            
            if currentTime < effectiveStart && effectiveStart < endOfDay {
                let gapMinutes = Int(effectiveStart.timeIntervalSince(currentTime) / 60)
                totalAvailable += max(0, gapMinutes)
            }
            
            let effectiveEnd = slot.endTime.addingTimeInterval(bufferDuration)
            if effectiveEnd > currentTime {
                currentTime = effectiveEnd
            }
        }
        
        // Add remaining time until end of day
        if currentTime < endOfDay {
            let remainingMinutes = Int(endOfDay.timeIntervalSince(currentTime) / 60)
            totalAvailable += max(0, remainingMinutes)
        }
        
        // Calculate possible sessions (with rest between)
        let workWithRest = workSessionDuration + restDuration
        let sideWithRest = sideSessionDuration + restDuration
        let deepWithRest = deepSessionConfig.duration + deepRestDuration
        
        let possibleWork = totalAvailable / max(1, workWithRest)
        let possibleSide = totalAvailable / max(1, sideWithRest)
        let possibleDeep = totalAvailable / max(1, deepWithRest)
        
        return (totalAvailable, possibleWork, possibleSide, possibleDeep)
    }
    
    // MARK: - State Persistence
    
    private var isLoadingState = false
    
    private func saveState() {
        guard !isLoadingState else { return }
        
        let state = Preset(
            id: UUID(), // Dummy ID
            name: "Current State", // Dummy Name
            icon: "gear", // Dummy Icon
            workSessionCount: workSessions,
            sideSessionCount: sideSessions,
            workSessionName: workSessionName,
            sideSessionName: sideSessionName,
            workSessionDuration: workSessionDuration,
            sideSessionDuration: sideSessionDuration,
            planningDuration: planningDuration,
            restDuration: restDuration,
            sideRestDuration: sideRestDuration,
            deepRestDuration: deepRestDuration,
            schedulePlanning: schedulePlanning,
            pattern: pattern,
            workSessionsPerCycle: workSessionsPerCycle,
            sideSessionsPerCycle: sideSessionsPerCycle,
            sideFirst: sideFirst,
            deepSessionConfig: deepSessionConfig,
            calendarMapping: CalendarMapping(
                workCalendarName: workCalendarName,
                sideCalendarName: sideCalendarName
            )
        )
        
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: "TaskScheduler.SavedState")
        }
    }
    
    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: "TaskScheduler.SavedState"),
              let state = try? JSONDecoder().decode(Preset.self, from: data) else {
            return
        }
        
        isLoadingState = true
        defer { isLoadingState = false }
        
        workSessions = state.workSessionCount
        sideSessions = state.sideSessionCount
        workSessionName = state.workSessionName
        sideSessionName = state.sideSessionName
        workSessionDuration = state.workSessionDuration
        sideSessionDuration = state.sideSessionDuration
        planningDuration = state.planningDuration
        restDuration = state.restDuration
        sideRestDuration = state.sideRestDuration
        deepRestDuration = state.deepRestDuration
        schedulePlanning = state.schedulePlanning
        pattern = state.pattern
        workSessionsPerCycle = state.workSessionsPerCycle
        sideSessionsPerCycle = state.sideSessionsPerCycle
        sideFirst = state.sideFirst
        deepSessionConfig = state.deepSessionConfig
        workCalendarName = state.calendarMapping.workCalendarName
        sideCalendarName = state.calendarMapping.sideCalendarName
    }
    
    func isPresetModified(_ preset: Preset) -> Bool {
        return workSessions != preset.workSessionCount ||
               sideSessions != preset.sideSessionCount ||
               workSessionName != preset.workSessionName ||
               sideSessionName != preset.sideSessionName ||
               workSessionDuration != preset.workSessionDuration ||
               sideSessionDuration != preset.sideSessionDuration ||
               planningDuration != preset.planningDuration ||
               restDuration != preset.restDuration ||
               sideRestDuration != preset.sideRestDuration ||
               deepRestDuration != preset.deepRestDuration ||
               schedulePlanning != preset.schedulePlanning ||
               pattern != preset.pattern ||
               workSessionsPerCycle != preset.workSessionsPerCycle ||
               sideSessionsPerCycle != preset.sideSessionsPerCycle ||
               sideFirst != preset.sideFirst ||
               deepSessionConfig != preset.deepSessionConfig ||
               workCalendarName != preset.calendarMapping.workCalendarName ||
               sideCalendarName != preset.calendarMapping.sideCalendarName
    }
}
