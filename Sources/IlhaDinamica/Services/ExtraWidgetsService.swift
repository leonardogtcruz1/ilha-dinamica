import AppKit
import ApplicationServices
import AVFoundation
import Combine
import CoreGraphics
import CoreImage.CIFilterBuiltins
import Darwin
import Foundation
import IOKit.pwr_mgt
import os

struct CalcHistoryItem: Identifiable, Equatable {
    let id: UUID
    let expression: String
    let result: String

    init(id: UUID = UUID(), expression: String, result: String) {
        self.id = id
        self.expression = expression
        self.result = result
    }
}

struct PickedColorItem: Identifiable, Equatable {
    let id: UUID
    let hex: String
    let rgb: String
    let swiftUICode: String
    let red: Double
    let green: Double
    let blue: Double

    init(id: UUID = UUID(), hex: String, rgb: String, swiftUICode: String, red: Double, green: Double, blue: Double) {
        self.id = id
        self.hex = hex
        self.rgb = rgb
        self.swiftUICode = swiftUICode
        self.red = red
        self.green = green
        self.blue = blue
    }
}

struct LauncherItem: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String
    let isFolder: Bool
    let isCustom: Bool
}

struct WorldCityItem: Identifiable, Equatable {
    let id: String
    let name: String
    let timeZoneIdentifier: String
    let flag: String
}

enum AmbientPreset: String, CaseIterable, Identifiable, Equatable {
    case rain
    case brownNoise
    case ocean
    case fireplace
    case whiteNoise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rain: return "Chuva"
        case .brownNoise: return "Ruído Marrom"
        case .ocean: return "Oceano"
        case .fireplace: return "Lareira"
        case .whiteNoise: return "Ruído Branco"
        }
    }

    var iconName: String {
        switch self {
        case .rain: return "cloud.rain.fill"
        case .brownNoise: return "waveform.low"
        case .ocean: return "water.waves"
        case .fireplace: return "flame.fill"
        case .whiteNoise: return "wind"
        }
    }
}

private enum MathExpressionEvaluator {
    static func evaluate(_ raw: String) -> Double? {
        let normalized = raw
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }
        var parser = Parser(chars: Array(normalized))
        guard let value = parser.parseExpression(), parser.isAtEnd else {
            return nil
        }
        guard value.isFinite, !value.isNaN else { return nil }
        return value
    }

    static func format(_ value: Double) -> String {
        if abs(value) < 1e-10 {
            return "0"
        }
        let rounded = value.rounded()
        if abs(value - rounded) < 1e-9 && abs(value) < 1e14 {
            return String(format: "%.0f", rounded)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 6
        formatter.minimumFractionDigits = 0
        formatter.decimalSeparator = "."
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.4g", value)
    }

    private struct Parser {
        let chars: [Character]
        var index: Int = 0

        var isAtEnd: Bool {
            var i = index
            while i < chars.count, chars[i].isWhitespace {
                i += 1
            }
            return i >= chars.count
        }

        private mutating func skipWhitespace() {
            while index < chars.count, chars[index].isWhitespace {
                index += 1
            }
        }

        mutating func peekNonWhitespace() -> Character? {
            skipWhitespace()
            guard index < chars.count else { return nil }
            return chars[index]
        }

        mutating func parseExpression() -> Double? {
            guard var lhs = parseTerm() else { return nil }
            while let op = peekNonWhitespace(), op == "+" || op == "-" {
                index += 1
                guard let rhs = parseTerm() else { return nil }
                lhs = (op == "+") ? (lhs + rhs) : (lhs - rhs)
            }
            return lhs
        }

        private mutating func parseTerm() -> Double? {
            guard var lhs = parsePower() else { return nil }
            while let op = peekNonWhitespace(), op == "*" || op == "/" {
                index += 1
                guard let rhs = parsePower() else { return nil }
                if op == "*" {
                    lhs *= rhs
                } else {
                    guard abs(rhs) > 1e-12 else { return nil }
                    lhs /= rhs
                }
            }
            return lhs
        }

        private mutating func parsePower() -> Double? {
            guard var base = parseUnary() else { return nil }
            if peekNonWhitespace() == "^" {
                index += 1
                guard let exp = parsePower() else { return nil }
                base = pow(base, exp)
            }
            return base
        }

        private mutating func parseUnary() -> Double? {
            if let ch = peekNonWhitespace(), ch == "+" || ch == "-" {
                index += 1
                guard let operand = parseUnary() else { return nil }
                return (ch == "-") ? -operand : operand
            }
            return parsePostfix()
        }

        private mutating func parsePostfix() -> Double? {
            guard var val = parsePrimary() else { return nil }
            while peekNonWhitespace() == "%" {
                index += 1
                val /= 100.0
            }
            return val
        }

        private mutating func parsePrimary() -> Double? {
            guard let ch = peekNonWhitespace() else { return nil }
            if ch == "(" {
                index += 1
                guard let inner = parseExpression(), peekNonWhitespace() == ")" else {
                    return nil
                }
                index += 1
                return inner
            }

            let start = index
            var sawDigit = false
            var sawDot = false
            while index < chars.count {
                let c = chars[index]
                if c.isNumber {
                    sawDigit = true
                    index += 1
                } else if c == "." && !sawDot {
                    sawDot = true
                    index += 1
                } else {
                    break
                }
            }
            guard sawDigit else { return nil }
            return Double(String(chars[start..<index]))
        }
    }
}

private final class AmbientSynthEngine: @unchecked Sendable {
    private struct RenderState {
        var preset: AmbientPreset? = nil
        var volume: Float = 0.45
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        var brown: Double = 0
        var pinkB0: Double = 0
        var pinkB1: Double = 0
        var pinkB2: Double = 0
        var lowPass: Double = 0
        var phase: Double = 0
        var dropEnv: Double = 0
        var crackleEnv: Double = 0
    }

    private let stateLock = OSAllocatedUnfairLock(initialState: RenderState())
    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var isRunning = false

    func configure(preset: AmbientPreset?, volume: Float) {
        stateLock.withLock { st in
            st.preset = preset
            st.volume = max(0, min(1, volume))
        }
        if preset != nil {
            startIfNeeded()
        } else {
            stop()
        }
    }

    func updateVolume(_ volume: Float) {
        stateLock.withLock { st in
            st.volume = max(0, min(1, volume))
        }
    }

    func stop() {
        stateLock.withLock { st in
            st.preset = nil
        }
        if isRunning {
            engine?.stop()
            isRunning = false
        }
    }

    private func startIfNeeded() {
        if isRunning { return }
        if engine == nil {
            let eng = AVAudioEngine()
            let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
            let lock = self.stateLock

            let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
                let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
                lock.withLock { st in
                    guard let preset = st.preset else {
                        for buffer in ablPointer {
                            if let ptr = buffer.mData?.assumingMemoryBound(to: Float.self) {
                                for frame in 0..<Int(frameCount) {
                                    ptr[frame] = 0
                                }
                            }
                        }
                        return
                    }

                    let gain = Double(st.volume) * 0.45
                    for frame in 0..<Int(frameCount) {
                        st.seed = st.seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                        let uniform = Double((st.seed >> 33)) / Double(UInt32.max >> 1) - 1.0

                        var sample: Double = 0
                        switch preset {
                        case .whiteNoise:
                            st.lowPass = st.lowPass * 0.65 + uniform * 0.35
                            sample = st.lowPass * 0.55

                        case .brownNoise:
                            st.brown = (st.brown + 0.03 * uniform) * 0.992
                            st.brown = max(-1.0, min(1.0, st.brown))
                            sample = st.brown * 1.4

                        case .rain:
                            st.pinkB0 = 0.997 * st.pinkB0 + uniform * 0.029
                            st.pinkB1 = 0.985 * st.pinkB1 + uniform * 0.032
                            st.pinkB2 = 0.950 * st.pinkB2 + uniform * 0.048
                            if (st.seed & 0x7FF) == 17 {
                                st.dropEnv = 0.35
                            }
                            st.dropEnv *= 0.996
                            sample = (st.pinkB0 + st.pinkB1 + st.pinkB2) * 0.48 + uniform * st.dropEnv * 0.25

                        case .ocean:
                            st.phase += 1.0 / (44_100.0 * 7.5)
                            if st.phase > 1.0 { st.phase -= 1.0 }
                            let waveLFO = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(st.phase * .pi * 2.0), 1.6)
                            st.brown = (st.brown + 0.04 * uniform) * 0.988
                            st.brown = max(-1.0, min(1.0, st.brown))
                            sample = st.brown * 1.55 * waveLFO

                        case .fireplace:
                            st.brown = (st.brown + 0.025 * uniform) * 0.993
                            st.brown = max(-1.0, min(1.0, st.brown))
                            if (st.seed & 0xFFF) == 31 {
                                st.crackleEnv = 0.75
                            }
                            st.crackleEnv *= 0.972
                            sample = st.brown * 1.15 + uniform * st.crackleEnv * 0.42
                        }

                        let out = Float(max(-0.95, min(0.95, sample * gain)))
                        for buffer in ablPointer {
                            if let ptr = buffer.mData?.assumingMemoryBound(to: Float.self) {
                                ptr[frame] = out
                            }
                        }
                    }
                }
                return noErr
            }

            eng.attach(node)
            eng.connect(node, to: eng.mainMixerNode, format: format)
            self.engine = eng
            self.sourceNode = node
        }

        do {
            try engine?.start()
            isRunning = true
        } catch {
            isRunning = false
        }
    }
}

@MainActor
final class ExtraWidgetsService: ObservableObject {
    private enum Keys {
        static let customLauncherPaths = "extraWidgets.customLauncherPaths"
        static let qrText = "extraWidgets.qrText"
        static let ambientVolume = "extraWidgets.ambientVolume"
    }

    // MARK: - Calculator
    @Published var calcExpression: String = "" {
        didSet { evaluateCalcLive() }
    }
    @Published var calcResult: String = "0"
    @Published var calcError: Bool = false
    @Published var calcHistory: [CalcHistoryItem] = []
    @Published var calcCopiedNotice: Bool = false

    // MARK: - Color Picker
    @Published private(set) var pickedColors: [PickedColorItem] = []
    @Published private(set) var isSamplingColor: Bool = false
    @Published private(set) var copiedColorLabel: String?

    // MARK: - Stopwatch & Countdown
    @Published var timerModeIsCountdown: Bool = false
    @Published private(set) var stopwatchElapsed: TimeInterval = 0
    @Published private(set) var isStopwatchRunning: Bool = false
    @Published private(set) var stopwatchLaps: [TimeInterval] = []

    @Published private(set) var countdownDurationSeconds: Int = 300
    @Published private(set) var countdownRemainingSeconds: Int = 300
    @Published private(set) var isCountdownRunning: Bool = false

    // MARK: - QR Code
    @Published var qrText: String {
        didSet {
            UserDefaults.standard.set(qrText, forKey: Keys.qrText)
            regenerateQRCode()
        }
    }
    @Published private(set) var qrImage: NSImage?
    @Published private(set) var qrActionFeedback: String?

    // MARK: - Launcher
    @Published private(set) var launcherItems: [LauncherItem] = []
    @Published private(set) var lastLaunchedName: String?

    // MARK: - Network
    @Published private(set) var localIP: String = "—"
    @Published private(set) var interfaceName: String = "Wi-Fi"
    @Published private(set) var publicIP: String = "—"
    @Published private(set) var isFetchingPublicIP: Bool = false
    @Published private(set) var pingMs: Int?
    @Published private(set) var isPinging: Bool = false
    @Published private(set) var downloadHistory: [Double] = Array(repeating: 0, count: 22)
    @Published private(set) var copiedIPNotice: String?

    // MARK: - Caffeine
    @Published private(set) var isCaffeineActive: Bool = false
    @Published private(set) var caffeinePresetMinutes: Int = 0
    @Published private(set) var caffeineRemainingSeconds: Int?

    // MARK: - Screen Clean
    @Published private(set) var isCleaningScreen: Bool = false
    @Published private(set) var cleaningRemainingSeconds: Int = 30
    @Published private(set) var cleaningNeedsAccessibility: Bool = false

    // MARK: - Ambient Sound
    @Published private(set) var activeAmbientPreset: AmbientPreset? = nil
    @Published var ambientVolume: Float {
        didSet {
            let clamped = max(0.05, min(1.0, ambientVolume))
            if abs(clamped - ambientVolume) > 0.001 {
                ambientVolume = clamped
                return
            }
            UserDefaults.standard.set(Double(clamped), forKey: Keys.ambientVolume)
            ambientSynth.updateVolume(clamped)
        }
    }

    // MARK: - World Clock
    @Published private(set) var now: Date = Date()
    let worldCities: [WorldCityItem] = [
        WorldCityItem(id: "sp", name: "São Paulo", timeZoneIdentifier: "America/Sao_Paulo", flag: "🇧🇷"),
        WorldCityItem(id: "ny", name: "Nova York", timeZoneIdentifier: "America/New_York", flag: "🇺🇸"),
        WorldCityItem(id: "ldn", name: "Londres", timeZoneIdentifier: "Europe/London", flag: "🇬🇧"),
        WorldCityItem(id: "lis", name: "Lisboa", timeZoneIdentifier: "Europe/Lisbon", flag: "🇵🇹"),
        WorldCityItem(id: "sf", name: "San Francisco", timeZoneIdentifier: "America/Los_Angeles", flag: "🌉"),
        WorldCityItem(id: "tyo", name: "Tóquio", timeZoneIdentifier: "Asia/Tokyo", flag: "🇯🇵")
    ]

    var isInteracting: Bool {
        isSamplingColor || isCleaningScreen
    }

    var hasActiveTimer: Bool {
        isStopwatchRunning || isCountdownRunning
    }

    private let systemMonitor: SystemMonitorService
    private let ambientSynth = AmbientSynthEngine()
    private var cancellables = Set<AnyCancellable>()
    private var tickTimer: Timer?

    private var stopwatchAccumulated: TimeInterval = 0
    private var stopwatchStartDate: Date?
    private var countdownEndDate: Date?

    private var caffeineAssertionID: IOPMAssertionID = 0
    private var caffeineEndDate: Date?

    private var cleanEndDate: Date?
    nonisolated(unsafe) private var cleanEventTap: CFMachPort?
    nonisolated(unsafe) private var cleanRunLoopSource: CFRunLoopSource?

    private var customLauncherPaths: [String] = []

    init(systemMonitor: SystemMonitorService) {
        self.systemMonitor = systemMonitor

        let savedQR = UserDefaults.standard.string(forKey: Keys.qrText)
        self.qrText = (savedQR?.isEmpty == false) ? savedQR! : "https://github.com/leonardogtcruz1/ilha-dinamica"

        let savedVol = UserDefaults.standard.object(forKey: Keys.ambientVolume) as? Double ?? 0.45
        self.ambientVolume = Float(max(0.05, min(1.0, savedVol)))

        self.customLauncherPaths = UserDefaults.standard.stringArray(forKey: Keys.customLauncherPaths) ?? []

        seedDefaultColors()
        regenerateQRCode()
        reloadLauncherItems()
        refreshNetworkInfo()
        observeSystemMonitor()
        startSharedTicker()
    }

    deinit {
        tickTimer?.invalidate()
        ambientSynth.stop()
        if caffeineAssertionID != 0 {
            IOPMAssertionRelease(caffeineAssertionID)
            caffeineAssertionID = 0
        }
        if let src = cleanRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        if let tap = cleanEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
    }

    // MARK: - Calculator Methods

    func appendCalcToken(_ token: String) {
        calcExpression.append(token)
    }

    func backspaceCalc() {
        guard !calcExpression.isEmpty else { return }
        calcExpression.removeLast()
    }

    func clearCalc() {
        calcExpression = ""
        calcResult = "0"
        calcError = false
    }

    func commitCalcEvaluation() {
        guard let value = MathExpressionEvaluator.evaluate(calcExpression) else {
            if !calcExpression.trimmingCharacters(in: .whitespaces).isEmpty {
                calcError = true
            }
            return
        }
        let formatted = MathExpressionEvaluator.format(value)
        calcResult = formatted
        calcError = false
        let entry = CalcHistoryItem(expression: calcExpression, result: formatted)
        calcHistory.insert(entry, at: 0)
        if calcHistory.count > 8 {
            calcHistory = Array(calcHistory.prefix(8))
        }
        calcExpression = formatted
    }

    func applyQuickConversion(_ kind: String) {
        let sourceValue = MathExpressionEvaluator.evaluate(calcExpression)
            ?? MathExpressionEvaluator.evaluate(calcResult)
            ?? 0
        let (label, converted): (String, Double)
        switch kind {
        case "plus10":
            (label, converted) = ("\(MathExpressionEvaluator.format(sourceValue)) +10%", sourceValue * 1.10)
        case "minus15":
            (label, converted) = ("\(MathExpressionEvaluator.format(sourceValue)) -15%", sourceValue * 0.85)
        case "c2f":
            (label, converted) = ("\(MathExpressionEvaluator.format(sourceValue))°C→°F", sourceValue * 9.0 / 5.0 + 32.0)
        case "km2mi":
            (label, converted) = ("\(MathExpressionEvaluator.format(sourceValue))km→mi", sourceValue * 0.621371)
        case "kg2lb":
            (label, converted) = ("\(MathExpressionEvaluator.format(sourceValue))kg→lb", sourceValue * 2.20462)
        case "div12":
            (label, converted) = ("\(MathExpressionEvaluator.format(sourceValue)) ÷ 12", sourceValue / 12.0)
        default:
            return
        }
        let formatted = MathExpressionEvaluator.format(converted)
        calcExpression = formatted
        calcResult = formatted
        calcHistory.insert(CalcHistoryItem(expression: label, result: formatted), at: 0)
        if calcHistory.count > 8 {
            calcHistory = Array(calcHistory.prefix(8))
        }
    }

    func copyCalcResult() {
        copyString(calcResult)
        calcCopiedNotice = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            self?.calcCopiedNotice = false
        }
    }

    private func evaluateCalcLive() {
        let trimmed = calcExpression.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            calcResult = "0"
            calcError = false
            return
        }
        if let value = MathExpressionEvaluator.evaluate(trimmed) {
            calcResult = MathExpressionEvaluator.format(value)
            calcError = false
        }
    }

    // MARK: - Color Picker Methods

    func pickColorFromScreen() {
        isSamplingColor = true
        NSColorSampler().show { [weak self] selected in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSamplingColor = false
                guard let selected,
                      let rgbColor = selected.usingColorSpace(.sRGB) else {
                    return
                }
                let r = Double(max(0, min(1, rgbColor.redComponent)))
                let g = Double(max(0, min(1, rgbColor.greenComponent)))
                let b = Double(max(0, min(1, rgbColor.blueComponent)))
                let ri = Int((r * 255.0).rounded())
                let gi = Int((g * 255.0).rounded())
                let bi = Int((b * 255.0).rounded())
                let hex = String(format: "#%02X%02X%02X", ri, gi, bi)
                let rgb = "rgb(\(ri), \(gi), \(bi))"
                let swiftUI = String(format: "Color(red: %.2f, green: %.2f, blue: %.2f)", r, g, b)

                let item = PickedColorItem(
                    hex: hex,
                    rgb: rgb,
                    swiftUICode: swiftUI,
                    red: r,
                    green: g,
                    blue: b
                )
                self.pickedColors.removeAll { $0.hex == hex }
                self.pickedColors.insert(item, at: 0)
                if self.pickedColors.count > 10 {
                    self.pickedColors = Array(self.pickedColors.prefix(10))
                }
                self.copyColorString(hex, label: hex)
            }
        }
    }

    func copyColorString(_ value: String, label: String) {
        copyString(value)
        copiedColorLabel = label
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            if self?.copiedColorLabel == label {
                self?.copiedColorLabel = nil
            }
        }
    }

    private func seedDefaultColors() {
        pickedColors = [
            PickedColorItem(
                hex: "#0A84FF",
                rgb: "rgb(10, 132, 255)",
                swiftUICode: "Color(red: 0.04, green: 0.52, blue: 1.00)",
                red: 0.04, green: 0.52, blue: 1.0
            ),
            PickedColorItem(
                hex: "#30D158",
                rgb: "rgb(48, 209, 88)",
                swiftUICode: "Color(red: 0.19, green: 0.82, blue: 0.35)",
                red: 0.19, green: 0.82, blue: 0.35
            ),
            PickedColorItem(
                hex: "#FF9F0A",
                rgb: "rgb(255, 159, 10)",
                swiftUICode: "Color(red: 1.00, green: 0.62, blue: 0.04)",
                red: 1.0, green: 0.62, blue: 0.04
            )
        ]
    }

    // MARK: - Stopwatch & Countdown Methods

    var formattedStopwatch: String {
        let totalCentiseconds = Int((stopwatchElapsed * 100).rounded(.down))
        let mins = (totalCentiseconds / 6000) % 60
        let secs = (totalCentiseconds / 100) % 60
        let cs = totalCentiseconds % 100
        let hours = totalCentiseconds / 360_000
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        }
        return String(format: "%02d:%02d.%02d", mins, secs, cs)
    }

    var formattedCountdown: String {
        let mins = countdownRemainingSeconds / 60
        let secs = countdownRemainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    func toggleStopwatch() {
        if isStopwatchRunning {
            if let start = stopwatchStartDate {
                stopwatchAccumulated += Date().timeIntervalSince(start)
                stopwatchElapsed = stopwatchAccumulated
            }
            stopwatchStartDate = nil
            isStopwatchRunning = false
        } else {
            stopwatchStartDate = Date()
            isStopwatchRunning = true
        }
    }

    func recordLap() {
        guard stopwatchElapsed > 0.05 else { return }
        stopwatchLaps.insert(stopwatchElapsed, at: 0)
        if stopwatchLaps.count > 12 {
            stopwatchLaps = Array(stopwatchLaps.prefix(12))
        }
    }

    func resetStopwatch() {
        isStopwatchRunning = false
        stopwatchStartDate = nil
        stopwatchAccumulated = 0
        stopwatchElapsed = 0
        stopwatchLaps.removeAll()
    }

    func selectCountdownPreset(minutes: Int) {
        let total = max(10, minutes * 60)
        countdownDurationSeconds = total
        countdownRemainingSeconds = total
        countdownEndDate = Date().addingTimeInterval(TimeInterval(total))
        isCountdownRunning = true
    }

    func toggleCountdown() {
        if isCountdownRunning {
            if let end = countdownEndDate {
                countdownRemainingSeconds = max(0, Int(ceil(end.timeIntervalSinceNow)))
            }
            countdownEndDate = nil
            isCountdownRunning = false
        } else {
            if countdownRemainingSeconds <= 0 {
                countdownRemainingSeconds = countdownDurationSeconds
            }
            countdownEndDate = Date().addingTimeInterval(TimeInterval(countdownRemainingSeconds))
            isCountdownRunning = true
        }
    }

    func resetCountdown() {
        isCountdownRunning = false
        countdownEndDate = nil
        countdownRemainingSeconds = countdownDurationSeconds
    }

    // MARK: - QR Code Methods

    func loadQRFromClipboard() {
        if let str = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !str.isEmpty {
            qrText = str
            setQRFeedback("Texto do Clipboard carregado")
        } else {
            setQRFeedback("Clipboard vazio")
        }
    }

    func copyQRImageToClipboard() {
        guard let qrImage, let tiff = qrImage.tiffRepresentation else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(tiff, forType: .tiff)
        if let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            pb.setData(png, forType: .png)
        }
        setQRFeedback("QR copiado!")
    }

    func saveQRImageToDownloads() {
        guard let qrImage,
              let tiff = qrImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]),
              let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let filename = "QRCode-\(formatter.string(from: Date())).png"
        let url = downloads.appendingPathComponent(filename)
        do {
            try png.write(to: url)
            setQRFeedback("Salvo em Downloads")
        } catch {
            setQRFeedback("Erro ao salvar")
        }
    }

    private func setQRFeedback(_ text: String) {
        qrActionFeedback = text
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if self?.qrActionFeedback == text {
                self?.qrActionFeedback = nil
            }
        }
    }

    private func regenerateQRCode() {
        let trimmed = qrText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            qrImage = nil
            return
        }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else {
            qrImage = nil
            return
        }

        let extent = output.extent.integral
        let targetSide: CGFloat = 240
        let scale = max(1, floor(targetSide / max(1, extent.width)))
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let ciContext = CIContext()
        guard let cgImg = ciContext.createCGImage(scaled, from: scaled.extent) else {
            qrImage = nil
            return
        }
        let image = NSImage(cgImage: cgImg, size: NSSize(width: targetSide, height: targetSide))
        qrImage = image
    }

    // MARK: - Launcher Methods

    func reloadLauncherItems() {
        var items: [LauncherItem] = []
        var seen = Set<String>()

        func appendIfExists(path: String, name: String? = nil, isFolder: Bool = false, isCustom: Bool = false) {
            guard !seen.contains(path), FileManager.default.fileExists(atPath: path) else { return }
            seen.insert(path)
            let displayName = name ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            items.append(LauncherItem(id: path, name: displayName, path: path, isFolder: isFolder, isCustom: isCustom))
        }

        for custom in customLauncherPaths {
            let isDir = (try? URL(fileURLWithPath: custom).resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let isApp = custom.hasSuffix(".app")
            appendIfExists(path: custom, isFolder: isDir && !isApp, isCustom: true)
        }

        let candidateApps = [
            "/Applications/Safari.app",
            "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app",
            "/Applications/Google Chrome.app",
            "/Applications/Spotify.app",
            "/System/Applications/Music.app",
            "/Applications/WhatsApp.app",
            "/Applications/Telegram.app",
            "/System/Applications/Messages.app",
            "/System/Applications/Notes.app",
            "/System/Applications/Calendar.app",
            "/System/Applications/Utilities/Terminal.app",
            "/System/Applications/System Settings.app",
            "/System/Applications/Shortcuts.app",
            "/Applications/Xcode.app"
        ]
        for appPath in candidateApps {
            appendIfExists(path: appPath, isFolder: false, isCustom: false)
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        appendIfExists(path: home.appendingPathComponent("Downloads").path, name: "Downloads", isFolder: true)
        appendIfExists(path: home.appendingPathComponent("Desktop").path, name: "Mesa", isFolder: true)
        appendIfExists(path: home.appendingPathComponent("Documents").path, name: "Documentos", isFolder: true)

        launcherItems = items
    }

    func openLauncherItem(_ item: LauncherItem) {
        let url = URL(fileURLWithPath: item.path)
        NSWorkspace.shared.open(url)
        lastLaunchedName = item.name
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if self?.lastLaunchedName == item.name {
                self?.lastLaunchedName = nil
            }
        }
    }

    func icon(for item: LauncherItem) -> NSImage {
        NSWorkspace.shared.icon(forFile: item.path)
    }

    func promptAddCustomApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Adicionar App ou Pasta ao Launcher"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let path = url.path
                if !self.customLauncherPaths.contains(path) {
                    self.customLauncherPaths.insert(path, at: 0)
                    UserDefaults.standard.set(self.customLauncherPaths, forKey: Keys.customLauncherPaths)
                    self.reloadLauncherItems()
                }
            }
        }
    }

    func removeCustomLauncherItem(_ item: LauncherItem) {
        guard item.isCustom else { return }
        customLauncherPaths.removeAll { $0 == item.path }
        UserDefaults.standard.set(customLauncherPaths, forKey: Keys.customLauncherPaths)
        reloadLauncherItems()
    }

    // MARK: - Network Methods

    func refreshNetworkInfo() {
        let (iface, ip) = Self.detectPrimaryIPv4()
        interfaceName = iface
        localIP = ip
    }

    func fetchPublicIP() {
        guard !isFetchingPublicIP else { return }
        isFetchingPublicIP = true
        Task {
            let fetched = await Self.requestPublicIP()
            self.publicIP = fetched ?? "Indisponível"
            self.isFetchingPublicIP = false
        }
    }

    func measurePing() {
        guard !isPinging else { return }
        isPinging = true
        Task {
            let ms = await Self.runPingCheck()
            self.pingMs = ms
            self.isPinging = false
        }
    }

    func copyNetworkString(_ value: String, label: String) {
        copyString(value)
        copiedIPNotice = label
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if self?.copiedIPNotice == label {
                self?.copiedIPNotice = nil
            }
        }
    }

    private static func detectPrimaryIPv4() -> (String, String) {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else {
            return ("Sem rede", "Indisponível")
        }
        defer { freeifaddrs(first) }

        var fallback: (String, String)?
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            let addr = current.pointee
            let flags = Int32(addr.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            if isUp, !isLoopback,
               let sa = addr.ifa_addr,
               sa.pointee.sa_family == UInt8(AF_INET),
               let namePtr = addr.ifa_name {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let res = getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                if res == 0 {
                    let ip = String(cString: host)
                    let name = String(cString: namePtr)
                    if name == "en0" {
                        return ("Wi-Fi (en0)", ip)
                    }
                    if name.hasPrefix("en") && fallback == nil {
                        fallback = ("Rede (\(name))", ip)
                    }
                }
            }
            cursor = addr.ifa_next
        }
        return fallback ?? ("Sem rede", "Offline")
    }

    private static func requestPublicIP() async -> String? {
        guard let url = URL(string: "https://api.ipify.org") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !ip.isEmpty else {
            return nil
        }
        return ip
    }

    private static func runPingCheck() async -> Int? {
        await Task.detached(priority: .utility) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/sbin/ping")
            proc.arguments = ["-c", "1", "-W", "1500", "1.1.1.1"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = Pipe()
            do {
                try proc.run()
            } catch {
                return nil
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            guard proc.terminationStatus == 0,
                  let text = String(data: data, encoding: .utf8),
                  let range = text.range(of: "time=") else {
                return nil
            }
            let tail = text[range.upperBound...]
            let numStr = tail.prefix { $0.isNumber || $0 == "." }
            if let ms = Double(numStr) {
                return max(1, Int(ms.rounded()))
            }
            return nil
        }.value
    }

    // MARK: - Caffeine Methods

    var formattedCaffeineRemaining: String {
        guard isCaffeineActive else { return "Inativo" }
        guard let rem = caffeineRemainingSeconds else { return "Sem limite" }
        let hrs = rem / 3600
        let mins = (rem % 3600) / 60
        let secs = rem % 60
        if hrs > 0 {
            return String(format: "%dh %02dm", hrs, mins)
        }
        return String(format: "%02d:%02d", mins, secs)
    }

    func toggleCaffeine() {
        if isCaffeineActive {
            disableCaffeine()
        } else {
            enableCaffeine(minutes: caffeinePresetMinutes)
        }
    }

    func enableCaffeine(minutes: Int) {
        caffeinePresetMinutes = minutes
        if caffeineAssertionID == 0 {
            var newID: IOPMAssertionID = 0
            let status = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Ilha Dinâmica — Modo Cafeína" as CFString,
                &newID
            )
            guard status == kIOReturnSuccess else {
                isCaffeineActive = false
                return
            }
            caffeineAssertionID = newID
        }

        isCaffeineActive = true
        if minutes > 0 {
            let total = minutes * 60
            caffeineEndDate = Date().addingTimeInterval(TimeInterval(total))
            caffeineRemainingSeconds = total
        } else {
            caffeineEndDate = nil
            caffeineRemainingSeconds = nil
        }
    }

    func disableCaffeine() {
        if caffeineAssertionID != 0 {
            IOPMAssertionRelease(caffeineAssertionID)
            caffeineAssertionID = 0
        }
        isCaffeineActive = false
        caffeineEndDate = nil
        caffeineRemainingSeconds = nil
    }

    // MARK: - Screen Clean Methods

    func startScreenClean(seconds: Int = 30) {
        stopScreenClean()

        let trusted = AXIsProcessTrusted()
        cleaningNeedsAccessibility = !trusted

        if trusted {
            let mask: CGEventMask =
                (1 << CGEventType.keyDown.rawValue)
                | (1 << CGEventType.keyUp.rawValue)
                | (1 << CGEventType.flagsChanged.rawValue)
                | (1 << 14)

            if let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: screenCleanKeyTapCallback,
                userInfo: nil
            ), let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) {
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
                cleanEventTap = tap
                cleanRunLoopSource = source
            } else {
                cleaningNeedsAccessibility = true
            }
        }

        cleaningRemainingSeconds = seconds
        cleanEndDate = Date().addingTimeInterval(TimeInterval(seconds))
        isCleaningScreen = true
    }

    func stopScreenClean() {
        if let source = cleanRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            cleanRunLoopSource = nil
        }
        if let tap = cleanEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            cleanEventTap = nil
        }
        cleanEndDate = nil
        isCleaningScreen = false
        cleaningRemainingSeconds = 30
    }

    func requestAccessibilityForClean() {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: kCFBooleanTrue!] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Ambient Sound Methods

    func toggleAmbientPreset(_ preset: AmbientPreset) {
        if activeAmbientPreset == preset {
            activeAmbientPreset = nil
            ambientSynth.configure(preset: nil, volume: ambientVolume)
        } else {
            activeAmbientPreset = preset
            ambientSynth.configure(preset: preset, volume: ambientVolume)
        }
    }

    func stopAmbientSound() {
        activeAmbientPreset = nil
        ambientSynth.stop()
    }

    // MARK: - World Clock Helpers

    func formattedTime(for city: WorldCityItem) -> String {
        guard let tz = TimeZone(identifier: city.timeZoneIdentifier) else { return "--:--" }
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = "HH:mm"
        return f.string(from: now)
    }

    func relativeOffsetLabel(for city: WorldCityItem) -> String {
        guard let tz = TimeZone(identifier: city.timeZoneIdentifier) else { return "" }
        let localOffset = TimeZone.current.secondsFromGMT(for: now)
        let cityOffset = tz.secondsFromGMT(for: now)
        let diffHours = Double(cityOffset - localOffset) / 3600.0
        if abs(diffHours) < 0.01 {
            return "Seu fuso"
        }
        let sign = diffHours > 0 ? "+" : ""
        if abs(diffHours.rounded() - diffHours) < 0.01 {
            return "\(sign)\(Int(diffHours.rounded()))h"
        }
        return String(format: "%@%.1fh", sign, diffHours)
    }

    func dayLabel(for city: WorldCityItem) -> String {
        guard let tz = TimeZone(identifier: city.timeZoneIdentifier) else { return "" }
        var localCal = Calendar.current
        localCal.timeZone = TimeZone.current
        var cityCal = Calendar.current
        cityCal.timeZone = tz

        let localDay = localCal.startOfDay(for: now)
        let cityDayString: String = {
            let f = DateFormatter()
            f.timeZone = tz
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: now)
        }()
        let localDayString: String = {
            let f = DateFormatter()
            f.timeZone = TimeZone.current
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: now)
        }()
        if cityDayString == localDayString { return "Hoje" }
        return cityDayString > localDayString || cityCal.date(byAdding: .day, value: -1, to: now) == localDay ? "Amanhã" : "Ontem"
    }

    // MARK: - Shared Helpers

    func copyString(_ value: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(value, forType: .string)
    }

    private func observeSystemMonitor() {
        systemMonitor.$downloadBytesPerSec
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bytes in
                guard let self else { return }
                var arr = self.downloadHistory
                arr.append(bytes)
                if arr.count > 22 {
                    arr.removeFirst(arr.count - 22)
                }
                self.downloadHistory = arr
            }
            .store(in: &cancellables)
    }

    private func startSharedTicker() {
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleTick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private var lastSlowTickSecond: Int = -1

    private func handleTick() {
        let currentDate = Date()

        if isStopwatchRunning, let start = stopwatchStartDate {
            stopwatchElapsed = stopwatchAccumulated + currentDate.timeIntervalSince(start)
        }

        if isCountdownRunning, let end = countdownEndDate {
            let rem = Int(ceil(end.timeIntervalSince(currentDate)))
            if rem <= 0 {
                countdownRemainingSeconds = 0
                isCountdownRunning = false
                countdownEndDate = nil
                NSSound(named: NSSound.Name("Glass"))?.play()
            } else if rem != countdownRemainingSeconds {
                countdownRemainingSeconds = rem
            }
        }

        let currentSecond = Int(currentDate.timeIntervalSince1970)
        if currentSecond != lastSlowTickSecond {
            lastSlowTickSecond = currentSecond
            now = currentDate

            if isCaffeineActive, let end = caffeineEndDate {
                let rem = Int(ceil(end.timeIntervalSince(currentDate)))
                if rem <= 0 {
                    disableCaffeine()
                } else {
                    caffeineRemainingSeconds = rem
                }
            }

            if isCleaningScreen, let end = cleanEndDate {
                let rem = Int(ceil(end.timeIntervalSince(currentDate)))
                if rem <= 0 {
                    stopScreenClean()
                } else {
                    cleaningRemainingSeconds = rem
                }
            }
        }
    }
}

private func screenCleanKeyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        return Unmanaged.passUnretained(event)
    }
    return nil
}
