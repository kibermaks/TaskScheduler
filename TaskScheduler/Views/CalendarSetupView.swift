import SwiftUI

struct CalendarSetupView: View {
    @EnvironmentObject var calendarService: CalendarService
    @EnvironmentObject var schedulingEngine: SchedulingEngine
    
    @State private var selectedWorkCalendar: String = ""
    @State private var selectedSideCalendar: String = ""
    @State private var selectedDeepCalendar: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isCompleting = false
    @State private var isReloading = false
    
    var canComplete: Bool {
        !selectedWorkCalendar.isEmpty && !selectedSideCalendar.isEmpty && !selectedDeepCalendar.isEmpty
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "0F172A"), Color(hex: "1E293B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Main content container with frosted glass effect
            VStack(spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Calendar Setup")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Choose which calendars to use for each session type")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Reload button
                    Button {
                        reloadCalendars()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isReloading ? "arrow.clockwise" : "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .rotationEffect(.degrees(isReloading ? 360 : 0))
                                .animation(isReloading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isReloading)
                            Text("Reload")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .disabled(isReloading)
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .padding(.bottom, 16)
                
                // Info note at top
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "60A5FA"))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Don't worry, you can always change these settings later in the app.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("If you need to create new calendars, use the Reload button after adding them in Calendar.app.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "3B82F6").opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "60A5FA").opacity(0.4), lineWidth: 1.5)
                        )
                )
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Work Sessions
                        calendarSelectionCard(
                            title: "Work Sessions",
                            icon: "briefcase.fill",
                            color: Color(hex: "8B5CF6"),
                            description: "Primary focus blocks for important tasks",
                            tag: "#work",
                            selectedCalendar: $selectedWorkCalendar
                        )
                        
                        // Side Sessions
                        calendarSelectionCard(
                            title: "Side Sessions",
                            icon: "star.fill",
                            color: Color(hex: "3B82F6"),
                            description: "Life admin, emails, and quick errands",
                            tag: "#side",
                            selectedCalendar: $selectedSideCalendar
                        )
                        
                        // Deep Sessions
                        calendarSelectionCard(
                            title: "Deep Work Sessions",
                            icon: "bolt.circle.fill",
                            color: Color(hex: "10B981"),
                            description: "Rare, high-intensity focus blocks",
                            tag: "#deep",
                            selectedCalendar: $selectedDeepCalendar
                        )
                    }
                    .padding(.bottom, 32)
                }
                
                // Footer
                VStack(spacing: 16) {
                    if showError {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color(hex: "EF4444"))
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    Button {
                        completeSetup()
                    } label: {
                        HStack(spacing: 12) {
                            if isCompleting {
                                ProgressView()
                                    .scaleEffect(0.9)
                                    .tint(.white)
                            }
                            Text(isCompleting ? "Completing..." : "Complete Setup")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    canComplete ?
                                    LinearGradient(
                                        colors: [Color(hex: "10B981"), Color(hex: "059669")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: canComplete ? Color(hex: "10B981").opacity(0.5) : .clear, radius: 15, y: 8)
                        )
                        .opacity(canComplete ? 1.0 : 0.5)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canComplete || isCompleting)
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 32)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "1E293B").opacity(0.95))
                    .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .padding(40)
            .frame(width: 800)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            calendarService.loadCalendars()
            loadAvailableCalendars()
        }
    }
    
    private func calendarSelectionCard(
        title: String,
        icon: String,
        color: Color,
        description: String,
        tag: String,
        selectedCalendar: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        LinearGradient(
                            colors: [color.opacity(0.8), color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: color.opacity(0.3), radius: 8, y: 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Text(tag)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            // Calendar picker
            HStack(spacing: 10) {
                Text("Calendar")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Menu {
                    ForEach(calendarService.calendarNames(), id: \.self) { name in
                        Button(name) {
                            selectedCalendar.wrappedValue = name
                        }
                    }
                } label: {
                    menuLabelView(
                        selectedCalendar: selectedCalendar.wrappedValue,
                        color: color
                    )
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [color.opacity(0.6), color.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: color.opacity(0.15), radius: 12, y: 6)
        )
        .padding(.horizontal, 32)
    }
    
    private func menuLabelView(selectedCalendar: String, color: Color) -> some View {
        HStack {
            Text(selectedCalendar.isEmpty ? "Select a calendar..." : selectedCalendar)
                .foregroundColor(selectedCalendar.isEmpty ? .white.opacity(0.5) : .white)
                .font(.system(size: 14, weight: .medium))
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "0F172A").opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.5), lineWidth: 2)
                )
        )
    }
    
    private func loadAvailableCalendars() {
        let calendars = calendarService.calendarNames()
        guard !calendars.isEmpty else { return }
        
        func prioritizedMatch(from candidates: [String], keywords: [String]) -> String? {
            // 1. Look for exact matches, in priority order
            for keyword in keywords {
                if let exact = candidates.first(where: { $0.lowercased() == keyword.lowercased() }) {
                    return exact
                }
            }
            // 2. Otherwise, look for first by keyword in order (not exact, substring, but respect keyword priority)
            for keyword in keywords {
                if let contains = candidates.first(where: { $0.lowercased().contains(keyword.lowercased()) }) {
                    return contains
                }
            }
            // 3. Fallback
            return nil
        }
        
        // Work: prioritize "work" then "tasks"
        if selectedWorkCalendar.isEmpty {
            let workKeywords = ["work", "tasks"]
            if let match = prioritizedMatch(from: calendars, keywords: workKeywords) {
                selectedWorkCalendar = match
            } else {
                selectedWorkCalendar = calendars.first ?? ""
            }
        }

        // Side: prioritize "side" then "admin" then "personal"
        if selectedSideCalendar.isEmpty {
            let sideKeywords = ["side", "admin", "personal"]
            if let match = prioritizedMatch(from: calendars, keywords: sideKeywords) {
                selectedSideCalendar = match
            } else if calendars.count > 1 {
                selectedSideCalendar = calendars[1]
            } else {
                selectedSideCalendar = calendars.first ?? ""
            }
        }
        
        // Deep: prioritize "deep" then "focus" then "work"
        if selectedDeepCalendar.isEmpty {
            let deepKeywords = ["deep", "focus", "work"]
            if let match = prioritizedMatch(from: calendars, keywords: deepKeywords) {
                selectedDeepCalendar = match
            } else if calendars.count > 2 {
                selectedDeepCalendar = calendars[2]
            } else {
                selectedDeepCalendar = calendars.first ?? ""
            }
        }
    }
    
    private func reloadCalendars() {
        isReloading = true
        calendarService.loadCalendars()
        
        // Give a brief moment for the animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isReloading = false
            loadAvailableCalendars()
        }
    }
    
    private func completeSetup() {
        // Validate selections
        guard !selectedWorkCalendar.isEmpty,
              !selectedSideCalendar.isEmpty,
              !selectedDeepCalendar.isEmpty else {
            errorMessage = "Please select a calendar for each session type"
            showError = true
            return
        }
        
        isCompleting = true
        
        // Save to scheduling engine (these will trigger saveState() via didSet)
        schedulingEngine.workCalendarName = selectedWorkCalendar
        schedulingEngine.sideCalendarName = selectedSideCalendar
        
        // Update deep session config (need to create a new instance to trigger didSet)
        var deepConfig = schedulingEngine.deepSessionConfig
        deepConfig.calendarName = selectedDeepCalendar
        schedulingEngine.deepSessionConfig = deepConfig
        
        // Give a moment for all saves to complete, then mark setup as complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Mark setup as complete
            UserDefaults.standard.set(true, forKey: "TaskScheduler.HasCompletedSetup")
            
            // Trigger refresh notification
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: Notification.Name("SetupCompleted"), object: nil)
                isCompleting = false
            }
        }
    }
}

#Preview {
    CalendarSetupView()
        .environmentObject(CalendarService())
        .environmentObject(SchedulingEngine())
}
