import Foundation

// MARK: - Per-type ambient sound settings

struct SessionSoundConfig: Codable, Equatable {
    var sound: String           // Built-in ambient name, "Off", or custom name
    var volume: Float           // 0.0–1.0
    var customSoundPath: String? = nil

    static let off = SessionSoundConfig(sound: "Off", volume: 0.0)

    static let availableSounds = [
        "Off",
        "Clock Ticking",
        "Clock Ticking Slow",
        "Duskfall on a River",
        "Light Rain",
        "Mountain Atmosphere",
        "Ocean Waves",
        "Peaceful Wind",
        "Thunder in the Woods",
    ]
}

// MARK: - Start/End transition sound settings

struct TransitionSoundConfig: Codable, Equatable {
    var sound: String           // Built-in transition name, "Off", or custom name
    var volume: Float           // 0.0–1.0
    var customSoundPath: String? = nil

    static let off = TransitionSoundConfig(sound: "Off", volume: 0.0)

    static let availableSounds = ["Off", "Kitchen Timer", "Gong"]
}

// MARK: - Time display mode

enum TimeDisplayMode: String, Codable, CaseIterable {
    case remaining = "remaining"
    case elapsed = "elapsed"
}

// MARK: - Accelerando config

struct AccelerandoConfig: Codable, Equatable {
    var enabled: Bool = false
    var maxMultiplier: Double = 1.5

    static let multiplierOptions: [Double] = [1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0]
}

// MARK: - Codable rect for window position persistence

struct CodableRect: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

// MARK: - Custom sound entry

struct CustomSoundEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var filePath: String

    init(name: String, filePath: String) {
        self.id = UUID()
        self.name = name
        self.filePath = filePath
    }
}

// MARK: - Custom sound store

class CustomSoundStore {
    static let shared = CustomSoundStore()
    private static let storageKey = "TaskScheduler.CustomSounds"

    private init() {}

    func loadEntries() -> [CustomSoundEntry] {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let entries = try? JSONDecoder().decode([CustomSoundEntry].self, from: data) else {
            return []
        }
        return entries
    }

    func addEntry(_ entry: CustomSoundEntry) {
        var entries = loadEntries()
        entries.append(entry)
        save(entries)
    }

    func removeEntry(id: UUID) {
        var entries = loadEntries()
        entries.removeAll { $0.id == id }
        save(entries)
    }

    func entry(named name: String) -> CustomSoundEntry? {
        loadEntries().first { $0.name == name }
    }

    private func save(_ entries: [CustomSoundEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - Main config

struct SessionAwarenessConfig: Codable, Equatable {
    var enabled: Bool = true
    var outputDeviceUID: String? = nil      // nil = system default

    // Per-type ambient sound settings
    var workSound: SessionSoundConfig = .init(sound: "Clock Ticking", volume: 0.5)
    var sideSound: SessionSoundConfig = .init(sound: "Clock Ticking Slow", volume: 0.5)
    var deepSound: SessionSoundConfig = .init(sound: "Mountain Atmosphere", volume: 0.4)
    var planningSound: SessionSoundConfig = .init(sound: "Peaceful Wind", volume: 0.3)
    var breakSound: SessionSoundConfig = .init(sound: "Ocean Waves", volume: 0.3)

    // Non-tagged calendar events (busy slots without our tags)
    var trackOtherEvents: Bool = false
    var otherEventsSound: SessionSoundConfig = .init(sound: "Off", volume: 0.0)

    // Start/End session transition sounds
    var startSound: TransitionSoundConfig = .init(sound: "Kitchen Timer", volume: 0.6)
    var endSound: TransitionSoundConfig = .init(sound: "Gong", volume: 0.6)

    // Phase 2: Time display mode
    var timeDisplayMode: TimeDisplayMode = .remaining

    // Phase 3: Ending soon transition
    var endingSoonSound: TransitionSoundConfig = .off

    // Phase 3: Presence reminder
    var presenceReminderEnabled: Bool = true
    var presenceReminderIntervalMinutes: Int = 10
    var presenceReminderSound: TransitionSoundConfig = .init(sound: "Gong", volume: 0.4)

    // Phase 3: Accelerando per type
    var workSoundAccelerando: AccelerandoConfig = .init()
    var sideSoundAccelerando: AccelerandoConfig = .init()
    var deepSoundAccelerando: AccelerandoConfig = .init()
    var planningSoundAccelerando: AccelerandoConfig = .init()
    var otherEventsSoundAccelerando: AccelerandoConfig = .init()

    // Phase 5: Menu bar & Dock
    var showMenuBarItem: Bool = false
    var showDockProgress: Bool = true

    // Phase 6: Mini-player & main window frames
    var miniPlayerFrame: CodableRect? = nil
    var mainWindowFrame: CodableRect? = nil

    static let `default` = SessionAwarenessConfig()

    // MARK: - Persistence

    private static let storageKey = "TaskScheduler.SessionAwarenessConfig"

    static func load() -> SessionAwarenessConfig {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let config = try? JSONDecoder().decode(SessionAwarenessConfig.self, from: data) else {
            return .default
        }
        return config
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - Backward-compatible decoding

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        outputDeviceUID = try c.decodeIfPresent(String.self, forKey: .outputDeviceUID)

        workSound = try c.decodeIfPresent(SessionSoundConfig.self, forKey: .workSound) ?? .init(sound: "Clock Ticking", volume: 0.5)
        sideSound = try c.decodeIfPresent(SessionSoundConfig.self, forKey: .sideSound) ?? .init(sound: "Clock Ticking Slow", volume: 0.5)
        deepSound = try c.decodeIfPresent(SessionSoundConfig.self, forKey: .deepSound) ?? .init(sound: "Mountain Atmosphere", volume: 0.4)
        planningSound = try c.decodeIfPresent(SessionSoundConfig.self, forKey: .planningSound) ?? .init(sound: "Peaceful Wind", volume: 0.3)
        breakSound = try c.decodeIfPresent(SessionSoundConfig.self, forKey: .breakSound) ?? .off

        trackOtherEvents = try c.decodeIfPresent(Bool.self, forKey: .trackOtherEvents) ?? false
        otherEventsSound = try c.decodeIfPresent(SessionSoundConfig.self, forKey: .otherEventsSound) ?? .off

        startSound = try c.decodeIfPresent(TransitionSoundConfig.self, forKey: .startSound) ?? .init(sound: "Kitchen Timer", volume: 0.6)
        endSound = try c.decodeIfPresent(TransitionSoundConfig.self, forKey: .endSound) ?? .init(sound: "Gong", volume: 0.6)

        timeDisplayMode = try c.decodeIfPresent(TimeDisplayMode.self, forKey: .timeDisplayMode) ?? .remaining
        endingSoonSound = try c.decodeIfPresent(TransitionSoundConfig.self, forKey: .endingSoonSound) ?? .off

        presenceReminderEnabled = try c.decodeIfPresent(Bool.self, forKey: .presenceReminderEnabled) ?? true
        presenceReminderIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .presenceReminderIntervalMinutes) ?? 10
        presenceReminderSound = try c.decodeIfPresent(TransitionSoundConfig.self, forKey: .presenceReminderSound) ?? .init(sound: "Gong", volume: 0.4)

        workSoundAccelerando = try c.decodeIfPresent(AccelerandoConfig.self, forKey: .workSoundAccelerando) ?? .init()
        sideSoundAccelerando = try c.decodeIfPresent(AccelerandoConfig.self, forKey: .sideSoundAccelerando) ?? .init()
        deepSoundAccelerando = try c.decodeIfPresent(AccelerandoConfig.self, forKey: .deepSoundAccelerando) ?? .init()
        planningSoundAccelerando = try c.decodeIfPresent(AccelerandoConfig.self, forKey: .planningSoundAccelerando) ?? .init()
        otherEventsSoundAccelerando = try c.decodeIfPresent(AccelerandoConfig.self, forKey: .otherEventsSoundAccelerando) ?? .init()

        showMenuBarItem = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarItem) ?? false
        showDockProgress = try c.decodeIfPresent(Bool.self, forKey: .showDockProgress) ?? true
        miniPlayerFrame = try c.decodeIfPresent(CodableRect.self, forKey: .miniPlayerFrame)
        mainWindowFrame = try c.decodeIfPresent(CodableRect.self, forKey: .mainWindowFrame)
    }

    init() {}

    // MARK: - Helpers

    func soundConfig(for sessionType: SessionType) -> SessionSoundConfig {
        switch sessionType {
        case .work: return workSound
        case .side: return sideSound
        case .deep: return deepSound
        case .planning: return planningSound
        case .bigRest: return breakSound
        }
    }

    func accelerandoConfig(for sessionType: SessionType) -> AccelerandoConfig {
        switch sessionType {
        case .work: return workSoundAccelerando
        case .side: return sideSoundAccelerando
        case .deep: return deepSoundAccelerando
        case .planning: return planningSoundAccelerando
        case .bigRest: return .init()
        }
    }
}
