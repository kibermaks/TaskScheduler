import SwiftUI

struct CalendarPermissionView: View {
    @EnvironmentObject var calendarService: CalendarService
    @State private var isRequesting = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "0F172A"), Color(hex: "1E293B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icon
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 80))
                    .foregroundColor(Color(hex: "EF4444"))
                    .symbolEffect(.bounce, value: isRequesting)
                
                VStack(spacing: 16) {
                    Text("Calendar Access Required")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Task Scheduler needs access to your calendar to schedule sessions and detect busy time slots.")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Permission steps
                VStack(alignment: .leading, spacing: 16) {
                    permissionStep(
                        icon: "1.circle.fill",
                        title: "Grant Access",
                        description: "Click the button below to authorize calendar access"
                    )
                    permissionStep(
                        icon: "2.circle.fill",
                        title: "Configure Calendars",
                        description: "Select which calendars to use for different session types"
                    )
                    permissionStep(
                        icon: "3.circle.fill",
                        title: "Start Scheduling",
                        description: "Begin optimizing your day with smart session planning"
                    )
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Request button
                Button {
                    requestPermission()
                } label: {
                    HStack(spacing: 12) {
                        if isRequesting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Text(isRequesting ? "Requesting Access..." : "Grant Calendar Access")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 280)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "EF4444"))
                            .shadow(color: Color(hex: "EF4444").opacity(0.4), radius: 10, y: 5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isRequesting)
                .padding(.bottom, 40)
            }
        }
        .frame(width: 600, height: 700)
    }
    
    private func permissionStep(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color(hex: "8B5CF6"))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func requestPermission() {
        isRequesting = true
        Task {
            let granted = await calendarService.requestAccess()
            await MainActor.run {
                isRequesting = false
                if granted {
                    // Permission granted, the app will automatically transition to setup
                }
            }
        }
    }
}

#Preview {
    CalendarPermissionView()
        .environmentObject(CalendarService())
}
