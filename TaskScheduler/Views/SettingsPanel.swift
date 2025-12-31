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
                
                // Extra Sessions Section
                extraSessionSection
                
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
    
    // MARK: - Extra Sessions Section
    
    private var extraSessionSection: some View {
         VStack(alignment: .leading, spacing: 12) {
             HStack {
                 Image(systemName: "plus.circle.fill")
                     .foregroundColor(Color(hex: "10B981"))
                 Text("Extra Sessions")
                     .font(.headline)
                     .foregroundColor(.white)
                 Spacer()
                 Toggle("", isOn: $schedulingEngine.extraSessionConfig.enabled)
                     .labelsHidden()
                     .toggleStyle(.switch)
                     .tint(Color(hex: "10B981"))
             }
             
             if schedulingEngine.extraSessionConfig.enabled {
                 // Count (max limit)
                 HStack {
                     Text("Sessions Count:")
                         .font(.system(size: 13))
                         .foregroundColor(.white.opacity(0.7))
                     Spacer()
                     Stepper("\(schedulingEngine.extraSessionConfig.sessionCount)", value: $schedulingEngine.extraSessionConfig.sessionCount, in: 1...10)
                         .font(.system(size: 13, weight: .medium))
                         .fixedSize()
                 }
                 
                 // Inject After
                 HStack {
                     Text("Inject after:")
                         .font(.system(size: 13))
                         .foregroundColor(.white.opacity(0.7))
                     Spacer()
                     Stepper("\(schedulingEngine.extraSessionConfig.injectAfterEvery) sessions", value: $schedulingEngine.extraSessionConfig.injectAfterEvery, in: 1...10)
                         .font(.system(size: 13, weight: .medium))
                         .fixedSize()
                 }

                 // Name
                 HStack {
                     Text("Name:")
                         .font(.system(size: 13))
                         .foregroundColor(.white.opacity(0.7))
                     Spacer()
                     TextField("Name", text: $schedulingEngine.extraSessionConfig.name)
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
                     Stepper("\(schedulingEngine.extraSessionConfig.duration) min", value: $schedulingEngine.extraSessionConfig.duration, in: 5...120, step: 5)
                         .font(.system(size: 13, weight: .medium))
                         .fixedSize()
                 }
                 
                 // Calendar Picker
                 HStack {
                     Text("Calendar:")
                         .font(.system(size: 13))
                         .foregroundColor(.white.opacity(0.7))
                     Spacer()
                     Picker("", selection: $schedulingEngine.extraSessionConfig.calendarName) {
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
            
            // Extra Rest (only if extra enabled logic? User said 'tied to Extra sessions', maybe always show or only if enabled. Since they asked for parameter, I'll show it.)
             HStack {
                Text("After Extra:")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Stepper(
                    "\(schedulingEngine.extraRestDuration) min",
                    value: $schedulingEngine.extraRestDuration,
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
