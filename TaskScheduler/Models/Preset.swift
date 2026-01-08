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

// MARK: - Deep Session Configuration
struct DeepSessionConfig: Codable, Equatable {
    var enabled: Bool
    var sessionCount: Int
    var injectAfterEvery: Int
    var name: String
    var duration: Int
    var calendarName: String
    
    static let `default` = DeepSessionConfig(
        enabled: false,
        sessionCount: 1,
        injectAfterEvery: 3,
        name: "Deep Session",
        duration: 15,
        calendarName: "Work"
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
    var sideSessionsPerCycle: Int // For Custom Ratio
    var sideFirst: Bool // For Custom Ratio
    
    var deepSessionConfig: DeepSessionConfig
    
    var calendarMapping: CalendarMapping
    
    var deepRestDuration: Int
    
    var restDuration: Int
    var sideRestDuration: Int
    
    var schedulePlanning: Bool
    var pattern: SchedulePattern
    var workSessionsPerCycle: Int
    
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
        sideRestDuration: Int? = nil,
        deepRestDuration: Int? = nil,
        schedulePlanning: Bool = true,
        pattern: SchedulePattern = .alternating,
        workSessionsPerCycle: Int = 2,
        sideSessionsPerCycle: Int = 1,
        sideFirst: Bool = false,
        deepSessionConfig: DeepSessionConfig = .default,
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
        
        self.sideRestDuration = sideRestDuration ?? max(5, Int(Double(restDuration) * 0.75))
        self.deepRestDuration = deepRestDuration ?? restDuration
        
        self.schedulePlanning = schedulePlanning
        self.pattern = pattern
        self.workSessionsPerCycle = workSessionsPerCycle
        self.sideSessionsPerCycle = sideSessionsPerCycle
        self.sideFirst = sideFirst
        self.deepSessionConfig = deepSessionConfig
        self.calendarMapping = calendarMapping
        self.defaultStartHour = defaultStartHour
        self.schedulePlanning = schedulePlanning
        self.pattern = pattern
        self.workSessionsPerCycle = workSessionsPerCycle
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, icon
        case workSessionCount, sideSessionCount
        case workSessionName, sideSessionName
        case workSessionDuration, sideSessionDuration
        case planningDuration, restDuration, sideRestDuration, deepRestDuration
        case schedulePlanning, pattern, workSessionsPerCycle, sideSessionsPerCycle, sideFirst
        case deepSessionConfig, calendarMapping, defaultStartHour
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        workSessionCount = try container.decode(Int.self, forKey: .workSessionCount)
        sideSessionCount = try container.decode(Int.self, forKey: .sideSessionCount)
        workSessionName = try container.decode(String.self, forKey: .workSessionName)
        sideSessionName = try container.decode(String.self, forKey: .sideSessionName)
        workSessionDuration = try container.decode(Int.self, forKey: .workSessionDuration)
        sideSessionDuration = try container.decode(Int.self, forKey: .sideSessionDuration)
        planningDuration = try container.decode(Int.self, forKey: .planningDuration)
        restDuration = try container.decode(Int.self, forKey: .restDuration)
        sideRestDuration = try container.decode(Int.self, forKey: .sideRestDuration)
        deepRestDuration = try container.decodeIfPresent(Int.self, forKey: .deepRestDuration) ?? restDuration
        schedulePlanning = try container.decode(Bool.self, forKey: .schedulePlanning)
        pattern = try container.decode(SchedulePattern.self, forKey: .pattern)
        workSessionsPerCycle = try container.decode(Int.self, forKey: .workSessionsPerCycle)
        sideSessionsPerCycle = try container.decodeIfPresent(Int.self, forKey: .sideSessionsPerCycle) ?? 1
        sideFirst = try container.decodeIfPresent(Bool.self, forKey: .sideFirst) ?? false
        deepSessionConfig = try container.decode(DeepSessionConfig.self, forKey: .deepSessionConfig)
        calendarMapping = try container.decode(CalendarMapping.self, forKey: .calendarMapping)
        defaultStartHour = try container.decodeIfPresent(Int.self, forKey: .defaultStartHour) ?? 8
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
