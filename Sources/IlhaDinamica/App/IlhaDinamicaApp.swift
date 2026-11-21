import AppKit
import SwiftUI

@main
struct IlhaDinamicaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Ilha Dinâmica", systemImage: "capsule.inset.filled") {
            MenuBarContentView(
                coordinator: appDelegate.coordinator,
                music: appDelegate.music,
                pomodoro: appDelegate.pomodoro,
                battery: appDelegate.battery,
                audio: appDelegate.audio,
                recorder: appDelegate.recorder,
                openSettings: { appDelegate.openSettingsWindow() }
            )
        }
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
