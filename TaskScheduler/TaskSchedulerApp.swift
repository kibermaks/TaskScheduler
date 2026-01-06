import SwiftUI

@main
struct TaskSchedulerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var calendarService = CalendarService()
    @StateObject private var schedulingEngine = SchedulingEngine()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(calendarService)
                .environmentObject(schedulingEngine)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        Settings {
            AppSettingsView()
                .environmentObject(schedulingEngine)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

struct AppSettingsView: View {
    @EnvironmentObject var schedulingEngine: SchedulingEngine
    
    var body: some View {
        Form {
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
            }
            
            Section {
                Text("These settings control the visible range of the timeline when 'Hide Night Hours' is enabled.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
    }
}

