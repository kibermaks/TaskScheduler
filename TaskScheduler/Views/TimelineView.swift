import SwiftUI

struct TimelineView: View {
    let selectedDate: Date
    let startTime: Date
    
    @EnvironmentObject var calendarService: CalendarService
    @EnvironmentObject var schedulingEngine: SchedulingEngine
    
    private let hourHeight: CGFloat = 90 // Zoomed in from 60
    private let timeColumnWidth: CGFloat = 55
    
    
    // Detail Sheet State
    @State private var selectedSession: ScheduledSession?
    @State private var selectedBusySlot: BusyTimeSlot?
    
    // Inline Editing State (only for BusyTimeSlot)
    @State private var editingTitle: String?
    @State private var editingNotes: String?
    @State private var editingURL: String?
    @FocusState private var focusedField: EditField?
    
    enum EditField {
        case title
        case notes
        case url
    }
    
    // Width tracking for adaptive UI - default to 0 to start compact
    @State private var containerWidth: CGFloat = 0
    @State private var showingLegendPopover = false
    
    private var isNarrow: Bool {
        // Use a reasonable threshold for narrow width
        containerWidth < 600
    }

    private var isExtraNarrow: Bool {
        // Use a reasonable threshold for narrow width
        containerWidth < 400
    }
    
    private var showingDetailSheet: Bool {
        selectedSession != nil || selectedBusySlot != nil
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack(alignment: .leading, spacing: 12) {
                    headerView
                    timelineScrollView
                }
                
                // Detail sheet overlay
                if showingDetailSheet {
                    detailSheetOverlay
                }
            }
            .onAppear {
                containerWidth = geo.size.width
            }
            .onChange(of: geo.size.width) { _, newWidth in
                containerWidth = newWidth
            }
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Text(formattedDate)
                .font(.system(size: isNarrow ? 17 : 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
            
            Spacer(minLength: 8)
            
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
                .padding(.vertical, 20)
                .frame(height: CGFloat(visibleHours.count) * hourHeight + 40)
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
            .clipped()
        }
    }
    
    private var hourGridLines: some View {
        VStack(spacing: 0) {
            ForEach(visibleHours, id: \.self) { _ in
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                    Spacer()
                }
                .frame(height: hourHeight)
            }
            // Bottom edge line
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
        }
    }
    
    private func scrollToStartTime(proxy: ScrollViewProxy) {
        let hour = Calendar.current.component(.hour, from: startTime)
        let visibleStart = schedulingEngine.hideNightHours ? schedulingEngine.dayStartHour : 0
        let targetHour = max(visibleStart, hour)
        proxy.scrollTo("hour-\(targetHour)", anchor: .center)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        if isExtraNarrow {
            formatter.dateFormat = "MMM d, yyyy"
        } else {
            formatter.dateFormat = "EEEE, MMMM d, yyyy"
        }
        return formatter.string(from: selectedDate)
    }
    
    private var legendView: some View {
        HStack(spacing: 12) {
            if isNarrow {
                // Compact Legend: Just the "Legend" button, no color boxes
                Button {
                    showingLegendPopover.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text("Legend")
                            .font(.system(size: 11, weight: .bold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .black))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.15))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingLegendPopover, arrowEdge: .bottom) {
                    legendPopoverContent
                }
            } else {
                // Wide Legend: Dots with labels
                HStack(spacing: 16) {
                    ForEach(SessionType.allCases) { type in
                        legendItem(color: type.color, label: type.rawValue)
                    }
                }
            }
            
            // Toggle night button
            Button(action: {
                withAnimation {
                    schedulingEngine.hideNightHours.toggle()
                }
            }) {
                Image(systemName: schedulingEngine.hideNightHours ? "moon.stars.fill" : "moon.stars")
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help(schedulingEngine.hideNightHours ? "Show 00:00 - 06:00" : "Hide 00:00 - 06:00")
        }
    }
    
    private var legendPopoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session Types")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            
            Divider().background(Color.white.opacity(0.1))
            
            ForEach(SessionType.allCases) { type in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(type.color)
                        .frame(width: 14, height: 14)
                    Text(type.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                }
            }
        }
        .padding(12)
        .frame(width: 160)
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

private struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension TimelineView {
    
    private var timeColumnView: some View {
        VStack(spacing: 0) {
            ForEach(visibleHours, id: \.self) { hour in
                HStack {
                    Text(formattedHour(hour))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .offset(y: -7)
                }
                .frame(width: timeColumnWidth, height: hourHeight, alignment: .topTrailing)
                .padding(.trailing, 8)
                .id("hour-\(hour)")
            }
            
            // End of day mark
            HStack {
                let endHour = schedulingEngine.hideNightHours ? schedulingEngine.dayEndHour : 24
                Text(formattedHour(endHour))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .offset(y: -7)
            }
            .frame(width: timeColumnWidth, height: 0, alignment: .topTrailing)
            .padding(.trailing, 8)
        }
    }
    
    private func formattedHour(_ hour: Int) -> String {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = hour
        
        // Handle hour 24 and beyond for formatting by shifting to next day
        if hour >= 24 {
            components.hour = hour - 24
            if let date = calendar.date(from: components),
               let nextDay = calendar.date(byAdding: .day, value: 1, to: date) {
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                return formatter.string(from: nextDay)
            }
        }
        
        
        if let date = calendar.date(from: components) {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
    
    private var visibleHours: [Int] {
        if schedulingEngine.hideNightHours {
            return Array(schedulingEngine.dayStartHour..<schedulingEngine.dayEndHour)
        } else {
            return Array(0..<24)
        }
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
        let blockHeight = max(height, 20)
        
        // Calculate center position for .position() modifier
        let centerX = 8 + blockWidth / 2
        let centerY = yPos + blockHeight / 2
        
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
                
                if let notes = slot.notes, !notes.isEmpty, height > 45 {
                    Text(notes)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(4)
        }
        .frame(width: blockWidth, height: blockHeight)
        .position(x: centerX, y: centerY)
        .onTapGesture(count: 2) {
            selectedSession = nil
            selectedBusySlot = slot
        }
        .contextMenu {
            Button("View Details") {
                selectedSession = nil
                selectedBusySlot = slot
            }
        }
    }
    
    // MARK: - Projected Session Block - Right Half with Tooltip
    
    private func projectedSessionBlock(for session: ScheduledSession, containerWidth: CGFloat) -> some View {
        let yPos = calculateYPosition(for: session.startTime)
        let height = calculateHeight(from: session.startTime, to: session.endTime)
        let blockHeight = max(height, 20)
        let blockWidth = (containerWidth / 2) - 16
        let xOffset = containerWidth / 2 + 8
        let isCompact = height < 40
        
        // Calculate center position for .position() modifier
        let centerX = xOffset + blockWidth / 2
        let centerY = yPos + blockHeight / 2
        
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(session.type.color.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
                        .foregroundColor(session.type.color)
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
                    
                    if height > 65 {
                        Text("\(session.durationMinutes) min")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(4)
            }
        }
        .frame(width: blockWidth, height: blockHeight)
        .position(x: centerX, y: centerY)
        .onTapGesture(count: 2) {
            selectedBusySlot = nil
            selectedSession = session
        }
        .contextMenu {
            Button("View Details") {
                selectedBusySlot = nil
                selectedSession = session
            }
        }
    }
    
    // MARK: - Detail Sheet Overlay
    
    private var detailSheetOverlay: some View {
        ZStack {
            // Dimmed background - click to dismiss
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedSession = nil
                        selectedBusySlot = nil
                        resetEditingState()
                    }
                }
            
            // Detail card
            VStack(alignment: .leading, spacing: 12) {
                if let session = selectedSession {
                    sessionDetailContent(session)
                } else if let slot = selectedBusySlot {
                    busySlotDetailContent(slot)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "1E293B"))
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            )
            .frame(maxWidth: 280)
            .transition(.scale.combined(with: .opacity))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingDetailSheet)
    }
    
    private func sessionDetailContent(_ session: ScheduledSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: session.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(session.type.color)
                Text(session.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    selectedSession = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            VStack(alignment: .leading, spacing: 10) {
                Label(timeRangeString(start: session.startTime, end: session.endTime), systemImage: "clock")
                Label("\(session.durationMinutes) minutes", systemImage: "hourglass")
                Label(session.calendarName, systemImage: "calendar")
                Label(session.type.rawValue, systemImage: "tag")
            }
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private func busySlotDetailContent(_ slot: BusyTimeSlot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 18))
                    .foregroundColor(slot.calendarColor)
                
                // Inline editable title
                if let editingTitle = editingTitle {
                    TextField("Event title", text: Binding(
                        get: { editingTitle },
                        set: { self.editingTitle = $0 }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .focused($focusedField, equals: .title)
                    .onSubmit {
                        saveTitle(for: slot, newTitle: editingTitle)
                    }
                } else {
                    Text(slot.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .onTapGesture {
                            editingTitle = slot.title
                            focusedField = .title
                        }
                }
                
                Spacer()
                Button {
                    selectedBusySlot = nil
                    resetEditingState()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            VStack(alignment: .leading, spacing: 10) {
                Label(timeRangeString(start: slot.startTime, end: slot.endTime), systemImage: "clock")
                Label(slot.calendarName, systemImage: "tray")
                
                // Notes section with inline editing
                VStack(alignment: .leading, spacing: 4) {
                    Divider().background(Color.white.opacity(0.1))
                    
                    if let editingNotes = editingNotes {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes:")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                            TextEditor(text: Binding(
                                get: { editingNotes },
                                set: { self.editingNotes = $0 }
                            ))
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(4)
                            .frame(minHeight: 60, maxHeight: 100)
                            .focused($focusedField, equals: .notes)
                        }
                    } else if let notes = slot.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes:")
                                .font(.system(size: 12, weight: .bold))
                            Text(notes)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .onTapGesture {
                            editingNotes = notes
                            focusedField = .notes
                        }
                    } else {
                        Button {
                            editingNotes = ""
                            focusedField = .notes
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 11))
                                Text("Add note")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // URL section with inline editing
                VStack(alignment: .leading, spacing: 4) {
                    Divider().background(Color.white.opacity(0.1))
                    
                    if let editingURL = editingURL {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("URL:")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                            TextField("https://example.com", text: Binding(
                                get: { editingURL },
                                set: { self.editingURL = $0 }
                            ))
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(6)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(4)
                            .focused($focusedField, equals: .url)
                            .onSubmit {
                                saveURL(for: slot, newURL: editingURL)
                            }
                        }
                    } else if let url = slot.url {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("URL:")
                                .font(.system(size: 12, weight: .bold))
                            Link(url.absoluteString, destination: url)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "3B82F6"))
                                .lineLimit(1)
                        }
                        .onTapGesture {
                            editingURL = url.absoluteString
                            focusedField = .url
                        }
                    } else {
                        Button {
                            editingURL = ""
                            focusedField = .url
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 11))
                                Text("Add URL")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.8))
        }
        .onChange(of: focusedField) { oldValue, newValue in
            // Auto-save when focus leaves a field
            if oldValue == .title && newValue != .title, let title = editingTitle {
                saveTitle(for: slot, newTitle: title)
            }
            if oldValue == .notes && newValue != .notes, let notes = editingNotes {
                saveNotes(for: slot, newNotes: notes)
            }
            if oldValue == .url && newValue != .url, let urlString = editingURL {
                saveURL(for: slot, newURL: urlString)
            }
        }
    }
    
    // MARK: - Position Calculations
    
    private func calculateYPosition(for date: Date) -> CGFloat {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let secondsSinceStart = date.timeIntervalSince(dayStart)
        let hours = secondsSinceStart / 3600
        
        let finalHours = hours - (schedulingEngine.hideNightHours ? CGFloat(schedulingEngine.dayStartHour) : 0)
        return finalHours * hourHeight
    }
    
    
    
    private func calculateHeight(from start: Date, to end: Date) -> CGFloat {
        let duration = end.timeIntervalSince(start)
        let hours = duration / 3600
        return CGFloat(hours) * hourHeight
    }
    
    private func timeRangeString(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    // MARK: - Inline Editing Helpers
    
    private func saveTitle(for slot: BusyTimeSlot, newTitle: String) {
        guard !newTitle.isEmpty else {
            editingTitle = nil
            return
        }
        
        let success = calendarService.updateEvent(
            eventId: slot.id,
            title: newTitle,
            notes: nil,
            url: nil
        )
        
        if success {
            Task {
                await calendarService.fetchEvents(for: selectedDate)
                editingTitle = nil
            }
        }
    }
    
    private func saveNotes(for slot: BusyTimeSlot, newNotes: String) {
        let notesToSave = newNotes.isEmpty ? nil : newNotes
        
        let success = calendarService.updateEvent(
            eventId: slot.id,
            title: nil,
            notes: notesToSave,
            url: nil
        )
        
        if success {
            Task {
                await calendarService.fetchEvents(for: selectedDate)
                editingNotes = nil
            }
        }
    }
    
    private func saveURL(for slot: BusyTimeSlot, newURL: String) {
        let urlToSave: URL?
        if newURL.isEmpty {
            urlToSave = nil
        } else {
            // Try to create URL, add https:// if no scheme
            var urlString = newURL.trimmingCharacters(in: .whitespaces)
            if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
                urlString = "https://" + urlString
            }
            urlToSave = URL(string: urlString)
        }
        
        let success = calendarService.updateEvent(
            eventId: slot.id,
            title: nil,
            notes: nil,
            url: urlToSave
        )
        
        if success {
            Task {
                await calendarService.fetchEvents(for: selectedDate)
                editingURL = nil
            }
        }
    }
    
    private func resetEditingState() {
        editingTitle = nil
        editingNotes = nil
        editingURL = nil
        focusedField = nil
    }
}

#Preview {
    TimelineView(selectedDate: Date(), startTime: Date())
        .environmentObject(CalendarService())
        .environmentObject(SchedulingEngine())
        .frame(width: 600, height: 800)
        .background(Color(hex: "0F172A"))
}
