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
                                    calendarService.setCalendar(calendar, included: included)
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
}
