import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let settings: SettingsStore
    let music: MusicService
    let pomodoro: PomodoroService
    let battery: BatteryService
    let shelf: ShelfService
    let clipboard: ClipboardService
    let calendar: CalendarService
    let notes: NotesService
    let audio: AudioControlService
    let camera: CameraMirrorService
    let system: SystemMonitorService
    let weather: WeatherService
    let recorder: ScreenRecorderService
    let mediaKeys: MediaKeyInterceptor
    let coordinator: IslandCoordinator

    private var islandPanel: IslandPanel?
    private var settingsWindow: NSWindow?
    private var screenObserver: NSObjectProtocol?
    private var activityToken: NSObjectProtocol?

    override init() {
        let settings = SettingsStore()
        let music = MusicService()
        let pomodoro = PomodoroService(settings: settings)
        let battery = BatteryService()
        let shelf = ShelfService()
        let clipboard = ClipboardService()
        let calendar = CalendarService()
        let notes = NotesService()
        let audio = AudioControlService()
        let camera = CameraMirrorService()
        let system = SystemMonitorService()
        let weather = WeatherService(settings: settings)
        let recorder = ScreenRecorderService(settings: settings, audio: audio)
        let mediaKeys = MediaKeyInterceptor(settings: settings, audio: audio)

        let coordinator = IslandCoordinator(
            settings: settings,
            music: music,
            pomodoro: pomodoro,
            battery: battery,
            shelf: shelf,
            clipboard: clipboard,
            calendar: calendar,
            notes: notes,
            audio: audio,
            camera: camera,
            system: system,
            weather: weather,
            recorder: recorder
        )

        self.settings = settings
        self.music = music
        self.pomodoro = pomodoro
        self.battery = battery
        self.shelf = shelf
        self.clipboard = clipboard
        self.calendar = calendar
        self.notes = notes
        self.audio = audio
        self.camera = camera
        self.system = system
        self.weather = weather
        self.recorder = recorder
        self.mediaKeys = mediaKeys
        self.coordinator = coordinator

        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
            reason: "Manter resposta instantânea da Ilha Dinâmica ao passar o mouse"
        )

        wireCallbacks()
        mediaKeys.start()
        setupIslandPanel()
        observeScreenChanges()
        presentInitialPeek()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
        mediaKeys.disable()
        if recorder.isRecording {
            recorder.stopRecording()
        }
        camera.stop()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        OverlaySpaceManager.shared.cleanup()
    }

    func openSettingsWindow() {
        if settingsWindow == nil {
            let view = SettingsView(
                settings: settings,
                coordinator: coordinator,
                battery: battery,
                audio: audio,
                weather: weather,
                mediaKeys: mediaKeys
            )
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Preferências — Ilha Dinâmica"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func wireCallbacks() {
        coordinator.onOpenSettings = { [weak self] in
            self?.openSettingsWindow()
        }

        battery.onBatteryEvent = { [weak self] event in
            guard let self, self.settings.enableBatteryModule, self.settings.showBatteryToasts else {
                return
            }
            self.coordinator.showToast(event, duration: 3.4)
        }

        music.onTrackChanged = { [weak self] title, artist, accent in
            guard let self, self.settings.enableMusicModule, self.settings.showTrackChangeToast else {
                return
            }
            self.coordinator.showToast(
                ToastEvent(kind: .trackChanged(title: title, artist: artist, accent: accent)),
                duration: 2.8
            )
        }

        pomodoro.onPhaseCompleted = { [weak self] completed, next in
            guard let self, self.settings.enablePomodoroModule else { return }
            self.coordinator.showToast(
                ToastEvent(kind: .pomodoroFinished(completed: completed, next: next)),
                duration: 4.5
            )
        }

        shelf.onFilesAdded = { [weak self] count in
            guard let self, self.settings.enableShelfModule else { return }
            self.coordinator.showToast(
                ToastEvent(kind: .shelfAdded(count: count)),
                duration: 2.4
            )
        }

        calendar.onMeetingSoon = { [weak self] title, minutesUntil in
            guard let self, self.settings.enableCalendarModule, self.settings.showMeetingToasts else {
                return
            }
            self.coordinator.showToast(
                ToastEvent(kind: .meetingSoon(title: title, minutesUntil: minutesUntil)),
                duration: 4.5
            )
        }

        audio.onVolumeChanged = { [weak self] level, isMuted in
            guard let self, self.settings.showHudToasts else { return }
            self.coordinator.showToast(
                ToastEvent(kind: .volume(level: level, isMuted: isMuted)),
                duration: 1.5
            )
        }

        audio.onBrightnessChanged = { [weak self] level in
            guard let self, self.settings.showHudToasts else { return }
            self.coordinator.showToast(
                ToastEvent(kind: .brightness(level: level)),
                duration: 1.5
            )
        }

        audio.onMicMuteChanged = { [weak self] isMuted in
            guard let self else { return }
            self.coordinator.showToast(
                ToastEvent(kind: .micMuted(isMuted: isMuted)),
                duration: 1.8
            )
        }

        audio.onBluetoothConnected = { [weak self] device in
            guard let self, self.settings.showBluetoothToasts else { return }
            self.coordinator.showToast(
                ToastEvent(kind: .bluetoothConnected(
                    name: device.name,
                    batteryText: device.batterySummary,
                    isAudio: device.isAudio
                )),
                duration: 3.6
            )
        }

        recorder.onRecordingSaved = { [weak self] url in
            guard let self else { return }
            if self.settings.recordAddToShelf && self.settings.enableShelfModule {
                self.shelf.addFiles([url], emitCallback: false)
                self.coordinator.presentShelfPreviewBriefly()
            } else {
                self.coordinator.showToast(
                    ToastEvent(kind: .recordingSaved(filename: url.lastPathComponent)),
                    duration: 3.4
                )
            }
        }

        recorder.onRecordingError = { [weak self] message in
            guard let self else { return }
            if self.coordinator.mode == .expanded {
                self.coordinator.collapse()
            }
            self.coordinator.showToast(
                ToastEvent(kind: .recordingError(message: message)),
                duration: 4.0
            )
        }
    }

    private func setupIslandPanel() {
        let rootView = IslandRootView(
            coordinator: coordinator,
            settings: settings,
            music: music,
            pomodoro: pomodoro,
            battery: battery,
            shelf: shelf,
            clipboard: clipboard,
            calendar: calendar,
            notes: notes,
            audio: audio,
            camera: camera,
            system: system,
            weather: weather,
            recorder: recorder
        )
        let panel = IslandPanel(rootView: rootView, geometry: coordinator.geometry)
        panel.onDragEntered = { [weak self] in
            guard let self, self.settings.enableShelfModule else { return }
            self.shelf.isDropTargeted = true
            if self.coordinator.mode != .expanded || self.coordinator.activeTab != .shelf {
                self.coordinator.expand(tab: .shelf)
            }
        }
        panel.onDragExited = { [weak self] in
            self?.shelf.isDropTargeted = false
        }
        panel.onPerformDrop = { [weak self] info in
            guard let self, self.settings.enableShelfModule else { return false }
            let handled = self.shelf.handleDraggingInfo(info)
            if handled {
                self.coordinator.expand(tab: .shelf)
            }
            return handled
        }
        coordinator.panel = panel
        islandPanel = panel
        panel.orderFrontRegardless()
        OverlaySpaceManager.shared.attach(window: panel)
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.coordinator.updateGeometry()
            }
        }
    }

    private func presentInitialPeek() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self else { return }
            self.coordinator.presentBriefPeek(tab: self.settings.enabledTabs.first, duration: 2.2)
        }
    }
}
