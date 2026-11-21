import AppKit
import AudioToolbox
import CoreAudio
import CoreGraphics
import Foundation

struct AudioOutputDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let isDefault: Bool
    let isBluetooth: Bool
}

struct BluetoothDeviceInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let minorType: String
    let batteryMain: String?
    let batteryLeft: String?
    let batteryRight: String?
    let batteryCase: String?
    let isAudio: Bool

    var batterySummary: String? {
        if let left = batteryLeft, let right = batteryRight {
            if let box = batteryCase {
                return "E \(left) • D \(right) • Estojo \(box)"
            }
            return "E \(left) • D \(right)"
        }
        return batteryMain ?? batteryLeft ?? batteryRight ?? batteryCase
    }
}

@MainActor
final class AudioControlService: ObservableObject {
    @Published private(set) var volume: Float = 0.5
    @Published private(set) var isMuted: Bool = false
    @Published private(set) var isMicMuted: Bool = false
    @Published private(set) var brightness: Float = 0.5
    @Published private(set) var outputDevices: [AudioOutputDevice] = []
    @Published private(set) var bluetoothDevices: [BluetoothDeviceInfo] = []
    @Published private(set) var defaultOutputName: String = "Alto-falantes"

    @Published var isDraggingVolume: Bool = false
    @Published var isDraggingBrightness: Bool = false
    @Published var isHoveringVolume: Bool = false
    @Published var isHoveringBrightness: Bool = false
    @Published var volumeOverscroll: CGFloat = 0
    @Published var brightnessOverscroll: CGFloat = 0
    @Published var volumeDragVelocity: CGFloat = 0
    @Published var brightnessDragVelocity: CGFloat = 0

    var onVolumeChanged: ((Float, Bool) -> Void)?
    var onBrightnessChanged: ((Float) -> Void)?
    var onMicMuteChanged: ((Bool) -> Void)?
    var onBluetoothConnected: ((BluetoothDeviceInfo) -> Void)?

    private typealias FGetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias FSetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private var displayServicesHandle: UnsafeMutableRawPointer?
    private var getBrightnessFn: FGetBrightness?
    private var setBrightnessFn: FSetBrightness?

    nonisolated(unsafe) private var currentObservedOutputDevice: AudioDeviceID = 0
    nonisolated(unsafe) private var outputVolumeListenerBlock: AudioObjectPropertyListenerBlock?
    nonisolated(unsafe) private var outputMuteListenerBlock: AudioObjectPropertyListenerBlock?
    nonisolated(unsafe) private var systemDevicesListenerBlock: AudioObjectPropertyListenerBlock?
    nonisolated(unsafe) private var defaultOutputListenerBlock: AudioObjectPropertyListenerBlock?
    nonisolated(unsafe) private var defaultInputListenerBlock: AudioObjectPropertyListenerBlock?

    private var savedMicVolume: Float = 0.8
    private var hasInitializedVolume = false
    private var hasInitializedBrightness = false
    private var hasInitializedBluetooth = false
    private var knownBluetoothIDs = Set<String>()
    private var lastObservedVolume: Float = -1
    private var lastObservedMuted: Bool = false
    private var lastObservedBrightness: Float = -1
    private var lastVolumeHapticEdge: Int = 0
    private var lastBrightnessHapticEdge: Int = 0
    private var prevVolumeDragX: CGFloat?
    private var prevBrightnessDragX: CGFloat?

    private var brightnessTimer: Timer?
    private var bluetoothTimer: Timer?

    init() {
        loadDisplayServices()
        refreshAudioState(emitToast: false)
        refreshBrightness(emitToast: false)
        setupCoreAudioListeners()
        startTimers()
        Task { await refreshBluetoothDevices(emitToast: false) }
    }

    deinit {
        brightnessTimer?.invalidate()
        bluetoothTimer?.invalidate()
        removeSystemListeners()
        if currentObservedOutputDevice != 0 {
            removeOutputDeviceListeners(for: currentObservedOutputDevice)
        }
    }

    var primaryAudioBluetoothDevice: BluetoothDeviceInfo? {
        bluetoothDevices.first(where: { $0.isAudio }) ?? bluetoothDevices.first
    }

    var isDefaultInputBluetooth: Bool {
        guard let dev = defaultDeviceID(isInput: true) else { return false }
        let transport = deviceTransportType(dev)
        return transport == kAudioDeviceTransportTypeBluetooth
            || transport == kAudioDeviceTransportTypeBluetoothLE
    }

    func builtInMicrophoneUID() -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr,
              size > 0 else {
            return nil
        }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else {
            return nil
        }

        for id in ids {
            guard hasInputStreams(id) else { continue }
            if deviceTransportType(id) == kAudioDeviceTransportTypeBuiltIn,
               let uid = deviceUID(id) {
                return uid
            }
        }
        return nil
    }

    var canControlVolume: Bool {
        guard let dev = defaultDeviceID(isInput: false) else { return false }
        return readDeviceVolume(dev, scope: kAudioDevicePropertyScopeOutput) != nil
    }

    var canControlBrightness: Bool {
        guard let getBrightnessFn, setBrightnessFn != nil else { return false }
        var level: Float = 0
        return getBrightnessFn(CGMainDisplayID(), &level) == 0
    }

    func setVolume(_ newVolume: Float) {
        let clamped = max(0, min(1, newVolume))
        volume = clamped

        guard let dev = defaultDeviceID(isInput: false) else { return }
        if isMuted && clamped > 0 {
            setDeviceMute(dev, scope: kAudioDevicePropertyScopeOutput, muted: false)
            isMuted = false
        }
        setDeviceVolume(dev, scope: kAudioDevicePropertyScopeOutput, value: clamped)
    }

    func stepVolume(delta: Float) {
        guard let dev = defaultDeviceID(isInput: false) else { return }
        let current = readDeviceVolume(dev, scope: kAudioDevicePropertyScopeOutput) ?? volume

        var targetVolume = max(0, min(1, current + delta))
        var targetMuted = isMuted

        if delta > 0 {
            if isMuted {
                setDeviceMute(dev, scope: kAudioDevicePropertyScopeOutput, muted: false)
                targetMuted = false
                if current <= 0.001 {
                    targetVolume = max(0, min(1, delta))
                }
            }
            setDeviceVolume(dev, scope: kAudioDevicePropertyScopeOutput, value: targetVolume)
        } else if delta < 0 {
            if targetVolume <= 0.001 {
                targetVolume = 0
                setDeviceVolume(dev, scope: kAudioDevicePropertyScopeOutput, value: 0)
                setDeviceMute(dev, scope: kAudioDevicePropertyScopeOutput, muted: true)
                targetMuted = true
            } else {
                if isMuted {
                    setDeviceMute(dev, scope: kAudioDevicePropertyScopeOutput, muted: false)
                    targetMuted = false
                }
                setDeviceVolume(dev, scope: kAudioDevicePropertyScopeOutput, value: targetVolume)
            }
        }

        let readBack = readDeviceVolume(dev, scope: kAudioDevicePropertyScopeOutput) ?? targetVolume
        volume = readBack
        isMuted = targetMuted
        lastObservedVolume = readBack
        lastObservedMuted = targetMuted
        onVolumeChanged?(readBack, targetMuted)
    }

    func toggleMute() {
        guard let dev = defaultDeviceID(isInput: false) else { return }
        let target = !isMuted
        setDeviceMute(dev, scope: kAudioDevicePropertyScopeOutput, muted: target)
        isMuted = target
        lastObservedMuted = target
        onVolumeChanged?(volume, target)
    }

    func setBrightness(_ newBrightness: Float) {
        let clamped = max(0.02, min(1, newBrightness))
        brightness = clamped
        lastObservedBrightness = clamped
        guard let setBrightnessFn else { return }
        _ = setBrightnessFn(CGMainDisplayID(), clamped)
    }

    func stepBrightness(delta: Float) {
        guard let setBrightnessFn else { return }
        var current = brightness
        if let getBrightnessFn {
            var hardwareLevel: Float = 0
            if getBrightnessFn(CGMainDisplayID(), &hardwareLevel) == 0 {
                current = hardwareLevel
            }
        }
        let next = max(0, min(1, current + delta))
        _ = setBrightnessFn(CGMainDisplayID(), next)
        brightness = next
        lastObservedBrightness = next
        onBrightnessChanged?(next)
    }

    func updateVolumeDrag(rawRatio: Float, locationX: CGFloat) {
        NSCursor.arrow.set()
        if !isDraggingVolume {
            isDraggingVolume = true
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            prevVolumeDragX = locationX
        }
        let deltaX = locationX - (prevVolumeDragX ?? locationX)
        prevVolumeDragX = locationX
        volumeDragVelocity = max(-1, min(1, deltaX / 16.0))
        volumeOverscroll = Self.rubberBandOverscroll(for: rawRatio)

        let clamped = max(0, min(1, rawRatio))
        setVolume(clamped)
        updateEdgeHaptic(value: clamped, lowEdge: 0.001, highEdge: 0.999, resetMargin: 0.02, state: &lastVolumeHapticEdge)
    }

    func endVolumeDrag(rawRatio: Float) {
        NSCursor.arrow.set()
        let clamped = max(0, min(1, rawRatio))
        setVolume(clamped)
        lastObservedVolume = volume
        lastObservedMuted = isMuted
        isDraggingVolume = false
        volumeOverscroll = 0
        volumeDragVelocity = 0
        lastVolumeHapticEdge = 0
        prevVolumeDragX = nil
    }

    func updateBrightnessDrag(rawRatio: Float, locationX: CGFloat) {
        NSCursor.arrow.set()
        if !isDraggingBrightness {
            isDraggingBrightness = true
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            prevBrightnessDragX = locationX
        }
        let deltaX = locationX - (prevBrightnessDragX ?? locationX)
        prevBrightnessDragX = locationX
        brightnessDragVelocity = max(-1, min(1, deltaX / 16.0))
        brightnessOverscroll = Self.rubberBandOverscroll(for: rawRatio)

        let clamped = max(0.02, min(1, rawRatio))
        setBrightness(clamped)
        updateEdgeHaptic(value: clamped, lowEdge: 0.021, highEdge: 0.999, resetMargin: 0.04, state: &lastBrightnessHapticEdge)
    }

    func endBrightnessDrag(rawRatio: Float) {
        NSCursor.arrow.set()
        let clamped = max(0.02, min(1, rawRatio))
        setBrightness(clamped)
        lastObservedBrightness = brightness
        isDraggingBrightness = false
        brightnessOverscroll = 0
        brightnessDragVelocity = 0
        lastBrightnessHapticEdge = 0
        prevBrightnessDragX = nil
    }

    private static func rubberBandOverscroll(for rawRatio: Float) -> CGFloat {
        if rawRatio < 0 {
            return CGFloat(-tanh(Double(-rawRatio) * 3.0))
        }
        if rawRatio > 1 {
            return CGFloat(tanh(Double(rawRatio - 1) * 3.0))
        }
        return 0
    }

    private func updateEdgeHaptic(value: Float, lowEdge: Float, highEdge: Float, resetMargin: Float, state: inout Int) {
        if value <= lowEdge && state != -1 {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            state = -1
        } else if value >= highEdge && state != 1 {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            state = 1
        } else if value > resetMargin && value < 0.98 {
            state = 0
        }
    }

    func toggleMicMute() {
        guard let dev = defaultDeviceID(isInput: true) else { return }
        let targetMuted = !isMicMuted

        if hasMuteProperty(dev, scope: kAudioDevicePropertyScopeInput) {
            if setDeviceMute(dev, scope: kAudioDevicePropertyScopeInput, muted: targetMuted) {
                isMicMuted = targetMuted
                onMicMuteChanged?(targetMuted)
                return
            }
        }

        // Fallback via scalar volume if input device doesn't expose kAudioDevicePropertyMute
        if targetMuted {
            let current = readDeviceVolume(dev, scope: kAudioDevicePropertyScopeInput) ?? 0.8
            if current > 0.01 { savedMicVolume = current }
            setDeviceVolume(dev, scope: kAudioDevicePropertyScopeInput, value: 0)
            isMicMuted = true
        } else {
            let restore = savedMicVolume > 0.05 ? savedMicVolume : 0.8
            setDeviceVolume(dev, scope: kAudioDevicePropertyScopeInput, value: restore)
            isMicMuted = false
        }
        onMicMuteChanged?(isMicMuted)
    }

    func selectOutputDevice(_ deviceID: AudioDeviceID) {
        var id = deviceID
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &id
        )
        if status == noErr {
            refreshAudioState(emitToast: false)
            Task { await refreshBluetoothDevices(emitToast: false) }
        }
    }

    func refreshAllNow() {
        refreshAudioState(emitToast: false)
        refreshBrightness(emitToast: false)
        Task { await refreshBluetoothDevices(emitToast: false) }
    }

    // MARK: - DisplayServices

    private func loadDisplayServices() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_NOW) else { return }
        displayServicesHandle = handle
        if let getSym = dlsym(handle, "DisplayServicesGetBrightness") {
            getBrightnessFn = unsafeBitCast(getSym, to: FGetBrightness.self)
        }
        if let setSym = dlsym(handle, "DisplayServicesSetBrightness") {
            setBrightnessFn = unsafeBitCast(setSym, to: FSetBrightness.self)
        }
    }

    private func refreshBrightness(emitToast: Bool) {
        guard let getBrightnessFn else { return }
        var level: Float = 0
        let err = getBrightnessFn(CGMainDisplayID(), &level)
        guard err == 0 else { return }
        let clamped = max(0, min(1, level))

        if !hasInitializedBrightness {
            brightness = clamped
            lastObservedBrightness = clamped
            hasInitializedBrightness = true
            return
        }

        if abs(clamped - lastObservedBrightness) > 0.012 {
            brightness = clamped
            lastObservedBrightness = clamped
            if emitToast && !isDraggingBrightness {
                onBrightnessChanged?(clamped)
            }
        }
    }

    // MARK: - CoreAudio Listeners & State

    private func setupCoreAudioListeners() {
        let systemObj = AudioObjectID(kAudioObjectSystemObject)

        var defaultOutAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let outBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshAudioState(emitToast: false)
                await self?.refreshBluetoothDevices(emitToast: true)
            }
        }
        defaultOutputListenerBlock = outBlock
        AudioObjectAddPropertyListenerBlock(systemObj, &defaultOutAddr, DispatchQueue.main, outBlock)

        var defaultInAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let inBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshMicState()
            }
        }
        defaultInputListenerBlock = inBlock
        AudioObjectAddPropertyListenerBlock(systemObj, &defaultInAddr, DispatchQueue.main, inBlock)

        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let devBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshOutputDevices()
                await self?.refreshBluetoothDevices(emitToast: true)
            }
        }
        systemDevicesListenerBlock = devBlock
        AudioObjectAddPropertyListenerBlock(systemObj, &devicesAddr, DispatchQueue.main, devBlock)
    }

    nonisolated private func removeSystemListeners() {
        let systemObj = AudioObjectID(kAudioObjectSystemObject)
        if let block = defaultOutputListenerBlock {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(systemObj, &addr, DispatchQueue.main, block)
        }
        if let block = defaultInputListenerBlock {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(systemObj, &addr, DispatchQueue.main, block)
        }
        if let block = systemDevicesListenerBlock {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(systemObj, &addr, DispatchQueue.main, block)
        }
    }

    private func attachOutputDeviceListeners(to deviceID: AudioDeviceID) {
        if currentObservedOutputDevice == deviceID { return }
        if currentObservedOutputDevice != 0 {
            removeOutputDeviceListeners(for: currentObservedOutputDevice)
        }
        currentObservedOutputDevice = deviceID
        guard deviceID != 0 else { return }

        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let volBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.handleOutputVolumeOrMuteNotification()
            }
        }
        outputVolumeListenerBlock = volBlock
        AudioObjectAddPropertyListenerBlock(deviceID, &volAddr, DispatchQueue.main, volBlock)

        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let muteBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.handleOutputVolumeOrMuteNotification()
            }
        }
        outputMuteListenerBlock = muteBlock
        AudioObjectAddPropertyListenerBlock(deviceID, &muteAddr, DispatchQueue.main, muteBlock)
    }

    nonisolated private func removeOutputDeviceListeners(for deviceID: AudioDeviceID) {
        if let volBlock = outputVolumeListenerBlock {
            var volAddr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(deviceID, &volAddr, DispatchQueue.main, volBlock)
        }
        if let muteBlock = outputMuteListenerBlock {
            var muteAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(deviceID, &muteAddr, DispatchQueue.main, muteBlock)
        }
    }

    private func handleOutputVolumeOrMuteNotification() {
        refreshAudioState(emitToast: true)
    }

    private func refreshAudioState(emitToast: Bool) {
        refreshOutputDevices()
        refreshMicState()

        guard let dev = defaultDeviceID(isInput: false) else { return }
        attachOutputDeviceListeners(to: dev)
        defaultOutputName = deviceName(dev) ?? "Alto-falantes"

        let newVol = readDeviceVolume(dev, scope: kAudioDevicePropertyScopeOutput) ?? volume
        let newMuted = readDeviceMute(dev, scope: kAudioDevicePropertyScopeOutput) ?? false

        if !hasInitializedVolume {
            volume = newVol
            isMuted = newMuted
            lastObservedVolume = newVol
            lastObservedMuted = newMuted
            hasInitializedVolume = true
            return
        }

        let changed = abs(newVol - lastObservedVolume) > 0.01 || newMuted != lastObservedMuted
        volume = newVol
        isMuted = newMuted

        if changed {
            lastObservedVolume = newVol
            lastObservedMuted = newMuted
            if emitToast && !isDraggingVolume {
                onVolumeChanged?(newVol, newMuted)
            }
        }
    }

    private func refreshMicState() {
        guard let dev = defaultDeviceID(isInput: true) else {
            isMicMuted = false
            return
        }
        if let muted = readDeviceMute(dev, scope: kAudioDevicePropertyScopeInput) {
            isMicMuted = muted
        } else if let vol = readDeviceVolume(dev, scope: kAudioDevicePropertyScopeInput) {
            isMicMuted = vol <= 0.01
        }
    }

    private func refreshOutputDevices() {
        let defaultID = defaultDeviceID(isInput: false) ?? 0
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr,
              size > 0 else {
            return
        }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else {
            return
        }

        var list: [AudioOutputDevice] = []
        for id in ids {
            guard hasOutputStreams(id), let name = deviceName(id) else { continue }
            let transport = deviceTransportType(id)
            let isBT = transport == kAudioDeviceTransportTypeBluetooth
                || transport == kAudioDeviceTransportTypeBluetoothLE
            list.append(AudioOutputDevice(id: id, name: name, isDefault: id == defaultID, isBluetooth: isBT))
        }
        outputDevices = list
    }

    private func defaultDeviceID(isInput: Bool) -> AudioDeviceID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: isInput ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dev: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev)
        return (status == noErr && dev != 0) ? dev : nil
    }

    private func hasOutputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &size)
        return status == noErr && size > 0
    }

    private func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &size)
        return status == noErr && size > 0
    }

    private func deviceUID(_ deviceID: AudioDeviceID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uidRef: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &uidRef)
        guard status == noErr, let str = uidRef?.takeRetainedValue() as String? else { return nil }
        return str
    }

    private func deviceName(_ deviceID: AudioDeviceID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var nameRef: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &nameRef)
        guard status == noErr, let str = nameRef?.takeRetainedValue() as String? else { return nil }
        return str
    }

    private func deviceTransportType(_ deviceID: AudioDeviceID) -> UInt32 {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        _ = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &transport)
        return transport
    }

    private func readDeviceVolume(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Float? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var vol: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        if AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &vol) == noErr {
            return vol
        }

        // Fallback to channel 1 scalar volume
        addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: scope,
            mElement: 1
        )
        if AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &vol) == noErr {
            return vol
        }
        return nil
    }

    @discardableResult
    private func setDeviceVolume(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, value: Float) -> Bool {
        var val = Float32(max(0, min(1, value)))
        let size = UInt32(MemoryLayout<Float32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &val) == noErr {
            return true
        }

        var succeeded = false
        for channel: UInt32 in [0, 1, 2] {
            var chAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: scope,
                mElement: channel
            )
            if AudioObjectSetPropertyData(deviceID, &chAddr, 0, nil, size, &val) == noErr {
                succeeded = true
            }
        }
        return succeeded
    }

    private func hasMuteProperty(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        return AudioObjectHasProperty(deviceID, &addr)
    }

    private func readDeviceMute(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &muted) == noErr else {
            return nil
        }
        return muted != 0
    }

    @discardableResult
    private func setDeviceMute(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, muted: Bool) -> Bool {
        var val: UInt32 = muted ? 1 : 0
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        return AudioObjectSetPropertyData(deviceID, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &val) == noErr
    }

    // MARK: - Timers & Bluetooth Polling

    private func startTimers() {
        let bTimer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshBrightness(emitToast: true)
            }
        }
        RunLoop.main.add(bTimer, forMode: .common)
        brightnessTimer = bTimer

        let btTimer = Timer(timeInterval: 20.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshBluetoothDevices(emitToast: true)
            }
        }
        RunLoop.main.add(btTimer, forMode: .common)
        bluetoothTimer = btTimer
    }

    func refreshBluetoothDevices(emitToast: Bool) async {
        let devices = await Self.fetchConnectedBluetoothDevices()
        let newIDs = Set(devices.map(\.id))

        if hasInitializedBluetooth && emitToast {
            let newlyConnected = devices.filter { !knownBluetoothIDs.contains($0.id) }
            if let firstNew = newlyConnected.first(where: \.isAudio) ?? newlyConnected.first {
                onBluetoothConnected?(firstNew)
            }
        }

        knownBluetoothIDs = newIDs
        bluetoothDevices = devices
        hasInitializedBluetooth = true
    }

    private static func fetchConnectedBluetoothDevices() async -> [BluetoothDeviceInfo] {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            process.arguments = ["SPBluetoothDataType", "-json"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
            } catch {
                return []
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let entries = root["SPBluetoothDataType"] as? [[String: Any]] else {
                return []
            }

            var parsed: [BluetoothDeviceInfo] = []
            for entry in entries {
                guard let connectedList = entry["device_connected"] as? [[String: Any]] else { continue }
                for itemDict in connectedList {
                    for (deviceName, rawProps) in itemDict {
                        guard let props = rawProps as? [String: Any] else { continue }
                        let address = (props["device_address"] as? String) ?? deviceName
                        let minorType = (props["device_minorType"] as? String) ?? ""
                        let services = (props["device_services"] as? String) ?? ""
                        let isAudio = minorType.localizedCaseInsensitiveContains("Headphone")
                            || minorType.localizedCaseInsensitiveContains("Headset")
                            || minorType.localizedCaseInsensitiveContains("Speaker")
                            || services.contains("A2DP")
                            || services.contains("HFP")

                        parsed.append(
                            BluetoothDeviceInfo(
                                id: address,
                                name: deviceName,
                                minorType: minorType,
                                batteryMain: props["device_batteryLevelMain"] as? String,
                                batteryLeft: props["device_batteryLevelLeft"] as? String,
                                batteryRight: props["device_batteryLevelRight"] as? String,
                                batteryCase: props["device_batteryLevelCase"] as? String,
                                isAudio: isAudio
                            )
                        )
                    }
                }
            }
            return parsed
        }.value
    }
}
