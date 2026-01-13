import SwiftUI

struct SettingsPanel: View {
    @EnvironmentObject var schedulingEngine: SchedulingEngine
    @EnvironmentObject var calendarService: CalendarService
    
    @Binding var hasSeenPatternsGuide: Bool
    @Binding var showingPatternsGuide: Bool
    
    @State private var showingWorkHelp = false
    @State private var showingSideHelp = false
    @State private var showingDeepHelp = false
    @State private var showingPlanningHelp = false
    @State private var showingPatternHelp = false
    @State private var showingRestHelp = false
    
    private let workHelpText = "Work sessions are your primary focus blocks. Use these for your main professional tasks or projects that require sustained concentration."
    private let sideHelpText = "Side sessions are for secondary tasks or 'life admin'. Perfect for paying bills, checking something new, responding to emails, or handling quick errands."
    private let deepHelpText = "Deep sessions (often called Deep Work) are rare, high-intensity focus blocks. They are injected periodically for your most demanding creative or analytical work."
    private let planningHelpText = "The Planning session is a short block at the start of your day to review your tasks and organize your sequence. It ensures you start with clarity."
    private let patternHelpText = "Scheduling patterns define how Work and Side sessions are interleaved. 'Alternating' swaps between them, while 'Concentrated' groups types together."
    private let restHelpText = "Rest intervals are crucial for maintaining peak performance. Choose different durations for after-work, after-side, or after-deep sessions to recharge effectively."
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Planning Section
                planningSection
                
                Divider().background(Color.white.opacity(0.1))
                
                sessionSection(
                    title: "Work Sessions",
                    icon: "briefcase.fill",
                    iconColor: Color(hex: "8B5CF6"),
                    count: $schedulingEngine.workSessions,
                    name: $schedulingEngine.workSessionName,
                    duration: $schedulingEngine.workSessionDuration,
                    calendar: $schedulingEngine.workCalendarName,
                    helpText: workHelpText,
                    isShowingHelp: $showingWorkHelp
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
                    calendar: $schedulingEngine.sideCalendarName,
                    helpText: sideHelpText,
                    isShowingHelp: $showingSideHelp
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
                        NumericInputField(value: $schedulingEngine.dayStartHour, range: 0...12, unit: "h")
                    }
                    
                    HStack {
                        Text("Night Edge:")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        NumericInputField(value: $schedulingEngine.dayEndHour, range: 13...24, unit: "h")
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
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(Color(hex: "EF4444"))
                Text("Planning Session")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Button {
                    showingPlanningHelp.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingPlanningHelp) {
                    Text(planningHelpText)
                        .font(.system(size: 13))
                        .padding()
                        .frame(width: 250)
                }
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
                    
                    NumericInputField(
                        value: $schedulingEngine.planningDuration,
                        range: 5...60,
                        step: 5,
                        unit: "min"
                    )
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
        calendar: Binding<String>,
        helpText: String,
        isShowingHelp: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Button {
                    isShowingHelp.wrappedValue.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .popover(isPresented: isShowingHelp) {
                    Text(helpText)
                        .font(.system(size: 13))
                        .padding()
                        .frame(width: 250)
                }
            }
            
            // Count
            HStack {
                Text("Count:")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                NumericInputField(value: count, range: 0...15)
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
                
                NumericInputField(
                    value: duration,
                    range: 10...120,
                    step: 5,
                    unit: "min"
                )
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
             HStack(spacing: 8) {
                 Image(systemName: "bolt.circle.fill")
                     .foregroundColor(Color(hex: "10B981"))
                 Text("Deep Sessions")
                     .font(.headline)
                     .foregroundColor(.white)
                 
                 Button {
                     showingDeepHelp.toggle()
                 } label: {
                     Image(systemName: "info.circle")
                         .font(.system(size: 13))
                         .foregroundColor(.white.opacity(0.4))
                 }
                 .buttonStyle(.plain)
                 .popover(isPresented: $showingDeepHelp) {
                     Text(deepHelpText)
                         .font(.system(size: 13))
                         .padding()
                         .frame(width: 250)
                 }
                 
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
                     NumericInputField(value: $schedulingEngine.deepSessionConfig.sessionCount, range: 1...10)
                 }
                 
                 HStack {
                     Text("Inject after:")
                         .font(.system(size: 13))
                         .foregroundColor(.white.opacity(0.7))
                     Spacer()
                     NumericInputField(value: $schedulingEngine.deepSessionConfig.injectAfterEvery, range: 1...10, unit: "sessions")
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
                     NumericInputField(value: $schedulingEngine.deepSessionConfig.duration, range: 5...120, step: 5, unit: "min")
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
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(Color(hex: "10B981"))
                Text("Scheduling Pattern")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Button {
                    showingPatternHelp.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingPatternHelp) {
                    Text(patternHelpText)
                        .font(.system(size: 13))
                        .padding()
                        .frame(width: 250)
                }
            }
            
            if !hasSeenPatternsGuide {
                // Reveal options button with frosted glass effect
                Button {
                    showingPatternsGuide = true
                    hasSeenPatternsGuide = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Reveal options")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "10B981"))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.5)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: "10B981").opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
            } else {
                // Pattern options (shown after guide is seen)
                VStack(alignment: .leading, spacing: 12) {
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
                            
                            NumericInputField(value: $schedulingEngine.workSessionsPerCycle, range: 1...5)
                        }
                    }
                    
                    if schedulingEngine.pattern == .customRatio {
                        HStack {
                            Text("Side per cycle:")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Spacer()
                            
                            NumericInputField(value: $schedulingEngine.sideSessionsPerCycle, range: 1...5)
                        }
                        
                        Toggle("Side First", isOn: $schedulingEngine.sideFirst)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .toggleStyle(.switch)
                            .tint(Color(hex: "3B82F6"))
                    }
                }
            }
        }
    }
    
    // MARK: - Rest Section
    
    private var restSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundColor(Color(hex: "F59E0B"))
                Text("Rest Between Sessions")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Button {
                    showingRestHelp.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingRestHelp) {
                    Text(restHelpText)
                        .font(.system(size: 13))
                        .padding()
                        .frame(width: 250)
                }
            }
            
             // Work Rest
              HStack {
                 Text("After Work:")
                     .font(.system(size: 13))
                     .foregroundColor(.white.opacity(0.7))
                 
                 Spacer()
                 
                 NumericInputField(value: $schedulingEngine.restDuration, range: 0...60, step: 5, unit: "min")
             }
             
             // Side Rest
              HStack {
                 Text("After Side:")
                     .font(.system(size: 13))
                     .foregroundColor(.white.opacity(0.7))
                 
                 Spacer()
                 
                 NumericInputField(value: $schedulingEngine.sideRestDuration, range: 0...60, step: 5, unit: "min")
             }
             
              HStack {
                 Text("After Deep:")
                     .font(.system(size: 13))
                     .foregroundColor(.white.opacity(0.7))
                 
                 Spacer()
                 
                 NumericInputField(value: $schedulingEngine.deepRestDuration, range: 0...60, step: 5, unit: "min")
             }
        }
    }
}

#Preview {
    SettingsPanel(
        hasSeenPatternsGuide: .constant(false),
        showingPatternsGuide: .constant(false)
    )
        .environmentObject(SchedulingEngine())
        .environmentObject(CalendarService())
        .frame(width: 320, height: 800)
        .background(Color(hex: "0F172A"))
}

