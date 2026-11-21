import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let enableMusicModule = "settings.enableMusicModule"
        static let enablePomodoroModule = "settings.enablePomodoroModule"
        static let enableBatteryModule = "settings.enableBatteryModule"
        static let enableShelfModule = "settings.enableShelfModule"
        static let enableClipboardModule = "settings.enableClipboardModule"
        static let enableCalendarModule = "settings.enableCalendarModule"
        static let enableNotesModule = "settings.enableNotesModule"
        static let enableAudioModule = "settings.enableAudioModule"
        static let enableSystemModule = "settings.enableSystemModule"

        static let showTrackChangeToast = "settings.showTrackChangeToast"
        static let showBatteryToasts = "settings.showBatteryToasts"
        static let showHudToasts = "settings.showHudToasts"
        static let replaceSystemHUD = "settings.replaceSystemHUD"
        static let showBluetoothToasts = "settings.showBluetoothToasts"
        static let showMeetingToasts = "settings.showMeetingToasts"
        static let showWeatherInHeader = "settings.showWeatherInHeader"
        static let weatherCity = "settings.weatherCity"

        static let openOnHover = "settings.openOnHover"
        static let hoverDelayMs = "settings.hoverDelayMs"
        static let animationSpeed = "settings.animationSpeed"
        static let focusMinutes = "settings.focusMinutes"
        static let shortBreakMinutes = "settings.shortBreakMinutes"
        static let longBreakMinutes = "settings.longBreakMinutes"
        static let pomodoroAutoStart = "settings.pomodoroAutoStart"
        static let pomodoroSound = "settings.pomodoroSound"
        static let launchAtLogin = "settings.launchAtLogin"
        static let recordSystemAudio = "settings.recordSystemAudio"
        static let recordIncludeMic = "settings.recordIncludeMicV2"
        static let recordShowClicks = "settings.recordShowClicks"
        static let recordAddToShelf = "settings.recordAddToShelf"
    }

    static let availableSounds: [String] = [
        "Glass",
        "Ping",
        "Pop",
        "Purr",
        "Submarine",
        "Hero",
        "Nenhum"
    ]

    private let defaults: UserDefaults
    private var isBootstrapping = true

    @Published var enableMusicModule: Bool {
        didSet { save(enableMusicModule, forKey: Keys.enableMusicModule) }
    }

    @Published var enablePomodoroModule: Bool {
        didSet { save(enablePomodoroModule, forKey: Keys.enablePomodoroModule) }
    }

    @Published var enableBatteryModule: Bool {
        didSet { save(enableBatteryModule, forKey: Keys.enableBatteryModule) }
    }

    @Published var enableShelfModule: Bool {
        didSet { save(enableShelfModule, forKey: Keys.enableShelfModule) }
    }

    @Published var enableClipboardModule: Bool {
        didSet { save(enableClipboardModule, forKey: Keys.enableClipboardModule) }
    }

    @Published var enableCalendarModule: Bool {
        didSet { save(enableCalendarModule, forKey: Keys.enableCalendarModule) }
    }

    @Published var enableNotesModule: Bool {
        didSet { save(enableNotesModule, forKey: Keys.enableNotesModule) }
    }

    @Published var enableAudioModule: Bool {
        didSet { save(enableAudioModule, forKey: Keys.enableAudioModule) }
    }

    @Published var enableSystemModule: Bool {
        didSet { save(enableSystemModule, forKey: Keys.enableSystemModule) }
    }

    @Published var showTrackChangeToast: Bool {
        didSet { save(showTrackChangeToast, forKey: Keys.showTrackChangeToast) }
    }

    @Published var showBatteryToasts: Bool {
        didSet { save(showBatteryToasts, forKey: Keys.showBatteryToasts) }
    }

    @Published var showHudToasts: Bool {
        didSet { save(showHudToasts, forKey: Keys.showHudToasts) }
    }

    @Published var replaceSystemHUD: Bool {
        didSet { save(replaceSystemHUD, forKey: Keys.replaceSystemHUD) }
    }

    @Published var showBluetoothToasts: Bool {
        didSet { save(showBluetoothToasts, forKey: Keys.showBluetoothToasts) }
    }

    @Published var showMeetingToasts: Bool {
        didSet { save(showMeetingToasts, forKey: Keys.showMeetingToasts) }
    }

    @Published var showWeatherInHeader: Bool {
        didSet { save(showWeatherInHeader, forKey: Keys.showWeatherInHeader) }
    }

    @Published var weatherCity: String {
        didSet { save(weatherCity, forKey: Keys.weatherCity) }
    }

    @Published var openOnHover: Bool {
        didSet { save(openOnHover, forKey: Keys.openOnHover) }
    }

    @Published var hoverDelayMs: Double {
        didSet {
            let clamped = max(0, min(1000, hoverDelayMs))
            if clamped != hoverDelayMs {
                hoverDelayMs = clamped
                return
            }
            save(hoverDelayMs, forKey: Keys.hoverDelayMs)
        }
    }

    @Published var animationSpeed: Double {
        didSet {
            let clamped = max(0.5, min(2.5, animationSpeed))
            if clamped != animationSpeed {
                animationSpeed = clamped
                return
            }
            save(animationSpeed, forKey: Keys.animationSpeed)
        }
    }

    @Published var focusMinutes: Int {
        didSet {
            let clamped = max(1, min(120, focusMinutes))
            if clamped != focusMinutes {
                focusMinutes = clamped
                return
            }
            save(focusMinutes, forKey: Keys.focusMinutes)
        }
    }

    @Published var shortBreakMinutes: Int {
        didSet {
            let clamped = max(1, min(60, shortBreakMinutes))
            if clamped != shortBreakMinutes {
                shortBreakMinutes = clamped
                return
            }
            save(shortBreakMinutes, forKey: Keys.shortBreakMinutes)
        }
    }

    @Published var longBreakMinutes: Int {
        didSet {
            let clamped = max(1, min(90, longBreakMinutes))
            if clamped != longBreakMinutes {
                longBreakMinutes = clamped
                return
            }
            save(longBreakMinutes, forKey: Keys.longBreakMinutes)
        }
    }

    @Published var pomodoroAutoStart: Bool {
        didSet { save(pomodoroAutoStart, forKey: Keys.pomodoroAutoStart) }
    }

    @Published var pomodoroSound: String {
        didSet { save(pomodoroSound, forKey: Keys.pomodoroSound) }
    }

    @Published var recordSystemAudio: Bool {
        didSet { save(recordSystemAudio, forKey: Keys.recordSystemAudio) }
    }

    @Published var recordIncludeMic: Bool {
        didSet { save(recordIncludeMic, forKey: Keys.recordIncludeMic) }
    }

    @Published var recordShowClicks: Bool {
        didSet { save(recordShowClicks, forKey: Keys.recordShowClicks) }
    }

    @Published var recordAddToShelf: Bool {
        didSet { save(recordAddToShelf, forKey: Keys.recordAddToShelf) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            save(launchAtLogin, forKey: Keys.launchAtLogin)
            guard !isBootstrapping else { return }
            applyLaunchAtLogin(launchAtLogin)
        }
    }

    @Published private(set) var launchAtLoginNotice: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.enableMusicModule = defaults.object(forKey: Keys.enableMusicModule) as? Bool ?? true
        self.enablePomodoroModule = defaults.object(forKey: Keys.enablePomodoroModule) as? Bool ?? true
        self.enableBatteryModule = defaults.object(forKey: Keys.enableBatteryModule) as? Bool ?? true
        self.enableShelfModule = defaults.object(forKey: Keys.enableShelfModule) as? Bool ?? true
        self.enableClipboardModule = defaults.object(forKey: Keys.enableClipboardModule) as? Bool ?? true
        self.enableCalendarModule = defaults.object(forKey: Keys.enableCalendarModule) as? Bool ?? true
        self.enableNotesModule = defaults.object(forKey: Keys.enableNotesModule) as? Bool ?? true
        self.enableAudioModule = defaults.object(forKey: Keys.enableAudioModule) as? Bool ?? true
        self.enableSystemModule = defaults.object(forKey: Keys.enableSystemModule) as? Bool ?? true

        self.showTrackChangeToast = defaults.object(forKey: Keys.showTrackChangeToast) as? Bool ?? true
        self.showBatteryToasts = defaults.object(forKey: Keys.showBatteryToasts) as? Bool ?? true
        self.showHudToasts = defaults.object(forKey: Keys.showHudToasts) as? Bool ?? true
        self.replaceSystemHUD = defaults.object(forKey: Keys.replaceSystemHUD) as? Bool ?? true
        self.showBluetoothToasts = defaults.object(forKey: Keys.showBluetoothToasts) as? Bool ?? true
        self.showMeetingToasts = defaults.object(forKey: Keys.showMeetingToasts) as? Bool ?? true
        self.showWeatherInHeader = defaults.object(forKey: Keys.showWeatherInHeader) as? Bool ?? true
        self.weatherCity = defaults.string(forKey: Keys.weatherCity) ?? ""

        self.openOnHover = defaults.object(forKey: Keys.openOnHover) as? Bool ?? true

        let storedHover = defaults.object(forKey: Keys.hoverDelayMs) as? Double ?? 140
        self.hoverDelayMs = max(0, min(1000, storedHover))

        let storedSpeed = defaults.object(forKey: Keys.animationSpeed) as? Double ?? 1.2
        self.animationSpeed = max(0.5, min(2.5, storedSpeed))

        let storedFocus = defaults.object(forKey: Keys.focusMinutes) as? Int ?? 25
        self.focusMinutes = max(1, min(120, storedFocus))

        let storedShort = defaults.object(forKey: Keys.shortBreakMinutes) as? Int ?? 5
        self.shortBreakMinutes = max(1, min(60, storedShort))

        let storedLong = defaults.object(forKey: Keys.longBreakMinutes) as? Int ?? 15
        self.longBreakMinutes = max(1, min(90, storedLong))

        self.pomodoroAutoStart = defaults.object(forKey: Keys.pomodoroAutoStart) as? Bool ?? false
        self.pomodoroSound = defaults.string(forKey: Keys.pomodoroSound) ?? "Glass"
        self.recordSystemAudio = defaults.object(forKey: Keys.recordSystemAudio) as? Bool ?? true
        self.recordIncludeMic = defaults.object(forKey: Keys.recordIncludeMic) as? Bool ?? false
        self.recordShowClicks = defaults.object(forKey: Keys.recordShowClicks) as? Bool ?? false
        self.recordAddToShelf = defaults.object(forKey: Keys.recordAddToShelf) as? Bool ?? true

        let savedLaunch = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        if Bundle.main.bundleURL.pathExtension == "app" {
            let status = SMAppService.mainApp.status
            if status == .enabled {
                self.launchAtLogin = true
            } else {
                self.launchAtLogin = savedLaunch
            }
        } else {
            self.launchAtLogin = savedLaunch
        }

        self.isBootstrapping = false
    }

    var effectiveHoverDelayMs: Double {
        let scaled = (hoverDelayMs * 0.65) / pow(animationSpeed, 1.6)
        return scaled < 15 ? 0 : scaled
    }

    var effectiveCollapseDelaySeconds: TimeInterval {
        max(0.015, 0.14 / pow(animationSpeed, 1.6))
    }

    var expandSpring: Animation {
        let resp = max(0.085, 0.34 / pow(animationSpeed, 1.35))
        let damp = min(0.92, 0.78 + max(0, animationSpeed - 1.0) * 0.09)
        return .spring(response: resp, dampingFraction: damp)
    }

    var collapseSpring: Animation {
        let resp = max(0.075, 0.30 / pow(animationSpeed, 1.35))
        let damp = min(0.94, 0.82 + max(0, animationSpeed - 1.0) * 0.08)
        return .spring(response: resp, dampingFraction: damp)
    }

    var toastSpring: Animation {
        let resp = max(0.085, 0.30 / pow(animationSpeed, 1.35))
        return .spring(response: resp, dampingFraction: 0.82)
    }

    var sizeSpring: Animation {
        let resp = max(0.075, 0.26 / pow(animationSpeed, 1.35))
        return .spring(response: resp, dampingFraction: 0.85)
    }

    var animationSpeedLabel: String {
        if animationSpeed < 0.8 { return "Lenta" }
        if animationSpeed < 1.25 { return "Normal" }
        if animationSpeed < 1.75 { return "Rápida" }
        return "Turbo"
    }

    var enabledTabs: [IslandTab] {
        var tabs: [IslandTab] = []
        if enableMusicModule { tabs.append(.music) }
        if enablePomodoroModule { tabs.append(.pomodoro) }
        if enableShelfModule { tabs.append(.shelf) }
        if enableClipboardModule { tabs.append(.clipboard) }
        if enableCalendarModule { tabs.append(.calendar) }
        if enableNotesModule { tabs.append(.notes) }
        if enableAudioModule { tabs.append(.audio) }
        if enableSystemModule { tabs.append(.system) }
        return tabs.isEmpty ? [.music] : tabs
    }

    private func save<T>(_ value: T, forKey key: String) {
        guard !isBootstrapping else { return }
        defaults.set(value, forKey: key)
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            launchAtLoginNotice = "Disponível apenas quando executado como IlhaDinamica.app."
            return
        }

        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            launchAtLoginNotice = nil
        } catch {
            launchAtLoginNotice = "Não foi possível alterar início automático (\(error.localizedDescription))."
        }
    }
}
