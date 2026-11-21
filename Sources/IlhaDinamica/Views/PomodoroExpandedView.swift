import SwiftUI

struct PomodoroExpandedView: View {
    @ObservedObject var pomodoro: PomodoroService

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 7)

                Circle()
                    .trim(from: 0, to: pomodoro.progress)
                    .stroke(
                        pomodoro.phase.accentColor,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.25), value: pomodoro.progress)

                VStack(spacing: 2) {
                    Text(pomodoro.formattedRemaining)
                        .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                    Text(pomodoro.phase.shortTitle.uppercased())
                        .font(.system(size: 8.5, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(pomodoro.phase.accentColor)
                }
            }
            .frame(width: 86, height: 86)

            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 6) {
                    ForEach(PomodoroPhase.allCases) { phase in
                        let selected = pomodoro.phase == phase
                        Button {
                            pomodoro.selectPhase(phase)
                        } label: {
                            Text(phase.shortTitle)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(selected ? .black : Color.white.opacity(0.72))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    selected ? phase.accentColor : Color.white.opacity(0.10),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        pomodoro.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 11.5, weight: .bold))
                            Text(pomodoro.isRunning ? "Pausar" : "Iniciar")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(pomodoro.phase.accentColor, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        pomodoro.addOneMinute()
                    } label: {
                        Text("+1m")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Adicionar 1 minuto")

                    Button {
                        pomodoro.reset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Reiniciar etapa")

                    Button {
                        pomodoro.skip()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Pular para próxima etapa")
                }

                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(
                                    index < pomodoro.completedSessionsInCycle
                                        ? PomodoroPhase.focus.accentColor
                                        : Color.white.opacity(0.18)
                                )
                                .frame(width: 6.5, height: 6.5)
                        }
                    }

                    Text("Hoje: \(pomodoro.completedToday) ciclos • \(pomodoro.focusedMinutesToday) min")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.54))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
    }
}
