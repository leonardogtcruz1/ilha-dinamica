import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import Foundation
import IOKit.hidsystem

@MainActor
final class MediaKeyInterceptor: ObservableObject {
    @Published private(set) var isActive: Bool = false
    @Published private(set) var isAccessibilityGranted: Bool = AXIsProcessTrusted()

    private let settings: SettingsStore
    private let audio: AudioControlService

    nonisolated(unsafe) private var eventTap: CFMachPort?
    nonisolated(unsafe) private var runLoopSource: CFRunLoopSource?
    private var pollTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var hasPromptedOnce = false

    init(settings: SettingsStore, audio: AudioControlService) {
        self.settings = settings
        self.audio = audio
    }

    deinit {
        pollTimer?.invalidate()
        tearDownTap()
    }

    func start() {
        Publishers.CombineLatest(settings.$replaceSystemHUD, settings.$showHudToasts)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.syncState(promptIfNeeded: false)
            }
            .store(in: &cancellables)

        syncState(promptIfNeeded: true)
    }

    func requestAccessibilityAndEnable() {
        hasPromptedOnce = true
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: kCFBooleanTrue!] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        syncState(promptIfNeeded: false)
    }

    func disable() {
        stopPermissionPolling()
        tearDownTap()
        isActive = false
    }

    private func syncState(promptIfNeeded: Bool) {
        let trusted = AXIsProcessTrusted()
        isAccessibilityGranted = trusted

        let shouldIntercept = settings.replaceSystemHUD && settings.showHudToasts
        guard shouldIntercept else {
            disable()
            return
        }

        if trusted {
            stopPermissionPolling()
            if eventTap == nil {
                installEventTap()
            }
            return
        }

        tearDownTap()
        isActive = false

        if promptIfNeeded && !hasPromptedOnce {
            hasPromptedOnce = true
            let promptKey = "AXTrustedCheckOptionPrompt" as CFString
            let options = [promptKey: kCFBooleanTrue!] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }

        startPermissionPolling()
    }

    private func installEventTap() {
        tearDownTap()

        // Event type 14 = NX_SYSDEFINED (hardware media/brightness keys)
        let mask: CGEventMask = CGEventMask(1 << 14)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mediaKeyTapCallback,
            userInfo: refcon
        ) else {
            isActive = false
            startPermissionPolling()
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            isActive = false
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        isActive = true
    }

    nonisolated private func tearDownTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }

    private func startPermissionPolling() {
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let trusted = AXIsProcessTrusted()
                self.isAccessibilityGranted = trusted
                if trusted {
                    self.syncState(promptIfNeeded: false)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPermissionPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    fileprivate func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type.rawValue == 14,
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.type == .systemDefined,
              nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passUnretained(event)
        }

        let data1 = nsEvent.data1
        let keyCode = Int32((data1 & 0xFFFF_0000) >> 16)
        let keyFlags = data1 & 0x0000_FFFF
        let keyState = (keyFlags & 0xFF00) >> 8
        let isRepeat = (keyFlags & 0x1) != 0

        guard keyState == 0x0A || keyState == 0x0B else {
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        // Preserve Command, Control, and Option+Key (which opens Sound/Display Settings)
        if flags.contains(.maskCommand)
            || flags.contains(.maskControl)
            || (flags.contains(.maskAlternate) && !flags.contains(.maskShift)) {
            return Unmanaged.passUnretained(event)
        }

        let step: Float = (flags.contains(.maskAlternate) && flags.contains(.maskShift))
            ? (1.0 / 64.0)
            : (1.0 / 16.0)
        let isKeyDown = (keyState == 0x0A)

        switch keyCode {
        case NX_KEYTYPE_SOUND_UP:
            guard audio.canControlVolume else { return Unmanaged.passUnretained(event) }
            if isKeyDown {
                DispatchQueue.main.async { [weak self] in
                    self?.audio.stepVolume(delta: step)
                }
            }
            return nil

        case NX_KEYTYPE_SOUND_DOWN:
            guard audio.canControlVolume else { return Unmanaged.passUnretained(event) }
            if isKeyDown {
                DispatchQueue.main.async { [weak self] in
                    self?.audio.stepVolume(delta: -step)
                }
            }
            return nil

        case NX_KEYTYPE_MUTE:
            guard audio.canControlVolume else { return Unmanaged.passUnretained(event) }
            if isKeyDown && !isRepeat {
                DispatchQueue.main.async { [weak self] in
                    self?.audio.toggleMute()
                }
            }
            return nil

        case NX_KEYTYPE_BRIGHTNESS_UP:
            guard audio.canControlBrightness else { return Unmanaged.passUnretained(event) }
            if isKeyDown {
                DispatchQueue.main.async { [weak self] in
                    self?.audio.stepBrightness(delta: step)
                }
            }
            return nil

        case NX_KEYTYPE_BRIGHTNESS_DOWN:
            guard audio.canControlBrightness else { return Unmanaged.passUnretained(event) }
            if isKeyDown {
                DispatchQueue.main.async { [weak self] in
                    self?.audio.stepBrightness(delta: -step)
                }
            }
            return nil

        default:
            return Unmanaged.passUnretained(event)
        }
    }
}

private func mediaKeyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()
    return MainActor.assumeIsolated {
        interceptor.handleEvent(type: type, event: event)
    }
}
