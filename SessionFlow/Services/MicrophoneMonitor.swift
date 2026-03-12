import Foundation
import CoreAudio
import Combine

class MicrophoneMonitor: ObservableObject {
    @Published private(set) var isMicActive = false

    private var listenerBlock: AudioObjectPropertyListenerBlock?
    private var observedDevice: AudioDeviceID = 0

    init() {
        observeDefaultInputDevice()
    }

    deinit {
        removeListener()
    }

    private func observeDefaultInputDevice() {
        // Get default input device
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )
        guard status == noErr, deviceID != 0 else { return }

        observedDevice = deviceID
        updateMicState()

        // Listen for changes to "is running somewhere"
        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateMicState() }
        }
        listenerBlock = block

        AudioObjectAddPropertyListenerBlock(deviceID, &runningAddress, DispatchQueue.main, block)

        // Also listen for default input device changes
        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.removeListener()
                self?.observeDefaultInputDevice()
            }
        }
    }

    private func updateMicState() {
        guard observedDevice != 0 else { return }

        // Check if input device has input streams running
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(observedDevice, &address, 0, nil, &size, &isRunning)

        let active = (status == noErr && isRunning != 0)
        if isMicActive != active {
            isMicActive = active
        }
    }

    private func removeListener() {
        guard let block = listenerBlock, observedDevice != 0 else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(observedDevice, &address, DispatchQueue.main, block)
        listenerBlock = nil
    }
}
