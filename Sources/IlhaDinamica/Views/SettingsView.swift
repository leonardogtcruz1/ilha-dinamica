import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var coordinator: IslandCoordinator
    @ObservedObject var battery: BatteryService
    @ObservedObject var audio: AudioControlService
    @ObservedObject var weather: WeatherService
    @ObservedObject var mediaKeys: MediaKeyInterceptor
    @ObservedObject var calls: CallMonitorService

    var body: some View {
        Form {
            Section("Módulos Ativos") {
                Toggle("Player de Música (Spotify & Apple Music)", isOn: $settings.enableMusicModule)
                Toggle("Timer Pomodoro", isOn: $settings.enablePomodoroModule)
                Toggle("Bandeja de Arquivos (Shelf)", isOn: $settings.enableShelfModule)
                Toggle("Histórico de Clipboard", isOn: $settings.enableClipboardModule)
                Toggle("Agenda & Reuniões", isOn: $settings.enableCalendarModule)
                Toggle("Notas & Tarefas", isOn: $settings.enableNotesModule)
                Toggle("Áudio, Brilho & Bluetooth", isOn: $settings.enableAudioModule)
                Toggle("Mac (Bateria, CPU, RAM & Clima)", isOn: $settings.enableSystemModule)
            }

            Section("Biblioteca de Widgets Extras") {
                ForEach(IslandTab.allCases.filter { !$0.isDefaultEnabled }) { tab in
                    Toggle(
                        "\(tab.title) — \(tab.subtitle)",
                        isOn: Binding(
                            get: { settings.isTabEnabled(tab) },
                            set: { settings.setTabEnabled(tab, enabled: $0) }
                        )
                    )
                }
            }

            Section("Comportamento e Alertas") {
                Picker("Estilo e layout da ilha", selection: $settings.layoutPreset) {
                    ForEach(IslandLayoutPreset.allCases) { preset in
                        Text("\(preset.title) (\(preset.badge))").tag(preset)
                    }
                }

                Picker("Cor da ilha (fundo e borda)", selection: $settings.islandSurfaceTheme) {
                    ForEach(IslandSurfaceTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }

                Picker("Cor dos botões e abas", selection: $settings.buttonAccentColor) {
                    ForEach(IslandElementColor.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }

                Picker("Cor dos sliders e barras", selection: $settings.sliderAccentColor) {
                    ForEach(IslandElementColor.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }

                Toggle("Expandir ao passar o mouse", isOn: $settings.openOnHover)

                if settings.openOnHover {
                    HStack {
                        Text("Atraso ao abrir (hover)")
                        Spacer()
                        Slider(value: $settings.hoverDelayMs, in: 0...1000, step: 50)
                            .frame(width: 145)
                        Text(settings.hoverDelayMs == 0 ? "0 ms" : "\(Int(settings.hoverDelayMs)) ms")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 58, alignment: .trailing)
                    }
                }

                HStack {
                    Text("Velocidade da animação")
                    Spacer()
                    Slider(value: $settings.animationSpeed, in: 0.5...2.5, step: 0.1)
                        .frame(width: 145)
                    Text("\(String(format: "%.1fx", settings.animationSpeed)) (\(settings.animationSpeedLabel))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: 84, alignment: .trailing)
                }

                Toggle("HUD de Volume e Brilho na ilha", isOn: $settings.showHudToasts)
                if settings.showHudToasts {
                    Toggle("Ocultar popup nativo do macOS (volume e brilho)", isOn: $settings.replaceSystemHUD)
                    if settings.replaceSystemHUD {
                        if mediaKeys.isActive {
                            Text("Ativo — o popup nativo volta automaticamente ao fechar o app.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if !mediaKeys.isAccessibilityGranted {
                            HStack {
                                Text("Requer permissão de Acessibilidade")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Autorizar") {
                                    mediaKeys.requestAccessibilityAndEnable()
                                }
                                .controlSize(.small)
                            }
                        }
                    }
                }
                HStack {
                    Toggle("Aviso de fones Bluetooth / AirPods", isOn: $settings.showBluetoothToasts)
                    Spacer()
                    Button("Testar") {
                        audio.triggerBluetoothPreview()
                    }
                    .controlSize(.small)
                }
                HStack {
                    Toggle("Popup de ligações recebidas e ativas", isOn: $settings.showCallAlerts)
                    Spacer()
                    Button("Testar") {
                        calls.triggerPreviewCall()
                    }
                    .controlSize(.small)
                }
                Toggle("Lembrete de reuniões (5 min antes)", isOn: $settings.showMeetingToasts)
                Toggle("Aviso ao trocar de música", isOn: $settings.showTrackChangeToast)
                Toggle("Avisos de bateria e carregador", isOn: $settings.showBatteryToasts)
                Toggle("Iniciar junto com o macOS", isOn: $settings.launchAtLogin)

                if let notice = settings.launchAtLoginNotice {
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Clima") {
                Toggle("Mostrar temperatura no topo da ilha", isOn: $settings.showWeatherInHeader)

                HStack {
                    TextField("Cidade (vazio = automático)", text: $settings.weatherCity)
                        .textFieldStyle(.roundedBorder)

                    Button("Atualizar") {
                        Task { await weather.refreshNow() }
                    }
                }
            }

            Section("Gravação de Tela") {
                Toggle("Gravar áudio do Mac (sistema)", isOn: $settings.recordSystemAudio)
                Toggle("Gravar áudio do microfone", isOn: $settings.recordIncludeMic)
                Text("Captura o áudio estéreo do Mac em alta qualidade. Com fones Bluetooth/AirPods, se o microfone estiver ativado, usa automaticamente o microfone integrado do Mac para não perder qualidade.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Destacar cliques do mouse", isOn: $settings.recordShowClicks)
                Toggle("Adicionar gravação à Bandeja da ilha", isOn: $settings.recordAddToShelf)
            }

            Section("Pomodoro") {
                Stepper(
                    "Foco: \(settings.focusMinutes) min",
                    value: $settings.focusMinutes,
                    in: 1...120
                )
                Stepper(
                    "Pausa curta: \(settings.shortBreakMinutes) min",
                    value: $settings.shortBreakMinutes,
                    in: 1...60
                )
                Stepper(
                    "Pausa longa: \(settings.longBreakMinutes) min",
                    value: $settings.longBreakMinutes,
                    in: 1...90
                )

                Toggle("Iniciar próxima etapa automaticamente", isOn: $settings.pomodoroAutoStart)

                Picker("Som de conclusão", selection: $settings.pomodoroSound) {
                    ForEach(SettingsStore.availableSounds, id: \.self) { sound in
                        Text(sound).tag(sound)
                    }
                }
            }

            Section("Testar Animações") {
                HStack(spacing: 8) {
                    Button("Carregamento") {
                        if coordinator.mode == .expanded { coordinator.collapse() }
                        coordinator.showToast(
                            ToastEvent(kind: .charging(percent: battery.percentage, watts: battery.adapterWatts ?? 35))
                        )
                    }

                    Button("Volume HUD") {
                        if coordinator.mode == .expanded { coordinator.collapse() }
                        coordinator.showToast(
                            ToastEvent(kind: .volume(
                                level: audio.volume,
                                isMuted: audio.isMuted,
                                deviceName: audio.defaultOutputName,
                                deviceIcon: audio.defaultOutputIconName
                            ))
                        )
                    }

                    Button("AirPods") {
                        if coordinator.mode == .expanded { coordinator.collapse() }
                        let bt = audio.primaryAudioBluetoothDevice
                        coordinator.showToast(
                            ToastEvent(kind: .bluetoothConnected(
                                name: bt?.name ?? "AirPods Pro 3 de Leo",
                                batteryText: bt?.batterySummary ?? "E 98% • D 100% • Estojo 14%",
                                isAudio: true,
                                batteryLeft: bt?.batteryLeft ?? "98%",
                                batteryRight: bt?.batteryRight ?? "100%",
                                batteryCase: bt?.batteryCase ?? "14%",
                                batteryMain: bt?.batteryMain,
                                iconName: bt.map { audio.iconForBluetoothDevice($0) } ?? "airpodspro"
                            )),
                            duration: 4.2
                        )
                    }

                    Button("Pomodoro") {
                        if coordinator.mode == .expanded { coordinator.collapse() }
                        coordinator.showToast(
                            ToastEvent(kind: .pomodoroFinished(completed: .focus, next: .shortBreak))
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 470, height: 645)
    }
}
