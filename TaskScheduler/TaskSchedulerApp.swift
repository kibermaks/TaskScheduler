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
            Text("TaskScheduler Settings")
                .padding()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
