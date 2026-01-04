import SwiftUI

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
        .navigationTitle("Settings")
    }
}

#Preview {
    AppSettingsView()
        .environmentObject(SchedulingEngine())
}
