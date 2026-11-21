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
    @Published var isEditingWidgets: Bool = false {
        didSet { syncPanelKeyFocus() }
    }
    @Published var isPresetsOpen: Bool = false {
        didSet { syncPanelKeyFocus() }
    }
    @Published var presetPanelTab: PresetPanelTab = .layouts
    @Published var isShowingPresetHome: Bool = false {
        didSet { syncPanelKeyFocus() }
    }
    @Published var draggingWidgetTab: IslandTab? = nil
    @Published var draggingWidgetInitialIndex: Int = 0
    @Published var draggingWidgetTranslation: CGSize = .zero

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
    private var lastIdleDragPasteboardChangeCount: Int = NSPasteboard(name: .drag).changeCount
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
        recorder: ScreenRecorderService,
        extraWidgets: ExtraWidgetsService
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
        self.extraWidgets = extraWidgets
        self.geometry = NotchGeometry.current()
        self.isShowingPresetHome = settings.layoutPreset.hasHomeDashboard

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
                return CGSize(
                    width: geometry.notchWidth + settings.layoutPreset.compactExtraWidth,
                    height: geometry.notchHeight
                )
            } else {
                return CGSize(width: 200, height: 33)
            }

        case .toast(let event):
            if case .bluetoothConnected = event.kind {
                return CGSize(
                    width: max(geometry.notchWidth + 242, 420),
                    height: geometry.hasNotch ? 154 : 124
                )
            }
            if case .charging = event.kind {
                return CGSize(
                    width: max(geometry.notchWidth + 246, 424),
                    height: geometry.hasNotch ? 164 : 134
                )
            }
            if case .volume = event.kind {
                if geometry.hasNotch {
                    return CGSize(
                        width: max(geometry.notchWidth + 226, 404),
                        height: max(geometry.notchHeight + 60, 92)
                    )
                } else {
                    return CGSize(width: 368, height: 72)
                }
            }
            if geometry.hasNotch {
                return CGSize(
                    width: max(geometry.notchWidth + 216, 392),
                    height: max(geometry.notchHeight + 54, 86)
                )
            } else {
                return CGSize(width: 356, height: 66)
            }

        case .expanded:
            let preset = settings.layoutPreset
            let recordingExtra: CGFloat = recorder.isRecording ? 32 : 0
            if isEditingWidgets {
                let editorExtraHeight: CGFloat = recorder.isRecording ? 154 : 174
                return CGSize(
                    width: 632,
                    height: max(geometry.notchHeight + 214, 246) + recordingExtra + editorExtraHeight
                )
            }
            if isPresetsOpen {
                return CGSize(
                    width: 616,
                    height: 384 + recordingExtra
                )
            }
            return CGSize(
                width: preset.expandedWidth,
                height: max(geometry.notchHeight + (preset.expandedBaseHeight - 32), preset.expandedBaseHeight) + recordingExtra
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

    func isPointInsideIsland(_ point: CGPoint = NSEvent.mouseLocation) -> Bool {
        activeScreenRect().contains(point)
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
            isShowingPresetHome = false
            activeTab = tab
            if isWeatherOpen {
                isWeatherOpen = false
            }
            if isPresetsOpen {
                isPresetsOpen = false
            }
            if tab == .shelf && isMirrorOpen {
                isMirrorOpen = false
                camera.stop()
            }
        } else {
            if !settings.enabledTabs.contains(activeTab), let first = settings.enabledTabs.first {
                activeTab = first
            }
            if tab == nil {
                isShowingPresetHome = settings.layoutPreset.hasHomeDashboard
            }
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
        if isEditingWidgets {
            isEditingWidgets = false
        }
        if isPresetsOpen {
            isPresetsOpen = false
        }
        draggingWidgetTab = nil
        draggingWidgetInitialIndex = 0
        draggingWidgetTranslation = .zero
        camera.stop()

        withAnimation(settings.collapseSpring) {
            mode = restingMode
        }
        syncPanelKeyFocus()
        OverlaySpaceManager.shared.resetActiveSpaceMenuBar()
    }

    func selectTab(_ tab: IslandTab) {
        withAnimation(settings.sizeSpring) {
            isShowingPresetHome = false
            activeTab = tab
        }
    }

    func showPresetHome() {
        guard settings.layoutPreset.hasHomeDashboard else { return }
        if isMirrorOpen {
            isMirrorOpen = false
            camera.stop()
        }
        if isWeatherOpen {
            isWeatherOpen = false
        }
        if isEditingWidgets {
            isEditingWidgets = false
        }
        if isPresetsOpen {
            isPresetsOpen = false
        }
        if mode != .expanded {
            expand()
        }
        withAnimation(settings.sizeSpring) {
            isShowingPresetHome = true
        }
    }

    func toggleExpanded() {
        if mode == .expanded {
            collapse()
        } else {
            expand(tab: settings.layoutPreset.hasHomeDashboard ? nil : smartDefaultTab())
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
            if isEditingWidgets {
                isEditingWidgets = false
            }
            if isPresetsOpen {
                isPresetsOpen = false
            }
            if mode != .expanded {
                expand()
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
        if isEditingWidgets {
            isEditingWidgets = false
        }
        if isPresetsOpen {
            isPresetsOpen = false
        }
        if mode != .expanded {
            expand()
        }
        withAnimation(settings.sizeSpring) {
            isWeatherOpen = true
        }
    }

    func toggleWidgetEditor() {
        draggingWidgetTab = nil
        draggingWidgetInitialIndex = 0
        draggingWidgetTranslation = .zero
        if isEditingWidgets {
            withAnimation(settings.sizeSpring) {
                isEditingWidgets = false
            }
        } else {
            if isMirrorOpen {
                isMirrorOpen = false
                camera.stop()
            }
            if isWeatherOpen {
                isWeatherOpen = false
            }
            if isPresetsOpen {
                isPresetsOpen = false
            }
            if mode != .expanded {
                expand()
            }
            withAnimation(settings.sizeSpring) {
                isEditingWidgets = true
            }
        }
    }

    func togglePresets() {
        draggingWidgetTab = nil
        draggingWidgetInitialIndex = 0
        draggingWidgetTranslation = .zero
        if isPresetsOpen {
            withAnimation(settings.sizeSpring) {
                isPresetsOpen = false
            }
        } else {
            if isMirrorOpen {
                isMirrorOpen = false
                camera.stop()
            }
            if isWeatherOpen {
                isWeatherOpen = false
            }
            if isEditingWidgets {
                isEditingWidgets = false
            }
            if mode != .expanded {
                expand()
            }
            withAnimation(settings.sizeSpring) {
                isPresetsOpen = true
            }
        }
    }

    func updateWidgetDrag(tab: IslandTab, translation: CGSize, slotStride: CGFloat) {
        let active = settings.enabledTabs
        guard let currentIndex = active.firstIndex(of: tab) else { return }

        if draggingWidgetTab != tab {
            draggingWidgetTab = tab
            draggingWidgetInitialIndex = currentIndex
        }
        draggingWidgetTranslation = translation

        let projectedSlot = (CGFloat(draggingWidgetInitialIndex) * slotStride + translation.width) / slotStride
        let targetIndex = max(0, min(active.count - 1, Int(projectedSlot.rounded())))
        if targetIndex != currentIndex {
            withAnimation(settings.sizeSpring) {
                settings.moveEnabledTab(tab, toEnabledIndex: targetIndex)
            }
        }
    }

    func endWidgetDrag() {
        guard draggingWidgetTab != nil else { return }
        withAnimation(settings.sizeSpring) {
            draggingWidgetTab = nil
            draggingWidgetInitialIndex = 0
            draggingWidgetTranslation = .zero
        }
    }

    func dragOffset(for tab: IslandTab, slotStride: CGFloat) -> CGSize {
        guard draggingWidgetTab == tab,
              let currentIndex = settings.enabledTabs.firstIndex(of: tab) else {
            return .zero
        }
        let dx = draggingWidgetTranslation.width - CGFloat(currentIndex - draggingWidgetInitialIndex) * slotStride
        let dy = max(-10, min(10, draggingWidgetTranslation.height * 0.25))
        return CGSize(width: dx, height: dy)
    }

    func focusPanelForTyping() {
        guard mode == .expanded,
              activeTab.requiresKeyboardFocus,
              !isShowingPresetHome,
              !isMirrorOpen,
              !isWeatherOpen,
              !isEditingWidgets,
              !isPresetsOpen else { return }
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
        let needsKey = (mode == .expanded && activeTab.requiresKeyboardFocus && !isShowingPresetHome && !isMirrorOpen && !isWeatherOpen && !isEditingWidgets && !isPresetsOpen)
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

        settings.$tabOrder
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if !self.settings.enabledTabs.contains(self.activeTab),
                   let fallback = self.settings.enabledTabs.first {
                    self.activeTab = fallback
                }
            }
            .store(in: &cancellables)

        settings.$enabledExtraTabs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if !self.settings.enabledTabs.contains(self.activeTab),
                   let fallback = self.settings.enabledTabs.first {
                    self.activeTab = fallback
                }
                self.syncRestingMode(animated: true)
            }
            .store(in: &cancellables)

        settings.$layoutPreset
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                withAnimation(self.settings.sizeSpring) {
                    self.isShowingPresetHome = self.settings.layoutPreset.hasHomeDashboard
                    self.objectWillChange.send()
                }
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
        if isInside && mouse.y >= geometry.screenFrame.maxY - 38 {
            OverlaySpaceManager.shared.interruptMenuBarReveal()
        }
        let mousePressed = NSEvent.pressedMouseButtons != 0
        let startedOutside = !wasInteractingInside

        if !mousePressed {
            lastIdleDragPasteboardChangeCount = NSPasteboard(name: .drag).changeCount
            if isDetachedForDrag {
                scheduleReattachAfterDrag()
            }
            wasInteractingInside = false
        }

        let hasActiveExternalFileDrag = mousePressed
            && startedOutside
            && settings.enableShelfModule
            && Self.dragPasteboardHasDropPayload(sinceIdleChangeCount: lastIdleDragPasteboardChangeCount)

        if hasActiveExternalFileDrag && isInside {
            reattachTask?.cancel()
            reattachTask = nil
            if !isDetachedForDrag {
                OverlaySpaceManager.shared.detach(window: panel)
                panel.orderFrontRegardless()
                isDetachedForDrag = true
            }
            hoverCollapseTask?.cancel()
            hoverCollapseTask = nil
            wasMouseInside = true
            if mode != .expanded || activeTab != .shelf {
                expand(tab: .shelf)
            }
        } else if isInside && !isDetachedForDrag && !hasActiveExternalFileDrag {
            wasInteractingInside = true
        }

        let interactiveMode: Bool
        if case .idle = mode {
            interactiveMode = false
        } else {
            interactiveMode = true
        }
        let shouldAcceptMouse = (isInside && (interactiveMode || hasActiveExternalFileDrag))
            || (wasInteractingInside && mousePressed)
        if panel.ignoresMouseEvents == shouldAcceptMouse {
            panel.ignoresMouseEvents = !shouldAcceptMouse
        }

        let isInteractingWithControls = (wasInteractingInside && mousePressed)
            || audio.isDraggingVolume
            || audio.isDraggingBrightness
            || music.isScrubbing
            || draggingWidgetTab != nil
            || extraWidgets.isInteracting
            || (hasActiveExternalFileDrag && isInside)

        let wasInsideBefore = wasMouseInside
        let isKeyboardTabActive = (mode == .expanded && activeTab.requiresKeyboardFocus && !isShowingPresetHome && !isMirrorOpen && !isWeatherOpen && !isEditingWidgets && !isPresetsOpen)
        let isSliderDragging = audio.isDraggingVolume || audio.isDraggingBrightness || music.isScrubbing || draggingWidgetTab != nil
        if isSliderDragging || (isInside && !wasInsideBefore && interactiveMode && !isKeyboardTabActive) {
            NSCursor.arrow.set()
        }

        if isInside {
            wasMouseInside = true
            hoverCollapseTask?.cancel()
            hoverCollapseTask = nil

            if mode != .expanded
                && settings.openOnHover
                && !mousePressed
                && !suppressHoverExpandUntilExit {
                if settings.effectiveHoverDelayMs <= 0 {
                    expand(tab: settings.layoutPreset.hasHomeDashboard ? nil : smartDefaultTab())
                } else if hoverExpandTask == nil {
                    scheduleHoverExpand()
                }
            }
        } else {
            if wasInsideBefore {
                OverlaySpaceManager.shared.resetActiveSpaceMenuBar()
            }
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

    private static func dragPasteboardHasDropPayload(sinceIdleChangeCount idleCount: Int) -> Bool {
        let pb = NSPasteboard(name: .drag)
        guard pb.changeCount != idleCount else { return false }
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
                  NSEvent.pressedMouseButtons == 0,
                  !self.suppressHoverExpandUntilExit,
                  self.mode != .expanded else {
                return
            }
            self.expand(tab: self.settings.layoutPreset.hasHomeDashboard ? nil : self.smartDefaultTab())
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
        case .idle, .compact, .toast:
            return CGRect(
                x: base.minX,
                y: base.minY,
                width: base.width,
                height: base.height + geometry.topInset + 2
            )
        }
    }
}
