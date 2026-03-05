import Foundation
import AVFoundation
import CoreAudio
import SwiftUI

class SessionAudioService: ObservableObject {

    // MARK: - Published state

    @Published var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: "TaskScheduler.SessionAudioMuted")
            if isMuted { stopAmbient() } else if shouldBePlayingAmbient { resumeAmbient() }
        }
    }
    @Published var isPlaying: Bool = false
    @Published var availableOutputDevices: [AudioOutputDevice] = []

    // MARK: - Audio engine

    private var ambientEngine = AVAudioEngine()
    private var ambientPlayerNode = AVAudioPlayerNode()
    private var varispeedNode = AVAudioUnitVarispeed()
    private var transitionPlayer: AVAudioPlayer?

    private var currentAmbientBuffer: AVAudioPCMBuffer?
    private var currentAmbientConfig: SessionSoundConfig?
    private var shouldBePlayingAmbient = false

    private var deviceListenerBlock: AudioObjectPropertyListenerBlock?

    // MARK: - Output device model

    struct AudioOutputDevice: Identifiable, Equatable, Hashable {
        let id: AudioDeviceID
        let uid: String
        let name: String
    }

    // MARK: - Sound file mapping

    private static let ambientFiles: [String: (name: String, ext: String)] = [
        "Clock Ticking": ("Clock Ticking", "wav"),
        "Clock Ticking Slow": ("Clock Ticking Slow", "wav"),
        "Duskfall on a River": ("Duskfall on a River", "mp3"),
        "Light Rain": ("Light Rain Falling on Forest Floor", "mp3"),
        "Mountain Atmosphere": ("Mountain Atmosphere", "mp3"),
        "Ocean Waves": ("Ocean Waves", "mp3"),
        "Peaceful Wind": ("Peaceful Wind Atop a Hill", "mp3"),
        "Thunder in the Woods": ("Thunder in the Woods", "mp3"),
    ]

    private static let transitionFiles: [String: (name: String, ext: String)] = [
        "Kitchen Timer": ("Kitchen Timer", "wav"),
        "Gong": ("Gong", "mp3"),
    ]

    // MARK: - Init

    init() {
        self.isMuted = UserDefaults.standard.bool(forKey: "TaskScheduler.SessionAudioMuted")
        setupAmbientEngine()
        refreshOutputDevices()
        observeDeviceChanges()
    }

    deinit {
        removeDeviceListener()
    }

    // MARK: - Ambient Engine Setup

    private func setupAmbientEngine() {
        ambientEngine.attach(ambientPlayerNode)
        ambientEngine.attach(varispeedNode)
        ambientEngine.connect(ambientPlayerNode, to: varispeedNode, format: nil)
        ambientEngine.connect(varispeedNode, to: ambientEngine.mainMixerNode, format: nil)
    }

    // MARK: - Ambient Playback

    func playAmbient(config: SessionSoundConfig) {
        guard !isMuted, config.sound != "Off" else {
            shouldBePlayingAmbient = config.sound != "Off"
            currentAmbientConfig = config
            return
        }

        stopAmbientInternal()
        currentAmbientConfig = config
        shouldBePlayingAmbient = true

        guard let buffer = loadAmbientBuffer(for: config) else { return }
        currentAmbientBuffer = buffer

        // Reconnect with the buffer's exact format to prevent format mismatch crash
        ambientEngine.connect(ambientPlayerNode, to: varispeedNode, format: buffer.format)
        ambientEngine.connect(varispeedNode, to: ambientEngine.mainMixerNode, format: buffer.format)
        ambientPlayerNode.volume = config.volume
        varispeedNode.rate = 1.0

        do {
            try ambientEngine.start()
            ambientPlayerNode.scheduleBuffer(buffer, at: nil, options: .loops)
            ambientPlayerNode.play()
            DispatchQueue.main.async { self.isPlaying = true }
        } catch {
            print("SessionAudioService: Failed to start ambient engine: \(error)")
        }
    }

    /// Update ambient sound dynamically (e.g. when user changes settings mid-session)
    func updateAmbientIfPlaying(config: SessionSoundConfig) {
        guard shouldBePlayingAmbient || isPlaying else { return }

        if currentAmbientConfig?.sound != config.sound {
            // Sound type changed — restart or stop
            if config.sound == "Off" {
                stopAmbient()
            } else {
                playAmbient(config: config)
            }
        } else if currentAmbientConfig?.volume != config.volume {
            // Volume only — adjust directly without engine restart
            ambientPlayerNode.volume = config.volume
            currentAmbientConfig = config
        }
    }

    /// Update playback rate for accelerando effect
    func updatePlaybackRate(progress: Double, accelerando: AccelerandoConfig) {
        guard accelerando.enabled else {
            if varispeedNode.rate != 1.0 {
                varispeedNode.rate = 1.0
            }
            return
        }
        // Linear interpolation: 1.0 at progress=0, maxMultiplier at progress=1.0
        let rate = Float(1.0 + (accelerando.maxMultiplier - 1.0) * progress)
        varispeedNode.rate = rate
    }

    func stopAmbient() {
        stopAmbientInternal()
        shouldBePlayingAmbient = false
        currentAmbientConfig = nil
    }

    /// Stops engine/player without clearing state (used internally before restarting)
    private func stopAmbientInternal() {
        ambientPlayerNode.stop()
        varispeedNode.rate = 1.0
        if ambientEngine.isRunning {
            ambientEngine.stop()
        }
        currentAmbientBuffer = nil
        DispatchQueue.main.async { self.isPlaying = false }
    }

    private func resumeAmbient() {
        guard let config = currentAmbientConfig, config.sound != "Off" else { return }
        playAmbient(config: config)
    }

    // MARK: - Transition Playback

    func playTransition(config: TransitionSoundConfig) {
        guard !isMuted, config.sound != "Off" else { return }

        guard let url = transitionSoundURL(for: config) else { return }

        do {
            transitionPlayer = try AVAudioPlayer(contentsOf: url)
            transitionPlayer?.volume = config.volume
            transitionPlayer?.play()
        } catch {
            print("SessionAudioService: Failed to play transition sound: \(error)")
        }
    }

    // MARK: - Sound file loading

    private func loadAmbientBuffer(for config: SessionSoundConfig) -> AVAudioPCMBuffer? {
        guard let url = ambientSoundURL(for: config) else { return nil }

        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
            try file.read(into: buffer)
            return buffer
        } catch {
            print("SessionAudioService: Failed to load ambient sound: \(error)")
            return nil
        }
    }

    private func ambientSoundURL(for config: SessionSoundConfig) -> URL? {
        // Custom sound by path
        if let customPath = config.customSoundPath, !customPath.isEmpty {
            let url = URL(fileURLWithPath: customPath)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        // Custom sound by name (from CustomSoundStore)
        if let entry = CustomSoundStore.shared.entry(named: config.sound) {
            let url = URL(fileURLWithPath: entry.filePath)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        // Built-in sound
        guard let file = Self.ambientFiles[config.sound] else { return nil }
        return Bundle.main.url(forResource: file.name, withExtension: file.ext)
    }

    private func transitionSoundURL(for config: TransitionSoundConfig) -> URL? {
        if let customPath = config.customSoundPath, !customPath.isEmpty {
            let url = URL(fileURLWithPath: customPath)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        // Custom sound by name
        if let entry = CustomSoundStore.shared.entry(named: config.sound) {
            let url = URL(fileURLWithPath: entry.filePath)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        guard let file = Self.transitionFiles[config.sound] else { return nil }
        return Bundle.main.url(forResource: file.name, withExtension: file.ext)
    }

    // MARK: - Output Device Management

    func setOutputDevice(uid: String?) {
        let outputNode = ambientEngine.outputNode
        guard let audioUnit = outputNode.audioUnit else { return }

        let wasRunning = ambientEngine.isRunning
        if wasRunning {
            ambientPlayerNode.stop()
            ambientEngine.stop()
        }

        if let uid = uid, let deviceID = deviceID(forUID: uid) {
            var id = deviceID
            AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &id,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
        }

        if wasRunning, shouldBePlayingAmbient {
            resumeAmbient()
        }
    }

    func refreshOutputDevices() {
        availableOutputDevices = enumerateOutputDevices()
    }

    private func enumerateOutputDevices() -> [AudioOutputDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress, 0, nil, &dataSize
        )
        guard status == noErr else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        let status2 = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress, 0, nil, &dataSize, &deviceIDs
        )
        guard status2 == noErr else { return [] }

        return deviceIDs.compactMap { id -> AudioOutputDevice? in
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            let streamStatus = AudioObjectGetPropertyDataSize(id, &streamAddress, 0, nil, &streamSize)
            var hasOutput = (streamStatus == noErr && streamSize > 0)

            if !hasOutput {
                var outputAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyStreamConfiguration,
                    mScope: kAudioObjectPropertyScopeOutput,
                    mElement: kAudioObjectPropertyElementMain
                )
                var outputSize: UInt32 = 0
                if AudioObjectGetPropertyDataSize(id, &outputAddress, 0, nil, &outputSize) == noErr && outputSize > 0 {
                    let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
                    defer { bufferListPointer.deallocate() }
                    if AudioObjectGetPropertyData(id, &outputAddress, 0, nil, &outputSize, bufferListPointer) == noErr {
                        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
                        let outputChannels = bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
                        hasOutput = outputChannels > 0
                    }
                }
            }

            guard hasOutput else { return nil }

            // Filter out virtual and aggregate devices (Teams, aggregate, etc.)
            let transportType: UInt32 = {
                var address = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyTransportType,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                var value: UInt32 = 0
                var size = UInt32(MemoryLayout<UInt32>.size)
                AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
                return value
            }()

            let excludedTransports: Set<UInt32> = [
                kAudioDeviceTransportTypeAggregate,
                kAudioDeviceTransportTypeVirtual
            ]
            if excludedTransports.contains(transportType) { return nil }

            let name: String = {
                var address = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyDeviceNameCFString,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                var value: CFString = "" as CFString
                var size = UInt32(MemoryLayout<CFString>.size)
                withUnsafeMutablePointer(to: &value) { ptr in
                    _ = AudioObjectGetPropertyData(id, &address, 0, nil, &size, ptr)
                }
                return value as String
            }()

            let uid: String = {
                var address = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyDeviceUID,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                var value: CFString = "" as CFString
                var size = UInt32(MemoryLayout<CFString>.size)
                withUnsafeMutablePointer(to: &value) { ptr in
                    _ = AudioObjectGetPropertyData(id, &address, 0, nil, &size, ptr)
                }
                return value as String
            }()

            guard !name.isEmpty, !uid.isEmpty else { return nil }

            return AudioOutputDevice(id: id, uid: uid, name: name)
        }
    }

    private func deviceID(forUID uid: String) -> AudioDeviceID? {
        availableOutputDevices.first { $0.uid == uid }?.id
    }

    // MARK: - Device change listener

    private func observeDeviceChanges() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refreshOutputDevices()
            }
        }
        deviceListenerBlock = block

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            block
        )
    }

    private func removeDeviceListener() {
        guard let block = deviceListenerBlock else { return }
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            block
        )
    }

    // MARK: - Custom Sound Import

    static func importCustomSound(from sourceURL: URL) -> String? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let soundsDir = appSupport.appendingPathComponent("TaskScheduler/CustomSounds")

        do {
            try FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)
            let dest = soundsDir.appendingPathComponent(sourceURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: sourceURL, to: dest)
            return dest.path
        } catch {
            print("SessionAudioService: Failed to import custom sound: \(error)")
            return nil
        }
    }
}
