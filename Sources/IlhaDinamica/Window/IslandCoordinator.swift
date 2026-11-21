import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class IslandCoordinator: ObservableObject {
    @Published private(set) var geometry: NotchGeometry
    @Published private(set) var mode: IslandMode = .idle
    @Published var activeTab: IslandTab = .music {
        didSet { syncPanelKeyFocus() }
    }
    @Published var isPinned: Bool = false
    @Published var isMirrorOpen: Bool = false {
        didSet { syncPanelKeyFocus() }
    }
    @Published var isWeatherOpen: Bool = false {
        didSet { syncPanelKeyFocus() }
    }

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

    weak var panel: IslandPanel?
    var onOpenSettings: (() -> Void)?

    private var mouseTimer: Timer?
    nonisolated(unsafe) private var globalMouseMonitor: Any?
    nonisolated(unsafe) private var localMouseMonitor: Any?
    private var hoverExpandTask: Task<Void, Never>?
    private var hoverCollapseTask: Task<Void, Never>?
    private var toastDismissTask: Task<Void, Never>?
    private var reattachTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var wasMouseInside = false
    private var wasInteractingInside = false
    private var isDetachedForDrag = false
    private var suppressHoverExpandUntilExit = false
    private weak var previouslyActiveApp: NSRunningApplication?

    init(
        settings: SettingsStore,
        music: MusicService,
        pomodoro: PomodoroService,
        battery: BatteryService,
        shelf: ShelfService,
        clipboard: ClipboardService,
        calendar: CalendarService,
        notes: NotesService,
        audio: AudioControlService,
        camera: CameraMirrorService,
        system: SystemMonitorService,
        weather: WeatherService,
        recorder: ScreenRecorderService
    ) {
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
        self.geometry = NotchGeometry.current()

        observeServices()
        syncRestingMode(animated: false)
        startMouseTracking()
    }

    deinit {
        mouseTimer?.invalidate()
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        hoverExpandTask?.cancel()
        hoverCollapseTask?.cancel()
        toastDismissTask?.cancel()
        reattachTask?.cancel()
    }

    var currentSize: CGSize {
        switch mode {
        case .idle:
            return CGSize(width: geometry.notchWidth, height: geometry.notchHeight)

        case .compact:
            if geometry.hasNotch {
                return CGSize(width: geometry.notchWidth + 148, height: geometry.notchHeight)
            } else {
                return CGSize(width: 224, height: 36)
            }

        case .toast:
            if geometry.hasNotch {
                return CGSize(
                    width: max(geometry.notchWidth + 216, 392),
                    height: max(geometry.notchHeight + 54, 86)
                )
            } else {
                return CGSize(width: 356, height: 66)
            }

        case .expanded:
            let recordingExtra: CGFloat = recorder.isRecording ? 32 : 0
            return CGSize(
                width: 508,
                height: max(geometry.notchHeight + 214, 246) + recordingExtra
            )
        }
    }

    var shouldShowCompact: Bool {
        let musicActive = settings.enableMusicModule && (music.isPlaying || music.hasTrack)
        let pomodoroActive = settings.enablePomodoroModule && pomodoro.isRunning
        let batteryActive = settings.enableBatteryModule && (battery.isCharging || battery.percentage <= 20)
        let micActive = audio.isMicMuted
        return recorder.isRecording || musicActive || pomodoroActive || batteryActive || micActive
    }

    var restingMode: IslandMode {
        shouldShowCompact ? .compact : .idle
    }

    func updateGeometry() {
        let updated = NotchGeometry.current()
        if updated != geometry {
            geometry = updated
            panel?.updateFrame(for: updated)
        }
    }

    func expand(tab: IslandTab? = nil) {
        hoverExpandTask?.cancel()
        hoverExpandTask = nil
        hoverCollapseTask?.cancel()
        hoverCollapseTask = nil
        toastDismissTask?.cancel()
        toastDismissTask = nil

        if let tab, settings.enabledTabs.contains(tab) {
            activeTab = tab
            if isWeatherOpen {
                isWeatherOpen = false
            }
            if tab == .shelf && isMirrorOpen {
                isMirrorOpen = false
                camera.stop()
            }
        } else if !settings.enabledTabs.contains(activeTab), let first = settings.enabledTabs.first {
            activeTab = first
        }

        withAnimation(settings.expandSpring) {
            mode = .expanded
        }
        syncPanelKeyFocus()
    }

    func presentShelfPreviewBriefly() {
        presentBriefPeek(tab: .shelf, duration: 5.5)
    }

    func presentBriefPeek(tab: IslandTab?, duration: TimeInterval) {
        expand(tab: tab)
        guard !wasMouseInside, !isPinned else { return }
        scheduleHoverCollapse(after: duration, keepOpenIfWeather: true)
    }

    func collapse() {
        hoverExpandTask?.cancel()
        hoverExpandTask = nil
        hoverCollapseTask?.cancel()
        hoverCollapseTask = nil
        if wasMouseInside {
            suppressHoverExpandUntilExit = true
        }
        isPinned = false
        if isMirrorOpen {
            isMirrorOpen = false
        }
        if isWeatherOpen {
            isWeatherOpen = false
        }
        camera.stop()

        withAnimation(settings.collapseSpring) {
            mode = restingMode
        }
        syncPanelKeyFocus()
    }

    func toggleExpanded() {
        if mode == .expanded {
            collapse()
        } else {
            expand(tab: smartDefaultTab())
        }
    }

    func togglePin() {
        isPinned.toggle()
        if isPinned && mode != .expanded {
            expand()
        }
    }

    func toggleMirror() {
        if isMirrorOpen {
            isMirrorOpen = false
            camera.stop()
        } else {
            if isWeatherOpen {
                isWeatherOpen = false
            }
            if mode != .expanded {
                expand(tab: activeTab)
            }
            isMirrorOpen = true
            camera.start()
        }
    }

    func toggleWeather() {
        if isWeatherOpen {
            withAnimation(settings.sizeSpring) {
                isWeatherOpen = false
            }
        } else {
            openWeather()
        }
    }

    func openWeather() {
        if isMirrorOpen {
            isMirrorOpen = false
            camera.stop()
        }
        if mode != .expanded {
            expand(tab: activeTab)
        }
        withAnimation(settings.sizeSpring) {
            isWeatherOpen = true
        }
    }

    func focusPanelForTyping() {
        guard mode == .expanded, activeTab == .notes, !isMirrorOpen, !isWeatherOpen else { return }
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier {
            previouslyActiveApp = front
        }
        panel?.allowsKeyFocus = true
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKey()
    }

    func showToast(_ event: ToastEvent, duration: TimeInterval? = nil) {
        if case .expanded = mode {
            return
        }

        toastDismissTask?.cancel()
        hoverExpandTask?.cancel()

        let resolvedDuration = duration ?? (event.kind.isQuickHUD ? 1.6 : 3.2)

        withAnimation(settings.toastSpring) {
            mode = .toast(event)
        }

        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(resolvedDuration * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            if case .toast(let current) = self.mode, current.id == event.id {
                withAnimation(self.settings.collapseSpring) {
                    self.mode = self.restingMode
                }
            }
        }
    }

    func openSettings() {
        onOpenSettings?()
    }

    private func syncPanelKeyFocus() {
        let needsKey = (mode == .expanded && activeTab == .notes && !isMirrorOpen && !isWeatherOpen)
        panel?.allowsKeyFocus = needsKey
        if !needsKey {
            if panel?.isKeyWindow == true {
                panel?.resignKey()
            }
            if let prev = previouslyActiveApp {
                previouslyActiveApp = nil
                if NSApp.isActive {
                    prev.activate()
                }
            }
        }
    }

    private func smartDefaultTab() -> IslandTab {
        if settings.enabledTabs.contains(activeTab) {
            if activeTab == .music && !music.hasTrack && pomodoro.isRunning && settings.enablePomodoroModule {
                return .pomodoro
            }
            return activeTab
        }
        if settings.enableMusicModule && music.hasTrack { return .music }
        if settings.enablePomodoroModule && pomodoro.isRunning { return .pomodoro }
        return settings.enabledTabs.first ?? .music
    }

    private func observeServices() {
        recorder.$isRecording
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                withAnimation(self.settings.sizeSpring) {
                    self.objectWillChange.send()
                }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest4(
            music.$isPlaying,
            music.$hasTrack,
            pomodoro.$isRunning,
            Publishers.CombineLatest4(battery.$isCharging, battery.$percentage, audio.$isMicMuted, recorder.$isRecording)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _, _, _ in
            self?.syncRestingMode(animated: true)
        }
        .store(in: &cancellables)

        Publishers.CombineLatest4(
            settings.$enableMusicModule,
            settings.$enablePomodoroModule,
            settings.$enableShelfModule,
            settings.$enableClipboardModule
        )
        .combineLatest(
            Publishers.CombineLatest4(
                settings.$enableCalendarModule,
                settings.$enableNotesModule,
                settings.$enableAudioModule,
                settings.$enableSystemModule
            )
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _ in
            guard let self else { return }
            if !self.settings.enabledTabs.contains(self.activeTab),
               let fallback = self.settings.enabledTabs.first {
                self.activeTab = fallback
            }
            self.syncRestingMode(animated: true)
        }
        .store(in: &cancellables)
    }

    private func syncRestingMode(animated: Bool) {
        switch mode {
        case .expanded, .toast:
            return
        case .idle, .compact:
            let target = restingMode
            if mode != target {
                if animated {
                    withAnimation(settings.expandSpring) {
                        mode = target
                    }
                } else {
                    mode = target
                }
            }
        }
    }

    private func startMouseTracking() {
        let timer = Timer(timeInterval: 0.04, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateMousePosition()
            }
        }
        timer.tolerance = 0.005
        RunLoop.main.add(timer, forMode: .common)
        mouseTimer = timer

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluateMousePosition()
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.evaluateMousePosition()
            }
            return event
        }
    }

    private func evaluateMousePosition() {
        guard let panel else { return }

        let mouse = NSEvent.mouseLocation
        let hitRect = activeScreenRect()
        let isInside = hitRect.contains(mouse)
        let mousePressed = NSEvent.pressedMouseButtons != 0
        let startedOutside = !wasInteractingInside

        let dragTriggerRect = dragNotchTriggerRect()

        if !mousePressed {
            if isDetachedForDrag {
                scheduleReattachAfterDrag()
            }
            wasInteractingInside = false
        }

        let isExternalDragSession = mousePressed
            && startedOutside
            && settings.enableShelfModule
            && (mouse.y >= geometry.screenFrame.maxY - 180 || isDetachedForDrag)
            && Self.dragPasteboardHasDropPayload()

        if isExternalDragSession {
            reattachTask?.cancel()
            reattachTask = nil
            if !isDetachedForDrag {
                OverlaySpaceManager.shared.detach(window: panel)
                panel.orderFrontRegardless()
                isDetachedForDrag = true
            }
            if dragTriggerRect.contains(mouse) {
                hoverCollapseTask?.cancel()
                hoverCollapseTask = nil
                wasMouseInside = true
                if mode != .expanded || activeTab != .shelf {
                    expand(tab: .shelf)
                }
            }
        } else if isInside && !isDetachedForDrag {
            wasInteractingInside = true
        }

        let interactiveMode: Bool
        if case .idle = mode {
            interactiveMode = false
        } else {
            interactiveMode = true
        }
        let shouldAcceptMouse = (isInside && interactiveMode)
            || (isExternalDragSession && dragTriggerRect.contains(mouse))
            || (wasInteractingInside && mousePressed)
        if panel.ignoresMouseEvents == shouldAcceptMouse {
            panel.ignoresMouseEvents = !shouldAcceptMouse
        }

        let isInteractingWithControls = mousePressed
            || audio.isDraggingVolume
            || audio.isDraggingBrightness
            || music.isScrubbing
            || isExternalDragSession

        let wasInsideBefore = wasMouseInside
        let isNotesTextActive = (mode == .expanded && activeTab == .notes && !isMirrorOpen && !isWeatherOpen)
        let isSliderDragging = audio.isDraggingVolume || audio.isDraggingBrightness || music.isScrubbing
        if isSliderDragging || (isInside && !wasInsideBefore && interactiveMode && !isNotesTextActive) {
            NSCursor.arrow.set()
        }

        if isInside {
            wasMouseInside = true
            hoverCollapseTask?.cancel()
            hoverCollapseTask = nil

            if mode != .expanded
                && settings.openOnHover
                && !suppressHoverExpandUntilExit {
                if settings.effectiveHoverDelayMs <= 0 {
                    expand(tab: smartDefaultTab())
                } else if hoverExpandTask == nil {
                    scheduleHoverExpand()
                }
            }
        } else {
            wasMouseInside = false
            suppressHoverExpandUntilExit = false
            hoverExpandTask?.cancel()
            hoverExpandTask = nil

            if mode == .expanded && !isPinned && !isMirrorOpen {
                if isInteractingWithControls {
                    hoverCollapseTask?.cancel()
                    hoverCollapseTask = nil
                } else if hoverCollapseTask == nil {
                    scheduleHoverCollapse()
                }
            }
        }
    }

    private func scheduleReattachAfterDrag() {
        guard isDetachedForDrag, reattachTask == nil else { return }
        reattachTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled, let self, let panel = self.panel else { return }
            if NSEvent.pressedMouseButtons == 0 {
                OverlaySpaceManager.shared.attach(window: panel)
                self.isDetachedForDrag = false
                self.reattachTask = nil
            }
        }
    }

    private func dragNotchTriggerRect() -> CGRect {
        let width: CGFloat = 440
        let height: CGFloat = max(geometry.notchHeight + 64, 96)
        let originX = geometry.notchCenterX - width / 2.0
        let originY = geometry.screenFrame.maxY - height
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    private static func dragPasteboardHasDropPayload() -> Bool {
        let pb = NSPasteboard(name: .drag)
        guard let types = pb.types, !types.isEmpty else { return false }

        let knownTypes: Set<String> = [
            NSPasteboard.PasteboardType.fileURL.rawValue,
            NSPasteboard.PasteboardType.png.rawValue,
            NSPasteboard.PasteboardType.tiff.rawValue,
            "NSFilenamesPboardType",
            "public.png",
            "public.jpeg",
            "public.image",
            "com.apple.pasteboard.promised-file-url",
            "com.apple.NSFilePromiseItemMetaData"
        ]
        if types.contains(where: { knownTypes.contains($0.rawValue) }) {
            return true
        }
        let promiseTypes = Set(NSFilePromiseReceiver.readableDraggedTypes)
        return types.contains(where: { promiseTypes.contains($0.rawValue) })
    }

    private func scheduleHoverExpand() {
        hoverExpandTask?.cancel()
        let delayNs = UInt64(max(0, settings.effectiveHoverDelayMs)) * 1_000_000
        hoverExpandTask = Task { [weak self] in
            if delayNs > 0 {
                try? await Task.sleep(nanoseconds: delayNs)
            }
            guard !Task.isCancelled, let self else { return }
            self.hoverExpandTask = nil
            guard self.wasMouseInside,
                  !self.suppressHoverExpandUntilExit,
                  self.mode != .expanded else {
                return
            }
            self.expand(tab: self.smartDefaultTab())
        }
    }

    private func scheduleHoverCollapse(after delaySeconds: TimeInterval? = nil, keepOpenIfWeather: Bool = false) {
        hoverCollapseTask?.cancel()
        let resolved = delaySeconds ?? settings.effectiveCollapseDelaySeconds
        let delayNs = UInt64(max(0.01, resolved) * 1_000_000_000)
        hoverCollapseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNs)
            guard !Task.isCancelled, let self else { return }
            self.hoverCollapseTask = nil
            guard !self.wasMouseInside,
                  !self.isPinned,
                  !self.isMirrorOpen,
                  (!keepOpenIfWeather || !self.isWeatherOpen),
                  NSEvent.pressedMouseButtons == 0,
                  !self.audio.isDraggingVolume,
                  !self.audio.isDraggingBrightness,
                  !self.music.isScrubbing else {
                return
            }
            self.collapse()
        }
    }

    private func activeScreenRect() -> CGRect {
        let size = currentSize
        let originX = geometry.notchCenterX - size.width / 2.0
        let topY = geometry.screenFrame.maxY - geometry.topInset
        let originY = topY - size.height
        let base = CGRect(x: originX, y: originY, width: size.width, height: size.height)

        switch mode {
        case .expanded:
            return CGRect(
                x: base.minX - 2,
                y: base.minY - 2,
                width: base.width + 4,
                height: base.height + 8
            )
        case .idle, .compact:
            if geometry.hasNotch {
                return CGRect(
                    x: base.minX - 6,
                    y: base.minY,
                    width: base.width + 12,
                    height: base.height + 8
                )
            } else {
                return base.insetBy(dx: -4, dy: -4)
            }
        case .toast:
            return base.insetBy(dx: -4, dy: -4)
        }
    }
}
