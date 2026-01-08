import SwiftUI

struct SettingsPanel: View {
    @EnvironmentObject var schedulingEngine: SchedulingEngine
    @EnvironmentObject var calendarService: CalendarService
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Planning Section
                planningSection
                
                Divider().background(Color.white.opacity(0.1))
                
                // Work Sessions Section
                sessionSection(
                    title: "Work Sessions",
                    icon: "briefcase.fill",
                    iconColor: Color(hex: "8B5CF6"),
                    count: $schedulingEngine.workSessions,
                    name: $schedulingEngine.workSessionName,
                    duration: $schedulingEngine.workSessionDuration,
                    calendar: $schedulingEngine.workCalendarName
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                // Side Sessions Section
                sessionSection(
                    title: "Side Sessions",
                    icon: "star.fill",
                    iconColor: Color(hex: "3B82F6"),
                    count: $schedulingEngine.sideSessions,
                    name: $schedulingEngine.sideSessionName,
                    duration: $schedulingEngine.sideSessionDuration,
                    calendar: $schedulingEngine.sideCalendarName
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                // Deep Sessions Section
                deepSessionSection
                
                Divider().background(Color.white.opacity(0.1))
                
                // Pattern Section
                patternSection
                
                Divider().background(Color.white.opacity(0.1))
                
                // Rest Section
                restSection
            }
            .padding()
        }
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
    
    // MARK: - Timeline Visibility Section
    
    private var timelineVisibilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(Color(hex: "3B82F6"))
                Text("Timeline View")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Toggle(isOn: $schedulingEngine.hideNightHours) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hide night hours")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                    Text(schedulingEngine.hideNightHours ? "Showing \(formattedHour(schedulingEngine.dayStartHour)) - \(formattedHour(schedulingEngine.dayEndHour))" : "Showing full 24h")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .toggleStyle(.switch)
            .tint(Color(hex: "3B82F6"))
            
            if schedulingEngine.hideNightHours {
                VStack(spacing: 8) {
                    HStack {
                        Text("Morning Edge:")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Stepper("\(schedulingEngine.dayStartHour):00", value: $schedulingEngine.dayStartHour, in: 0...12)
                            .labelsHidden()
                            .scaleEffect(0.8)
                    }
                    
                    HStack {
                        Text("Night Edge:")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Stepper("\(schedulingEngine.dayEndHour):00", value: $schedulingEngine.dayEndHour, in: 13...24)
                            .labelsHidden()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.leading, 8)
            }
        }
    }
    
    private func formattedHour(_ hour: Int) -> String {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = hour % 24
        
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        
        if let date = calendar.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
    
    
    
    // MARK: - Planning Section
    
    private var planningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(Color(hex: "EF4444"))
                Text("Planning Session")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Toggle(isOn: $schedulingEngine.schedulePlanning) {
                Text("Schedule planning session")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
            }
            .toggleStyle(.switch)
            .tint(Color(hex: "EF4444"))
            
            if schedulingEngine.schedulePlanning {
                HStack {
                    Text("Duration:")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Stepper(
                        "\(schedulingEngine.planningDuration) min",
                        value: $schedulingEngine.planningDuration,
                        in: 5...60,
                        step: 5
                    )
                    .font(.system(size: 13, weight: .medium))
                    .fixedSize()
                }
            }
        }
    }
    
    // MARK: - Session Section (Generic)
    
    private func sessionSection(
        title: String,
        icon: String,
        iconColor: Color,
        count: Binding<Int>,
        name: Binding<String>,
        duration: Binding<Int>,
        calendar: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            // Count
            HStack {
                Text("Count:")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Stepper(
                    "\(count.wrappedValue)",
                    value: count,
                    in: 0...15
                )
                .font(.system(size: 13, weight: .medium))
                .fixedSize()
            }
            
            // Name
            HStack {
                Text("Name:")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                TextField("Session name", text: name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                    .frame(width: 150)
            }
            
            // Duration
            HStack {
                Text("Duration:")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Stepper(
                    "\(duration.wrappedValue) min",
                    value: duration,
                    in: 10...120,
                    step: 5
                )
                .font(.system(size: 13, weight: .medium))
                .fixedSize()
            }
            
            // Calendar
            HStack {
                Text("Calendar:")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Picker("", selection: calendar) {
                    ForEach(calendarService.calendarNames(), id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }
        }
    }
    
    // MARK: - Deep Sessions Section
    
    private var deepSessionSection: some View {
         VStack(alignment: .leading, spacing: 12) {
             HStack {
                 Image(systemName: "bolt.circle.fill")
                     .foregroundColor(Color(hex: "10B981"))
                 Text("Deep Sessions")
                     .font(.headline)
                     .foregroundColor(.white)
                 Spacer()
                 Toggle("", isOn: $schedulingEngine.deepSessionConfig.enabled)
                     .labelsHidden()
                     .toggleStyle(.switch)
                     .tint(Color(hex: "10B981"))
             }
             
             if schedulingEngine.deepSessionConfig.enabled {
                 HStack {
                     Text("Sessions Count:")
                         .font(.system(size: 13))
                         .foregroundColor(.white.opacity(0.7))
                     Spacer()
                     Stepper("\(schedulingEngine.deepSessionConfig.sessionCount)", value: $schedulingEngine.deepSessionConfig.sessionCount, in: 1...10)
                         .font(.system(size: 13, weight: .medium))
                         .fixedSize()
                 }
                 
                 HStack {
                     Text("Inject after:")
                         .font(.system(size: 13))
                         .foregroundColor(.white.opacity(0.7))
                     Spacer()
                     Stepper("\(schedulingEngine.deepSessionConfig.injectAfterEvery) sessions", value: $schedulingEngine.deepSessionConfig.injectAfterEvery, in: 1...10)
                         .font(.system(size: 13, weight: .medium))
                         .fixedSize()
                 }
 
                 HStack {
                     Text("Name:")
                         .font(.system(size: 13))
                         .foregroundColor(.white.opacity(0.7))
                     Spacer()
                     TextField("Name", text: $schedulingEngine.deepSessionConfig.name)
                         .textFieldStyle(.plain)
                         .font(.system(size: 13))
                         .padding(6)
                         .background(Color.white.opacity(0.1))
                         .cornerRadius(6)
                         .frame(width: 150)
                 }
                 
                 HStack {
                     Text("Duration:")
                         .font(.system(size: 13))
                         .foregroundColor(.white.opacity(0.7))
                     Spacer()
                     Stepper("\(schedulingEngine.deepSessionConfig.duration) min", value: $schedulingEngine.deepSessionConfig.duration, in: 5...120, step: 5)
                         .font(.system(size: 13, weight: .medium))
                         .fixedSize()
                 }
                 
                 HStack {
                     Text("Calendar:")
                         .font(.system(size: 13))
                         .foregroundColor(.white.opacity(0.7))
                     Spacer()
                     Picker("", selection: $schedulingEngine.deepSessionConfig.calendarName) {
                         ForEach(calendarService.calendarNames(), id: \.self) { name in
                             Text(name).tag(name)
                         }
                     }
                     .pickerStyle(.menu)
                     .frame(width: 150)
                 }
             }
        }
    }
    
    // MARK: - Pattern Section
    
    private var patternSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(Color(hex: "10B981"))
                Text("Scheduling Pattern")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("Pattern:")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Picker("", selection: $schedulingEngine.pattern) {
                    ForEach(SchedulePattern.allCases) { pattern in
                        HStack {
                            Image(systemName: pattern.icon)
                            Text(pattern.rawValue)
                        }
                        .tag(pattern)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
            }
            
            Text(schedulingEngine.pattern.description)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
            
            if [.alternating, .alternatingReverse, .customRatio].contains(schedulingEngine.pattern) {
                HStack {
                    Text("Work per cycle:")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Stepper(
                        "\(schedulingEngine.workSessionsPerCycle)",
                        value: $schedulingEngine.workSessionsPerCycle,
                        in: 1...5
                    )
                    .font(.system(size: 13, weight: .medium))
                    .fixedSize()
                }
            }
            
            if schedulingEngine.pattern == .customRatio {
                HStack {
                    Text("Side per cycle:")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Stepper(
                        "\(schedulingEngine.sideSessionsPerCycle)",
                        value: $schedulingEngine.sideSessionsPerCycle,
                        in: 1...5
                    )
                    .font(.system(size: 13, weight: .medium))
                    .fixedSize()
                }
                
                Toggle("Side First", isOn: $schedulingEngine.sideFirst)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .toggleStyle(.switch)
                    .tint(Color(hex: "3B82F6"))
            }
        }
    }
    
    // MARK: - Rest Section
    
    private var restSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundColor(Color(hex: "F59E0B"))
                Text("Rest Between Sessions")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            // Work Rest
             HStack {
                Text("After Work:")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Stepper(
                    "\(schedulingEngine.restDuration) min",
                    value: $schedulingEngine.restDuration,
                    in: 0...60,
                    step: 5
                )
                .font(.system(size: 13, weight: .medium))
                .fixedSize()
            }
            
            // Side Rest
             HStack {
                Text("After Side:")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Stepper(
                    "\(schedulingEngine.sideRestDuration) min",
                    value: $schedulingEngine.sideRestDuration,
                    in: 0...60,
                    step: 5
                )
                .font(.system(size: 13, weight: .medium))
                .fixedSize()
            }
            
             HStack {
                Text("After Deep:")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Stepper(
                    "\(schedulingEngine.deepRestDuration) min",
                    value: $schedulingEngine.deepRestDuration,
                    in: 0...60,
                    step: 5
                )
                .font(.system(size: 13, weight: .medium))
                .fixedSize()
            }
        }
    }
}

#Preview {
    SettingsPanel()
        .environmentObject(SchedulingEngine())
        .environmentObject(CalendarService())
        .frame(width: 320, height: 800)
        .background(Color(hex: "0F172A"))
}

struct AppSettingsView: View {
    @EnvironmentObject var schedulingEngine: SchedulingEngine
    
    var body: some View {
        Form {
            Section("Scheduling Logic") {
                Toggle("Aware existing tasks", isOn: $schedulingEngine.awareExistingTasks)
                
                Text("When enabled, the app only projects remaining tasks needed to meet your quotas by counting existing events on your calendar.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tagging System")
                        .font(.caption)
                        .fontWeight(.bold)
                    Text("The app uses hashtags in event notes to identify session types: #work, #side, #deep, #plan. This allows accurate counting even if calendars overlap.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
            
            Section("Timeline Visibility") {
                Toggle("Hide night hours", isOn: $schedulingEngine.hideNightHours)
                
                HStack {
                    Text("Morning Edge:")
                    Spacer()
                    Stepper("\(schedulingEngine.dayStartHour):00", value: $schedulingEngine.dayStartHour, in: 0...12)
                }
                .disabled(!schedulingEngine.hideNightHours)
                
                HStack {
                    Text("Night Edge:")
                    Spacer()
                    Stepper("\(schedulingEngine.dayEndHour):00", value: $schedulingEngine.dayEndHour, in: 13...24)
                }
                .disabled(!schedulingEngine.hideNightHours)
                Text("These settings control the visible range of the timeline when 'Hide Night Hours' is enabled.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
        .navigationTitle("Settings")
    }
}

#Preview {
    AppSettingsView()
        .environmentObject(SchedulingEngine())
}
