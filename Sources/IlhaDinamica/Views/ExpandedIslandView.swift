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

    var body: some View {
        VStack(spacing: 0) {
            headerRow
                .frame(height: coordinator.geometry.notchHeight + 4)
                .padding(.horizontal, coordinator.geometry.hasNotch ? 24 : 16)
                .padding(.top, coordinator.geometry.hasNotch ? 2 : 8)

            if recorder.isRecording {
                recordingLiveBanner
                    .padding(.horizontal, coordinator.geometry.hasNotch ? 26 : 16)
                    .padding(.top, 5)
            }

            if !coordinator.isMirrorOpen && !coordinator.isWeatherOpen {
                tabBarRow
                    .padding(.horizontal, coordinator.geometry.hasNotch ? 26 : 16)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
            } else {
                Spacer()
                    .frame(height: 10)
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
                } else {
                    tabContent
                }
            }
            .id(activeContentID)
            .transition(.opacity)
            .padding(.horizontal, coordinator.geometry.hasNotch ? 26 : 18)
            .padding(.bottom, 14)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var activeContentID: String {
        if coordinator.isMirrorOpen { return "mirror" }
        if coordinator.isWeatherOpen { return "weather" }
        return coordinator.activeTab.rawValue
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
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
            .frame(maxWidth: .infinity, alignment: .leading)

            if coordinator.geometry.hasNotch {
                Spacer()
                    .frame(width: coordinator.geometry.notchWidth + 14)
            } else {
                Spacer(minLength: 10)
            }

            HStack(spacing: 5) {
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
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(
                            recorder.isRecording
                                ? Color.white
                                : Color(red: 1.0, green: 0.28, blue: 0.26)
                        )
                        .frame(width: 22, height: 22)
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
                    coordinator.toggleMirror()
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(coordinator.isMirrorOpen ? Color(red: 0.36, green: 0.76, blue: 1.0) : Color.white.opacity(0.66))
                        .frame(width: 22, height: 22)
                        .background(
                            coordinator.isMirrorOpen ? Color(red: 0.36, green: 0.76, blue: 1.0).opacity(0.20) : Color.white.opacity(0.07),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .help(coordinator.isMirrorOpen ? "Fechar espelho" : "Espelho rápido (Webcam)")

                Button {
                    coordinator.togglePin()
                } label: {
                    Image(systemName: coordinator.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(coordinator.isPinned ? Color.yellow : Color.white.opacity(0.62))
                        .frame(width: 22, height: 22)
                        .background(
                            coordinator.isPinned ? Color.yellow.opacity(0.18) : Color.white.opacity(0.07),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .help(coordinator.isPinned ? "Desafixar ilha" : "Fixar ilha aberta")

                Button {
                    coordinator.openSettings()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.66))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Preferências")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var tabBarRow: some View {
        HStack(spacing: 5) {
            ForEach(settings.enabledTabs) { tab in
                let isSelected = coordinator.activeTab == tab
                Button {
                    withAnimation(settings.sizeSpring) {
                        coordinator.activeTab = tab
                    }
                } label: {
                    HStack(spacing: 5) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 11, weight: .semibold))

                            if !isSelected && hasBadge(for: tab) {
                                Circle()
                                    .fill(badgeColor(for: tab))
                                    .frame(width: 5, height: 5)
                                    .offset(x: 3, y: -2)
                            }
                        }

                        if isSelected {
                            Text(tab.title)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(isSelected ? .white : Color.white.opacity(0.55))
                    .padding(.horizontal, isSelected ? 10 : 8)
                    .frame(height: 24)
                    .background(
                        isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.06),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .help(tab.title)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch coordinator.activeTab {
        case .music:
            MusicExpandedView(music: music)
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
            AudioExpandedView(audio: audio)
        case .system:
            SystemExpandedView(
                battery: battery,
                system: system,
                weather: weather,
                onOpenWeather: { coordinator.openWeather() }
            )
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
        default:
            return .white
        }
    }
}
