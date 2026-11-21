import SwiftUI

struct CompactIslandView: View {
    @ObservedObject var coordinator: IslandCoordinator
    @ObservedObject var settings: SettingsStore
    @ObservedObject var music: MusicService
    @ObservedObject var pomodoro: PomodoroService
    @ObservedObject var battery: BatteryService
    @ObservedObject var audio: AudioControlService
    @ObservedObject var recorder: ScreenRecorderService

    private var showMusic: Bool {
        settings.enableMusicModule && (music.isPlaying || music.hasTrack)
    }

    private var showPomodoro: Bool {
        settings.enablePomodoroModule && pomodoro.isRunning
    }

    private var showBattery: Bool {
        settings.enableBatteryModule && (battery.isCharging || battery.percentage <= 20)
    }

    var body: some View {
        HStack(spacing: 0) {
            leftWing
                .frame(maxWidth: .infinity, alignment: .leading)

            if coordinator.geometry.hasNotch {
                Spacer()
                    .frame(width: coordinator.geometry.notchWidth + 12)
            } else {
                Spacer(minLength: 8)
            }

            rightWing
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, coordinator.geometry.hasNotch ? 11 : 10)
        .frame(height: coordinator.currentSize.height)
    }

    @ViewBuilder
    private var leftWing: some View {
        if recorder.isRecording {
            TimelineView(.animation(minimumInterval: 0.1)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let pulse = 0.55 + 0.45 * ((sin(t * 4.5) + 1.0) * 0.5)
                ZStack {
                    Circle()
                        .stroke(Color(red: 1.0, green: 0.26, blue: 0.24).opacity(0.42 * pulse), lineWidth: 2)
                        .frame(width: 17, height: 17)
                    Circle()
                        .fill(Color(red: 1.0, green: 0.26, blue: 0.24).opacity(pulse))
                        .frame(width: 9.5, height: 9.5)
                }
            }
        } else if showMusic {
            HStack(spacing: 5) {
                if let artwork = music.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 19, height: 19)
                        .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                            .fill(music.accentColor.opacity(0.24))
                        Image(systemName: "music.note")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(music.accentColor)
                    }
                    .frame(width: 19, height: 19)
                }

                if audio.isMicMuted {
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Color.red)
                } else if showPomodoro {
                    Image(systemName: pomodoro.phase.iconName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(pomodoro.phase.accentColor)
                }
            }
        } else if showPomodoro {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 2.4)
                Circle()
                    .trim(from: 0, to: pomodoro.progress)
                    .stroke(
                        pomodoro.phase.accentColor,
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Image(systemName: pomodoro.phase.iconName)
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(pomodoro.phase.accentColor)
            }
            .frame(width: 19, height: 19)
        } else if showBattery {
            Image(systemName: batteryIconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(batteryAccent)
                .symbolRenderingMode(.hierarchical)
        } else {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.red)
        }
    }

    @ViewBuilder
    private var rightWing: some View {
        if recorder.isRecording {
            Text(recorder.formattedElapsed)
                .font(.system(size: 11.5, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color(red: 1.0, green: 0.30, blue: 0.28))
                .lineLimit(1)
        } else if showPomodoro {
            Text(pomodoro.formattedRemaining)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(pomodoro.phase.accentColor)
                .lineLimit(1)
        } else if showMusic {
            AudioVisualizerView(
                isPlaying: music.isPlaying,
                accentColor: music.accentColor,
                barCount: 4,
                barWidth: 2.4,
                maxHeight: 14,
                spacing: 2.0
            )
        } else if showBattery {
            Text("\(battery.percentage)%")
                .font(.system(size: 11.5, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(batteryAccent)
                .lineLimit(1)
        } else {
            Text("Mudo")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color.red.opacity(0.92))
                .lineLimit(1)
        }
    }

    private var batteryIconName: String {
        if battery.isCharging || battery.isPluggedIn {
            return "bolt.fill"
        } else if battery.percentage <= 20 {
            return "battery.25"
        } else if battery.percentage <= 50 {
            return "battery.50"
        } else if battery.percentage <= 80 {
            return "battery.75"
        } else {
            return "battery.100"
        }
    }

    private var batteryAccent: Color {
        if battery.isCharging || battery.isFullyCharged {
            return Color(red: 0.22, green: 0.90, blue: 0.48)
        } else if battery.percentage <= 10 {
            return Color(red: 1.0, green: 0.28, blue: 0.26)
        } else if battery.percentage <= 20 {
            return Color(red: 1.0, green: 0.65, blue: 0.16)
        } else {
            return Color.white.opacity(0.92)
        }
    }
}
