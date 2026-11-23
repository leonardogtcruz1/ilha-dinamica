import AppKit
import SwiftUI

@main
struct IlhaDinamicaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(
                coordinator: appDelegate.coordinator,
                music: appDelegate.music,
                pomodoro: appDelegate.pomodoro,
                battery: appDelegate.battery,
                audio: appDelegate.audio,
                recorder: appDelegate.recorder,
                openSettings: { appDelegate.openSettingsWindow() }
            )
        } label: {
            MenuBarLabelView(coordinator: appDelegate.coordinator)
        }
    }
}

private struct MenuBarLabelView: View {
    @ObservedObject var coordinator: IslandCoordinator

    var body: some View {
        Image(systemName: coordinator.isTemporarilyHidden ? "eye.slash" : "capsule.inset.filled")
            .accessibilityLabel("Ilha Dinâmica")
    }
}

private struct MenuBarContentView: View {
    @ObservedObject var coordinator: IslandCoordinator
    @ObservedObject var music: MusicService
    @ObservedObject var pomodoro: PomodoroService
    @ObservedObject var battery: BatteryService
    @ObservedObject var audio: AudioControlService
    @ObservedObject var recorder: ScreenRecorderService
    let openSettings: () -> Void

    var body: some View {
        if coordinator.isTemporarilyHidden {
            let showTitle = coordinator.hiddenResumeTimeText.map { "Mostrar Ilha (volta às \($0))" } ?? "Mostrar Ilha"
            Button(showTitle) {
                coordinator.showFromTemporaryHide()
            }
            .keyboardShortcut("h", modifiers: [.control, .option])
        } else {
            Button("Ocultar Ilha") {
                coordinator.hideTemporarily()
            }
            .keyboardShortcut("h", modifiers: [.control, .option])

            Menu("Ocultar por tempo…") {
                Button("1 minuto") { coordinator.hideTemporarily(for: 60) }
                Button("5 minutos") { coordinator.hideTemporarily(for: 300) }
                Button("15 minutos") { coordinator.hideTemporarily(for: 900) }
                Button("1 hora") { coordinator.hideTemporarily(for: 3600) }
            }
        }

        Divider()

        Button(coordinator.mode == .expanded ? "Recolher Ilha" : "Expandir Ilha") {
            coordinator.toggleExpanded()
        }

        Button(coordinator.isPinned ? "Desafixar Ilha" : "Fixar Ilha Aberta") {
            coordinator.togglePin()
        }

        Divider()

        Button(audio.isMicMuted ? "Ativar Microfone" : "Mutar Microfone") {
            audio.toggleMicMute()
        }

        Button(coordinator.isMirrorOpen ? "Fechar Espelho Webcam" : "Abrir Espelho Webcam") {
            coordinator.toggleMirror()
        }

        Button(
            recorder.isRecording
                ? "Parar Gravação (\(recorder.formattedElapsed))"
                : "Gravar Tela Inteira"
        ) {
            recorder.toggleRecording()
        }
        .disabled(recorder.isStopping)

        Button("Gravar Área Selecionada…") {
            recorder.startAreaSelectionRecording()
        }

        Divider()

        if music.hasTrack {
            Button(music.isPlaying ? "Pausar: \(music.title)" : "Tocar: \(music.title)") {
                music.togglePlayPause()
            }
        }

        Button(
            pomodoro.isRunning
                ? "Pausar Pomodoro (\(pomodoro.formattedRemaining))"
                : "Iniciar Pomodoro (\(pomodoro.phase.title))"
        ) {
            pomodoro.toggle()
        }

        Divider()

        Button("Preferências…") {
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Encerrar Ilha Dinâmica") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
