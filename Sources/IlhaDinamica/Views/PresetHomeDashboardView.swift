import AppKit
import SwiftUI

struct PresetHomeDashboardView: View {
    @ObservedObject var coordinator: IslandCoordinator
    @ObservedObject var settings: SettingsStore
    @ObservedObject var music: MusicService
    @ObservedObject var pomodoro: PomodoroService
    @ObservedObject var battery: BatteryService
    @ObservedObject var shelf: ShelfService
    @ObservedObject var calendar: CalendarService
    @ObservedObject var notes: NotesService
    @ObservedObject var audio: AudioControlService
    @ObservedObject var system: SystemMonitorService
    @ObservedObject var weather: WeatherService
    @ObservedObject var recorder: ScreenRecorderService
    @ObservedObject var extraWidgets: ExtraWidgetsService

    var body: some View {
        switch settings.layoutPreset {
        case .superIsland:
            superIslandThreePanelLayout
        case .atoll:
            atollHomeLayout
        case .dynamicLake:
            dynamicLakeHomeLayout
        case .liquidGlass:
            musicAndCalendarLayout
        case .aurora:
            musicAndWeatherLayout
        case .minimalCompact:
            creatorAirDropAndControlsLayout
        case .dashboardDock:
            centralProThreeColumnLayout
        case .titaniumGold:
            focusAndAgendaLayout
        case .obsidian:
            MusicExpandedView(music: music, settings: settings)
        }
    }

    // MARK: - 1. Glass Studio (.liquidGlass — Mix DynamicLake + Atoll)

    private var musicAndCalendarLayout: some View {
        let customBtn = settings.buttonAccentColor.color
        let buttonTint = settings.resolvedButtonColor(fallback: Color.white.opacity(0.92))
        let buttonFg = customBtn != nil
            ? settings.resolvedButtonForeground(fallback: .black)
            : Color.black
        let sliderTint = settings.resolvedSliderColor(
            fallback: music.hasTrack ? music.accentColor : settings.layoutPreset.accentColor
        )
        let todayTint = settings.resolvedButtonColor(fallback: Color(red: 0.30, green: 0.64, blue: 1.0))
        let todayFg = settings.resolvedButtonForeground(fallback: .white)
        let displayedElapsed = music.isScrubbing ? music.scrubSeconds : music.elapsedTime

        return HStack(alignment: .top, spacing: 14) {
            GeometryReader { geo in
                let artSize = max(74, min(92, geo.size.height - 76))

                VStack(alignment: .leading, spacing: 0) {
                    if !music.hasTrack {
                        compactStandbyMusicView(
                            iconSize: 64,
                            buttonTint: customBtn ?? Color.white.opacity(0.16),
                            buttonFg: customBtn != nil ? buttonFg : .white,
                            title: "Glass Studio",
                            subtitle: "Toque algo para controlar aqui"
                        )
                    } else {
                        HStack(alignment: .center, spacing: 11) {
                            glowingArtworkButton(
                                size: artSize,
                                cornerRadius: max(14, artSize * 0.17),
                                glowTint: sliderTint,
                                pauseScale: 0.92,
                                showAppBadge: true
                            )

                            VStack(alignment: .leading, spacing: 2.5) {
                                HStack(spacing: 6) {
                                    Text(music.title)
                                        .font(.system(size: 14.5, weight: .bold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)

                                    Spacer(minLength: 4)

                                    AudioVisualizerView(
                                        isPlaying: music.isPlaying,
                                        accentColor: settings.sliderAccentColor == .presetDefault ? .white : sliderTint,
                                        barCount: 5,
                                        barWidth: 2.2,
                                        maxHeight: 16,
                                        spacing: 2
                                    )
                                }

                                Text(music.artist.isEmpty ? music.player.displayName : music.artist)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.84))
                                    .lineLimit(1)

                                Text(music.player.displayName)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(sliderTint)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(sliderTint.opacity(0.16), in: Capsule())
                            }
                        }

                        Spacer(minLength: 6)

                        capsuleScrubBar(
                            tint: sliderTint,
                            trackHeight: 5.5,
                            trackColor: Color.white.opacity(0.20),
                            showKnob: false,
                            showTimestamps: true
                        )

                        Spacer(minLength: 6)

                        HStack(spacing: 14) {
                            Spacer(minLength: 0)
                            smallCircleAction("gobackward.10", helpText: "Voltar 10s") {
                                guard music.duration > 0 else { return }
                                music.seek(to: max(0, displayedElapsed - 10))
                            }
                            smallCircleAction("backward.fill", helpText: "Anterior") {
                                music.previousTrack()
                            }
                            Button {
                                music.togglePlayPause()
                            } label: {
                                Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundStyle(buttonFg)
                                    .offset(x: music.isPlaying ? 0 : 1)
                                    .frame(width: 32, height: 32)
                                    .background(buttonTint, in: Circle())
                                    .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
                            }
                            .buttonStyle(.plain)
                            smallCircleAction("forward.fill", helpText: "Próxima") {
                                music.nextTrack()
                            }
                            smallCircleAction("airplayaudio", helpText: "Saída de áudio") {
                                coordinator.selectTab(.audio)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
            .frame(width: 298)
            .frame(maxHeight: .infinity)

            hairlineDivider(color: Color.white.opacity(0.14))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 6) {
                    Button {
                        coordinator.selectTab(.calendar)
                    } label: {
                        VStack(alignment: .leading, spacing: 0.5) {
                            Text(atollMonthLabel(extraWidgets.now))
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(.white)
                            Text(atollYearLabel(extraWidgets.now))
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.58))
                        }
                        .frame(width: 34, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    miniFiveDayStrip(
                        todayTint: todayTint,
                        todayForeground: todayFg,
                        fadeColor: Color.black.opacity(0.22)
                    )
                }

                atollCalendarEventsList(
                    maxTimed: 3,
                    buttonTint: todayTint,
                    buttonFg: todayFg,
                    rowFill: Color.white.opacity(0.08)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 2)
    }

    // MARK: - 2. Aurora Pulse (.aurora — Palco Neon + Relógio & Clima)

    private var musicAndWeatherLayout: some View {
        let presetAccent = settings.layoutPreset.accentColor
        let sliderTint = settings.resolvedSliderColor(fallback: presetAccent)
        let customBtn = settings.buttonAccentColor.color
        let buttonTint = settings.resolvedButtonColor(fallback: presetAccent)
        let buttonFg = settings.resolvedButtonForeground(fallback: .white)

        return HStack(alignment: .top, spacing: 14) {
            GeometryReader { geo in
                let artSize = max(72, min(86, geo.size.height - 68))

                VStack(alignment: .leading, spacing: 0) {
                    if !music.hasTrack {
                        compactStandbyMusicView(
                            iconSize: 64,
                            buttonTint: buttonTint,
                            buttonFg: buttonFg,
                            title: "Aurora Pulse",
                            subtitle: "Inicie sua música favorita"
                        )
                    } else {
                        HStack(alignment: .center, spacing: 11) {
                            glowingArtworkButton(
                                size: artSize,
                                cornerRadius: max(13, artSize * 0.16),
                                glowTint: sliderTint,
                                pauseScale: 0.94,
                                showAppBadge: true
                            )

                            VStack(alignment: .leading, spacing: 2.5) {
                                HStack(spacing: 6) {
                                    Text(music.title)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)

                                    Spacer(minLength: 4)

                                    AudioVisualizerView(
                                        isPlaying: music.isPlaying,
                                        accentColor: sliderTint,
                                        barCount: 4,
                                        barWidth: 2.2,
                                        maxHeight: 15,
                                        spacing: 2
                                    )
                                }

                                Text(music.artist.isEmpty ? music.player.displayName : music.artist)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(sliderTint)
                                    .lineLimit(1)

                                Text(music.album.isEmpty ? music.player.displayName : music.album)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.50))
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 6)

                        capsuleScrubBar(
                            tint: sliderTint,
                            trackHeight: 5,
                            trackColor: Color.white.opacity(0.14),
                            showKnob: true,
                            showTimestamps: true
                        )

                        Spacer(minLength: 6)

                        HStack(spacing: 20) {
                            Spacer(minLength: 0)
                            smallCircleAction("backward.fill", helpText: "Anterior") {
                                music.previousTrack()
                            }
                            Button {
                                music.togglePlayPause()
                            } label: {
                                Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(buttonFg)
                                    .offset(x: music.isPlaying ? 0 : 1)
                                    .frame(width: 30, height: 30)
                                    .background(
                                        customBtn != nil
                                            ? AnyShapeStyle(buttonTint)
                                            : AnyShapeStyle(
                                                LinearGradient(
                                                    colors: [presetAccent, Color(red: 0.24, green: 0.86, blue: 1.0)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            ),
                                        in: Circle()
                                    )
                                    .shadow(color: buttonTint.opacity(0.42), radius: 6, y: 2)
                            }
                            .buttonStyle(.plain)
                            smallCircleAction("forward.fill", helpText: "Próxima") {
                                music.nextTrack()
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
            .frame(width: 288)
            .frame(maxHeight: .infinity)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [sliderTint.opacity(0.48), Color.white.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1)
                .padding(.vertical, 4)

            Button {
                coordinator.openWeather()
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(formattedClockTime)
                                .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.white)
                            Text(formattedWeekdayAndMonth)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(sliderTint)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Image(systemName: weather.symbolName)
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.28))
                            Text(weather.temperatureCelsius.map { String(format: "%.0f°", $0) } ?? "--°")
                                .font(.system(size: 19, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 1.5) {
                        Text(weather.cityName.isEmpty ? "Previsão local" : weather.cityName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(weather.conditionText)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.62))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        if let maxT = weather.todayMaxCelsius, let minT = weather.todayMinCelsius {
                            weatherPill(
                                icon: "thermometer.medium",
                                value: String(format: "%.0f°/%.0f°", minT, maxT),
                                tint: sliderTint
                            )
                        }
                        weatherPill(
                            icon: "drop.fill",
                            value: weather.humidityPercent.map { "\($0)%" } ?? "--",
                            tint: Color(red: 0.36, green: 0.76, blue: 1.0)
                        )
                        weatherPill(
                            icon: "wind",
                            value: weather.windKmh.map { String(format: "%.0f", $0) } ?? "--",
                            tint: Color.white.opacity(0.84)
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .buttonStyle(.plain)
            .help("Abrir previsão completa")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 2)
    }

    // MARK: - 3. Creator Deck (.minimalCompact — 3 Painéis Pro Hairline)

    private var creatorAirDropAndControlsLayout: some View {
        let buttonTint = settings.resolvedButtonColor(fallback: Color(red: 0.28, green: 0.74, blue: 1.0))
        let buttonFg = settings.resolvedButtonForeground(fallback: .white)
        let sliderTint = settings.resolvedSliderColor(fallback: Color(red: 0.28, green: 0.88, blue: 0.56))
        let targeted = shelf.isAirDropDropTargeted

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(buttonTint)
                        Text("AirDrop")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button("Finder") {
                        shelf.openAirDropWindow()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.08), in: Capsule())
                }

                Button {
                    if shelf.items.isEmpty {
                        shelf.pickFilesForAirDrop()
                    } else {
                        shelf.sendAllViaAirDrop()
                    }
                } label: {
                    HStack(spacing: 9) {
                        ZStack {
                            Circle()
                                .fill(buttonTint.opacity(targeted ? 0.36 : 0.18))
                                .frame(width: 34, height: 34)
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(targeted ? .white : buttonTint)
                        }

                        VStack(alignment: .leading, spacing: 1.5) {
                            Text(targeted ? "Solte para enviar" : (shelf.items.isEmpty ? "Enviar arquivos" : "Enviar (\(shelf.items.count))"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("Arraste aqui ou clique")
                                .font(.system(size: 9.5))
                                .foregroundStyle(Color.white.opacity(0.55))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(7)
                    .background(
                        buttonTint.opacity(targeted ? 0.24 : 0.10),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(targeted ? buttonTint : buttonTint.opacity(0.30), lineWidth: targeted ? 1.3 : 0.8)
                    )
                }
                .buttonStyle(.plain)
                .onDrop(of: [.fileURL], isTargeted: $shelf.isAirDropDropTargeted) { providers in
                    shelf.handleAirDropDrop(providers: providers)
                }

                if !shelf.items.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(Array(shelf.items.prefix(2))) { item in
                            Button {
                                shelf.sendItemViaAirDrop(item)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(nsImage: shelf.fallbackIcon(for: item.url))
                                        .resizable()
                                        .frame(width: 14, height: 14)
                                    Text(item.name)
                                        .font(.system(size: 9.5, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.88))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3.5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(width: 196, alignment: .topLeading)

            hairlineDivider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: audio.defaultOutputIconName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(sliderTint)
                    Text(audio.defaultOutputName)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        audio.toggleMicMute()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: audio.isMicMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(audio.isMicMuted ? "Mudo" : "Mic")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(audio.isMicMuted ? .white : Color.white.opacity(0.82))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            audio.isMicMuted ? Color.red.opacity(0.85) : Color.white.opacity(0.08),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }

                quickCapsuleSlider(
                    icon: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    label: "Volume",
                    value: audio.isMuted ? 0 : Double(audio.volume),
                    tint: audio.isMuted ? .red : sliderTint,
                    onIconTap: { audio.toggleMute() }
                ) { ratio in
                    audio.setVolume(Float(ratio))
                }

                quickCapsuleSlider(
                    icon: "sun.max.fill",
                    label: "Brilho",
                    value: Double(audio.brightness),
                    tint: settings.resolvedSliderColor(fallback: Color(red: 1.0, green: 0.78, blue: 0.24)),
                    onIconTap: nil
                ) { ratio in
                    audio.setBrightness(Float(max(0.02, ratio)))
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            hairlineDivider()

            VStack(alignment: .leading, spacing: 7) {
                Button {
                    if recorder.isRecording {
                        recorder.stopRecording()
                    } else {
                        recorder.startFullScreenRecording()
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: recorder.isRecording ? "stop.circle.fill" : "record.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(recorder.isRecording ? .white : (settings.buttonAccentColor == .presetDefault ? Color(red: 1.0, green: 0.30, blue: 0.28) : buttonFg))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(recorder.isRecording ? "Parar Rec" : "Gravar Tela")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(recorder.isRecording ? .white : (settings.buttonAccentColor == .presetDefault ? .white : buttonFg))
                            Text(recorder.isRecording ? recorder.formattedElapsed : "Tela cheia")
                                .font(.system(size: 9, design: .rounded).monospacedDigit())
                                .foregroundStyle((recorder.isRecording || settings.buttonAccentColor == .presetDefault) ? Color.white.opacity(0.75) : buttonFg.opacity(0.78))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 44)
                    .background(
                        recorder.isRecording
                            ? Color.red
                            : (settings.buttonAccentColor == .presetDefault ? Color(red: 1.0, green: 0.28, blue: 0.26).opacity(0.22) : buttonTint),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    extraWidgets.toggleCaffeine()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(extraWidgets.isCaffeineActive ? "Cafeína ON" : "Cafeína")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .foregroundStyle(extraWidgets.isCaffeineActive ? buttonFg : .white.opacity(0.84))
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(
                        extraWidgets.isCaffeineActive
                            ? (settings.buttonAccentColor == .presetDefault ? IslandTab.caffeine.accentColor : buttonTint)
                            : Color.white.opacity(0.08),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)

                HStack(spacing: 5) {
                    statMiniPill(label: "CPU", value: "\(Int(system.cpuUsagePercent.rounded()))%", tint: sliderTint)
                    statMiniPill(label: "BAT", value: "\(battery.percentage)%", tint: Color(red: 0.22, green: 0.90, blue: 0.48))
                }
                Spacer(minLength: 0)
            }
            .frame(width: 146, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 2)
    }

    // MARK: - 4. Central Pro (.dashboardDock — 3 Colunas Editoriais + Dock Inferior)

    private var centralProThreeColumnLayout: some View {
        let sliderTint = settings.resolvedSliderColor(
            fallback: music.hasTrack ? music.accentColor : settings.layoutPreset.accentColor
        )
        let customBtn = settings.buttonAccentColor.color
        let buttonTint = settings.resolvedButtonColor(fallback: Color.white)
        let buttonFg = customBtn != nil ? settings.resolvedButtonForeground(fallback: .black) : Color.black
        let pomoRingTint = settings.resolvedSliderColor(fallback: pomodoro.phase.accentColor)
        let pomoBtnTint = settings.resolvedButtonColor(fallback: pomodoro.phase.accentColor)
        let pomoBtnFg = customBtn != nil ? buttonFg : Color.black
        let pending = Array(notes.todos.filter { !$0.isDone }.prefix(3))

        return HStack(alignment: .top, spacing: 11) {
            VStack(alignment: .leading, spacing: 0) {
                if !music.hasTrack {
                    compactStandbyMusicView(
                        iconSize: 48,
                        buttonTint: customBtn ?? settings.layoutPreset.accentColor,
                        buttonFg: customBtn != nil ? buttonFg : .white,
                        title: "Música",
                        subtitle: "Nada tocando"
                    )
                } else {
                    HStack(spacing: 8) {
                        glowingArtworkButton(
                            size: 58,
                            cornerRadius: 11,
                            glowTint: sliderTint,
                            pauseScale: 0.92,
                            showAppBadge: false
                        )

                        VStack(alignment: .leading, spacing: 1.5) {
                            Text(music.title)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(music.artist.isEmpty ? music.player.displayName : music.artist)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(sliderTint)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 2)
                        AudioVisualizerView(
                            isPlaying: music.isPlaying,
                            accentColor: sliderTint,
                            barCount: 3,
                            barWidth: 2,
                            maxHeight: 12,
                            spacing: 1.6
                        )
                    }

                    Spacer(minLength: 6)

                    capsuleScrubBar(
                        tint: sliderTint,
                        trackHeight: 4.5,
                        trackColor: Color.white.opacity(0.16),
                        showKnob: false,
                        showTimestamps: true
                    )

                    Spacer(minLength: 6)

                    HStack(spacing: 14) {
                        Spacer(minLength: 0)
                        smallCircleAction("backward.fill", size: 24, iconSize: 11, helpText: "Anterior") {
                            music.previousTrack()
                        }
                        Button {
                            music.togglePlayPause()
                        } label: {
                            Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(buttonFg)
                                .offset(x: music.isPlaying ? 0 : 1)
                                .frame(width: 30, height: 30)
                                .background(buttonTint, in: Circle())
                        }
                        .buttonStyle(.plain)
                        smallCircleAction("forward.fill", size: 24, iconSize: 11, helpText: "Próxima") {
                            music.nextTrack()
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            hairlineDivider()

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 3.5)
                        Circle()
                            .trim(from: 0, to: pomodoro.progress)
                            .stroke(pomoRingTint, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: pomodoro.phase.iconName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(pomoRingTint)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(pomodoro.formattedRemaining)
                            .font(.system(size: 15.5, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                        Text(pomodoro.phase.shortTitle.uppercased())
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(pomoRingTint)
                    }

                    Spacer()

                    Button {
                        pomodoro.toggle()
                    } label: {
                        Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(pomoBtnFg)
                            .frame(width: 24, height: 24)
                            .background(pomoBtnTint, in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    Text("TAREFAS (\(notes.pendingCount))")
                        .font(.system(size: 8.5, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.white.opacity(0.48))
                    Spacer()
                    Button {
                        coordinator.selectTab(.notes)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(pomoBtnTint)
                    }
                    .buttonStyle(.plain)
                }

                if pending.isEmpty {
                    Text("Tudo concluído!")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.46))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    VStack(spacing: 4) {
                        ForEach(pending) { item in
                            Button {
                                notes.toggle(item)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(pomoBtnTint)
                                    Text(item.title)
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(width: 192, alignment: .topLeading)

            hairlineDivider()

            VStack(alignment: .leading, spacing: 7) {
                Button {
                    coordinator.openWeather()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: weather.symbolName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.28))
                        VStack(alignment: .leading, spacing: 0.5) {
                            Text(weather.temperatureCelsius.map { String(format: "%.0f°", $0) } ?? "--°")
                                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.white)
                            Text(weather.cityName.isEmpty ? weather.conditionText : weather.cityName)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.58))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)

                miniCapsuleMeterRow(label: "CPU", ratio: max(0, min(1, system.cpuUsagePercent / 100.0)), valueText: "\(Int(system.cpuUsagePercent.rounded()))%", tint: sliderTint)
                miniCapsuleMeterRow(label: "BAT", ratio: max(0, min(1, Double(battery.percentage) / 100.0)), valueText: "\(battery.percentage)%", tint: settings.resolvedSliderColor(fallback: Color(red: 0.22, green: 0.90, blue: 0.48)))

                Spacer(minLength: 0)

                HStack(spacing: 5) {
                    Button {
                        if shelf.items.isEmpty {
                            shelf.pickFilesForAirDrop()
                        } else {
                            shelf.sendAllViaAirDrop()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 9.5, weight: .bold))
                            Text(shelf.items.isEmpty ? "AirDrop" : "Enviar")
                                .font(.system(size: 9.5, weight: .bold))
                        }
                        .foregroundStyle(buttonFg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 25)
                        .background(
                            customBtn != nil ? buttonTint : Color(red: 0.24, green: 0.66, blue: 1.0),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        extraWidgets.toggleCaffeine()
                    } label: {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(extraWidgets.isCaffeineActive ? buttonFg : .white.opacity(0.84))
                            .frame(width: 28, height: 25)
                            .background(
                                extraWidgets.isCaffeineActive
                                    ? (customBtn ?? IslandTab.caffeine.accentColor)
                                    : Color.white.opacity(0.08),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Cafeína")
                }
            }
            .frame(width: 162, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 2)
    }

    // MARK: - 5. Zen Titanium (.titaniumGold — Pomodoro + Som Ambiente + Fita de 5 Dias & Tarefas)

    private var focusAndAgendaLayout: some View {
        let presetAccent = settings.layoutPreset.accentColor
        let sliderTint = settings.resolvedSliderColor(fallback: presetAccent)
        let customBtn = settings.buttonAccentColor.color
        let buttonTint = settings.resolvedButtonColor(fallback: presetAccent)
        let buttonFg = settings.resolvedButtonForeground(fallback: .black)
        let pending = Array(notes.todos.filter { !$0.isDone }.prefix(2))

        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.11), lineWidth: 5.5)
                    Circle()
                        .trim(from: 0, to: pomodoro.progress)
                        .stroke(
                            sliderTint,
                            style: StrokeStyle(lineWidth: 5.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text(pomodoro.formattedRemaining)
                            .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                        Text(pomodoro.phase.shortTitle.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(sliderTint)
                    }
                }
                .frame(width: 72, height: 72)

                HStack(spacing: 6) {
                    Button {
                        pomodoro.toggle()
                    } label: {
                        Label(
                            pomodoro.isRunning ? "Pausar" : "Focar",
                            systemImage: pomodoro.isRunning ? "pause.fill" : "play.fill"
                        )
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(buttonFg)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(buttonTint, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        pomodoro.addOneMinute()
                    } label: {
                        Text("+1m")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(Color.white.opacity(0.09), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 5) {
                    zenAmbientButton(.rain, label: "Chuva", activeTint: sliderTint)
                    zenAmbientButton(.brownNoise, label: "Foco", activeTint: sliderTint)
                }
            }
            .frame(width: 214, alignment: .center)

            hairlineDivider(color: (customBtn ?? presetAccent).opacity(0.24))

            VStack(alignment: .leading, spacing: 7) {
                miniFiveDayStrip(
                    todayTint: buttonTint,
                    todayForeground: buttonFg,
                    fadeColor: Color.black.opacity(0.20)
                )

                if let next = calendar.nextEvent {
                    HStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(next.accentColor)
                            .frame(width: 3, height: 18)
                        Text(next.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        Text(eventTimeLabel(next))
                            .font(.system(size: 9.5, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color.white.opacity(0.60))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(sliderTint)
                        Text("Agenda livre • \(formattedClockTime)")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.76))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if pending.isEmpty {
                    Button {
                        coordinator.selectTab(.notes)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checklist")
                                .font(.system(size: 10.5))
                                .foregroundStyle(buttonTint)
                            Text("Nenhuma tarefa pendente • Abrir Notas")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color.white.opacity(0.56))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(spacing: 4) {
                        ForEach(pending) { item in
                            Button {
                                notes.toggle(item)
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 11))
                                        .foregroundStyle(buttonTint)
                                    Text(item.title)
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4.5)
                                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 2)
    }

    private func zenAmbientButton(_ preset: AmbientPreset, label: String, activeTint: Color) -> some View {
        let isActive = extraWidgets.activeAmbientPreset == preset
        return Button {
            extraWidgets.toggleAmbientPreset(preset)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: preset.iconName)
                    .font(.system(size: 9.5, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(isActive ? .black : Color.white.opacity(0.76))
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background(
                isActive ? activeTint : Color.white.opacity(0.075),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .help("Som ambiente: \(preset.title)")
    }

    // MARK: - 6. SuperIsland 3-Panel Editorial Layout

    private var superIslandThreePanelLayout: some View {
        HStack(alignment: .top, spacing: 14) {
            superIslandNowPlayingPanel
                .frame(width: 222, alignment: .topLeading)

            hairlineDivider(color: Color.white.opacity(0.08))

            superIslandCalendarPanel
                .frame(maxWidth: .infinity, alignment: .topLeading)

            hairlineDivider(color: Color.white.opacity(0.08))

            superIslandWeatherPanel
                .frame(width: 148, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 2)
    }

    private var superIslandNowPlayingPanel: some View {
        let displayedElapsed = music.isScrubbing ? music.scrubSeconds : music.elapsedTime
        let progress = music.duration > 0 ? max(0, min(1, displayedElapsed / music.duration)) : 0
        let sliderTint = settings.resolvedSliderColor(fallback: Color.white.opacity(0.88))

        return GeometryReader { panelGeo in
            let artSize = max(72, min(84, panelGeo.size.height - 82))

            VStack(alignment: .leading, spacing: 0) {
                if !music.hasTrack {
                    VStack(spacing: 8) {
                        superIslandEmptyState(
                            icon: "music.note.house",
                            title: "Nada tocando",
                            subtitle: "Inicie no Spotify ou Apple Music"
                        )
                        HStack(spacing: 6) {
                            Spacer()
                            if music.isAppInstalled("com.spotify.client") {
                                Button("Spotify") { music.openPlayer(.spotify) }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.08), in: Capsule())
                            }
                            if music.isAppInstalled("com.apple.Music") {
                                Button("Música") { music.openPlayer(.appleMusic) }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.08), in: Capsule())
                            }
                            Spacer()
                        }
                        .padding(.bottom, 4)
                    }
                    .frame(width: panelGeo.size.width, height: panelGeo.size.height, alignment: .center)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(music.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.88))
                            .lineLimit(1)

                        Text(superIslandTrackSecondaryLine)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.58))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    HStack(alignment: .center, spacing: 14) {
                        Button {
                            music.openActivePlayer()
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                if let artwork = music.artwork {
                                    Image(nsImage: artwork)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: artSize, height: artSize)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(0.10), lineWidth: 0.75)
                                        )
                                } else {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: artSize, height: artSize)
                                        .overlay(
                                            Image(systemName: "music.note")
                                                .font(.system(size: max(20, artSize * 0.28), weight: .medium))
                                                .foregroundStyle(Color.white.opacity(0.65))
                                        )
                                }

                                if let bundleID = music.player.bundleIdentifier,
                                   let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                                        .resizable()
                                        .interpolation(.high)
                                        .frame(width: 18, height: 18)
                                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(Color.black.opacity(0.9))
                                        )
                                        .offset(x: 4, y: 4)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 9) {
                            superIslandTransportButton("backward.fill", isPrimary: false) {
                                music.previousTrack()
                            }
                            superIslandTransportButton(music.isPlaying ? "pause.fill" : "play.fill", isPrimary: true) {
                                music.togglePlayPause()
                            }
                            superIslandTransportButton("forward.fill", isPrimary: false) {
                                music.nextTrack()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Spacer(minLength: 4)

                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geo in
                            let w = max(1, geo.size.width)
                            ZStack(alignment: .leading) {
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.14))
                                    .frame(height: 3)
                                Capsule(style: .continuous)
                                    .fill(sliderTint)
                                    .frame(width: w * CGFloat(progress), height: 3)
                                Circle()
                                    .fill(settings.sliderAccentColor == .presetDefault ? Color.white : sliderTint)
                                    .frame(width: 7.5, height: 7.5)
                                    .offset(x: max(0, min(w - 7.5, w * CGFloat(progress) - 3.75)))
                            }
                            .frame(height: 12)
                            .contentShape(Rectangle())
                            .gesture(scrubDragGesture(width: w))
                        }
                        .frame(height: 12)

                        HStack {
                            Text(formatTrackTime(displayedElapsed))
                            Spacer(minLength: 8)
                            Text(formatTrackTime(music.duration))
                        }
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.36))
                        .lineLimit(1)
                    }
                    .padding(.horizontal, 4)
                }
            }
            .frame(width: panelGeo.size.width, height: panelGeo.size.height, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity)
    }

    private func superIslandTransportButton(_ symbol: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        let customBtn = isPrimary ? settings.buttonAccentColor.color : nil
        return Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: isPrimary ? 13 : 11.5, weight: .semibold))
                .foregroundStyle(customBtn != nil ? settings.resolvedButtonForeground(fallback: .white) : .white.opacity(0.92))
                .frame(width: isPrimary ? 32 : 26, height: isPrimary ? 32 : 26)
                .background(
                    Circle()
                        .fill(customBtn ?? Color.white.opacity(isPrimary ? 0.12 : 0.07))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isPrimary ? 0.10 : 0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var superIslandTrackSecondaryLine: String {
        let artist = music.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let album = music.album.trimmingCharacters(in: .whitespacesAndNewlines)
        if !artist.isEmpty && !album.isEmpty {
            return "\(artist) • \(album)"
        }
        if !artist.isEmpty { return artist }
        if !album.isEmpty { return album }
        return "Mídia"
    }

    private var superIslandCalendarPanel: some View {
        let upcoming = Array(calendar.events.prefix(3))
        let subtitle: String = {
            if !calendar.hasCalendarAccess { return "Permita o acesso nas preferências" }
            if upcoming.isEmpty { return "Nenhum evento agendado hoje" }
            return upcoming.count == 1 ? "1 próximo evento" : "\(upcoming.count) próximos eventos"
        }()

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                coordinator.selectTab(.calendar)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedWeekdayAndMonth)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            if !calendar.hasCalendarAccess {
                Spacer(minLength: 0)
                Button("Permitir Acesso") {
                    calendar.requestAccess()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.10), in: Capsule())
                Spacer(minLength: 0)
            } else if upcoming.isEmpty {
                superIslandEmptyState(
                    icon: "calendar",
                    title: "Nada por agora",
                    subtitle: "Sua agenda está livre no momento."
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(upcoming) { event in
                        HStack(alignment: .top, spacing: 9) {
                            Circle()
                                .fill(event.accentColor)
                                .frame(width: 8, height: 8)
                                .padding(.top, 5)

                            VStack(alignment: .leading, spacing: 2.5) {
                                Text(event.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.68))
                                    .lineLimit(1)

                                HStack(spacing: 6) {
                                    Text(eventTimeLabel(event))
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.54))
                                        .lineLimit(1)

                                    if event.isHappeningNow || event.minutesUntilStart <= 60 {
                                        Text(event.isHappeningNow ? "Agora" : "em \(max(1, event.minutesUntilStart))m")
                                            .font(.system(size: 9.5, weight: .semibold))
                                            .foregroundStyle(Color.white.opacity(0.90))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1.5)
                                            .background(Capsule(style: .continuous).fill(Color.white.opacity(0.08)))
                                    }
                                }
                            }

                            Spacer(minLength: 0)

                            if let url = event.meetingURL {
                                Button {
                                    NSWorkspace.shared.open(url)
                                } label: {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 10.5, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.92))
                                        .frame(width: 26, height: 26)
                                        .background(
                                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                .fill(Color.white.opacity(0.06))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var superIslandWeatherPanel: some View {
        Button {
            coordinator.openWeather()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 9) {
                    Image(systemName: weather.symbolName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.06)))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(weather.temperatureCelsius.map { String(format: "%.0f°", $0) } ?? "--°")
                            .font(.system(size: 24, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color.white.opacity(0.88))
                        Text(weather.conditionText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.58))
                            .lineLimit(1)
                    }
                }

                Text(weather.cityName.isEmpty ? "Clima local" : weather.cityName)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.58))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.orange.opacity(0.88))
                            Text("Máx")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.36))
                        }
                        Text(weather.todayMaxCelsius.map { String(format: "%.0f°", $0) } ?? "--")
                            .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color.white.opacity(0.62))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.cyan.opacity(0.88))
                            Text("Mín")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.36))
                        }
                        Text(weather.todayMinCelsius.map { String(format: "%.0f°", $0) } ?? "--")
                            .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color.white.opacity(0.62))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .help("Abrir previsão completa")
    }

    private func superIslandEmptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.36))
                .padding(.bottom, 2)
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.84))
            Text(subtitle)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - 7. Atoll NotchHomeView Layout

    private var atollAccentBlue: Color {
        Color(red: 0.30, green: 0.64, blue: 1.0)
    }

    private var atollHomeLayout: some View {
        HStack(alignment: .center, spacing: 18) {
            atollMusicPlayerColumn
                .frame(width: 326, alignment: .topLeading)

            atollCalendarColumn
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.top, 2)
    }

    private var atollMusicPlayerColumn: some View {
        let displayedElapsed = music.isScrubbing ? music.scrubSeconds : music.elapsedTime
        let baseTint = music.hasTrack ? music.accentColor : atollAccentBlue
        let sliderTint = settings.resolvedSliderColor(fallback: baseTint)
        let customBtn = settings.buttonAccentColor.color
        let buttonBg = customBtn ?? Color.white.opacity(0.08)
        let buttonFg = customBtn != nil ? settings.resolvedButtonForeground(fallback: .white) : Color.white

        return GeometryReader { geo in
            let artSize = max(92, min(116, geo.size.height - 12))
            let corner = max(13, artSize * 0.13)

            Group {
                if !music.hasTrack {
                    HStack(alignment: .center, spacing: 13) {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                            .frame(width: artSize, height: artSize)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: max(22, artSize * 0.24), weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.45))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: corner, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.75)
                            )

                        VStack(alignment: .leading, spacing: 7) {
                            Text("Nada tocando")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text("Inicie uma faixa no Spotify ou Apple Music")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.50))
                                .lineLimit(2)

                            HStack(spacing: 6) {
                                if music.isAppInstalled("com.spotify.client") {
                                    Button("Spotify") {
                                        music.openPlayer(.spotify)
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.10), in: Capsule())
                                }
                                if music.isAppInstalled("com.apple.Music") {
                                    Button("Música") {
                                        music.openPlayer(.appleMusic)
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.10), in: Capsule())
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    HStack(alignment: .center, spacing: 13) {
                        glowingArtworkButton(
                            size: artSize,
                            cornerRadius: corner,
                            glowTint: sliderTint,
                            pauseScale: 0.90,
                            showAppBadge: true
                        )

                        VStack(alignment: .leading, spacing: 0) {
                            VStack(alignment: .leading, spacing: 1.5) {
                                Text(music.title)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                Text(music.artist.isEmpty ? music.player.displayName : music.artist)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(sliderTint)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 4)

                            capsuleScrubBar(
                                tint: sliderTint,
                                trackHeight: 6,
                                trackColor: Color.white.opacity(0.18),
                                showKnob: false,
                                showTimestamps: true
                            )

                            Spacer(minLength: 4)

                            HStack(spacing: 12) {
                                Spacer(minLength: 0)

                                smallCircleAction("gobackward.10", size: 24, iconSize: 11.5, helpText: "Voltar 10 segundos") {
                                    guard music.duration > 0 else { return }
                                    music.seek(to: max(0, displayedElapsed - 10))
                                }
                                smallCircleAction("backward.fill", size: 26, iconSize: 13.5, helpText: "Anterior") {
                                    music.previousTrack()
                                }

                                Button {
                                    music.togglePlayPause()
                                } label: {
                                    Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(buttonFg)
                                        .offset(x: music.isPlaying ? 0 : 1)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(buttonBg))
                                }
                                .buttonStyle(.plain)

                                smallCircleAction("forward.fill", size: 26, iconSize: 13.5, helpText: "Próxima") {
                                    music.nextTrack()
                                }
                                smallCircleAction("airplayaudio", size: 24, iconSize: 11.5, helpText: "Saída de áudio") {
                                    coordinator.selectTab(.audio)
                                }

                                Spacer(minLength: 0)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: artSize)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .frame(maxHeight: .infinity)
    }

    private var atollCalendarColumn: some View {
        let now = extraWidgets.now
        let todayTint = settings.resolvedButtonColor(fallback: atollAccentBlue)
        let todayFg = settings.resolvedButtonForeground(fallback: .white)

        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 8) {
                Button {
                    coordinator.selectTab(.calendar)
                } label: {
                    VStack(alignment: .leading, spacing: 0.5) {
                        Text(atollMonthLabel(now))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(atollYearLabel(now))
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    .frame(width: 36, alignment: .leading)
                }
                .buttonStyle(.plain)
                .help("Abrir agenda completa")

                miniFiveDayStrip(
                    todayTint: todayTint,
                    todayForeground: todayFg,
                    fadeColor: Color.black.opacity(0.55)
                )
            }

            atollCalendarEventsList(
                maxTimed: 3,
                buttonTint: todayTint,
                buttonFg: todayFg,
                rowFill: Color.white.opacity(0.08)
            )
        }
    }

    // MARK: - 8. DynamicLake Liquid Glass Layout (DynaMusic + DynaGlance)

    private var dynamicLakeHomeLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            dynamicLakeMediaSection

            Spacer(minLength: 6)

            dynamicLakeGlanceBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 2)
    }

    private var dynamicLakeMediaSection: some View {
        let displayedElapsed = music.isScrubbing ? music.scrubSeconds : music.elapsedTime
        let progress = music.duration > 0 ? max(0, min(1, displayedElapsed / music.duration)) : 0
        let sliderTint = settings.resolvedSliderColor(fallback: Color.white.opacity(0.92))
        let vizTint = settings.resolvedSliderColor(fallback: .white)
        let customBtn = settings.buttonAccentColor.color

        return GeometryReader { sectionGeo in
            let artSize = max(60, min(74, sectionGeo.size.height - 78))
            let corner = max(14, artSize * 0.22)

            Group {
                if !music.hasTrack {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                            .frame(width: artSize, height: artSize)
                            .overlay(
                                RoundedRectangle(cornerRadius: corner, style: .continuous)
                                    .stroke(Color.white.opacity(0.30), lineWidth: 0.85)
                            )
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: max(20, artSize * 0.34), weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.92))
                            )
                            .shadow(color: Color.black.opacity(0.25), radius: 6, y: 3)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("DynamicLake")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.28), radius: 2, y: 1)

                            Text("Nada tocando no momento")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.72))

                            HStack(spacing: 7) {
                                if music.isAppInstalled("com.spotify.client") {
                                    Button("Spotify") {
                                        music.openPlayer(.spotify)
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.16), in: Capsule())
                                    .overlay(Capsule().stroke(Color.white.opacity(0.32), lineWidth: 0.75))
                                }
                                if music.isAppInstalled("com.apple.Music") {
                                    Button("Música") {
                                        music.openPlayer(.appleMusic)
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.16), in: Capsule())
                                    .overlay(Capsule().stroke(Color.white.opacity(0.32), lineWidth: 0.75))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(width: sectionGeo.size.width, height: sectionGeo.size.height, alignment: .center)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center, spacing: 13) {
                            Button {
                                music.openActivePlayer()
                            } label: {
                                Group {
                                    if let artwork = music.artwork {
                                        Image(nsImage: artwork)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.14))
                                            .overlay(
                                                Image(systemName: "music.note")
                                                    .font(.system(size: max(20, artSize * 0.34), weight: .semibold))
                                                    .foregroundStyle(.white)
                                            )
                                    }
                                }
                                .frame(width: artSize, height: artSize)
                                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                                        .stroke(Color.white.opacity(0.30), lineWidth: 0.85)
                                )
                                .shadow(color: Color.black.opacity(0.25), radius: 6, y: 3)
                            }
                            .buttonStyle(.plain)
                            .help("Abrir player de música")

                            VStack(alignment: .leading, spacing: 1.5) {
                                Text(music.title)
                                    .font(.system(size: 15.5, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .shadow(color: .black.opacity(0.28), radius: 2, y: 1)

                                Text(music.artist.isEmpty ? music.player.displayName : music.artist)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.84))
                                    .lineLimit(1)

                                HStack(spacing: 4) {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 9.5, weight: .semibold))
                                    Text(music.player.displayName)
                                        .font(.system(size: 10.5, weight: .medium))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(Color.white.opacity(0.65))
                            }

                            Spacer(minLength: 8)

                            AudioVisualizerView(
                                isPlaying: music.isPlaying,
                                accentColor: vizTint,
                                barCount: 5,
                                barWidth: 2.6,
                                maxHeight: 20,
                                spacing: 2.5
                            )
                        }

                        Spacer(minLength: 6)

                        HStack(spacing: 10) {
                            Text(formatTrackTime(displayedElapsed))
                                .font(.system(size: 11.5, weight: .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(Color.white.opacity(0.84))
                                .frame(width: 38, alignment: .leading)

                            GeometryReader { geo in
                                let w = max(1, geo.size.width)
                                ZStack(alignment: .leading) {
                                    Capsule(style: .continuous)
                                        .fill(Color.white.opacity(0.22))
                                        .frame(height: 5.5)

                                    Capsule(style: .continuous)
                                        .fill(sliderTint)
                                        .frame(width: progress > 0 ? max(5.5, w * CGFloat(progress)) : 0, height: 5.5)
                                }
                                .frame(height: 14)
                                .contentShape(Rectangle())
                                .gesture(scrubDragGesture(width: w))
                            }
                            .frame(height: 14)

                            Text(formatTrackTime(music.duration))
                                .font(.system(size: 11.5, weight: .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(Color.white.opacity(0.84))
                                .frame(width: 38, alignment: .trailing)
                        }

                        Spacer(minLength: 6)

                        HStack(spacing: 0) {
                            Button {
                                coordinator.selectTab(.music)
                            } label: {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.84))
                                    .frame(width: 32, height: 30)
                            }
                            .buttonStyle(.plain)
                            .help("Expandir player")

                            Spacer()

                            HStack(spacing: 34) {
                                Button {
                                    music.previousTrack()
                                } label: {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(.white)
                                        .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    music.togglePlayPause()
                                } label: {
                                    Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundStyle(customBtn ?? .white)
                                        .offset(x: music.isPlaying ? 0 : 1.5)
                                        .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                                        .frame(width: 32, height: 30)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    music.nextTrack()
                                } label: {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(.white)
                                        .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()

                            Button {
                                coordinator.selectTab(.audio)
                            } label: {
                                Image(systemName: audio.isExternalOrHeadphoneOutput ? audio.defaultOutputIconName : "laptopcomputer")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.84))
                                    .frame(width: 32, height: 30)
                            }
                            .buttonStyle(.plain)
                            .help(audio.defaultOutputName)
                        }
                    }
                    .frame(width: sectionGeo.size.width, height: sectionGeo.size.height, alignment: .topLeading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dynamicLakeGlanceBar: some View {
        let customBtn = settings.buttonAccentColor.color
        let dynaDropBg = customBtn ?? Color.white.opacity(0.14)
        let dynaDropFg = customBtn != nil ? settings.resolvedButtonForeground(fallback: .white) : Color.white.opacity(0.92)

        return VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 0.75)

            HStack(spacing: 10) {
                Button {
                    coordinator.openWeather()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: weather.symbolName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.88, blue: 0.45))

                        Text(weather.temperatureCelsius.map { String(format: "%.0f°", $0) } ?? "--°")
                            .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)

                        if !weather.conditionText.isEmpty {
                            Text(weather.conditionText)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.72))
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Ver previsão do tempo")

                Button {
                    coordinator.selectTab(.calendar)
                } label: {
                    if let next = calendar.nextEvent {
                        HStack(spacing: 4.5) {
                            Circle()
                                .fill(next.accentColor)
                                .frame(width: 6, height: 6)
                            Text(next.title)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .lineLimit(1)
                            Text(atollEventStartTime(next))
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(Color.white.opacity(0.66))
                                .lineLimit(1)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.68))
                            Text("Agenda livre")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.65))
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Abrir agenda")

                Spacer(minLength: 4)

                Button {
                    coordinator.selectTab(.shelf)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 9.5, weight: .semibold))
                        Text(shelf.items.isEmpty ? "DynaDrop" : "\(shelf.items.count) arq.")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(dynaDropFg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(dynaDropBg, in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Abrir bandeja DynaDrop")

                HStack(spacing: 2.5) {
                    if battery.isCharging || battery.isPluggedIn {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(Color(red: 0.30, green: 0.94, blue: 0.56))
                    }
                    Text("\(battery.percentage)%")
                        .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.white.opacity(0.80))
                }
            }
            .padding(.top, 7)
        }
    }

    // MARK: - Shared Reusable Components

    private func hairlineDivider(color: Color = Color.white.opacity(0.11)) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: 1)
            .padding(.vertical, 4)
    }

    private func glowingArtworkButton(
        size: CGFloat,
        cornerRadius: CGFloat,
        glowTint: Color,
        pauseScale: CGFloat,
        showAppBadge: Bool
    ) -> some View {
        Button {
            music.openActivePlayer()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let artwork = music.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(glowTint.opacity(0.24))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: size * 0.28, weight: .semibold))
                                    .foregroundStyle(glowTint)
                            )
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(music.isPlaying ? 0 : 0.24))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.75)
                )
                .scaleEffect(music.isPlaying ? 1.0 : pauseScale)

                if showAppBadge,
                   let bundleID = music.player.bundleIdentifier,
                   let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    let badgeSize = max(18, size * 0.26)
                    Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: badgeSize, height: badgeSize)
                        .clipShape(RoundedRectangle(cornerRadius: badgeSize * 0.25, style: .continuous))
                        .background(
                            RoundedRectangle(cornerRadius: badgeSize * 0.28, style: .continuous)
                                .fill(Color.black.opacity(0.92))
                                .padding(-1.5)
                        )
                        .offset(x: 4, y: 4)
                }
            }
            .frame(width: size, height: size)
            .background(
                RadialGradient(
                    colors: [
                        glowTint.opacity(music.isPlaying ? 0.50 : 0.14),
                        glowTint.opacity(music.isPlaying ? 0.20 : 0.04),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 3,
                    endRadius: size * 0.62
                )
                .scaleEffect(1.32)
                .blur(radius: 10)
            )
        }
        .buttonStyle(.plain)
        .help("Abrir player de música")
    }

    private func compactStandbyMusicView(
        iconSize: CGFloat,
        buttonTint: Color,
        buttonFg: Color,
        title: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: iconSize, height: iconSize)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: iconSize * 0.34, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.60))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.56))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                if music.isAppInstalled("com.spotify.client") {
                    Button("Spotify") { music.openPlayer(.spotify) }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(buttonFg)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(buttonTint, in: Capsule())
                }
                if music.isAppInstalled("com.apple.Music") {
                    Button("Música") { music.openPlayer(.appleMusic) }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(buttonFg)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(buttonTint, in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func capsuleScrubBar(
        tint: Color,
        trackHeight: CGFloat,
        trackColor: Color,
        showKnob: Bool,
        showTimestamps: Bool
    ) -> some View {
        let displayedElapsed = music.isScrubbing ? music.scrubSeconds : music.elapsedTime
        let progress = music.duration > 0 ? max(0, min(1, displayedElapsed / music.duration)) : 0

        return VStack(spacing: 3.5) {
            GeometryReader { geo in
                let w = max(1, geo.size.width)
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(trackColor)
                        .frame(height: trackHeight)

                    Capsule(style: .continuous)
                        .fill(tint)
                        .frame(width: progress > 0 ? max(trackHeight, w * CGFloat(progress)) : 0, height: trackHeight)

                    if showKnob {
                        Circle()
                            .fill(Color.white)
                            .frame(width: trackHeight + 3.5, height: trackHeight + 3.5)
                            .offset(x: max(0, min(w - (trackHeight + 3.5), w * CGFloat(progress) - (trackHeight + 3.5) / 2)))
                    }
                }
                .frame(height: 12)
                .contentShape(Rectangle())
                .gesture(scrubDragGesture(width: w))
            }
            .frame(height: 12)

            if showTimestamps {
                HStack {
                    Text(formatTrackTime(displayedElapsed))
                    Spacer(minLength: 8)
                    Text(formatTrackTime(music.duration))
                }
                .font(.system(size: 9.5, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.white.opacity(0.48))
                .lineLimit(1)
            }
        }
    }

    private func scrubDragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard music.duration > 0 else { return }
                music.isScrubbing = true
                music.scrubSeconds = Double(max(0, min(1, value.location.x / width))) * music.duration
            }
            .onEnded { value in
                guard music.duration > 0 else {
                    music.isScrubbing = false
                    return
                }
                let target = Double(max(0, min(1, value.location.x / width))) * music.duration
                music.isScrubbing = false
                music.seek(to: target)
            }
    }

    private func smallCircleAction(
        _ symbol: String,
        size: CGFloat = 26,
        iconSize: CGFloat = 12,
        helpText: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.84))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private func quickCapsuleSlider(
        icon: String,
        label: String,
        value: Double,
        tint: Color,
        onIconTap: (() -> Void)?,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        let clamped = max(0, min(1, value))
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if let onIconTap {
                    Button(action: onIconTap) {
                        Image(systemName: icon)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(tint)
                }
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.84))
                Spacer()
                Text("\(Int((clamped * 100).rounded()))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(tint)
            }

            GeometryReader { geo in
                let w = max(1, geo.size.width)
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 6)
                    Capsule(style: .continuous)
                        .fill(tint)
                        .frame(width: clamped > 0.005 ? max(6, w * CGFloat(clamped)) : 0, height: 6)
                }
                .frame(height: 14)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let ratio = max(0, min(1, Double(drag.location.x / w)))
                            onChange(ratio)
                        }
                        .onEnded { drag in
                            let ratio = max(0, min(1, Double(drag.location.x / w)))
                            onChange(ratio)
                        }
                )
            }
            .frame(height: 14)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func miniFiveDayStrip(todayTint: Color, todayForeground: Color, fadeColor: Color) -> some View {
        let now = extraWidgets.now
        let cal = Calendar.current

        return ZStack {
            HStack(spacing: 4) {
                ForEach([-1, 0, 1, 2, 3], id: \.self) { offset in
                    let dayDate = cal.date(byAdding: .day, value: offset, to: now) ?? now
                    let isToday = (offset == 0)
                    Button {
                        coordinator.selectTab(.calendar)
                    } label: {
                        VStack(spacing: 3.5) {
                            Text(atollWeekdayLabel(dayDate))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(isToday ? .white : Color.white.opacity(0.58))
                                .lineLimit(1)

                            ZStack {
                                Circle()
                                    .fill(isToday ? todayTint : .clear)
                                    .frame(width: 20, height: 20)
                                Text("\(cal.component(.day, from: dayDate))")
                                    .font(.system(size: 11.5, weight: .medium, design: .rounded).monospacedDigit())
                                    .foregroundStyle(isToday ? todayForeground : Color.white.opacity(0.72))
                            }
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(isToday ? todayTint.opacity(0.18) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            LinearGradient(colors: [fadeColor, Color.clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 10)
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, alignment: .leading)

            LinearGradient(colors: [Color.clear, fadeColor], startPoint: .leading, endPoint: .trailing)
                .frame(width: 10)
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }

    private func atollCalendarEventsList(
        maxTimed: Int,
        buttonTint: Color,
        buttonFg: Color,
        rowFill: Color
    ) -> some View {
        let allDayEvents = calendar.events.filter { $0.isAllDay }
        let timedLimit = allDayEvents.isEmpty ? maxTimed : max(1, maxTimed - 1)
        let timedEvents = Array(calendar.events.filter { !$0.isAllDay }.prefix(timedLimit))

        return VStack(alignment: .leading, spacing: 5) {
            if !calendar.hasCalendarAccess {
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    Button("Permitir Acesso") {
                        calendar.requestAccess()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(buttonFg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(buttonTint, in: Capsule())
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            } else if allDayEvents.isEmpty && timedEvents.isEmpty {
                Spacer(minLength: 0)
                VStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.35))
                    Text("Sem eventos hoje")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.48))
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else {
                if !allDayEvents.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(allDayEvents) { event in
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(event.accentColor)
                                        .frame(width: 5, height: 5)
                                    Text(event.title)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.88))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 7)
                                .frame(height: 20)
                                .background(Capsule().fill(rowFill))
                            }
                        }
                    }
                    .frame(height: 20)
                }

                ForEach(timedEvents) { event in
                    HStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(event.accentColor)
                            .frame(width: 3, height: 20)

                        Text(event.title)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        Text(atollEventStartTime(event))
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .foregroundStyle(Color.white.opacity(0.55))
                            .lineLimit(1)

                        if let url = event.meetingURL {
                            Button {
                                NSWorkspace.shared.open(url)
                            } label: {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(buttonFg)
                                    .frame(width: 20, height: 20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(buttonTint)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("Entrar na reunião")
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func miniCapsuleMeterRow(label: String, ratio: Double, valueText: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.52))
                Spacer()
                Text(valueText)
                    .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(tint)
            }
            GeometryReader { geo in
                let w = max(1, geo.size.width)
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.14))
                    Capsule(style: .continuous)
                        .fill(tint)
                        .frame(width: max(5, w * CGFloat(max(0, min(1, ratio)))))
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func statMiniPill(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.48))
            Text(value)
                .font(.system(size: 11.5, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func weatherPill(icon: String, value: String, tint: Color) -> some View {
        HStack(spacing: 3.5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.86))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.08), in: Capsule())
    }

    // MARK: - Formatting Helpers

    private var formattedClockTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: extraWidgets.now)
    }

    private var formattedWeekdayAndMonth: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "EEE, d MMM"
        return f.string(from: extraWidgets.now).capitalized
    }

    private func eventTimeLabel(_ event: CalendarEventItem) -> String {
        if event.isAllDay { return "O dia todo" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "\(f.string(from: event.startDate))–\(f.string(from: event.endDate))"
    }

    private func atollMonthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "MMM"
        return f.string(from: date).replacingOccurrences(of: ".", with: "").capitalized
    }

    private func atollYearLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: date)
    }

    private func atollWeekdayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "E"
        let raw = f.string(from: date).replacingOccurrences(of: ".", with: "").capitalized
        return String(raw.prefix(3))
    }

    private func atollEventStartTime(_ event: CalendarEventItem) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: event.startDate)
    }

    private func formatTrackTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
