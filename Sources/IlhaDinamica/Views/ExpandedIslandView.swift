import SwiftUI

struct ExpandedIslandView: View {
    @ObservedObject var coordinator: IslandCoordinator
    @ObservedObject var settings: SettingsStore
    @ObservedObject var music: MusicService
    @ObservedObject var pomodoro: PomodoroService
    @ObservedObject var battery: BatteryService
    @ObservedObject var shelf: ShelfService
    @ObservedObject var clipboard: ClipboardService
    @ObservedObject var calendar: CalendarService
    @ObservedObject var notes: NotesService
    @ObservedObject var audio: AudioControlService
    @ObservedObject var camera: CameraMirrorService
    @ObservedObject var system: SystemMonitorService
    @ObservedObject var weather: WeatherService
    @ObservedObject var recorder: ScreenRecorderService
    @ObservedObject var extraWidgets: ExtraWidgetsService

    var body: some View {
        let showTabBar = !coordinator.isMirrorOpen && !coordinator.isWeatherOpen && !coordinator.isPresetsOpen
        let bottomTabLayout = (settings.layoutPreset.tabBarPosition == .bottom)
            && !coordinator.isEditingWidgets
            && showTabBar
        let shoulderTabLayout = (settings.layoutPreset.tabBarPosition == .shoulder)
            && !coordinator.isEditingWidgets
            && showTabBar

        let headerHorizontalPadding: CGFloat = coordinator.geometry.hasNotch
            ? max(20, settings.layoutPreset.topEarRadius + 4)
            : 16

        VStack(spacing: 0) {
            Group {
                if shoulderTabLayout {
                    switch settings.layoutPreset {
                    case .atoll:
                        atollShoulderHeaderRow
                    case .dynamicLake, .liquidGlass:
                        dynamicLakeShoulderHeaderRow
                    default:
                        superIslandShoulderHeaderRow
                    }
                } else {
                    headerRow
                }
            }
            .frame(height: coordinator.geometry.notchHeight + 4)
            .padding(.horizontal, headerHorizontalPadding)
            .padding(.top, coordinator.geometry.hasNotch ? 2 : 8)

            if recorder.isRecording {
                recordingLiveBanner
                    .padding(.horizontal, coordinator.geometry.hasNotch ? 26 : 16)
                    .padding(.top, 5)
            }

            if showTabBar && !bottomTabLayout && !shoulderTabLayout {
                tabBarRow
                    .padding(.horizontal, coordinator.geometry.hasNotch ? 26 : 16)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
            } else {
                Spacer()
                    .frame(height: 8)
            }

            Group {
                if coordinator.isMirrorOpen {
                    MirrorExpandedView(
                        camera: camera,
                        audio: audio,
                        onClose: { coordinator.toggleMirror() }
                    )
                } else if coordinator.isWeatherOpen {
                    WeatherExpandedView(
                        weather: weather,
                        onClose: { coordinator.toggleWeather() }
                    )
                } else if coordinator.isEditingWidgets {
                    WidgetEditorExpandedView(
                        coordinator: coordinator,
                        settings: settings
                    )
                } else if coordinator.isPresetsOpen {
                    LayoutPresetsExpandedView(
                        coordinator: coordinator,
                        settings: settings
                    )
                } else if coordinator.isShowingPresetHome && settings.layoutPreset.hasHomeDashboard {
                    PresetHomeDashboardView(
                        coordinator: coordinator,
                        settings: settings,
                        music: music,
                        pomodoro: pomodoro,
                        battery: battery,
                        shelf: shelf,
                        calendar: calendar,
                        notes: notes,
                        audio: audio,
                        system: system,
                        weather: weather,
                        recorder: recorder,
                        extraWidgets: extraWidgets
                    )
                } else {
                    tabContent
                }
            }
            .id(activeContentID)
            .transition(.opacity)
            .padding(.horizontal, coordinator.geometry.hasNotch ? 26 : 18)
            .padding(.bottom, bottomTabLayout ? 8 : 14)
            .frame(maxHeight: .infinity, alignment: .top)

            if bottomTabLayout {
                tabBarRow
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.75)
                    )
                    .padding(.horizontal, coordinator.geometry.hasNotch ? 24 : 16)
                    .padding(.bottom, 12)
            }
        }
    }

    private var activeContentID: String {
        if coordinator.isMirrorOpen { return "mirror" }
        if coordinator.isWeatherOpen { return "weather" }
        if coordinator.isEditingWidgets { return "widgetEditor" }
        if coordinator.isPresetsOpen { return "presets" }
        if coordinator.isShowingPresetHome && settings.layoutPreset.hasHomeDashboard {
            return "presetHome_\(settings.layoutPreset.rawValue)"
        }
        return coordinator.activeTab.rawValue
    }

    @ViewBuilder
    private func notchedHeaderLayout<Left: View, Right: View>(
        @ViewBuilder left: @escaping (_ wingWidth: CGFloat) -> Left,
        @ViewBuilder right: @escaping () -> Right
    ) -> some View {
        if coordinator.geometry.hasNotch {
            GeometryReader { geo in
                let notchGap = coordinator.geometry.notchWidth + 28
                let wingWidth = max(0, (geo.size.width - notchGap) / 2.0)

                HStack(spacing: 0) {
                    left(wingWidth)
                        .frame(width: wingWidth, height: geo.size.height, alignment: .leading)
                        .clipped()

                    Spacer()
                        .frame(width: notchGap)

                    right()
                        .frame(width: wingWidth, height: geo.size.height, alignment: .trailing)
                        .clipped()
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            }
        } else {
            HStack(spacing: 10) {
                left(.infinity)
                    .frame(maxWidth: .infinity, alignment: .leading)

                right()
                    .layoutPriority(1)
            }
        }
    }

    private func snappedScrollWidth(
        wingWidth: CGFloat,
        homeWidth: CGFloat,
        homeSpacing: CGFloat,
        itemWidth: CGFloat,
        itemSpacing: CGFloat
    ) -> (width: CGFloat?, wholeCount: Int) {
        guard wingWidth.isFinite else {
            return (nil, settings.enabledTabs.count)
        }
        let remaining = max(0, wingWidth - homeWidth - homeSpacing)
        let stride = itemWidth + itemSpacing
        let wholeCount = max(1, Int(floor((remaining + itemSpacing) / stride)))
        let snapped = CGFloat(wholeCount) * itemWidth + CGFloat(max(0, wholeCount - 1)) * itemSpacing
        return (min(remaining, snapped), wholeCount)
    }

    private func snappedShoulderScroll<Content: View>(
        wingWidth: CGFloat,
        slotSize: CGFloat,
        spacing: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let layout = snappedScrollWidth(
            wingWidth: wingWidth,
            homeWidth: slotSize,
            homeSpacing: spacing,
            itemWidth: slotSize,
            itemSpacing: spacing
        )
        let needsFade = settings.enabledTabs.count > layout.wholeCount

        return ScrollView(.horizontal, showsIndicators: false) {
            content()
                .padding(.trailing, needsFade ? 4 : 0)
        }
        .frame(width: layout.width)
        .mask(shoulderScrollFadeMask(enabled: needsFade))
    }

    private func shoulderScrollFadeMask(enabled: Bool) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(.black)
            LinearGradient(
                colors: [.black, enabled ? .clear : .black],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 6)
        }
    }

    private var headerRow: some View {
        notchedHeaderLayout { _ in
            HStack(spacing: 5) {
                if settings.showWeatherInHeader, let temp = weather.temperatureCelsius {
                    Button {
                        coordinator.toggleWeather()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: weather.symbolName)
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.28))
                            Text(String(format: "%.0f°", temp))
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(coordinator.isWeatherOpen ? .white : Color.white.opacity(0.84))
                        }
                        .padding(.horizontal, 7)
                        .frame(height: 22)
                        .background(
                            coordinator.isWeatherOpen
                                ? Color(red: 1.0, green: 0.80, blue: 0.28).opacity(0.24)
                                : Color.white.opacity(0.07),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    coordinator.isWeatherOpen ? Color(red: 1.0, green: 0.80, blue: 0.28).opacity(0.55) : Color.clear,
                                    lineWidth: 0.75
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .help(coordinator.isWeatherOpen ? "Fechar previsão do tempo" : "Ver previsão do tempo")
                }

                HStack(spacing: 3) {
                    if battery.isCharging || battery.isPluggedIn {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(Color(red: 0.22, green: 0.90, blue: 0.48))
                    }
                    Text("\(battery.percentage)%")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.white.opacity(0.78))
                }
                .padding(.horizontal, 6)
                .frame(height: 22)
                .background(Color.white.opacity(0.07), in: Capsule())

                Button {
                    audio.toggleMicMute()
                } label: {
                    Image(systemName: audio.isMicMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(audio.isMicMuted ? .white : Color.white.opacity(0.68))
                        .frame(width: 22, height: 22)
                        .background(
                            audio.isMicMuted ? Color.red.opacity(0.85) : Color.white.opacity(0.07),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .help(audio.isMicMuted ? "Ativar microfone" : "Mutar microfone")
            }
        } right: {
            headerRightActionButtons
        }
    }

    private var superIslandShoulderHeaderRow: some View {
        notchedHeaderLayout { wingWidth in
            HStack(spacing: 4) {
                superIslandShoulderTabButton(
                    icon: "house.fill",
                    isSelected: coordinator.isShowingPresetHome,
                    helpText: "Início (\(settings.layoutPreset.title))"
                ) {
                    coordinator.showPresetHome()
                }

                snappedShoulderScroll(wingWidth: wingWidth, slotSize: 28, spacing: 4) {
                    HStack(spacing: 4) {
                        ForEach(settings.enabledTabs) { tab in
                            let selected = coordinator.activeTab == tab && !coordinator.isShowingPresetHome
                            superIslandShoulderTabButton(
                                icon: tab.iconName,
                                isSelected: selected,
                                badgeDot: !selected && hasBadge(for: tab) ? badgeColor(for: tab) : nil,
                                helpText: tab.title
                            ) {
                                coordinator.selectTab(tab)
                            }
                        }
                    }
                }
            }
        } right: {
            HStack(spacing: 5) {
                if settings.layoutPreset == .superIsland {
                    HStack(spacing: 2.5) {
                        if battery.isCharging || battery.isPluggedIn {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color(red: 0.22, green: 0.90, blue: 0.48))
                        }
                        Text("\(battery.percentage)%")
                            .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color.white.opacity(0.76))
                    }
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(Color.black.opacity(0.92), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                }

                headerRightActionButtons
            }
        }
    }

    private func superIslandShoulderTabButton(
        icon: String,
        isSelected: Bool,
        badgeDot: Color? = nil,
        helpText: String,
        action: @escaping () -> Void
    ) -> some View {
        let customBtn = settings.buttonAccentColor.color
        let activeIconColor = isSelected ? (customBtn ?? Color.white.opacity(0.96)) : Color.white.opacity(0.72)
        let activeStrokeColor = isSelected
            ? (customBtn?.opacity(0.72) ?? Color.white.opacity(0.18))
            : Color.white.opacity(0.08)
        let activeFillOverlay = isSelected
            ? (customBtn?.opacity(0.16) ?? Color.white.opacity(0.08))
            : Color.white.opacity(0.02)

        return Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(activeIconColor)

                if let badgeDot {
                    Circle()
                        .fill(badgeDot)
                        .frame(width: 4.5, height: 4.5)
                        .offset(x: 4, y: -2)
                }
            }
            .frame(width: 28, height: 22)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.98), Color.black.opacity(0.94)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(activeFillOverlay)
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(activeStrokeColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var atollShoulderHeaderRow: some View {
        notchedHeaderLayout { wingWidth in
            HStack(spacing: 4) {
                atollShoulderTabButton(
                    icon: "house.fill",
                    isSelected: coordinator.isShowingPresetHome,
                    helpText: "Início (Atoll)"
                ) {
                    coordinator.showPresetHome()
                }

                snappedShoulderScroll(wingWidth: wingWidth, slotSize: 26, spacing: 4) {
                    HStack(spacing: 4) {
                        ForEach(settings.enabledTabs) { tab in
                            let selected = coordinator.activeTab == tab && !coordinator.isShowingPresetHome
                            atollShoulderTabButton(
                                icon: tab.iconName,
                                isSelected: selected,
                                badgeDot: !selected && hasBadge(for: tab) ? badgeColor(for: tab) : nil,
                                helpText: tab.title
                            ) {
                                coordinator.selectTab(tab)
                            }
                        }
                    }
                }
            }
        } right: {
            HStack(spacing: 6) {
                HStack(spacing: 2.5) {
                    if battery.isCharging || battery.isPluggedIn {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color(red: 0.22, green: 0.90, blue: 0.48))
                    } else {
                        Image(systemName: atollBatterySymbolName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(
                                battery.percentage <= 20
                                    ? Color(red: 1.0, green: 0.34, blue: 0.30)
                                    : Color.white.opacity(0.68)
                            )
                    }
                    Text("\(battery.percentage)%")
                        .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.white.opacity(0.78))
                }

                headerRightActionButtons
            }
        }
    }

    private var atollBatterySymbolName: String {
        switch battery.percentage {
        case 88...: return "battery.100"
        case 63..<88: return "battery.75"
        case 38..<63: return "battery.50"
        case 15..<38: return "battery.25"
        default: return "battery.0"
        }
    }

    private func atollShoulderTabButton(
        icon: String,
        isSelected: Bool,
        badgeDot: Color? = nil,
        helpText: String,
        action: @escaping () -> Void
    ) -> some View {
        let customBtn = settings.buttonAccentColor.color
        let pillFill: Color = isSelected ? (customBtn?.opacity(0.28) ?? Color.white.opacity(0.20)) : Color.clear
        let pillGlow: Color = isSelected ? (customBtn?.opacity(0.26) ?? Color.white.opacity(0.18)) : .clear

        return Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        isSelected
                            ? (customBtn == .white ? .white : (customBtn ?? .white))
                            : Color.white.opacity(0.45)
                    )

                if let badgeDot {
                    Circle()
                        .fill(badgeDot)
                        .frame(width: 4.5, height: 4.5)
                        .offset(x: 4, y: -2)
                }
            }
            .frame(width: 26, height: 22)
            .background(
                Capsule(style: .continuous)
                    .fill(pillFill)
                    .shadow(color: pillGlow, radius: 5)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected && customBtn != nil ? customBtn!.opacity(0.65) : Color.clear, lineWidth: 0.8)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var dynamicLakeShoulderHeaderRow: some View {
        notchedHeaderLayout { wingWidth in
            HStack(spacing: 4) {
                dynamicLakeShoulderTabButton(
                    icon: "house.fill",
                    isSelected: coordinator.isShowingPresetHome,
                    helpText: "Início (\(settings.layoutPreset.title))"
                ) {
                    coordinator.showPresetHome()
                }

                snappedShoulderScroll(wingWidth: wingWidth, slotSize: 26, spacing: 4) {
                    HStack(spacing: 4) {
                        ForEach(settings.enabledTabs) { tab in
                            let selected = coordinator.activeTab == tab && !coordinator.isShowingPresetHome
                            dynamicLakeShoulderTabButton(
                                icon: tab.iconName,
                                isSelected: selected,
                                badgeDot: !selected && hasBadge(for: tab) ? badgeColor(for: tab) : nil,
                                helpText: tab.title
                            ) {
                                coordinator.selectTab(tab)
                            }
                        }
                    }
                }
            }
        } right: {
            headerRightActionButtons
        }
    }

    private func dynamicLakeShoulderTabButton(
        icon: String,
        isSelected: Bool,
        badgeDot: Color? = nil,
        helpText: String,
        action: @escaping () -> Void
    ) -> some View {
        let customBtn = settings.buttonAccentColor.color
        let pillFill: Color = isSelected ? (customBtn?.opacity(0.32) ?? Color.white.opacity(0.26)) : Color.clear
        let pillStroke: Color = isSelected ? (customBtn?.opacity(0.68) ?? Color.white.opacity(0.42)) : Color.clear

        return Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(isSelected ? 1.0 : 0.72))

                if let badgeDot {
                    Circle()
                        .fill(badgeDot)
                        .frame(width: 4.5, height: 4.5)
                        .offset(x: 4, y: -2)
                }
            }
            .frame(width: 26, height: 22)
            .background(
                Capsule(style: .continuous)
                    .fill(pillFill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(pillStroke, lineWidth: 0.75)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var headerRightActionButtons: some View {
        HStack(spacing: 3) {
                Button {
                    if recorder.isRecording {
                        recorder.stopRecording()
                    } else {
                        recorder.startFullScreenRecording()
                        if recorder.isRecording {
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 250_000_000)
                                if coordinator.mode == .expanded && !coordinator.isPinned {
                                    coordinator.collapse()
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: recorder.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(
                            recorder.isRecording
                                ? Color.white
                                : Color(red: 1.0, green: 0.28, blue: 0.26)
                        )
                        .frame(width: 18.5, height: 18.5)
                        .background(
                            recorder.isRecording
                                ? Color(red: 1.0, green: 0.24, blue: 0.22)
                                : Color(red: 1.0, green: 0.28, blue: 0.26).opacity(0.16),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .help(recorder.isRecording ? "Parar gravação de tela" : "Iniciar gravação de tela")

                Button {
                    coordinator.toggleWidgetEditor()
                } label: {
                    let activeColor = settings.resolvedButtonColor(fallback: Color(red: 0.36, green: 0.76, blue: 1.0))
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(
                            coordinator.isEditingWidgets
                                ? activeColor
                                : Color.white.opacity(0.66)
                        )
                        .frame(width: 18.5, height: 18.5)
                        .background(
                            coordinator.isEditingWidgets
                                ? activeColor.opacity(0.22)
                                : Color.white.opacity(0.07),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .help(coordinator.isEditingWidgets ? "Fechar edição de widgets" : "Editar e reordenar widgets da Ilha")

                Button {
                    coordinator.togglePresets()
                } label: {
                    let paletteTint = settings.resolvedButtonColor(fallback: settings.layoutPreset.accentColor)
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(
                            (coordinator.isPresetsOpen || settings.hasCustomColors)
                                ? paletteTint
                                : Color.white.opacity(0.66)
                        )
                        .frame(width: 18.5, height: 18.5)
                        .background(
                            coordinator.isPresetsOpen
                                ? paletteTint.opacity(0.22)
                                : Color.white.opacity(0.07),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .help(coordinator.isPresetsOpen ? "Fechar estilos & layouts" : "Estilos e layouts da Ilha")

                Button {
                    coordinator.toggleMirror()
                } label: {
                    let mirrorTint = settings.resolvedButtonColor(fallback: Color(red: 0.36, green: 0.76, blue: 1.0))
                    Image(systemName: "camera.fill")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(coordinator.isMirrorOpen ? mirrorTint : Color.white.opacity(0.66))
                        .frame(width: 18.5, height: 18.5)
                        .background(
                            coordinator.isMirrorOpen ? mirrorTint.opacity(0.20) : Color.white.opacity(0.07),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .help(coordinator.isMirrorOpen ? "Fechar espelho" : "Espelho rápido (Webcam)")

                Button {
                    coordinator.togglePin()
                } label: {
                    Image(systemName: coordinator.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(coordinator.isPinned ? Color.yellow : Color.white.opacity(0.62))
                        .frame(width: 18.5, height: 18.5)
                        .background(
                            coordinator.isPinned ? Color.yellow.opacity(0.18) : Color.white.opacity(0.07),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .help(coordinator.isPinned ? "Desafixar ilha" : "Fixar ilha aberta")

                Button {
                    coordinator.hideTemporarily()
                } label: {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.66))
                        .frame(width: 18.5, height: 18.5)
                        .background(Color.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Ocultar ilha temporariamente (⌃⌥H)")
                .contextMenu {
                    Button("Ocultar até mostrar (⌃⌥H)") { coordinator.hideTemporarily() }
                    Divider()
                    Button("Ocultar por 1 minuto") { coordinator.hideTemporarily(for: 60) }
                    Button("Ocultar por 5 minutos") { coordinator.hideTemporarily(for: 300) }
                    Button("Ocultar por 15 minutos") { coordinator.hideTemporarily(for: 900) }
                    Button("Ocultar por 1 hora") { coordinator.hideTemporarily(for: 3600) }
                }

                Button {
                    coordinator.openSettings()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.66))
                        .frame(width: 18.5, height: 18.5)
                        .background(Color.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Preferências")
            }
    }

    private var tabBarRow: some View {
        let tabs = settings.enabledTabs
        return Group {
            if coordinator.isEditingWidgets {
                let tray = TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    HStack(spacing: 5) {
                        ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                            let isDragging = coordinator.draggingWidgetTab == tab
                            let angle = isDragging ? 0.0 : sin(t * 22.0 + Double(index) * 1.6) * 2.1
                            tabPill(for: tab, jiggleDegrees: angle, isDragging: isDragging)
                                .zIndex(isDragging ? 10 : 0)
                        }
                    }
                    .coordinateSpace(name: "TopTabBarEdit")
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                }

                if tabs.count > 8 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        tray
                    }
                } else {
                    tray
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                let row = HStack(spacing: 5) {
                    if settings.layoutPreset.hasHomeDashboard {
                        homeTabPill
                    }
                    ForEach(tabs) { tab in
                        tabPill(for: tab, jiggleDegrees: 0, isDragging: false)
                    }
                }

                if tabs.count > (settings.layoutPreset.hasHomeDashboard ? 6 : 7) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        row
                            .padding(.horizontal, 2)
                    }
                } else {
                    row
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private var homeTabPill: some View {
        let style = settings.layoutPreset.tabPillStyle
        let accent = settings.resolvedButtonColor(fallback: settings.layoutPreset.accentColor)
        let selected = coordinator.isShowingPresetHome
        let cornerRadius: CGFloat = (style == .dock) ? 9 : 13

        return Button {
            coordinator.showPresetHome()
        } label: {
            HStack(spacing: 4.5) {
                Image(systemName: "rectangle.3.group.fill")
                    .font(.system(size: style == .dock ? 11 : 10.5, weight: .semibold))
                if selected && style != .iconOnly {
                    Text("Início")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(selected ? .white : Color.white.opacity(0.60))
            .padding(.horizontal, (selected && style != .iconOnly) ? 10 : 8)
            .frame(height: style == .dock ? 26 : 24)
            .background(
                selected ? accent.opacity(0.32) : Color.white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(selected ? accent.opacity(0.85) : Color.clear, lineWidth: 0.9)
            )
        }
        .buttonStyle(.plain)
        .help("Painel principal do layout (\(settings.layoutPreset.title))")
    }

    private func tabPill(for tab: IslandTab, jiggleDegrees: Double, isDragging: Bool) -> some View {
        let isEditing = coordinator.isEditingWidgets
        let isSelected = coordinator.activeTab == tab && (!coordinator.isShowingPresetHome || isEditing)
        let canRemove = settings.enabledTabs.count > 1
        let dragOffset = isEditing ? coordinator.dragOffset(for: tab, slotStride: 61) : .zero

        return ZStack(alignment: .topLeading) {
            Group {
                if isEditing {
                    HStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isSelected ? tab.accentColor : .white.opacity(0.85))
                    }
                    .frame(width: 56, height: 24)
                    .background(
                        isDragging
                            ? Color.white.opacity(0.28)
                            : (isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.08)),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isDragging ? tab.accentColor : (isSelected ? tab.accentColor.opacity(0.55) : Color.clear),
                                lineWidth: isDragging ? 1.1 : 0.7
                            )
                    )
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(settings.sizeSpring) {
                            coordinator.activeTab = tab
                        }
                    }
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 2, coordinateSpace: .named("TopTabBarEdit"))
                            .onChanged { value in
                                coordinator.updateWidgetDrag(
                                    tab: tab,
                                    translation: value.translation,
                                    slotStride: 61
                                )
                            }
                            .onEnded { _ in
                                coordinator.endWidgetDrag()
                            }
                    )
                    .help("\(tab.title) — Arraste para reordenar")
                } else {
                    styledNormalTabButton(for: tab, isSelected: isSelected)
                }
            }

            if isEditing && canRemove {
                Button {
                    withAnimation(settings.sizeSpring) {
                        settings.setTabEnabled(tab, enabled: false)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color(red: 1.0, green: 0.28, blue: 0.26))
                }
                .buttonStyle(.plain)
                .offset(x: -4, y: -4)
                .help("Remover \(tab.title)")
            }
        }
        .scaleEffect(isDragging ? 1.08 : 1.0)
        .rotationEffect(.degrees(jiggleDegrees))
        .offset(dragOffset)
    }

    private func styledNormalTabButton(for tab: IslandTab, isSelected: Bool) -> some View {
        let style = settings.layoutPreset.tabPillStyle
        let customButton = settings.buttonAccentColor.color
        let presetAccent = settings.resolvedButtonColor(fallback: settings.layoutPreset.accentColor)
        let showTitle = isSelected && style != .iconOnly

        let pillFill: AnyShapeStyle = {
            if !isSelected {
                return AnyShapeStyle(style == .glass ? Color.white.opacity(0.08) : Color.white.opacity(0.06))
            }
            if let customButton {
                switch style {
                case .glow:
                    return AnyShapeStyle(
                        LinearGradient(
                            colors: [customButton.opacity(0.58), customButton.opacity(0.32)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                case .glass, .dock, .capsule, .iconOnly:
                    return AnyShapeStyle(customButton.opacity(0.26))
                }
            }
            switch style {
            case .glow:
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [presetAccent.opacity(0.55), tab.accentColor.opacity(0.38)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            case .glass:
                return AnyShapeStyle(Color.white.opacity(0.24))
            case .dock:
                return AnyShapeStyle(presetAccent.opacity(0.26))
            case .capsule, .iconOnly:
                return AnyShapeStyle(Color.white.opacity(0.18))
            }
        }()

        let strokeColor: Color = {
            if isSelected, let customButton {
                return customButton.opacity(0.68)
            }
            switch style {
            case .glow:
                return isSelected ? presetAccent.opacity(0.90) : Color.white.opacity(0.08)
            case .glass:
                return isSelected ? Color.white.opacity(0.40) : Color.white.opacity(0.14)
            case .dock:
                return isSelected ? presetAccent.opacity(0.55) : Color.clear
            case .iconOnly, .capsule:
                return Color.clear
            }
        }()

        let cornerRadius: CGFloat = (style == .dock) ? 9 : 13

        return Button {
            coordinator.selectTab(tab)
        } label: {
            HStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.iconName)
                        .font(.system(size: style == .dock ? 11.5 : 11, weight: .semibold))

                    if !isSelected && hasBadge(for: tab) {
                        Circle()
                            .fill(badgeColor(for: tab))
                            .frame(width: 5, height: 5)
                            .offset(x: 3, y: -2)
                    }
                }

                if showTitle {
                    Text(tab.title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(isSelected ? .white : Color.white.opacity(style == .glass ? 0.68 : 0.55))
            .padding(.horizontal, showTitle ? 10 : (style == .iconOnly ? 9 : 8))
            .frame(height: style == .dock ? 26 : 24)
            .background(
                pillFill,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(strokeColor, lineWidth: style == .glow && isSelected ? 1.0 : 0.75)
            )
            .overlay(alignment: .bottom) {
                if style == .iconOnly && isSelected {
                    Circle()
                        .fill(presetAccent)
                        .frame(width: 3.5, height: 3.5)
                        .offset(y: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .help(tab.title)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch coordinator.activeTab {
        case .music:
            MusicExpandedView(music: music, settings: settings)
        case .pomodoro:
            PomodoroExpandedView(pomodoro: pomodoro)
        case .shelf:
            ShelfExpandedView(shelf: shelf)
        case .clipboard:
            ClipboardExpandedView(clipboard: clipboard)
        case .calendar:
            CalendarExpandedView(calendar: calendar)
        case .notes:
            NotesExpandedView(notes: notes, coordinator: coordinator)
        case .audio:
            AudioExpandedView(audio: audio, settings: settings)
        case .system:
            SystemExpandedView(
                battery: battery,
                system: system,
                weather: weather,
                onOpenWeather: { coordinator.openWeather() }
            )
        case .calculator:
            CalculatorExpandedView(extraWidgets: extraWidgets, coordinator: coordinator)
        case .colorPicker:
            ColorPickerExpandedView(extraWidgets: extraWidgets)
        case .stopwatch:
            StopwatchExpandedView(extraWidgets: extraWidgets)
        case .qrCode:
            QRCodeExpandedView(extraWidgets: extraWidgets, coordinator: coordinator)
        case .launcher:
            LauncherExpandedView(extraWidgets: extraWidgets)
        case .network:
            NetworkExpandedView(extraWidgets: extraWidgets, system: system)
        case .caffeine:
            CaffeineExpandedView(extraWidgets: extraWidgets)
        case .screenClean:
            ScreenCleanExpandedView(extraWidgets: extraWidgets)
        case .batteries:
            BatteriesExpandedView(battery: battery, audio: audio)
        case .ambientSound:
            AmbientSoundExpandedView(extraWidgets: extraWidgets)
        case .worldClock:
            WorldClockExpandedView(extraWidgets: extraWidgets)
        }
    }

    private var recordingLiveBanner: some View {
        HStack(spacing: 8) {
            TimelineView(.animation(minimumInterval: 0.1)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let pulse = 0.55 + 0.45 * ((sin(t * 4.5) + 1.0) * 0.5)
                Circle()
                    .fill(Color(red: 1.0, green: 0.26, blue: 0.24).opacity(pulse))
                    .frame(width: 8, height: 8)
            }

            Text(recorder.isStopping ? "Finalizando gravação..." : "Gravando tela • \(recorder.formattedElapsed)")
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)

            Spacer()

            Button {
                recorder.stopRecording()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 8.5, weight: .bold))
                    Text("Parar")
                        .font(.system(size: 10.5, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color(red: 1.0, green: 0.24, blue: 0.22), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(recorder.isStopping)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(red: 1.0, green: 0.24, blue: 0.22).opacity(0.18), in: Capsule())
    }

    private func hasBadge(for tab: IslandTab) -> Bool {
        switch tab {
        case .music:
            return music.isPlaying
        case .pomodoro:
            return pomodoro.isRunning
        case .shelf:
            return !shelf.items.isEmpty
        case .notes:
            return notes.pendingCount > 0
        case .calendar:
            return calendar.nextEvent?.isHappeningNow == true
        case .stopwatch:
            return extraWidgets.hasActiveTimer
        case .caffeine:
            return extraWidgets.isCaffeineActive
        case .ambientSound:
            return extraWidgets.activeAmbientPreset != nil
        case .screenClean:
            return extraWidgets.isCleaningScreen
        default:
            return false
        }
    }

    private func badgeColor(for tab: IslandTab) -> Color {
        switch tab {
        case .music:
            return music.accentColor
        case .pomodoro:
            return pomodoro.phase.accentColor
        case .shelf:
            return Color(red: 0.36, green: 0.76, blue: 1.0)
        case .notes:
            return Color(red: 1.0, green: 0.78, blue: 0.24)
        case .calendar:
            return Color(red: 0.22, green: 0.90, blue: 0.48)
        case .stopwatch, .caffeine, .ambientSound, .screenClean:
            return tab.accentColor
        default:
            return .white
        }
    }
}
