import AppKit
import SwiftUI

struct ToastIslandView: View {
    let event: ToastEvent
    let geometry: NotchGeometry
    @ObservedObject var music: MusicService

    var body: some View {
        VStack(spacing: 0) {
            if geometry.hasNotch {
                Spacer()
                    .frame(height: geometry.notchHeight - 2)
            }

            if case .volume(let level, let isMuted) = event.kind {
                hudBarRow(
                    icon: isMuted ? "speaker.slash.fill" : (level > 0.5 ? "speaker.wave.3.fill" : "speaker.wave.1.fill"),
                    title: isMuted ? "Sem som" : "Volume",
                    value: isMuted ? 0 : level,
                    tint: isMuted ? .red : Color(red: 0.28, green: 0.88, blue: 0.54)
                )
            } else if case .brightness(let level) = event.kind {
                hudBarRow(
                    icon: "sun.max.fill",
                    title: "Brilho",
                    value: level,
                    tint: Color(red: 1.0, green: 0.78, blue: 0.24)
                )
            } else {
                standardBannerRow
            }
        }
    }

    private var standardBannerRow: some View {
        HStack(spacing: 12) {
            iconBadge

            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subtitleText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            trailingView
        }
        .padding(.horizontal, geometry.hasNotch ? 24 : 18)
        .frame(maxHeight: .infinity)
    }

    private func hudBarRow(icon: String, title: String, value: Float, tint: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.20))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int((value * 100).rounded()))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(tint)
                }

                GeometryReader { geo in
                    let w = max(1, geo.size.width)
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.16))
                        Capsule(style: .continuous)
                            .fill(tint)
                            .frame(width: w * CGFloat(max(0, min(1, value))))
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(.horizontal, geometry.hasNotch ? 24 : 18)
        .frame(maxHeight: .infinity)
    }

    private var accentColor: Color {
        switch event.kind {
        case .charging, .fullBattery:
            return Color(red: 0.22, green: 0.90, blue: 0.48)
        case .unplugged:
            return Color(red: 1.0, green: 0.72, blue: 0.22)
        case .lowBattery:
            return Color(red: 1.0, green: 0.30, blue: 0.26)
        case .pomodoroFinished(let completed, _):
            return completed.accentColor
        case .trackChanged(_, _, let accent):
            return accent
        case .volume(_, let isMuted):
            return isMuted ? .red : Color(red: 0.28, green: 0.88, blue: 0.54)
        case .brightness:
            return Color(red: 1.0, green: 0.78, blue: 0.24)
        case .micMuted(let isMuted):
            return isMuted ? Color(red: 1.0, green: 0.30, blue: 0.26) : Color(red: 0.22, green: 0.90, blue: 0.48)
        case .bluetoothConnected:
            return Color(red: 0.34, green: 0.72, blue: 1.0)
        case .meetingSoon:
            return Color(red: 1.0, green: 0.38, blue: 0.38)
        case .shelfAdded:
            return Color(red: 0.36, green: 0.76, blue: 1.0)
        case .recordingSaved:
            return Color(red: 0.22, green: 0.90, blue: 0.48)
        case .recordingError:
            return Color(red: 1.0, green: 0.30, blue: 0.26)
        }
    }

    private var iconName: String {
        switch event.kind {
        case .charging:
            return "bolt.fill"
        case .unplugged:
            return "battery.50"
        case .lowBattery:
            return "battery.25"
        case .fullBattery:
            return "battery.100.bolt"
        case .pomodoroFinished(let completed, _):
            return completed.iconName
        case .trackChanged:
            return "music.note"
        case .volume(_, let isMuted):
            return isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        case .brightness:
            return "sun.max.fill"
        case .micMuted(let isMuted):
            return isMuted ? "mic.slash.fill" : "mic.fill"
        case .bluetoothConnected(_, _, let isAudio):
            return isAudio ? "airpodspro" : "dot.radiowaves.left.and.right"
        case .meetingSoon:
            return "video.fill"
        case .shelfAdded:
            return "tray.and.arrow.down.fill"
        case .recordingSaved:
            return "record.circle.fill"
        case .recordingError:
            return "exclamationmark.triangle.fill"
        }
    }

    private var titleText: String {
        switch event.kind {
        case .charging:
            return "Carregando"
        case .unplugged:
            return "Na bateria"
        case .lowBattery:
            return "Bateria fraca"
        case .fullBattery:
            return "Bateria completa"
        case .pomodoroFinished(let completed, _):
            return "\(completed.title) concluído"
        case .trackChanged(let title, _, _):
            return title
        case .volume:
            return "Volume"
        case .brightness:
            return "Brilho"
        case .micMuted(let isMuted):
            return isMuted ? "Microfone Mutado" : "Microfone Ativado"
        case .bluetoothConnected(let name, _, _):
            return name
        case .meetingSoon(let title, _):
            return title
        case .shelfAdded(let count):
            return count == 1 ? "Arquivo guardado" : "\(count) arquivos guardados"
        case .recordingSaved:
            return "Gravação salva"
        case .recordingError:
            return "Erro na gravação"
        }
    }

    private var subtitleText: String {
        switch event.kind {
        case .charging(_, let watts):
            if let watts {
                return "Fonte de \(watts)W conectada"
            }
            return "Carregador conectado"
        case .unplugged:
            return "Alimentação desconectada"
        case .lowBattery:
            return "Conecte o carregador em breve"
        case .fullBattery:
            return "Carga de 100% atingida"
        case .pomodoroFinished(_, let next):
            return "Próxima etapa: \(next.title)"
        case .trackChanged(_, let artist, _):
            return artist.isEmpty ? "Tocando agora" : artist
        case .volume, .brightness:
            return ""
        case .micMuted(let isMuted):
            return isMuted ? "Captura de áudio silenciada" : "Pronto para falar"
        case .bluetoothConnected(_, let batteryText, _):
            return batteryText ?? "Dispositivo Bluetooth conectado"
        case .meetingSoon(_, let minutes):
            return minutes <= 1 ? "Começa agora" : "Começa em \(minutes) minutos"
        case .shelfAdded:
            return "Disponível na Bandeja da ilha"
        case .recordingSaved(let filename):
            return filename
        case .recordingError(let message):
            return message
        }
    }

    @ViewBuilder
    private var iconBadge: some View {
        if case .trackChanged = event.kind, let artwork = music.artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.75)
                )
                .shadow(color: accentColor.opacity(0.32), radius: 5, x: 0, y: 2)
        } else {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.20))
                    .frame(width: 32, height: 32)
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
        }
    }

    @ViewBuilder
    private var trailingView: some View {
        switch event.kind {
        case .charging(let percent, _), .unplugged(let percent), .lowBattery(let percent):
            pill("\(percent)%", color: accentColor)

        case .fullBattery:
            pill("100%", color: accentColor)

        case .pomodoroFinished(_, let next):
            pill(next.shortTitle, color: next.accentColor)

        case .trackChanged(_, _, let accent):
            AudioVisualizerView(
                isPlaying: true,
                accentColor: accent,
                barCount: 4,
                barWidth: 2.5,
                maxHeight: 16,
                spacing: 2.2
            )

        case .micMuted(let isMuted):
            pill(isMuted ? "OFF" : "ON", color: accentColor)

        case .bluetoothConnected:
            pill("BT", color: accentColor)

        case .meetingSoon(_, let minutes):
            pill("\(minutes)m", color: accentColor)

        case .shelfAdded(let count):
            pill("+\(count)", color: accentColor)

        case .recordingSaved(let filename):
            pill(filename.lowercased().hasSuffix(".mp4") ? "MP4" : "MOV", color: accentColor)

        case .recordingError:
            pill("!", color: accentColor)

        case .volume, .brightness:
            EmptyView()
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.16), in: Capsule())
    }
}
