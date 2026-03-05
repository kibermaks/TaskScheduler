import SwiftUI
import EventKit
import AppKit

struct AppSettingsView: View {
    @EnvironmentObject var schedulingEngine: SchedulingEngine
    @EnvironmentObject var calendarService: CalendarService
    @EnvironmentObject var sessionAwarenessService: SessionAwarenessService
    @EnvironmentObject var sessionAudioService: SessionAudioService

    @AppStorage("hasSeenWelcome") var hasSeenWelcome = false
    @AppStorage("hasSeenPatternsGuide") var hasSeenPatternsGuide = false
    @AppStorage("hasSeenTasksGuide") var hasSeenTasksGuide = false
    @AppStorage("timelineIntroBarDismissed") var timelineIntroBarDismissed = false
    @AppStorage("showDevSettings") private var showDevSettings = false

    @State private var showingResetPresetsConfirmation = false
    @State private var showingResetAwarenessConfirmation = false
    @State private var pendingReplacementContext: CalendarReplacementContext?
    @State private var selectedReplacementCalendarId: String = ""
    @State private var replacementErrorMessage: String?

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            calendarsTab
                .tabItem {
                    Label("Calendars", systemImage: "calendar")
                }

            sessionAwarenessTab
                .tabItem {
                    Label("Awareness", systemImage: "eye.circle")
                }
        }
        .frame(width: 520, height: 580)
        .preferredColorScheme(.dark)
        .alert("Reset Presets?", isPresented: $showingResetPresetsConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetPresets()
            }
        } message: {
            Text("This will permanently delete all saved presets and launch Calendar Setup to recreate them.")
        }
        .sheet(item: $pendingReplacementContext, onDismiss: {
            selectedReplacementCalendarId = ""
        }) { context in
            CalendarReplacementSheet(
                context: context,
                replacementOptions: replacementOptions(excluding: context.calendar),
                selectedCalendarId: $selectedReplacementCalendarId,
                onCancel: {
                    pendingReplacementContext = nil
                },
                onConfirm: {
                    confirmCalendarReplacement(for: context)
                }
            )
        }
        .alert("Cannot Hide Calendar", isPresented: replacementErrorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(replacementErrorMessage ?? "Unknown issue occurred.")
        }
    }

    // MARK: - Tab 1: General

    private var generalTab: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)

                    Text("General")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .onTapGesture(count: 4) {
                            withAnimation { showDevSettings.toggle() }
                        }

                    Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }

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

                LabeledContent("Schedule until:") {
                    HStack {
                        if schedulingEngine.scheduleEndHour > 24 {
                            Text("+1d \(formattedHourForSettings(schedulingEngine.scheduleEndHour))")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                        NumericInputField(value: $schedulingEngine.scheduleEndHour, range: 13...30, step: 1, unit: "h")
                    }
                }
                Text("When to stop placing sessions. Values above 24 extend into the next day.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Timeline Visibility") {
                Toggle("Hide night hours", isOn: $schedulingEngine.hideNightHours)

                LabeledContent("Morning Edge:") {
                    HStack {
                        NumericInputField(value: $schedulingEngine.dayStartHour, range: 0...12, step: 1, unit: "h")
                    }
                }
                .padding(.leading, 10)
                .disabled(!schedulingEngine.hideNightHours)

                Text("Night edge is controlled by \"Schedule until\" above.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Tips") {
                Toggle("Show \"Did you know?\" card", isOn: $schedulingEngine.showDidYouKnowCard)
                Text("Displays rotating tips next of how to use the app.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Preset Management") {
                Button(role: .destructive, action: { showingResetPresetsConfirmation = true }) {
                    Label("Reset Presets", systemImage: "arrow.counterclockwise")
                }

                Text("This will erase all saved presets and launch Calendar Setup.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if showDevSettings {
                Section("Developer Settings") {
                    Button(action: {
                        hasSeenWelcome = false
                        hasSeenPatternsGuide = false
                        hasSeenTasksGuide = false
                        timelineIntroBarDismissed = false
                        UserDefaults.standard.set(false, forKey: "hasSeenSessionAwarenessGuide")
                    }) {
                        Label("Reset All Dirty Triggers", systemImage: "arrow.counterclockwise")
                    }

                    Button(action: resetCalendarSetup) {
                        Label("Reset Calendar Setup", systemImage: "calendar.badge.clock")
                    }

                    Text("This will show the calendar setup screen again for testing.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    Button(role: .destructive, action: resetCalendarPermissions) {
                        Label("Reset Calendar Permissions", systemImage: "lock.slash.fill")
                    }

                    Text("Note: Resetting permissions will immediately terminate the application to clear the system cache.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tab 2: Calendars

    private var calendarsTab: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)

                    Text("Calendar Filters")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }

            Section {
                if calendarService.authorizationStatus != .fullAccess {
                    Text("Grant calendar access to manage which calendars contribute busy events.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    let calendars = calendarService.availableCalendars.sorted { $0.title < $1.title }
                    if calendars.isEmpty {
                        Text("No editable calendars available. Create or add calendars in the macOS Calendar app.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Unchecked calendars are ignored when fetching busy slots and counting existing sessions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        ForEach(calendars, id: \.calendarIdentifier) { calendar in
                            Toggle(isOn: Binding(
                                get: { !calendarService.isCalendarExcluded(identifier: calendar.calendarIdentifier) },
                                set: { included in
                                    handleCalendarToggle(for: calendar, included: included)
                                }
                            )) {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(color(for: calendar))
                                        .frame(width: 12, height: 12)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(calendar.title)
                                            .font(.body)
                                        Text(calendar.source.title)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tab 3: Session Awareness

    @State private var showingCustomSoundImport = false
    @State private var customSoundImportIsAmbient = true
    @State private var pendingImportURL: URL? = nil
    @State private var customSoundName: String = ""
    @State private var showingNamePrompt = false

    private var sessionAwarenessTab: some View {
        Form {
            Section {
                Toggle("Enable session awareness", isOn: Binding(
                    get: { sessionAwarenessService.config.enabled },
                    set: { newValue in
                        sessionAwarenessService.config.enabled = newValue
                        sessionAwarenessService.isEnabled = newValue
                    }
                ))

                Text("Bottom panel tracks your current session with timer, progress, and ambient sound.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if sessionAwarenessService.config.enabled {
                Section("Ambient Sounds") {
                    ambientSoundRow(icon: "briefcase.fill", iconColor: SessionType.work.color, label: "Work",
                                    soundKeyPath: \.workSound, accelKeyPath: \.workSoundAccelerando)
                    ambientSoundRow(icon: "star.fill", iconColor: SessionType.side.color, label: "Side",
                                    soundKeyPath: \.sideSound, accelKeyPath: \.sideSoundAccelerando)
                    ambientSoundRow(icon: "bolt.circle.fill", iconColor: SessionType.deep.color, label: "Deep",
                                    soundKeyPath: \.deepSound, accelKeyPath: \.deepSoundAccelerando)
                    ambientSoundRow(icon: "calendar.badge.clock", iconColor: SessionType.planning.color, label: "Planning",
                                    soundKeyPath: \.planningSound, accelKeyPath: \.planningSoundAccelerando)
                }

                Section("Session Transitions") {
                    soundRow(icon: "play.fill", iconColor: .green, label: "Start",
                             config: bindingSoundConfig(forTransition: \.startSound), isAmbient: false)
                    soundRow(icon: "clock.badge.exclamationmark", iconColor: .yellow, label: "Ending",
                             config: bindingSoundConfig(forTransition: \.endingSoonSound), isAmbient: false)

                    Text("\"Ending\" plays 2 minutes before session ends.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    soundRow(icon: "stop.fill", iconColor: .orange, label: "End",
                             config: bindingSoundConfig(forTransition: \.endSound), isAmbient: false)
                }

                Section("Session Presence Reminder") {
                    Toggle("Enable presence reminder", isOn: Binding(
                        get: { sessionAwarenessService.config.presenceReminderEnabled },
                        set: { sessionAwarenessService.config.presenceReminderEnabled = $0 }
                    ))

                    if sessionAwarenessService.config.presenceReminderEnabled {
                        Picker("Interval", selection: Binding(
                            get: { sessionAwarenessService.config.presenceReminderIntervalMinutes },
                            set: { sessionAwarenessService.config.presenceReminderIntervalMinutes = $0 }
                        )) {
                            Text("5 min").tag(5)
                            Text("10 min").tag(10)
                            Text("15 min").tag(15)
                            Text("20 min").tag(20)
                            Text("30 min").tag(30)
                        }

                        soundRow(icon: "bell.badge.fill", iconColor: .yellow, label: "Sound",
                                 config: bindingSoundConfig(forTransition: \.presenceReminderSound), isAmbient: false)
                    }

                    Text("Plays a reminder sound periodically during active sessions.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Other Calendar Events") {
                    Toggle("Track non-tagged events", isOn: Binding(
                        get: { sessionAwarenessService.config.trackOtherEvents },
                        set: { sessionAwarenessService.config.trackOtherEvents = $0 }
                    ))

                    Text("Shows calendar events without session tags in the bottom panel.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if sessionAwarenessService.config.trackOtherEvents {
                        ambientSoundRow(icon: "calendar", iconColor: .gray, label: "Other",
                                        soundKeyPath: \.otherEventsSound, accelKeyPath: \.otherEventsSoundAccelerando)
                    }
                }

                Section("Menu Bar & Dock") {
                    Toggle("Show in menu bar", isOn: Binding(
                        get: { sessionAwarenessService.config.showMenuBarItem },
                        set: { sessionAwarenessService.config.showMenuBarItem = $0 }
                    ))

                    Toggle("Show progress on Dock icon", isOn: Binding(
                        get: { sessionAwarenessService.config.showDockProgress },
                        set: { sessionAwarenessService.config.showDockProgress = $0 }
                    ))

                    Text("Menu bar shows session icon and timer. Dock icon shows a progress donut during active sessions.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Audio Output") {
                    Picker("Output Device", selection: Binding(
                        get: { sessionAwarenessService.config.outputDeviceUID ?? "" },
                        set: { newValue in
                            let uid = newValue.isEmpty ? nil : newValue
                            sessionAwarenessService.config.outputDeviceUID = uid
                            sessionAudioService.setOutputDevice(uid: uid)
                        }
                    )) {
                        Text("System Default").tag("")
                        ForEach(sessionAudioService.availableOutputDevices) { device in
                            Text(device.name).tag(device.uid)
                        }
                    }
                    .onAppear { sessionAudioService.refreshOutputDevices() }
                }

                Section {
                    Button("Reset Awareness Settings", role: .destructive) {
                        showingResetAwarenessConfirmation = true
                    }

                    Text("Resets all awareness settings to defaults: sounds, transitions, presence reminder, menu bar, and audio output.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .alert("Reset Awareness Settings?", isPresented: $showingResetAwarenessConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAwarenessSettings()
            }
        } message: {
            Text("This will reset all session awareness settings to their defaults. This cannot be undone.")
        }
        .alert("Name Your Sound", isPresented: $showingNamePrompt) {
            TextField("Sound name", text: $customSoundName)
            Button("Add") { finishCustomSoundImport() }
            Button("Cancel", role: .cancel) { pendingImportURL = nil }
        } message: {
            Text("Enter a display name for this custom sound.")
        }
    }

    // MARK: - Ambient sound row with accelerando

    private func ambientSoundRow(icon: String, iconColor: Color, label: String,
                                  soundKeyPath: WritableKeyPath<SessionAwarenessConfig, SessionSoundConfig>,
                                  accelKeyPath: WritableKeyPath<SessionAwarenessConfig, AccelerandoConfig>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(iconColor)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 13))
                .frame(width: 70, alignment: .leading)

            soundPicker(for: soundKeyPath, isAmbient: true)

            Slider(value: Binding(
                get: { sessionAwarenessService.config[keyPath: soundKeyPath].volume },
                set: { sessionAwarenessService.config[keyPath: soundKeyPath].volume = $0 }
            ), in: 0...1)
                .frame(maxWidth: .infinity)
                .opacity(sessionAwarenessService.config[keyPath: soundKeyPath].sound == "Off" ? 0 : 1)
                .disabled(sessionAwarenessService.config[keyPath: soundKeyPath].sound == "Off")

            Button {
                previewAmbientSound(sessionAwarenessService.config[keyPath: soundKeyPath].sound,
                                    volume: sessionAwarenessService.config[keyPath: soundKeyPath].volume)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help("Preview")
            .opacity(sessionAwarenessService.config[keyPath: soundKeyPath].sound == "Off" ? 0 : 1)
            .disabled(sessionAwarenessService.config[keyPath: soundKeyPath].sound == "Off")

            // Accelerando toggle
            let accelEnabled = sessionAwarenessService.config[keyPath: accelKeyPath].enabled
            Button {
                sessionAwarenessService.config[keyPath: accelKeyPath].enabled.toggle()
            } label: {
                Image(systemName: "hare.fill")
                    .font(.system(size: 9))
                    .foregroundColor(accelEnabled ? .orange : .white.opacity(0.25))
                    .frame(width: 22, height: 22)
                    .background(accelEnabled ? Color.orange.opacity(0.15) : Color.white.opacity(0.05))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help(accelEnabled
                  ? "Accelerando: sound gradually speeds up during the session"
                  : "Enable accelerando — gradually speeds up playback over the session duration")
            .opacity(sessionAwarenessService.config[keyPath: soundKeyPath].sound == "Off" ? 0 : 1)
            .disabled(sessionAwarenessService.config[keyPath: soundKeyPath].sound == "Off")

            if accelEnabled && sessionAwarenessService.config[keyPath: soundKeyPath].sound != "Off" {
                Picker("", selection: Binding(
                    get: { sessionAwarenessService.config[keyPath: accelKeyPath].maxMultiplier },
                    set: { sessionAwarenessService.config[keyPath: accelKeyPath].maxMultiplier = $0 }
                )) {
                    ForEach(AccelerandoConfig.multiplierOptions, id: \.self) { mult in
                        Text(String(format: "%.1fx", mult)).tag(mult)
                    }
                }
                .labelsHidden()
                .frame(width: 60)
                .help("Target speed at session end — playback linearly accelerates from 1.0x to this speed")
            }
        }
    }

    // MARK: - Sound Picker with Standard/Custom sections

    private func soundPicker(for keyPath: WritableKeyPath<SessionAwarenessConfig, SessionSoundConfig>, isAmbient: Bool) -> some View {
        let currentSound = sessionAwarenessService.config[keyPath: keyPath].sound
        let customSounds = CustomSoundStore.shared.loadEntries()

        return Picker("", selection: Binding(
            get: { currentSound },
            set: { newValue in
                if newValue == "__import__" {
                    customSoundImportIsAmbient = isAmbient
                    openCustomSoundImport(for: keyPath)
                } else {
                    sessionAwarenessService.config[keyPath: keyPath].sound = newValue
                }
            }
        )) {
            Section("Standard") {
                ForEach(SessionSoundConfig.availableSounds, id: \.self) { Text($0).tag($0) }
            }
            if !customSounds.isEmpty {
                Section("Custom") {
                    ForEach(customSounds) { entry in
                        Text(entry.name).tag(entry.name)
                    }
                }
            }
            Divider()
            Text("Import Sound...").tag("__import__")
        }
        .labelsHidden()
        .frame(width: 140)
    }

    private func transitionSoundPicker(for keyPath: WritableKeyPath<SessionAwarenessConfig, TransitionSoundConfig>) -> some View {
        let currentSound = sessionAwarenessService.config[keyPath: keyPath].sound
        let customSounds = CustomSoundStore.shared.loadEntries()

        return Picker("", selection: Binding(
            get: { currentSound },
            set: { newValue in
                if newValue == "__import__" {
                    customSoundImportIsAmbient = false
                    openTransitionSoundImport(for: keyPath)
                } else {
                    sessionAwarenessService.config[keyPath: keyPath].sound = newValue
                }
            }
        )) {
            Section("Standard") {
                ForEach(TransitionSoundConfig.availableSounds, id: \.self) { Text($0).tag($0) }
            }
            if !customSounds.isEmpty {
                Section("Custom") {
                    ForEach(customSounds) { entry in
                        Text(entry.name).tag(entry.name)
                    }
                }
            }
            Divider()
            Text("Import Sound...").tag("__import__")
        }
        .labelsHidden()
        .frame(width: 140)
    }

    // MARK: - Unified Sound Row (for transition sounds)

    private struct SoundRowConfig {
        var sound: Binding<String>
        var volume: Binding<Float>
        var availableSounds: [String]
    }

    private func bindingSoundConfig(forTransition keyPath: WritableKeyPath<SessionAwarenessConfig, TransitionSoundConfig>) -> SoundRowConfig {
        SoundRowConfig(
            sound: Binding(
                get: { sessionAwarenessService.config[keyPath: keyPath].sound },
                set: { sessionAwarenessService.config[keyPath: keyPath].sound = $0 }
            ),
            volume: Binding(
                get: { sessionAwarenessService.config[keyPath: keyPath].volume },
                set: { sessionAwarenessService.config[keyPath: keyPath].volume = $0 }
            ),
            availableSounds: TransitionSoundConfig.availableSounds
        )
    }

    private func soundRow(icon: String, iconColor: Color, label: String, config: SoundRowConfig, isAmbient: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(iconColor)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 13))
                .frame(width: 70, alignment: .leading)

            Picker("", selection: config.sound) {
                Section("Standard") {
                    ForEach(config.availableSounds, id: \.self) { Text($0).tag($0) }
                }
                let customSounds = CustomSoundStore.shared.loadEntries()
                if !customSounds.isEmpty {
                    Section("Custom") {
                        ForEach(customSounds) { entry in
                            Text(entry.name).tag(entry.name)
                        }
                    }
                }
                Divider()
                Text("Import Sound...").tag("__import__")
            }
            .labelsHidden()
            .frame(width: 140)
            .onChange(of: config.sound.wrappedValue) { _, newValue in
                if newValue == "__import__" {
                    // Revert to "Off" and open import
                    config.sound.wrappedValue = "Off"
                    showCustomSoundFilePanel()
                }
            }

            Slider(value: config.volume, in: 0...1)
                .frame(maxWidth: .infinity)
                .opacity(config.sound.wrappedValue == "Off" ? 0 : 1)
                .disabled(config.sound.wrappedValue == "Off")

            Button {
                if isAmbient {
                    previewAmbientSound(config.sound.wrappedValue, volume: config.volume.wrappedValue)
                } else {
                    previewTransitionSound(config.sound.wrappedValue, volume: config.volume.wrappedValue)
                }
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help("Preview")
            .opacity(config.sound.wrappedValue == "Off" ? 0 : 1)
            .disabled(config.sound.wrappedValue == "Off")
        }
    }

    // MARK: - Custom Sound Import

    private func openCustomSoundImport(for keyPath: WritableKeyPath<SessionAwarenessConfig, SessionSoundConfig>) {
        // Revert picker to current value
        let current = sessionAwarenessService.config[keyPath: keyPath].sound
        sessionAwarenessService.config[keyPath: keyPath].sound = current == "__import__" ? "Off" : current
        showCustomSoundFilePanel()
    }

    private func openTransitionSoundImport(for keyPath: WritableKeyPath<SessionAwarenessConfig, TransitionSoundConfig>) {
        let current = sessionAwarenessService.config[keyPath: keyPath].sound
        sessionAwarenessService.config[keyPath: keyPath].sound = current == "__import__" ? "Off" : current
        showCustomSoundFilePanel()
    }

    private func showCustomSoundFilePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.wav, .mp3, .aiff, .mpeg4Audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an audio file to import as a custom sound"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        pendingImportURL = url
        customSoundName = url.deletingPathExtension().lastPathComponent
        showingNamePrompt = true
    }

    private func finishCustomSoundImport() {
        guard let url = pendingImportURL, !customSoundName.isEmpty else { return }

        if let filePath = SessionAudioService.importCustomSound(from: url) {
            let entry = CustomSoundEntry(name: customSoundName, filePath: filePath)
            CustomSoundStore.shared.addEntry(entry)
        }

        pendingImportURL = nil
        customSoundName = ""
    }

    // MARK: - Sound Preview

    private func previewAmbientSound(_ sound: String, volume: Float) {
        guard sound != "Off" else { return }
        let config = SessionSoundConfig(sound: sound, volume: volume)
        sessionAudioService.playAmbient(config: config)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if !sessionAwarenessService.isActive {
                sessionAudioService.stopAmbient()
            }
        }
    }

    private func previewTransitionSound(_ sound: String, volume: Float) {
        guard sound != "Off" else { return }
        let config = TransitionSoundConfig(sound: sound, volume: volume)
        sessionAudioService.playTransition(config: config)
    }

    // MARK: - Utility

    private func formattedHourForSettings(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        var components = DateComponents()
        components.hour = hour % 24
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour % 24):00"
    }

    private func resetCalendarSetup() {
        UserDefaults.standard.set(false, forKey: "TaskScheduler.HasCompletedSetup")
        NotificationCenter.default.post(name: Notification.Name("ResetCalendarSetup"), object: nil)
    }

    private func resetPresets() {
        UserDefaults.standard.removeObject(forKey: "TaskScheduler.Presets")
        UserDefaults.standard.removeObject(forKey: "TaskScheduler.LastActivePresetID")
        timelineIntroBarDismissed = false
        UserDefaults.standard.set(false, forKey: "TaskScheduler.HasCompletedSetup")
        NotificationCenter.default.post(name: Notification.Name("PresetsReset"), object: nil)
        NotificationCenter.default.post(name: Notification.Name("ResetCalendarSetup"), object: nil)
        if let window = NSApp.windows.first(where: { $0.title == "Settings" }) {
            window.close()
        }
    }

    private func resetAwarenessSettings() {
        sessionAudioService.stopAmbient()
        let wasEnabled = sessionAwarenessService.config.enabled
        var freshConfig = SessionAwarenessConfig()
        freshConfig.enabled = wasEnabled
        sessionAwarenessService.config = freshConfig
        sessionAudioService.setOutputDevice(uid: nil)
    }

    private func resetCalendarPermissions() {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Calendar", bundleId]
        do {
            try process.run()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.terminate(nil)
            }
        } catch {
            print("Failed to reset permissions: \(error)")
        }
    }
}

#Preview {
    AppSettingsView()
        .environmentObject(SchedulingEngine())
        .environmentObject(CalendarService())
        .environmentObject(SessionAwarenessService())
        .environmentObject(SessionAudioService())
}

extension AppSettingsView {
    private func color(for calendar: EKCalendar) -> Color {
        if let cgColor = calendar.cgColor,
           let nsColor = NSColor(cgColor: cgColor) {
            return Color(nsColor: nsColor)
        }
        return .gray
    }

    private func handleCalendarToggle(for calendar: EKCalendar, included: Bool) {
        if included {
            calendarService.setCalendar(calendar, included: true)
            return
        }

        let affectedPresets = presetsUsingCalendar(calendar: calendar)
        guard !affectedPresets.isEmpty else {
            calendarService.setCalendar(calendar, included: false)
            return
        }

        let options = replacementOptions(excluding: calendar)
        guard !options.isEmpty else {
            replacementErrorMessage = "No other visible calendars are available to replace \"\(calendar.title)\". Create or enable another calendar first."
            return
        }

        selectedReplacementCalendarId = ""
        pendingReplacementContext = CalendarReplacementContext(calendar: calendar, affectedPresets: affectedPresets)
    }

    private func presetsUsingCalendar(calendar: EKCalendar) -> [Preset] {
        let presets = PresetStorage.shared.loadPresets()
        return presets.filter { preset in
            preset.calendarMapping.workCalendarIdentifier == calendar.calendarIdentifier ||
            (preset.calendarMapping.workCalendarIdentifier == nil && preset.calendarMapping.workCalendarName == calendar.title) ||
            preset.calendarMapping.sideCalendarIdentifier == calendar.calendarIdentifier ||
            (preset.calendarMapping.sideCalendarIdentifier == nil && preset.calendarMapping.sideCalendarName == calendar.title) ||
            preset.deepSessionConfig.calendarIdentifier == calendar.calendarIdentifier ||
            (preset.deepSessionConfig.calendarIdentifier == nil && preset.deepSessionConfig.calendarName == calendar.title)
        }
    }

    private func replacementOptions(excluding calendar: EKCalendar) -> [EKCalendar] {
        calendarService.availableCalendars.filter {
            $0.calendarIdentifier != calendar.calendarIdentifier &&
            !calendarService.isCalendarExcluded(identifier: $0.calendarIdentifier)
        }
    }

    private func confirmCalendarReplacement(for context: CalendarReplacementContext) {
        guard
            let replacement = calendarService.availableCalendars.first(where: { $0.calendarIdentifier == selectedReplacementCalendarId })
        else {
            replacementErrorMessage = "Select a replacement calendar before continuing."
            return
        }

        applyCalendarReplacement(
            oldCalendar: context.calendar,
            newCalendar: replacement,
            affectedPresetIDs: Set(context.affectedPresets.map { $0.id })
        )

        calendarService.setCalendar(context.calendar, included: false)
        pendingReplacementContext = nil
    }

    private func applyCalendarReplacement(oldCalendar: EKCalendar, newCalendar: EKCalendar, affectedPresetIDs: Set<UUID>) {
        var presets = PresetStorage.shared.loadPresets()
        var changed = false
        let newIdentifier = newCalendar.calendarIdentifier

        for index in presets.indices {
            guard affectedPresetIDs.contains(presets[index].id) else { continue }

            if presets[index].calendarMapping.workCalendarIdentifier == oldCalendar.calendarIdentifier ||
                (presets[index].calendarMapping.workCalendarIdentifier == nil && presets[index].calendarMapping.workCalendarName == oldCalendar.title) {
                presets[index].calendarMapping.workCalendarName = newCalendar.title
                presets[index].calendarMapping.workCalendarIdentifier = newIdentifier
                changed = true
            }
            if presets[index].calendarMapping.sideCalendarIdentifier == oldCalendar.calendarIdentifier ||
                (presets[index].calendarMapping.sideCalendarIdentifier == nil && presets[index].calendarMapping.sideCalendarName == oldCalendar.title) {
                presets[index].calendarMapping.sideCalendarName = newCalendar.title
                presets[index].calendarMapping.sideCalendarIdentifier = newIdentifier
                changed = true
            }
            if presets[index].deepSessionConfig.calendarIdentifier == oldCalendar.calendarIdentifier ||
                (presets[index].deepSessionConfig.calendarIdentifier == nil && presets[index].deepSessionConfig.calendarName == oldCalendar.title) {
                presets[index].deepSessionConfig.calendarName = newCalendar.title
                presets[index].deepSessionConfig.calendarIdentifier = newIdentifier
                changed = true
            }
        }

        if changed {
            PresetStorage.shared.savePresets(presets)
            NotificationCenter.default.post(name: Notification.Name("PresetsUpdated"), object: nil)
        }

        if schedulingEngine.workCalendarIdentifier == oldCalendar.calendarIdentifier ||
            (schedulingEngine.workCalendarIdentifier == nil && schedulingEngine.workCalendarName == oldCalendar.title) {
            schedulingEngine.workCalendarName = newCalendar.title
            schedulingEngine.workCalendarIdentifier = newIdentifier
        }
        if schedulingEngine.sideCalendarIdentifier == oldCalendar.calendarIdentifier ||
            (schedulingEngine.sideCalendarIdentifier == nil && schedulingEngine.sideCalendarName == oldCalendar.title) {
            schedulingEngine.sideCalendarName = newCalendar.title
            schedulingEngine.sideCalendarIdentifier = newIdentifier
        }
        if schedulingEngine.deepSessionConfig.calendarIdentifier == oldCalendar.calendarIdentifier ||
            (schedulingEngine.deepSessionConfig.calendarIdentifier == nil && schedulingEngine.deepSessionConfig.calendarName == oldCalendar.title) {
            var config = schedulingEngine.deepSessionConfig
            config.calendarName = newCalendar.title
            config.calendarIdentifier = newIdentifier
            schedulingEngine.deepSessionConfig = config
        }
    }

    private var replacementErrorBinding: Binding<Bool> {
        Binding(
            get: { replacementErrorMessage != nil },
            set: { newValue in
                if !newValue {
                    replacementErrorMessage = nil
                }
            }
        )
    }
}

private struct CalendarReplacementContext: Identifiable {
    let calendar: EKCalendar
    let affectedPresets: [Preset]

    var id: String { calendar.calendarIdentifier }
}

private struct CalendarReplacementSheet: View {
    let context: CalendarReplacementContext
    let replacementOptions: [EKCalendar]
    @Binding var selectedCalendarId: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reassign Calendar")
                .font(.title2)
                .fontWeight(.bold)

            Text("\"\(context.calendar.title)\" is used in the presets below. Choose a replacement calendar before hiding it.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            if !context.affectedPresets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Affected Presets (\(context.affectedPresets.count))")
                        .font(.headline)
                    ForEach(context.affectedPresets) { preset in
                        HStack(spacing: 6) {
                            Image(systemName: preset.icon)
                                .foregroundColor(.accentColor)
                                .frame(width: 18)
                            Text(preset.name)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(8)
                    }
                }
            }

            Picker("Replacement Calendar", selection: $selectedCalendarId) {
                Text("Select a calendar...").tag("")
                ForEach(replacementOptions, id: \.calendarIdentifier) { option in
                    Text(option.title).tag(option.calendarIdentifier)
                }
            }
            .pickerStyle(.menu)

            Spacer(minLength: 0)

            HStack {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                Spacer()
                Button("Replace & Hide") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCalendarId.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 380)
    }
}
