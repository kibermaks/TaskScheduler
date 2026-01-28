import SwiftUI
import EventKit
import AppKit

struct AppSettingsView: View {
    @EnvironmentObject var schedulingEngine: SchedulingEngine
    @EnvironmentObject var calendarService: CalendarService
    
    @AppStorage("hasSeenWelcome") var hasSeenWelcome = false
    @AppStorage("hasSeenPatternsGuide") var hasSeenPatternsGuide = false
    @AppStorage("hasSeenTasksGuide") var hasSeenTasksGuide = false
    @AppStorage("timelineIntroBarDismissed") var timelineIntroBarDismissed = false
    @AppStorage("showDevSettings") private var showDevSettings = false
    
    @State private var showingResetPresetsConfirmation = false
    @State private var pendingReplacementContext: CalendarReplacementContext?
    @State private var selectedReplacementCalendarId: String = ""
    @State private var replacementErrorMessage: String?
    
    var body: some View {
        Form {
            Section {
                 HStack(spacing: 8) {
                     Image(systemName: "gearshape.2.fill")
                         .font(.system(size: 24))
                         .foregroundColor(.accentColor)
                     
                     Text("Settings")
                         .font(.system(size: 24, weight: .bold, design: .rounded))
                         .onTapGesture(count: 4) {
                             withAnimation {
                                 showDevSettings.toggle()
                             }
                         }
                     
                     Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"))")
                         .font(.caption)
                         .foregroundColor(.secondary)
                 }
                 .frame(maxWidth: .infinity)
                 .padding(.vertical, 10)
            }
            
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
            
            Section("Calendar Filters") {
                if calendarService.authorizationStatus != .fullAccess {
                    Text("Grant calendar access to manage which calendars contribute busy events.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    let calendars = calendarService.availableCalendars.sorted { $0.title < $1.title }
                    if calendars.isEmpty {
                        Text("No editable calendars available. Create or add calendars in the macOS Calendar app.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {   
                        Text("Unchecked calendars are ignored when fetching busy slots and counting existing sessions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        ForEach(calendars, id: \.calendarIdentifier) { calendar in
                            Toggle(isOn: Binding(
                                get: { !calendarService.isCalendarExcluded(identifier: calendar.calendarIdentifier) },
                                set: { included in
                                    handleCalendarToggle(for: calendar, included: included)
                                }
                            )) {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(color(for: calendar))
                                        .frame(width: 12, height: 12)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(calendar.title)
                                            .font(.body)
                                        Text(calendar.source.title)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Section("Timeline Visibility") {
                Toggle("Hide night hours", isOn: $schedulingEngine.hideNightHours)

                
                LabeledContent("Morning Edge:") {
                    HStack {
                        NumericInputField(value: $schedulingEngine.dayStartHour, range: 0...12, step: 1, unit: "h")
                    }
                }
                .padding(.leading, 10)
                .disabled(!schedulingEngine.hideNightHours)
                
                LabeledContent("Night Edge:") {
                    HStack {
                        NumericInputField(value: $schedulingEngine.dayEndHour, range: 13...24, step: 1, unit: "h")
                    }
                }
                .padding(.leading, 10)
                .disabled(!schedulingEngine.hideNightHours)
                Text("Adjust which hours are visible on the timeline. When enabled, you can set the visible range for morning and night edges.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Tips") {
                Toggle("Show \"Did you know?\" card", isOn: $schedulingEngine.showDidYouKnowCard)
                Text("Displays rotating tips next of how to use the app.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Preset Management") {
                Button(role: .destructive, action: { showingResetPresetsConfirmation = true }) {
                    Label("Reset Presets", systemImage: "arrow.counterclockwise")
                }
                
                Text("This will erase all saved presets and launch Calendar Setup.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if showDevSettings {
                Section("Developer Settings 🛠️") {
                    Button(action: {
                        hasSeenWelcome = false
                        hasSeenPatternsGuide = false
                        hasSeenTasksGuide = false
                        timelineIntroBarDismissed = false
                    }) {
                        Label("Reset All Dirty Triggers", systemImage: "arrow.counterclockwise")
                    }
                    
                    Button(action: resetCalendarSetup) {
                        Label("Reset Calendar Setup", systemImage: "calendar.badge.clock")
                    }
                    
                    Text("This will show the calendar setup screen again for testing.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    Button(role: .destructive, action: resetCalendarPermissions) {
                        Label("Reset Calendar Permissions", systemImage: "lock.slash.fill")
                    }
                    
                    Text("Note: Resetting permissions will immediately terminate the application to clear the system cache.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 550, height: 640)
        .navigationTitle("Settings")
        .preferredColorScheme(.dark)
        .alert("Reset Presets?", isPresented: $showingResetPresetsConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetPresets()
            }
        } message: {
            Text("This will permanently delete all saved presets and launch Calendar Setup to recreate them.")
        }
        .sheet(item: $pendingReplacementContext, onDismiss: {
            selectedReplacementCalendarId = ""
        }) { context in
            CalendarReplacementSheet(
                context: context,
                replacementOptions: replacementOptions(excluding: context.calendar),
                selectedCalendarId: $selectedReplacementCalendarId,
                onCancel: {
                    pendingReplacementContext = nil
                },
                onConfirm: {
                    confirmCalendarReplacement(for: context)
                }
            )
        }
        .alert("Cannot Hide Calendar", isPresented: replacementErrorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(replacementErrorMessage ?? "Unknown issue occurred.")
        }
        .onAppear {
            if let window = NSApp.windows.first(where: { $0.title == "Settings" }) {
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
                // Force window size update as SwiftUI sometimes ignores it after first launch
                window.setContentSize(NSSize(width: 550, height: 640))
            }
        }
    }
    
    private func resetCalendarSetup() {
        UserDefaults.standard.set(false, forKey: "TaskScheduler.HasCompletedSetup")
        // Post notification to trigger refresh in ContentView
        NotificationCenter.default.post(name: Notification.Name("ResetCalendarSetup"), object: nil)
    }
    
    private func resetPresets() {
        UserDefaults.standard.removeObject(forKey: "TaskScheduler.Presets")
        UserDefaults.standard.removeObject(forKey: "TaskScheduler.LastActivePresetID")
        // Reset UI hints
        timelineIntroBarDismissed = false
        // Launch Calendar Setup to recreate presets
        UserDefaults.standard.set(false, forKey: "TaskScheduler.HasCompletedSetup")
        // Post notifications
        NotificationCenter.default.post(name: Notification.Name("PresetsReset"), object: nil)
        NotificationCenter.default.post(name: Notification.Name("ResetCalendarSetup"), object: nil)
        // Close settings window
        if let window = NSApp.windows.first(where: { $0.title == "Settings" }) {
            window.close()
        }
    }
    
    private func resetCalendarPermissions() {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Calendar", bundleId]
        do {
            try process.run()
            // tccutil reset usually kills the app, but let's be sure
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.terminate(nil)
            }
        } catch {
            print("Failed to reset permissions: \(error)")
        }
    }
}

#Preview {
    AppSettingsView()
        .environmentObject(SchedulingEngine())
        .environmentObject(CalendarService())
}

extension AppSettingsView {
    private func color(for calendar: EKCalendar) -> Color {
        if let cgColor = calendar.cgColor,
           let nsColor = NSColor(cgColor: cgColor) {
            return Color(nsColor: nsColor)
        }
        return .gray
    }
    
    private func handleCalendarToggle(for calendar: EKCalendar, included: Bool) {
        if included {
            calendarService.setCalendar(calendar, included: true)
            return
        }
        
        let affectedPresets = presetsUsingCalendar(calendar: calendar)
        guard !affectedPresets.isEmpty else {
            calendarService.setCalendar(calendar, included: false)
            return
        }
        
        let options = replacementOptions(excluding: calendar)
        guard !options.isEmpty else {
            replacementErrorMessage = "No other visible calendars are available to replace \"\(calendar.title)\". Create or enable another calendar first."
            return
        }
        
        selectedReplacementCalendarId = ""
        pendingReplacementContext = CalendarReplacementContext(calendar: calendar, affectedPresets: affectedPresets)
    }
    
    private func presetsUsingCalendar(calendar: EKCalendar) -> [Preset] {
        let presets = PresetStorage.shared.loadPresets()
        return presets.filter { preset in
            preset.calendarMapping.workCalendarIdentifier == calendar.calendarIdentifier ||
            (preset.calendarMapping.workCalendarIdentifier == nil && preset.calendarMapping.workCalendarName == calendar.title) ||
            preset.calendarMapping.sideCalendarIdentifier == calendar.calendarIdentifier ||
            (preset.calendarMapping.sideCalendarIdentifier == nil && preset.calendarMapping.sideCalendarName == calendar.title) ||
            preset.deepSessionConfig.calendarIdentifier == calendar.calendarIdentifier ||
            (preset.deepSessionConfig.calendarIdentifier == nil && preset.deepSessionConfig.calendarName == calendar.title)
        }
    }
    
    private func replacementOptions(excluding calendar: EKCalendar) -> [EKCalendar] {
        calendarService.availableCalendars.filter {
            $0.calendarIdentifier != calendar.calendarIdentifier &&
            !calendarService.isCalendarExcluded(identifier: $0.calendarIdentifier)
        }
    }
    
    private func confirmCalendarReplacement(for context: CalendarReplacementContext) {
        guard
            let replacement = calendarService.availableCalendars.first(where: { $0.calendarIdentifier == selectedReplacementCalendarId })
        else {
            replacementErrorMessage = "Select a replacement calendar before continuing."
            return
        }
        
        applyCalendarReplacement(
            oldCalendar: context.calendar,
            newCalendar: replacement,
            affectedPresetIDs: Set(context.affectedPresets.map { $0.id })
        )
        
        calendarService.setCalendar(context.calendar, included: false)
        pendingReplacementContext = nil
    }
    
    private func applyCalendarReplacement(oldCalendar: EKCalendar, newCalendar: EKCalendar, affectedPresetIDs: Set<UUID>) {
        var presets = PresetStorage.shared.loadPresets()
        var changed = false
        let newIdentifier = newCalendar.calendarIdentifier
        
        for index in presets.indices {
            guard affectedPresetIDs.contains(presets[index].id) else { continue }
            
            if presets[index].calendarMapping.workCalendarIdentifier == oldCalendar.calendarIdentifier ||
                (presets[index].calendarMapping.workCalendarIdentifier == nil && presets[index].calendarMapping.workCalendarName == oldCalendar.title) {
                presets[index].calendarMapping.workCalendarName = newCalendar.title
                presets[index].calendarMapping.workCalendarIdentifier = newIdentifier
                changed = true
            }
            if presets[index].calendarMapping.sideCalendarIdentifier == oldCalendar.calendarIdentifier ||
                (presets[index].calendarMapping.sideCalendarIdentifier == nil && presets[index].calendarMapping.sideCalendarName == oldCalendar.title) {
                presets[index].calendarMapping.sideCalendarName = newCalendar.title
                presets[index].calendarMapping.sideCalendarIdentifier = newIdentifier
                changed = true
            }
            if presets[index].deepSessionConfig.calendarIdentifier == oldCalendar.calendarIdentifier ||
                (presets[index].deepSessionConfig.calendarIdentifier == nil && presets[index].deepSessionConfig.calendarName == oldCalendar.title) {
                presets[index].deepSessionConfig.calendarName = newCalendar.title
                presets[index].deepSessionConfig.calendarIdentifier = newIdentifier
                changed = true
            }
        }
        
        if changed {
            PresetStorage.shared.savePresets(presets)
            NotificationCenter.default.post(name: Notification.Name("PresetsUpdated"), object: nil)
        }
        
        if schedulingEngine.workCalendarIdentifier == oldCalendar.calendarIdentifier ||
            (schedulingEngine.workCalendarIdentifier == nil && schedulingEngine.workCalendarName == oldCalendar.title) {
            schedulingEngine.workCalendarName = newCalendar.title
            schedulingEngine.workCalendarIdentifier = newIdentifier
        }
        if schedulingEngine.sideCalendarIdentifier == oldCalendar.calendarIdentifier ||
            (schedulingEngine.sideCalendarIdentifier == nil && schedulingEngine.sideCalendarName == oldCalendar.title) {
            schedulingEngine.sideCalendarName = newCalendar.title
            schedulingEngine.sideCalendarIdentifier = newIdentifier
        }
        if schedulingEngine.deepSessionConfig.calendarIdentifier == oldCalendar.calendarIdentifier ||
            (schedulingEngine.deepSessionConfig.calendarIdentifier == nil && schedulingEngine.deepSessionConfig.calendarName == oldCalendar.title) {
            var config = schedulingEngine.deepSessionConfig
            config.calendarName = newCalendar.title
            config.calendarIdentifier = newIdentifier
            schedulingEngine.deepSessionConfig = config
        }
    }
    
    private var replacementErrorBinding: Binding<Bool> {
        Binding(
            get: { replacementErrorMessage != nil },
            set: { newValue in
                if !newValue {
                    replacementErrorMessage = nil
                }
            }
        )
    }
}

private struct CalendarReplacementContext: Identifiable {
    let calendar: EKCalendar
    let affectedPresets: [Preset]
    
    var id: String { calendar.calendarIdentifier }
}

private struct CalendarReplacementSheet: View {
    let context: CalendarReplacementContext
    let replacementOptions: [EKCalendar]
    @Binding var selectedCalendarId: String
    let onCancel: () -> Void
    let onConfirm: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reassign Calendar")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("\"\(context.calendar.title)\" is used in the presets below. Choose a replacement calendar before hiding it.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            if !context.affectedPresets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Affected Presets (\(context.affectedPresets.count))")
                        .font(.headline)
                    ForEach(context.affectedPresets) { preset in
                        HStack(spacing: 6) {
                            Image(systemName: preset.icon)
                                .foregroundColor(.accentColor)
                                .frame(width: 18)
                            Text(preset.name)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(8)
                    }
                }
            }
            
            Picker("Replacement Calendar", selection: $selectedCalendarId) {
                Text("Select a calendar…").tag("")
                ForEach(replacementOptions, id: \.calendarIdentifier) { option in
                    Text(option.title).tag(option.calendarIdentifier)
                }
            }
            .pickerStyle(.menu)
            
            Spacer(minLength: 0)
            
            HStack {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                Spacer()
                Button("Replace & Hide") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCalendarId.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 380)
    }
}
