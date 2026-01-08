import SwiftUI

struct AppSettingsView: View {
    @EnvironmentObject var schedulingEngine: SchedulingEngine
    
    var body: some View {
        Form {
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
