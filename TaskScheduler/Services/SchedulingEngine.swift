import Foundation
import SwiftUI

// MARK: - Scheduling Engine
/// Core scheduling algorithm ported from AppleScript
class SchedulingEngine: ObservableObject {
    // MARK: - Configuration
    @Published var workSessions: Int = 5
    @Published var sideSessions: Int = 2
    @Published var workSessionName: String = "Work Session"
    @Published var sideSessionName: String = "Side Session"
    @Published var workSessionDuration: Int = 40
    @Published var sideSessionDuration: Int = 30
    @Published var planningDuration: Int = 15
    @Published var restDuration: Int = 20
    @Published var schedulePlanning: Bool = true
    @Published var pattern: SchedulePattern = .alternating
    @Published var workSessionsPerCycle: Int = 2
    @Published var sideSessionsPerCycle: Int = 1
    @Published var sideFirst: Bool = false // New
    @Published var workCalendarName: String = "Work"
    @Published var sideCalendarName: String = "Side Tasks"
    
    // Task lists and enablement
    @Published var workTasks: String = UserDefaults.standard.string(forKey: "TaskScheduler.WorkTasks") ?? "" {
        didSet { UserDefaults.standard.set(workTasks, forKey: "TaskScheduler.WorkTasks") }
    }
    @Published var sideTasks: String = UserDefaults.standard.string(forKey: "TaskScheduler.SideTasks") ?? "" {
        didSet { UserDefaults.standard.set(sideTasks, forKey: "TaskScheduler.SideTasks") }
    }
    @Published var extraTasks: String = UserDefaults.standard.string(forKey: "TaskScheduler.ExtraTasks") ?? "" {
        didSet { UserDefaults.standard.set(extraTasks, forKey: "TaskScheduler.ExtraTasks") }
    }
    @Published var useWorkTasks: Bool = UserDefaults.standard.bool(forKey: "TaskScheduler.UseWorkTasks") {
        didSet { UserDefaults.standard.set(useWorkTasks, forKey: "TaskScheduler.UseWorkTasks") }
    }
    @Published var useSideTasks: Bool = UserDefaults.standard.bool(forKey: "TaskScheduler.UseSideTasks") {
        didSet { UserDefaults.standard.set(useSideTasks, forKey: "TaskScheduler.UseSideTasks") }
    }
    @Published var useExtraTasks: Bool = UserDefaults.standard.bool(forKey: "TaskScheduler.UseExtraTasks") {
        didSet { UserDefaults.standard.set(useExtraTasks, forKey: "TaskScheduler.UseExtraTasks") }
    }
    
    // New Rest Durations
    @Published var sideRestDuration: Int = 15 // Default 75% of 20
    @Published var extraRestDuration: Int = 20
    
    // Extra Sessions
    @Published var extraSessionConfig: ExtraSessionConfig = .default
    
    // MARK: - Scheduling Settings
    private let existingEventBuffer: Int = 10 // minutes
    private let roundingInterval: Int = 5 // Changed to 5 minutes for better precision
    private let maxSchedulingHour: Int = 24
    
    // MARK: - Scheduled Output
    @Published var projectedSessions: [ScheduledSession] = []
    @Published var schedulingMessage: String = ""
    
    // MARK: - Apply Preset
    
    func applyPreset(_ preset: Preset) {
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
        extraRestDuration = preset.extraRestDuration
        sideSessionsPerCycle = preset.sideSessionsPerCycle
        extraSessionConfig = preset.extraSessionConfig
        sideFirst = preset.sideFirst
        
        schedulePlanning = preset.schedulePlanning
        pattern = preset.pattern
        workSessionsPerCycle = preset.workSessionsPerCycle
        workCalendarName = preset.calendarMapping.workCalendarName
        sideCalendarName = preset.calendarMapping.sideCalendarName
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
            extraRestDuration: extraRestDuration,
            schedulePlanning: schedulePlanning,
            pattern: pattern,
            workSessionsPerCycle: workSessionsPerCycle,
            sideSessionsPerCycle: sideSessionsPerCycle,
            sideFirst: sideFirst,
            extraSessionConfig: extraSessionConfig,
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
        includePlanning: Bool
    ) -> [ScheduledSession] {
        var sessions: [ScheduledSession] = []
        var currentTime = roundToNextInterval(startTime)
        
        let calendar = Calendar.current
        let endOfDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: baseDate)!)
        
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
        var extraCount = 0
        var regularSessionsScheduled = 0 // Tracks Work + Side specifically for injection logic
        
        var attempts = 0
        let maxAttempts = 500
        
        // Prepare task titles
        let workTitles = workTasks.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let sideTitles = sideTasks.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let extraTitles = extraTasks.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        while (workCount < workSessions || sideCount < sideSessions || planningNeeded || (extraSessionConfig.enabled && extraCount < extraSessionConfig.sessionCount)) && attempts < maxAttempts {
            attempts += 1
            
            if currentTime >= endOfDay {
                schedulingMessage = "Reached end of day before all sessions could be scheduled."
                break
            }
            
            // Determine what to schedule next
            var sessionType: SessionType
            var sessionDuration: Int
            var sessionTitle: String
            var calendarName: String
            var isExtra = false
            
            if planningNeeded {
                sessionType = .planning
                sessionDuration = planningDuration
                sessionTitle = "Planning"
                calendarName = workCalendarName
            } else {
                // Check if we should inject an extra session
                // Logic: Inject after every N regular sessions
                let shouldInjectExtra = extraSessionConfig.enabled
                    && extraCount < extraSessionConfig.sessionCount
                    && regularSessionsScheduled > 0
                    && regularSessionsScheduled % extraSessionConfig.injectAfterEvery == 0
                    // Ensure we don't inject immediately again if we just did (though loop structure normally handles this if we track properly)
                    // We need to verify if the LAST scheduled session was NOT an extra session (to avoid double tap if logic allows)
                    // But regularSessionsScheduled only increments on regular sessions, so this condition holds until next regular session
                
                // However, we must ensure we haven't ALREADY acted on this specific regular count milestone.
                // E.g. at 3, we inject. loop continues. at 3 again? No, because we need to NOT increment regular count.
                // We need to track if we just injected for this milestone.
                // A simpler way: 'sessionsSinceLastExtra'.
                
                // Let's refactor injection trigger:
                let sessionsSinceStartOrLastExtra = regularSessionsScheduled - (extraCount * extraSessionConfig.injectAfterEvery)
                 
                if shouldInjectExtra && sessionsSinceStartOrLastExtra >= extraSessionConfig.injectAfterEvery {
                     sessionType = .extra
                     sessionDuration = extraSessionConfig.duration
                     
                     if useExtraTasks && extraCount < extraTitles.count {
                         sessionTitle = extraTitles[extraCount]
                     } else {
                         sessionTitle = extraSessionConfig.name
                     }
                     
                     calendarName = extraSessionConfig.calendarName
                     isExtra = true
                 } else if sessionIndex < sessionOrder.count {
                    // Standard pattern logic
                    // Check if we've already met the quota for this projected type
                    var proposedType = sessionOrder[sessionIndex]
                    
                    // If we already have enough of the proposed type, try to skip to next
                    if (proposedType == .work && workCount >= workSessions) ||
                       (proposedType == .side && sideCount >= sideSessions) {
                        sessionIndex += 1
                        continue
                    }
                    
                    sessionType = proposedType
                    switch sessionType {
                    case .work:
                        sessionDuration = workSessionDuration
                        if useWorkTasks && workCount < workTitles.count {
                            sessionTitle = workTitles[workCount]
                        } else {
                            sessionTitle = workSessionName
                        }
                        calendarName = workCalendarName
                    case .side:
                        sessionDuration = sideSessionDuration
                        if useSideTasks && sideCount < sideTitles.count {
                            sessionTitle = sideTitles[sideCount]
                        } else {
                            sessionTitle = sideSessionName
                        }
                        calendarName = sideCalendarName
                    case .planning, .extra:
                         // Should not happen in pattern
                         sessionDuration = workSessionDuration
                         sessionTitle = "Unknown"
                         calendarName = workCalendarName
                    }
                } else {
                    // Try to schedule remaining sessions (if pattern exhausted but counts not met)
                    if workCount < workSessions {
                        sessionType = .work
                        sessionDuration = workSessionDuration
                        if useWorkTasks && workCount < workTitles.count {
                            sessionTitle = workTitles[workCount]
                        } else {
                            sessionTitle = workSessionName
                        }
                        calendarName = workCalendarName
                    } else if sideCount < sideSessions {
                        sessionType = .side
                        sessionDuration = sideSessionDuration
                        if useSideTasks && sideCount < sideTitles.count {
                            sessionTitle = sideTitles[sideCount]
                        } else {
                            sessionTitle = sideSessionName
                        }
                        calendarName = sideCalendarName
                    } else if extraSessionConfig.enabled && extraCount < extraSessionConfig.sessionCount {
                        // Remaining extras?
                         sessionType = .extra
                         sessionDuration = extraSessionConfig.duration
                         if useExtraTasks && extraCount < extraTitles.count {
                             sessionTitle = extraTitles[extraCount]
                         } else {
                             sessionTitle = extraSessionConfig.name
                         }
                         calendarName = extraSessionConfig.calendarName
                         isExtra = true
                    } else {
                        break // Done
                    }
                }
            }
            
            let potentialEnd = currentTime.addingTimeInterval(TimeInterval(sessionDuration * 60))
            
            // Check if session exceeds day boundary
            if potentialEnd > endOfDay {
                schedulingMessage = "Cannot fit remaining sessions before end of day."
                break
            }
            
            // Check for conflicts
            let conflict = findConflict(
                start: currentTime,
                end: potentialEnd,
                busySlots: busySlots,
                buffer: bufferDuration
            )
            
            if let conflictEnd = conflict {
                // Try alternative fitting (only for regular sessions)
                if !planningNeeded && !isExtra {
                    let alternativeSession = tryAlternativeSession(
                        currentTime: currentTime,
                        conflictEnd: conflictEnd,
                        currentType: sessionType,
                        workCount: workCount,
                        sideCount: sideCount,
                        busySlots: busySlots,
                        buffer: bufferDuration,
                        endOfDay: endOfDay
                    )
                    
                    if let alt = alternativeSession {
                        sessions.append(alt)
                        if alt.type == .work {
                            workCount += 1
                        } else {
                            sideCount += 1
                        }
                        regularSessionsScheduled += 1
                        
                        // Add rest
                        var appliedRest = restDuration
                        if alt.type == .side { appliedRest = sideRestDuration }
                        
                        currentTime = alt.endTime.addingTimeInterval(TimeInterval(appliedRest * 60))
                        currentTime = roundToNextInterval(currentTime)
                        
                        continue
                    }
                }
                
                currentTime = roundToNextInterval(conflictEnd)
                continue
            }
            
            // Schedule the session
            let session = ScheduledSession(
                type: sessionType,
                title: sessionTitle,
                startTime: currentTime,
                endTime: potentialEnd,
                calendarName: calendarName
            )
            sessions.append(session)
            
            // Update counters and apply specific rest
            var appliedRest = restDuration // Default
            
            if planningNeeded {
                planningNeeded = false
                appliedRest = max(5, restDuration / 2)
            } else if isExtra {
                extraCount += 1
                appliedRest = extraRestDuration
            } else {
                switch sessionType {
                case .work:
                    workCount += 1
                    regularSessionsScheduled += 1
                    appliedRest = restDuration
                case .side:
                    sideCount += 1
                    regularSessionsScheduled += 1
                    appliedRest = sideRestDuration
                default: break
                }
                sessionIndex += 1
            }
            
            currentTime = potentialEnd.addingTimeInterval(TimeInterval(appliedRest * 60))
            
            currentTime = roundToNextInterval(currentTime)
        }
        
        projectedSessions = sessions
        
        if sessions.isEmpty {
            schedulingMessage = "Could not find any suitable time slots."
        } else if workCount < workSessions || sideCount < sideSessions {
            schedulingMessage = "Scheduled \(sessions.count) sessions. Some sessions couldn't be placed."
        } else {
            schedulingMessage = "Successfully projected \(sessions.count) sessions."
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
        endOfDay: Date
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
            
            let titles = sideTasks.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if useSideTasks && sideCount < titles.count {
                alternativeTitle = titles[sideCount]
            } else {
                alternativeTitle = sideSessionName
            }
        } else if currentType == .side && workCount < workSessions {
            alternativeType = .work
            alternativeDuration = workSessionDuration
            alternativeCalendar = workCalendarName
            
            let titles = workTasks.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if useWorkTasks && workCount < titles.count {
                alternativeTitle = titles[workCount]
            } else {
                alternativeTitle = workSessionName
            }
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
                calendarName: alternativeCalendar
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
    ) -> (availableMinutes: Int, possibleWorkSessions: Int, possibleSideSessions: Int) {
        let calendar = Calendar.current
        let endOfDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: baseDate)!)
        
        var totalAvailable = 0
        var currentTime = startTime
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
        
        let possibleWork = totalAvailable / workWithRest
        let possibleSide = totalAvailable / sideWithRest
        
        return (totalAvailable, possibleWork, possibleSide)
    }
}
