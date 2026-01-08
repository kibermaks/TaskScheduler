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
            CommandGroup(after: .help) {
                Button("Welcome Guide...") {
                    NotificationCenter.default.post(name: Notification.Name("ShowWelcomeScreen"), object: nil)
                }
                .keyboardShortcut("?", modifiers: .command)
                
                Button("Patterns Strategy...") {
                    NotificationCenter.default.post(name: Notification.Name("ShowPatternsGuide"), object: nil)
                }
                
                Button("Organizing Tasks...") {
                    NotificationCenter.default.post(name: Notification.Name("ShowTasksGuide"), object: nil)
                }
            }
        }
        
        Settings {
            AppSettingsView()
                .environmentObject(schedulingEngine)
        }
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

