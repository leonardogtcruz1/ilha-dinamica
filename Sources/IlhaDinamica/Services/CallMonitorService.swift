import AppKit
import ApplicationServices
import CoreAudio
import Foundation
import SwiftUI

@MainActor
final class CallMonitorService: ObservableObject {
    @Published private(set) var isIncomingCallRinging: Bool = false
    @Published private(set) var incomingCallerName: String = ""
    @Published private(set) var incomingSourceName: String = ""
    @Published private(set) var incomingIsVideo: Bool = false
    @Published private(set) var incomingCanControlButtons: Bool = false

    @Published private(set) var isInActiveCall: Bool = false
    @Published private(set) var activeCallTitle: String = ""
    @Published private(set) var activeCallSourceName: String = ""
    @Published private(set) var activeCallBundleID: String? = nil
    @Published private(set) var activeCallElapsed: TimeInterval = 0

    var onIncomingCallStarted: ((String, String, Bool, Bool) -> Void)?
    var onIncomingCallEnded: (() -> Void)?

    var formattedActiveDuration: String {
        let total = max(0, Int(activeCallElapsed.rounded(.down)))
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%02d:%02d", mins, secs)
    }

    private var pollTimer: Timer?
    private var lastElapsedTickDate: Date = Date()

    private var acceptButtonElement: AXUIElement?
    private var declineButtonElement: AXUIElement?
    private var incomingSourceBundleID: String?
    private var lastIncomingSignature: String = ""
    private var suppressedSignature: String = ""
    private var suppressedUntil: Date = .distantPast
    private var lastIncomingSeenTimestamp: Date = .distantPast
    private var recentRingingCallerName: String = ""
    private var recentRingingSourceName: String = ""

    private var isPreviewRinging: Bool = false
    private var previewRingingUntil: Date = .distantPast
    private var isPreviewActiveCall: Bool = false
    private var previewActiveUntil: Date = .distantPast

    private struct AudioProcessState {
        let bundleID: String
        let isRunningInput: Bool
        let isRunningOutput: Bool
    }

    private struct AXIncomingCallMatch {
        let callerName: String
        let sourceName: String
        let sourceBundleID: String?
        let isVideo: Bool
        let acceptButton: AXUIElement?
        let declineButton: AXUIElement?
    }

    init() {
        startTimer()
    }

    deinit {
        pollTimer?.invalidate()
    }

    private func startTimer() {
        pollTimer?.invalidate()
        lastElapsedTickDate = Date()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        timer.tolerance = 0.08
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func acceptIncomingCall() {
        if isPreviewRinging {
            isPreviewRinging = false
            previewRingingUntil = .distantPast
            clearIncomingState(notifyEnded: true)
            isPreviewActiveCall = true
            previewActiveUntil = Date().addingTimeInterval(6.0)
            isInActiveCall = true
            activeCallTitle = "Contato Teste"
            activeCallSourceName = "iPhone / FaceTime"
            activeCallBundleID = "com.apple.FaceTime"
            activeCallElapsed = 0
            lastElapsedTickDate = Date()
            return
        }

        if let acceptButton = acceptButtonElement {
            _ = AXUIElementPerformAction(acceptButton, kAXPressAction as CFString)
        } else if let bundleID = incomingSourceBundleID ?? detectPreferredCallBundleID() {
            openApp(bundleIdentifier: bundleID)
        }

        suppressedSignature = lastIncomingSignature
        suppressedUntil = Date().addingTimeInterval(8.0)
        recentRingingCallerName = incomingCallerName
        recentRingingSourceName = incomingSourceName
        lastIncomingSeenTimestamp = Date()
        clearIncomingState(notifyEnded: true)
    }

    func declineIncomingCall() {
        if isPreviewRinging {
            isPreviewRinging = false
            previewRingingUntil = .distantPast
            clearIncomingState(notifyEnded: true)
            return
        }

        if let declineButton = declineButtonElement {
            _ = AXUIElementPerformAction(declineButton, kAXPressAction as CFString)
        }

        suppressedSignature = lastIncomingSignature
        suppressedUntil = Date().addingTimeInterval(8.0)
        clearIncomingState(notifyEnded: true)
    }

    func openActiveCallApp() {
        if let bundleID = activeCallBundleID {
            openApp(bundleIdentifier: bundleID)
        } else if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.FaceTime") != nil {
            openApp(bundleIdentifier: "com.apple.FaceTime")
        }
    }

    func triggerPreviewCall() {
        isPreviewActiveCall = false
        previewActiveUntil = .distantPast
        isPreviewRinging = true
        previewRingingUntil = Date().addingTimeInterval(10.0)
        acceptButtonElement = nil
        declineButtonElement = nil
        incomingSourceBundleID = "com.apple.FaceTime"

        incomingCallerName = "Contato Teste"
        incomingSourceName = "iPhone / FaceTime"
        incomingIsVideo = false
        incomingCanControlButtons = true
        isIncomingCallRinging = true
        lastIncomingSignature = "preview|\(Date().timeIntervalSince1970)"
        onIncomingCallStarted?("Contato Teste", "iPhone / FaceTime", false, true)
    }

    private func tick() {
        let now = Date()
        let delta = max(0, min(2.0, now.timeIntervalSince(lastElapsedTickDate)))
        lastElapsedTickDate = now

        if isPreviewRinging {
            if now >= previewRingingUntil {
                isPreviewRinging = false
                previewRingingUntil = .distantPast
                clearIncomingState(notifyEnded: true)
            } else {
                return
            }
        }

        if isPreviewActiveCall {
            if now < previewActiveUntil {
                activeCallElapsed += delta
                isInActiveCall = true
                return
            } else {
                isPreviewActiveCall = false
                previewActiveUntil = .distantPast
            }
        }

        let audioStates = Self.queryAudioProcessStates()
        let telephonyRinging = detectTelephonyRinging(audioStates: audioStates)

        let axMatch = scanIncomingCallAX(audioStates: audioStates)

        if let match = axMatch {
            let signature = "\(match.sourceName)|\(match.callerName)|\(match.isVideo)"
            let isSuppressed = (signature == suppressedSignature && now < suppressedUntil)
            if !isSuppressed {
                let wasRinging = isIncomingCallRinging
                let metadataChanged = signature != lastIncomingSignature
                    || ((match.acceptButton != nil || match.declineButton != nil) != incomingCanControlButtons)

                acceptButtonElement = match.acceptButton
                declineButtonElement = match.declineButton
                incomingSourceBundleID = match.sourceBundleID
                incomingCallerName = match.callerName
                incomingSourceName = match.sourceName
                incomingIsVideo = match.isVideo
                incomingCanControlButtons = (match.acceptButton != nil || match.declineButton != nil)
                isIncomingCallRinging = true
                lastIncomingSignature = signature
                lastIncomingSeenTimestamp = now
                recentRingingCallerName = match.callerName
                recentRingingSourceName = match.sourceName

                if !wasRinging || metadataChanged {
                    onIncomingCallStarted?(
                        incomingCallerName,
                        incomingSourceName,
                        incomingIsVideo,
                        incomingCanControlButtons
                    )
                }
            }
        } else if telephonyRinging {
            let fallbackCaller = recentRingingCallerName.isEmpty ? "Chamada recebida" : recentRingingCallerName
            let fallbackSource = recentRingingSourceName.isEmpty ? "iPhone / FaceTime" : recentRingingSourceName
            let signature = "\(fallbackSource)|\(fallbackCaller)|telephony"
            let isSuppressed = (signature == suppressedSignature && now < suppressedUntil)
            if !isSuppressed && !isIncomingCallRinging {
                acceptButtonElement = nil
                declineButtonElement = nil
                incomingSourceBundleID = "com.apple.FaceTime"
                incomingCallerName = fallbackCaller
                incomingSourceName = fallbackSource
                incomingIsVideo = false
                incomingCanControlButtons = false
                isIncomingCallRinging = true
                lastIncomingSignature = signature
                lastIncomingSeenTimestamp = now
                onIncomingCallStarted?(fallbackCaller, fallbackSource, false, false)
            }
        } else if isIncomingCallRinging {
            clearIncomingState(notifyEnded: true)
        }

        // Active / Ongoing call tracking (CoreAudio bidirectional + telephony input)
        let activeCommApp = detectActiveCallAudioSource(audioStates: audioStates)
        let callActiveNow = activeCommApp != nil

        if callActiveNow {
            if isIncomingCallRinging {
                clearIncomingState(notifyEnded: true)
            }
            if !isInActiveCall {
                activeCallElapsed = 0
                isInActiveCall = true
            } else {
                activeCallElapsed += delta
            }

            if let comm = activeCommApp {
                activeCallSourceName = comm.sourceName
                activeCallBundleID = comm.bundleID
            } else {
                activeCallSourceName = "iPhone / FaceTime"
                activeCallBundleID = "com.apple.FaceTime"
            }

            if !recentRingingCallerName.isEmpty && now.timeIntervalSince(lastIncomingSeenTimestamp) < 1800 {
                activeCallTitle = recentRingingCallerName
            } else {
                activeCallTitle = activeCallSourceName
            }
        } else if isInActiveCall {
            isInActiveCall = false
            activeCallTitle = ""
            activeCallSourceName = ""
            activeCallBundleID = nil
            activeCallElapsed = 0
        }
    }

    private func clearIncomingState(notifyEnded: Bool) {
        let wasRinging = isIncomingCallRinging
        isIncomingCallRinging = false
        incomingCallerName = ""
        incomingSourceName = ""
        incomingIsVideo = false
        incomingCanControlButtons = false
        acceptButtonElement = nil
        declineButtonElement = nil
        incomingSourceBundleID = nil
        lastIncomingSignature = ""
        if notifyEnded && wasRinging {
            onIncomingCallEnded?()
        }
    }

    // MARK: - Signal A: NotificationCenter & Calling App AX Scanner

    private func scanIncomingCallAX(audioStates: [AudioProcessState]) -> AXIncomingCallMatch? {
        guard AXIsProcessTrusted() else { return nil }

        var candidateApps: [(pid: pid_t, bundleID: String, hintSource: String?)] = []

        for bundleID in ["com.apple.notificationcenterui", "com.apple.UserNotificationCenter"] {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
                candidateApps.append((app.processIdentifier, bundleID, nil))
            }
        }

        let audioRingingApps: [(bundleID: String, label: String)] = [
            ("com.apple.FaceTime", "FaceTime"),
            ("net.whatsapp.WhatsApp", "WhatsApp"),
            ("com.hnc.Discord", "Discord"),
            ("us.zoom.xos", "Zoom"),
            ("com.microsoft.teams2", "Teams"),
            ("com.microsoft.teams", "Teams"),
            ("ru.keepcoder.Telegram", "Telegram")
        ]
        for entry in audioRingingApps {
            let isOutputtingNoInput = audioStates.contains { state in
                let lower = state.bundleID.lowercased()
                let target = entry.bundleID.lowercased()
                return (lower == target || lower.hasPrefix(target + ".")) && state.isRunningOutput && !state.isRunningInput
            }
            if isOutputtingNoInput {
                for app in NSRunningApplication.runningApplications(withBundleIdentifier: entry.bundleID) {
                    candidateApps.append((app.processIdentifier, entry.bundleID, entry.label))
                }
            }
        }

        for candidate in candidateApps {
            let appElement = AXUIElementCreateApplication(candidate.pid)
            var windowsRef: AnyObject?
            let err = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
            guard err == .success, let windows = windowsRef as? [AXUIElement], !windows.isEmpty else {
                continue
            }

            for window in windows {
                if let match = inspectAXWindow(
                    window,
                    ownerBundleID: candidate.bundleID,
                    hintSourceName: candidate.hintSource
                ) {
                    return match
                }
            }
        }

        return nil
    }

    private func inspectAXWindow(
        _ root: AXUIElement,
        ownerBundleID: String,
        hintSourceName: String?
    ) -> AXIncomingCallMatch? {
        var texts: [String] = []
        var buttons: [(label: String, element: AXUIElement)] = []
        var visitedCount = 0

        func walk(_ element: AXUIElement, depth: Int) {
            guard depth <= 8, visitedCount < 140 else { return }
            visitedCount += 1

            let role = axStringAttribute(element, attribute: kAXRoleAttribute as String) ?? ""
            let title = axStringAttribute(element, attribute: kAXTitleAttribute as String) ?? ""
            let desc = axStringAttribute(element, attribute: kAXDescriptionAttribute as String) ?? ""
            let value = axStringAttribute(element, attribute: kAXValueAttribute as String) ?? ""
            let help = axStringAttribute(element, attribute: kAXHelpAttribute as String) ?? ""

            if role == (kAXButtonRole as String) {
                let buttonLabel = [title, desc, help].first { !$0.isEmpty } ?? ""
                if !buttonLabel.isEmpty {
                    buttons.append((buttonLabel, element))
                }
            } else {
                for raw in [value, title, desc] {
                    let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty && !texts.contains(clean) {
                        texts.append(clean)
                    }
                }
            }

            var childrenRef: AnyObject?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                for child in children {
                    walk(child, depth: depth + 1)
                }
            }
        }

        walk(root, depth: 0)

        let combinedLower = (texts + buttons.map(\.label)).joined(separator: " \n ").lowercased()
        let missedKeywords = ["chamada perdida", "ligação perdida", "missed call", "missed facetime"]
        if missedKeywords.contains(where: { combinedLower.contains($0) }) {
            return nil
        }

        let acceptKeywords = [
            "atender", "aceitar", "accept", "answer", "atender com áudio", "atender com vídeo",
            "audio", "áudio", "video", "vídeo", "voice", "join", "entrar"
        ]
        let strongAcceptKeywords = ["atender", "aceitar", "accept", "answer"]
        let declineKeywords = [
            "recusar", "rejeitar", "decline", "reject", "ignorar", "ignore",
            "desligar", "encerrar", "hang up"
        ]

        let acceptBtn = buttons.first { btn in
            let l = btn.label.lowercased()
            return acceptKeywords.contains(where: { l.contains($0) })
        }
        let strongAcceptBtn = buttons.first { btn in
            let l = btn.label.lowercased()
            return strongAcceptKeywords.contains(where: { l.contains($0) })
        }
        let declineBtn = buttons.first { btn in
            let l = btn.label.lowercased()
            return declineKeywords.contains(where: { l.contains($0) })
        }

        let incomingPhrases = [
            "incoming call", "incoming facetime", "facetime audio", "facetime video",
            "áudio do facetime", "vídeo do facetime", "ligação recebida", "chamada recebida",
            "chamada de voz", "chamada de vídeo", "chamada do iphone", "iphone cellular call",
            "usando seu iphone", "using your iphone", "está ligando", "is calling",
            "chamada de áudio", "audio call", "voice call", "video call"
        ]
        let hasIncomingPhrase = incomingPhrases.contains { combinedLower.contains($0) }
        let hasBothCallButtons = (acceptBtn != nil && declineBtn != nil)
        let hasStrongButtonPair = (strongAcceptBtn != nil && declineBtn != nil)

        guard hasBothCallButtons || (hasIncomingPhrase && (strongAcceptBtn != nil || declineBtn != nil || hintSourceName != nil || combinedLower.contains("iphone") || combinedLower.contains("facetime") || combinedLower.contains("whatsapp"))) else {
            return nil
        }

        if !hasIncomingPhrase && !hasStrongButtonPair {
            return nil
        }

        let (sourceName, sourceBundle) = resolveCallSource(
            combinedLower: combinedLower,
            ownerBundleID: ownerBundleID,
            fallbackName: hintSourceName
        )

        let isVideo = combinedLower.contains("vídeo") || combinedLower.contains("video")
        let buttonLabelsLower = Set(buttons.map { $0.label.lowercased() })
        let callerName = extractCallerName(
            from: texts,
            sourceName: sourceName,
            buttonLabelsLower: buttonLabelsLower
        )

        return AXIncomingCallMatch(
            callerName: callerName,
            sourceName: sourceName,
            sourceBundleID: sourceBundle,
            isVideo: isVideo,
            acceptButton: (strongAcceptBtn ?? acceptBtn)?.element,
            declineButton: declineBtn?.element
        )
    }

    private func resolveCallSource(
        combinedLower: String,
        ownerBundleID: String,
        fallbackName: String?
    ) -> (name: String, bundleID: String?) {
        if combinedLower.contains("whatsapp") || ownerBundleID == "net.whatsapp.WhatsApp" {
            return ("WhatsApp", "net.whatsapp.WhatsApp")
        }
        if combinedLower.contains("iphone") || combinedLower.contains("celular") || combinedLower.contains("cellular") {
            return ("iPhone", "com.apple.FaceTime")
        }
        if combinedLower.contains("facetime") || ownerBundleID == "com.apple.FaceTime" {
            return ("FaceTime", "com.apple.FaceTime")
        }
        if combinedLower.contains("discord") || ownerBundleID == "com.hnc.Discord" {
            return ("Discord", "com.hnc.Discord")
        }
        if combinedLower.contains("telegram") || ownerBundleID == "ru.keepcoder.Telegram" {
            return ("Telegram", "ru.keepcoder.Telegram")
        }
        if combinedLower.contains("teams") || ownerBundleID.hasPrefix("com.microsoft.teams") {
            return ("Teams", ownerBundleID.hasPrefix("com.microsoft.teams") ? ownerBundleID : "com.microsoft.teams2")
        }
        if combinedLower.contains("zoom") || ownerBundleID == "us.zoom.xos" {
            return ("Zoom", "us.zoom.xos")
        }
        if combinedLower.contains("slack") {
            return ("Slack", "com.tinyspeck.slackmacgap")
        }
        if combinedLower.contains("meet") {
            return ("Google Meet", nil)
        }
        if let fallbackName {
            return (fallbackName, ownerBundleID)
        }
        return ("Ligação", "com.apple.FaceTime")
    }

    private func extractCallerName(
        from texts: [String],
        sourceName: String,
        buttonLabelsLower: Set<String>
    ) -> String {
        let genericIgnore: Set<String> = [
            "facetime", "whatsapp", "discord", "telegram", "zoom", "teams", "slack",
            "iphone", "ligação", "notification center", "central de notificações",
            "incoming call", "chamada recebida", "ligação recebida",
            "áudio do facetime", "vídeo do facetime", "facetime audio", "facetime video",
            "chamada de voz", "chamada de vídeo", "chamada de áudio", "chamada do iphone",
            "tocando", "ringing", "usando seu iphone", "using your iphone",
            "whatsapp audio", "whatsapp video", "áudio do whatsapp", "vídeo do whatsapp"
        ]

        for candidate in texts {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2, trimmed.count <= 64 else { continue }
            let lower = trimmed.lowercased()
            if genericIgnore.contains(lower) { continue }
            if buttonLabelsLower.contains(lower) { continue }
            if lower == sourceName.lowercased() { continue }
            if lower.contains("usando seu iphone") || lower.contains("using your iphone") { continue }
            return trimmed
        }
        return sourceName
    }

    private func axStringAttribute(_ element: AXUIElement, attribute: String) -> String? {
        var valueRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef) == .success,
              let str = valueRef as? String else {
            return nil
        }
        let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    // MARK: - Signal C: CoreAudio Bidirectional Call Telemetry

    private static func queryAudioProcessStates() -> [AudioProcessState] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size
        ) == noErr, size > 0 else {
            return []
        }

        let count = Int(size) / MemoryLayout<AudioObjectID>.stride
        var processObjects = [AudioObjectID](repeating: 0, count: count)
        var actualSize = size
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &actualSize,
            &processObjects
        ) == noErr else {
            return []
        }

        let validCount = min(count, Int(actualSize) / MemoryLayout<AudioObjectID>.stride)
        var states: [AudioProcessState] = []

        var inputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningInput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var outputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningOutput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var bundleAddress = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyBundleID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        for idx in 0..<validCount {
            let objID = processObjects[idx]
            var inVal: UInt32 = 0
            var outVal: UInt32 = 0
            var uSize = UInt32(MemoryLayout<UInt32>.size)

            let inStatus = AudioObjectGetPropertyData(objID, &inputAddress, 0, nil, &uSize, &inVal)
            var outSize = UInt32(MemoryLayout<UInt32>.size)
            let outStatus = AudioObjectGetPropertyData(objID, &outputAddress, 0, nil, &outSize, &outVal)

            let isInput = (inStatus == noErr && inVal != 0)
            let isOutput = (outStatus == noErr && outVal != 0)
            guard isInput || isOutput else { continue }

            var cfBundle: Unmanaged<CFString>?
            var bundleSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            let bundleStatus = withUnsafeMutablePointer(to: &cfBundle) { ptr in
                AudioObjectGetPropertyData(objID, &bundleAddress, 0, nil, &bundleSize, ptr)
            }
            if bundleStatus == noErr, let cfStr = cfBundle?.takeRetainedValue() {
                let bid = (cfStr as String).trimmingCharacters(in: .whitespacesAndNewlines)
                if !bid.isEmpty {
                    states.append(AudioProcessState(bundleID: bid, isRunningInput: isInput, isRunningOutput: isOutput))
                }
            }
        }
        return states
    }

    private func detectTelephonyRinging(audioStates: [AudioProcessState]) -> Bool {
        audioStates.contains { state in
            let l = state.bundleID.lowercased()
            let isTelephony = l.contains("callservicesd")
                || l.contains("telephonyutilities")
                || l.contains("avconferenced")
                || l == "com.apple.facetime"
            return isTelephony && state.isRunningOutput && !state.isRunningInput
        }
    }

    private func detectActiveCallAudioSource(audioStates: [AudioProcessState]) -> (sourceName: String, bundleID: String)? {
        let knownCommApps: [(prefix: String, sourceName: String, launchBundle: String)] = [
            ("com.apple.FaceTime", "FaceTime", "com.apple.FaceTime"),
            ("com.apple.TelephonyUtilities", "iPhone / FaceTime", "com.apple.FaceTime"),
            ("com.apple.avconferenced", "FaceTime / iPhone", "com.apple.FaceTime"),
            ("callservicesd", "iPhone / FaceTime", "com.apple.FaceTime"),
            ("net.whatsapp.WhatsApp", "WhatsApp", "net.whatsapp.WhatsApp"),
            ("com.hnc.Discord", "Discord", "com.hnc.Discord"),
            ("us.zoom.xos", "Zoom", "us.zoom.xos"),
            ("com.microsoft.teams2", "Teams", "com.microsoft.teams2"),
            ("com.microsoft.teams", "Teams", "com.microsoft.teams"),
            ("ru.keepcoder.Telegram", "Telegram", "ru.keepcoder.Telegram"),
            ("com.tinyspeck.slackmacgap", "Slack", "com.tinyspeck.slackmacgap")
        ]

        let hasTelephonyInput = audioStates.contains { state in
            let l = state.bundleID.lowercased()
            return state.isRunningInput && (l.contains("avconferenced") || l.contains("callservicesd") || l.contains("telephonyutilities") || l.contains("facetime"))
        }

        for entry in knownCommApps {
            let p = entry.prefix.lowercased()
            let exactBidirectional = audioStates.contains { state in
                let l = state.bundleID.lowercased()
                return (l == p || l.hasPrefix(p + ".")) && state.isRunningInput && state.isRunningOutput
            }
            if exactBidirectional {
                return (entry.sourceName, entry.launchBundle)
            }
        }

        if hasTelephonyInput {
            return ("iPhone / FaceTime", "com.apple.FaceTime")
        }
        return nil
    }

    private func detectPreferredCallBundleID() -> String? {
        for bid in ["com.apple.FaceTime", "net.whatsapp.WhatsApp", "com.hnc.Discord", "us.zoom.xos"] {
            if !NSRunningApplication.runningApplications(withBundleIdentifier: bid).isEmpty {
                return bid
            }
        }
        return "com.apple.FaceTime"
    }

    private func openApp(bundleIdentifier: String) {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: config)
        }
    }
}
