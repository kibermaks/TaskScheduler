import SwiftUI

struct AppSettingsView: View {
    @EnvironmentObject var schedulingEngine: SchedulingEngine
    
    @AppStorage("hasSeenWelcome") var hasSeenWelcome = false
    @AppStorage("hasSeenPatternsGuide") var hasSeenPatternsGuide = false
    @AppStorage("hasSeenTasksGuide") var hasSeenTasksGuide = false
    
    @State private var showDevSettings = false
    
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
                     
                     Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
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
            
            Section("Timeline Visibility") {
                Toggle("Hide night hours", isOn: $schedulingEngine.hideNightHours)
                
                HStack {
                    Text("Morning Edge:")
                    Spacer()
                    NumericInputField(value: $schedulingEngine.dayStartHour, range: 0...12, unit: "h")
                }
                .disabled(!schedulingEngine.hideNightHours)
                
                HStack {
                    Text("Night Edge:")
                    Spacer()
                    NumericInputField(value: $schedulingEngine.dayEndHour, range: 13...24, unit: "h")
                }
                .disabled(!schedulingEngine.hideNightHours)
            }
            
            Section {
                Text("These settings control the visible range of the timeline when 'Hide Night Hours' is enabled.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if showDevSettings {
                Section("Developer Settings 🛠️") {
                    Button(action: {
                        hasSeenWelcome = false
                        hasSeenPatternsGuide = false
                        hasSeenTasksGuide = false
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
}
