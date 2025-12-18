import SwiftUI

struct TimelineView: View {
    let selectedDate: Date
    let startTime: Date
    
    @EnvironmentObject var calendarService: CalendarService
    @EnvironmentObject var schedulingEngine: SchedulingEngine
    
    private let hourHeight: CGFloat = 90 // Zoomed in from 60
    private let timeColumnWidth: CGFloat = 70
    
    // Popover State
    @State private var selectedSession: ScheduledSession?
    @State private var selectedBusySlot: BusyTimeSlot?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            timelineScrollView
        }
    }
    
    private var headerView: some View {
        HStack {
            Text(formattedDate)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            if calendarService.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
            }
            
            legendView
        }
    }
    
    private var timelineScrollView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            ScrollViewReader { proxy in
                HStack(alignment: .top, spacing: 0) {
                    timeColumnView
                    eventsAreaView
                }
                .frame(height: 24 * hourHeight)
                .onAppear { scrollToStartTime(proxy: proxy) }
                .onChange(of: startTime) { _, _ in scrollToStartTime(proxy: proxy) }
            }
        }
        .background(Color.white.opacity(0.02))
        .cornerRadius(12)
    }
    
    private var eventsAreaView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                hourGridLines
                
                if Calendar.current.isDateInToday(selectedDate) {
                    currentTimeIndicator(width: geometry.size.width)
                }
                
                // Existing events - left half
                ForEach(calendarService.busySlots) { slot in
                    eventBlock(for: slot, containerWidth: geometry.size.width)
                }
                
                // Projected sessions - right half
                ForEach(schedulingEngine.projectedSessions) { session in
                    projectedSessionBlock(for: session, containerWidth: geometry.size.width)
                }
            }
        }
    }
    
    private var hourGridLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { _ in
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                    Spacer()
                }
                .frame(height: hourHeight)
            }
        }
    }
    
    private func scrollToStartTime(proxy: ScrollViewProxy) {
        let hour = Calendar.current.component(.hour, from: startTime)
        proxy.scrollTo("hour-\(max(0, hour - 1))", anchor: .top)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: selectedDate)
    }
    
    private var legendView: some View {
        HStack(spacing: 16) {
            legendItem(color: Color(hex: "8B5CF6"), label: "Work")
            legendItem(color: Color(hex: "3B82F6"), label: "Side")
            legendItem(color: Color(hex: "EF4444"), label: "Planning")
            legendItem(color: Color(hex: "10B981"), label: "Extra")
            // legendItem(color: Color.gray.opacity(0.6), label: "Busy")
        }
        .font(.system(size: 12))
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private var timeColumnView: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack {
                    Spacer()
                    Text(formattedHour(hour))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(width: timeColumnWidth, height: hourHeight, alignment: .topTrailing)
                .padding(.trailing, 8)
                .id("hour-\(hour)")
            }
        }
    }
    
    private func formattedHour(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }
    
    private func currentTimeIndicator(width: CGFloat) -> some View {
        let yPos = calculateYPosition(for: Date())
        
        return HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
            
            Rectangle()
                .fill(Color.red)
                .frame(width: width - 10, height: 2)
        }
        .offset(x: 0, y: yPos)
    }
    
    // ... (rest of file)
    
    // MARK: - Event Block (Busy) - Left Half
    
    private func eventBlock(for slot: BusyTimeSlot, containerWidth: CGFloat) -> some View {
        let yPos = calculateYPosition(for: slot.startTime)
        let height = calculateHeight(from: slot.startTime, to: slot.endTime)
        let blockWidth = (containerWidth / 2) - 16
        
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(slot.calendarColor.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(slot.calendarColor.opacity(0.5), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 1) {
                Text(slot.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if height > 25 {
                    Text(timeRangeString(start: slot.startTime, end: slot.endTime))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(4)
        }
        .frame(width: blockWidth, height: max(height, 20))
        .offset(x: 8, y: yPos)
        .onTapGesture {
            selectedBusySlot = slot
        }
        .popover(item: $selectedBusySlot) { slot in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(slot.calendarColor)
                    Text(slot.title)
                        .font(.headline)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Label(timeRangeString(start: slot.startTime, end: slot.endTime), systemImage: "clock")
                    Label(slot.calendarName, systemImage: "tray")
                }
                .font(.callout)
            }
            .padding()
            .frame(width: 250)
        }
    }
    
    // MARK: - Projected Session Block - Right Half with Tooltip
    
    private func projectedSessionBlock(for session: ScheduledSession, containerWidth: CGFloat) -> some View {
        let yPos = calculateYPosition(for: session.startTime)
        let height = calculateHeight(from: session.startTime, to: session.endTime)
        let blockWidth = (containerWidth / 2) - 16
        let xOffset = containerWidth / 2 + 8
        let isCompact = height < 40
        
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(session.type.color.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(session.type.color, lineWidth: 2)
                )
                .shadow(color: session.type.color.opacity(0.3), radius: 3, y: 1)
            
            if isCompact {
                HStack(spacing: 3) {
                    Image(systemName: session.type.icon)
                        .font(.system(size: 10))
                    Text(session.title)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundColor(.white)
                .padding(3)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        Image(systemName: session.type.icon)
                            .font(.system(size: 11))
                        Text(session.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(.white)
                    
                    Text(timeRangeString(start: session.startTime, end: session.endTime))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    if height > 55 {
                        Text("\(session.durationMinutes) min")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(4)
            }
        }
        .frame(width: blockWidth, height: max(height, 20))
        .offset(x: xOffset, y: yPos)
        .onTapGesture {
            selectedSession = session
        }
        .popover(item: $selectedSession) { session in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: session.type.icon)
                        .foregroundColor(session.type.color)
                    Text(session.title)
                        .font(.headline)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Label(timeRangeString(start: session.startTime, end: session.endTime), systemImage: "clock")
                    Label("\(session.durationMinutes) minutes", systemImage: "hourglass")
                    Label(session.calendarName, systemImage: "calendar")
                    Label(session.type.rawValue, systemImage: "tag")
                }
                .font(.callout)
            }
            .padding()
            .frame(width: 250)
        }
    }
    
    // MARK: - Position Calculations
    
    private func calculateYPosition(for date: Date) -> CGFloat {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let secondsSinceStart = date.timeIntervalSince(dayStart)
        let hours = secondsSinceStart / 3600
        return CGFloat(hours) * hourHeight
    }
    
    private func calculateHeight(from start: Date, to end: Date) -> CGFloat {
        let duration = end.timeIntervalSince(start)
        let hours = duration / 3600
        return CGFloat(hours) * hourHeight
    }
    
    private func timeRangeString(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

#Preview {
    TimelineView(selectedDate: Date(), startTime: Date())
        .environmentObject(CalendarService())
        .environmentObject(SchedulingEngine())
        .frame(width: 600, height: 800)
        .background(Color(hex: "0F172A"))
}
