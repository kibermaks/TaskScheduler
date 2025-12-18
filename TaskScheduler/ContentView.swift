import SwiftUI

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var calendarService: CalendarService
    @EnvironmentObject var schedulingEngine: SchedulingEngine
    
    @State private var selectedDate = Date()
    @State private var startTime = Date()
    @State private var showingConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var dateSelection: DateSelection = .today
    @State private var autoPreview = true
    @State private var useNowTime = true
    @State private var deletePastSessions = false
    @State private var presets: [Preset] = []
    @State private var selectedPreset: Preset?
    @State private var showingNewPresetSheet = false
    @State private var nowTimer: Timer?
    
    enum DateSelection: String, CaseIterable {
        case today = "Today"
        case tomorrow = "Tomorrow"
        case custom = "Custom"
    }
    
    var body: some View {
        ContentViewBody(
            selectedDate: $selectedDate,
            startTime: $startTime,
            showingConfirmation: $showingConfirmation,
            showingDeleteConfirmation: $showingDeleteConfirmation,
            dateSelection: $dateSelection,
            autoPreview: $autoPreview,
            useNowTime: $useNowTime,
            deletePastSessions: $deletePastSessions,
            presets: $presets,
            selectedPreset: $selectedPreset,
            showingNewPresetSheet: $showingNewPresetSheet,
            nowTimer: $nowTimer
        )
    }
}

// MARK: - Content View Body (Extracted)
struct ContentViewBody: View {
    @EnvironmentObject var calendarService: CalendarService
    @EnvironmentObject var schedulingEngine: SchedulingEngine
    
    @Binding var selectedDate: Date
    @Binding var startTime: Date
    @Binding var showingConfirmation: Bool
    @Binding var showingDeleteConfirmation: Bool
    @Binding var dateSelection: ContentView.DateSelection
    @Binding var autoPreview: Bool
    @Binding var useNowTime: Bool
    @Binding var deletePastSessions: Bool
    @Binding var presets: [Preset]
    @Binding var selectedPreset: Preset?
    @Binding var showingNewPresetSheet: Bool
    @Binding var nowTimer: Timer?
    
    var body: some View {
        ZStack {
            backgroundGradient
            VStack(spacing: 0) {
                HeaderView(
                    dateSelection: $dateSelection,
                    selectedDate: $selectedDate,
                    useNowTime: $useNowTime,
                    startTime: $startTime,
                    autoPreview: $autoPreview
                )
                mainHStack
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingNewPresetSheet) {
            NewPresetSheet { preset in
                PresetStorage.shared.addPreset(preset)
                presets = PresetStorage.shared.loadPresets()
                applyPreset(preset)
            }
            .environmentObject(schedulingEngine)
        }
        .alert("Schedule Sessions", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Schedule") { scheduleAllSessions() }
        } message: {
            Text("Add \(schedulingEngine.projectedSessions.count) sessions to your calendar?")
        }
        .sheet(isPresented: $showingDeleteConfirmation) {
            DeleteConfirmationSheet(
                deletePastSessions: $deletePastSessions,
                showingSheet: $showingDeleteConfirmation,
                onDelete: deleteScheduledSessions
            )
            .environmentObject(schedulingEngine)
        }
        .task { await requestCalendarAccess() }
        .onAppear { onAppearActions() }
        .onDisappear { nowTimer?.invalidate() }
        .onChange(of: dateSelection) { _, newSelection in
            updateSelectedDate(for: newSelection)
        }
        .onChange(of: selectedDate) { _, _ in
            Task {
                await calendarService.fetchEvents(for: selectedDate)
                if autoPreview { updateProjectedSchedule() }
            }
        }
        .onChange(of: startTime) { _, _ in
            if autoPreview && !useNowTime { updateProjectedSchedule() }
        }
        .onChange(of: useNowTime) { _, isNow in
            if isNow { startTime = roundedNowTime() }
            if autoPreview { updateProjectedSchedule() }
        }
        .onChange(of: calendarService.lastRefresh) { _, _ in
            // Calendar events changed externally (from Calendar.app)
            if autoPreview { updateProjectedSchedule() }
        }
        .modifier(SettingsChangeModifier(autoPreview: autoPreview, updatePreview: updateProjectedSchedule))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if useNowTime && dateSelection == .today {
                startTime = roundedNowTime()
            } else if autoPreview {
                updateProjectedSchedule()
            }
        }
    }
    
    private func updateSelectedDate(for selection: ContentView.DateSelection) {
        let calendar = Calendar.current
        switch selection {
        case .today:
            selectedDate = Date()
            useNowTime = true
            startTime = roundedNowTime()
        case .tomorrow:
            selectedDate = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            useNowTime = false
            startTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        case .custom:
            useNowTime = false
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(hex: "0F172A"), Color(hex: "1E293B")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var mainHStack: some View {
        HStack(spacing: 0) {
            LeftPanel(
                presets: $presets,
                selectedPreset: $selectedPreset,
                showingNewPresetSheet: $showingNewPresetSheet,
                autoPreview: autoPreview,
                updatePreview: updateProjectedSchedule,
                applyPreset: applyPreset
            )
            
            Divider().background(Color.white.opacity(0.1))
            
            TimelineView(selectedDate: selectedDate, startTime: effectiveStartTime)
                .padding()
            
            Divider().background(Color.white.opacity(0.1))
            
            RightPanel(
                selectedDate: selectedDate,
                effectiveStartTime: effectiveStartTime,
                autoPreview: autoPreview,
                showingConfirmation: $showingConfirmation,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                deletePastSessions: $deletePastSessions,
                updatePreview: updateProjectedSchedule
            )
        }
    }
    
    var effectiveStartTime: Date {
        if useNowTime && dateSelection == .today {
            return roundedNowTime()
        }
        return startTime
    }
    
    func roundedNowTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let minute = components.minute ?? 0
        let roundedMinute = ((minute / 5) + 1) * 5
        let extraHour = roundedMinute >= 60 ? 1 : 0
        
        var newComponents = components
        newComponents.minute = roundedMinute % 60
        newComponents.hour = (components.hour ?? 0) + extraHour
        newComponents.second = 0
        
        return calendar.date(from: newComponents) ?? now
    }
    
    private func onAppearActions() {
        presets = PresetStorage.shared.loadPresets()
        
        // Restore last active preset
        if let lastId = PresetStorage.shared.loadLastActivePresetId(),
           let lastPreset = presets.first(where: { $0.id == lastId }) {
            applyPreset(lastPreset)
        } else if let first = presets.first {
            applyPreset(first)
        }
        
        nowTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            if useNowTime && dateSelection == .today && autoPreview {
                DispatchQueue.main.async { updateProjectedSchedule() }
            }
        }
    }
    
    private func applyPreset(_ preset: Preset) {
        selectedPreset = preset
        schedulingEngine.applyPreset(preset)
        PresetStorage.shared.saveLastActivePresetId(preset.id)
        if autoPreview { updateProjectedSchedule() }
    }
    
    func updateProjectedSchedule() {
        let planningExists = calendarService.hasPlanningSession(for: selectedDate)
        _ = schedulingEngine.generateSchedule(
            startTime: effectiveStartTime,
            baseDate: selectedDate,
            busySlots: calendarService.busySlots,
            includePlanning: !planningExists
        )
    }
    
    private func requestCalendarAccess() async {
        if calendarService.authorizationStatus != .fullAccess &&
           calendarService.authorizationStatus != .authorized {
            let _ = await calendarService.requestAccess()
        }
        await calendarService.fetchEvents(for: selectedDate)
        if autoPreview { updateProjectedSchedule() }
    }
    
    private func scheduleAllSessions() {
        let result = calendarService.createSessions(schedulingEngine.projectedSessions)
        if result.failed == 0 {
            schedulingEngine.schedulingMessage = "Successfully scheduled \(result.success) sessions!"
        } else {
            schedulingEngine.schedulingMessage = "Scheduled \(result.success), failed \(result.failed)"
        }
        Task {
            await calendarService.fetchEvents(for: selectedDate)
            schedulingEngine.projectedSessions = []
        }
    }
    
    private func deleteScheduledSessions() {
        // Collect all calendars to clear
        var calendars = [schedulingEngine.workCalendarName, schedulingEngine.sideCalendarName]
        if schedulingEngine.extraSessionConfig.enabled {
            calendars.append(schedulingEngine.extraSessionConfig.calendarName)
        }
        
        // Remove duplicates if any calendars share the same name
        calendars = Array(Set(calendars))
        
        // Passing nil for sessionNames means "delete all events on these calendars"
        let result: (deleted: Int, failed: Int)
        if deletePastSessions {
            result = calendarService.deleteSessionEvents(for: selectedDate, sessionNames: nil, fromCalendars: calendars)
        } else {
            result = calendarService.deleteFutureSessionEvents(for: selectedDate, after: Date(), sessionNames: nil, fromCalendars: calendars)
        }
        
        schedulingEngine.schedulingMessage = result.deleted > 0 ? "Deleted \(result.deleted) events" : "No events found to delete"
        
        Task {
            await calendarService.fetchEvents(for: selectedDate)
            if autoPreview { updateProjectedSchedule() }
        }
    }
}

// MARK: - Settings Change Modifier
struct SettingsChangeModifier: ViewModifier {
    @EnvironmentObject var engine: SchedulingEngine
    let autoPreview: Bool
    let updatePreview: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: engine.workSessions) { _, _ in trigger() }
            .onChange(of: engine.sideSessions) { _, _ in trigger() }
            .onChange(of: engine.workSessionDuration) { _, _ in trigger() }
            .onChange(of: engine.sideSessionDuration) { _, _ in trigger() }
            .onChange(of: engine.restDuration) { _, _ in trigger() }
            .onChange(of: engine.pattern) { _, _ in trigger() }
            .onChange(of: engine.schedulePlanning) { _, _ in trigger() }
            .onChange(of: engine.planningDuration) { _, _ in trigger() }
            .background(extraObservers)
    }
    
    private var extraObservers: some View {
        Color.clear
            .onChange(of: engine.workSessionsPerCycle) { _, _ in trigger() }
            .onChange(of: engine.sideSessionsPerCycle) { _, _ in trigger() }
            .onChange(of: engine.sideRestDuration) { _, _ in trigger() }
            .onChange(of: engine.extraRestDuration) { _, _ in trigger() }
            .onChange(of: engine.extraSessionConfig.enabled) { _, _ in trigger() }
            .onChange(of: engine.extraSessionConfig.sessionCount) { _, _ in trigger() }
            .onChange(of: engine.extraSessionConfig.injectAfterEvery) { _, _ in trigger() }
            .onChange(of: engine.extraSessionConfig.name) { _, _ in trigger() }
            .onChange(of: engine.extraSessionConfig.duration) { _, _ in trigger() }
            .onChange(of: engine.extraSessionConfig.calendarName) { _, _ in trigger() }
    }
    
    private func trigger() {
        if autoPreview { updatePreview() }
    }
}

// MARK: - Header View
struct HeaderView: View {
    @Binding var dateSelection: ContentView.DateSelection
    @Binding var selectedDate: Date
    @Binding var useNowTime: Bool
    @Binding var startTime: Date
    @Binding var autoPreview: Bool
    
    var body: some View {
        HStack {
            appTitle
            Spacer()
            dateButtons
            Spacer()
            startTimeControls
            Spacer()
            autoToggle
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.2))
    }
    
    private var appTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Task Scheduler")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Plan your productive day")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private var dateButtons: some View {
        HStack(spacing: 12) {
            ForEach(ContentView.DateSelection.allCases, id: \.self) { sel in
                Button { dateSelection = sel } label: {
                    Text(sel.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(dateSelection == sel ? Color(hex: "8B5CF6") : Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
            }
            if dateSelection == .custom {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .frame(width: 130)
            }
        }
    }
    
    private var startTimeControls: some View {
        HStack(spacing: 8) {
            Text("Start:").foregroundColor(.white.opacity(0.7))
            Picker("", selection: $useNowTime) {
                Text("Now").tag(true)
                Text("Set").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
            
            if !useNowTime {
                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(width: 80)
            } else {
                Text(formatNowTime())
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "3B82F6"))
                    .padding(.horizontal, 8)
            }
        }
    }
    
    private func formatNowTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let calendar = Calendar.current
        let now = Date()
        let comp = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let minute = comp.minute ?? 0
        let rounded = ((minute / 5) + 1) * 5
        var newComp = comp
        newComp.minute = rounded % 60
        newComp.hour = (comp.hour ?? 0) + (rounded >= 60 ? 1 : 0)
        let date = calendar.date(from: newComp) ?? now
        return formatter.string(from: date)
    }
    
    private var autoToggle: some View {
        Toggle(isOn: $autoPreview) {
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                Text("Auto")
            }
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.8))
        }
        .toggleStyle(.switch)
        .tint(Color(hex: "3B82F6"))
    }
}

// MARK: - Left Panel
struct LeftPanel: View {
    @EnvironmentObject var schedulingEngine: SchedulingEngine
    @Binding var presets: [Preset]
    @Binding var selectedPreset: Preset?
    @Binding var showingNewPresetSheet: Bool
    let autoPreview: Bool
    let updatePreview: () -> Void
    let applyPreset: (Preset) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            presetDropdown
            Divider().background(Color.white.opacity(0.1))
            SettingsPanel()
        }
        .frame(width: 320)
        .padding()
    }
    
    private var presetDropdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bookmark.fill").foregroundColor(Color(hex: "8B5CF6"))
                Text("Preset").font(.headline).foregroundColor(.white)
                Spacer()
            }
            presetMenu
        }
        .padding(.bottom, 12)
    }
    
    private var presetMenu: some View {
        Menu {
            ForEach(presets) { preset in
                Button { applyPreset(preset) } label: { Label(preset.name, systemImage: preset.icon) }
            }
            Divider()
            Button { showingNewPresetSheet = true } label: { Label("Save Current as New Preset...", systemImage: "plus") }
            if let p = selectedPreset {
                Button { updateCurrentPreset(p) } label: { Label("Update Current Preset", systemImage: "arrow.triangle.2.circlepath") }
                Button(role: .destructive) { deletePreset(p) } label: { Label("Delete Preset", systemImage: "trash") }
            }
        } label: {
            HStack {
                if let p = selectedPreset {
                    Image(systemName: p.icon).foregroundColor(Color(hex: "8B5CF6"))
                    Text(p.name).foregroundColor(.white)
                } else {
                    Image(systemName: "doc").foregroundColor(.white.opacity(0.5))
                    Text("No Preset Selected").foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.white.opacity(0.1)).cornerRadius(8)
        }
        .menuStyle(.borderlessButton)
    }
    
    private func updateCurrentPreset(_ preset: Preset) {
        let updated = Preset(id: preset.id, name: preset.name, icon: preset.icon,
            workSessionCount: schedulingEngine.workSessions, sideSessionCount: schedulingEngine.sideSessions,
            workSessionName: schedulingEngine.workSessionName, sideSessionName: schedulingEngine.sideSessionName,
            workSessionDuration: schedulingEngine.workSessionDuration, sideSessionDuration: schedulingEngine.sideSessionDuration,
            planningDuration: schedulingEngine.planningDuration, restDuration: schedulingEngine.restDuration,
            sideRestDuration: schedulingEngine.sideRestDuration,
            extraRestDuration: schedulingEngine.extraRestDuration,
            schedulePlanning: schedulingEngine.schedulePlanning, pattern: schedulingEngine.pattern,
            workSessionsPerCycle: schedulingEngine.workSessionsPerCycle,
            sideSessionsPerCycle: schedulingEngine.sideSessionsPerCycle,
            sideFirst: schedulingEngine.sideFirst,
            extraSessionConfig: schedulingEngine.extraSessionConfig,
            calendarMapping: CalendarMapping(workCalendarName: schedulingEngine.workCalendarName, sideCalendarName: schedulingEngine.sideCalendarName))
        PresetStorage.shared.updatePreset(updated)
        presets = PresetStorage.shared.loadPresets()
        selectedPreset = updated
    }
    
    private func deletePreset(_ preset: Preset) {
        PresetStorage.shared.deletePreset(preset)
        presets = PresetStorage.shared.loadPresets()
        selectedPreset = presets.first
        if let first = selectedPreset {
            applyPreset(first)
        }
    }
}

// MARK: - Right Panel
struct RightPanel: View {
    @EnvironmentObject var calendarService: CalendarService
    @EnvironmentObject var schedulingEngine: SchedulingEngine
    let selectedDate: Date
    let effectiveStartTime: Date
    let autoPreview: Bool
    @Binding var showingConfirmation: Bool
    @Binding var showingDeleteConfirmation: Bool
    @Binding var deletePastSessions: Bool
    let updatePreview: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            availabilityCard
            sessionsSummaryCard
            Spacer()
            actionButtons
        }
        .frame(width: 280)
        .padding()
    }
    
    private var availabilityCard: some View {
        let avail = schedulingEngine.calculateAvailability(startTime: effectiveStartTime, baseDate: selectedDate, busySlots: calendarService.busySlots)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill").foregroundColor(Color(hex: "3B82F6"))
                Text("Availability").font(.headline).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 8) {
                row("Available Time:", "\(avail.availableMinutes / 60)h \(avail.availableMinutes % 60)m")
                row("Possible Work:", "\(avail.possibleWorkSessions) sessions", Color(hex: "8B5CF6"))
                row("Possible Side:", "\(avail.possibleSideSessions) sessions", Color(hex: "3B82F6"))
            }
            .font(.system(size: 13)).foregroundColor(.white.opacity(0.8))
        }
        .padding().background(Color.white.opacity(0.05)).cornerRadius(12)
    }
    
    private func row(_ label: String, _ val: String, _ color: Color? = nil) -> some View {
        HStack { Text(label); Spacer(); Text(val).fontWeight(.semibold).foregroundColor(color ?? .white.opacity(0.8)) }
    }
    
    private var sessionsSummaryCard: some View {
        let sessions = schedulingEngine.projectedSessions
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.clipboard.fill").foregroundColor(Color(hex: "8B5CF6"))
                Text("Projected Sessions").font(.headline).foregroundColor(.white)
            }
            if sessions.isEmpty {
                Text("Enable 'Auto' or click 'Preview'").font(.system(size: 12)).foregroundColor(.white.opacity(0.5)).padding(.vertical, 8)
            } else {
                sessionStats(sessions)
            }
            if !schedulingEngine.schedulingMessage.isEmpty {
                Text(schedulingEngine.schedulingMessage).font(.system(size: 11)).foregroundColor(.yellow.opacity(0.8))
            }
        }
        .padding().background(Color.white.opacity(0.05)).cornerRadius(12)
    }
    
    private func sessionStats(_ sessions: [ScheduledSession]) -> some View {
        let wc = sessions.filter { $0.type == .work }.count
        let sc = sessions.filter { $0.type == .side }.count
        let pc = sessions.filter { $0.type == .planning }.count
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return VStack(alignment: .leading, spacing: 6) {
            if pc > 0 { countRow(.planning, pc) }
            countRow(.work, wc)
            countRow(.side, sc)
            Divider().background(Color.white.opacity(0.2))
            HStack { Text("Total:").fontWeight(.medium); Spacer(); Text("\(sessions.count) sessions").fontWeight(.semibold) }
            if let last = sessions.last {
                HStack {
                    Text("Done by:").foregroundColor(Color(hex: "10B981"))
                    Spacer()
                    Text(formatter.string(from: last.endTime)).fontWeight(.semibold).foregroundColor(Color(hex: "10B981"))
                }
            }
        }
        .font(.system(size: 13)).foregroundColor(.white.opacity(0.8))
    }
    
    private func countRow(_ type: SessionType, _ count: Int) -> some View {
        HStack { Circle().fill(type.color).frame(width: 8, height: 8); Text("\(type.rawValue):"); Spacer(); Text("\(count)").fontWeight(.medium) }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if !autoPreview {
                Button(action: updatePreview) {
                    HStack { Image(systemName: "eye.fill"); Text("Preview Schedule") }
                        .font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color(hex: "3B82F6")).foregroundColor(.white).cornerRadius(10)
                }.buttonStyle(.plain)
            }
            Button(action: { showingConfirmation = true }) {
                HStack { Image(systemName: "calendar.badge.plus"); Text("Schedule Sessions") }
                    .font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(schedulingEngine.projectedSessions.isEmpty ? Color.gray.opacity(0.3) : Color(hex: "8B5CF6"))
                    .foregroundColor(.white).cornerRadius(10)
            }.buttonStyle(.plain).disabled(schedulingEngine.projectedSessions.isEmpty)
            Button(action: { deletePastSessions = false; showingDeleteConfirmation = true }) {
                HStack { Image(systemName: "trash"); Text("Delete Day's Sessions") }
                    .font(.system(size: 13, weight: .medium)).frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.red.opacity(0.2)).foregroundColor(.red).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.red.opacity(0.3), lineWidth: 1))
            }.buttonStyle(.plain)
        }
    }
}

// MARK: - Delete Confirmation Sheet
struct DeleteConfirmationSheet: View {
    @EnvironmentObject var schedulingEngine: SchedulingEngine
    @Binding var deletePastSessions: Bool
    @Binding var showingSheet: Bool
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Delete Schedule?")
                .font(.title2)
                .bold()
            
            VStack(spacing: 8) {
                Text("This will delete ALL events from the following calendars for the selected day:")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                
                // List calendars
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle().fill(Color(hex: "8B5CF6")).frame(width: 6, height: 6)
                        Text(schedulingEngine.workCalendarName)
                    }
                    HStack {
                        Circle().fill(Color(hex: "3B82F6")).frame(width: 6, height: 6)
                        Text(schedulingEngine.sideCalendarName)
                    }
                    if schedulingEngine.extraSessionConfig.enabled {
                        HStack {
                            Circle().fill(Color(hex: "10B981")).frame(width: 6, height: 6)
                            Text(schedulingEngine.extraSessionConfig.calendarName)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                
                Text("This action cannot be undone.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Toggle(isOn: $deletePastSessions) {
                Text("Delete past events too")
                    .font(.system(size: 13))
            }
            .toggleStyle(.checkbox)
            
            HStack(spacing: 16) {
                Button("Cancel") { showingSheet = false }
                    .keyboardShortcut(.cancelAction)
                
                Button("Delete All") { onDelete(); showingSheet = false }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

#Preview {
    ContentView()
        .environmentObject(CalendarService())
        .environmentObject(SchedulingEngine())
        .frame(width: 1200, height: 800)
}
