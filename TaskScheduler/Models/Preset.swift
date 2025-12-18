import Foundation

// MARK: - Calendar Mapping for Presets
struct CalendarMapping: Codable, Equatable {
    var workCalendarName: String
    var sideCalendarName: String
    
    static let `default` = CalendarMapping(
        workCalendarName: "Work",
        sideCalendarName: "Side Tasks"
    )
}

// MARK: - Extra Session Configuration
struct ExtraSessionConfig: Codable, Equatable {
    var enabled: Bool
    var sessionCount: Int
    var injectAfterEvery: Int
    var name: String
    var duration: Int
    var calendarName: String
    
    static let `default` = ExtraSessionConfig(
        enabled: false,
        sessionCount: 1,
        injectAfterEvery: 3,
        name: "Extra Session",
        duration: 15,
        calendarName: "Work" // Default to Work calendar
    )
}

// MARK: - Preset Configuration
struct Preset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    
    // Session counts
    var workSessionCount: Int
    var sideSessionCount: Int
    
    // Session names
    var workSessionName: String
    var sideSessionName: String
    
    // Durations (in minutes)
    var workSessionDuration: Int
    var sideSessionDuration: Int
    var planningDuration: Int
    var restDuration: Int // Default Work rest
    var sideRestDuration: Int // Rest after side session
    var extraRestDuration: Int // Rest after extra session
    
    // Scheduling options
    var schedulePlanning: Bool
    var pattern: SchedulePattern
    var workSessionsPerCycle: Int
    var sideSessionsPerCycle: Int // For Custom Ratio
    var sideFirst: Bool // For Custom Ratio
    
    // Extra Sessions
    var extraSessionConfig: ExtraSessionConfig
    
    // Calendar mapping
    var calendarMapping: CalendarMapping
    
    // Default start hour for future days
    var defaultStartHour: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "calendar",
        workSessionCount: Int = 5,
        sideSessionCount: Int = 2,
        workSessionName: String = "Work Session",
        sideSessionName: String = "Side Session",
        workSessionDuration: Int = 40,
        sideSessionDuration: Int = 30,
        planningDuration: Int = 15,
        restDuration: Int = 20,
        sideRestDuration: Int? = nil, // Optional in init, defaults to 75% of restDuration
        extraRestDuration: Int? = nil,
        schedulePlanning: Bool = true,
        pattern: SchedulePattern = .alternating,
        workSessionsPerCycle: Int = 2,
        sideSessionsPerCycle: Int = 1,
        sideFirst: Bool = false,
        extraSessionConfig: ExtraSessionConfig = .default,
        calendarMapping: CalendarMapping = .default,
        defaultStartHour: Int = 8
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.workSessionCount = workSessionCount
        self.sideSessionCount = sideSessionCount
        self.workSessionName = workSessionName
        self.sideSessionName = sideSessionName
        self.workSessionDuration = workSessionDuration
        self.sideSessionDuration = sideSessionDuration
        self.planningDuration = planningDuration
        self.restDuration = restDuration
        
        // Default side rest to 75% of work rest (rounded to nearest 5 mins if possible, but keeping simple int math here)
        self.sideRestDuration = sideRestDuration ?? max(5, Int(Double(restDuration) * 0.75))
        self.extraRestDuration = extraRestDuration ?? restDuration
        
        self.schedulePlanning = schedulePlanning
        self.pattern = pattern
        self.workSessionsPerCycle = workSessionsPerCycle
        self.sideSessionsPerCycle = sideSessionsPerCycle
        self.sideFirst = sideFirst
        self.extraSessionConfig = extraSessionConfig
        self.calendarMapping = calendarMapping
        self.defaultStartHour = defaultStartHour
    }
    
    // MARK: - Default Presets
    static let defaultWorkday = Preset(
        name: "Standard Workday",
        icon: "briefcase.fill",
        workSessionCount: 5,
        sideSessionCount: 2,
        pattern: .alternating,
        calendarMapping: CalendarMapping(
            workCalendarName: "Work",
            sideCalendarName: "Side Tasks"
        )
    )
    
    static let focusDay = Preset(
        name: "Focus Day",
        icon: "brain.head.profile",
        workSessionCount: 7,
        sideSessionCount: 1,
        workSessionDuration: 50,
        restDuration: 10,
        pattern: .allWorkFirst,
        calendarMapping: CalendarMapping(
            workCalendarName: "Work",
            sideCalendarName: "Side Tasks"
        )
    )
    
    static let weekend = Preset(
        name: "Weekend",
        icon: "sun.max.fill",
        workSessionCount: 2,
        sideSessionCount: 4,
        workSessionName: "Weekend Work",
        sideSessionName: "Weekend Side",
        workSessionDuration: 30,
        sideSessionDuration: 45,
        schedulePlanning: false,
        pattern: .allSideFirst,
        calendarMapping: CalendarMapping(
            workCalendarName: "Weekend Work",
            sideCalendarName: "Weekend Side"
        ),
        defaultStartHour: 10
    )
    
    static let lightDay = Preset(
        name: "Light Day",
        icon: "leaf.fill",
        workSessionCount: 3,
        sideSessionCount: 2,
        workSessionDuration: 30,
        restDuration: 30,
        pattern: .alternating,
        calendarMapping: CalendarMapping(
            workCalendarName: "Work",
            sideCalendarName: "Side Tasks"
        )
    )
    
    static let initialPresets: [Preset] = [
        .defaultWorkday,
        .focusDay,
        .weekend,
        .lightDay
    ]
}

// MARK: - Preset Storage Manager
class PresetStorage {
    static let shared = PresetStorage()
    private let presetsKey = "TaskScheduler.Presets"
    private let lastActivePresetKey = "TaskScheduler.LastActivePresetID"
    
    private init() {}
    
    func loadPresets() -> [Preset] {
        if let data = UserDefaults.standard.data(forKey: presetsKey),
           let presets = try? JSONDecoder().decode([Preset].self, from: data),
           !presets.isEmpty {
            return presets
        }
        // If empty, return the initial defaults
        return Preset.initialPresets
    }
    
    func savePresets(_ presets: [Preset]) {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: presetsKey)
    }
    
    func addPreset(_ preset: Preset) {
        var presets = loadPresets()
        presets.append(preset)
        savePresets(presets)
    }
    
    func updatePreset(_ updatedPreset: Preset) {
        var presets = loadPresets()
        if let index = presets.firstIndex(where: { $0.id == updatedPreset.id }) {
            presets[index] = updatedPreset
            savePresets(presets)
        }
    }
    
    func deletePreset(_ preset: Preset) {
        var presets = loadPresets()
        presets.removeAll { $0.id == preset.id }
        savePresets(presets)
    }
    
    // MARK: - Persistence of Selection
    
    func saveLastActivePresetId(_ id: UUID?) {
        if let id = id {
            UserDefaults.standard.set(id.uuidString, forKey: lastActivePresetKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastActivePresetKey)
        }
    }
    
    func loadLastActivePresetId() -> UUID? {
        guard let str = UserDefaults.standard.string(forKey: lastActivePresetKey) else { return nil }
        return UUID(uuidString: str)
    }
}
