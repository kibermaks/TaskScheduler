import SwiftUI

struct TasksPanel: View {
    @EnvironmentObject var schedulingEngine: SchedulingEngine
    
    @StateObject private var workAction = TaskEditorAction()
    @StateObject private var sideAction = TaskEditorAction()
    @StateObject private var deepAction = TaskEditorAction()
    
    @State private var isWorkFocused = false
    @State private var isSideFocused = false
    @State private var isDeepFocused = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                taskSection(
                    title: "Work Tasks",
                    icon: "briefcase.fill",
                    iconColor: Color(hex: "8B5CF6"),
                    isEnabled: $schedulingEngine.useWorkTasks,
                    text: $schedulingEngine.workTasks,
                    action: workAction,
                    isFocused: $isWorkFocused
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                taskSection(
                    title: "Side Tasks",
                    icon: "star.fill",
                    iconColor: Color(hex: "3B82F6"),
                    isEnabled: $schedulingEngine.useSideTasks,
                    text: $schedulingEngine.sideTasks,
                    action: sideAction,
                    isFocused: $isSideFocused
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                taskSection(
                    title: "Deep Tasks",
                    icon: "bolt.circle.fill",
                    iconColor: Color(hex: "10B981"),
                    isEnabled: $schedulingEngine.useDeepTasks,
                    text: $schedulingEngine.deepTasks,
                    action: deepAction,
                    isFocused: $isDeepFocused
                )
            }
            .padding()
        }
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
    
    private func taskSection(
        title: String,
        icon: String,
        iconColor: Color,
        isEnabled: Binding<Bool>,
        text: Binding<String>,
        action: TaskEditorAction,
        isFocused: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(iconColor)
            }
            
            HStack(alignment: .top, spacing: 12) {
                TaskEditor(text: text, isFocused: isFocused, action: action)
                    .frame(height: 120)
                
                VStack(spacing: 8) {
                    reorderButton(icon: "chevron.up", isEnabled: isFocused.wrappedValue, action: { action.moveUp.send() })
                    reorderButton(icon: "chevron.down", isEnabled: isFocused.wrappedValue, action: { action.moveDown.send() })
                    Spacer()
                }
            }
            
            Text("One title per line. Use Ctrl + Cmd + Up/Down to reorder.")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
        }
    }
    
    private func reorderButton(icon: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isEnabled ? .white : .white.opacity(0.2))
                .frame(width: 24, height: 24)
                .background(isEnabled ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

#Preview {
    TasksPanel()
        .environmentObject(SchedulingEngine())
        .frame(width: 320, height: 600)
        .background(Color(hex: "0F172A"))
}
