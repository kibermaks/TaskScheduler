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
    
    @StateObject private var nameHistory = SessionNameHistory.shared
    
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
                    isShowingHelp: $showingWorkHelp,
                    sessionType: .work
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
                    isShowingHelp: $showingSideHelp,
                    sessionType: .side
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
            
            HStack {
                Text("Schedule planning session")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Toggle("", isOn: $schedulingEngine.schedulePlanning)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Color(hex: "EF4444"))
            }
            
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
        isShowingHelp: Binding<Bool>,
        sessionType: SessionType
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
            
            // Name History
            let historyNames = nameHistory.getNames(for: sessionType)
            if !historyNames.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent names:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    
                    FlowLayout(spacing: 6) {
                        ForEach(historyNames, id: \.self) { historyName in
                            HStack(spacing: 4) {
                                Button {
                                    name.wrappedValue = historyName
                                } label: {
                                    Text(historyName)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    nameHistory.removeName(historyName, from: sessionType)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white.opacity(0.5))
                                        .frame(width: 14, height: 14)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
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
                
                CalendarPickerCompact(
                    selectedCalendar: calendar,
                    calendars: calendarService.calendarInfoList(),
                    accentColor: iconColor
                )
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
                    NumericInputField(value: $schedulingEngine.deepSessionConfig.injectAfterEvery, range: 1...10, unit: "slots")
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
                 
                 // Deep Name History
                 let deepHistoryNames = nameHistory.getNames(for: .deep)
                 if !deepHistoryNames.isEmpty {
                     VStack(alignment: .leading, spacing: 6) {
                         Text("Recent names:")
                             .font(.system(size: 11, weight: .medium))
                             .foregroundColor(.white.opacity(0.5))
                         
                         FlowLayout(spacing: 6) {
                             ForEach(deepHistoryNames, id: \.self) { historyName in
                                 HStack(spacing: 4) {
                                     Button {
                                         schedulingEngine.deepSessionConfig.name = historyName
                                     } label: {
                                         Text(historyName)
                                             .font(.system(size: 11))
                                             .foregroundColor(.white.opacity(0.8))
                                             .padding(.horizontal, 8)
                                             .padding(.vertical, 4)
                                             .background(Color.white.opacity(0.1))
                                             .cornerRadius(4)
                                     }
                                     .buttonStyle(.plain)
                                     
                                     Button {
                                         nameHistory.removeName(historyName, from: .deep)
                                     } label: {
                                         Image(systemName: "xmark")
                                             .font(.system(size: 8, weight: .bold))
                                             .foregroundColor(.white.opacity(0.5))
                                             .frame(width: 14, height: 14)
                                     }
                                     .buttonStyle(.plain)
                                 }
                             }
                         }
                     }
                 }
                 
                 HStack {
                     Text("Duration:")
                         .font(.system(size: 13))
                         .foregroundColor(.white.opacity(0.7))
                     Spacer()
                     NumericInputField(value: $schedulingEngine.deepSessionConfig.duration, range: 5...180, step: 5, unit: "min")
                 }
                 
                HStack {
                    Text("Calendar:")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    CalendarPickerCompact(
                        selectedCalendar: $schedulingEngine.deepSessionConfig.calendarName,
                        calendars: calendarService.calendarInfoList(),
                        accentColor: Color(hex: "10B981")
                    )
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
                    
                    if [.customRatio, .sidesFirstAndLast].contains(schedulingEngine.pattern) {
                        HStack {
                            Text("Side per cycle:")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Spacer()
                            
                            NumericInputField(value: $schedulingEngine.sideSessionsPerCycle, range: 1...5)
                        }
                    }
                    
                    if schedulingEngine.pattern == .customRatio {
                        Toggle("Side First", isOn: $schedulingEngine.sideFirst)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .toggleStyle(.switch)
                            .tint(Color(hex: "3B82F6"))
                    }
                    
                    // Flexible Side Scheduling setting
                    Divider().background(Color.white.opacity(0.05))
                    
                    HStack {
                        Text("Flexible Side Scheduling")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Toggle("", isOn: $schedulingEngine.flexibleSideScheduling)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(Color(hex: "3B82F6"))
                    }
                    
                    Text("Try to fit side sessions into smaller time gaps when work sessions don't fit")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.leading, 8)
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

// MARK: - Flow Layout Helper
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Session Name History Manager
class SessionNameHistory: ObservableObject {
    static let shared = SessionNameHistory()
    
    private let workKey = "TaskScheduler.WorkSessionNames"
    private let sideKey = "TaskScheduler.SideSessionNames"
    private let deepKey = "TaskScheduler.DeepSessionNames"
    
    @Published var workNames: [String] = []
    @Published var sideNames: [String] = []
    @Published var deepNames: [String] = []
    
    private init() {
        loadNames()
    }
    
    private func loadNames() {
        workNames = UserDefaults.standard.stringArray(forKey: workKey) ?? []
        sideNames = UserDefaults.standard.stringArray(forKey: sideKey) ?? []
        deepNames = UserDefaults.standard.stringArray(forKey: deepKey) ?? []
    }
    
    func addName(_ name: String, for type: SessionType) {
        guard !name.isEmpty else { return }
        
        var names: [String]
        let key: String
        
        switch type {
        case .work:
            names = workNames
            key = workKey
        case .side:
            names = sideNames
            key = sideKey
        case .deep:
            names = deepNames
            key = deepKey
        default:
            return
        }
        
        // Remove if exists and add to front (most recent first)
        names.removeAll { $0 == name }
        names.insert(name, at: 0)
        
        // Limit to 20 most recent
        if names.count > 20 {
            names = Array(names.prefix(20))
        }
        
        UserDefaults.standard.set(names, forKey: key)
        
        switch type {
        case .work:
            workNames = names
        case .side:
            sideNames = names
        case .deep:
            deepNames = names
        default:
            break
        }
    }
    
    func removeName(_ name: String, from type: SessionType) {
        var names: [String]
        let key: String
        
        switch type {
        case .work:
            names = workNames
            key = workKey
        case .side:
            names = sideNames
            key = sideKey
        case .deep:
            names = deepNames
            key = deepKey
        default:
            return
        }
        
        names.removeAll { $0 == name }
        UserDefaults.standard.set(names, forKey: key)
        
        switch type {
        case .work:
            workNames = names
        case .side:
            sideNames = names
        case .deep:
            deepNames = names
        default:
            break
        }
    }
    
    func getNames(for type: SessionType) -> [String] {
        switch type {
        case .work:
            return workNames
        case .side:
            return sideNames
        case .deep:
            return deepNames
        default:
            return []
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

