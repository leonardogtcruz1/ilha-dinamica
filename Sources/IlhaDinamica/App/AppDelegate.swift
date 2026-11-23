import AppKit
import Carbon
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
    let extraWidgets: ExtraWidgetsService
    let mediaKeys: MediaKeyInterceptor
    let coordinator: IslandCoordinator

    private var islandPanel: IslandPanel?
    private var settingsWindow: NSWindow?
    private var screenObserver: NSObjectProtocol?
    private var activityToken: NSObjectProtocol?
    private var globalHideHotKey: GlobalHideHotKey?

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
        let extraWidgets = ExtraWidgetsService(systemMonitor: system)
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
            recorder: recorder,
            extraWidgets: extraWidgets
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
        self.extraWidgets = extraWidgets
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
        globalHideHotKey = GlobalHideHotKey { [weak self] in
            Task { @MainActor [weak self] in
                self?.coordinator.toggleTemporaryHide()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
        globalHideHotKey?.unregister()
        globalHideHotKey = nil
        mediaKeys.disable()
        extraWidgets.stopScreenClean()
        extraWidgets.disableCaffeine()
        extraWidgets.stopAmbientSound()
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
            let duration: TimeInterval
            if case .charging = event.kind {
                duration = 5.2
            } else {
                duration = 3.4
            }
            self.coordinator.showToast(event, duration: duration)
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
                ToastEvent(kind: .volume(
                    level: level,
                    isMuted: isMuted,
                    deviceName: self.audio.defaultOutputName,
                    deviceIcon: self.audio.defaultOutputIconName
                )),
                duration: 1.6
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
                    isAudio: device.isAudio,
                    batteryLeft: device.batteryLeft,
                    batteryRight: device.batteryRight,
                    batteryCase: device.batteryCase,
                    batteryMain: device.batteryMain,
                    iconName: self.audio.iconForBluetoothDevice(device)
                )),
                duration: 4.2
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
            recorder: recorder,
            extraWidgets: extraWidgets
        )
        let panel = IslandPanel(rootView: rootView, geometry: coordinator.geometry)
        panel.isPointInsideIsland = { [weak self] point in
            self?.coordinator.isPointInsideIsland(point) ?? false
        }
        panel.onDragEntered = { [weak self] in
            guard let self, self.settings.enableShelfModule, self.coordinator.isPointInsideIsland() else { return }
            self.coordinator.ensureDragSafeLayer()
            if !self.shelf.isDropTargeted {
                self.shelf.isDropTargeted = true
            }
            if self.coordinator.mode != .expanded
                || self.coordinator.activeTab != .shelf
                || self.coordinator.isShowingPresetHome {
                self.coordinator.expand(tab: .shelf)
            }
            self.shelf.isAirDropDropTargeted = self.isCursorInAirDropZone()
        }
        panel.onDragExited = { [weak self] in
            self?.shelf.isDropTargeted = false
            self?.shelf.isAirDropDropTargeted = false
        }
        panel.onPerformDrop = { [weak self] info in
            guard let self, self.settings.enableShelfModule else { return false }
            let toAirDrop = self.isCursorInAirDropZone()
            self.shelf.isAirDropDropTargeted = false
            let handled = toAirDrop
                ? self.shelf.handleExternalDropToAirDrop(info)
                : self.shelf.handleDraggingInfo(info)
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

    private func isCursorInAirDropZone() -> Bool {
        let onShelfTab = (coordinator.activeTab == .shelf && !coordinator.isShowingPresetHome)
        let onCreatorAirDropHome = (coordinator.isShowingPresetHome && settings.layoutPreset == .minimalCompact)
        guard coordinator.mode == .expanded, (onShelfTab || onCreatorAirDropHome) else {
            return false
        }
        let islandLeft = coordinator.geometry.notchCenterX - coordinator.currentSize.width / 2.0
        let mouseX = NSEvent.mouseLocation.x
        let zoneWidth: CGFloat = onCreatorAirDropHome ? (coordinator.currentSize.width * 0.5) : 152
        return mouseX >= islandLeft && mouseX <= islandLeft + zoneWidth
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

private final class GlobalHideHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let handler: () -> Void

    init?(handler: @escaping () -> Void) {
        self.handler = handler
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData, let event else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr, hotKeyID.signature == 0x494C4841, hotKeyID.id == 1 else {
                    return OSStatus(eventNotHandledErr)
                }
                let instance = Unmanaged<GlobalHideHotKey>.fromOpaque(userData).takeUnretainedValue()
                instance.handler()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &handlerRef
        )
        guard installStatus == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: 0x494C4841, id: 1)
        let regStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_H),
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard regStatus == noErr else {
            unregister()
            return nil
        }
    }

    deinit {
        unregister()
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }
}
